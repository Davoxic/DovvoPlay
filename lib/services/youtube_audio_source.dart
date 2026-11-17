import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_service.dart';

/// Sorgente audio progressiva basata su StreamAudioSource.
///
/// Invece di passare direttamente l'URL di Google Video ad AVPlayer (che fallirebbe
/// con errore 403 o (-1) unknown error su iOS a causa dei controlli di sicurezza di Apple),
/// YouTubeAudioSource riceve i chunk HTTP tramite il client Dart e li serve al player
/// in streaming continuo con avvio immediato (< 200 ms).
class YouTubeAudioSource extends StreamAudioSource {
  final String videoId;
  StreamInfo streamInfo;

  YouTubeAudioSource({
    required this.videoId,
    required this.streamInfo,
    dynamic tag,
  }) : super(tag: tag);

  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    var total = streamInfo.size.totalBytes;
    var rangeStart = start ?? 0;
    var rangeEnd = _rangeEnd(total, rangeStart, end);
    final client = http.Client();
    http.Request createRequest(Uri url, int sourceLength, int from, int to) {
      final req = http.Request('GET', url);
      if (sourceLength > 0) {
        req.headers['Range'] = 'bytes=$from-${to > 0 ? to - 1 : ''}';
      }
      req.headers['User-Agent'] = _userAgent;
      return req;
    }

    Future<http.StreamedResponse> send(Uri url) => client
        .send(createRequest(url, total, rangeStart, rangeEnd))
        .timeout(const Duration(seconds: 15));

    try {
      var response = await send(streamInfo.url);

      // Aggiorna l'URL firmato scaduto e ritenta una volta.
      if (response.statusCode == 403) {
        await response.stream.drain();
        final fresh = await YouTubeService.instance
            .getPlayableStreamInfo(videoId)
            .timeout(const Duration(seconds: 20));
        if (fresh == null) {
          throw HttpException(
            YouTubeService.instance.lastFailureReason ??
                'YouTube non ha rinnovato lo stream scaduto.',
          );
        }
        streamInfo = fresh;
        total = streamInfo.size.totalBytes;
        rangeStart = start ?? 0;
        rangeEnd = _rangeEnd(total, rangeStart, end);
        response = await send(streamInfo.url);
      }

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.stream.drain();
        throw HttpException(
          'YouTube ha risposto HTTP ${response.statusCode} durante lo streaming.',
        );
      }
      if (rangeStart > 0 && response.statusCode == HttpStatus.ok) {
        await response.stream.drain();
        throw const HttpException(
          'YouTube non ha rispettato la richiesta di intervallo audio.',
        );
      }

      final isWebm = streamInfo.container.name.toLowerCase() == 'webm';
      final contentType = isWebm ? 'audio/webm' : 'audio/mp4';
      final expectedLength = rangeEnd > rangeStart
          ? rangeEnd - rangeStart
          : response.contentLength;

      return StreamAudioResponse(
        sourceLength: total > 0 ? total : null,
        contentLength: response.contentLength ?? expectedLength,
        offset: rangeStart,
        stream: _closeClientWithStream(response.stream, client),
        contentType: contentType,
      );
    } catch (e) {
      client.close();
      print('Errore YouTubeAudioSource.request: $e');
      rethrow;
    }
  }

  int _rangeEnd(int total, int start, int? end) {
    if (total <= 0) return 0;
    final requestedEnd = end == null || end > total ? total : end;
    return requestedEnd < start ? start : requestedEnd;
  }

  Stream<List<int>> _closeClientWithStream(
    Stream<List<int>> source,
    http.Client client,
  ) {
    StreamSubscription<List<int>>? subscription;
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        subscription = source.timeout(
          const Duration(seconds: 20),
          onTimeout: (sink) {
            sink.addError(
              TimeoutException(
                  'Timeout durante la ricezione dello stream YouTube.'),
            );
            sink.close();
          },
        ).listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
              unawaited(controller.close());
            }
            client.close();
          },
          onDone: () {
            if (!controller.isClosed) unawaited(controller.close());
            client.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
        client.close();
      },
    );
    return controller.stream;
  }
}
