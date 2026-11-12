import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_notice.dart';
import '../../services/history_service.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/track_artwork.dart';

class _Voce {
  final String titolo;
  final String sotto;
  final String? copertina;
  final int conteggio;
  const _Voce(this.titolo, this.sotto, this.copertina, this.conteggio);
}

class _Periodo {
  final String etichetta;

  /// Inizio delle chiavi giorno/mese comprese: '2026-11', '2026', ''.
  final String prefisso;

  /// Come chiamarlo nel titolo: "novembre 2026", "2026", "di sempre".
  final String nome;
  const _Periodo(this.etichetta, this.prefisso, this.nome);
}

class _Dati {
  final int minuti;
  final int braniDiversi;
  final int ascoltiCompleti;
  final List<_Voce> brani;
  final List<_Voce> artisti;
  final List<_Voce> album;
  final String? giornoTop;
  final int minutiGiornoTop;
  final List<int> ore;
  final int oraTop;

  const _Dati({
    required this.minuti,
    required this.braniDiversi,
    required this.ascoltiCompleti,
    required this.brani,
    required this.artisti,
    required this.album,
    required this.giornoTop,
    required this.minutiGiornoTop,
    required this.ore,
    required this.oraTop,
  });

  bool get vuoto => minuti < 1 && brani.isEmpty;
}

