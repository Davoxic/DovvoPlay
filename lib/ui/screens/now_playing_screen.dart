import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/animation_theme_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/likes_service.dart';
import '../../services/party_service.dart';
import '../../services/playback_settings.dart';
import '../../services/stats_service.dart';
import '../theme.dart';
import '../widgets/animated_track_transition.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/player_sheets.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/track_artwork.dart';
import 'listen_together_screen.dart';
import 'lyrics_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;

  /// Effetto ambient dietro la copertina, si accende toccandola.
  bool _ambiente = false;
  late AnimationController _pulsazione;

  /// Posizione scelta col dito mentre si trascina il cursore. Finche' non e'
  /// null il cursore segue il dito e non la riproduzione: lo spostamento
  /// vero avviene una volta sola, al rilascio.
  double? _trascinamento;

  @override
  void initState() {
    super.initState();
    // Durata provvisoria: viene riallineata al BPM del brano quando si accende
    _pulsazione = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _pulsazione.dispose();
    super.dispose();
  }

  /// Accende o spegne l'ambient, sincronizzandolo al BPM del brano.
  ///
  /// Il BPM arriva dal tag TBPM, che il PC scrive durante il download: su iOS
  /// non si puo' analizzare l'audio in uscita senza permessi che non vogliamo
  /// chiedere, quindi il tempo viene calcolato una volta sola sul computer.
  /// Senza BPM noto si usa un respiro lento, senza finta sincronia.
  void _toggleAmbiente(Track? track) {
    setState(() => _ambiente = !_ambiente);
    if (!_ambiente) {
      _pulsazione.stop();
      return;
    }
    final bpm = track?.bpm;
    final ms = (bpm != null && bpm >= 40 && bpm <= 220)
        ? (60000 / bpm).round()
        : 2000;
    _pulsazione.duration = Duration(milliseconds: ms);
    _pulsazione.repeat(reverse: true);
  }

  /// Scelta dell'animazione di transizione tra i brani.
  void _showAnimationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: AnimationThemeService.instance,
          builder: (context, _) {
            final servizio = AnimationThemeService.instance;
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      'Animazione tra i brani',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  // 'animations' e' static const: va letto dalla classe,
                  // non dall'istanza, altrimenti l'analisi fallisce.
                  ...AnimationThemeService.animations.map((a) {
                    final scelta = servizio.selectedType == a.type;
                    return ListTile(
                      leading: Icon(
                        a.icon,
                        color: scelta ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                      title: Text(
                        a.name,
                        style: TextStyle(
                          color: scelta ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: scelta ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        a.description,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                      trailing: scelta
                          ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                          : null,
                      onTap: () {
                        servizio.setAnimationType(a.type);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _apriTesti(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, a1, a2) => const LyricsScreen(),
        transitionsBuilder: (context, a1, a2, child) {
          return FadeTransition(opacity: a1, child: child);
        },
      ),
    );
  }

  /// Pulsante piccolo della riga in fondo: icona, eventuale etichetta sotto.
  Widget _azione({
    required IconData icona,
    required String suggerimento,
    required VoidCallback onTap,
    bool attivo = false,
    String? etichetta,
  }) {
    final colore = attivo ? AppTheme.primary : AppTheme.textSecondary;
    return Tooltip(
      message: suggerimento,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icona, size: 22, color: colore),
              if (etichetta != null)
                Text(
                  etichetta,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    color: colore,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShuffleModeSheet(BuildContext context, AudioPlayerService player) {
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
                    'Modalità Shuffle',
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
                    children: ShuffleMode.values.map((mode) {
                      final isSelected = player.shuffleMode == mode;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: isSelected ? AppTheme.primary.withOpacity(0.18) : Colors.transparent,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            mode.icon,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          mode.description,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22)
                            : null,
                        onTap: () {
                          player.setShuffleMode(mode);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(mode.icon, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Shuffle: ${mode.label}'),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppTheme.surfaceLight,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerGesti = AudioPlayerService.instance;
    return GestureDetector(
      // Swipe a destra: brano successivo. A sinistra: precedente.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 120) return;
        if (v > 0) {
          playerGesti.next();
        } else {
          playerGesti.previous();
        }
      },
      // Doppio tocco al centro: ricomincia il brano da capo.
      onDoubleTap: () => playerGesti.seek(Duration.zero),
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0 || _dragOffset > 0) {
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 600.0);
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 100 || (details.primaryVelocity != null && details.primaryVelocity! > 600)) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dragOffset = 0.0;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF16130B),
                  AppTheme.background,
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

                  if (track == null) {
                    return const Center(child: Text('Nessun brano in riproduzione'));
                  }

                  final maxDuration = player.duration.inMilliseconds.toDouble();
                  final limite = maxDuration > 0 ? maxDuration : 1.0;
                  final currentPos = (_trascinamento ??
                          player.position.inMilliseconds.toDouble())
                      .clamp(0.0, limite);
                  final party = PartyService.instance;

                  return LayoutBuilder(
                    builder: (context, vincoli) {
                  // La copertina prende lo spazio che resta: il resto della
                  // schermata ha altezza fissa, e su un telefono piccolo una
                  // copertina larga quanto lo schermo lo farebbe traboccare.
                  final larghezza = MediaQuery.of(context).size.width;
                  final riservato = player.lastErrorMessage != null ? 450.0 : 390.0;
                  final lato = math.max(
                    120.0,
                    math.min(larghezza * 0.78, vincoli.maxHeight - riservato),
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Column(
                      children: [
                        // Pillola indicatore swipe-down
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Top bar con dismiss button e playlist
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: AppTheme.textPrimary),
                              tooltip: 'Riduci a icona (scorri verso il basso)',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Column(
                              children: [
                                Text(
                                  'IN RIPRODUZIONE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  party.inParty
                                      ? 'Party ${party.code}'
                                      : (track.isOnline ? 'Streaming' : 'Libreria Locale'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.tune_rounded, size: 22, color: AppTheme.primary),
                                  tooltip: 'Equalizzatore audio',
                                  onPressed: () => EqualizerSheet.show(context),
                                ),
                                // Animazione di transizione, accanto all'EQ
                                ListenableBuilder(
                                  listenable: AnimationThemeService.instance,
                                  builder: (context, _) => IconButton(
                                    icon: Icon(
                                      AnimationThemeService.instance.currentTheme.icon,
                                      size: 22,
                                      color: AppTheme.primary,
                                    ),
                                    tooltip: 'Animazione tra i brani',
                                    onPressed: () => _showAnimationSheet(context),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.playlist_add_rounded, size: 26, color: AppTheme.textPrimary),
                                  tooltip: 'Aggiungi a playlist',
                                  onPressed: () => PlaylistPickerSheet.show(context, [track]),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Spacer(flex: 1),

                        // Artwork: toccandola si accende l'effetto ambient,
                        // un bagliore che pulsa a tempo col BPM del brano.
                        GestureDetector(
                          onTap: () => _toggleAmbiente(track),
                          child: AnimatedBuilder(
                            animation: _pulsazione,
                            builder: (context, child) {
                              final t = _ambiente ? _pulsazione.value : 0.0;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Bagliore dietro la copertina
                                  if (_ambiente)
                                    Container(
                                      width: lato * (1.03 + 0.12 * t),
                                      height: lato * (1.03 + 0.12 * t),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(40),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primary.withOpacity(0.18 + 0.32 * t),
                                            blurRadius: 40 + 60 * t,
                                            spreadRadius: 4 + 16 * t,
                                          ),
                                        ],
                                      ),
                                    ),
                                  child!,
                                ],
                              );
                            },
                            child: Hero(
                          tag: 'current_artwork',
                          child: AnimatedTrackTransition(
                            trackKey: track.id,
                            child: Container(
                              width: lato,
                              height: lato,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppTheme.goldBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    blurRadius: 36,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: TrackArtwork(
                                url: track.thumbnailUrl,
                                width: lato,
                                height: lato,
                                borderRadius: 28,
                              ),
                            ),
                          ),
                        ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Info Traccia & Badge Shuffle
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.displayArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListenableBuilder(
                              listenable: LikesService.instance,
                              builder: (context, _) {
                                final piace = LikesService.instance.isLiked(track);
                                return IconButton(
                                  icon: Icon(
                                    piace
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: piace ? AppTheme.primary : AppTheme.textSecondary,
                                    size: 26,
                                  ),
                                  tooltip: piace ? 'Rimuovi da Mi piace' : 'Mi piace',
                                  onPressed: () => LikesService.instance.toggle(track),
                                );
                              },
                            ),
                            if (player.shuffleMode != ShuffleMode.off)
                              GestureDetector(
                                onTap: () => _showShuffleModeSheet(context, player),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(player.shuffleMode.icon, size: 14, color: AppTheme.primary),
                                      const SizedBox(width: 5),
                                      Text(
                                        player.shuffleMode.label,
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        if (player.lastErrorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    player.lastErrorMessage!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Slider di avanzamento
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: AppTheme.primary,
                            inactiveTrackColor: const Color(0x33D4AF37),
                            thumbColor: AppTheme.primary,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentPos,
                            min: 0.0,
                            max: limite,
                            onChanged: (val) {
                              setState(() => _trascinamento = val);
                            },
                            onChangeEnd: (val) {
                              setState(() => _trascinamento = null);
                              player.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),

                        // Timestamp
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(Duration(milliseconds: currentPos.toInt())),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              Text(
                                _formatTime(player.duration),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Controls
                        // Minuti ascoltati oggi: stava dentro il tasto shuffle
                        // e lo rendeva larghissimo, sbilanciando tutta la riga.
                        // Con le "statistiche per nerd" accese la riga mostra
                        // invece formato, bitrate e peso del file.
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            StatsService.instance,
                            PlaybackSettings.instance,
                          ]),
                          builder: (context, _) {
                            final nerd = PlaybackSettings.instance.nerdStats
                                ? player.nerdStatsLabel
                                : '';
                            final mins = StatsService.instance.todayStat.listeningSeconds ~/ 60;
                            return Text(
                              nerd.isNotEmpty ? nerd : '$mins minuti ascoltati oggi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        // Tre zone: i laterali occupano lo stesso spazio, quindi
                        // il gruppo centrale resta centrato qualunque sia la
                        // larghezza di shuffle e repeat. Con spaceEvenly e un
                        // tasto shuffle largo, play e frecce finivano spostati.
                        Row(
                          children: [
                            // --- Shuffle, piccolo ---
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                // Un solo gestore per tocco e pressione lunga:
                                // dentro un IconButton l'InkWell intercetta il
                                // gesto e onLongPress non scatterebbe.
                                child: Tooltip(
                                  message: player.isShuffle
                                      ? 'Shuffle: ${player.shuffleMode.label} - tieni premuto per il tipo'
                                      : 'Shuffle casuale - tieni premuto per il tipo',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      // Un tocco: casuale puro, oppure spegne.
                                      if (player.shuffleMode == ShuffleMode.standard) {
                                        player.setShuffleMode(ShuffleMode.off);
                                      } else {
                                        player.setShuffleMode(ShuffleMode.standard);
                                      }
                                    },
                                    // Pressione lunga: menu con i tipi di shuffle.
                                    onLongPress: () => _showShuffleModeSheet(context, player),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        player.shuffleMode.icon,
                                        size: 22,
                                        color: player.isShuffle
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // --- Gruppo centrale: precedente, play, successivo ---
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                                  icon: Icon(Icons.skip_previous_rounded,
                                      size: 46, color: AppTheme.textPrimary),
                                  onPressed: () => player.previous(),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => player.togglePlayPause(),
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x55FFD700),
                                          blurRadius: 26,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: player.isBuffering
                                          ? const SizedBox(
                                              width: 32,
                                              height: 32,
                                              child: CircularProgressIndicator(
                                                  color: Colors.black, strokeWidth: 3),
                                            )
                                          : Icon(
                                              player.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 50,
                                              color: Colors.black,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                                  icon: Icon(Icons.skip_next_rounded,
                                      size: 46, color: AppTheme.textPrimary),
                                  onPressed: () => player.next(),
                                ),
                              ],
                            ),

                            // --- Repeat, piccolo ---
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: Icon(
                                    player.loopMode == PlayerLoopMode.one
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                    size: 22,
                                    color: player.loopMode != PlayerLoopMode.off
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                  ),
                                  tooltip: 'Ripetizione',
                                  onPressed: () => player.toggleLoopMode(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Testi, coda, timer, velocita', party e menu del brano.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _azione(
                              icona: Icons.lyrics_rounded,
                              suggerimento: 'Testi',
                              onTap: () => _apriTesti(context),
                            ),
                            _azione(
                              icona: Icons.queue_music_rounded,
                              suggerimento: 'Coda',
                              onTap: () => QueueSheet.show(context),
                            ),
                            _azione(
                              icona: Icons.bedtime_rounded,
                              suggerimento: 'Timer di spegnimento',
                              attivo: player.hasSleepTimer,
                              etichetta: player.sleepAfterTrack
                                  ? 'fine brano'
                                  : (player.sleepRemaining != null
                                      ? SleepTimerSheet.formatRemaining(player.sleepRemaining!)
                                      : null),
                              onTap: () => SleepTimerSheet.show(context),
                            ),
                            _azione(
                              icona: Icons.speed_rounded,
                              suggerimento: 'Velocità di riproduzione',
                              attivo: (player.speed - 1.0).abs() > 0.01,
                              etichetta: (player.speed - 1.0).abs() > 0.01
                                  ? '${AudioPlayerService.formatSpeed(player.speed)}x'
                                  : null,
                              onTap: () => SpeedSheet.show(context),
                            ),
                            _azione(
                              icona: Icons.groups_rounded,
                              suggerimento: 'Ascolta insieme',
                              attivo: party.inParty,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ListenTogetherScreen(),
                                  ),
                                );
                              },
                            ),
                            _azione(
                              icona: Icons.more_horiz_rounded,
                              suggerimento: 'Altro',
                              onTap: () => SongActionsSheet.show(context, track),
                            ),
                          ],
                        ),

                        const Spacer(flex: 1),
                      ],
                    ),
                  );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
