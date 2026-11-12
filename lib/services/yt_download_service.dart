import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'youtube_service.dart';

enum YtDownloadState { queued, downloading, done, failed }

class YtDownload {
  final Track track;
  YtDownloadState state;
  double progress;
  String? error;

  YtDownload(this.track)
      : state = YtDownloadState.queued,
        progress = 0.0;

  String get videoId => track.id.replaceFirst('yt_', '');
}

/// Coda dei download sul telefono dei brani in streaming.
///
/// Scarica un brano alla volta: YouTube rallenta chi apre piu' flussi
/// insieme, e in fila l'avanzamento resta leggibile. A file pronto il brano
/// entra in libreria con titolo, artista e copertina gia' corretti.
class YtDownloadService extends ChangeNotifier {
  static final YtDownloadService instance = YtDownloadService._();
  YtDownloadService._();

  final List<YtDownload> _voci = [];
  bool _alLavoro = false;

  List<YtDownload> get items => List.unmodifiable(_voci);
  bool get isWorking => _alLavoro;

  int get pendingCount => _voci
      .where((v) =>
          v.state == YtDownloadState.queued ||
          v.state == YtDownloadState.downloading)
      .length;

  YtDownload? get current {
    for (final v in _voci) {
      if (v.state == YtDownloadState.downloading) return v;
    }
    return null;
  }

  /// Avanzamento complessivo delle voci non ancora chiuse, da 0 a 1.
  double get overallProgress {
    if (_voci.isEmpty) return 0.0;
    var somma = 0.0;
    for (final v in _voci) {
      if (v.state == YtDownloadState.done || v.state == YtDownloadState.failed) {
        somma += 1.0;
      } else {
        somma += v.progress;
      }
    }
    return (somma / _voci.length).clamp(0.0, 1.0);
  }

  /// true se il brano e' gia' un file nella libreria.
  bool isDownloaded(Track track) {
    if (!track.isOnline) return true;
    final id = track.id.replaceFirst('yt_', '');
    if (id.isEmpty) return false;
    for (final t in LibraryService.instance.tracks) {
      final fp = t.filePath;
      if (fp != null && fp.contains(id)) return true;
    }
    return false;
  }

  YtDownloadState? stateOf(Track track) {
    for (final v in _voci) {
      if (v.track.id == track.id) return v.state;
    }
    return null;
  }

  /// Accoda un brano. Restituisce false se non serviva (gia' scaricato o
  /// gia' in coda).
  bool enqueue(Track track) {
    if (!track.isOnline) return false;
    if (isDownloaded(track)) return false;
    final esiste = _voci.any((v) =>
        v.track.id == track.id &&
        (v.state == YtDownloadState.queued ||
            v.state == YtDownloadState.downloading));
    if (esiste) return false;
    _voci.removeWhere((v) => v.track.id == track.id);
    _voci.add(YtDownload(track));
    notifyListeners();
    _lavora();
    return true;
  }

  /// Accoda piu' brani. Restituisce quanti ne ha davvero accodati.
  int enqueueAll(List<Track> tracks) {
    var n = 0;
    for (final t in tracks) {
      if (enqueue(t)) n++;
    }
    return n;
  }

  void retry(YtDownload voce) {
    if (voce.state != YtDownloadState.failed) return;
    voce.state = YtDownloadState.queued;
    voce.progress = 0.0;
    voce.error = null;
    notifyListeners();
    _lavora();
  }

  /// Toglie dalla coda una voce non ancora partita.
  void remove(YtDownload voce) {
    if (voce.state == YtDownloadState.downloading) return;
    _voci.remove(voce);
    notifyListeners();
  }

  void cancelQueued() {
    _voci.removeWhere((v) => v.state == YtDownloadState.queued);
    notifyListeners();
  }

  void clearFinished() {
    _voci.removeWhere((v) =>
        v.state == YtDownloadState.done || v.state == YtDownloadState.failed);
    notifyListeners();
  }

  Future<void> _lavora() async {
    if (_alLavoro) return;
    _alLavoro = true;
    try {
      while (true) {
        YtDownload? prossimo;
        for (final v in _voci) {
          if (v.state == YtDownloadState.queued) {
            prossimo = v;
            break;
          }
        }
        if (prossimo == null) break;
        await _scarica(prossimo);
      }
    } finally {
      _alLavoro = false;
      notifyListeners();
    }
  }

  Future<void> _scarica(YtDownload voce) async {
    voce.state = YtDownloadState.downloading;
    voce.progress = 0.0;
    notifyListeners();

    final t = voce.track;
    final artista = t.artist.trim();
    // "Artista - Titolo" nel nome del file: se un giorno i dati della
    // libreria si perdono, la scansione ricava comunque l'artista dal nome.
    final nome = artista.isEmpty ? t.title : '$artista - ${t.title}';

    var ultimoAvviso = 0.0;
    File? file;
    try {
      file = await YouTubeService.instance.downloadAudioStream(
        voce.videoId,
        nome,
        onProgress: (p) {
          voce.progress = p;
          // Senza freno arriverebbero migliaia di notifiche a brano.
          if (p - ultimoAvviso >= 0.02 || p >= 1.0) {
            ultimoAvviso = p;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      voce.error = e.toString();
    }

    if (file == null) {
      voce.state = YtDownloadState.failed;
      voce.error ??= YouTubeService.instance.lastFailureReason ??
          'Download non riuscito.';
      notifyListeners();
      return;
    }

    var dimensione = 0;
    try {
      dimensione = await file.length();
    } catch (_) {}

    final copertina = await _salvaCopertina(t, voce.videoId);
    await LibraryService.instance.registerDownloadedTrack(Track(
      id: file.path,
      title: t.title,
      artist: artista.isEmpty ? 'Artista sconosciuto' : artista,
      album: (t.album == 'YouTube' || t.album == 'YouTube Music') ? '' : t.album,
      duration: t.duration,
      filePath: file.path,
      fileSize: dimensione,
      thumbnailUrl: copertina ?? t.thumbnailUrl ?? '',
    ));

    voce.progress = 1.0;
    voce.state = YtDownloadState.done;
    notifyListeners();
  }

  /// Salva la copertina accanto alle altre, cosi' si vede anche offline.
  Future<String?> _salvaCopertina(Track t, String videoId) async {
    final url = t.thumbnailUrl;
    if (url == null || !url.startsWith('http')) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/Covers');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final sicuro = videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final dest = File('${dir.path}/yt_$sicuro.jpg');
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200 || r.bodyBytes.length < 500) return null;
      await dest.writeAsBytes(r.bodyBytes);
      return dest.path;
    } catch (e) {
      debugPrint('Avviso copertina download: $e');
      return null;
    }
  }
}
