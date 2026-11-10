import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../screens/now_playing_screen.dart';
import '../theme.dart';
import 'track_artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

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

        void openNowPlaying() {
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

        return GestureDetector(
          onTap: openNowPlaying,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -150) {
                // Swipe da destra verso sinistra: Brano successivo (Avanti)
                player.next();
              } else if (details.primaryVelocity! > 150) {
                // Swipe da sinistra verso destra: Brano precedente (Indietro)
                player.previous();
              }
            }
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
              openNowPlaying();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.goldSurfaceGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22FFD700),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppTheme.goldBorder, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Progress indicator gold in alto
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        TrackArtwork(
                          url: track.thumbnailUrl,
                          width: 44,
                          height: 44,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
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
                        if (player.isBuffering)
                          IconButton(
                            icon: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                            ),
                            onPressed: () => player.togglePlayPause(),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: AppTheme.primary,
                              size: 32,
                            ),
                            onPressed: () {
                              player.togglePlayPause();
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded, color: AppTheme.secondary, size: 26),
                          onPressed: () {
                            player.next();
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
