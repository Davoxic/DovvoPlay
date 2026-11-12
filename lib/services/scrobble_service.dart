import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'lyrics_service.dart';

/// Scrobbling su ListenBrainz: registra gli ascolti nel proprio profilo.
///
/// ListenBrainz e' aperto e chiede solo un token utente, che ciascuno copia
/// dalla propria pagina. Il token resta nelle preferenze dell'app su questo
/// dispositivo e viene inviato soltanto a ListenBrainz.
class ScrobbleService extends ChangeNotifier {
  static final ScrobbleService instance = ScrobbleService._();
  ScrobbleService._();

  static const String _kToken = 'dovvoplay_listenbrainz_token';
  static const String _kUtente = 'dovvoplay_listenbrainz_user';
  static const String _kAttivo = 'dovvoplay_listenbrainz_enabled';
  static const String _host = 'api.listenbrainz.org';

  String _token = '';
  String _utente = '';
  bool _attivo = true;
  String? _ultimoErrore;
  int _inviati = 0;

  bool get isConnected => _token.isNotEmpty;
  bool get enabled => _attivo;
  String get userName => _utente;
  String? get lastError => _ultimoErrore;

  /// Ascolti inviati in questa sessione.
  int get sentCount => _inviati;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken) ?? '';
      _utente = prefs.getString(_kUtente) ?? '';
      _attivo = prefs.getBool(_kAttivo) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Avviso scrobbling: $e');
    }
  }

  /// Verifica il token e, se valido, lo salva. Restituisce null se e' andata
  /// bene, altrimenti il motivo da mostrare.
  Future<String?> connect(String token) async {
    final t = token.trim();
    if (t.isEmpty) return 'Incolla il tuo token utente ListenBrainz.';
    try {
      final r = await http.get(
        Uri.https(_host, '/1/validate-token'),
        headers: {'Authorization': 'Token $t'},
      ).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        return 'ListenBrainz ha risposto ${r.statusCode}.';
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! Map || data['valid'] != true) {
        return 'ListenBrainz ha rifiutato quel token.';
      }
      _token = t;
      _utente = data['user_name']?.toString() ?? '';
      _ultimoErrore = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, _token);
      await prefs.setString(_kUtente, _utente);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Impossibile raggiungere ListenBrainz: $e';
    }
  }

  Future<void> disconnect() async {
    _token = '';
    _utente = '';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kUtente);
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    _attivo = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAttivo, v);
    } catch (_) {}
  }

  Map<String, dynamic> _metadati(Track track, {int? durataMs}) {
    final artista = LyricsService.primaryArtist(track.displayArtist);
    final m = <String, dynamic>{
      'artist_name': artista.isEmpty ? track.displayArtist : artista,
      'track_name': LyricsService.cleanTitle(track.displayTitle),
    };
    final album = track.album.trim();
    if (album.isNotEmpty && album != 'YouTube' && album != 'YouTube Music') {
      m['release_name'] = album;
    }
    final info = <String, dynamic>{
      'media_player': 'DovvoPlay',
      'submission_client': 'DovvoPlay',
    };
    if (durataMs != null && durataMs > 0) info['duration_ms'] = durataMs;
    m['additional_info'] = info;
    return m;
  }

  Future<void> _invia(Map<String, dynamic> corpo) async {
    try {
      final r = await http
          .post(
            Uri.https(_host, '/1/submit-listens'),
            headers: {
              'Authorization': 'Token $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        _ultimoErrore = null;
      } else {
        _ultimoErrore = 'ListenBrainz ha risposto ${r.statusCode}';
      }
    } catch (e) {
      _ultimoErrore = e.toString();
    }
  }

  /// Aggiorna "sto ascoltando" all'avvio di un brano.
  void onTrackStart(Track track) {
    if (!isConnected || !_attivo) return;
    _invia({
      'listen_type': 'playing_now',
      'payload': [
        {'track_metadata': _metadati(track)},
      ],
    });
  }

  /// Registra l'ascolto a brano concluso o cambiato.
  ///
  /// Vale la regola classica dello scrobbling: conta se si e' ascoltata
  /// almeno meta' del brano, oppure quattro minuti. I brani sotto i trenta
  /// secondi non vengono registrati.
  void onTrackEnd(Track track, int ascoltatiMs, Duration durata) {
    if (!isConnected || !_attivo) return;
    final totaleMs = durata.inMilliseconds;
    if (totaleMs > 0 && totaleMs < 30000) return;
    final abbastanza = ascoltatiMs >= 240000 ||
        (totaleMs > 0 && ascoltatiMs >= totaleMs ~/ 2);
    if (!abbastanza) return;

    final inizio = DateTime.now()
            .subtract(Duration(milliseconds: ascoltatiMs))
            .millisecondsSinceEpoch ~/
        1000;
    _inviati++;
    _invia({
      'listen_type': 'single',
      'payload': [
        {
          'listened_at': inizio,
          'track_metadata': _metadati(track, durataMs: totaleMs),
        },
      ],
    }).then((_) => notifyListeners());
  }
}
