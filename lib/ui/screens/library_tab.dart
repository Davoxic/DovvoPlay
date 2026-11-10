import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/stats_service.dart';
import '../../services/view_mode_service.dart';
import '../theme.dart';
import '../widgets/track_tile.dart';
import 'stats_screen.dart';

enum TrackSortMode {
  none('Nessuno', Icons.sort_rounded),
  duration('Durata', Icons.timer_outlined),
  playCount('Ascolti Totali', Icons.local_fire_department_rounded),
  artist('Artista', Icons.person_rounded),
  alphabetical('A-Z', Icons.sort_by_alpha_rounded);

  final String label;
  final IconData icon;
  const TrackSortMode(this.label, this.icon);
}

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterText = '';
  String _activeCategory = 'all'; // 'all', 'top', 'least', 'recent'
  TrackSortMode _sortMode = TrackSortMode.none;

  @override
  void dispose() {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        const Color(0xFFFFB300),
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.leastPlayed,
                        '💎 Riscopri (Meno Ascoltate)',
                        'Dai spazio ai brani mai ascoltati o che ascolti raramente',
                        const Color(0xFF64FFDA),
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.mediumPlayed,
                        '⚖️ Equilibrato (Medio Ascolto)',
                        'Le canzoni di mezzo: né le solite hit, né quelle sconosciute',
                        const Color(0xFF64B5F6),
                      ),
                      _buildShuffleTile(
                        ctx,
                        tracks,
                        ShuffleMode.recent,
                        '⏳ Freschi & Recenti',
                        'Concentrati sui brani aggiunti o ascoltati ultimamente',
                        const Color(0xFFBA68C8),
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
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
      listenable: Listenable.merge([
        LibraryService.instance,
        StatsService.instance,
        ViewModeService.instance,
      ]),
      builder: (context, _) {
        final lib = LibraryService.instance;
        final stats = StatsService.instance;
        final viewMode = ViewModeService.instance.currentMode;

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

        final sortedTracks = List<Track>.from(filteredTracks);
        switch (_sortMode) {
          case TrackSortMode.duration:
            sortedTracks.sort((a, b) => b.duration.compareTo(a.duration));
            break;
          case TrackSortMode.playCount:
            sortedTracks.sort((a, b) {
              final aSec = stats.getStat(a.id)?.totalDurationSeconds ?? 0;
              final bSec = stats.getStat(b.id)?.totalDurationSeconds ?? 0;
              return bSec.compareTo(aSec);
            });
            break;
          case TrackSortMode.artist:
            sortedTracks.sort((a, b) => a.displayArtist.toLowerCase().compareTo(b.displayArtist.toLowerCase()));
            break;
          case TrackSortMode.alphabetical:
            sortedTracks.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
            break;
          case TrackSortMode.none:
            break;
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Libreria',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.goldBorder),
                  ),
                  child: Text(
                    '${lib.tracks.length}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(ViewModeService.instance.currentInfo.icon, color: AppTheme.primary),
                tooltip: 'Cambia layout (${ViewModeService.instance.currentInfo.name})',
                onPressed: () {
                  ViewModeService.instance.cycleNextMode();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 900),
                      content: Text('Layout: ${ViewModeService.instance.currentInfo.name}'),
                      backgroundColor: AppTheme.surfaceCard,
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.analytics_rounded, color: AppTheme.primary),
                tooltip: 'Statistiche d\'ascolto',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceCard,
            onRefresh: () async {
              await lib.scanLibrary();
            },
            child: Column(
              children: [
                // Schede Rapide: Shuffle Magico & Statistiche
                if (lib.tracks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                    color: AppTheme.primary.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 20),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Shuffle Magico',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${stats.todayStat.listeningSeconds ~/ 60}m ascoltati oggi',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
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
                                color: AppTheme.surfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.goldBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    stats.totalListeningSeconds > 0
                                        ? stats.formatDurationSummary()
                                        : 'Insight',
                                    style: TextStyle(
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _filterCtrl,
                      onChanged: (val) => setState(() => _filterText = val),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cerca tra i brani locali...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppTheme.goldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),

                // Chip filtri rapidi
                if (lib.tracks.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('all', 'Tutti i brani', Icons.music_note_rounded),
                        const SizedBox(width: 8),
                        _buildFilterChip('top', '🔥 Più ascoltate (70-100%)', Icons.local_fire_department_rounded),
                        const SizedBox(width: 8),
                        _buildFilterChip('least', '💎 Da riscoprire', Icons.explore_rounded),
                        const SizedBox(width: 8),
                        _buildFilterChip('recent', '🕒 Recenti', Icons.history_rounded),
                      ],
                    ),
                  ),

                // Barra Ordinamento Canzoni (Durata / Ascolti / Artista / Alfabetico / Niente)
                if (lib.tracks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 7),
                          child: Text(
                            'ORDINA:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        ...TrackSortMode.values.map((mode) {
                          final isSelected = _sortMode == mode;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              avatar: Icon(
                                mode.icon,
                                size: 12,
                                color: isSelected ? Colors.black : AppTheme.primary,
                              ),
                              label: Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.surfaceCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primary : AppTheme.goldBorder,
                                ),
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _sortMode = mode);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // Sezione Tracce Dinamica in base al ViewMode
                Expanded(
                  child: lib.tracks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.goldBorder, width: 1.5),
                                  ),
                                  child: Icon(Icons.library_music_rounded, size: 40, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Nessun brano salvato',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Carica file dal computer via Wi-Fi\no scarica brani da YouTube nella sezione Impostazioni!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.file_upload_outlined, color: Colors.black),
                                  label: const Text(
                                    'Importa da File / iCloud',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _pickFiles,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildTracksContainer(sortedTracks, viewMode),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTracksContainer(List<Track> tracks, LibraryViewMode viewMode) {
    if (viewMode == LibraryViewMode.gridCovers) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: tracks.length,
        itemBuilder: (context, idx) {
          return TrackTile(
            track: tracks[idx],
            queue: tracks,
            mode: viewMode,
            index: idx,
          );
        },
      );
    } else if (viewMode == LibraryViewMode.gridCompact) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.74,
        ),
        itemCount: tracks.length,
        itemBuilder: (context, idx) {
          return TrackTile(
            track: tracks[idx],
            queue: tracks,
            mode: viewMode,
            index: idx,
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 110, top: 4),
      itemCount: tracks.length,
      itemBuilder: (context, idx) {
        return TrackTile(
          track: tracks[idx],
          queue: tracks,
          mode: viewMode,
          index: idx,
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
          color: isSelected ? AppTheme.primary : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textSecondary,
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
