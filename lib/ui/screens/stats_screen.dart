import 'dart:async';
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
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx1) {
        return _ResetStepDialog(
          step: 1,
          title: 'SEI VERAMENTE SICURO?',
          message: 'Stai per cancellare tutte le statistiche di ascolto, i minuti settimanali, le classifiche e i dati storici.',
          buttonText: 'CONFERMA PASSAGGIO 1 (RESET)',
          onConfirmed: () {
            Navigator.pop(ctx1);
            _showFinalResetConfirmationDialog(context);
          },
        );
      },
    );
  }

  void _showFinalResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx2) {
        return _ResetStepDialog(
          step: 2,
          title: 'ULTIMA CONFERMA: AZIONE IRREVERSIBILE!',
          message: 'Tutti i dati registrati secondo per secondo andranno persi per sempre. Sei assolutamente certo di voler procedere?',
          buttonText: 'ELIMINA DEFINITIVAMENTE TUTTO',
          onConfirmed: () async {
            Navigator.pop(ctx2);
            await StatsService.instance.resetAllStats();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tutte le statistiche sono state azzerate con successo.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldBorder),
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

  Widget _buildDailyMoodBanner(DailyMoodOutcome mood) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mood.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mood.color.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mood.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(mood.icon, color: mood.color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mood.title,
                  style: TextStyle(
                    color: mood.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mood.message,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(DayStat today, StatsService stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FASCE D\'ASCOLTO OGGI',
            style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.bold, color: AppTheme.secondary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTierBadge('70-100%', '${today.completedCount}', 'Complete', Colors.greenAccent),
              _buildTierBadge('35-70%', '${today.halfCount}', 'A Metà', Colors.blueAccent),
              _buildTierBadge('15-35%', '${today.briefCount}', 'Poco', Colors.orangeAccent),
              _buildTierBadge('0-15%', '${today.skipsCount}', 'Skippate', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String pct, String count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Text(
            count,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        Text(pct, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
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
                'Ascolta qualche brano per vedere i tuoi dati aggiornati secondo per secondo!',
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
                  icon: const Icon(Icons.shuffle_rounded, size: 16, color: Colors.black),
                  label: const Text('Riproduci con Shuffle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
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
          badgeText = '$count ${count == 1 ? 'ascolto (≥70%)' : 'ascolti (≥70%)'}';
          badgeIcon = Icons.local_fire_department_rounded;
          badgeColor = Colors.orangeAccent;
        } else if (badgeType == 'skips') {
          final count = stats.getSkipCount(track.id);
          badgeText = '$count ${count == 1 ? 'skip (0-15%)' : 'skip (0-15%)'}';
          badgeIcon = Icons.skip_next_rounded;
          badgeColor = Colors.redAccent;
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
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.goldBorder),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Statistiche d\'Ascolto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            tooltip: 'Azzera tutte le statistiche',
            onPressed: () => _showResetConfirmationDialog(context),
          ),
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
          final today = stats.todayStat;
          final mood = stats.getDailyMood();

          final top5 = stats.getTop5PlayedTracks(allTracks);
          final mostSkipped = stats.getMostSkippedTracks(allTracks);
          final mostRepeated = stats.getMostRepeatedTracks(allTracks);
          final leastPlayed = stats.getLeastPlayedTracks(allTracks);
          final recentlyPlayed = stats.getRecentlyPlayedTracks(allTracks);

          return Column(
            children: [
              // Grid KPI riepilogativi
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Column(
                  children: [
                    // Mood del giorno
                    _buildDailyMoodBanner(mood),
                    const SizedBox(height: 10),

                    // Fasce d'ascolto oggi (Complete, Metà, Poco, Skippate)
                    _buildBreakdownRow(today, stats),
                    const SizedBox(height: 10),

                    // Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'Tempo Reale',
                            stats.formatDurationSummary(),
                            Icons.timer_rounded,
                            AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildKpiCard(
                            'Settimana',
                            '${stats.getWeeklyMinutes()} min',
                            Icons.calendar_view_week_rounded,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildKpiCard(
                            'Top Artista',
                            stats.topArtist,
                            Icons.person_rounded,
                            Colors.purpleAccent,
                          ),
                        ),
                      ],
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
                  Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Top 5 Ascoltate (70-100%)'),
                  Tab(icon: Icon(Icons.skip_next_rounded, size: 18), text: 'Più Skippate (0-15%)'),
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
                      top5,
                      'plays',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.mostPlayed, baseList: top5);
                        if (top5.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(top5.first);
                        }
                      },
                    ),
                    _buildTrackList(
                      mostSkipped,
                      'skips',
                      onPlayAll: () {
                        AudioPlayerService.instance.setShuffleMode(ShuffleMode.standard, baseList: mostSkipped);
                        if (mostSkipped.isNotEmpty) {
                          AudioPlayerService.instance.playTrack(mostSkipped.first);
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

class _ResetStepDialog extends StatefulWidget {
  final int step;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onConfirmed;

  const _ResetStepDialog({
    required this.step,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onConfirmed,
  });

  @override
  State<_ResetStepDialog> createState() => _ResetStepDialogState();
}

class _ResetStepDialogState extends State<_ResetStepDialog> {
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _secondsLeft == 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF140707),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  canProceed
                      ? 'Attesa completata. Tasto sbloccato.'
                      : 'Attendi obbligatoriamente $_secondsLeft secondi...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: canProceed ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: canProceed ? widget.onConfirmed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.redAccent.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            canProceed ? widget.buttonText : 'Attendi (${_secondsLeft}s)...',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
