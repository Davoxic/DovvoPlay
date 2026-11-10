import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/backup_service.dart';
import '../../services/library_service.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/track_artwork.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(List<Track> tracks, String badgeType, {required VoidCallback onPlayAll}) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 56, color: AppTheme.primary.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text(
                'Nessuna statistica disponibile',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ascolta qualche brano per vedere i tuoi dati aggiornati!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final stats = StatsService.instance;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90, top: 8),
      itemCount: tracks.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tracks.length} brani',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: onPlayAll,
                  icon: const Icon(Icons.shuffle_rounded, size: 16),
                  label: const Text('Riproduci con Shuffle', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          );
        }

        final track = tracks[idx - 1];
        String badgeText = '';
        IconData badgeIcon = Icons.headphones_rounded;
        Color badgeColor = AppTheme.primary;

        if (badgeType == 'plays') {
          final count = stats.getPlayCount(track.id);
          final stat = stats.getStat(track.id);
          final skips = stat?.skipCount ?? 0;
          badgeText = skips > 0
              ? '$count ascolti (≥50%) • $skips skip'
              : '$count ${count == 1 ? 'ascolto (≥50%)' : 'ascolti (≥50%)'}';
          badgeIcon = Icons.local_fire_department_rounded;
          badgeColor = Colors.orangeAccent;
        } else if (badgeType == 'repeats') {
          final count = stats.getRepeatCount(track.id);
          badgeText = '$count ${count == 1 ? 'ripetizione' : 'ripetizioni'}';
          badgeIcon = Icons.repeat_one_rounded;
          badgeColor = AppTheme.secondary;
        } else if (badgeType == 'least') {
          final count = stats.getPlayCount(track.id);
          badgeText = count == 0 ? 'Mai ascoltato' : '$count ascolti';
          badgeIcon = Icons.explore_rounded;
          badgeColor = Colors.tealAccent;
        } else if (badgeType == 'recent') {
          badgeText = 'Recente';
          badgeIcon = Icons.history_rounded;
          badgeColor = Colors.purpleAccent;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              alignment: Alignment.topLeft,
              children: [
                TrackArtwork(
                  url: track.thumbnailUrl,
                  width: 48,
                  height: 48,
                  borderRadius: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(6)),
                  ),
                  child: Text(
                    '#$idx',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            title: Text(
              track.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 11, color: badgeColor),
                      const SizedBox(width: 3),
                      Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary, size: 30),
              onPressed: () {
                AudioPlayerService.instance.playTrack(track, newQueue: tracks);
              },
            ),
            onTap: () {
              AudioPlayerService.instance.playTrack(track, newQueue: tracks);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche d\'Ascolto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Esporta Statistiche & Backup',
            onPressed: () async {
              final file = await BackupService.instance.exportToFile();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup salvato: ${file.path.split('/').last}'),
                    backgroundColor: AppTheme.secondary,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([StatsService.instance, LibraryService.instance]),
        builder: (context, _) {
          final stats = StatsService.instance;
          final allTracks = LibraryService.instance.tracks;

          final mostPlayed = stats.getMostPlayedTracks(allTracks);
          final mostRepeated = stats.getMostRepeatedTracks(allTracks);
          final leastPlayed = stats.getLeastPlayedTracks(allTracks);
          final recentlyPlayed = stats.getRecentlyPlayedTracks(allTracks);

          return Column(
            children: [
              // Grid KPI riepilogativi
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'Tempo Ascolto',
                            stats.formatDurationSummary(),
                            Icons.timer_rounded,
                            AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Ascolti Reali (≥50%)',
                            '${stats.totalPlaysCount}',
                            Icons.headphones_rounded,
                            Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'Brani in Loop',
                            '${stats.totalRepeatsCount}',
                            Icons.repeat_one_rounded,
                            Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Skippate (<50%)',
                            '${stats.totalSkipsCount}',
                            Icons.skip_next_rounded,
                            Colors.redAccent.shade200,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x15FFFFFF)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: AppTheme.secondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Regola 50%: un brano è conteggiato solo se ascoltato per oltre metà durata, altrimenti è considerato skippato.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Tab Bar per le categorie
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Più Ascoltate'),
                  Tab(icon: Icon(Icons.repeat_rounded, size: 18), text: 'Più Ripetute'),
                  Tab(icon: Icon(Icons.explore_rounded, size: 18), text: 'Da Riscoprire'),
                  Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Recenti'),
                ],
              ),

              // Tab Bar Views
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildTrackList(
                      mostPlayed,
                      'plays',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.mostPlayed, baseList: mostPlayed);
                        if (mostPlayed.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(mostPlayed.first);
                        }
                      },
                    ),
                    _buildTrackList(
                      mostRepeated,
                      'repeats',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.standard, baseList: mostRepeated);
                        if (mostRepeated.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(mostRepeated.first);
                        }
                      },
                    ),
                    _buildTrackList(
                      leastPlayed,
                      'least',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.leastPlayed, baseList: leastPlayed);
                        if (leastPlayed.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(leastPlayed.first);
                        }
                      },
                    ),
                    _buildTrackList(
                      recentlyPlayed,
                      'recent',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.recent, baseList: recentlyPlayed);
                        if (recentlyPlayed.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(recentlyPlayed.first);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
