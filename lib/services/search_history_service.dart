import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le ultime ricerche fatte nel catalogo online.
class SearchHistoryService extends ChangeNotifier {
  static final SearchHistoryService instance = SearchHistoryService._();
  SearchHistoryService._();

  static const String _chiave = 'dovvoplay_search_history_v1';
  static const int _massimo = 15;

  final List<String> _voci = [];

  List<String> get items => List.unmodifiable(_voci);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvate = prefs.getStringList(_chiave);
      if (salvate != null) {
        _voci
          ..clear()
          ..addAll(salvate);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Avviso ricerche recenti: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chiave, _voci);
    } catch (_) {}
  }

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _voci.removeWhere((v) => v.toLowerCase() == q.toLowerCase());
    _voci.insert(0, q);
    if (_voci.length > _massimo) {
      _voci.removeRange(_massimo, _voci.length);
    }
    notifyListeners();
    _save();
  }

  void remove(String query) {
    _voci.remove(query);
    notifyListeners();
    _save();
  }

  void clear() {
    _voci.clear();
    notifyListeners();
    _save();
  }
}
