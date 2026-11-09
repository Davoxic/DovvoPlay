import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/library_service.dart';
import '../theme.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (context, _) {
        final lib = LibraryService.instance;
        final totalSize = lib.tracks.fold<int>(0, (acc, t) => acc + (t.fileSize ?? 0));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Impostazioni'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            children: [
              // Statistiche Libreria
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.18),
                      AppTheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATISTICHE LIBRERIA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Brani Totali', '${lib.tracks.length}'),
                        _buildStatItem('Playlist', '${lib.playlists.length}'),
                        _buildStatItem('Spazio Audio', _formatBytes(totalSize)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sezione Azioni Libreria
              _buildSectionHeader('GESTIONE MUSICA'),
              _buildSettingTile(
                icon: Icons.sync_rounded,
                title: 'Aggiorna / Risansiona Libreria',
                subtitle: 'Rileva file musicali aggiunti o cancellati manualmente',
                onTap: () async {
                  await lib.scanLibrary();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Libreria aggiornata!')),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Sezione Backup
              _buildSectionHeader('BACKUP E RIPRISTINO'),
              _buildSettingTile(
                icon: Icons.upload_file_rounded,
                title: 'Esporta Backup Playlist',
                subtitle: 'Copia negli appunti il backup JSON di tutte le playlist',
                onTap: () {
                  final jsonStr = lib.exportBackupJson();
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup JSON copiato negli appunti!')),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.download_for_offline_rounded,
                title: 'Importa Backup Playlist',
                subtitle: 'Ripristina playlist da un testo JSON o file di backup',
                onTap: () => _showImportBackupDialog(context),
              ),

              const SizedBox(height: 20),

              // Sezione Informazioni
              _buildSectionHeader('INFORMAZIONI'),
              _buildSettingTile(
                icon: Icons.info_outline_rounded,
                title: 'SborraPlay v1.0.0',
                subtitle: 'Edizione Flutter & YouTube Explode • Open Source',
                onTap: null,
              ),
              _buildSettingTile(
                icon: Icons.lock_open_rounded,
                title: 'Nessuna firma o account richiesto',
                subtitle: 'L\'app non traccia dati personali e non richiede registrazione.',
                onTap: null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: onTap != null ? const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary) : null,
        onTap: onTap,
      ),
    );
  }

  void _showImportBackupDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Importa Backup JSON', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Incolla qui il contenuto del file JSON esportato in precedenza:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{\n  "app": "SborraPlay", ...\n}',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Color(0x1A000000),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final str = textCtrl.text.trim();
              if (str.isNotEmpty) {
                try {
                  await LibraryService.instance.importBackupJson(str);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup importato con successo!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore formato JSON: $e')),
                  );
                }
              }
            },
            child: const Text('Importa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
