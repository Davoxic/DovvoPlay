import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../theme.dart';
import 'track_artwork.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTap,
  });

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerService = AudioPlayerService.instance;
    final isCurrent = playerService.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playerService.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppTheme.primary.withOpacity(0.5) : const Color(0x14FFFFFF),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            TrackArtwork(
              url: track.thumbnailUrl,
              width: 46,
              height: 46,
              borderRadius: 10,
              placeholderIcon: track.isOnline ? Icons.public_rounded : Icons.music_note_rounded,
            ),
            if (isCurrent)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withOpacity(0.45),
                ),
                child: Icon(
                  isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
          ],
        ),
        title: Text(
          track.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${track.displayArtist}${track.isOnline ? " • YouTube" : ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(track.duration),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
              color: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'playlist') {
                  _showAddToPlaylistSheet(context, track);
                } else if (val == 'delete') {
                  LibraryService.instance.deleteTrack(track);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Text('Aggiungi a playlist'),
                    ],
                  ),
                ),
                if (!track.isOnline)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Elimina file'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: onTap ??
            () {
              playerService.playTrack(track, newQueue: queue);
            },
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
              const Text(
                'Aggiungi a Playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Nessuna playlist creata.', style: TextStyle(color: AppTheme.textSecondary)),
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
                        subtitle: Text('${p.trackIds.length} brani', style: const TextStyle(color: AppTheme.textSecondary)),
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
