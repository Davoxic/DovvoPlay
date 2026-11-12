import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/party_service.dart';
import '../../services/playback_settings.dart';
import '../theme.dart';
import 'song_actions_sheet.dart';
import 'track_artwork.dart';

/// La coda di riproduzione: cosa suona, cosa viene dopo, e AutoPlay.
///
/// I brani in arrivo si riordinano trascinandoli dalla maniglia, si tolgono
/// con la X e si avviano con un tocco.
class QueueSheet extends StatefulWidget {
  const QueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const QueueSheet(),
    );
  }

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<QueueSheet> {
  int _firma = 0;

  @override
  void initState() {
    super.initState();
    _firma = _calcolaFirma();
    AudioPlayerService.instance.addListener(_playerCambiato);
    PlaybackSettings.instance.addListener(_ridisegna);
  }

  @override
  void dispose() {
    AudioPlayerService.instance.removeListener(_playerCambiato);
    PlaybackSettings.instance.removeListener(_ridisegna);
    super.dispose();
  }

  /// Il player notifica piu' volte al secondo per l'avanzamento: la lista
  /// va ridisegnata solo quando la coda cambia davvero, altrimenti un
  /// trascinamento in corso verrebbe disturbato di continuo.
  int _calcolaFirma() {
    final p = AudioPlayerService.instance;
    return Object.hash(
      p.currentIndex,
      p.queue.length,
      p.isLoadingAutoplay,
      p.isPlaying,
      Object.hashAll(p.queue.map((t) => t.id)),
    );
  }

  void _playerCambiato() {
    final nuova = _calcolaFirma();
    if (nuova != _firma && mounted) {
      setState(() => _firma = nuova);
    }
  }

  void _ridisegna() {
    if (mounted) setState(() {});
  }

  String _durata(Duration d) {
    if (d.inSeconds <= 0) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _riga(
    Track t, {
    required Key key,
    required int indiceAssoluto,
    required int indiceLista,
    required bool modificabile,
  }) {
    final player = AudioPlayerService.instance;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => player.jumpToQueueIndex(indiceAssoluto),
        onLongPress: () => SongActionsSheet.show(context, t, allowDelete: false),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Row(
            children: [
              TrackArtwork(url: t.thumbnailUrl, width: 42, height: 42, borderRadius: 8),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      t.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _durata(t.duration),
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              if (modificabile) ...[
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 19),
                  tooltip: 'Rimuovi dalla coda',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => player.removeQueueAt(indiceAssoluto),
                ),
                ReorderableDragStartListener(
                  index: indiceLista,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ] else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final impostazioni = PlaybackSettings.instance;
    final coda = player.queue;
    final corrente = player.currentTrack;
    final base = player.currentIndex + 1;
    final inArrivo = (base >= 0 && base <= coda.length)
        ? coda.sublist(base)
        : <Track>[];
    final ospite = PartyService.instance.isGuest;

    // Chiavi stabili anche se lo stesso brano compare due volte.
    final visti = <String, int>{};
    final chiavi = <Key>[];
    for (final t in inArrivo) {
      final n = visti[t.id] ?? 0;
      visti[t.id] = n + 1;
      chiavi.add(ValueKey<String>('${t.id}#$n'));
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Coda',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (inArrivo.isNotEmpty && !ospite)
                    TextButton(
                      onPressed: player.clearUpcoming,
                      child: Text(
                        'Svuota',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            if (corrente != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Text(
                  'IN RIPRODUZIONE',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.45)),
                ),
                child: Row(
                  children: [
                    TrackArtwork(
                      url: corrente.thumbnailUrl,
                      width: 46,
                      height: 46,
                      borderRadius: 9,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            corrente.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            corrente.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      player.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Text(
                inArrivo.isEmpty ? 'IN ARRIVO' : 'IN ARRIVO · ${inArrivo.length}',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondary,
                ),
              ),
            ),
            Expanded(
              child: inArrivo.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          player.isLoadingAutoplay
                              ? 'Cerco musica simile...'
                              : impostazioni.autoplay
                                  ? 'Nessun altro brano in coda.\nAutoPlay continuerà con musica simile.'
                                  : 'Nessun altro brano in coda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: inArrivo.length,
                      onReorder: (vecchio, nuovo) {
                        if (ospite) return;
                        var destinazione = nuovo;
                        if (destinazione > vecchio) destinazione -= 1;
                        player.moveQueueItem(base + vecchio, base + destinazione);
                      },
                      itemBuilder: (ctx, i) => _riga(
                        inArrivo[i],
                        key: chiavi[i],
                        indiceAssoluto: base + i,
                        indiceLista: i,
                        modificabile: !ospite,
                      ),
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.goldBorder.withOpacity(0.5)),
                ),
              ),
              child: SwitchListTile(
                dense: true,
                value: impostazioni.autoplay,
                activeColor: AppTheme.primary,
                onChanged: impostazioni.setAutoplay,
                secondary: Icon(Icons.all_inclusive_rounded, color: AppTheme.primary),
                title: Text(
                  'AutoPlay',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Text(
                  'A coda finita continua con musica simile',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
