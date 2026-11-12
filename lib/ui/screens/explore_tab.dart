import 'package:flutter/material.dart';
import '../../services/party_service.dart';
import '../../services/yt_download_service.dart';
import '../../services/ytmusic_service.dart';
import '../theme.dart';
import '../widgets/ytm_widgets.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'listen_together_screen.dart';
import 'replay_screen.dart';
import 'ytm_browse_screen.dart';
import 'ytm_search_screen.dart';

/// La scheda "Esplora": la porta sul catalogo online.
///
/// In alto la ricerca e le scorciatoie (classifiche, mood e generi, nuove
/// uscite, ascolto insieme, Replay, cronologia); sotto, le file proposte da
/// YouTube Music: playlist in primo piano, nuove uscite, tendenze.
class ExploreTab extends StatefulWidget {
  /// true quando la scheda e' quella mostrata. I contenuti si caricano alla
  /// prima visita e non all'avvio dell'app: chi usa solo la libreria locale
  /// non deve pagare due chiamate di rete a ogni apertura.
  final bool active;

  const ExploreTab({super.key, this.active = true});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  List<YtmShelf> _file = [];
  bool _caricamento = false;
  bool _caricato = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _carica());
    }
  }

  @override
  void didUpdateWidget(covariant ExploreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_caricato && !_caricamento) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _carica());
    }
  }

  Future<void> _carica() async {
    if (!mounted || _caricamento) return;
    setState(() {
      _caricamento = true;
      _errore = null;
    });

    final raccolte = <YtmShelf>[];
    var riuscite = 0;
    // Le due pagine sono indipendenti: se una fallisce si mostra l'altra.
    for (final id in const [
      YtMusicService.browseHome,
      YtMusicService.browseExplore,
    ]) {
      try {
        raccolte.addAll(await YtMusicService.instance.shelvesOf(id));
        riuscite++;
      } catch (_) {}
    }

    if (!mounted) return;

    // Stesso titolo in entrambe le pagine: si tiene la prima. Le file senza
    // titolo fatte di sole categorie sono i tre pulsanti di navigazione del
    // sito, che qui hanno gia' le loro scorciatoie.
    final visti = <String>{};
    final pulite = <YtmShelf>[];
    for (final s in raccolte) {
      if (s.title.isEmpty && s.onlyMoods) continue;
      if (s.title.isNotEmpty && !visti.add(s.title.toLowerCase())) continue;
      pulite.add(s);
    }

    setState(() {
      _caricamento = false;
      _caricato = riuscite > 0;
      _file = pulite;
      _errore = riuscite == 0
          ? 'Catalogo online non raggiungibile.\nControlla la connessione e riprova.'
          : null;
    });
  }

  void _apri(Widget schermata) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => schermata));
  }

  Widget _scorciatoia({
    required IconData icona,
    required String titolo,
    required List<Color> colori,
    required VoidCallback onTap,
    String? nota,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.goldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colori),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icona, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    if (nota != null)
                      Text(
                        nota,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.primary, fontSize: 10.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scorciatoie() {
    final voci = <Widget>[
      _scorciatoia(
        icona: Icons.leaderboard_rounded,
        titolo: 'Classifiche',
        colori: const [Color(0xFFFF5F6D), Color(0xFFFFC371)],
        onTap: () => _apri(const YtmBrowseScreen(
          browseId: YtMusicService.browseCharts,
          title: 'Classifiche',
        )),
      ),
      _scorciatoia(
        icona: Icons.mood_rounded,
        titolo: 'Mood e generi',
        colori: const [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
        onTap: () => _apri(const YtmBrowseScreen(
          browseId: YtMusicService.browseMoods,
          title: 'Mood e generi',
        )),
      ),
      _scorciatoia(
        icona: Icons.new_releases_rounded,
        titolo: 'Nuove uscite',
        colori: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        onTap: () => _apri(const YtmBrowseScreen(
          browseId: YtMusicService.browseNewReleases,
          title: 'Nuove uscite',
        )),
      ),
      ListenableBuilder(
        listenable: PartyService.instance,
        builder: (context, _) {
          final party = PartyService.instance;
          return _scorciatoia(
            icona: Icons.groups_rounded,
            titolo: 'Ascolta insieme',
            nota: party.inParty ? 'Party ${party.code}' : null,
            colori: const [Color(0xFFEC008C), Color(0xFFFC6767)],
            onTap: () => _apri(const ListenTogetherScreen()),
          );
        },
      ),
      _scorciatoia(
        icona: Icons.auto_awesome_rounded,
        titolo: 'Replay',
        colori: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        onTap: () => _apri(const ReplayScreen()),
      ),
      _scorciatoia(
        icona: Icons.history_rounded,
        titolo: 'Cronologia',
        colori: const [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
        onTap: () => _apri(const HistoryScreen()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          for (var i = 0; i < voci.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: voci[i]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < voci.length ? voci[i + 1] : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _contenuti() {
    final out = <Widget>[];
    for (final shelf in _file) {
      if (shelf.onlyMoods) {
        out.add(YtmShelfTitle(
          title: shelf.title,
          trailing: TextButton(
            onPressed: () => _apri(const YtmBrowseScreen(
              browseId: YtMusicService.browseMoods,
              title: 'Mood e generi',
            )),
            child: Text(
              'Mostra tutto',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
          ),
        ));
        out.add(YtmMoodRow(items: shelf.items));
      } else {
        out.add(YtmShelfTitle(title: shelf.title));
        out.add(YtmShelfCarousel(shelf: shelf));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Esplora'),
        actions: [
          ListenableBuilder(
            listenable: YtDownloadService.instance,
            builder: (context, _) {
              final inCorso = YtDownloadService.instance.pendingCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      inCorso > 0 ? Icons.downloading_rounded : Icons.download_rounded,
                      color: AppTheme.primary,
                    ),
                    tooltip: 'Download',
                    onPressed: () => _apri(const DownloadsScreen()),
                  ),
                  if (inCorso > 0)
                    Positioned(
                      right: 6,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$inCorso',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surfaceCard,
        onRefresh: _carica,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Spazio in fondo per il mini player che sta sopra le schede.
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: GestureDetector(
                onTap: () => _apri(const YtmSearchScreen()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.goldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Artisti, brani, album e altro',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _scorciatoie(),
            if (_caricamento && _file.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_errore != null)
              YtmMessage(
                icon: Icons.wifi_off_rounded,
                text: _errore!,
                onRetry: _carica,
              )
            else if (_caricato && _file.isEmpty)
              const YtmMessage(
                icon: Icons.explore_off_rounded,
                text: 'Niente da esplorare al momento.',
              )
            else
              ..._contenuti(),
          ],
        ),
      ),
    );
  }
}
