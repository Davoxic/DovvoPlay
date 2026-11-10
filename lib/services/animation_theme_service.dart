import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackTransitionType {
  slideHorizontal,
  slideVertical,
  fadeDissolve,
  explosionZoom,
  implosionShrink,
  vinylSpin,
  cube3d,
  fallingDrop,
  floatingBubble,
  glitchCyber,
  portalRipple,
  cardStack,
  pageCurl,
  heartbeatPulse,
  kaleidoscope,
  carousel3d,
}

class TrackAnimationTheme {
  final TrackTransitionType type;
  final String name;
  final String description;
  final IconData icon;

  const TrackAnimationTheme({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class AnimationThemeService extends ChangeNotifier {
  static final AnimationThemeService instance = AnimationThemeService._();
  AnimationThemeService._() {
    _loadAnimationTheme();
  }

  static const String _prefKey = 'sborraplay_track_transition_type_v2';

  static const List<TrackAnimationTheme> animations = [
    TrackAnimationTheme(
      type: TrackTransitionType.slideHorizontal,
      name: 'Scorrimento Orizzontale',
      description: 'Scivolamento fluido a destra o sinistra come uno swipe naturale',
      icon: Icons.swap_horiz_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.fadeDissolve,
      name: 'Dissolvenza Incrociata Cinematica',
      description: 'Transizione vellutata e progressiva a scomparsa',
      icon: Icons.opacity_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.explosionZoom,
      name: 'Esplosione & Zoom Shockwave',
      description: 'La copertina esplode verso l\'osservatore con bagliore energetico',
      icon: Icons.flare_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.implosionShrink,
      name: 'Implosione & Risucchio al Centro',
      description: 'Il brano precedente viene risucchiato e il nuovo sboccia dal centro',
      icon: Icons.filter_center_focus_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.vinylSpin,
      name: 'Rotazione Disco in Vinile 360°',
      description: 'Gira a tutta velocità come un vinile appoggiato sul piatto',
      icon: Icons.album_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.cube3d,
      name: 'Rotazione Cubo 3D',
      description: 'Effetto rotazione prospettica su faccia cubica tridimensionale',
      icon: Icons.view_in_ar_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.fallingDrop,
      name: 'Caduta Gravitazionale & Rimbalzo',
      description: 'Il nuovo brano cade dall\'alto con fisica elastica d\'impatto',
      icon: Icons.arrow_downward_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.floatingBubble,
      name: 'Fluttuazione Ascendente Spaziale',
      description: 'Sale dal basso ondeggiando morbidamente a zero gravità',
      icon: Icons.bubble_chart_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.slideVertical,
      name: 'Ascensore Verticale',
      description: 'Scorrimento pulito dall\'alto verso il basso',
      icon: Icons.swap_vert_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.glitchCyber,
      name: 'Glitch Cibernetico',
      description: 'Distorsione digitale cyberpunk con micro-spostamenti rapidi',
      icon: Icons.electric_bolt_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.portalRipple,
      name: 'Onda Concentrica Portale',
      description: 'Onda d\'urto ad anello concentrico che deforma lo spazio',
      icon: Icons.blur_circular_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.cardStack,
      name: 'Mazzo di Carte Sfogliate',
      description: 'La copertina scivola in diagonale svelando la carta sottostante',
      icon: Icons.style_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.pageCurl,
      name: 'Sfoglia Pagina Libro',
      description: 'Effetto voltapagina angolare 3D d\'archivio',
      icon: Icons.auto_stories_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.heartbeatPulse,
      name: 'Battito Cardiaco a Ritmo',
      description: 'Doppia pulsazione cardiaca sincrona con la musica',
      icon: Icons.favorite_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.kaleidoscope,
      name: 'Caleidoscopio Stellare',
      description: 'Rotazione geometrica ad apertura angolare prismatica',
      icon: Icons.star_border_purple500_rounded,
    ),
    TrackAnimationTheme(
      type: TrackTransitionType.carousel3d,
      name: 'Coverflow Tridimensionale',
      description: 'Scivolamento in profondità sull\'asse Z con prospettiva angolata',
      icon: Icons.view_carousel_rounded,
    ),
  ];

  TrackTransitionType _selectedType = TrackTransitionType.explosionZoom;
  TrackTransitionType get selectedType => _selectedType;

  TrackAnimationTheme get currentTheme =>
      animations.firstWhere((a) => a.type == _selectedType, orElse: () => animations.first);

  Future<void> _loadAnimationTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_prefKey);
      if (savedName != null) {
        _selectedType = TrackTransitionType.values.firstWhere(
          (t) => t.name == savedName,
          orElse: () => TrackTransitionType.explosionZoom,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setAnimationType(TrackTransitionType type) async {
    _selectedType = type;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, type.name);
    } catch (_) {}
  }
}
