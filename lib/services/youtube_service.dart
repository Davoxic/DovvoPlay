import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_track.dart';
import 'cache_service.dart';
import 'playback_settings.dart';

class YouTubeService {
  static final YouTubeService instance = YouTubeService._();
  YouTubeService._();

  YoutubeExplode? _yt;
  YoutubeExplode get yt => _yt ??= YoutubeExplode();

  /// Cerca video su YouTube e restituisce i risultati in modo resiliente
  Future<List<YouTubeTrack>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Se l'utente ha inserito un link diretto a un video di YouTube
      if (cleanQuery.contains('youtube.com/watch') || cleanQuery.contains('youtu.be/')) {
        try {
          final video = await yt.videos.get(cleanQuery).timeout(const Duration(seconds: 8));
          return [
            YouTubeTrack(
              id: video.id.value,
              title: video.title,
              author: video.author,
              duration: video.duration ?? Duration.zero,
              thumbnailUrl: video.thumbnails.highResUrl,
              url: video.url,
            )
          ];
        } catch (_) {}
      }

      // 2. Ricerca standard con timeout protetto
      final searchResults = await yt.search.search(cleanQuery).timeout(const Duration(seconds: 12));
      final tracks = <YouTubeTrack>[];

      for (final item in searchResults) {
        try {
          final id = item.id.value;
          if (id.isEmpty) continue;

          String thumb = '';
          try {
            thumb = item.thumbnails.highResUrl;
          } catch (_) {
            try {
              thumb = item.thumbnails.standardResUrl;
            } catch (_) {
              thumb = 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
            }
          }

          tracks.add(YouTubeTrack(
            id: id,
            title: item.title.isNotEmpty ? item.title : 'Video YouTube',
            author: item.author.isNotEmpty ? item.author : 'YouTube',
            duration: item.duration ?? Duration.zero,
            thumbnailUrl: thumb,
            url: item.url,
          ));
        } catch (itemErr) {
          // Ignora singolo elemento difettoso (es. canali, live streams) e mantieni gli altri
          print('Errore parsing elemento ricerca: $itemErr');
        }
      }
      return tracks;
    } catch (e) {
      print('Errore YouTubeService.search: $e');
      _yt?.close();
      _yt = YoutubeExplode();
      rethrow;
    }
  }

  /// Motivo dell'ultimo fallimento, da mostrare all'utente.
  String? lastFailureReason;

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

  /// Recupera lo StreamInfo rigorosamente compatibile con iOS (AAC in container MP4/M4A)
  /// CRITICO: Non restituisce MAI flussi WebM/Opus per la riproduzione diretta perché AVPlayer su iOS non li decodifica.
  Future<StreamInfo?> getPlayableStreamInfo(
    String videoId, {
    bool forDownload = false,
  }) async {
    lastFailureReason = null;
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

    // 2. Se fallisce, prova il manifest standard
    if (manifest == null) {
      try {
        manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 8));
      } catch (e) {
        print('getManifest standard: $e');
      }
    }

    if (manifest == null) {
      lastFailureReason =
          'YouTube non ha restituito i formati del video. Potrebbe essere un blocco '
          'temporaneo o un video non disponibile.';
      return null;
    }

    // 1. Cerca PRIMA nei flussi audio-only uno stream MP4 / AAC (itag 140 m4a 128kbps)
    final mp4Audio = manifest.audioOnly.where((s) {
      final containerName = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      final mime = s.codec.mimeType.toLowerCase();
      final isMp4Container = containerName == 'mp4' || containerName == 'm4a';
      final isAacCodec = codec.contains('mp4a') || codec.contains('aac') || mime.contains('mp4a');
      final isWebm = containerName.contains('webm') || codec.contains('opus') || mime.contains('opus');
      return isMp4Container && isAacCodec && !isWebm;
    }).toList();

    if (mp4Audio.isNotEmpty) {
      // Con il risparmio dati lo streaming prende il flusso piu' leggero;
      // i download restano sempre alla qualita' piu' alta disponibile.
      final leggero = !forDownload && PlaybackSettings.instance.dataSaver;
      return mp4Audio.reduce((a, b) {
        final aPiuAlto = a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond;
        if (leggero) return aPiuAlto ? b : a;
        return aPiuAlto ? a : b;
      });
    }

    // 2. Se non c'è audio-only MP4 puro, usa i flussi muxed MP4 (audio AAC nativo hardware per iOS)
    final mp4Muxed = manifest.muxed.where((s) {
      final containerName = s.container.name.toLowerCase();
      final codec = s.audioCodec.toLowerCase();
      final isMp4Container = containerName == 'mp4' || containerName == 'm4a';
      final isNotWebm = !codec.contains('opus');
      return isMp4Container && isNotWebm;
    }).toList();

    if (mp4Muxed.isNotEmpty) {
      // Prendi il muxed più leggero per risparmiare banda e bufferizzare istantaneamente
      return mp4Muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
    }

    // 3. Fallback: qualsiasi audio-only disponibile (per download / conversione)
    if (forDownload && manifest.audioOnly.isNotEmpty) {
      return manifest.audioOnly.withHighestBitrate();
    }

    final soloOpus = manifest.audioOnly.isNotEmpty || manifest.muxed.isNotEmpty;
    lastFailureReason = soloOpus
        ? 'Questo video e\' disponibile solo in formato Opus, che iOS non '
            'riproduce direttamente. Scaricalo delegando al PC per convertirlo in MP3.'
        : 'Nessun flusso audio disponibile per questo video.';
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
        // Tiene la cache sotto il limite scelto, senza toccare questo file.
        CacheService.instance.enforceLimit(tieni: safeId);
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

  /// Avvia il download in cache in background senza bloccare la riproduzione
  Future<void> cacheInBackground(String videoId, String title) async {
    try {
      await downloadToCache(videoId, title);
    } catch (e) {
      print('Errore cacheInBackground: $e');
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

      final streamInfo = await getPlayableStreamInfo(videoId, forDownload: true);
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