/// Replay: il riassunto di cio' che si e' ascoltato in un periodo.
///
/// Brani, artisti e album piu' ascoltati, minuti totali, il giorno piu'
/// intenso e l'ora in cui si ascolta di piu'. Tutto e' calcolato su questo
/// dispositivo dalle statistiche dell'app: nulla viene inviato altrove. Il
/// poster in cima si puo' condividere come immagine.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  static const List<String> _mesi = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  final GlobalKey _chiavePoster = GlobalKey();
  late final List<_Periodo> _periodi;
  int _scelto = 0;
  bool _condivisione = false;

  @override
  void initState() {
    super.initState();
    final oggi = DateTime.now();
    final scorso = DateTime(oggi.year, oggi.month - 1, 1);
    _periodi = [
      _Periodo(
        'Questo mese',
        HistoryService.monthKey(oggi),
        '${_mesi[oggi.month - 1]} ${oggi.year}',
      ),
      _Periodo(
        _maiuscola(_mesi[scorso.month - 1]),
        HistoryService.monthKey(scorso),
        '${_mesi[scorso.month - 1]} ${scorso.year}',
      ),
      _Periodo('Quest\'anno', '${oggi.year}', '${oggi.year}'),
      const _Periodo('Sempre', '', 'di sempre'),
    ];
  }

  static String _maiuscola(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _dataEstesa(String chiaveGiorno) {
    final d = DateTime.tryParse(chiaveGiorno);
    if (d == null) return chiaveGiorno;
    return '${d.day} ${_mesi[d.month - 1]} ${d.year}';
  }

  static String _oraParlata(int ora) {
    if (ora == 0) return 'mezzanotte';
    if (ora == 12) return 'mezzogiorno';
    return '$ora:00';
  }

  static String _formatMinuti(int minuti) {
    if (minuti < 60) return '$minuti min';
    final h = minuti ~/ 60;
    final m = minuti % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  _Dati _calcola(_Periodo periodo) {
    final stats = StatsService.instance;
    final storia = HistoryService.instance;
    final prefisso = periodo.prefisso;

    var secondi = 0;
    var completi = 0;
    String? giornoTop;
    var secondiGiornoTop = 0;
    final ascolti = <String, int>{};

    stats.days.forEach((chiave, giorno) {
      if (!chiave.startsWith(prefisso)) return;
      secondi += giorno.listeningSeconds;
      completi += giorno.completedCount;
      if (giorno.listeningSeconds > secondiGiornoTop) {
        secondiGiornoTop = giorno.listeningSeconds;
        giornoTop = chiave;
      }
      giorno.trackPlays.forEach((id, n) {
        ascolti[id] = (ascolti[id] ?? 0) + n;
      });
    });

    // Per "Sempre", se nessun brano e' mai stato ascoltato fino in fondo, si
    // ripiega sul tempo passato su ciascuno: meglio di una classifica vuota.
    final perTempo = ascolti.isEmpty && prefisso.isEmpty;
    if (perTempo) {
      stats.stats.forEach((id, s) {
        if (s.totalDurationSeconds >= 60) {
          ascolti[id] = s.totalDurationSeconds ~/ 60;
        }
      });
    }

    final ordinati = ascolti.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final brani = <_Voce>[];
    final perArtista = <String, int>{};
    final copertinaArtista = <String, String?>{};
    for (final e in ordinati) {
      final s = stats.stats[e.key];
      if (s == null) continue;
      final titolo = s.title.isEmpty ? 'Traccia sconosciuta' : s.title;
      final artista = s.artist.trim();
      if (brani.length < 5) {
        brani.add(_Voce(titolo, artista, s.thumbnailUrl, e.value));
      }
      if (artista.isNotEmpty && artista != 'Artista sconosciuto') {
        perArtista[artista] = (perArtista[artista] ?? 0) + e.value;
        copertinaArtista.putIfAbsent(artista, () => s.thumbnailUrl);
      }
    }

    final artistiOrdinati = perArtista.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final artisti = <_Voce>[
      for (final e in artistiOrdinati.take(5))
        _Voce(e.key, '', copertinaArtista[e.key], e.value),
    ];

    final album = <_Voce>[
      for (final e in storia.albumsFor(prefisso).take(5))
        _Voce(
          HistoryService.albumName(e.key),
          HistoryService.albumArtist(e.key),
          storia.albumCover(e.key),
          e.value,
        ),
    ];

    final ore = storia.hoursFor(prefisso);
    var oraTop = -1;
    var massimo = 0;
    for (var i = 0; i < ore.length; i++) {
      if (ore[i] > massimo) {
        massimo = ore[i];
        oraTop = i;
      }
    }

    return _Dati(
      minuti: secondi ~/ 60,
      braniDiversi: ascolti.length,
      ascoltiCompleti: completi,
      brani: brani,
      artisti: artisti,
      album: album,
      giornoTop: giornoTop,
      minutiGiornoTop: secondiGiornoTop ~/ 60,
      ore: ore,
      oraTop: oraTop,
    );
  }

  Future<void> _condividi() async {
    if (_condivisione) return;
    setState(() => _condivisione = true);
    try {
      final oggetto = _chiavePoster.currentContext?.findRenderObject();
      if (oggetto is! RenderRepaintBoundary) {
        throw Exception('poster non pronto');
      }
      final immagine = await oggetto.toImage(pixelRatio: 3.0);
      final dati = await immagine.toByteData(format: ui.ImageByteFormat.png);
      if (dati == null) throw Exception('immagine vuota');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/dovvoplay_replay.png');
      await file.writeAsBytes(dati.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Il mio Replay su DovvoPlay',
      );
    } catch (e) {
      AppNotice.show('Impossibile creare l\'immagine del Replay.');
    } finally {
      if (mounted) setState(() => _condivisione = false);
    }
  }

  // ------------------------------------------------------------------ pezzi

  Widget _poster(_Periodo periodo, _Dati d) {
    return RepaintBoundary(
      key: _chiavePoster,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppTheme.primary, Colors.black, 0.35) ?? AppTheme.primary,
              Color.lerp(AppTheme.secondary, Colors.black, 0.72) ?? Colors.black,
              const Color(0xFF0B0B0F),
            ],
          ),
          border: Border.all(color: AppTheme.goldBorder, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IL TUO REPLAY',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 11.5,
                letterSpacing: 2.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _maiuscola(periodo.nome),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${d.minuti}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'minuti\ncon la musica',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _colonnaPoster('BRANI', d.brani)),
                const SizedBox(width: 14),
                Expanded(child: _colonnaPoster('ARTISTI', d.artisti)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 6),
                Text(
                  'DovvoPlay',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '${d.braniDiversi} brani diversi',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colonnaPoster(String titolo, List<_Voce> voci) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titolo,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        if (voci.isEmpty)
          Text(
            '—',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        for (var i = 0; i < voci.length && i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}  ${voci[i].titolo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _scheda({required String titolo, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titolo,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _classifica(List<_Voce> voci, {required String unita, bool tonda = false}) {
    return Column(
      children: [
        for (var i = 0; i < voci.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i == 0 ? AppTheme.primary : AppTheme.textMuted,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                TrackArtwork(
                  url: voci[i].copertina,
                  width: 40,
                  height: 40,
                  borderRadius: tonda ? 20 : 8,
                  placeholderIcon: tonda ? Icons.person_rounded : Icons.music_note_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voci[i].titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (voci[i].sotto.isNotEmpty)
                        Text(
                          voci[i].sotto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${voci[i].conteggio} $unita',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _graficoOre(_Dati d) {
    var massimo = 1;
    for (final n in d.ore) {
      if (n > massimo) massimo = n;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ascolti soprattutto verso ${d.oraTop == 0 || d.oraTop == 12 ? '' : 'le '}${_oraParlata(d.oraTop)}.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 24; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    height: 4 + 66 * (d.ore[i] / massimo),
                    decoration: BoxDecoration(
                      color: i == d.oraTop
                          ? AppTheme.primary
                          : AppTheme.primary.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final e in const ['0', '6', '12', '18', '23'])
              Text(e, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([StatsService.instance, HistoryService.instance]),
      builder: (context, _) {
        final periodo = _periodi[_scelto];
        final d = _calcola(periodo);

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Replay'),
            actions: [
              if (!d.vuoto)
                IconButton(
                  icon: _condivisione
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  tooltip: 'Condividi il tuo Replay',
                  onPressed: _condivisione ? null : _condividi,
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _periodi.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final scelto = i == _scelto;
                    return ChoiceChip(
                      label: Text(
                        _periodi[i].etichetta,
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
                      onSelected: (_) => setState(() => _scelto = i),
                    );
                  },
                ),
              ),
              if (d.vuoto)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 70, 32, 0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 56,
                        color: AppTheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Non hai ancora ascoltato abbastanza',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ascolta ancora un po\' e DovvoPlay trasformerà la tua '
                        'cronologia in un Replay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _poster(periodo, d),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: _condivisione ? null : _condividi,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Condividi il tuo Replay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.goldBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (d.brani.isNotEmpty)
                  _scheda(
                    titolo: 'Brani più ascoltati',
                    child: _classifica(
                      d.brani,
                      unita: d.ascoltiCompleti == 0 && periodo.prefisso.isEmpty
                          ? 'min'
                          : 'ascolti',
                    ),
                  ),
                if (d.artisti.isNotEmpty)
                  _scheda(
                    titolo: 'Artisti più ascoltati',
                    child: _classifica(
                      d.artisti,
                      unita: d.ascoltiCompleti == 0 && periodo.prefisso.isEmpty
                          ? 'min'
                          : 'ascolti',
                      tonda: true,
                    ),
                  ),
                if (d.album.isNotEmpty)
                  _scheda(
                    titolo: 'Album più ascoltati',
                    child: _classifica(d.album, unita: 'avvii'),
                  ),
                if (d.oraTop >= 0)
                  _scheda(
                    titolo: 'Quando ascolti di più',
                    child: _graficoOre(d),
                  ),
                if (d.giornoTop != null && d.minutiGiornoTop > 0)
                  _scheda(
                    titolo: 'Il tuo giorno più intenso',
                    child: Text(
                      '${_dataEstesa(d.giornoTop!)}, con ${_formatMinuti(d.minutiGiornoTop)} di ascolto.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                    'Conteggiato su questo dispositivo con DovvoPlay. Album e orari '
                    'vengono raccolti a partire da questa versione.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
