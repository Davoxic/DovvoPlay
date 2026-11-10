import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/view_mode_service.dart';
import '../theme.dart';
import 'track_artwork.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final VoidCallback? onTap;
  final LibraryViewMode? mode;
  final int index;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTap,
    this.mode,
    this.index = 0,
  });

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = mode ?? ViewModeService.instance.currentMode;
    final playerService = AudioPlayerService.instance;
    final isCurrent = playerService.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playerService.isPlaying;

    switch (viewMode) {
      case LibraryViewMode.compactList:
        return _buildCompactList(context, isCurrent, isPlaying, playerService);
      case LibraryViewMode.gridCovers:
        return _buildGridCard(context, isCurrent, isPlaying, playerService, compact: false);
      case LibraryViewMode.gridCompact:
        return _buildGridCard(context, isCurrent, isPlaying, playerService, compact: true);
      case LibraryViewMode.cdJewelCase:
        return _buildCdJewelCase(context, isCurrent, isPlaying, playerService);
      case LibraryViewMode.vinylCrate:
        return _buildVinylCrate(context, isCurrent, isPlaying, playerService);
      case LibraryViewMode.cassetteTape:
        return _buildCassetteTape(context, isCurrent, isPlaying, playerService);
      case LibraryViewMode.minimalTypography:
        return _buildMinimalTypography(context, isCurrent, isPlaying, playerService);
      case LibraryViewMode.modernCards:
        return _buildModernCard(context, isCurrent, isPlaying, playerService);
    }
  }

  // 1. MODERN CARDS (Default attuale lussuoso)
  Widget _buildModernCard(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.surfaceLight : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppTheme.primary : AppTheme.goldBorder,
          width: isCurrent ? 1.4 : 0.8,
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
                  color: Colors.black.withOpacity(0.55),
                ),
                child: Icon(
                  isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded,
                  color: AppTheme.primary,
                  size: 24,
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
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(track.duration),
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            _buildOptionsButton(context),
          ],
        ),
        onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      ),
    );
  }

  // 2. COMPACT LIST (Massima densità stile iTunes)
  Widget _buildCompactList(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    return InkWell(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppTheme.goldBorder.withOpacity(0.5), width: 0.5)),
        ),
        child: Row(
          children: [
            TrackArtwork(
              url: track.thumbnailUrl,
              width: 34,
              height: 34,
              borderRadius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              _formatDuration(track.duration),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            _buildOptionsButton(context),
          ],
        ),
      ),
    );
  }

  // 3 & 4. GRID COVERS (Griglia album quadrata)
  Widget _buildGridCard(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService, {
    required bool compact,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent ? AppTheme.surfaceLight : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? AppTheme.primary : AppTheme.goldBorder,
            width: isCurrent ? 1.5 : 0.8,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TrackArtwork(
                      url: track.thumbnailUrl,
                      borderRadius: 10,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: AppTheme.primary,
                          size: compact ? 26 : 38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              track.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 11 : 13,
              ),
            ),
            Text(
              track.displayArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. CD JEWEL CASE (Custodia in plexiglass argentato)
  Widget _buildCdJewelCase(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    return GestureDetector(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D11),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCurrent ? AppTheme.primary : const Color(0x40FFFFFF), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isCurrent ? AppTheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cerniera plexiglass
            Container(
              width: 8,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            // Disco CD rotondo che spunta
            Stack(
              alignment: Alignment.center,
              children: [
                TrackArtwork(
                  url: track.thumbnailUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 6,
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'CD AUDIO • ${track.displayArtist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded, color: AppTheme.primary, size: 22),
            _buildOptionsButton(context),
          ],
        ),
      ),
    );
  }

  // 6. VINYL CRATE (Copertina cartonata con vinile che sporge a destra)
  Widget _buildVinylCrate(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    return GestureDetector(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrent ? AppTheme.primary : AppTheme.goldBorder),
        ),
        child: Row(
          children: [
            // Copertina LP
            TrackArtwork(
              url: track.thumbnailUrl,
              width: 54,
              height: 54,
              borderRadius: 4,
            ),
            // Vinile nero scanalato che fuoriesce
            Transform.translate(
              offset: const Offset(-8, 0),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141414),
                  border: Border.all(color: const Color(0xFF2E2E2E), width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent ? AppTheme.primary : Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LP 33 RPM • ${track.displayArtist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(_formatDuration(track.duration), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            _buildOptionsButton(context),
          ],
        ),
      ),
    );
  }

  // 7. CASSETTE TAPE (Design cassetta retrò Walkman)
  Widget _buildCassetteTape(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    return GestureDetector(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF181614),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCurrent ? AppTheme.primary : const Color(0x33D4AF37), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SIDE A',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(_formatDuration(track.duration), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                _buildOptionsButton(context),
              ],
            ),
            const SizedBox(height: 6),
            // Finestrella nastro centrale con due bobine
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary, width: 2))),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.brown.shade800,
                    ),
                  ),
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary, width: 2))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 8. MINIMAL TYPOGRAPHY (Stile editoriale rivista musicale)
  Widget _buildMinimalTypography(
    BuildContext context,
    bool isCurrent,
    bool isPlaying,
    AudioPlayerService playerService,
  ) {
    final idxStr = (index + 1).toString().padLeft(2, '0');
    return InkWell(
      onTap: onTap ?? () => playerService.playTrack(track, newQueue: queue),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              idxStr,
              style: TextStyle(
                color: isCurrent ? AppTheme.primary : AppTheme.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _formatDuration(track.duration),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            _buildOptionsButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
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
        PopupMenuItem(
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
                'Aggiungi a playlist',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nessuna playlist creata.', style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (c, i) {
                      final pl = playlists[i];
                      final alreadyIn = pl.trackIds.contains(track.id);
                      return ListTile(
                        leading: Icon(Icons.playlist_play_rounded, color: AppTheme.primary),
                        title: Text(pl.name, style: TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text('${pl.trackIds.length} brani', style: TextStyle(color: AppTheme.textSecondary)),
                        trailing: alreadyIn
                            ? Icon(Icons.check_rounded, color: AppTheme.primary)
                            : Icon(Icons.add_rounded, color: AppTheme.textSecondary),
                        onTap: () async {
                          if (alreadyIn) {
                            await LibraryService.instance.removeTrackFromPlaylist(pl.id, track.id);
                          } else {
                            await LibraryService.instance.addTrackToPlaylist(pl.id, track.id);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
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
