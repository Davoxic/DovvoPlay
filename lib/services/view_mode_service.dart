import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LibraryViewMode {
  modernCards,       // 1. Card moderne (Default attuale)
  compactList,       // 2. Lista ultra-compatta ad alta densità
  gridCovers,        // 3. Griglia copertine grandi 2x2
  gridCompact,       // 4. Griglia copertine densa 3x3
  cdJewelCase,       // 5. Custodie CD in plexiglass
  vinylCrate,        // 6. Scaffale Vinili da collezione
  cassetteTape,      // 7. Cassette Retrò Walkman
  minimalTypography, // 8. Tipografia Editoriale
}

class LibraryViewModeInfo {
  final LibraryViewMode mode;
  final String name;
  final String description;
  final IconData icon;

  const LibraryViewModeInfo({
    required this.mode,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class ViewModeService extends ChangeNotifier {
  static final ViewModeService instance = ViewModeService._();
  ViewModeService._() {
    _loadMode();
  }

  static const String _prefKey = 'sborraplay_library_view_mode_v2';

  static const List<LibraryViewModeInfo> modes = [
    LibraryViewModeInfo(
      mode: LibraryViewMode.modernCards,
      name: 'Card Moderne (Default)',
      description: 'Card sagomate con bordo riflettente, durata e miniature ampie',
      icon: Icons.view_agenda_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.compactList,
      name: 'Lista Compatta Streamlined',
      description: 'Righe compatte ad alta densità ideali per navigare centinaia di brani',
      icon: Icons.view_headline_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.gridCovers,
      name: 'Griglia Copertine 2x2',
      description: 'Focus visivo su grandi artwork quadrati con titoli sotto',
      icon: Icons.grid_view_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.gridCompact,
      name: 'Mosaico Denso 3x3',
      description: 'Tante copertine contemporaneamente a colpo d\'occhio',
      icon: Icons.apps_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.cdJewelCase,
      name: 'Custodie CD in Plexiglass',
      description: 'Stile teca jewel case con cerniera trasparente e riflesso specchiato',
      icon: Icons.album_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.vinylCrate,
      name: 'Scaffale Vinili da Collezione',
      description: 'Copertina vintage con vinile scanalato nero che fuoriesce',
      icon: Icons.radio_rounded,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.cassetteTape,
      name: 'Cassette Retrò Walkman',
      description: 'Design nastro magnetico con rotelle e finestrella vintage',
      icon: Icons.album_outlined,
    ),
    LibraryViewModeInfo(
      mode: LibraryViewMode.minimalTypography,
      name: 'Tipografia Editoriale',
      description: 'Layout pulito da rivista musicale con font marcati e micro-badge',
      icon: Icons.format_quote_rounded,
    ),
  ];

  LibraryViewMode _currentMode = LibraryViewMode.modernCards;
  LibraryViewMode get currentMode => _currentMode;

  LibraryViewModeInfo get currentInfo =>
      modes.firstWhere((m) => m.mode == _currentMode, orElse: () => modes.first);

  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_prefKey);
      if (savedName != null) {
        _currentMode = LibraryViewMode.values.firstWhere(
          (m) => m.name == savedName,
          orElse: () => LibraryViewMode.modernCards,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setViewMode(LibraryViewMode mode) async {
    _currentMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }

  void cycleNextMode() {
    final idx = modes.indexWhere((m) => m.mode == _currentMode);
    final nextIdx = (idx + 1) % modes.length;
    setViewMode(modes[nextIdx].mode);
  }
}
