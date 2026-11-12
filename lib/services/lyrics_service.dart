import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  /// Da dove arriva il testo, da mostrare sotto.
  final String source;

  /// true se ogni riga ha il suo istante.
  final bool synced;
  final bool instrumental;

  /// Righe con i tempi. Vuota se il testo non e' sincronizzato.
  final List<LyricLine> lines;
  final String plain;

  const Lyrics({
    required this.source,
    required this.synced,
    required this.instrumental,
    required this.lines,
    required this.plain,
  });

  bool get isEmpty => !instrumental && lines.isEmpty && plain.trim().isEmpty;
}

/// Testi dei brani, sincronizzati quando disponibili.
///
/// La fonte e' LRCLIB, un archivio aperto che non chiede chiavi ne' account.
/// Ogni testo trovato viene salvato su disco: la seconda volta compare subito
/// e funziona anche senza rete.
class LyricsService {
  static final LyricsService instance = LyricsService._();
  LyricsService._();

  static const String _host = 'lrclib.net';
  static const Map<String, String> _headers = {
    'User-Agent': 'DovvoPlay (lettore musicale)',
    'Accept': 'application/json',
  };

  /// Risultati gia' cercati in questa sessione, compresi i "non trovato".
  final Map<String, Lyrics?> _memoria = {};

  // ---------------------------------------------------------------- pulizia

  static final RegExp _rumore = RegExp(
    r'\s*[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|'
    r'\bhd\b|\b4k\b|explicit|\bm/?v\b|testo)[^\)\]]*[\)\]]',
    caseSensitive: false,
  );

