import 'package:flutter/material.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../theme.dart';
import 'playlist_detail_screen.dart';

class PlaylistTab extends StatelessWidget {
  const PlaylistTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (context, _) {
        final lib = LibraryService.instance;
        final playlists = lib.playlists;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Playlist'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 28),
                tooltip: 'Crea nuova playlist',
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            ],
          ),
          body: playlists.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: playlists.length + 1,
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      return _buildHeader(context, playlists.length);
                    }
                    final pl = playlists[idx - 1];
                    final count = pl.trackIds.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldSurfaceGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.goldBorder, width: 1),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33FFD700),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          pl.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$count ${count == 1 ? 'brano' : 'brani'}',
                            style: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppTheme.primary,
                                  size: 34,
                                ),
                                tooltip: 'Riproduci playlist',
                                onPressed: () {
                                  final tracks = lib.getTracksForPlaylist(pl);
                                  if (tracks.isNotEmpty) {
                                    AudioPlayerService.instance.playTrack(tracks.first, newQueue: tracks);
                                  }
                                },
                              ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary,
                              size: 22,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: pl),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int totalPlaylists) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.goldSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18FFD700),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 1.5),
              color: const Color(0x22FFD700),
            ),
            child: const Icon(Icons.library_music_rounded, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LE TUE RACCOLTE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalPlaylists ${totalPlaylists == 1 ? 'Playlist creata' : 'Playlist create'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showCreatePlaylistDialog(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nuova', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              elevation: 4,
              shadowColor: AppTheme.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0x28FFD700), Colors.transparent],
                ),
                border: Border.all(color: AppTheme.goldBorder, width: 1),
              ),
              child: const Icon(
                Icons.queue_music_rounded,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nessuna Playlist',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Organizza i tuoi brani preferiti creando raccolte personalizzate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Crea la tua prima Playlist',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: AppTheme.primary.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.goldBorder, width: 1.2),
        ),
        title: const Text(
          'Nuova Playlist',
          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nome della playlist...',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.goldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await LibraryService.instance.createPlaylist(name);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Crea', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
