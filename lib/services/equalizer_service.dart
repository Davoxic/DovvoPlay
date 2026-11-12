import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_player_service.dart';

class EqPreset {
  final String id;
  final String name;
  final String emoji;
  final List<double> gains; // 5 bands in dB (-12.0 to +12.0)

  const EqPreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.gains,
  });
}

class EqualizerService extends ChangeNotifier {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._() {
    _loadFromPrefs();
  }

  static const String _prefsKey = 'sborraplay_eq_settings_v1';

  static const List<String> bandLabels = [
    '60 Hz\nSub',
    '230 Hz\nBass',
    '910 Hz\nMid',
    '3.6 kHz\nHigh',
    '14 kHz\nAir',
  ];

  static const List<EqPreset> presets = [
    EqPreset(id: 'flat', name: 'Flat (Neutro)', emoji: '🎵', gains: [0, 0, 0, 0, 0]),
    EqPreset(id: 'bass', name: 'Bass Boost', emoji: '🔊', gains: [7.0, 5.0, 0.0, 0.0, 0.0]),
    EqPreset(id: 'rock', name: 'Rock', emoji: '🎸', gains: [5.0, 3.0, -1.0, 3.0, 6.0]),
    EqPreset(id: 'pop', name: 'Pop', emoji: '🎤', gains: [-1.0, 2.0, 5.0, 3.0, -1.0]),
    EqPreset(id: 'hiphop', name: 'Hip-Hop', emoji: '🎧', gains: [6.0, 4.0, 0.0, 2.0, 3.0]),
    EqPreset(id: 'electronic', name: 'Electronic', emoji: '⚡', gains: [6.0, 4.0, 0.0, 3.0, 5.0]),
    EqPreset(id: 'jazz', name: 'Jazz & Warm', emoji: '🎷', gains: [3.0, 2.0, 1.0, 2.0, 4.0]),
    EqPreset(id: 'vocal', name: 'Vocal Boost', emoji: '🗣️', gains: [-3.0, 0.0, 6.0, 4.0, -1.0]),
    EqPreset(id: 'acoustic', name: 'Acoustic', emoji: '🎻', gains: [3.0, 2.0, 2.0, 4.0, 3.0]),
    EqPreset(id: 'custom', name: 'Personalizzato', emoji: '🛠️', gains: [0, 0, 0, 0, 0]),
  ];

  bool _isEnabled = true;
  String _selectedPresetId = 'flat';
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _preampGain = 0.0; // dB (-6 to +6)

  bool get isEnabled => _isEnabled;
  String get selectedPresetId => _selectedPresetId;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  double get preampGain => _preampGain;

  EqPreset get currentPreset =>
      presets.firstWhere((p) => p.id == _selectedPresetId, orElse: () => presets[0]);

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _applyEqualizer();
    notifyListeners();
    _saveToPrefs();
  }

  void selectPreset(String presetId) {
    final preset = presets.firstWhere((p) => p.id == presetId, orElse: () => presets[0]);
    _selectedPresetId = preset.id;
    if (preset.id != 'custom') {
      _bandGains = List.from(preset.gains);
    }
    _applyEqualizer();
    notifyListeners();
    _saveToPrefs();
  }

  void setBandGain(int index, double gainDb) {
    if (index < 0 || index >= _bandGains.length) return;
    _bandGains[index] = gainDb.clamp(-12.0, 12.0);
    _selectedPresetId = 'custom';
    _applyEqualizer();
    notifyListeners();
    _saveToPrefs();
  }

  void setPreampGain(double gainDb) {
    _preampGain = gainDb.clamp(-6.0, 6.0);
    _applyEqualizer();
    notifyListeners();
    _saveToPrefs();
  }

  void resetToFlat() {
    selectPreset('flat');
    _preampGain = 0.0;
    _applyEqualizer();
    notifyListeners();
    _saveToPrefs();
  }

  /// ATTENZIONE: questo NON e' un equalizzatore per bande.
  ///
  /// just_audio espone un equalizzatore solo su Android (AndroidEqualizer);
  /// su iOS non esiste un equivalente, e un vero filtro a 5 bande
  /// richiederebbe AVAudioUnitEQ in codice nativo Swift. Nel progetto non e'
  /// praticabile cosi' com'e', perche' la pipeline di build esegue
  /// "flutter create . --platforms ios" a ogni compilazione e rigenera la
  /// cartella ios/, cancellando qualunque codice nativo aggiunto a mano.
  ///
  /// Finche' resta cosi', i cursori agiscono solo sul livello di uscita.
  /// Prima questa funzione ABBASSAVA il volume quando si alzava una banda
  /// (headroom anti-clipping), quindi "alzare i bassi" rendeva la musica piu'
  /// silenziosa: era il motivo per cui sembrava rotto. Ora il livello segue il
  /// guadagno medio e il preamp, in modo prevedibile.
  void _applyEqualizer() {
    try {
      // Il volume passa dal player, che ci moltiplica sopra la dissolvenza
      // tra i brani: impostandolo qui direttamente i due si annullerebbero.
      final player = AudioPlayerService.instance;
      if (!_isEnabled) {
        player.setBaseVolume(1.0);
        return;
      }

      final avgGain = _bandGains.reduce((a, b) => a + b) / _bandGains.length;
      final totale = (avgGain + _preampGain).clamp(-12.0, 12.0);

      // dB -> fattore lineare, limitato a 1.0 perche' just_audio non amplifica
      // oltre il volume originale: in positivo si resta a 1.0 senza penalizzare.
      final fattore = totale >= 0
          ? 1.0
          : math.pow(10, totale / 20.0).toDouble();
      player.setBaseVolume(fattore.clamp(0.15, 1.0));
    } catch (_) {}
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _isEnabled = data['isEnabled'] as bool? ?? true;
        _selectedPresetId = data['selectedPresetId']?.toString() ?? 'flat';
        _preampGain = (data['preampGain'] as num?)?.toDouble() ?? 0.0;
        final list = (data['bandGains'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
        if (list != null && list.length == 5) {
          _bandGains = list;
        }
        notifyListeners();
        _applyEqualizer();
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'isEnabled': _isEnabled,
        'selectedPresetId': _selectedPresetId,
        'preampGain': _preampGain,
        'bandGains': _bandGains,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {}
  }
}
