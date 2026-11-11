import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisualTheme {
  final String id;
  final String name;
  final String description;
  final bool isGradient;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceCard;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color goldBorder;
  final Color goldGlow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final LinearGradient primaryGradient;
  final LinearGradient surfaceGradient;
  final LinearGradient darkGradient;

  const VisualTheme({
    required this.id,
    required this.name,
    required this.description,
    this.isGradient = false,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceCard,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.goldBorder,
    required this.goldGlow,
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFBFB7A3),
    this.textMuted = const Color(0xFF756F62),
    required this.primaryGradient,
    required this.surfaceGradient,
    required this.darkGradient,
  });

  ThemeData toThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: goldBorder, width: 1),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withOpacity(0.2),
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.18),
      ),
    );
  }
}

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._() {
    _loadTheme();
  }

  static const String _prefKey = 'sborraplay_selected_theme_id_v2';

  // --- CATALOGO ALMENO 12 TEMI VISIVI (FISSI E CON GRADIENTI) ---
  static final List<VisualTheme> themes = [
    // 1. DEFAULT: NERO & ORO OLED
    const VisualTheme(
      id: 'oled_gold',
      name: 'Oro & Nero OLED (Default)',
      description: 'Lusso assoluto con sfondo 100% OLED black e oro metallico 24K',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF0B0B0A),
      surfaceLight: Color(0xFF141310),
      surfaceCard: Color(0xFF11100C),
      primary: Color(0xFFFFD700),
      secondary: Color(0xFFD4AF37),
      accent: Color(0xFFFFE57F),
      goldBorder: Color(0x38D4AF37),
      goldGlow: Color(0x33FFD700),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFBFB7A3),
      textMuted: Color(0xFF756F62),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFFFE898), Color(0xFFD4AF37), Color(0xFFAA7C11)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF1C180E), Color(0xFF0D0C08)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF14120B), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 2. CYBERPUNK NEON
    const VisualTheme(
      id: 'cyberpunk_neon',
      name: 'Cyberpunk Neon',
      description: 'Nero profondo con contrasti ciano elettrico e fucsia fluo',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF090814),
      surfaceLight: Color(0xFF131024),
      surfaceCard: Color(0xFF0F0D1C),
      primary: Color(0xFF00F0FF),
      secondary: Color(0xFFFF007F),
      accent: Color(0xFF8A2BE2),
      goldBorder: Color(0x4000F0FF),
      goldGlow: Color(0x3300F0FF),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFA5B4FC),
      textMuted: Color(0xFF6366F1),
      primaryGradient: LinearGradient(
        colors: [Color(0xFF00F0FF), Color(0xFFFF007F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF150F28), Color(0xFF080612)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF120B24), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 3. MIDNIGHT DIAMOND
    const VisualTheme(
      id: 'midnight_diamond',
      name: 'Midnight & Diamante Glaciale',
      description: 'Blu notte abissale con accenti azzurro cristallo puro',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF060B14),
      surfaceLight: Color(0xFF0C1628),
      surfaceCard: Color(0xFF08101E),
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF0284C7),
      accent: Color(0xFFBAE6FD),
      goldBorder: Color(0x3838BDF8),
      goldGlow: Color(0x3338BDF8),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFF94A3B8),
      textMuted: Color(0xFF475569),
      primaryGradient: LinearGradient(
        colors: [Color(0xFF7DD3FC), Color(0xFF0284C7), Color(0xFF0369A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF0E1F38), Color(0xFF040A14)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF0B172A), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 4. EMERALD LUXURY
    const VisualTheme(
      id: 'emerald_luxury',
      name: 'Smeraldo Reale & Ossidiana',
      description: 'Eleganza verde smeraldo brillante e nero grafite',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF05120B),
      surfaceLight: Color(0xFF0A2214),
      surfaceCard: Color(0xFF07190F),
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
      accent: Color(0xFF6EE7B7),
      goldBorder: Color(0x3810B981),
      goldGlow: Color(0x3310B981),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFA7F3D0),
      textMuted: Color(0xFF065F46),
      primaryGradient: LinearGradient(
        colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF0C2B1B), Color(0xFF040F09)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF071D12), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 5. RUBY CRIMSON
    const VisualTheme(
      id: 'ruby_crimson',
      name: 'Rubino Cremisi & Carbone',
      description: 'Rosso rubino pulsante su nero carbone intenso',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF140608),
      surfaceLight: Color(0xFF260C10),
      surfaceCard: Color(0xFF1C090C),
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFDC2626),
      accent: Color(0xFFFCA5A5),
      goldBorder: Color(0x38EF4444),
      goldGlow: Color(0x33EF4444),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFECACA),
      textMuted: Color(0xFF991B1B),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFF991B1B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF2B0E13), Color(0xFF0F0406)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF1C080B), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 6. AMETHYST PURPLE
    const VisualTheme(
      id: 'amethyst_purple',
      name: 'Ametista & Velluto Notturno',
      description: 'Viola nobiliare vellutato e lilla magnetico',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF0D0616),
      surfaceLight: Color(0xFF1A0D2B),
      surfaceCard: Color(0xFF130920),
      primary: Color(0xFFA855F7),
      secondary: Color(0xFF9333EA),
      accent: Color(0xFFD8B4FE),
      goldBorder: Color(0x38A855F7),
      goldGlow: Color(0x33A855F7),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFE9D5FF),
      textMuted: Color(0xFF6B21A8),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFC084FC), Color(0xFF9333EA), Color(0xFF6B21A8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF23103A), Color(0xFF090410)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF150A24), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 7. SUNSET ROSE GOLD
    const VisualTheme(
      id: 'sunset_rosegold',
      name: 'Sunset Rose Gold',
      description: 'Oro rosa sfumato su tramonto arancio e pesca',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF140A0C),
      surfaceLight: Color(0xFF241316),
      surfaceCard: Color(0xFF1C0E11),
      primary: Color(0xFFFB7185),
      secondary: Color(0xFFF43F5E),
      accent: Color(0xFFFDBA74),
      goldBorder: Color(0x38FB7185),
      goldGlow: Color(0x33FB7185),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFFE4E6),
      textMuted: Color(0xFF9F1239),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF2B1419), Color(0xFF0F0608)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF1C0D11), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 8. SOLAR AMBER
    const VisualTheme(
      id: 'solar_amber',
      name: 'Ambra Solare & Magma',
      description: 'Arancione ambra radioso e calore vulcanico',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF140A03),
      surfaceLight: Color(0xFF241407),
      surfaceCard: Color(0xFF1B0E05),
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFD97706),
      accent: Color(0xFFFDE68A),
      goldBorder: Color(0x38F59E0B),
      goldGlow: Color(0x33F59E0B),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFEF3C7),
      textMuted: Color(0xFF92400E),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFD97706), Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF2B170A), Color(0xFF0E0702)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF1C0F05), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 9. TITANIUM SILVER
    const VisualTheme(
      id: 'titanium_silver',
      name: 'Titanio & Argento Satinato',
      description: 'Finitura metallica fredda in alluminio e titanio spaziale',
      isGradient: false,
      background: Color(0xFF000000),
      surface: Color(0xFF121214),
      surfaceLight: Color(0xFF1E1E22),
      surfaceCard: Color(0xFF16161A),
      primary: Color(0xFFE2E8F0),
      secondary: Color(0xFF94A3B8),
      accent: Color(0xFFF8FAFC),
      goldBorder: Color(0x38E2E8F0),
      goldGlow: Color(0x22E2E8F0),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFCBD5E1),
      textMuted: Color(0xFF64748B),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8), Color(0xFF475569)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF1E1F24), Color(0xFF0F1012)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF141518), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 10. MINT MATRIX
    const VisualTheme(
      id: 'mint_matrix',
      name: 'Matrix & Menta Elettrica',
      description: 'Verde menta fluorescente ad alto contrasto per OLED',
      isGradient: false,
      background: Color(0xFF000000),
      surface: Color(0xFF03140F),
      surfaceLight: Color(0xFF08261E),
      surfaceCard: Color(0xFF051D16),
      primary: Color(0xFF14F195),
      secondary: Color(0xFF00C888),
      accent: Color(0xFFA7F3D0),
      goldBorder: Color(0x4014F195),
      goldGlow: Color(0x3314F195),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFF6EE7B7),
      textMuted: Color(0xFF047857),
      primaryGradient: LinearGradient(
        colors: [Color(0xFF6EE7B7), Color(0xFF14F195), Color(0xFF00A36C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF0B2D22), Color(0xFF020E0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF071E17), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 11. OCEAN AQUAMARINE
    const VisualTheme(
      id: 'ocean_aquamarine',
      name: 'Oceano Profondo & Acquamarina',
      description: 'Verde acqua e blu laguna tropicale',
      isGradient: true,
      background: Color(0xFF000000),
      surface: Color(0xFF031214),
      surfaceLight: Color(0xFF072428),
      surfaceCard: Color(0xFF051B1E),
      primary: Color(0xFF06B6D4),
      secondary: Color(0xFF0891B2),
      accent: Color(0xFF67E8F9),
      goldBorder: Color(0x3806B6D4),
      goldGlow: Color(0x3306B6D4),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFA5F3FC),
      textMuted: Color(0xFF155E75),
      primaryGradient: LinearGradient(
        colors: [Color(0xFF22D3EE), Color(0xFF0891B2), Color(0xFF0E7490)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF0A292E), Color(0xFF020C0E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF071B1E), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    // 12. MONOCHROME PURE OLED
    const VisualTheme(
      id: 'monochrome_pure',
      name: 'Monocromatico Pure Minimal',
      description: 'Puro bianco su nero assoluto ad altissimo contrasto',
      isGradient: false,
      background: Color(0xFF000000),
      surface: Color(0xFF0C0C0C),
      surfaceLight: Color(0xFF1A1A1A),
      surfaceCard: Color(0xFF141414),
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFFCCCCCC),
      accent: Color(0xFFEEEEEE),
      goldBorder: Color(0x40FFFFFF),
      goldGlow: Color(0x22FFFFFF),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFB0B0B0),
      textMuted: Color(0xFF666666),
      primaryGradient: LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFF888888)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [Color(0xFF1E1E1E), Color(0xFF0A0A0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGradient: LinearGradient(
        colors: [Color(0xFF141414), Color(0xFF000000)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  ];

  VisualTheme _currentTheme = themes.first;
  VisualTheme get currentTheme => _currentTheme;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null) {
        final found = themes.firstWhere((t) => t.id == savedId, orElse: () => themes.first);
        _currentTheme = found;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Passa al tema successivo, per il cambio rapido da un'icona.
  Future<void> cycleNextTheme() async {
    final i = themes.indexWhere((t) => t.id == _currentTheme.id);
    final next = themes[(i + 1) % themes.length];
    await setTheme(next.id);
  }

  Future<void> setTheme(String themeId) async {
    final found = themes.firstWhere((t) => t.id == themeId, orElse: () => themes.first);
    _currentTheme = found;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, themeId);
    } catch (_) {}
  }
}
