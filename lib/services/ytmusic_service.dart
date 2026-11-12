import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

enum YtmKind { song, album, artist, playlist, mood }

/// Un elemento del catalogo di YouTube Music: brano, album, artista,
/// playlist oppure una categoria "mood e generi".
class YtmItem {
  final YtmKind kind;

  /// videoId per i brani, browseId per tutto il resto.
  final String id;
  final String title;
  final String subtitle;
  final String artist;
  final String album;
  final Duration duration;
  final String thumbnailUrl;

  /// Parametro opaco che accompagna il browseId delle categorie.
  final String params;

  /// Colore della categoria, 0 se assente.
  final int color;

  const YtmItem({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.thumbnailUrl = '',
    this.params = '',
    this.color = 0,
  });

  bool get isSong => kind == YtmKind.song;

  YtmItem copyWith({String? artist, String? album, String? thumbnailUrl}) {
    return YtmItem(
      kind: kind,
      id: id,
      title: title,
      subtitle: subtitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      params: params,
      color: color,
    );
  }

  /// Il brano nella forma che il player sa riprodurre.
  Track toTrack() {
    return Track(
      id: 'yt_$id',
      title: title,
      artist: artist,
      album: album.isNotEmpty ? album : 'YouTube Music',
      duration: duration,
      isOnline: true,
      thumbnailUrl: thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
    );
  }
}

/// Una fila di elementi con il suo titolo ("Nuove uscite", "Album"...).
class YtmShelf {
  final String title;
  final List<YtmItem> items;
  const YtmShelf({required this.title, required this.items});

  bool get onlySongs => items.isNotEmpty && items.every((i) => i.isSong);
  bool get onlyMoods =>
      items.isNotEmpty && items.every((i) => i.kind == YtmKind.mood);
}

/// Una pagina: intestazione piu' le sue file.
class YtmPage {
  final String title;
  final String subtitle;
  final String artist;
  final String thumbnailUrl;
  final String description;
  final List<YtmShelf> shelves;

  const YtmPage({
    required this.title,
    required this.subtitle,
    required this.artist,
    required this.thumbnailUrl,
    required this.description,
    required this.shelves,
  });
}

/// Catalogo di YouTube Music: ricerca, home, classifiche, mood e generi,
/// pagine di album, artisti e playlist, radio di un brano.
///
/// Usa l'API pubblica del sito, la stessa che carica music.youtube.com senza
/// accesso: nessun account e nessuna chiave. Le risposte sono alberi JSON
/// molto profondi e YouTube ne ritocca spesso la forma; per questo qui non si
/// seguono percorsi fissi ma si cercano i blocchi per nome, ovunque stiano.
class YtMusicService {
  static final YtMusicService instance = YtMusicService._();
  YtMusicService._();

  static const String _base = 'https://music.youtube.com/youtubei/v1/';
  static const String _clientVersion = '1.20250310.01.00';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  // Filtri della ricerca.
  static const String filterSongs = 'EgWKAQIIAWoMEA4QChADEAQQCRAF';
  static const String filterVideos = 'EgWKAQIQAWoMEA4QChADEAQQCRAF';
  static const String filterAlbums = 'EgWKAQIYAWoMEA4QChADEAQQCRAF';
  static const String filterArtists = 'EgWKAQIgAWoMEA4QChADEAQQCRAF';
  static const String filterPlaylists = 'EgeKAQQoAEABagwQDhAKEAMQBBAJEAU%3D';

  // Pagine fisse.
  static const String browseHome = 'FEmusic_home';
  static const String browseExplore = 'FEmusic_explore';
  static const String browseCharts = 'FEmusic_charts';
  static const String browseMoods = 'FEmusic_moods_and_genres';
  static const String browseNewReleases = 'FEmusic_new_releases_albums';