  /// Toglie dal titolo le diciture che non fanno parte del nome del brano,
  /// tipo "(Official Video)" o "[Lyrics]".
  static String cleanTitle(String titolo) {
    var t = titolo.replaceAll(_rumore, '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? titolo.trim() : t;
  }

  /// Il primo artista di una lista, senza il suffisso dei canali automatici.
  static String primaryArtist(String artista) {
    var a = artista.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');
    final parti = a.split(
      RegExp(r',|&| e | feat\.? | ft\.? | x ', caseSensitive: false),
    );
    a = parti.isNotEmpty ? parti.first.trim() : a.trim();
    return a;
  }

  /// Titolo e artista da usare per la ricerca.
  static List<String> _indovina(Track track) {
    var titolo = cleanTitle(track.title);
    var artista = track.artist.trim();
    if (artista == 'Artista sconosciuto') artista = '';

    // "Artista - Titolo" e' la forma dei video di YouTube e dei file senza
    // tag. Si divide solo quando e' sicuro: altrimenti un titolo come
    // "The Veldt - Radio Edit" diventerebbe artista "The Veldt".
    final trattino = titolo.indexOf(' - ');
    if (trattino > 0 && trattino < titolo.length - 3) {
      final sinistra = titolo.substring(0, trattino).trim();
      final destra = titolo.substring(trattino + 3).trim();
      final uguale = sinistra.toLowerCase() == artista.toLowerCase();
      final contenuto = artista.isNotEmpty &&
          (artista.toLowerCase().contains(sinistra.toLowerCase()) ||
              sinistra.toLowerCase().contains(artista.toLowerCase()));
      if (artista.isEmpty || uguale || contenuto || track.album == 'YouTube') {
        artista = sinistra;
        titolo = destra;
      }
    }
    return [titolo, primaryArtist(artista)];
  }

  /// Hash stabile tra un avvio e l'altro (String.hashCode non lo garantisce).
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String keyOf(Track track) {
    final g = _indovina(track);
    return _hash('${g[1].toLowerCase()}|${g[0].toLowerCase()}');
  }

  // ------------------------------------------------------------------ disco

  Future<File> _fileDi(String chiave) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Lyrics');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$chiave.json');
  }

  Future<Lyrics?> _leggiDisco(String chiave) async {
    try {
      final f = await _fileDi(chiave);
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString());
      if (data is! Map) return null;
      return _costruisci(
        source: data['source']?.toString() ?? 'LRCLIB',
        lrc: data['lrc']?.toString() ?? '',
        plain: data['plain']?.toString() ?? '',
        instrumental: data['instrumental'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _scriviDisco(
    String chiave, {
    required String source,
    required String lrc,
    required String plain,
    required bool instrumental,
  }) async {
    try {
      final f = await _fileDi(chiave);
      await f.writeAsString(jsonEncode({
        'source': source,
        'lrc': lrc,
        'plain': plain,
        'instrumental': instrumental,
      }));
    } catch (e) {
      debugPrint('Avviso salvataggio testo: $e');
    }
  }

  // ---------------------------------------------------------------- parsing

  static final RegExp _tag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _tagParola = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

  /// Legge un testo in formato LRC: righe del tipo "[01:23.45] parole".
  static List<LyricLine> parseLrc(String lrc) {
    final out = <LyricLine>[];
    for (final riga in const LineSplitter().convert(lrc)) {
      final trovati = _tag.allMatches(riga).toList();
      if (trovati.isEmpty) continue;
      final testo = riga.replaceAll(_tag, '').replaceAll(_tagParola, '').trim();
      for (final m in trovati) {
        final min = int.tryParse(m.group(1) ?? '') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '') ?? 0;
        final fraz = m.group(3);
        var ms = 0;
        if (fraz != null && fraz.isNotEmpty) {
          final n = int.tryParse(fraz) ?? 0;
          if (fraz.length == 1) {
            ms = n * 100;
          } else if (fraz.length == 2) {
            ms = n * 10;
          } else {
            ms = n;
          }
        }
        out.add(LyricLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          testo,
        ));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  static Lyrics _costruisci({
    required String source,
    required String lrc,
    required String plain,
    required bool instrumental,
  }) {
    final righe = lrc.trim().isEmpty ? <LyricLine>[] : parseLrc(lrc);
    var semplice = plain;
    if (semplice.trim().isEmpty && righe.isNotEmpty) {
      semplice = righe.map((r) => r.text).join('\n');
    }
    return Lyrics(
      source: source,
      synced: righe.isNotEmpty,
      instrumental: instrumental,
      lines: righe,
      plain: semplice,
    );
  }

  // ------------------------------------------------------------------- rete

  Future<dynamic> _get(String percorso, Map<String, String> parametri) async {
    final uri = Uri.https(_host, percorso, parametri);
    final r = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 12),
        );
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('LRCLIB ha risposto ${r.statusCode}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static String _testo(dynamic v) => v is String ? v : '';

  /// Sceglie, tra piu' risultati, quello con la durata piu' vicina e
  /// preferendo i testi sincronizzati.
  static Map? _migliore(dynamic lista, int durataSec) {
    if (lista is! List) return null;
    Map? scelto;
    var punteggioScelto = -1000000;
    for (final e in lista) {
      if (e is! Map) continue;
      final sincro = _testo(e['syncedLyrics']).trim().isNotEmpty;
      final semplice = _testo(e['plainLyrics']).trim().isNotEmpty;
      final strumentale = e['instrumental'] == true;
      if (!sincro && !semplice && !strumentale) continue;

      var punteggio = sincro ? 100 : 0;
      final d = e['duration'];
      final durata = d is num ? d.round() : 0;
      if (durataSec > 0 && durata > 0) {
        final diff = (durata - durataSec).abs();
        if (diff <= 2) {
          punteggio += 80;
        } else if (diff <= 6) {
          punteggio += 40;
        } else if (diff > 20) {
          punteggio -= 150;
        } else {
          punteggio -= diff * 2;
        }
      }
      if (punteggio > punteggioScelto) {
        punteggioScelto = punteggio;
        scelto = e;
      }
    }
    return scelto;
  }

  /// Cerca il testo di [track]. Restituisce null se non esiste; lancia
  /// un'eccezione solo per problemi di rete, cosi' chi chiama puo' offrire
  /// di riprovare senza confondere "non trovato" con "non raggiungibile".
  Future<Lyrics?> fetch(Track track, {bool force = false}) async {
    final chiave = keyOf(track);
    if (!force && _memoria.containsKey(chiave)) return _memoria[chiave];

    if (!force) {
      final salvato = await _leggiDisco(chiave);
      if (salvato != null) {
        _memoria[chiave] = salvato;
        return salvato;
      }
    }

    final g = _indovina(track);
    final titolo = g[0];
    final artista = g[1];
    final durataSec = track.duration.inSeconds;

    Map? trovato;

    // 1. Corrispondenza esatta su titolo, artista e durata.
    if (artista.isNotEmpty && durataSec > 0) {
      final esatto = await _get('/api/get', {
        'track_name': titolo,
        'artist_name': artista,
        'duration': '$durataSec',
      });
      if (esatto is Map) trovato = _migliore([esatto], durataSec);
    }

    // 2. Ricerca per campi.
    if (trovato == null) {
      final parametri = <String, String>{'track_name': titolo};
      if (artista.isNotEmpty) parametri['artist_name'] = artista;
      trovato = _migliore(await _get('/api/search', parametri), durataSec);
    }

    // 3. Ricerca libera.
    if (trovato == null) {
      final q = artista.isEmpty ? titolo : '$artista $titolo';
      trovato = _migliore(await _get('/api/search', {'q': q}), durataSec);
    }

    // 4. Titolo completo, per i video il cui canale non e' l'artista.
    if (trovato == null) {
      final intero = cleanTitle(track.title);
      if (intero != titolo) {
        trovato = _migliore(await _get('/api/search', {'q': intero}), durataSec);
      }
    }

    if (trovato == null) {
      _memoria[chiave] = null;
      return null;
    }

    var lrc = _testo(trovato['syncedLyrics']);
    final semplice = _testo(trovato['plainLyrics']);
    final strumentale = trovato['instrumental'] == true;

    // Una versione di durata diversa avrebbe i tempi sfasati: meglio il
    // testo fermo che righe evidenziate nel momento sbagliato.
    final d = trovato['duration'];
    final durata = d is num ? d.round() : 0;
    if (durataSec > 0 && durata > 0 && (durata - durataSec).abs() > 8) {
      lrc = '';
    }

    final testo = _costruisci(
      source: 'LRCLIB',
      lrc: lrc,
      plain: semplice,
      instrumental: strumentale,
    );
    _memoria[chiave] = testo;
    await _scriviDisco(
      chiave,
      source: 'LRCLIB',
      lrc: lrc,
      plain: testo.plain,
      instrumental: strumentale,
    );
    return testo;
  }

  // ----------------------------------------------------------------- offset

  /// Scostamento del testo, in millisecondi: positivo = righe piu' tardi.
  Future<int> getOffsetMs(Track track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('dovvoplay_lyrics_offset_${keyOf(track)}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setOffsetMs(Track track, int ms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = 'dovvoplay_lyrics_offset_${keyOf(track)}';
      if (ms == 0) {
        await prefs.remove(k);
      } else {
        await prefs.setInt(k, ms);
      }
    } catch (_) {}
  }
}
