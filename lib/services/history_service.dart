import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class HistoryEntry {
  final Track track;
  final DateTime playedAt;

  const HistoryEntry({required this.track, required this.playedAt});

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'playedAt': playedAt.toIso8601String(),
      };

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final t = json['track'];
    if (t is! Map) return null;
    final track = Track.fromJson(Map<String, dynamic>.from(t));
    if (track.id.isEmpty) return null;
    final quando = DateTime.tryParse(json['playedAt']?.toString() ?? '');
    return HistoryEntry(track: track, playedAt: quando ?? DateTime.now());
  }
}

/// Cronologia di ascolto e contatori che servono al Replay.
///
/// Le statistiche esistenti contano quanto e cosa si ascolta, ma non a che
/// ora ne' da quale album: quei due dati vengono raccolti qui, mese per mese.
class HistoryService extends ChangeNotifier {
  static final HistoryService instance = HistoryService._();
  HistoryService._();

  static const int maxEntries = 400;

  /// I piu' recenti in testa.
  final List<HistoryEntry> _entries = [];

  /// 'yyyy-MM' -> 24 contatori, uno per ora del giorno.
  final Map<String, List<int>> _ore = {};

  /// 'yyyy-MM' -> chiave album -> ascolti avviati.
  final Map<String, Map<String, int>> _album = {};

  /// chiave album -> copertina.
  final Map<String, String> _copertine = {};

  Timer? _salvataggio;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Separa album e artista dentro la chiave: un carattere che non compare
  /// mai nei titoli.
  static const String sepAlbum = '\u0001';

  static String albumName(String chiave) => chiave.split(sepAlbum).first;

  static String albumArtist(String chiave) {
    final parti = chiave.split(sepAlbum);
    return parti.length > 1 ? parti[1] : '';
  }

  Future<File> get _file async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/history.json');
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map) {
          final lista = data['entries'];
          if (lista is List) {
            for (final e in lista) {
              if (e is! Map) continue;
              final voce = HistoryEntry.fromJson(Map<String, dynamic>.from(e));
              if (voce != null) _entries.add(voce);
            }
          }
          final ore = data['hours'];
          if (ore is Map) {
            ore.forEach((k, v) {
              if (v is List) {
                final conti = List<int>.filled(24, 0, growable: false);
                for (var i = 0; i < 24 && i < v.length; i++) {
                  final n = v[i];
                  conti[i] = n is num ? n.toInt() : 0;
                }
                _ore[k.toString()] = conti;
              }
            });
          }
          final album = data['albums'];
          if (album is Map) {
            album.forEach((mese, v) {
              if (v is Map) {
                final m = <String, int>{};
                v.forEach((nome, n) {
                  if (n is num) m[nome.toString()] = n.toInt();
                });
                _album[mese.toString()] = m;
              }
            });
          }
          final cop = data['covers'];
          if (cop is Map) {
            cop.forEach((k, v) {
              if (v is String) _copertine[k.toString()] = v;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Avviso caricamento cronologia: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  void _pianificaSalvataggio() {
    _salvataggio?.cancel();
    _salvataggio = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode({
        'version': 1,
        'entries': _entries.map((e) => e.toJson()).toList(),
        'hours': _ore,
        'albums': _album,
        'covers': _copertine,
      }));
    } catch (e) {
      debugPrint('Avviso salvataggio cronologia: $e');
    }
  }

  /// Registra l'avvio di un brano.
  void record(Track track) {
    final ora = DateTime.now();
    // Lo stesso brano rilanciato subito (un doppio tocco, un riavvio dopo un
    // errore) non deve comparire due volte di fila.
    if (_entries.isNotEmpty &&
        _entries.first.track.id == track.id &&
        ora.difference(_entries.first.playedAt).inMinutes < 2) {
      return;
    }

    _entries.insert(0, HistoryEntry(track: track, playedAt: ora));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }

    final mese = monthKey(ora);
    final conti = _ore.putIfAbsent(mese, () => List<int>.filled(24, 0));
    conti[ora.hour] = conti[ora.hour] + 1;

    final nomeAlbum = track.album.trim();
    if (nomeAlbum.isNotEmpty &&
        nomeAlbum != 'YouTube' &&
        nomeAlbum != 'YouTube Music') {
      final chiave = '$nomeAlbum$sepAlbum${track.displayArtist}';
      final perMese = _album.putIfAbsent(mese, () => <String, int>{});
      perMese[chiave] = (perMese[chiave] ?? 0) + 1;
      final cop = track.thumbnailUrl;
      if (cop != null && cop.isNotEmpty) _copertine[chiave] = cop;
    }

    notifyListeners();
    _pianificaSalvataggio();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    notifyListeners();
    _pianificaSalvataggio();
  }

  /// Svuota l'elenco dei brani ascoltati. I contatori del Replay restano.
  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  /// Ascolti avviati per ora del giorno, sommando i mesi che iniziano con
  /// [prefisso] ('2026-11' un mese, '2026' un anno, '' tutto).
  List<int> hoursFor(String prefisso) {
    final somma = List<int>.filled(24, 0);
    _ore.forEach((mese, conti) {
      if (!mese.startsWith(prefisso)) return;
      for (var i = 0; i < 24 && i < conti.length; i++) {
        somma[i] = somma[i] + conti[i];
      }
    });
    return somma;
  }

  /// Album ascoltati nel periodo, dal piu' ascoltato.
  List<MapEntry<String, int>> albumsFor(String prefisso) {
    final somma = <String, int>{};
    _album.forEach((mese, perMese) {
      if (!mese.startsWith(prefisso)) return;
      perMese.forEach((chiave, n) {
        somma[chiave] = (somma[chiave] ?? 0) + n;
      });
    });
    final lista = somma.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return lista;
  }

  String? albumCover(String chiave) => _copertine[chiave];
}
