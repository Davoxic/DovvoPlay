import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/search_history_service.dart';
import '../../services/ytmusic_service.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/ytm_widgets.dart';

class _Filtro {
  final String etichetta;
  final String? parametro;
  const _Filtro(this.etichetta, this.parametro);
}

/// Ricerca nel catalogo di YouTube Music: brani, video, album, artisti e
/// playlist, con i completamenti mentre si scrive e le ricerche recenti.
class YtmSearchScreen extends StatefulWidget {
  /// Testo da cercare subito all'apertura.
  final String initialQuery;

  const YtmSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<YtmSearchScreen> createState() => _YtmSearchScreenState();
}

class _YtmSearchScreenState extends State<YtmSearchScreen> {
  static const List<_Filtro> _filtri = [
    _Filtro('Tutti', null),
    _Filtro('Brani', YtMusicService.filterSongs),
    _Filtro('Video', YtMusicService.filterVideos),
    _Filtro('Album', YtMusicService.filterAlbums),
    _Filtro('Artisti', YtMusicService.filterArtists),
    _Filtro('Playlist', YtMusicService.filterPlaylists),
  ];

  final TextEditingController _campo = TextEditingController();
  final FocusNode _fuoco = FocusNode();
  Timer? _attesa;

  int _filtro = 0;
  String _cercato = '';
  List<YtmItem> _risultati = [];
  List<String> _suggerimenti = [];
  bool _caricamento = false;
  String? _errore;

  /// Cresce a ogni ricerca: una risposta arrivata in ritardo, per una
  /// ricerca ormai superata, viene scartata.
  int _richiesta = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery.trim();
    if (q.isNotEmpty) {
      _campo.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _cerca(q));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fuoco.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _campo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  void _testoCambiato(String testo) {
    setState(() {});
    _attesa?.cancel();
    final q = testo.trim();
    if (q.isEmpty) {
      setState(() => _suggerimenti = []);
      return;
    }
    // Aspetta che si smetta di scrivere prima di chiedere i completamenti.
    _attesa = Timer(const Duration(milliseconds: 320), () async {
      try {
        final s = await YtMusicService.instance.suggestions(q);
        if (!mounted || _campo.text.trim() != q) return;
        setState(() => _suggerimenti = s);
      } catch (_) {
        // I completamenti sono un aiuto: se mancano si cerca lo stesso.
      }
    });
  }

  Future<void> _cerca(String testo, {bool daFiltro = false}) async {
    final q = testo.trim();
    if (q.isEmpty) return;
    _attesa?.cancel();
    _fuoco.unfocus();
    if (!daFiltro) SearchHistoryService.instance.add(q);

    final richiesta = ++_richiesta;
    setState(() {
      _cercato = q;
      _caricamento = true;
      _errore = null;
      _suggerimenti = [];
      if (_campo.text != q) _campo.text = q;
    });

    try {
      final r = await YtMusicService.instance.search(
        q,
        filter: _filtri[_filtro].parametro,
      );
      if (!mounted || richiesta != _richiesta) return;
      setState(() {
        _risultati = r;
        _caricamento = false;
      });
    } catch (e) {
      if (!mounted || richiesta != _richiesta) return;
      setState(() {
        _caricamento = false;
        _errore = 'Ricerca non riuscita.\nControlla la connessione e riprova.';
      });
    }
  }

  void _pulisci() {
    _attesa?.cancel();
    _richiesta++;
    setState(() {
      _campo.clear();
      _cercato = '';
      _risultati = [];
      _suggerimenti = [];
      _errore = null;
      _caricamento = false;
    });
    _fuoco.requestFocus();
  }

  Widget _recenti() {
    return ListenableBuilder(
      listenable: SearchHistoryService.instance,
      builder: (context, _) {
        final voci = SearchHistoryService.instance.items;
        if (voci.isEmpty) {
          return const YtmMessage(
            icon: Icons.search_rounded,
            text: 'Cerca artisti, brani, album e playlist\nnel catalogo di YouTube Music.',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ricerche recenti',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: SearchHistoryService.instance.clear,
                    child: Text(
                      'Cancella',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            for (final v in voci)
              ListTile(
                dense: true,
                leading: Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 20),
                title: Text(v, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5)),
                trailing: IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                  tooltip: 'Rimuovi dalle ricerche recenti',
                  onPressed: () => SearchHistoryService.instance.remove(v),
                ),
                onTap: () => _cerca(v),
              ),
          ],
        );
      },
    );
  }

  Widget _elencoSuggerimenti() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final s in _suggerimenti)
          ListTile(
            dense: true,
            leading: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
            title: Text(s, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5)),
            trailing: IconButton(
              icon: Icon(Icons.north_west_rounded, color: AppTheme.textMuted, size: 18),
              tooltip: 'Modifica',
              onPressed: () {
                _campo.text = s;
                _campo.selection = TextSelection.collapsed(offset: s.length);
                _testoCambiato(s);
              },
            ),
            onTap: () => _cerca(s),
          ),
      ],
    );
  }

  Widget _elencoRisultati() {
    if (_caricamento) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_errore != null) {
      return YtmMessage(
        icon: Icons.wifi_off_rounded,
        text: _errore!,
        onRetry: () => _cerca(_cercato, daFiltro: true),
      );
    }
    if (_risultati.isEmpty) {
      return YtmMessage(
        icon: Icons.search_off_rounded,
        text: 'Niente corrisponde a "$_cercato"',
      );
    }
    final coda = <Track>[
      for (final i in _risultati)
        if (i.isSong) i.toTrack(),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _risultati.length,
      itemBuilder: (context, i) {
        final it = _risultati[i];
        if (it.isSong) return YtmSongTile(item: it, coda: coda);
        return YtmCollectionTile(item: it);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrivendo = _fuoco.hasFocus && _campo.text.trim() != _cercato;
    Widget corpo;
    if (_campo.text.trim().isEmpty) {
      corpo = _recenti();
    } else if (scrivendo && _suggerimenti.isNotEmpty) {
      corpo = _elencoSuggerimenti();
    } else if (_cercato.isEmpty) {
      corpo = const SizedBox.shrink();
    } else {
      corpo = _elencoRisultati();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _campo,
            focusNode: _fuoco,
            textInputAction: TextInputAction.search,
            onChanged: _testoCambiato,
            onSubmitted: _cerca,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Artisti, brani, album e altro',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14.5),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surfaceCard,
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
              suffixIcon: _campo.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                      tooltip: 'Cancella ricerca',
                      onPressed: _pulisci,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.goldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.4),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: Column(
        children: [
          if (_cercato.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                itemCount: _filtri.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final scelto = i == _filtro;
                  return ChoiceChip(
                    label: Text(
                      _filtri[i].etichetta,
                      style: TextStyle(
                        color: scelto ? Colors.black : AppTheme.textPrimary,
                        fontWeight: scelto ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12.5,
                      ),
                    ),
                    selected: scelto,
                    showCheckmark: false,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceLight,
                    side: BorderSide(color: AppTheme.goldBorder),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      if (i == _filtro) return;
                      setState(() => _filtro = i);
                      _cerca(_cercato, daFiltro: true);
                    },
                  );
                },
              ),
            ),
          Expanded(child: corpo),
        ],
      ),
    );
  }
}
