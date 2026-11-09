import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_service.dart';

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
    final total = streamInfo.size.totalBytes;
    final rangeStart = start ?? 0;
    final rangeEnd = (end != null && end < total) ? end : total;
    final length = rangeEnd - rangeStart;

    final client = http.Client();
    http.Request createRequest(Uri url) {
      final req = http.Request('GET', url);
      if (total > 0) {
        req.headers['Range'] = 'bytes=$rangeStart-${rangeEnd > 0 ? rangeEnd - 1 : ""}';
      }
      req.headers['User-Agent'] = _userAgent;
      return req;
    }

    try {
      var response = await client.send(createRequest(streamInfo.url));

      // Se il token temporaneo di YouTube è scaduto (403), aggiorna lo stream info al volo
      if (response.statusCode == 403) {
        final fresh = await YouTubeService.instance.getPlayableStreamInfo(videoId);
        if (fresh != null) {
          streamInfo = fresh;
          response = await client.send(createRequest(streamInfo.url));
        }
      }

      final isWebm = streamInfo.container.name.toLowerCase() == 'webm';
      final contentType = isWebm ? 'audio/webm' : 'audio/mp4';

      return StreamAudioResponse(
        sourceLength: total > 0 ? total : null,
        contentLength: length > 0 ? length : response.contentLength,
        offset: rangeStart,
        stream: response.stream,
        contentType: contentType,
      );
    } catch (e) {
      client.close();
      print('Errore YouTubeAudioSource.request: $e');
      rethrow;
    }
  }
}
