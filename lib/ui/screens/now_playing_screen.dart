import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../theme.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF23163A),
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
              final currentPos = player.position.inMilliseconds.toDouble().clamp(0.0, maxDuration > 0 ? maxDuration : 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    // Top bar with dismiss button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: AppTheme.textPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Column(
                          children: [
                            const Text(
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
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add_rounded, size: 26, color: AppTheme.textPrimary),
                          onPressed: () => _showAddToPlaylistSheet(context, track),
                        ),
                      ],
                    ),

                    const Spacer(flex: 1),

                    // Artwork
                    Hero(
                      tag: 'current_artwork',
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.78,
                        height: MediaQuery.of(context).size.width * 0.78,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.25),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: track.thumbnailUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: track.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (c, u, e) => Container(
                                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                                    child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                                  child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
                                ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Info Traccia
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
                        inactiveTrackColor: const Color(0x28FFFFFF),
                        thumbColor: Colors.white,
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
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          Text(
                            _formatTime(player.duration),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: player.isShuffle ? AppTheme.primary : AppTheme.textSecondary,
                            size: 24,
                          ),
                          onPressed: () => player.toggleShuffle(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 36, color: AppTheme.textPrimary),
                          onPressed: () => player.previous(),
                        ),
                        GestureDetector(
                          onTap: () => player.togglePlayPause(),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: player.isBuffering
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : Icon(
                                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 36, color: AppTheme.textPrimary),
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
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, dynamic track) {
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
              const Text(
                'Aggiungi a Playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
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
                        leading: const Icon(Icons.queue_music_rounded, color: AppTheme.primary),
                        title: Text(p.name, style: const TextStyle(color: AppTheme.textPrimary)),
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
