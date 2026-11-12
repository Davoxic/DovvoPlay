import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/history_service.dart';
import '../../services/library_service.dart';
import '../../services/party_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/track_artwork.dart';

/// Cronologia: i brani ascoltati, dal piu' recente, raggruppati per giorno.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const List<String> _mesi = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  static String _giorno(DateTime d) {
    final oggi = DateTime.now();
    final a = DateTime(oggi.year, oggi.month, oggi.day);
    final b = DateTime(d.year, d.month, d.day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    final anno = d.year == oggi.year ? '' : ' ${d.year}';
    return '${d.day} ${_mesi[d.month - 1]}$anno';
  }

  static String _ora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Il brano come sta oggi in libreria: dopo una reinstallazione il
  /// percorso salvato nella cronologia non esiste piu', quello attuale si'.
  static Track _attuale(Track t) {
    if (t.isOnline) return t;
    return LibraryService.instance.getTrackById(t.id) ?? t;
  }

  void _confermaSvuota(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.goldBorder),
        ),
        title: Text(
          'Svuotare la cronologia?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Text(
          'L\'elenco dei brani ascoltati verrà cancellato. Statistiche e Replay non cambiano.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              HistoryService.instance.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Svuota', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HistoryService.instance,
      builder: (context, _) {
        final voci = HistoryService.instance.entries;

        // Righe dell'elenco: un'intestazione per ogni cambio di giorno.
        final righe = <Object>[];
        String? ultimoGiorno;
        for (var i = 0; i < voci.length; i++) {
          final g = _giorno(voci[i].playedAt);
          if (g != ultimoGiorno) {
            righe.add(g);
            ultimoGiorno = g;
          }
          righe.add(i);
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Cronologia'),
            actions: [
              if (voci.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Svuota cronologia',
                  onPressed: () => _confermaSvuota(context),
                ),
            ],
          ),
          bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
          body: voci.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 56,
                          color: AppTheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Ancora niente riprodotto',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'I brani ascoltati appariranno qui',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: righe.length,
                  itemBuilder: (context, r) {
                    final riga = righe[r];
                    if (riga is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                        child: Text(
                          riga,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    final indice = riga as int;
                    final voce = voci[indice];
                    final t = _attuale(voce.track);
                    return Dismissible(
                      key: ValueKey<String>(
                        '${voce.playedAt.microsecondsSinceEpoch}_${voce.track.id}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: Colors.redAccent.withOpacity(0.25),
                        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                      ),
                      onDismissed: (_) => HistoryService.instance.removeAt(indice),
                      child: InkWell(
                        onTap: () {
                          final player = AudioPlayerService.instance;
                          if (PartyService.instance.isGuest) {
                            player.addToQueue(t);
                          } else {
                            player.playTrack(t);
                          }
                        },
                        onLongPress: () =>
                            SongActionsSheet.show(context, t, allowDelete: false),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 2, 6),
                          child: Row(
                            children: [
                              TrackArtwork(
                                url: t.thumbnailUrl,
                                width: 46,
                                height: 46,
                                borderRadius: 8,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.isOnline
                                          ? '${t.displayArtist} • streaming'
                                          : t.displayArtist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _ora(voce.playedAt),
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                tooltip: 'Azioni sul brano',
                                onPressed: () =>
                                    SongActionsSheet.show(context, t, allowDelete: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