  Future<dynamic> _post(String endpoint, Map<String, dynamic> corpo) async {
    final payload = <String, dynamic>{
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': _clientVersion,
          'hl': 'it',
          'gl': 'IT',
        },
      },
    };
    payload.addAll(corpo);

    final risposta = await http
        .post(
          Uri.parse('$_base$endpoint?prettyPrint=false'),
          headers: const {
            'Content-Type': 'application/json',
            'User-Agent': _userAgent,
            'Origin': 'https://music.youtube.com',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (risposta.statusCode != 200) {
      throw Exception('YouTube Music ha risposto ${risposta.statusCode}');
    }
    return jsonDecode(utf8.decode(risposta.bodyBytes));
  }

  // ---------------------------------------------------------------- ricerca

  /// Cerca nel catalogo. Senza [filter] restituisce risultati misti.
  Future<List<YtmItem>> search(String query, {String? filter}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final corpo = <String, dynamic>{'query': q};
    if (filter != null && filter.isNotEmpty) corpo['params'] = filter;
    final json = await _post('search', corpo);
    final grezzi = <YtmItem>[];
    _raccogliElementi(json, grezzi);
    return _senzaDoppioni(grezzi);
  }

  /// Completamenti mentre si scrive.
  Future<List<String>> suggestions(String input) async {
    final q = input.trim();
    if (q.isEmpty) return [];
    final json = await _post('music/get_search_suggestions', {'input': q});
    final out = <String>[];
    _raccogliSuggerimenti(json, out);
    return out;
  }

  // ---------------------------------------------------------------- pagine

  Future<List<YtmShelf>> shelvesOf(String browseId) async {
    final json = await _post('browse', {'browseId': browseId});
    final file = <YtmShelf>[];
    _raccogliFile(json, file);
    return file;
  }

  /// Carica una pagina: album, playlist, artista, classifiche, categoria.
  Future<YtmPage> browse(
    String browseId, {
    String params = '',
    int maxPagineExtra = 4,
  }) async {
    final corpo = <String, dynamic>{'browseId': browseId};
    if (params.isNotEmpty) corpo['params'] = params;
    final json = await _post('browse', corpo);

    final file = <YtmShelf>[];
    _raccogliFile(json, file);
    final testa = _leggiIntestazione(json);

    // Le playlist arrivano a blocchi di cento: si seguono i rimandi.
    final scaffale = _trovaPrimo(json, 'musicPlaylistShelfRenderer');
    if (scaffale != null && file.isNotEmpty) {
      var token = _tokenSeguito(scaffale);
      var pagine = 0;
      final altri = <YtmItem>[];
      while (token.isNotEmpty && pagine < maxPagineExtra) {
        pagine++;
        try {
          final seguito = await _post('browse', {'continuation': token});
          final blocco = <YtmItem>[];
          _raccogliElementi(seguito, blocco);
          if (blocco.isEmpty) break;
          altri.addAll(blocco);
          final prossimo = _tokenSeguito(seguito);
          if (prossimo == token) break;
          token = prossimo;
        } catch (_) {
          break;
        }
      }
      if (altri.isNotEmpty) {
        final i = file.indexWhere((s) => s.items.isNotEmpty && s.items.first.isSong);
        if (i != -1) {
          file[i] = YtmShelf(
            title: file[i].title,
            items: _senzaDoppioni([...file[i].items, ...altri]),
          );
        }
      }
    }

    // Le tracce di un album non ripetono copertina, album e artista: li
    // si prende dall'intestazione.
    if (browseId.startsWith('MPRE') && file.isNotEmpty && file.first.onlySongs) {
      final completi = file.first.items.map((it) {
        return it.copyWith(
          thumbnailUrl: it.thumbnailUrl.isEmpty ? testa.thumb : null,
          album: it.album.isEmpty ? testa.title : null,
          artist: it.artist.isEmpty ? testa.artist : null,
        );
      }).toList();
      file[0] = YtmShelf(title: file.first.title, items: completi);
    }

    return YtmPage(
      title: testa.title,
      subtitle: testa.subtitle,
      artist: testa.artist,
      thumbnailUrl: testa.thumb,
      description: testa.description,
      shelves: file,
    );
  }

  // ------------------------------------------------------------------ radio

  /// Brani simili a un video, nell'ordine proposto da YouTube Music.
  Future<List<Track>> radio(String videoId) async {
    final json = await _post('next', {
      'videoId': videoId,
      'playlistId': 'RDAMVM$videoId',
      'isAudioOnly': true,
      'enablePersistentPlaylistPanel': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
    });
    final grezzi = <YtmItem>[];
    _raccogliElementi(_trovaPrimo(json, 'playlistPanelRenderer'), grezzi);
    return _senzaDoppioni(grezzi)
        .where((i) => i.isSong)
        .map((i) => i.toTrack())
        .toList();
  }

  static final RegExp _idNelNome = RegExp(r'_([A-Za-z0-9_-]{11})\.[A-Za-z0-9]+$');

  /// Il videoId di un brano, se ricavabile senza rete.
  ///
  /// I download fatti dall'app si chiamano "Titolo_<videoId>.m4a": per quelli
  /// non serve cercare nulla.
  static String? localVideoId(Track track) {
    if (track.id.startsWith('yt_')) return track.id.substring(3);
    final percorso = track.filePath ?? track.id;
    final m = _idNelNome.firstMatch(percorso);
    return m?.group(1);
  }

  /// Trova su YouTube Music il brano che corrisponde a titolo e artista.
  Future<String?> findVideoId(String titolo, String artista) async {
    final q = artista.trim().isEmpty ? titolo : '$artista $titolo';
    final trovati = await search(q, filter: filterSongs);
    for (final it in trovati) {
      if (it.isSong) return it.id;
    }
    return null;
  }

  /// Brani simili a [seed], che sia online o un file locale.
  Future<List<Track>> radioFor(Track seed) async {
    final online = seed.id.startsWith('yt_');

    // Prima l'id ricavato dal brano stesso. Per un file locale e' solo
    // un'ipotesi letta dal nome: se non porta a nulla si passa alla ricerca.
    final diretto = localVideoId(seed);
    if (diretto != null && diretto.isNotEmpty) {
      try {
        final lista = await radio(diretto);
        if (lista.isNotEmpty || online) {
          final idSeme = 'yt_$diretto';
          return lista.where((t) => t.id != idSeme).toList();
        }
      } catch (_) {
        if (online) rethrow;
      }
    }

    final artista = seed.artist == 'Artista sconosciuto' ? '' : seed.artist;
    final trovato = await findVideoId(seed.title, artista);
    if (trovato == null || trovato.isEmpty) return [];
    final idTrovato = 'yt_$trovato';
    final lista = await radio(trovato);
    return lista.where((t) => t.id != idTrovato).toList();
  }
}

