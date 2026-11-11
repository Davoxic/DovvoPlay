import 'package:flutter/material.dart';
import '../../services/download_queue_service.dart';
import '../../services/pc_sync_service.dart';
import '../theme.dart';

/// Due frecce che girano, da mettere nella barra in alto di ogni schermata.
///
/// Restano visibili per tutta la durata del lavoro col computer: prima
/// l'indicatore stava solo dentro la card di PC Companion, quindi uscendo da
/// quella schermata non si sapeva piu' se la sincronizzazione fosse in corso.
/// Quando non c'e' nulla da mostrare occupa zero spazio.
class SyncIndicator extends StatefulWidget {
  /// Se true mostra anche il contatore x/y accanto alle frecce.
  final bool conContatore;

  const SyncIndicator({super.key, this.conContatore = true});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _giro;

  @override
  void initState() {
    super.initState();
    _giro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PcSyncService.instance,
        DownloadQueueService.instance,
      ]),
      builder: (context, _) {
        final sync = PcSyncService.instance;
        final coda = DownloadQueueService.instance;
        final attivo = sync.isSyncing || coda.isWorking;

        if (!attivo) return const SizedBox.shrink();

        final p = sync.syncProgress;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _giro,
                child: Icon(Icons.sync_rounded, size: 18, color: AppTheme.primary),
              ),
              if (widget.conContatore && p != null) ...[
                const SizedBox(width: 5),
                Text(
                  p.counter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
