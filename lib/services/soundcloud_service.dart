import 'dart:convert';
import 'package:http/http.dart' as http;

class SoundCloudTrack {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String url;
  final Duration duration;

  const SoundCloudTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.url,
    this.duration = Duration.zero,
  });
}

class SoundCloudService {
  static final SoundCloudService instance = SoundCloudService._();
  SoundCloudService._();

  /// Cerca su SoundCloud tramite endpoint pubblico oEmbed e scraping sicuro
  Future<List<SoundCloudTrack>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Se l'utente incolla un link diretto SoundCloud
      if (cleanQuery.contains('soundcloud.com/')) {
        final oembedUri = Uri.parse('https://soundcloud.com/oembed?url=${Uri.encodeComponent(cleanQuery)}&format=json');
        final res = await http.get(oembedUri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return [
            SoundCloudTrack(
              id: cleanQuery,
              title: data['title']?.toString() ?? 'SoundCloud Track',
              author: data['author_name']?.toString() ?? 'SoundCloud',
              thumbnailUrl: data['thumbnail_url']?.toString() ?? '',
              url: cleanQuery,
            )
          ];
        }
      }

      // 2. Ricerca standard web API (fallback resilient)
      final uri = Uri.parse('https://api-widget.soundcloud.com/search/queries?q=${Uri.encodeComponent(cleanQuery)}&client_id=LBCcHmRb8hHbd612gBtMc3usBi2DitLl&limit=15');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['collection'] as List? ?? [];
        return list.map((item) {
          final title = item['output']?.toString() ?? cleanQuery;
          return SoundCloudTrack(
            id: 'sc_${item['query']}',
            title: title,
            author: 'SoundCloud Creator',
            thumbnailUrl: 'https://a-v2.sndcdn.com/assets/images/sc-icons/ios-a62dfc8f.png',
            url: 'https://soundcloud.com/search?q=${Uri.encodeComponent(title)}',
          );
        }).toList();
      }
    } catch (e) {
      print('Errore SoundCloud search: $e');
    }
    return [];
  }
}