// ===================================================================
// Lettura delle risposte. Funzioni libere: non hanno stato.
// ===================================================================

class _Intestazione {
  final String title;
  final String subtitle;
  final String artist;
  final String thumb;
  final String description;
  const _Intestazione({
    this.title = '',
    this.subtitle = '',
    this.artist = '',
    this.thumb = '',
    this.description = '',
  });
}

/// Parole che nei sottotitoli indicano il tipo di elemento, non un nome.
const Set<String> _paroleTipo = {
  'Brano',
  'Song',
  'Video',
  'Episodio',
  'Episode',
  'Puntata',
  'Singolo',
  'Single',
  'Album',
  'EP',
  'Playlist',
  'Artista',
  'Artist',
  'Profilo',
  'Profile',
  'Podcast',
};

const Set<String> _chiaviFila = {
  'musicCarouselShelfRenderer',
  'musicShelfRenderer',
  'musicPlaylistShelfRenderer',
  'gridRenderer',
  'musicCardShelfRenderer',
  'playlistPanelRenderer',
};

String _s(dynamic v) => v is String ? v : '';

List _l(dynamic v) => v is List ? v : const [];

dynamic _percorso(dynamic nodo, List<String> chiavi) {
  dynamic cur = nodo;
  for (final k in chiavi) {
    if (cur is Map) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

/// Il primo valore non nullo associato a [chiave], cercando in profondita'.
dynamic _trovaPrimo(dynamic nodo, String chiave) {
  if (nodo is List) {
    for (final x in nodo) {
      final r = _trovaPrimo(x, chiave);
      if (r != null) return r;
    }
    return null;
  }
  if (nodo is Map) {
    final diretto = nodo[chiave];
    if (diretto != null) return diretto;
    for (final v in nodo.values) {
      final r = _trovaPrimo(v, chiave);
      if (r != null) return r;
    }
  }
  return null;
}

String _unisciRuns(List runs) {
  final sb = StringBuffer();
  for (final r in runs) {
    if (r is Map) sb.write(_s(r['text']));
  }
  return sb.toString();
}

String _testoRuns(dynamic nodo) {
  if (nodo is! Map) return '';
  final runs = nodo['runs'];
  if (runs is List) return _unisciRuns(runs);
  return _s(nodo['simpleText']);
}

final RegExp _formaDurata = RegExp(r'^(\d+:)?\d{1,2}:\d{2}$');

int _secondi(String testo) {
  final t = testo.trim();
  if (!_formaDurata.hasMatch(t)) return 0;
  var totale = 0;
  for (final p in t.split(':')) {
    totale = totale * 60 + (int.tryParse(p) ?? 0);
  }
  return totale;
}

final RegExp _misuraWH = RegExp(r'=w(\d+)-h(\d+)');
final RegExp _misuraS = RegExp(r'=s(\d+)');

/// Le copertine arrivano in miniatura: per quelle servite da Google si
/// chiede la stessa immagine piu' grande cambiando la misura nell'indirizzo.
String _ingrandisci(String indirizzo) {
  var url = indirizzo;
  if (url.isEmpty) return url;
  if (url.startsWith('//')) url = 'https:$url';
  if (!url.contains('googleusercontent.com') && !url.contains('ggpht.com')) {
    return url;
  }
  final wh = _misuraWH.firstMatch(url);
  if (wh != null) {
    final w = int.tryParse(wh.group(1) ?? '') ?? 0;
    final h = int.tryParse(wh.group(2) ?? '') ?? 0;
    if (w > 0 && w == h && w < 544) {
      return url.replaceFirst(_misuraWH, '=w544-h544');
    }
    return url;
  }
  final s = _misuraS.firstMatch(url);
  if (s != null) {
    final v = int.tryParse(s.group(1) ?? '') ?? 0;
    if (v > 0 && v < 544) return url.replaceFirst(_misuraS, '=s544');
  }
  return url;
}

String _miglioreCopertina(dynamic nodo) {
  final lista = _trovaPrimo(nodo, 'thumbnails');
  if (lista is! List || lista.isEmpty) return '';
  Map? scelta;
  var larghezza = -1;
  for (final x in lista) {
    if (x is! Map) continue;
    final w = x['width'];
    final wi = w is num ? w.toInt() : 0;
    if (wi >= larghezza) {
      larghezza = wi;
      scelta = x;
    }
  }
  if (scelta == null) return '';
  return _ingrandisci(_s(scelta['url']));
}

String _tipoPagina(dynamic browseEndpoint) => _s(_percorso(browseEndpoint, [
      'browseEndpointContextSupportedConfigs',
      'browseEndpointContextMusicConfig',
      'pageType',
    ]));

YtmKind? _tipoDi(String tipoPagina, String browseId) {
  if (tipoPagina.contains('ALBUM') || tipoPagina.contains('AUDIOBOOK')) {
    return YtmKind.album;
  }
  if (tipoPagina.contains('ARTIST')) return YtmKind.artist;
  if (tipoPagina.contains('PLAYLIST')) return YtmKind.playlist;
  // Canali utente, podcast e simili: pagine che qui non si sanno mostrare.
  if (tipoPagina.isNotEmpty) return null;
  if (browseId.startsWith('MPRE')) return YtmKind.album;
  if (browseId.startsWith('VL') ||
      browseId.startsWith('PL') ||
      browseId.startsWith('RD')) {
    return YtmKind.playlist;
  }
  if (browseId.startsWith('UC')) return YtmKind.artist;
  return null;
}

/// Il primo pezzo di un sottotitolo che sia un nome e non un tipo o una durata.
String _primoNome(String sottotitolo) {
  for (final parte in sottotitolo.split(' • ')) {
    final p = parte.trim();
    if (p.isEmpty) continue;
    if (_paroleTipo.contains(p)) continue;
    if (_secondi(p) > 0) continue;
    return p;
  }
  return '';
}

/// Riga di un elenco: risultati di ricerca, tracce di album e playlist.
YtmItem? _leggiRiga(dynamic r) {
  if (r is! Map) return null;

  final colonne = _l(r['flexColumns']);
  final runsColonne = <List>[];
  for (final c in colonne) {
    runsColonne.add(_l(_percorso(
      c,
      ['musicResponsiveListItemFlexColumnRenderer', 'text', 'runs'],
    )));
  }
  if (runsColonne.isEmpty) return null;

  final titolo = _unisciRuns(runsColonne[0]);
  if (titolo.isEmpty) return null;

  final runsSotto = <dynamic>[];
  for (var i = 1; i < runsColonne.length; i++) {
    if (runsSotto.isNotEmpty && runsColonne[i].isNotEmpty) {
      runsSotto.add(const <String, dynamic>{'text': ' • '});
    }
    runsSotto.addAll(runsColonne[i]);
  }
  final sottotitolo = _unisciRuns(runsSotto);

  // Le puntate dei podcast hanno un videoId ma non sono musica.
  if (_s(_trovaPrimo(r, 'musicVideoType')).contains('PODCAST')) return null;

  var videoId = _s(_percorso(r, ['playlistItemData', 'videoId']));
  if (videoId.isEmpty) {
    dynamic we = _trovaPrimo(r['overlay'], 'watchEndpoint');
    if (we == null && colonne.isNotEmpty) {
      we = _trovaPrimo(colonne[0], 'watchEndpoint');
    }
    videoId = _s(_percorso(we, ['videoId']));
  }

  final artisti = <String>[];
  var album = '';
  for (final run in runsSotto) {
    if (run is! Map) continue;
    final be = _percorso(run, ['navigationEndpoint', 'browseEndpoint']);
    if (be is! Map) continue;
    final tipo = _tipoDi(_tipoPagina(be), _s(be['browseId']));
    final testo = _s(run['text']);
    if (tipo == YtmKind.artist) {
      artisti.add(testo);
    } else if (tipo == YtmKind.album && album.isEmpty) {
      album = testo;
    }
  }
  var artista = artisti.join(', ');

  var durata = 0;
  for (final f in _l(r['fixedColumns'])) {
    final d = _secondi(_testoRuns(_percorso(
      f,
      ['musicResponsiveListItemFixedColumnRenderer', 'text'],
    )));
    if (d > 0) durata = d;
  }
  if (durata == 0) {
    for (final run in runsSotto) {
      if (run is! Map) continue;
      final d = _secondi(_s(run['text']));
      if (d > 0) durata = d;
    }
  }

  final copertina = _miglioreCopertina(r['thumbnail']);

  if (videoId.isNotEmpty) {
    if (artista.isEmpty) artista = _primoNome(sottotitolo);
    return YtmItem(
      kind: YtmKind.song,
      id: videoId,
      title: titolo,
      subtitle: sottotitolo,
      artist: artista,
      album: album,
      duration: Duration(seconds: durata),
      thumbnailUrl: copertina,
    );
  }

  final be = _percorso(r, ['navigationEndpoint', 'browseEndpoint']);
  if (be is Map) {
    final browseId = _s(be['browseId']);
    final tipo = _tipoDi(_tipoPagina(be), browseId);
    if (tipo == null || browseId.isEmpty) return null;
    return YtmItem(
      kind: tipo,
      id: browseId,
      title: titolo,
      subtitle: sottotitolo,
      artist: artista,
      thumbnailUrl: copertina,
    );
  }
  return null;
}

/// Scheda di un carosello: album, playlist, artisti, video.
YtmItem? _leggiScheda(dynamic r) {
  if (r is! Map) return null;
  final titolo = _testoRuns(r['title']);
  if (titolo.isEmpty) return null;
  final sottotitolo = _testoRuns(r['subtitle']);
  final copertina = _miglioreCopertina(r['thumbnailRenderer']);

  final videoId = _s(_percorso(r, ['navigationEndpoint', 'watchEndpoint', 'videoId']));
  if (videoId.isNotEmpty) {
    return YtmItem(
      kind: YtmKind.song,
      id: videoId,
      title: titolo,
      subtitle: sottotitolo,
      artist: _primoNome(sottotitolo),
      thumbnailUrl: copertina,
    );
  }

  final be = _percorso(r, ['navigationEndpoint', 'browseEndpoint']);
  if (be is Map) {
    final browseId = _s(be['browseId']);
    final tipo = _tipoDi(_tipoPagina(be), browseId);
    if (tipo == null || browseId.isEmpty) return null;
    return YtmItem(
      kind: tipo,
      id: browseId,
      title: titolo,
      subtitle: sottotitolo,
      artist: tipo == YtmKind.album ? _primoNome(sottotitolo) : '',
      thumbnailUrl: copertina,
    );
  }
  return null;
}

/// Voce della coda proposta dalla radio.
YtmItem? _leggiVoceCoda(dynamic r) {
  if (r is! Map) return null;
  final videoId = _s(r['videoId']);
  if (videoId.isEmpty) return null;
  final titolo = _testoRuns(r['title']);
  if (titolo.isEmpty) return null;

  final lungo = _testoRuns(r['longBylineText']);
  var artista = _testoRuns(r['shortBylineText']);
  if (artista.isEmpty) artista = _primoNome(lungo);

  var album = '';
  for (final run in _l(_percorso(r, ['longBylineText', 'runs']))) {
    if (run is! Map) continue;
    final be = _percorso(run, ['navigationEndpoint', 'browseEndpoint']);
    if (be is! Map) continue;
    if (_tipoDi(_tipoPagina(be), _s(be['browseId'])) == YtmKind.album) {
      album = _s(run['text']);
    }
  }

  return YtmItem(
    kind: YtmKind.song,
    id: videoId,
    title: titolo,
    subtitle: lungo,
    artist: artista,
    album: album,
    duration: Duration(seconds: _secondi(_testoRuns(r['lengthText']))),
    thumbnailUrl: _miglioreCopertina(r['thumbnail']),
  );
}

/// Pulsante di una categoria "mood e generi".
YtmItem? _leggiCategoria(dynamic r) {
  if (r is! Map) return null;
  final titolo = _testoRuns(r['buttonText']);
  final be = _percorso(r, ['clickCommand', 'browseEndpoint']);
  if (titolo.isEmpty || be is! Map) return null;
  final browseId = _s(be['browseId']);
  if (browseId.isEmpty) return null;
  final c = _percorso(r, ['solid', 'leftStripeColor']);
  return YtmItem(
    kind: YtmKind.mood,
    id: browseId,
    title: titolo,
    params: _s(be['params']),
    color: c is num ? c.toInt() : 0,
  );
}

/// Il "risultato migliore" in cima a una ricerca.
YtmItem? _leggiRisultatoMigliore(dynamic v) {
  if (v is! Map) return null;
  final titolo = _testoRuns(v['title']);
  if (titolo.isEmpty) return null;
  final sottotitolo = _testoRuns(v['subtitle']);
  final copertina = _miglioreCopertina(v['thumbnail']);
  final primoRun = _l(_percorso(v, ['title', 'runs']));
  final nav = primoRun.isNotEmpty ? _percorso(primoRun.first, ['navigationEndpoint']) : null;

  final videoId = _s(_percorso(nav, ['watchEndpoint', 'videoId']));
  if (videoId.isNotEmpty) {
    var durata = 0;
    for (final parte in sottotitolo.split(' • ')) {
      final d = _secondi(parte);
      if (d > 0) durata = d;
    }
    return YtmItem(
      kind: YtmKind.song,
      id: videoId,
      title: titolo,
      subtitle: sottotitolo,
      artist: _primoNome(sottotitolo),
      duration: Duration(seconds: durata),
      thumbnailUrl: copertina,
    );
  }

  final be = _percorso(nav, ['browseEndpoint']);
  if (be is Map) {
    final browseId = _s(be['browseId']);
    final tipo = _tipoDi(_tipoPagina(be), browseId);
    if (tipo == null || browseId.isEmpty) return null;
    return YtmItem(
      kind: tipo,
      id: browseId,
      title: titolo,
      subtitle: sottotitolo,
      thumbnailUrl: copertina,
    );
  }
  return null;
}

List<YtmItem> _leggiContenuti(dynamic lista) {
  final out = <YtmItem>[];
  for (final c in _l(lista)) {
    if (c is! Map) continue;
    YtmItem? it;
    if (c['musicResponsiveListItemRenderer'] != null) {
      it = _leggiRiga(c['musicResponsiveListItemRenderer']);
    } else if (c['musicTwoRowItemRenderer'] != null) {
      it = _leggiScheda(c['musicTwoRowItemRenderer']);
    } else if (c['playlistPanelVideoRenderer'] != null) {
      it = _leggiVoceCoda(c['playlistPanelVideoRenderer']);
    } else if (c['playlistPanelVideoWrapperRenderer'] != null) {
      it = _leggiVoceCoda(_percorso(c, [
        'playlistPanelVideoWrapperRenderer',
        'primaryRenderer',
        'playlistPanelVideoRenderer',
      ]));
    } else if (c['musicNavigationButtonRenderer'] != null) {
      it = _leggiCategoria(c['musicNavigationButtonRenderer']);
    }
    if (it != null) out.add(it);
  }
  return out;
}

YtmShelf? _leggiFila(String chiave, Map v) {
  var titolo = '';
  var elementi = <YtmItem>[];
  if (chiave == 'musicCarouselShelfRenderer') {
    titolo = _testoRuns(_trovaPrimo(v['header'], 'title'));
    elementi = _leggiContenuti(v['contents']);
  } else if (chiave == 'musicShelfRenderer' ||
      chiave == 'musicPlaylistShelfRenderer' ||
      chiave == 'playlistPanelRenderer') {
    titolo = _testoRuns(v['title']);
    elementi = _leggiContenuti(v['contents']);
  } else if (chiave == 'gridRenderer') {
    titolo = _testoRuns(_trovaPrimo(v['header'], 'title'));
    elementi = _leggiContenuti(v['items']);
  } else if (chiave == 'musicCardShelfRenderer') {
    titolo = _testoRuns(_trovaPrimo(v['header'], 'title'));
    final primo = _leggiRisultatoMigliore(v);
    if (primo != null) elementi.add(primo);
    elementi.addAll(_leggiContenuti(v['contents']));
  }
  if (elementi.isEmpty) return null;
  return YtmShelf(title: titolo, items: elementi);
}

/// Raccoglie le file di una pagina, nell'ordine in cui compaiono.
void _raccogliFile(dynamic nodo, List<YtmShelf> acc) {
  if (nodo is List) {
    for (final x in nodo) {
      _raccogliFile(x, acc);
    }
    return;
  }
  if (nodo is! Map) return;
  for (final voce in nodo.entries) {
    final k = voce.key;
    final v = voce.value;
    if (k is String && _chiaviFila.contains(k) && v is Map) {
      final fila = _leggiFila(k, v);
      if (fila != null) acc.add(fila);
    } else {
      _raccogliFile(v, acc);
    }
  }
}

/// Raccoglie tutti gli elementi di una risposta in un unico elenco.
void _raccogliElementi(dynamic nodo, List<YtmItem> acc) {
  if (nodo is List) {
    for (final x in nodo) {
      _raccogliElementi(x, acc);
    }
    return;
  }
  if (nodo is! Map) return;
  for (final voce in nodo.entries) {
    final k = voce.key;
    final v = voce.value;
    YtmItem? it;
    if (k == 'musicResponsiveListItemRenderer') {
      it = _leggiRiga(v);
    } else if (k == 'musicTwoRowItemRenderer') {
      it = _leggiScheda(v);
    } else if (k == 'playlistPanelVideoRenderer') {
      it = _leggiVoceCoda(v);
    } else if (k == 'playlistPanelVideoWrapperRenderer') {
      // Dentro c'e' anche la versione video dello stesso brano: si tiene
      // solo quella principale.
      _raccogliElementi(_percorso(v, ['primaryRenderer']), acc);
    } else if (k == 'musicCardShelfRenderer') {
      it = _leggiRisultatoMigliore(v);
      if (it != null) acc.add(it);
      it = null;
      _raccogliElementi(_percorso(v, ['contents']), acc);
    } else {
      _raccogliElementi(v, acc);
    }
    if (it != null) acc.add(it);
  }
}

void _raccogliSuggerimenti(dynamic nodo, List<String> acc) {
  if (nodo is List) {
    for (final x in nodo) {
      _raccogliSuggerimenti(x, acc);
    }
    return;
  }
  if (nodo is! Map) return;
  for (final voce in nodo.entries) {
    if (voce.key == 'searchSuggestionRenderer') {
      final t = _testoRuns(_percorso(voce.value, ['suggestion']));
      if (t.isNotEmpty) acc.add(t);
    } else {
      _raccogliSuggerimenti(voce.value, acc);
    }
  }
}

List<YtmItem> _senzaDoppioni(List<YtmItem> lista) {
  final visti = <String>{};
  final out = <YtmItem>[];
  for (final it in lista) {
    if (visti.add('${it.kind.index}:${it.id}')) out.add(it);
  }
  return out;
}

/// Il rimando al blocco successivo di un elenco lungo, '' se non c'e'.
String _tokenSeguito(dynamic nodo) {
  final comando = _trovaPrimo(nodo, 'continuationCommand');
  final t = _s(_percorso(comando, ['token']));
  if (t.isNotEmpty) return t;
  final vecchio = _trovaPrimo(nodo, 'nextContinuationData');
  return _s(_percorso(vecchio, ['continuation']));
}

_Intestazione _leggiIntestazione(dynamic json) {
  final h = _trovaPrimo(json, 'musicResponsiveHeaderRenderer') ??
      _trovaPrimo(json, 'musicImmersiveHeaderRenderer') ??
      _trovaPrimo(json, 'musicVisualHeaderRenderer') ??
      _trovaPrimo(json, 'musicDetailHeaderRenderer') ??
      _trovaPrimo(json, 'musicHeaderRenderer');
  if (h is! Map) return const _Intestazione();

  final artista = _testoRuns(h['straplineTextOne']);
  final parti = <String>[];
  for (final p in [
    artista,
    _testoRuns(h['subtitle']),
    _testoRuns(h['secondSubtitle']),
  ]) {
    if (p.isNotEmpty) parti.add(p);
  }

  final descrizione = _testoRuns(
    _trovaPrimo(h['description'], 'description') ?? h['description'],
  );

  return _Intestazione(
    title: _testoRuns(h['title']),
    subtitle: parti.join(' • '),
    artist: artista,
    thumb: _miglioreCopertina(h['thumbnail'] ?? h['foregroundThumbnail']),
    description: descrizione,
  );
}
