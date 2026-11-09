import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_track.dart';

class YouTubeService {
  static final YouTubeService instance = YouTubeService._();
  YouTubeService._();

  YoutubeExplode? _yt;
  YoutubeExplode get yt => _yt ??= YoutubeExplode();

  /// Cerca video su YouTube e restituisce i risultati
  Future<List<YouTubeTrack>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final searchResults = await yt.search.search(query);
      final tracks = <YouTubeTrack>[];

      for (final item in searchResults) {
        tracks.add(YouTubeTrack(
          id: item.id.value,
          title: item.title,
          author: item.author,
          duration: item.duration ?? Duration.zero,
          thumbnailUrl: item.thumbnails.highResUrl,
          url: item.url,
        ));
      }
      return tracks;
    } catch (e) {
      _yt?.close();
      _yt = YoutubeExplode();
      rethrow;
    }
  }

  /// Recupera l'URL diretto dello stream audio ottimizzato per riproduzione immediata su iOS.
  /// Usa i client `ios` e `androidVr` per evitare le restrizioni antibot e i blocchi 403 di AVPlayer.
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      // 1. Prova prima con i client iOS e Android VR che producono flussi audio puliti senza cipher JS
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
        ],
      ).timeout(const Duration(seconds: 10));

      final audioStreams = manifest.audioOnly.toList();
      StreamInfo? chosen;

      if (audioStreams.isNotEmpty) {
        // Cerca prima stream MP4 / AAC (compatibili nativamente al 100% con iOS AVPlayer)
        final mp4Streams = audioStreams.where(
          (s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'),
        ).toList();

        chosen = mp4Streams.isNotEmpty
            ? mp4Streams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next)
            : audioStreams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      } else if (manifest.muxed.isNotEmpty) {
        chosen = manifest.muxed.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      }

      if (chosen != null) {
        return chosen.url.toString();
      }
    } catch (e) {
      print('getAudioStreamUrl primario fallito ($e), provo fallback standard...');
    }

    // 2. Fallback su getManifest standard
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isNotEmpty) {
        final mp4Streams = audioStreams.where(
          (s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'),
        ).toList();
        final chosen = mp4Streams.isNotEmpty
            ? mp4Streams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next)
            : audioStreams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
        return chosen.url.toString();
      } else if (manifest.muxed.isNotEmpty) {
        return manifest.muxed.withHighestBitrate().url.toString();
      }
    } catch (e) {
      print('getAudioStreamUrl fallback fallito: $e');
    }

    return null;
  }

  /// Controlla se il brano è già stato scaricato in precedenza nella cartella Music
  Future<File?> getLocalDownloadedFile(String trackId) async {
    try {
      final safeId = trackId.replaceAll('yt_', '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final docsDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docsDir.path}/Music');
      if (await musicDir.exists()) {
        final files = musicDir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.contains(safeId) && await f.length() > 50000) {
            return f;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Scarica il brano audio in background nella cartella Music per ascolto offline
  Future<File?> downloadAudioStream(
    String videoId,
    String title, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docsDir.path}/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final safeId = videoId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetFile = File('${musicDir.path}/${safeName}_$safeId.m4a');
      if (await targetFile.exists() && await targetFile.length() > 50000) {
        return targetFile;
      }

      final streamUrl = await getAudioStreamUrl(videoId);
      if (streamUrl == null) return null;

      final tempFile = File('${musicDir.path}/${safeName}_$safeId.m4a.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(streamUrl));
        request.headers['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
        request.headers['Referer'] = 'https://www.youtube.com/';

        final response = await client.send(request);
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        final sink = tempFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.flush();
        await sink.close();

        if (await tempFile.length() > 50000) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);
          return targetFile;
        } else {
          if (await tempFile.exists()) await tempFile.delete();
          return null;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Errore downloadAudioStream: $e');
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
