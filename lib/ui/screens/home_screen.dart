import 'package:flutter/material.dart';
import '../../services/update_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import 'library_tab.dart';
import 'playlist_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Schermata di default su cui si apre: Libreria al centro (indice 1)
  int _currentIndex = 1;

  final List<Widget> _tabs = const [
    PlaylistTab(),  // Sinistra
    LibraryTab(),   // Centro (Default)
    SettingsTab(),  // Destra
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });
  }

  Future<void> _checkAutoUpdate() async {
    // Verifica silenziosa in background all'avvio
    final release = await UpdateService.instance.checkForUpdates(isSilent: true);
    if (!mounted || release == null || !release.isNewer) return;

    // Mostra il dialog con le novità e il download con 1 tocco
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _UpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(
            top: BorderSide(
              color: AppTheme.goldBorder,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.background,
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.queue_music_rounded),
              activeIcon: Icon(Icons.queue_music_rounded, color: AppTheme.primary),
              label: 'Playlist',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_music_rounded),
              activeIcon: Icon(Icons.library_music_rounded, color: AppTheme.primary),
              label: 'Libreria',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
              label: 'Impostazioni',
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppReleaseInfo release;
  const _UpdateDialog({required this.release});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _status = '';
  bool _downloadFinished = false;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _status = 'Avvio download del pacchetto .ipa...';
    });

    final file = await UpdateService.instance.downloadIpa(
      widget.release,
      onProgress: (p, s) {
        if (mounted) {
          setState(() {
            _progress = p;
            _status = s;
          });
        }
      },
    );

    if (mounted) {
      if (file != null) {
        setState(() {
          _downloading = false;
          _downloadFinished = true;
        });
        // Apri subito lo Share Sheet per firmare con ESign/Scarlet/Files
        await UpdateService.instance.shareIpa(file);
      } else {
        setState(() {
          _downloading = false;
          _status = 'Errore download. Prova da Impostazioni o GitHub.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.goldBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.goldGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nuovo Aggiornamento!',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.goldBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Attuale: v${UpdateService.currentVersion}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white54),
                  const SizedBox(width: 8),
                  Text(
                    widget.release.tagName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Cosa c\'è di nuovo:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.release.body.isNotEmpty ? widget.release.body : 'Miglioramenti generali e ottimizzazioni.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ),
            if (_downloading || _downloadFinished) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: AppTheme.primary,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(height: 6),
              Text(
                _status,
                style: TextStyle(fontSize: 11, color: AppTheme.secondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Più tardi', style: TextStyle(color: AppTheme.textMuted)),
        ),
        if (!_downloadFinished)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.file_download_rounded, size: 18),
            label: Text(_downloading ? 'Download in corso...' : 'Scarica & Firma'),
            onPressed: _downloading ? null : _startDownload,
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Firma con App...'),
            onPressed: () {
              final file = UpdateService.instance.downloadedIpa;
              if (file != null) {
                UpdateService.instance.shareIpa(file);
              }
            },
          ),
      ],
    );
  }
}
