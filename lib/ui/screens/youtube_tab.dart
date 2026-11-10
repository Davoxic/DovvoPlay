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
        if (res.isEmpty) {
          _errorMessage = 'Nessun risultato trovato per "$q". Prova con parole chiave diverse.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore di connessione a YouTube ($e).\nVerifica la connessione internet dell\'iPhone e riprova.';
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('YouTube Music Online'),
      ),
      body: Column(
        children: [
          // Banner informativo gold
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.goldSurfaceGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.goldBorder, width: 1.1),
            ),
            child: Row(
              children: [
                Icon(Icons.headset_rounded, color: AppTheme.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Riproduzione solo audio AAC: streaming istantaneo e ascolto a schermo spento con controlli da Lock Screen.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cerca brano o artista su YouTube...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceCard,
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.goldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
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
                    label: Text(tag, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    backgroundColor: AppTheme.surfaceLight,
                    side: BorderSide(color: AppTheme.goldBorder),
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
                ? Center(
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_searchCtrl.text.isNotEmpty) {
                                    _performSearch(_searchCtrl.text);
                                  }
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Riprova'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.youtube_searched_for_rounded, size: 64, color: AppTheme.primary.withOpacity(0.4)),
                                const SizedBox(height: 14),
                                Text(
                                  'Cerca le tue canzoni preferite',
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'I brani vengono riprodotti in streaming audio AAC immediato',
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
