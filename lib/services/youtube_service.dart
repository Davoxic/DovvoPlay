import 'dart:io';
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

  /// Recupera il file audio dalla cache o lo scarica via stream in background.
  /// Risolve il problema del 403 Forbidden di AVPlayer su iOS durante lo streaming diretto.
  Future<File?> getCachedOrDownloadAudioStream(
    String videoId,
    String title, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final safeId = videoId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 1. Controlla prima se è già salvato nella cartella permanente Music
      final docsDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docsDir.path}/Music');
      if (await musicDir.exists()) {
        final existingFiles = musicDir.listSync().whereType<File>();
        for (final f in existingFiles) {
          if (f.path.contains(safeId) && await f.length() > 50000) {
            return f;
          }
        }
      }

      // 2. Controlla nella cache temporanea dell'app
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/yt_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/$safeId.m4a');
      if (await cacheFile.exists() && await cacheFile.length() > 50000) {
        return cacheFile;
      }

      // 3. Ottieni il manifest dei flussi audio
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();

      StreamInfo? chosen;
      if (audioStreams.isNotEmpty) {
        final mp4Streams = audioStreams.where(
          (s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'),
        ).toList();
        chosen = mp4Streams.isNotEmpty
            ? mp4Streams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next)
            : audioStreams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      } else if (manifest.muxed.isNotEmpty) {
        chosen = manifest.muxed.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      }

      if (chosen == null) return null;

      // 4. Scarica prima in un file temporaneo .tmp
      final tempFile = File('${cacheDir.path}/$safeId.m4a.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final stream = yt.videos.streamsClient.get(chosen);
      final sink = tempFile.openWrite();

      int downloaded = 0;
      final total = chosen.size.totalBytes;

      await for (final chunk in stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(downloaded / total);
        }
      }
      await sink.flush();
      await sink.close();

      // Verifica che il download sia valido (> 50KB)
      if (await tempFile.length() > 50000) {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        await tempFile.rename(cacheFile.path);
        return cacheFile;
      } else {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return null;
      }
    } catch (e) {
      print('Errore getCachedOrDownloadAudioStream: $e');
      return null;
    }
  }

  /// Scarica permanentemente nella cartella Music per ascolto offline
  Future<File?> downloadAudioStream(
    String videoId,
    String title, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final safeId = videoId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final docsDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docsDir.path}/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final file = File('${musicDir.path}/${safeName}_$safeId.m4a');
      if (await file.exists() && await file.length() > 50000) {
        return file;
      }

      // Se il brano è già stato caricato nella cache temporanea durante lo streaming, copialo istantaneamente!
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/yt_cache/$safeId.m4a');
      if (await cacheFile.exists() && await cacheFile.length() > 50000) {
        await cacheFile.copy(file.path);
        return file;
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();
      StreamInfo? chosen;
      if (audioStreams.isNotEmpty) {
        final mp4Streams = audioStreams.where(
          (s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'),
        ).toList();
        chosen = mp4Streams.isNotEmpty
            ? mp4Streams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next)
            : audioStreams.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      } else if (manifest.muxed.isNotEmpty) {
        chosen = manifest.muxed.reduce((curr, next) => curr.bitrate.bitsPerSecond > next.bitrate.bitsPerSecond ? curr : next);
      }

      if (chosen == null) return null;

      final tempFile = File('${musicDir.path}/${safeName}_$safeId.m4a.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final stream = yt.videos.streamsClient.get(chosen);
      final sink = tempFile.openWrite();

      int downloaded = 0;
      final total = chosen.size.totalBytes;

      await for (final chunk in stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(downloaded / total);
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.length() > 50000) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        return file;
      } else {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return null;
      }
    } catch (e) {
      print('Errore downloadAudioStream: $e');
      return null;
    }
  }

  /// Fallback URL (usato solo se richiesto esplicitamente)
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isEmpty) return null;
      final mp4Streams = audioStreams.where(
        (s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'),
      ).toList();
      final chosen = mp4Streams.isNotEmpty
          ? mp4Streams.reduce((a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b)
          : audioStreams.reduce((a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);
      return chosen.url.toString();
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
