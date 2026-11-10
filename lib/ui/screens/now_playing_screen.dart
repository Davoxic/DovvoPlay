import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/animation_theme_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/animated_track_transition.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/track_artwork.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showShuffleModeSheet(BuildContext context, AudioPlayerService player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Modalità Shuffle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: ShuffleMode.values.map((mode) {
                      final isSelected = player.shuffleMode == mode;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: isSelected ? AppTheme.primary.withOpacity(0.18) : Colors.transparent,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            mode.icon,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          mode.description,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22)
                            : null,
                        onTap: () {
                          player.setShuffleMode(mode);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(mode.icon, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Shuffle: ${mode.label}'),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppTheme.surfaceLight,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 600.0);
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 100 || (details.primaryVelocity != null && details.primaryVelocity! > 600)) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dragOffset = 0.0;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF16130B),
                  AppTheme.background,
                  AppTheme.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListenableBuilder(
                listenable: AudioPlayerService.instance,
                builder: (context, _) {
                  final player = AudioPlayerService.instance;
                  final track = player.currentTrack;

                  if (track == null) {
                    return const Center(child: Text('Nessun brano in riproduzione'));
                  }

                  final maxDuration = player.duration.inMilliseconds.toDouble();
                  final currentPos = player.position.inMilliseconds
                      .toDouble()
                      .clamp(0.0, maxDuration > 0 ? maxDuration : 1.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Column(
                      children: [
                        // Pillola indicatore swipe-down
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Top bar con dismiss button e playlist
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: AppTheme.textPrimary),
                              tooltip: 'Riduci a icona (scorri verso il basso)',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Column(
                              children: [
                                Text(
                                  'IN RIPRODUZIONE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  track.isOnline ? 'YouTube Stream' : 'Libreria Locale',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.tune_rounded, size: 22, color: AppTheme.primary),
                                  tooltip: 'Equalizzatore audio',
                                  onPressed: () => EqualizerSheet.show(context),
                                ),
                                IconButton(
                                  icon: Icon(Icons.playlist_add_rounded, size: 26, color: AppTheme.textPrimary),
                                  tooltip: 'Aggiungi a playlist',
                                  onPressed: () => _showAddToPlaylistSheet(context, track),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Spacer(flex: 1),

                        // Logo/Badge Transizione Animata: Tappabile & Swipabile al volo
                        ListenableBuilder(
                          listenable: AnimationThemeService.instance,
                          builder: (context, _) {
                            final anim = AnimationThemeService.instance.currentTheme;
                            return GestureDetector(
                              onTap: () {
                                AnimationThemeService.instance.cycleNext();
                              },
                              onHorizontalDragEnd: (details) {
                                if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                                  AnimationThemeService.instance.cycleNext();
                                } else {
                                  AnimationThemeService.instance.cyclePrevious();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.goldBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.goldGlow.withOpacity(0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(anim.icon, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      anim.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'TAP/SWIPE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Artwork con Animazione Selezionabile (16+ Temi di Transizione)
                        Hero(
                          tag: 'current_artwork',
                          child: AnimatedTrackTransition(
                            trackKey: track.id,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.78,
                              height: MediaQuery.of(context).size.width * 0.78,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppTheme.goldBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    blurRadius: 36,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: TrackArtwork(
                                url: track.thumbnailUrl,
                                width: MediaQuery.of(context).size.width * 0.78,
                                height: MediaQuery.of(context).size.width * 0.78,
                                borderRadius: 28,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Info Traccia & Badge Shuffle
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.displayArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (player.shuffleMode != ShuffleMode.off)
                              GestureDetector(
                                onTap: () => _showShuffleModeSheet(context, player),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(player.shuffleMode.icon, size: 14, color: AppTheme.primary),
                                      const SizedBox(width: 5),
                                      Text(
                                        player.shuffleMode.label,
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (player.lastErrorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    player.lastErrorMessage!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Slider di avanzamento
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: const Color(0x33D4AF37),
                            thumbColor: AppTheme.primary,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentPos,
                            min: 0.0,
                            max: maxDuration > 0 ? maxDuration : 1.0,
                            onChanged: (val) {
                              player.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),

                        // Timestamp
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(player.position),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              Text(
                                _formatTime(player.duration),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Shuffle Button interattivo con selezione modalità e minuti ascoltati oggi
                            ListenableBuilder(
                              listenable: StatsService.instance,
                              builder: (context, _) {
                                final todayMins = StatsService.instance.todayStat.listeningSeconds ~/ 60;
                                return GestureDetector(
                                  onTap: () => _showShuffleModeSheet(context, player),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: player.isShuffle ? AppTheme.primary.withOpacity(0.18) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: player.isShuffle ? AppTheme.primary : Colors.white12,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          player.shuffleMode.icon,
                                          color: player.isShuffle ? AppTheme.primary : AppTheme.textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${todayMins}m oggi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: player.isShuffle ? AppTheme.primary : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.skip_previous_rounded, size: 36, color: AppTheme.textPrimary),
                              onPressed: () => player.previous(),
                            ),
                            GestureDetector(
                              onTap: () => player.togglePlayPause(),
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x55FFD700),
                                      blurRadius: 22,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: player.isBuffering
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                        )
                                      : Icon(
                                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          size: 40,
                                          color: Colors.black,
                                        ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.skip_next_rounded, size: 36, color: AppTheme.textPrimary),
                              onPressed: () => player.next(),
                            ),
                            IconButton(
                              icon: Icon(
                                player.loopMode == PlayerLoopMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: player.loopMode != PlayerLoopMode.off
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                                size: 24,
                              ),
                              onPressed: () => player.toggleLoopMode(),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final playlists = LibraryService.instance.playlists;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aggiungi a Playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Nessuna playlist presente.', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, idx) {
                      final p = playlists[idx];
                      return ListTile(
                        leading: Icon(Icons.queue_music_rounded, color: AppTheme.primary),
                        title: Text(p.name, style: TextStyle(color: AppTheme.textPrimary)),
                        onTap: () {
                          LibraryService.instance.addTrackToPlaylist(p.id, track.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Aggiunto a "${p.name}"')),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
