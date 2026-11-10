import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../screens/now_playing_screen.dart';
import '../theme.dart';
import 'track_artwork.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const NowPlayingScreen(),
        transitionsBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  void _animateReset() {
    final start = _dragOffset;
    final anim = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      setState(() {
        _dragOffset = anim.value;
      });
    });
    _animCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final progress = (player.duration.inMilliseconds > 0)
            ? (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () => _openNowPlaying(context),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.primaryDelta!;
            });
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            // Se swipe verso sinistra (prossimo brano)
            if (_dragOffset < -60 || velocity < -250) {
              player.next();
              _animateReset();
            }
            // Se swipe verso destra (brano precedente)
            else if (_dragOffset > 60 || velocity > 250) {
              player.previous();
              _animateReset();
            } else {
              _animateReset();
            }
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
              _openNowPlaying(context);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            // Finestrella leggermente più grande (74px) per maggiore eleganza
            height: 74,
            decoration: BoxDecoration(
              gradient: AppTheme.goldSurfaceGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppTheme.goldBorder, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Progress indicator gold sottile in alto
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),

                  // Contenuto: la copertina e i testi seguono fisicamente il dito durante lo swipe
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Transform.translate(
                            offset: Offset(_dragOffset, 0),
                            child: Row(
                              children: [
                                // Copertina leggermente più grande (50x50)
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    TrackArtwork(
                                      url: track.thumbnailUrl,
                                      width: 50,
                                      height: 50,
                                      borderRadius: 10,
                                    ),
                                    // Bordo sottile sulla copertina
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Titolo, Artista & Equalizer Playing Waveform animato
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Icona con animazione audio playing (barre animate in tempo reale)
                                          _AnimatedPlayingBars(isPlaying: player.isPlaying),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              track.displayTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.displayArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tasto Play/Pause dorato (il tasto avanti è stato rimosso per richiesta)
                        if (player.isBuffering)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                            ),
                          )
                        else
                          IconButton(
                            iconSize: 38,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            icon: Icon(
                              player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: AppTheme.primary,
                            ),
                            onPressed: () {
                              player.togglePlayPause();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icona animata con barre equalizzatore che ballano al ritmo della musica in riproduzione
class _AnimatedPlayingBars extends StatefulWidget {
  final bool isPlaying;
  const _AnimatedPlayingBars({required this.isPlaying});

  @override
  State<_AnimatedPlayingBars> createState() => _AnimatedPlayingBarsState();
}

class _AnimatedPlayingBarsState extends State<_AnimatedPlayingBars> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    // 3 barre ad altezze e frequenze sfasate per effetto onda reale
    const durations = [450, 600, 520];
    const maxHeights = [14.0, 18.0, 12.0];

    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durations[i]),
      );
    });

    _animations = List.generate(3, (i) {
      return Tween<double>(begin: 4.0, end: maxHeights[i]).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      );
    });

    if (widget.isPlaying) {
      _startAnim();
    }
  }

  void _startAnim() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted && widget.isPlaying) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnim() {
    for (final c in _controllers) {
      c.stop();
      c.animateTo(0.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnim();
      } else {
        _stopAnim();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, _) {
            final h = widget.isPlaying ? _animations[i].value : 4.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              width: 3.2,
              height: h,
              decoration: BoxDecoration(
                color: widget.isPlaying ? AppTheme.primary : AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
