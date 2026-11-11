import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/youtube_track.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_queue_service.dart';
import '../../services/pc_sync_service.dart';
import '../../services/library_service.dart';
import '../../services/youtube_service.dart';
import '../theme.dart';

class YouTubeTile extends StatefulWidget {
  final YouTubeTrack track;

  const YouTubeTile({super.key, required this.track});

  @override
  State<YouTubeTile> createState() => _YouTubeTileState();
}

class _YouTubeTileState extends State<YouTubeTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Chiede se scaricare sul telefono o delegare al PC.
  ///
  /// Il telefono scarica subito ma dipende da YouTube e dalla connessione;
  /// il PC usa yt-dlp, regge formati e playlist che il telefono non gestisce,
  /// e poi invia il file. Se il PC non e' collegato si scarica in locale
  /// senza chiedere, perche' non ci sarebbe alternativa.
  Future<void> _chiediDoveScaricare() async {
    if (!PcSyncService.instance.isConnected) {
      await _downloadOffline();
      return;
    }

    final scelta = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Dove scarico "${widget.track.title}"?',
                maxLines: 2,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.phone_iphone_rounded, color: AppTheme.textPrimary),
              title: Text('Sul telefono',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              subtitle: Text('Scarica subito qui, senza passare dal computer',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'locale'),
            ),
            ListTile(
              leading: Icon(Icons.computer_rounded, color: AppTheme.primary),
              title: Text('Delega al PC',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              subtitle: Text('Lo scarica il computer con yt-dlp e poi lo invia',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'pc'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (scelta == 'locale') {
      await _downloadOffline();
    } else if (scelta == 'pc') {
      DownloadQueueService.instance.enqueue(
        url: 'https://www.youtube.com/watch?v=${widget.track.id}',
        label: widget.track.title,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${widget.track.title}" accodato sul PC'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _downloadOffline() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final file = await YouTubeService.instance.downloadAudioStream(
      widget.track.id,
      widget.track.title,
      onProgress: (p) {
        setState(() => _downloadProgress = p);
      },
    );

    setState(() {
      _isDownloading = false;
    });

    if (file != null) {
      await LibraryService.instance.scanLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scaricato nella libreria: ${widget.track.title}'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } else {
      if (mounted) {
        // Il motivo arriva dal servizio: prima si leggeva solo "Errore
        // durante il download", che non diceva nulla di utile.
        final motivo = YouTubeService.instance.lastFailureReason;
        final pcDisponibile = PcSyncService.instance.isConnected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(motivo ?? 'Errore durante il download.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            action: pcDisponibile
                ? SnackBarAction(
                    label: 'USA IL PC',
                    textColor: Colors.white,
                    onPressed: () {
                      DownloadQueueService.instance.enqueue(
                        url: 'https://www.youtube.com/watch?v=${widget.track.id}',
                        label: widget.track.title,
                      );
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = AudioPlayerService.instance;
    final isCurrent = playerService.currentTrack?.id == 'yt_${widget.track.id}';
    final isBuffering = isCurrent && playerService.isBuffering;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF1A170F) : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppTheme.primary : AppTheme.goldBorder,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.track.thumbnailUrl,
                width: 72,
                height: 54,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(
                  width: 72,
                  height: 54,
                  color: const Color(0x1AFFFFFF),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ),
                ),
                errorWidget: (ctx, url, err) => Container(
                  width: 72,
                  height: 54,
                  color: const Color(0x1AFFFFFF),
                  child: Icon(Icons.music_video_rounded, color: AppTheme.textSecondary),
                ),
              ),
            ),
            if (widget.track.duration > Duration.zero)
              Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(widget.track.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        title: Text(
          widget.track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, size: 12, color: AppTheme.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.track.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2.5,
                    color: AppTheme.secondary,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(Icons.download_rounded, color: AppTheme.textSecondary, size: 20),
                tooltip: 'Salva brano offline',
                onPressed: _chiediDoveScaricare,
              ),
            if (isBuffering)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
          ],
        ),
        onTap: () async {
          await playerService.playYouTubeTrack(widget.track);
          if (context.mounted && playerService.lastErrorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(playerService.lastErrorMessage!),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }
}
