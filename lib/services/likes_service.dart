import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'library_service.dart';

/// I brani a cui e' stato messo il cuore.
///
/// Vale sia per i file locali sia per i brani in streaming: di ognuno si
/// conserva una copia dei dati, cosi' quelli online restano elencabili anche
/// se non stanno nella libreria.
class LikesService extends ChangeNotifier {
  static final LikesService instance = LikesService._();
  LikesService._();

  /// I piu' recenti in testa.
  final List<Track> _liked = [];
  final Set<String> _chiavi = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get count => _liked.length;

  /// Chiave stabile di un brano.
  ///
  /// Gli id dei file locali sono percorsi assoluti, e su iOS la cartella
  /// Documents cambia nome a ogni reinstallazione: tenendo solo il nome del
  /// file i cuori sopravvivono agli aggiornamenti dell'IPA.
  static String keyOf(String id) {
    if (id.startsWith('yt_')) return id;
    final slash = id.lastIndexOf('/');
    final backslash = id.lastIndexOf('\\');
    final i = slash > backslash ? slash : backslash;
    return i == -1 ? id : id.substring(i + 1);
  }

  bool isLiked(Track track) => _chiavi.contains(keyOf(track.id));

  /// I brani piaciuti ancora riproducibili: quelli locali il cui file non
  /// esiste piu' vengono saltati, senza toglierli dall'elenco salvato.
  List<Track> get tracks {
    final out = <Track>[];
    for (final t in _liked) {
      if (t.isOnline) {
        out.add(t);
        continue;
      }
      final locale = LibraryService.instance.getTrackById(t.id);
      if (locale != null) out.add(locale);
    }
    return out;
  }

  Future<File> get _file async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/likes.json');
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map && data['tracks'] is List) {
          _caricaLista(data['tracks'] as List, sostituisci: true);
        }
      }
    } catch (e) {
      debugPrint('Avviso caricamento Mi piace: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  int _caricaLista(List lista, {required bool sostituisci}) {
    if (sostituisci) {
      _liked.clear();
      _chiavi.clear();
    }
    var aggiunti = 0;
    for (final e in lista) {
      if (e is! Map) continue;
      try {
        final t = Track.fromJson(Map<String, dynamic>.from(e));
        if (t.id.isEmpty) continue;
        final k = keyOf(t.id);
        if (_chiavi.add(k)) {
          _liked.add(t);
          aggiunti++;
        }
      } catch (_) {}
    }
    return aggiunti;
  }

  Future<void> _save() async {
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode({
        'version': 1,
        'tracks': _liked.map((t) => t.toJson()).toList(),
      }));
    } catch (e) {
      debugPrint('Avviso salvataggio Mi piace: $e');
    }
  }

  /// Mette o toglie il cuore. Restituisce true se ora il brano piace.
  Future<bool> toggle(Track track) async {
    final k = keyOf(track.id);
    bool oraPiace;
    if (_chiavi.contains(k)) {
      _chiavi.remove(k);
      _liked.removeWhere((t) => keyOf(t.id) == k);
      oraPiace = false;
    } else {
      _chiavi.add(k);
      _liked.insert(0, track);
      oraPiace = true;
    }
    notifyListeners();
    await _save();
    return oraPiace;
  }

  /// Per il backup completo.
  List<Map<String, dynamic>> exportJson() =>
      _liked.map((t) => t.toJson()).toList();

  /// Unisce i cuori di un backup a quelli presenti. Restituisce quanti nuovi.
  Future<int> importJson(List lista) async {
    final aggiunti = _caricaLista(lista, sostituisci: false);
    if (aggiunti > 0) {
      notifyListeners();
      await _save();
    }
    return aggiunti;
  }
}
