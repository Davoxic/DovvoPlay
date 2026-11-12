import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/likes_service.dart';
import '../../services/party_service.dart';
import '../../services/view_mode_service.dart';
import '../../services/yt_download_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';

/// "Brani che ti piacciono": tutto cio' a cui e' stato messo il cuore,
/// file locali e brani in streaming insieme.
class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  void _riproduci(List<Track> brani, {bool casuale = false}) {
    if (brani.isEmpty) return;
    if (PartyService.instance.isGuest) {
      AppNotice.show("Nel party e' l'host a scegliere i brani");
      return;
    }
    final player = AudioPlayerService.instance;
    if (casuale) {
      final mescolati = List<Track>.from(brani)..shuffle(Random());
      player.setShuffleMode(ShuffleMode.off);
      player.playTrack(mescolati.first, newQueue: mescolati);
    } else {
      player.playTrack(brani.first, newQueue: brani);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LikesService.instance,
        LibraryService.instance,
        AudioPlayerService.instance.currentTrackId,
      ]),
      builder: (context, _) {
        final brani = LikesService.instance.tracks;
        final online = brani.where((t) => t.isOnline).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Brani che ti piacciono'),
            actions: [
              if (online.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Scarica i brani in streaming',
                  onPressed: () {
                    final n = YtDownloadService.instance.enqueueAll(online);
                    AppNotice.show(
                      n == 0
                          ? 'Questi brani sono già scaricati o in coda'
                          : '$n brani in download: li trovi in Download',
                    );
                  },
                ),
            ],
          ),
          bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
          body: brani.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 56,
                          color: AppTheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nessun brano piaciuto',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tocca il cuore su un brano per salvarlo qui',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: brani.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldSurfaceGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.goldBorder, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${brani.length} ${brani.length == 1 ? 'brano' : 'brani'}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    online.isEmpty
                                        ? 'Tutti sul telefono'
                                        : '${online.length} in streaming',
                                    style: TextStyle(color: AppTheme.secondary, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.shuffle_rounded, color: AppTheme.primary),
                              tooltip: 'Riproduzione casuale',
                              onPressed: () => _riproduci(brani, casuale: true),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(12),
                              ),
                              onPressed: () => _riproduci(brani),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final t = brani[i - 1];
                    return TrackTile(
                      track: t,
                      queue: brani,
                      // Sempre a riga: i layout a griglia della libreria qui
                      // non avrebbero una griglia in cui stare.
                      mode: LibraryViewMode.modernCards,
                      onTap: PartyService.instance.isGuest
                          ? () => AudioPlayerService.instance.addToQueue(t)
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }
}
