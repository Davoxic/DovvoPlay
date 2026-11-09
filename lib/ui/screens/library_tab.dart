import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/library_service.dart';
import '../theme.dart';
import '../widgets/track_tile.dart';
import 'playlist_detail_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'flac', 'aif', 'aiff', 'caf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final musicDir = await LibraryService.instance.musicDirectory;
      int imported = 0;

      for (final pf in result.files) {
        if (pf.path != null) {
          final src = File(pf.path!);
          final dest = File('${musicDir.path}/${pf.name}');
          await src.copy(dest.path);
          imported++;
        }
      }

      await LibraryService.instance.scanLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported brani importati con successo!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Nuova Playlist', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nome della playlist',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                LibraryService.instance.createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Crea', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryService.instance,
      builder: (context, _) {
        final lib = LibraryService.instance;
        final filteredTracks = lib.tracks.where((t) {
          if (_filterText.isEmpty) return true;
          return t.title.toLowerCase().contains(_filterText.toLowerCase()) ||
              t.artist.toLowerCase().contains(_filterText.toLowerCase());
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Libreria'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_upload_outlined, color: AppTheme.textPrimary),
                tooltip: 'Importa file audio',
                onPressed: _pickFiles,
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, color: AppTheme.primary),
                tooltip: 'Crea playlist',
                onPressed: _showCreatePlaylistDialog,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(text: 'Brani (${lib.tracks.length})'),
                Tab(text: 'Playlist (${lib.playlists.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Brani
              RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                onRefresh: () async {
                  await lib.scanLibrary();
                },
                child: Column(
                  children: [
                    // Filtro di ricerca locale
                    if (lib.tracks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextField(
                          controller: _filterCtrl,
                          onChanged: (val) => setState(() => _filterText = val),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cerca tra i brani locali...',
                            hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                    Expanded(
                      child: lib.tracks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.library_music_rounded, size: 64, color: AppTheme.primary.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Nessun brano salvato',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Carica file dal computer via Wi-Fi\no cerca e scarica brani da YouTube!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                                    label: const Text('Importa da File / iCloud', style: TextStyle(color: Colors.white)),
                                    onPressed: _pickFiles,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90, top: 8),
                              itemCount: filteredTracks.length,
                              itemBuilder: (context, idx) {
                                return TrackTile(
                                  track: filteredTracks[idx],
                                  queue: filteredTracks,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // TAB 2: Playlist
              lib.playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.queue_music_rounded, size: 64, color: AppTheme.secondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'Nessuna playlist',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Crea playlist per organizzare i tuoi brani locali e online.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            label: const Text('Crea prima playlist', style: TextStyle(color: Colors.white)),
                            onPressed: _showCreatePlaylistDialog,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90, top: 12),
                      itemCount: lib.playlists.length,
                      itemBuilder: (context, idx) {
                        final pl = lib.playlists[idx];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x14FFFFFF)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
                            ),
                            title: Text(
                              pl.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15),
                            ),
                            subtitle: Text(
                              '${pl.trackIds.length} brani',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PlaylistDetailScreen(playlist: pl),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }
}
