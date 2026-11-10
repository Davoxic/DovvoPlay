import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/track_tile.dart';
import 'playlist_detail_screen.dart';
import 'stats_screen.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterText = '';
  String _activeCategory = 'all'; // 'all', 'top', 'least', 'recent'

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

  void _showMagicShufflePicker(BuildContext context, List<Track> tracks) {
    if (tracks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Scegli il tuo Shuffle Magico',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.magic,
                        '🔮 Shuffle Magico',
                        'Mix perfetto: bilancia le tue preferite, le medie e le perle dimenticate',
                        AppTheme.primary,
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.mostPlayed,
                        '🔥 Hit Parade (Più Ascoltate)',
                        'Riproduce e mescola solo i tuoi brani preferiti e più ripetuti',
                        Colors.orangeAccent,
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.leastPlayed,
                        '💎 Riscopri (Meno Ascoltate)',
                        'Dai spazio ai brani mai ascoltati o che ascolti raramente',
                        Colors.tealAccent,
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.mediumPlayed,
                        '⚖️ Equilibrato (Medio Ascolto)',
                        'Le canzoni di mezzo: né le solite hit, né quelle sconosciute',
                        Colors.blueAccent,
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.recent,
                        '⏳ Freschi & Recenti',
                        'Concentrati sui brani aggiunti o ascoltati ultimamente',
                        Colors.purpleAccent,
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.standard,
                        '🎲 Casuale 100%',
                        'Mescolamento casuale puro di tutta la libreria',
                        AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShuffleTile(
    BuildContext ctx,
    List<Track> tracks,
    ShuffleMode mode,
    String title,
    String subtitle,
    Color color,
  ) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(mode.icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      onTap: () {
        Navigator.pop(ctx);
        final player = AudioPlayerService.instance;
        player.setShuffleMode(mode, baseList: tracks);
        if (player.queue.isNotEmpty) {
          player.playTrack(player.queue.first);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avviato $title!'),
            backgroundColor: AppTheme.surfaceLight,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LibraryService.instance, StatsService.instance]),
      builder: (context, _) {
        final lib = LibraryService.instance;
        final stats = StatsService.instance;

        // Filtro per categoria
        List<Track> baseTracks = lib.tracks;
        if (_activeCategory == 'top') {
          baseTracks = stats.getMostPlayedTracks(lib.tracks);
        } else if (_activeCategory == 'least') {
          baseTracks = stats.getLeastPlayedTracks(lib.tracks);
        } else if (_activeCategory == 'recent') {
          baseTracks = stats.getRecentlyPlayedTracks(lib.tracks);
        }

        final filteredTracks = baseTracks.where((t) {
          if (_filterText.isEmpty) return true;
          return t.title.toLowerCase().contains(_filterText.toLowerCase()) ||
              t.artist.toLowerCase().contains(_filterText.toLowerCase());
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Libreria'),
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics_rounded, color: AppTheme.secondary),
                tooltip: 'Statistiche d\'ascolto',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                },
              ),
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
                    // Schede Rapide: Shuffle Magico & Statistiche
                    if (lib.tracks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                onTap: () => _showMagicShufflePicker(context, lib.tracks),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Shuffle Magico',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0x18FFFFFF)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.bar_chart_rounded, color: AppTheme.secondary, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        stats.totalListeningSeconds > 0
                                            ? stats.formatDurationSummary()
                                            : 'Insight',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Campo ricerca locale
                    if (lib.tracks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                    // Chip filtri rapidi (Tutti, Più ascoltate, Riscopri, Recenti)
                    if (lib.tracks.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildFilterChip('all', 'Tutti i brani', Icons.music_note_rounded),
                            const SizedBox(width: 8),
                            _buildFilterChip('top', '🔥 Più ascoltate', Icons.local_fire_department_rounded),
                            const SizedBox(width: 8),
                            _buildFilterChip('least', '💎 Da riscoprire', Icons.explore_rounded),
                            const SizedBox(width: 8),
                            _buildFilterChip('recent', '🕒 Recenti', Icons.history_rounded),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),

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
                              padding: const EdgeInsets.only(bottom: 90, top: 4),
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

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _activeCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0x18FFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
