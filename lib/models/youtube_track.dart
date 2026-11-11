import 'track.dart';

class YouTubeTrack {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String url;

  YouTubeTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.url,
  });

  Track toTrack({String? streamUrl}) {
    return Track(
      id: 'yt_$id',
      title: title,
      artist: author,
      album: 'YouTube',
      duration: duration,
      isOnline: true,
      streamUrl: streamUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
