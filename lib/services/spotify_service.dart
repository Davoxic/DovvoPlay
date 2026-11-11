import 'dart:convert';
import 'package:http/http.dart' as http;

class SpotifyItem {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String url;
  final Duration duration;

  const SpotifyItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.url,
    this.duration = Duration.zero,
  });
}

class SpotifyPlaylistInfo {
  final String title;
  final String author;
  final String thumbnailUrl;
  final List<SpotifyItem> tracks;

  const SpotifyPlaylistInfo({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.tracks,
  });
}

class SpotifyService {
  static final SpotifyService instance = SpotifyService._();
  SpotifyService._();

  /// Estrae metadati da qualsiasi link Spotify (Brano, Album, Playlist)
  Future<SpotifyItem?> getTrackInfoFromUrl(String url) async {
    try {
      final cleanUrl = url.trim();
      final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(cleanUrl)}');
      final res = await http.get(oembedUri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fullTitle = data['title']?.toString() ?? 'Spotify Track';
        final thumb = data['thumbnail_url']?.toString() ?? '';
        final author = data['author_name']?.toString() ?? 'Spotify';

        // Spesso il titolo oEmbed è "Nome Canzone" oppure "Nome Canzone - Artista"
        String title = fullTitle;
        String artist = author;
        if (fullTitle.contains(' - ')) {
          final parts = fullTitle.split(' - ');
          title = parts[0].trim();
          artist = parts.sublist(1).join(' - ').trim();
        }

        return SpotifyItem(
          id: cleanUrl,
          title: title,
          artist: artist,
          thumbnailUrl: thumb,
          url: cleanUrl,
        );
      }
    } catch (e) {
      print('Errore getTrackInfoFromUrl: $e');
    }
    return null;
  }

  /// Analizza una playlist Spotify tramite oEmbed ed estrazione web
  Future<SpotifyPlaylistInfo?> parseSpotifyPlaylist(String playlistUrl) async {
    try {
      final cleanUrl = playlistUrl.trim();
      final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(cleanUrl)}');
      final res = await http.get(oembedUri).timeout(const Duration(seconds: 8));

      String plTitle = 'Playlist Spotify';
      String plAuthor = 'Spotify User';
      String plThumb = '';

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        plTitle = data['title']?.toString() ?? 'Playlist Spotify';
        plAuthor = data['author_name']?.toString() ?? 'Spotify';
        plThumb = data['thumbnail_url']?.toString() ?? '';
      }

      // Scarica la pagina pubblica della playlist o embed per estrarre la lista brani
      final tracks = <SpotifyItem>[];
      final embedUrl = cleanUrl.replaceFirst('open.spotify.com/playlist/', 'open.spotify.com/embed/playlist/');
      final embedRes = await http.get(Uri.parse(embedUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15'
      }).timeout(const Duration(seconds: 10));

      if (embedRes.statusCode == 200) {
        final html = embedRes.body;
        // Cerca i dati JSON incorporati in __NEXT_DATA__ o nei tag script
        final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>').firstMatch(html);
        if (nextDataMatch != null) {
          final jsonStr = nextDataMatch.group(1);
          if (jsonStr != null) {
            final nextData = jsonDecode(jsonStr);
            final rawTracks = nextData['props']?['pageProps']?['state']?['data']?['entity']?['trackList'] ?? [];
            if (rawTracks is List) {
              for (final t in rawTracks) {
                final title = t['title']?.toString() ?? '';
                final subtitle = t['subtitle']?.toString() ?? '';
                if (title.isNotEmpty) {
                  tracks.add(SpotifyItem(
                    id: t['uri']?.toString() ?? '$title-$subtitle',
                    title: title,
                    artist: subtitle.isNotEmpty ? subtitle : plAuthor,
                    thumbnailUrl: plThumb,
                    url: cleanUrl,
                  ));
                }
              }
            }
          }
        }
      }

      // Se non ci sono brani dall'embed o è un link singolo, aggiungi almeno il brano estratto
      if (tracks.isEmpty) {
        final single = await getTrackInfoFromUrl(cleanUrl);
        if (single != null) {
          tracks.add(single);
        }
      }

      return SpotifyPlaylistInfo(
        title: plTitle,
        author: plAuthor,
        thumbnailUrl: plThumb,
        tracks: tracks,
      );
    } catch (e) {
      print('Errore parseSpotifyPlaylist: $e');
      return null;
    }
  }

  /// Cerca brani su Spotify via web search
  Future<List<SpotifyItem>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // Se è un link diretto Spotify
      if (cleanQuery.contains('open.spotify.com/')) {
        final item = await getTrackInfoFromUrl(cleanQuery);
        if (item != null) return [item];
      }

      // Ricerca rapida web metadata
      final searchUri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(cleanQuery)}&media=music&entity=song&limit=15');
      final res = await http.get(searchUri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        return results.map((r) {
          final title = r['trackName']?.toString() ?? 'Brano';
          final artist = r['artistName']?.toString() ?? 'Artista';
          final thumb = r['artworkUrl100']?.toString().replaceAll('100x100', '600x600') ?? '';
          final durMillis = r['trackTimeMillis'] as int? ?? 0;
          return SpotifyItem(
            id: 'sp_${r['trackId']}',
            title: title,
            artist: artist,
            thumbnailUrl: thumb,
            url: r['trackViewUrl']?.toString() ?? '',
            duration: Duration(milliseconds: durMillis),
          );
        }).toList();
      }
    } catch (e) {
      print('Errore ricerca Spotify: $e');
    }
    return [];
  }
}
