import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/track_artwork.dart';

enum StatPeriodView { day, month, year }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatPeriodView _selectedView = StatPeriodView.day;
  DateTime _selectedDate = DateTime.now();

  void _previousPeriod() {
    setState(() {
      if (_selectedView == StatPeriodView.day) {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      } else if (_selectedView == StatPeriodView.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
      }
    });
  }

  void _nextPeriod() {
    final now = DateTime.now();
    setState(() {
      if (_selectedView == StatPeriodView.day) {
        final next = _selectedDate.add(const Duration(days: 1));
        if (!next.isAfter(now)) _selectedDate = next;
      } else if (_selectedView == StatPeriodView.month) {
        final next = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        if (!next.isAfter(now)) _selectedDate = next;
      } else {
        final next = DateTime(_selectedDate.year + 1, 1, 1);
        if (!next.isAfter(now)) _selectedDate = next;
      }
    });
  }

  void _resetToCurrent() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx1) {
        return _ResetStepDialog(
          step: 1,
          title: 'SEI VERAMENTE SICURO?',
          message:
              'Stai per cancellare tutte le statistiche di ascolto, i secondi registrati, i conteggi skip e le classifiche storiche.',
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
          message:
              'Tutti i secondi e i riepiloghi andranno persi per sempre. Sei assolutamente certo di voler cancellare tutto?',
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

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final stats = StatsService.instance;
    final library = LibraryService.instance.tracks;

    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) {
        // Calcola PeriodStat in base alla vista selezionata
        final PeriodStat period;
        if (_selectedView == StatPeriodView.day) {
          period = stats.getStatForDay(_selectedDate);
        } else if (_selectedView == StatPeriodView.month) {
          period = stats.getStatForMonth(_selectedDate.year, _selectedDate.month);
        } else {
          period = stats.getStatForYear(_selectedDate.year);
        }

        final mood = period.getMood();
        final now = DateTime.now();
        final isToday = _selectedView == StatPeriodView.day &&
            _selectedDate.year == now.year &&
            _selectedDate.month == now.month &&
            _selectedDate.day == now.day;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Reportistica & Statistiche',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Selettore Vista: Giorno / Mese / Anno
                _buildViewModeSelector(),

                const SizedBox(height: 12),

                // 2. Navigatore Periodo (< Data Corrente >)
                _buildPeriodNavigator(period.label, isCurrent: isToday),

                const SizedBox(height: 16),

                // 3. Banner Mood & Esito del Periodo
                _buildMoodBanner(mood),

                const SizedBox(height: 14),

                // 4. KPI Tempo di Ascolto e Brani Totali
                _buildKpiSection(period),

                const SizedBox(height: 18),

                // 5. Le 4 Categorie di Ascolto (0-15%, 15-35%, 35-70%, 70-100%)
                _buildCategoriesCard(period),

                const SizedBox(height: 20),

                // 6. Top 5 Brani più ascoltati (70% - 100%) del periodo
                _buildRankingsSection(
                  title: '🏆 Top 5 Brani più Ascoltati (70-100%)',
                  subtitle: 'Canzoni ascoltate con entusiasmo in questo periodo',
                  trackIdsWithCounts: period.trackPlays,
                  library: library,
                  emptyMessage: 'Nessun brano ha superato il 70% di ascolto.',
                  isCompleted: true,
                ),

                const SizedBox(height: 18),

                // 7. Brani più skippati (0% - 15%) del periodo
                _buildRankingsSection(
                  title: '⏭️ Brani più Skippati (0-15%)',
                  subtitle: 'Canzoni saltate nei primi secondi',
                  trackIdsWithCounts: period.trackSkips,
                  library: library,
                  emptyMessage: 'Nessun brano skippato in questo periodo!',
                  isCompleted: false,
                ),

                const SizedBox(height: 18),

                // 8. Top Artisti del Periodo
                _buildTopArtistsCard(period, library),

                const SizedBox(height: 32),

                // 9. Reset Totale Statistiche (2 step, 5 secondi di attesa obbligatoria)
                Center(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          'RESET STATISTICHE & STORICO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cancella tutti i secondi registrati e le classifiche con 2 passaggi di sicurezza obbligatori.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 20),
                          label: const Text('AZZERA TUTTE LE STATISTICHE', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showResetConfirmationDialog(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildViewModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSegmentButton(StatPeriodView.day, '📅 GIORNO'),
          _buildSegmentButton(StatPeriodView.month, '🗓️ MESE'),
          _buildSegmentButton(StatPeriodView.year, '📆 ANNO'),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(StatPeriodView view, String title) {
    final isSelected = _selectedView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedView = view;
            _selectedDate = DateTime.now();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.black : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodNavigator(String label, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: AppTheme.primary, size: 28),
            onPressed: _previousPeriod,
          ),
          GestureDetector(
            onTap: _resetToCurrent,
            child: Column(
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (!isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Tocca per tornare a oggi',
                      style: TextStyle(fontSize: 10, color: AppTheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isCurrent ? Colors.white24 : AppTheme.primary,
              size: 28,
            ),
            onPressed: isCurrent ? null : _nextPeriod,
          ),
        ],
      ),
    );
  }

  Widget _buildMoodBanner(DailyMoodOutcome mood) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mood.color.withOpacity(0.2),
            AppTheme.surfaceCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mood.color.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mood.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection(PeriodStat period) {
    final formattedTime = _formatDuration(period.listeningSeconds);
    final totalListened = period.halfCount + period.completedCount;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'TEMPO D\'ASCOLTO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  '${period.listeningSeconds} sec registrati',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.goldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.headphones_rounded, color: const Color(0xFF64FFDA), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'BRANI ASCOLTATI',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalListened',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64FFDA),
                  ),
                ),
                Text(
                  '${period.skipsCount} saltati (0-15%)',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesCard(PeriodStat period) {
    final total = period.totalInteractions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FASCE D\'ASCOLTO & PERCENTUALI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.secondary,
                ),
              ),
              Text(
                'Tot: $total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildCategoryRow(
            emoji: '✅',
            title: 'Ascoltata Completa',
            range: '70% - 100%',
            count: period.completedCount,
            total: total,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 10),

          _buildCategoryRow(
            emoji: '🌓',
            title: 'Ascoltata a Metà',
            range: '35% - 70%',
            count: period.halfCount,
            total: total,
            color: const Color(0xFF64B5F6),
          ),
          const SizedBox(height: 10),

          _buildCategoryRow(
            emoji: '⏳',
            title: 'Ascoltata Poco',
            range: '15% - 35%',
            count: period.briefCount,
            total: total,
            color: const Color(0xFFFFB74D),
          ),
          const SizedBox(height: 10),

          _buildCategoryRow(
            emoji: '⏭️',
            title: 'Skippata Rapida',
            range: '0% - 15%',
            count: period.skipsCount,
            total: total,
            color: const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required String emoji,
    required String title,
    required String range,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? (count / total) : 0.0;
    final pctStr = (pct * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 6),
                Text(
                  '($range)',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
            Text(
              '$count brani ($pctStr%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsSection({
    required String title,
    required String subtitle,
    required Map<String, int> trackIdsWithCounts,
    required List<Track> library,
    required String emptyMessage,
    required bool isCompleted,
  }) {
    // Ordina per conteggio decrescente
    final sortedEntries = trackIdsWithCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topList = sortedEntries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          if (topList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            ...List.generate(topList.length, (idx) {
              final entry = topList[idx];
              final track = library.firstWhere(
                (t) => t.id == entry.key,
                orElse: () => Track(
                  id: entry.key,
                  title: 'Brano rimosso',
                  artist: 'Sconosciuto',
                  album: '',
                  duration: Duration.zero,
                  filePath: null,
                ),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: idx == 0 ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TrackArtwork(
                      url: track.thumbnailUrl,
                      width: 38,
                      height: 38,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            track.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppTheme.primary.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value} ${isCompleted ? 'ascolti' : 'skip'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppTheme.primary : Colors.redAccent,
                        ),
                      ),
                    ),
                    if (isCompleted && track.filePath != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary, size: 26),
                        onPressed: () {
                          AudioPlayerService.instance.playTrack(track, newQueue: library);
                        },
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopArtistsCard(PeriodStat period, List<Track> library) {
    final Map<String, int> artistPlays = {};
    for (var entry in period.trackPlays.entries) {
      final track = library.firstWhere(
        (t) => t.id == entry.key,
        orElse: () => Track(id: '', title: '', artist: 'Sconosciuto', album: '', duration: Duration.zero),
      );
      if (track.artist.isNotEmpty) {
        artistPlays[track.displayArtist] = (artistPlays[track.displayArtist] ?? 0) + entry.value;
      }
    }

    final sortedArtists = artistPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_external_on_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '🎤 TOP ARTISTI DEL PERIODO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topArtists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Nessun dato artisti disponibile.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            )
          else
            ...List.generate(topArtists.length, (idx) {
              final a = topArtists[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(
                      '#${idx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: idx == 0 ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a.key,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ),
                    Text(
                      '${a.value} brani ascoltati',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                    ),
                  ],
                ),
              );
            }),
        ],
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
      if (mounted) {
        setState(() {
          if (_secondsLeft > 1) {
            _secondsLeft--;
          } else {
            _secondsLeft = 0;
            _timer?.cancel();
          }
        });
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
    return AlertDialog(
      backgroundColor: const Color(0xFF160B0B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'PASSAGGIO ${widget.step} DI 2',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_secondsLeft > 0)
            Center(
              child: Text(
                'Attendi $_secondsLeft secondi prima di confermare...',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ANNULLA'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondsLeft == 0 ? Colors.redAccent : Colors.red.shade900.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _secondsLeft == 0 ? widget.onConfirmed : null,
                child: Text(
                  _secondsLeft > 0 ? 'ATTENDI (${_secondsLeft}s)' : widget.buttonText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
