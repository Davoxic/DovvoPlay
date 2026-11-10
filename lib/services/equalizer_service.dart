import 'dart:convert';
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

  void _applyEqualizer() {
    // Adatta il volume audio per compensare il boost delle frequenze ed evitare distorsioni
    try {
      final player = AudioPlayerService.instance.player;
      if (!_isEnabled) {
        player.setVolume(1.0);
        return;
      }

      // Calcola guadagno medio e applica headroom dinamico
      final maxGain = _bandGains.reduce((a, b) => a > b ? a : b);
      final avgGain = _bandGains.reduce((a, b) => a + b) / _bandGains.length;
      final totalBoost = (maxGain + _preampGain).clamp(-12.0, 12.0);

      // Headroom per evitare clipping digitale a volumi alti
      double volumeMultiplier = 1.0;
      if (totalBoost > 0) {
        volumeMultiplier = 1.0 / (1.0 + (totalBoost * 0.04));
      } else if (totalBoost < 0) {
        volumeMultiplier = (1.0 + (avgGain * 0.03)).clamp(0.4, 1.0);
      }
      player.setVolume(volumeMultiplier.clamp(0.2, 1.0));
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
