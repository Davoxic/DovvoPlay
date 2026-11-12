import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/lyrics_service.dart';
import '../../services/playback_settings.dart';
import '../theme.dart';

/// Il testo del brano in riproduzione.
///
/// Quando il testo ha i tempi, la riga cantata viene evidenziata e tenuta al
/// centro; toccando una riga la riproduzione salta a quel punto. Senza tempi
/// il testo resta fermo e si scorre a mano.
class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final ScrollController _scroll = ScrollController();

  String? _idBrano;
  Lyrics? _testo;
  bool _caricamento = false;
  String? _errore;
  int _offsetMs = 0;
  int _rigaAttiva = -1;
  List<GlobalKey> _chiavi = [];

  /// Dopo uno scorrimento a mano il testo non viene riportato subito alla
  /// riga corrente: darebbe fastidio a chi sta leggendo piu' avanti.
  DateTime _ultimoScorrimentoManuale = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    AudioPlayerService.instance.addListener(_playerCambiato);
    PlaybackSettings.instance.addListener(_ridisegna);
    _carica();
  }

  @override
  void dispose() {
    AudioPlayerService.instance.removeListener(_playerCambiato);
    PlaybackSettings.instance.removeListener(_ridisegna);
    _scroll.dispose();
    super.dispose();
  }

  void _ridisegna() {
    if (mounted) setState(() {});
  }

  Future<void> _carica({bool forza = false}) async {
    final track = AudioPlayerService.instance.currentTrack;
    if (track == null) {
      setState(() {
        _idBrano = null;
        _testo = null;
        _caricamento = false;
        _errore = null;
      });
      return;
    }

    final id = track.id;
    setState(() {
      _idBrano = id;
      _testo = null;
      _errore = null;
      _caricamento = true;
      _rigaAttiva = -1;
      _chiavi = [];
    });

    Lyrics? trovato;
    String? errore;
    var offset = 0;
    try {
      trovato = await LyricsService.instance.fetch(track, force: forza);
      offset = await LyricsService.instance.getOffsetMs(track);
    } catch (e) {
      errore = 'Impossibile recuperare il testo. Controlla la connessione.';
    }

    // Nel frattempo il brano puo' essere cambiato: questo risultato non
    // serve piu'.
    if (!mounted || _idBrano != id) return;
    setState(() {
      _testo = trovato;
      _errore = errore;
      _offsetMs = offset;
      _caricamento = false;
      _chiavi = trovato == null
          ? []
          : List.generate(trovato.lines.length, (_) => GlobalKey());
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _aggiornaRiga(forzaScorrimento: true);
  }

  void _playerCambiato() {
    if (!mounted) return;
    final track = AudioPlayerService.instance.currentTrack;
    if (track?.id != _idBrano) {
      _carica();
      return;
    }
    _aggiornaRiga();
  }

  bool get _sincronizzato {
    final t = _testo;
    return t != null && t.synced && PlaybackSettings.instance.syncedLyrics;
  }

  int _trovaRiga(Duration posizione) {
    final t = _testo;
    if (t == null || t.lines.isEmpty) return -1;
    final ms = posizione.inMilliseconds - _offsetMs;
    var indice = -1;
    for (var i = 0; i < t.lines.length; i++) {
      if (t.lines[i].time.inMilliseconds <= ms) {
        indice = i;
      } else {
        break;
      }
    }
    return indice;
  }

  void _aggiornaRiga({bool forzaScorrimento = false}) {
    if (!_sincronizzato) return;
    final nuova = _trovaRiga(AudioPlayerService.instance.position);
    if (nuova == _rigaAttiva && !forzaScorrimento) return;
    if (nuova != _rigaAttiva) {
      setState(() => _rigaAttiva = nuova);
    }
    final daPoco = DateTime.now().difference(_ultimoScorrimentoManuale).inSeconds < 3;
    if (daPoco && !forzaScorrimento) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _portaAlCentro(nuova));
  }

  void _portaAlCentro(int indice) {
    if (!mounted || indice < 0 || indice >= _chiavi.length) return;
    final ctx = _chiavi[indice].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.38,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _cambiaOffset(int delta) async {
    final track = AudioPlayerService.instance.currentTrack;
    if (track == null) return;
    final nuovo = delta == 0 ? 0 : (_offsetMs + delta).clamp(-10000, 10000);
    setState(() => _offsetMs = nuovo);
    await LyricsService.instance.setOffsetMs(track, nuovo);
    _aggiornaRiga(forzaScorrimento: true);
  }

  void _apriOffset() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, aggiorna) {
          Future<void> sposta(int delta) async {
            await _cambiaOffset(delta);
            aggiorna(() {});
          }

          final secondi = (_offsetMs / 1000).toStringAsFixed(1);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sincronizzazione del testo',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Valori positivi mostrano le righe più tardi',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 34,
                        icon: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.primary),
                        tooltip: 'Anticipa di mezzo secondo',
                        onPressed: () => sposta(-500),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${_offsetMs > 0 ? '+' : ''}$secondi s',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 34,
                        icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                        tooltip: 'Ritarda di mezzo secondo',
                        onPressed: () => sposta(500),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _offsetMs == 0 ? null : () => sposta(0),
                    child: const Text('Azzera'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _tempo(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _messaggio(IconData icona, String testo, {bool riprova = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 54, color: AppTheme.primary.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(
              testo,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5, height: 1.4),
            ),
            if (riprova) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _carica(forza: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Riprova'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.goldBorder),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _corpo(Track? track) {
    if (track == null) {
      return _messaggio(Icons.music_off_rounded, 'Nessun brano in riproduzione');
    }
    if (_caricamento) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(
              'Recupero del testo...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_errore != null) {
      return _messaggio(Icons.wifi_off_rounded, _errore!, riprova: true);
    }
    final t = _testo;
    if (t == null || t.isEmpty) {
      return _messaggio(
        Icons.lyrics_outlined,
        'Nessun testo trovato per questo brano',
        riprova: true,
      );
    }
    if (t.instrumental && t.lines.isEmpty && t.plain.trim().isEmpty) {
      return _messaggio(Icons.piano_rounded, 'Strumentale');
    }

    if (!_sincronizzato) {
      return SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 40),
        child: Text(
          t.plain,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            height: 1.65,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final sfoca = PlaybackSettings.instance.blurLyrics;
    final altezza = MediaQuery.of(context).size.height;

    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _ultimoScorrimentoManuale = DateTime.now();
        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(26, altezza * 0.16, 26, altezza * 0.42),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(t.lines.length, (i) {
            final riga = t.lines[i];
            final attiva = i == _rigaAttiva;
            final distanza = _rigaAttiva < 0 ? 3 : (i - _rigaAttiva).abs();
            final vuota = riga.text.trim().isEmpty;

            Widget testo = AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: attiva
                    ? AppTheme.textPrimary
                    : AppTheme.textPrimary.withOpacity(distanza <= 1 ? 0.55 : 0.34),
                fontSize: attiva ? 25 : 21,
                height: 1.3,
                fontWeight: attiva ? FontWeight.w800 : FontWeight.w700,
              ),
              child: Text(vuota ? '♪' : riga.text),
            );

            // La sfocatura costa: la si applica solo alle righe vicine,
            // che sono quelle davvero sullo schermo.
            if (sfoca && !attiva && distanza >= 1 && distanza <= 6) {
              final sigma = (distanza * 0.55).clamp(0.5, 2.4);
              testo = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: testo,
              );
            }

            return GestureDetector(
              key: i < _chiavi.length ? _chiavi[i] : null,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final ms = riga.time.inMilliseconds + _offsetMs;
                AudioPlayerService.instance.seek(Duration(milliseconds: ms < 0 ? 0 : ms));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: SizedBox(width: double.infinity, child: testo),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(AppTheme.primary, AppTheme.background, 0.78) ?? AppTheme.background,
              AppTheme.background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: AudioPlayerService.instance,
            builder: (context, _) {
              final player = AudioPlayerService.instance;
              final track = player.currentTrack;
              final totale = player.duration.inMilliseconds;
              final avanzamento = totale > 0
                  ? (player.position.inMilliseconds / totale).clamp(0.0, 1.0)
                  : 0.0;
              final t = _testo;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: AppTheme.textPrimary,
                          ),
                          tooltip: 'Chiudi testi',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.displayTitle ?? 'Testi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (track != null)
                                Text(
                                  track.displayArtist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (t != null && t.synced)
                          IconButton(
                            icon: Icon(Icons.timer_outlined, color: AppTheme.primary, size: 22),
                            tooltip: 'Sincronizzazione del testo',
                            onPressed: _apriOffset,
                          ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 22),
                          tooltip: 'Cerca di nuovo il testo',
                          onPressed: _caricamento ? null : () => _carica(forza: true),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _corpo(track)),
                  if (t != null && !t.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        t.synced ? 'Testo sincronizzato · ${t.source}' : 'Testo di ${t.source}',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                      ),
                    ),
                  if (track != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 10, 10),
                      child: Row(
                        children: [
                          Text(
                            _tempo(player.position),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: avanzamento,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _tempo(player.duration),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          IconButton(
                            iconSize: 40,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              player.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: AppTheme.primary,
                            ),
                            onPressed: player.togglePlayPause,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
