import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/party_service.dart';
import '../../services/yt_download_service.dart';
import '../../services/ytmusic_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_artwork.dart';
import '../widgets/ytm_widgets.dart';

/// Pagina del catalogo online: un album, una playlist, un artista, le
/// classifiche, le nuove uscite oppure una categoria "mood e generi".
///
/// La forma e' la stessa per tutte: un'intestazione, quando c'e', e una
/// serie di file. Per album e playlist la prima fila e' l'elenco dei brani,
/// con i tasti per riprodurli, scaricarli o salvarli come playlist.
class YtmBrowseScreen extends StatefulWidget {
  final String browseId;
  final String params;
  final String title;
  final YtmKind? kind;

  const YtmBrowseScreen({
    super.key,
    required this.browseId,
    this.params = '',
    this.title = '',
    this.kind,
  });

  @override
  State<YtmBrowseScreen> createState() => _YtmBrowseScreenState();
}

class _YtmBrowseScreenState extends State<YtmBrowseScreen> {
  YtmPage? _pagina;
  bool _caricamento = true;
  String? _errore;
  bool _descrizioneAperta = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final p = await YtMusicService.instance.browse(
        widget.browseId,
        params: widget.params,
      );
      if (!mounted) return;
      setState(() {
        _pagina = p;
        _caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _caricamento = false;
        _errore = 'Impossibile caricare questa pagina.\nControlla la connessione e riprova.';
      });
    }
  }

  bool get _raccolta =>
      widget.kind == YtmKind.album || widget.kind == YtmKind.playlist;

  /// I brani principali della pagina: le tracce di un album o di una
  /// playlist, i piu' ascoltati di un artista.
  List<Track> _braniPrincipali(YtmPage p) {
    for (final s in p.shelves) {
      if (s.onlySongs) return s.items.map((i) => i.toTrack()).toList();
    }
    return const [];
  }

  void _riproduci(List<Track> brani, {bool casuale = false}) {
    if (brani.isEmpty) return;
    if (PartyService.instance.isGuest) {
      AppNotice.show("Nel party e' l'host a scegliere i brani");
      return;
    }
    final player = AudioPlayerService.instance;
    if (casuale) {
      final mescolati = List<Track>.from(brani)..shuffle(Random());
      player.setShuffleMode(ShuffleMode.off);
      player.playTrack(mescolati.first, newQueue: mescolati);
    } else {
      player.playTrack(brani.first, newQueue: brani);
    }
  }

  Future<void> _salvaComePlaylist(String nome, List<Track> brani) async {
    if (brani.isEmpty) return;
    final titolo = nome.trim().isEmpty ? 'Playlist online' : nome.trim();
    await LibraryService.instance.createPlaylistWithTracks(titolo, brani);
    AppNotice.show('Salvata nelle tue playlist: "$titolo" (${brani.length} brani)');
  }

  void _scaricaTutto(List<Track> brani) {
    final n = YtDownloadService.instance.enqueueAll(brani);
    AppNotice.show(
      n == 0
          ? 'Questi brani sono già scaricati o in coda'
          : '$n brani in download: li trovi in Download',
    );
  }

  Widget _intestazione(YtmPage p, List<Track> brani) {
    final artista = widget.kind == YtmKind.artist;
    final titolo = p.title.isNotEmpty ? p.title : widget.title;
    final copertina = p.thumbnailUrl;
    final larghezza = MediaQuery.of(context).size.width;
    final lato = min(larghezza * 0.52, 220.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        children: [
          if (copertina.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(artista ? lato / 2 : 18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: TrackArtwork(
                url: copertina,
                width: lato,
                height: lato,
                borderRadius: artista ? lato / 2 : 18,
                placeholderIcon: artista ? Icons.person_rounded : Icons.album_rounded,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            titolo,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          if (p.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _descrizioneAperta = !_descrizioneAperta),
              child: Text(
                p.description,
                maxLines: _descrizioneAperta ? 40 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
              ),
            ),
          ],
          if (brani.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _riproduci(brani),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Riproduci',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _riproduci(brani, casuale: true),
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    label: const Text(
                      'Casuale',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.goldBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _scaricaTutto(brani),
                  icon: Icon(Icons.download_rounded, size: 18, color: AppTheme.textSecondary),
                  label: Text(
                    'Scarica tutto',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ),
                if (_raccolta)
                  TextButton.icon(
                    onPressed: () => _salvaComePlaylist(titolo, brani),
                    icon: Icon(
                      Icons.library_add_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    label: Text(
                      'Salva come playlist',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ),
                if (artista)
                  TextButton.icon(
                    onPressed: () => AudioPlayerService.instance.startRadio(brani.first),
                    icon: Icon(Icons.sensors_rounded, size: 18, color: AppTheme.textSecondary),
                    label: Text(
                      'Radio',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _slivers(YtmPage p) {
    final out = <Widget>[];
    final brani = _braniPrincipali(p);
    final conIntestazione = widget.kind == YtmKind.album ||
        widget.kind == YtmKind.playlist ||
        widget.kind == YtmKind.artist;

    if (conIntestazione) {
      out.add(SliverToBoxAdapter(child: _intestazione(p, brani)));
    }

    var primaDiBrani = true;
    for (final shelf in p.shelves) {
      if (shelf.onlyMoods) {
        if (shelf.title.isNotEmpty) {
          out.add(SliverToBoxAdapter(child: YtmShelfTitle(title: shelf.title)));
        } else {
          out.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
        }
        out.add(SliverToBoxAdapter(child: YtmMoodRow(items: shelf.items, aCapo: true)));
        continue;
      }

      // La prima fila di soli brani e' l'elenco vero e proprio e si mostra
      // per intero; lo stesso per le file corte. Il resto va in carosello.
      final elenco = shelf.onlySongs && (primaDiBrani || shelf.items.length <= 10);
      final principale = shelf.onlySongs && primaDiBrani;
      if (shelf.onlySongs) primaDiBrani = false;

      if (shelf.title.isNotEmpty) {
        out.add(SliverToBoxAdapter(child: YtmShelfTitle(title: shelf.title)));
      } else {
        out.add(const SliverToBoxAdapter(child: SizedBox(height: 14)));
      }

      if (elenco) {
        final coda = shelf.items.map((i) => i.toTrack()).toList();
        final numerati = principale && widget.kind == YtmKind.album;
        out.add(SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => YtmSongTile(
              item: shelf.items[i],
              coda: coda,
              numero: numerati ? i + 1 : null,
            ),
            childCount: shelf.items.length,
          ),
        ));
      } else if (shelf.items.length > 30 && !shelf.onlySongs) {
        // File molto lunghe (le nuove uscite sono centinaia): una griglia
        // che si costruisce man mano, invece di un carosello infinito.
        out.add(SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final it = shelf.items[i];
                return LayoutBuilder(
                  builder: (context, vincoli) => YtmCard(
                    item: it,
                    larghezza: vincoli.maxWidth,
                    onTap: () => openYtmItem(context, it, fratelli: shelf.items),
                  ),
                );
              },
              childCount: shelf.items.length,
            ),
          ),
        ));
      } else {
        out.add(SliverToBoxAdapter(child: YtmShelfCarousel(shelf: shelf)));
      }
    }

    if (p.shelves.isEmpty) {
      out.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: YtmMessage(
          icon: Icons.library_music_outlined,
          text: 'Niente da mostrare qui al momento.',
        ),
      ));
    }

    out.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = _pagina;
    final titoloBarra = widget.kind == YtmKind.album ||
            widget.kind == YtmKind.playlist ||
            widget.kind == YtmKind.artist
        ? ''
        : (p != null && p.title.isNotEmpty ? p.title : widget.title);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(titoloBarra),
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: _caricamento
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _errore != null
              ? YtmMessage(
                  icon: Icons.wifi_off_rounded,
                  text: _errore!,
                  onRetry: _carica,
                )
              : p == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceCard,
                      onRefresh: _carica,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: _slivers(p),
                      ),
                    ),
    );
  }
}
