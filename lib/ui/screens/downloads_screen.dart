import 'package:flutter/material.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/cache_service.dart';
import '../../services/playback_settings.dart';
import '../../services/yt_download_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_artwork.dart';

/// Download dei brani in streaming e spazio occupato dalle cache.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int? _byteCache;

  static const List<int> _limiti = [256, 512, 1024, 2048, 4096, 8192];

  @override
  void initState() {
    super.initState();
    _misura();
  }

  Future<void> _misura() async {
    final b = await CacheService.instance.songCacheBytes();
    if (mounted) setState(() => _byteCache = b);
  }

  String _etichettaLimite(int mb) => mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB';

  Widget _sezione(String titolo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        titolo,
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: AppTheme.secondary,
        ),
      ),
    );
  }

  Widget _rigaDownload(YtDownload voce) {
    final servizio = YtDownloadService.instance;
    String stato;
    Color colore = AppTheme.textSecondary;
    switch (voce.state) {
      case YtDownloadState.queued:
        stato = 'In coda';
        break;
      case YtDownloadState.downloading:
        stato = 'Download in corso · ${(voce.progress * 100).round()}%';
        colore = AppTheme.primary;
        break;
      case YtDownloadState.done:
        stato = 'Scaricato';
        colore = const Color(0xFF4CAF50);
        break;
      case YtDownloadState.failed:
        stato = voce.error ?? 'Non riuscito';
        colore = Colors.redAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          TrackArtwork(url: voce.track.thumbnailUrl, width: 46, height: 46, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voce.track.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stato,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colore, fontSize: 11.5),
                ),
                if (voce.state == YtDownloadState.downloading) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: voce.progress > 0 ? voce.progress : null,
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (voce.state == YtDownloadState.failed)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 20),
              tooltip: 'Riprova',
              onPressed: () => servizio.retry(voce),
            ),
          if (voce.state != YtDownloadState.downloading)
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 19),
              tooltip: 'Togli dall\'elenco',
              onPressed: () => servizio.remove(voce),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  void _scegliLimite() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'Limite cache brani',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Superato il limite, i brani ascoltati da più tempo vengono tolti dalla cache.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
            for (final mb in _limiti)
              ListTile(
                dense: true,
                title: Text(
                  _etichettaLimite(mb),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5),
                ),
                trailing: PlaybackSettings.instance.cacheLimitMb == mb
                    ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                    : null,
                onTap: () async {
                  PlaybackSettings.instance.setCacheLimitMb(mb);
                  Navigator.pop(ctx);
                  await CacheService.instance.enforceLimit(tieni: _idInRiproduzione());
                  _misura();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Il file del brano che sta suonando non va tolto da sotto al lettore.
  String? _idInRiproduzione() {
    final t = AudioPlayerService.instance.currentTrack;
    if (t == null || !t.id.startsWith('yt_')) return null;
    return t.id.substring(3);
  }

  Widget _voceImpostazione({
    required IconData icona,
    required String titolo,
    required String sottotitolo,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icona, color: AppTheme.primary),
      title: Text(
        titolo,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        sottotitolo,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        YtDownloadService.instance,
        PlaybackSettings.instance,
      ]),
      builder: (context, _) {
        final servizio = YtDownloadService.instance;
        final voci = servizio.items;
        final finiti = voci.any((v) =>
            v.state == YtDownloadState.done || v.state == YtDownloadState.failed);
        final inCoda = voci.any((v) => v.state == YtDownloadState.queued);
        final cache = _byteCache;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Download')),
          bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _sezione(
                servizio.pendingCount > 0
                    ? 'DOWNLOAD · ${(servizio.overallProgress * 100).round()}%'
                    : 'DOWNLOAD',
              ),
              if (voci.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Nessun download in corso.\n'
                    'Per scaricare un brano in streaming apri il suo menu e scegli '
                    '"Scarica sul telefono"; da un album o una playlist online puoi '
                    'scaricarli tutti insieme.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.45),
                  ),
                )
              else ...[
                for (final v in voci) _rigaDownload(v),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      if (inCoda)
                        TextButton(
                          onPressed: servizio.cancelQueued,
                          child: const Text(
                            'Annulla quelli in coda',
                            style: TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      const Spacer(),
                      if (finiti)
                        TextButton(
                          onPressed: servizio.clearFinished,
                          child: Text(
                            'Togli i completati',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              _sezione('ARCHIVIAZIONE'),
              _voceImpostazione(
                icona: Icons.music_note_rounded,
                titolo: 'Svuota cache brani',
                sottotitolo: cache == null
                    ? 'Misurazione...'
                    : 'Audio tenuto dallo streaming: ${CacheService.formatBytes(cache)}',
                onTap: () async {
                  await CacheService.instance.clearSongCache(tieni: _idInRiproduzione());
                  await _misura();
                  AppNotice.show('Cache dei brani svuotata');
                },
              ),
              _voceImpostazione(
                icona: Icons.sd_storage_rounded,
                titolo: 'Limite cache brani',
                sottotitolo:
                    'Fino a ${_etichettaLimite(PlaybackSettings.instance.cacheLimitMb)} di audio per riascolti immediati',
                onTap: _scegliLimite,
              ),
              _voceImpostazione(
                icona: Icons.image_rounded,
                titolo: 'Svuota cache immagini',
                sottotitolo: 'Libera lo spazio usato dalle copertine scaricate dalla rete',
                onTap: () async {
                  await CacheService.instance.clearImageCache();
                  AppNotice.show('Cache delle immagini svuotata');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
