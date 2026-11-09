import 'package:flutter/material.dart';
import '../../models/youtube_track.dart';
import '../../services/youtube_service.dart';
import '../theme.dart';
import '../widgets/youtube_tile.dart';

class YouTubeTab extends StatefulWidget {
  const YouTubeTab({super.key});

  @override
  State<YouTubeTab> createState() => _YouTubeTabState();
}

class _YouTubeTabState extends State<YouTubeTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<YouTubeTrack> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _quickSearches = [
    'Top Italia 2026',
    'Rap Italiano',
    'Lo-Fi Chill',
    'Pop Hits',
    'Synthwave',
    'Rock Classico',
  ];

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await YouTubeService.instance.search(q);
      setState(() {
        _results = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore durante la ricerca. Riprova più tardi.';
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Music Online'),
      ),
      body: Column(
        children: [
          // Banner informativo su stream e background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.15),
                  AppTheme.secondary.withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.headset_rounded, color: AppTheme.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Riproduzione solo audio: ascolta anche a schermo spento con controlli da lock screen senza scaricare il video.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cerca brano o artista su YouTube...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Chip di ricerca rapida
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickSearches.length,
              itemBuilder: (context, idx) {
                final tag = _quickSearches[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    backgroundColor: AppTheme.surfaceLight,
                    side: const BorderSide(color: Color(0x14FFFFFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    onPressed: () {
                      _searchCtrl.text = tag;
                      _performSearch(tag);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Risultati o Loading
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text(
                          'Ricerca in corso su YouTube...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.youtube_searched_for_rounded, size: 64, color: AppTheme.primary.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Cerca le tue canzoni preferite',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'I brani vengono trasmessi in streaming audio immediato',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90, top: 4),
                            itemCount: _results.length,
                            itemBuilder: (context, idx) {
                              return YouTubeTile(track: _results[idx]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
