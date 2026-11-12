import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferenze di riproduzione: AutoPlay, dissolvenza, qualita' dello
/// streaming, testi e limite della cache.
///
/// Stanno tutte qui perche' le leggono sia il player sia le schermate: un
/// solo punto che notifica evita di avere copie non allineate in giro.
class PlaybackSettings extends ChangeNotifier {
  static final PlaybackSettings instance = PlaybackSettings._();
  PlaybackSettings._();

  static const String _prefisso = 'dovvoplay_playback_';

  bool _autoplay = true;
  bool _noRepeatAutoplay = true;
  int _fadeSeconds = 0;
  bool _dataSaver = false;
  bool _nerdStats = false;
  bool _syncedLyrics = true;
  bool _blurLyrics = true;
  int _cacheLimitMb = 1024;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// A coda finita continua con musica simile.
  bool get autoplay => _autoplay;

  /// AutoPlay non ripropone un brano gia' suggerito nella sessione.
  bool get noRepeatAutoplay => _noRepeatAutoplay;

  /// Secondi di dissolvenza tra un brano e il successivo. 0 = spenta.
  int get fadeSeconds => _fadeSeconds;

  /// Preferisce il flusso audio piu' leggero.
  bool get dataSaver => _dataSaver;

  /// Mostra formato, bitrate e peso del file nel player.
  bool get nerdStats => _nerdStats;

  /// Evidenzia la riga cantata quando il testo ha i tempi.
  bool get syncedLyrics => _syncedLyrics;

  /// Sfoca le righe lontane da quella corrente.
  bool get blurLyrics => _blurLyrics;

  /// Spazio massimo, in MB, per l'audio tenuto in cache dallo streaming.
  int get cacheLimitMb => _cacheLimitMb;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoplay = prefs.getBool('${_prefisso}autoplay') ?? true;
      _noRepeatAutoplay = prefs.getBool('${_prefisso}no_repeat') ?? true;
      _fadeSeconds = (prefs.getInt('${_prefisso}fade') ?? 0).clamp(0, 12);
      _dataSaver = prefs.getBool('${_prefisso}data_saver') ?? false;
      _nerdStats = prefs.getBool('${_prefisso}nerd_stats') ?? false;
      _syncedLyrics = prefs.getBool('${_prefisso}synced_lyrics') ?? true;
      _blurLyrics = prefs.getBool('${_prefisso}blur_lyrics') ?? true;
      _cacheLimitMb = (prefs.getInt('${_prefisso}cache_limit') ?? 1024).clamp(128, 8192);
    } catch (e) {
      debugPrint('Avviso PlaybackSettings: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _salva(String chiave, Object valore) async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = '$_prefisso$chiave';
      if (valore is bool) {
        await prefs.setBool(k, valore);
      } else if (valore is int) {
        await prefs.setInt(k, valore);
      } else if (valore is double) {
        await prefs.setDouble(k, valore);
      } else {
        await prefs.setString(k, valore.toString());
      }
    } catch (e) {
      debugPrint('Avviso salvataggio preferenze: $e');
    }
  }

  void setAutoplay(bool v) {
    _autoplay = v;
    _salva('autoplay', v);
  }

  void setNoRepeatAutoplay(bool v) {
    _noRepeatAutoplay = v;
    _salva('no_repeat', v);
  }

  void setFadeSeconds(int v) {
    _fadeSeconds = v.clamp(0, 12);
    _salva('fade', _fadeSeconds);
  }

  void setDataSaver(bool v) {
    _dataSaver = v;
    _salva('data_saver', v);
  }

  void setNerdStats(bool v) {
    _nerdStats = v;
    _salva('nerd_stats', v);
  }

  void setSyncedLyrics(bool v) {
    _syncedLyrics = v;
    _salva('synced_lyrics', v);
  }

  void setBlurLyrics(bool v) {
    _blurLyrics = v;
    _salva('blur_lyrics', v);
  }

  void setCacheLimitMb(int v) {
    _cacheLimitMb = v.clamp(128, 8192);
    _salva('cache_limit', _cacheLimitMb);
  }
}
