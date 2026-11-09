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
          thumbnailUrl: item.thumbnails.mediumResUrl,
          url: item.url,
        ));
      }
      return tracks;
    } catch (e) {
      // In caso di errore ricrea l'istanza
      _yt?.close();
      _yt = YoutubeExplode();
      rethrow;
    }
  }

  /// Recupera l'URL temporaneo dello stream audio (ottimizzato AAC/m4a per iOS AVPlayer)
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      // Su iOS, AVPlayer gestisce nativamente i formati audio m4a/mp4 AAC
      final mp4Streams = audioStreams.where(
        (s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4'),
      );

      final chosen = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : audioStreams.withHighestBitrate();

      return chosen.url.toString();
    } catch (e) {
      print('Errore recupero stream audio: $e');
      return null;
    }
  }

  /// Scarica lo stream audio direttamente sul dispositivo per ascolto offline
  Future<File?> downloadAudioStream(
    String videoId,
    String title, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      final mp4Streams = audioStreams.where(
        (s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4'),
      );
      final chosen = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : audioStreams.withHighestBitrate();

      final stream = yt.videos.streamsClient.get(chosen);
      final docsDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docsDir.path}/Music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final file = File('${musicDir.path}/$safeName.m4a');
      final sink = file.openWrite();

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

      return file;
    } catch (e) {
      print('Errore download stream audio: $e');
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
