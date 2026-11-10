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

  /// Recupera l'URL dello stream nativo HLS (.m3u8) per iOS se disponibile
  Future<String?> getHlsStreamUrl(String videoId) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.safari,
        ],
      ).timeout(const Duration(seconds: 7));

      if (manifest.hls.isNotEmpty) {
        final hls = manifest.hls.first;
        return hls.url.toString();
      }
    } catch (e) {
      print('getHlsStreamUrl info: $e');
    }
    return null;
  }

  /// Recupera lo StreamInfo riproducibile su iOS (privilegia AAC in MP4 o Muxed MP4)
  Future<StreamInfo?> getPlayableStreamInfo(String videoId) async {
    StreamManifest? manifest;

    // 1. Prova prima con client iOS e Safari (generano stream compatibili AAC/MP4 per AVPlayer)
    try {
      manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.safari,
          YoutubeApiClient.androidVr,
        ],
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      print('getManifest ytClients: $e');
    }

    // 2. Fallback su manifest standard
    if (manifest == null) {
      try {
        manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
      } catch (e) {
        print('getManifest standard: $e');
      }
    }

    if (manifest == null) return null;

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
      return mp4Audio.reduce((a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);
    }

    // 2. Se non c'è audio-only MP4, usa i flussi muxed MP4 (audio AAC nativo per iOS)
    final mp4Muxed = manifest.muxed.where((s) {
      final containerName = s.container.name.toLowerCase();
      return containerName == 'mp4' || containerName == 'm4a';
    }).toList();

    if (mp4Muxed.isNotEmpty) {
      return mp4Muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
    }

    // 3. Fallback: qualunque audio-only disponibile
    if (manifest.audioOnly.isNotEmpty) {
      return manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);
    }

    return null;
  }

  /// Recupera l'URL diretto dello stream audio (se disponibile)
  Future<String?> getAudioStreamUrl(String videoId) async {
    final info = await getPlayableStreamInfo(videoId);
    return info?.url.toString();
  }

  /// Cerca se la traccia è già disponibile nei download offline o nella cache locale
  Future<File?> getLocalAudioFile(String trackId) async {
    final safeId = trackId.replaceAll('yt_', '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // 1. Controlla nei download offline permanenti (cartella Music)
    try {
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

    // 2. Controlla nella cache temporanea di streaming
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/yt_cache');
      if (await cacheDir.exists()) {
        final files = cacheDir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.contains(safeId) && await f.length() > 50000) {
            return f;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Alias retrocompatibile
  Future<File?> getLocalDownloadedFile(String trackId) => getLocalAudioFile(trackId);

  /// Scarica il flusso audio AAC (.m4a) in cache temporanea via youtube_explode
  /// (senza 403 Forbidden di Apple AVPlayer)
  Future<File?> downloadToCache(
    String videoId,
    String title, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/yt_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final safeId = videoId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetFile = File('${cacheDir.path}/yt_$safeId.m4a');
      if (await targetFile.exists() && await targetFile.length() > 50000) {
        return targetFile;
      }

      final streamInfo = await getPlayableStreamInfo(videoId);
      if (streamInfo == null) return null;

      final tempFile = File('${cacheDir.path}/yt_$safeId.m4a.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = tempFile.openWrite();
      int receivedBytes = 0;
      final totalBytes = streamInfo.size.totalBytes;

      try {
        await for (final chunk in stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

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
    } catch (e) {
      print('Errore downloadToCache: $e');
      return null;
    }
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

      // Se il brano è già stato scaricato nella cache streaming, copialo istantaneamente!
      final cached = await getLocalAudioFile(videoId);
      if (cached != null && await cached.exists() && await cached.length() > 50000) {
        await cached.copy(targetFile.path);
        return targetFile;
      }

      final streamInfo = await getPlayableStreamInfo(videoId);
      if (streamInfo == null) return null;

      final tempFile = File('${musicDir.path}/${safeName}_$safeId.m4a.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = tempFile.openWrite();
      int receivedBytes = 0;
      final totalBytes = streamInfo.size.totalBytes;

      try {
        await for (final chunk in stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

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
