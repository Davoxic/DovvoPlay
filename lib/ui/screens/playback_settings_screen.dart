import 'package:flutter/material.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/playback_settings.dart';
import '../../services/scrobble_service.dart';
import '../theme.dart';
import '../widgets/player_sheets.dart';
import 'downloads_screen.dart';

/// Impostazioni di riproduzione, streaming, testi e scrobbling.
class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  Widget _sezione(String titolo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Text(
        titolo,
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: AppTheme.secondary,
        ),
      ),
    );
  }

  Widget _interruttore({
    required IconData icona,
    required String titolo,
    required String sottotitolo,
    required bool valore,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: valore,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
      secondary: Icon(icona, color: AppTheme.primary),
      title: Text(
        titolo,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        sottotitolo,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _voce({
    required IconData icona,
    required String titolo,
    required String sottotitolo,
    required VoidCallback onTap,
    Color? colore,
  }) {
    return ListTile(
      leading: Icon(icona, color: colore ?? AppTheme.primary),
      title: Text(
        titolo,
        style: TextStyle(
          color: colore ?? AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        sottotitolo,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  void _collegaListenBrainz(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _DialogoToken(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PlaybackSettings.instance,
        ScrobbleService.instance,
      ]),
      builder: (context, _) {
        final s = PlaybackSettings.instance;
        final scrobble = ScrobbleService.instance;
        final player = AudioPlayerService.instance;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Riproduzione')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _sezione('RIPRODUZIONE'),
              _interruttore(
                icona: Icons.all_inclusive_rounded,
                titolo: 'AutoPlay',
                sottotitolo: 'A coda finita continua con musica simile all\'ultimo brano',
                valore: s.autoplay,
                onChanged: s.setAutoplay,
              ),
              _interruttore(
                icona: Icons.repeat_on_rounded,
                titolo: 'Non ripetere i brani nella sessione',
                sottotitolo: 'AutoPlay non ripropone un brano già suggerito',
                valore: s.noRepeatAutoplay,
                onChanged: s.setNoRepeatAutoplay,
              ),
              ListTile(
                leading: Icon(Icons.blur_linear_rounded, color: AppTheme.primary),
                title: Text(
                  'Dissolvenza tra i brani',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fadeSeconds == 0
                          ? 'Disattivata'
                          : 'Sfuma gli ultimi ${s.fadeSeconds} secondi e l\'attacco del brano dopo',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: AppTheme.primary,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: s.fadeSeconds.toDouble(),
                        min: 0,
                        max: 12,
                        divisions: 12,
                        label: s.fadeSeconds == 0 ? 'No' : '${s.fadeSeconds} s',
                        onChanged: (v) => s.setFadeSeconds(v.round()),
                      ),
                    ),
                  ],
                ),
              ),
              _voce(
                icona: Icons.speed_rounded,
                titolo: 'Velocità di riproduzione',
                sottotitolo: '${AudioPlayerService.formatSpeed(player.speed)}x',
                onTap: () => SpeedSheet.show(context),
              ),
              _voce(
                icona: Icons.bedtime_rounded,
                titolo: 'Timer di spegnimento',
                sottotitolo: player.hasSleepTimer
                    ? 'Attivo'
                    : 'Metti in pausa la riproduzione dopo un po\'',
                onTap: () => SleepTimerSheet.show(context),
              ),

              _sezione('STREAMING'),
              _interruttore(
                icona: Icons.data_saver_on_rounded,
                titolo: 'Risparmio dati',
                sottotitolo:
                    'Lo streaming sceglie il flusso audio più leggero. I download restano alla qualità più alta',
                valore: s.dataSaver,
                onChanged: s.setDataSaver,
              ),
              _interruttore(
                icona: Icons.developer_board_rounded,
                titolo: 'Mostra statistiche per nerd',
                sottotitolo: 'Formato, bitrate e peso del file nel player',
                valore: s.nerdStats,
                onChanged: s.setNerdStats,
              ),
              _voce(
                icona: Icons.download_rounded,
                titolo: 'Download e archiviazione',
                sottotitolo: 'Coda dei download, cache dei brani e delle immagini',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
                  );
                },
              ),

              _sezione('TESTI'),
              _interruttore(
                icona: Icons.lyrics_rounded,
                titolo: 'Testi sincronizzati',
                sottotitolo: 'Evidenzia la riga sul player mentre viene cantata',
                valore: s.syncedLyrics,
                onChanged: s.setSyncedLyrics,
              ),
              _interruttore(
                icona: Icons.blur_on_rounded,
                titolo: 'Sfoca testi non a fuoco',
                sottotitolo: 'Mantiene l\'attenzione sulla riga corrente',
                valore: s.blurLyrics,
                onChanged: s.setBlurLyrics,
              ),

              _sezione('SCROBBLING'),
              if (!scrobble.isConnected)
                _voce(
                  icona: Icons.podcasts_rounded,
                  titolo: 'Collega ListenBrainz',
                  sottotitolo: 'Registra i tuoi ascolti nel tuo profilo ListenBrainz',
                  onTap: () => _collegaListenBrainz(context),
                )
              else ...[
                _interruttore(
                  icona: Icons.podcasts_rounded,
                  titolo: 'Registra i brani (scrobble)',
                  sottotitolo: scrobble.userName.isEmpty
                      ? 'Connesso a ListenBrainz'
                      : 'Connesso come ${scrobble.userName}'
                          '${scrobble.sentCount > 0 ? ' · ${scrobble.sentCount} inviati ora' : ''}',
                  valore: scrobble.enabled,
                  onChanged: scrobble.setEnabled,
                ),
                if (scrobble.lastError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 20, 4),
                    child: Text(
                      'Ultimo invio non riuscito: ${scrobble.lastError}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                    ),
                  ),
                _voce(
                  icona: Icons.link_off_rounded,
                  titolo: 'Disconnetti ListenBrainz',
                  sottotitolo: 'Il token viene cancellato da questo dispositivo',
                  colore: Colors.redAccent,
                  onTap: () async {
                    await scrobble.disconnect();
                    AppNotice.show('ListenBrainz disconnesso');
                  },
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Un ascolto viene registrato quando hai sentito almeno metà del brano, '
                  'oppure quattro minuti. I brani sotto i trenta secondi non contano.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DialogoToken extends StatefulWidget {
  const _DialogoToken();

  @override
  State<_DialogoToken> createState() => _DialogoTokenState();
}

class _DialogoTokenState extends State<_DialogoToken> {
  final TextEditingController _token = TextEditingController();
  bool _verifica = false;
  String? _errore;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _collega() async {
    setState(() {
      _verifica = true;
      _errore = null;
    });
    final errore = await ScrobbleService.instance.connect(_token.text);
    if (!mounted) return;
    if (errore == null) {
      Navigator.pop(context);
      AppNotice.show('ListenBrainz collegato');
    } else {
      setState(() {
        _verifica = false;
        _errore = errore;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.goldBorder, width: 1.2),
      ),
      title: Text(
        'Token ListenBrainz',
        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incolla il tuo token utente: lo trovi su listenbrainz.org, nelle '
              'impostazioni del profilo. Resta su questo dispositivo e viene '
              'inviato solo a ListenBrainz.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _token,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Token utente',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                errorText: _errore,
                errorMaxLines: 3,
                filled: true,
                fillColor: Colors.black,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.goldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verifica ? null : () => Navigator.pop(context),
          child: Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _verifica ? null : _collega,
          child: Text(
            _verifica ? 'Verifica...' : 'Collega',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
