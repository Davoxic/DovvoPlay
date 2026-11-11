import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/animation_theme_service.dart';

class AnimatedTrackTransition extends StatelessWidget {
  final Widget child;
  final String trackKey;
  final Duration duration;

  const AnimatedTrackTransition({
    super.key,
    required this.child,
    required this.trackKey,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AnimationThemeService.instance,
      builder: (context, _) {
        final animType = AnimationThemeService.instance.selectedType;

        return AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget currentChild, Animation<double> animation) {
            return _buildTransition(animType, currentChild, animation);
          },
          child: KeyedSubtree(
            key: ValueKey<String>(trackKey),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildTransition(
    TrackTransitionType type,
    Widget child,
    Animation<double> animation,
  ) {
    switch (type) {
      case TrackTransitionType.slideHorizontal:
        final offset = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: offset, child: FadeTransition(opacity: animation, child: child));

      case TrackTransitionType.slideVertical:
        final offset = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: offset, child: FadeTransition(opacity: animation, child: child));

      case TrackTransitionType.fadeDissolve:
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );

      case TrackTransitionType.explosionZoom:
        final scale = Tween<double>(begin: 0.2, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.elasticOut));
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          ),
        );

      case TrackTransitionType.implosionShrink:
        final scale = Tween<double>(begin: 1.8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );

      case TrackTransitionType.vinylSpin:
        final rotation = Tween<double>(begin: -1.0, end: 0.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final scale = Tween<double>(begin: 0.7, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return RotationTransition(
          turns: rotation,
          child: ScaleTransition(scale: scale, child: child),
        );

      case TrackTransitionType.cube3d:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final angle = (1.0 - val) * math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: w,
              ),
            );
          },
          child: child,
        );

      case TrackTransitionType.fallingDrop:
        final offset = Tween<Offset>(
          begin: const Offset(0.0, -1.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.bounceOut));
        return SlideTransition(position: offset, child: child);

      case TrackTransitionType.floatingBubble:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final yOffset = (1.0 - val) * 80;
            final xOffset = math.sin(val * math.pi * 2) * 12;
            return Transform.translate(
              offset: Offset(xOffset, yOffset),
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + (val * 0.15),
                  child: w,
                ),
              ),
            );
          },
          child: child,
        );

      case TrackTransitionType.glitchCyber:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final jitter = val < 0.8 ? math.sin(val * 40) * 8 : 0.0;
            return Transform.translate(
              offset: Offset(jitter, 0),
              child: Opacity(
                opacity: (val * 1.5).clamp(0.0, 1.0),
                child: w,
              ),
            );
          },
          child: child,
        );

      case TrackTransitionType.portalRipple:
        final scale = Tween<double>(begin: 0.1, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutExpo));
        final turns = Tween<double>(begin: 0.25, end: 0.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return RotationTransition(
          turns: turns,
          child: ScaleTransition(scale: scale, child: child),
        );

      case TrackTransitionType.cardStack:
        final offset = Tween<Offset>(
          begin: const Offset(0.7, -0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
        return SlideTransition(position: offset, child: child);

      case TrackTransitionType.pageCurl:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final angle = (1.0 - val) * math.pi / 3;
            return Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-angle),
              child: Opacity(opacity: val.clamp(0.0, 1.0), child: w),
            );
          },
          child: child,
        );

      case TrackTransitionType.heartbeatPulse:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final pulse = 1.0 + (math.sin(val * math.pi * 3).abs() * 0.15);
            return Transform.scale(scale: pulse, child: Opacity(opacity: val.clamp(0.0, 1.0), child: w));
          },
          child: child,
        );

      case TrackTransitionType.kaleidoscope:
        final rotation = Tween<double>(begin: 0.5, end: 0.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint));
        final scale = Tween<double>(begin: 0.3, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint));
        return RotationTransition(
          turns: rotation,
          child: ScaleTransition(scale: scale, child: child),
        );

      case TrackTransitionType.carousel3d:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, w) {
            final val = animation.value;
            final offset = (1.0 - val) * 200;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..translate(0.0, 0.0, -offset)
                ..rotateY((1.0 - val) * 0.6),
              child: Opacity(opacity: val.clamp(0.0, 1.0), child: w),
            );
          },
          child: child,
        );
    }
  }
}
