import 'package:flutter/material.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../theme.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (context, _) {
        final lib = LibraryService.instance;
        final currentPl = lib.playlists.firstWhere(
          (p) => p.id == widget.playlist.id,
          orElse: () => widget.playlist,
        );
        final tracks = lib.getTracksForPlaylist(currentPl);

        return Scaffold(
          appBar: AppBar(
            title: Text(currentPl.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                tooltip: 'Elimina playlist',
                onPressed: () {
                  _confirmDeletePlaylist(context, currentPl);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Header Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.2),
                      AppTheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentPl.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tracks.length} brani',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tracks.isNotEmpty)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () {
                          AudioPlayerService.instance.playTrack(tracks.first, newQueue: tracks);
                        },
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                  ],
                ),
              ),

              // Lista brani
              Expanded(
                child: tracks.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun brano in questa playlist.\nAggiungi brani dalla Libreria o da YouTube!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: tracks.length,
                        itemBuilder: (context, idx) {
                          final t = tracks[idx];
                          return Dismissible(
                            key: ValueKey(t.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              color: Colors.redAccent.withOpacity(0.3),
                              child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                            ),
                            onDismissed: (_) {
                              lib.removeTrackFromPlaylist(currentPl.id, t.id);
                            },
                            child: TrackTile(track: t, queue: tracks),
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

  void _confirmDeletePlaylist(BuildContext context, Playlist pl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminare playlist?'),
        content: Text('Sei sicuro di voler eliminare "${pl.name}"? I file audio originali non verranno cancellati.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              LibraryService.instance.deletePlaylist(pl.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
