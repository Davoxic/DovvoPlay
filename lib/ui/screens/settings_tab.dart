import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/backup_service.dart';
import '../../services/library_service.dart';
import '../theme.dart';
import 'stats_screen.dart';
import 'wifi_tab.dart';
import 'youtube_tab.dart';

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
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Impostazioni'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              // Header Gold Edition
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldSurfaceGradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.goldBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14FFD700),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary, width: 1.5),
                            color: const Color(0x22FFD700),
                          ),
                          child: const Icon(Icons.star_rounded, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SBORRAPLAY GOLD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppTheme.secondary,
                              ),
                            ),
                            Text(
                              'OLED Black Edition',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x1AD4AF37)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Brani', '${lib.tracks.length}'),
                          Container(width: 1, height: 28, color: const Color(0x22D4AF37)),
                          _buildStatItem('Playlist', '${lib.playlists.length}'),
                          Container(width: 1, height: 28, color: const Color(0x22D4AF37)),
                          _buildStatItem('Spazio', _formatBytes(totalSize)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SEZIONE FONTI & TRASFERIMENTO
              _buildSectionHeader('FONTI & TRASFERIMENTO'),
              _buildFeatureTile(
                icon: Icons.youtube_searched_for_rounded,
                iconGradient: const LinearGradient(colors: [Color(0xFFFF4B4B), Color(0xFFFF8A00)]),
                title: 'YouTube Music Online',
                subtitle: 'Cerca brani, streaming audio AAC istantaneo e download offline',
                badgeText: 'ONLINE',
                badgeColor: const Color(0xFFFF5252),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const YouTubeTab()),
                  );
                },
              ),
              _buildFeatureTile(
                icon: Icons.wifi_tethering_rounded,
                iconGradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0091EA)]),
                title: 'Trasferimento Wi-Fi PC',
                subtitle: 'Carica canzoni dal computer tramite browser (senza cavi né iTunes)',
                badgeText: 'WIRELESS',
                badgeColor: const Color(0xFF00E5FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WifiTab()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // SEZIONE ASCOLTI & INTELLIGENZA
              _buildSectionHeader('STATISTICHE & LIBRERIA'),
              _buildSettingTile(
                icon: Icons.insights_rounded,
                title: 'Statistiche e Abitudini d\'Ascolto',
                subtitle: 'Classifica ascolti reali (≥50%), brani in loop, skip e tempo totale',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.sync_rounded,
                title: 'Riscansiona File Locali',
                subtitle: 'Rileva file musicali aggiunti ed estrai copertine ID3 / M4A',
                onTap: () async {
                  await lib.scanLibrary();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Libreria aggiornata e copertine estratte!'),
                        backgroundColor: AppTheme.secondary,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // SEZIONE SALVATAGGIO & BACKUP COMPLETO
              _buildSectionHeader('SALVATAGGIO & BACKUP COMPLETO'),
              _buildSettingTile(
                icon: Icons.upload_file_rounded,
                title: 'Esporta Backup Completo (File & Appunti)',
                subtitle: 'Salva statistiche, abitudini d\'ascolto, cronologia e playlist in JSON',
                onTap: () async {
                  try {
                    final file = await BackupService.instance.exportToFile();
                    final jsonStr = BackupService.instance.createBackupJsonString();
                    await Clipboard.setData(ClipboardData(text: jsonStr));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Backup salvato su file e negli appunti!\n(${file.path.split('/').last})',
                          ),
                          backgroundColor: AppTheme.secondary,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Errore salvataggio backup: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.folder_open_rounded,
                title: 'Ripristina Backup da File (.json)',
                subtitle: 'Scegli il file di backup salvato per ripristinare ascolti e playlist',
                onTap: () async {
                  try {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (res != null && res.files.single.path != null) {
                      final file = File(res.files.single.path!);
                      final result = await BackupService.instance.importFromFile(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.success
                                  ? 'Ripristinati ${result.restoredStats} ascolti e ${result.restoredPlaylists} playlist!'
                                  : result.message,
                            ),
                            backgroundColor: result.success ? AppTheme.secondary : Colors.redAccent,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Errore apertura file: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.content_paste_rounded,
                title: 'Ripristina Backup da Testo o Appunti',
                subtitle: 'Incolla il contenuto JSON copiato in precedenza',
                onTap: () => _showImportBackupDialog(context),
              ),

              const SizedBox(height: 20),

              // SEZIONE INFORMAZIONI
              _buildSectionHeader('INFORMAZIONI APP'),
              _buildSettingTile(
                icon: Icons.info_outline_rounded,
                title: 'SborraPlay Gold v1.0.0',
                subtitle: 'Tema Oro & Nero OLED • Riproduzione Locale & YouTube',
                onTap: null,
              ),
              _buildSettingTile(
                icon: Icons.shield_rounded,
                title: '100% Locale e Privato',
                subtitle: 'Nessun account richiesto, nessun tracciamento dei tuoi dati',
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3,
          color: AppTheme.secondary,
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Gradient iconGradient,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.goldSurfaceGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder, width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10FFD700),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.5)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 24),
        onTap: onTap,
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
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1CD4AF37)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0x18FFD700),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x28FFD700)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
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
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.goldBorder),
        ),
        title: const Text('Importa Backup JSON', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: Color(0x33000000),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.goldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final str = textCtrl.text.trim();
              if (str.isNotEmpty) {
                final result = await BackupService.instance.importFromJsonString(str);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.success
                            ? 'Ripristinati ${result.restoredStats} ascolti e ${result.restoredPlaylists} playlist!'
                            : result.message,
                      ),
                      backgroundColor: result.success ? AppTheme.secondary : Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Importa', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
