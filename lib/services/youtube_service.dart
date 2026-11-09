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

  /// Recupera l'URL diretto dello stream audio ottimizzato per riproduzione su iOS (AAC/MP4).
  Future<String?> getAudioStreamUrl(String videoId) async {
    // 1. Prova prima il manifest standard
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
      final url = _extractPlayableUrl(manifest);
      if (url != null) return url;
    } catch (e) {
      print('getManifest standard: $e');
    }

    // 2. Fallback su client Android VR e iOS
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.androidVr,
          YoutubeApiClient.ios,
        ],
      ).timeout(const Duration(seconds: 8));
      final url = _extractPlayableUrl(manifest);
      if (url != null) return url;
    } catch (e) {
      print('getManifest ytClients: $e');
    }

    return null;
  }

  /// Seleziona un URL compatibile nativamente con il decoder AVPlayer di iOS (MP4/AAC).
  String? _extractPlayableUrl(StreamManifest manifest) {
    // 1. Cerca nei flussi audio-only uno stream MP4 / AAC (itag 140 m4a)
    final mp4Audio = manifest.audioOnly.where((s) {
      final containerName = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      return containerName == 'mp4' ||
             containerName == 'm4a' ||
             codec.contains('mp4a') ||
             codec.contains('aac');
    }).toList();

    if (mp4Audio.isNotEmpty) {
      final chosen = mp4Audio.reduce((a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);
      return chosen.url.toString();
    }

    // 2. Se non c'è audio-only MP4 (YouTube offre solo Opus/WebM in audioOnly),
    // usa i flussi muxed MP4: hanno sempre traccia audio AAC decodificabile nativamente da iOS AVPlayer.
    final mp4Muxed = manifest.muxed.where((s) {
      final containerName = s.container.name.toLowerCase();
      return containerName == 'mp4' || containerName == 'm4a';
    }).toList();

    if (mp4Muxed.isNotEmpty) {
      // Scegli lo stream muxed a risoluzione più leggera (es. 360p) per avvio istantaneo con minimo consumo dati
      final chosen = mp4Muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
      return chosen.url.toString();
    }

    // 3. Fallback su HLS m3u8 se disponibile (nativo iOS)
    if (manifest.hls.isNotEmpty) {
      return manifest.hls.first.url.toString();
    }

    // 4. Fallback estremo su qualsiasi audio disponibile
    if (manifest.audioOnly.isNotEmpty) {
      return manifest.audioOnly.withHighestBitrate().url.toString();
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

        final response = await client.send(request).timeout(const Duration(seconds: 15));
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
