import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../theme.dart';

/// Timer di spegnimento: mette in pausa dopo un certo tempo, oppure alla
/// fine del brano in riproduzione.
class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const SleepTimerSheet(),
    );
  }

  /// "12:05" oppure "1:02:05".
  static String formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  Timer? _tic;

  static const List<int> _minuti = [5, 10, 15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    // Il conto alla rovescia va ridisegnato ogni secondo.
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final resto = player.sleepRemaining;
    final aFineBrano = player.sleepAfterTrack;
    final attivo = player.hasSleepTimer;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
                child: Text(
                  'Timer di spegnimento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  attivo
                      ? (aFineBrano
                          ? 'In pausa alla fine di questo brano'
                          : '${SleepTimerSheet.formatRemaining(resto ?? Duration.zero)} alla pausa della riproduzione')
                      : 'Metti in pausa la riproduzione dopo un po\'',
                  style: TextStyle(
                    color: attivo ? AppTheme.primary : AppTheme.textMuted,
                    fontSize: 12.5,
                    fontWeight: attivo ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _minuti.map((m) {
                    final etichetta = m == 60 ? '1 ora' : (m == 90 ? '1 ora e mezza' : '$m min');
                    return ActionChip(
                      label: Text(
                        etichetta,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      backgroundColor: AppTheme.surfaceLight,
                      side: BorderSide(color: AppTheme.goldBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      onPressed: () {
                        player.startSleepTimer(Duration(minutes: m));
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(
                  Icons.skip_next_rounded,
                  color: aFineBrano ? AppTheme.primary : AppTheme.textPrimary,
                ),
                title: Text(
                  'Dopo questo brano',
                  style: TextStyle(
                    color: aFineBrano ? AppTheme.primary : AppTheme.textPrimary,
                    fontSize: 14.5,
                  ),
                ),
                trailing: aFineBrano
                    ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                    : null,
                onTap: () {
                  player.sleepAfterCurrentTrack();
                  Navigator.pop(context);
                },
              ),
              if (attivo)
                ListTile(
                  leading: const Icon(Icons.timer_off_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Disattiva timer',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.5),
                  ),
                  onTap: () {
                    player.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Velocita' di riproduzione, da meta' al doppio.
class SpeedSheet extends StatelessWidget {
  const SpeedSheet({super.key});

  static const List<double> _passi = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const SpeedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioPlayerService.instance,
      builder: (context, _) {
        final player = AudioPlayerService.instance;
        final attuale = player.speed;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Velocità di riproduzione',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${AudioPlayerService.formatSpeed(attuale)}x',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _passi.map((v) {
                    final scelto = (v - attuale).abs() < 0.01;
                    return ChoiceChip(
                      label: Text(
                        '${AudioPlayerService.formatSpeed(v)}x',
                        style: TextStyle(
                          color: scelto ? Colors.black : AppTheme.textPrimary,
                          fontWeight: scelto ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      selected: scelto,
                      showCheckmark: false,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceLight,
                      side: BorderSide(color: AppTheme.goldBorder),
                      onSelected: (_) => player.setSpeed(v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.primary,
                  ),
                  child: Slider(
                    value: attuale.clamp(0.5, 2.0),
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (v) => player.setSpeed(v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
