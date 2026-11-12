import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/party_service.dart';
import '../theme.dart';
import '../widgets/track_artwork.dart';

/// "Ascolta insieme": crea un party o entra in quello di un amico.
///
/// Chi crea il party riceve un codice di dieci caratteri da condividere;
/// chi lo inserisce sente la stessa musica, in sincrono. Funziona tra
/// telefoni collegati alla stessa rete Wi-Fi.
class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _codice = TextEditingController();
  bool _soloIo = false;
  double _dimensione = 6;
  bool _alLavoro = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    PartyService.instance.loadName().then((n) {
      if (mounted && _nome.text.isEmpty) _nome.text = n;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _codice.dispose();
    super.dispose();
  }

  Future<void> _crea() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _alLavoro = true;
      _errore = null;
    });
    final errore = await PartyService.instance.createParty(
      name: _nome.text,
      hostOnly: _soloIo,
      maxSize: _dimensione.round(),
    );
    if (!mounted) return;
    setState(() {
      _alLavoro = false;
      _errore = errore;
    });
  }

  Future<void> _entra() async {
    FocusScope.of(context).unfocus();
    if (!PartyService.isValidCode(_codice.text)) {
      setState(() => _errore = 'Codice non valido: sono dieci tra lettere e cifre.');
      return;
    }
    setState(() {
      _alLavoro = true;
      _errore = null;
    });
    final errore = await PartyService.instance.joinParty(
      code: _codice.text,
      name: _nome.text,
    );
    if (!mounted) return;
    setState(() {
      _alLavoro = false;
      _errore = errore;
    });
  }

  InputDecoration _decorazione(String suggerimento, IconData icona) {
    return InputDecoration(
      hintText: suggerimento,
      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
      prefixIcon: Icon(icona, color: AppTheme.primary, size: 20),
      isDense: true,
      filled: true,
      fillColor: AppTheme.surfaceCard,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.goldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.4),
      ),
    );
  }

  Widget _riquadro({required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: child,
    );
  }

  Widget _titoletto(String testo) {
    return Text(
      testo,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // --------------------------------------------------------------- ingresso

  Widget _ingresso() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: const Icon(Icons.groups_rounded, color: Colors.black, size: 38),
              ),
              const SizedBox(height: 14),
              Text(
                'Avvia un party',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Perché la musica suona meglio in compagnia. Invita gli amici '
                'collegati al tuo stesso Wi-Fi ad ascoltare e aggiungere brani '
                'in tempo reale.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.45),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.words,
            maxLength: 24,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: _decorazione('Soprannome per questo party', Icons.person_rounded)
                .copyWith(counterText: ''),
          ),
        ),
        if (_errore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              _errore!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
        _riquadro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titoletto('Crea un party'),
              const SizedBox(height: 2),
              Text(
                'Ricevi un codice da condividere con gli amici',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _soloIo,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _soloIo = v),
                title: Text(
                  'Solo io controllo la musica',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'Gli altri ascoltano con te, senza poter cambiare brano',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Dimensione del party',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${_dimensione.round()} dispositivi',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: AppTheme.primary,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _dimensione,
                  min: 2,
                  max: 10,
                  divisions: 8,
                  onChanged: (v) => setState(() => _dimensione = v),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _alLavoro ? null : _crea,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    _alLavoro ? 'Un momento...' : 'Crea un party',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        _riquadro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titoletto('Entra in un party'),
              const SizedBox(height: 10),
              TextField(
                controller: _codice,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 11,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.bold,
                ),
                decoration: _decorazione('Codice del party', Icons.key_rounded)
                    .copyWith(counterText: ''),
                onSubmitted: (_) => _entra(),
              ),
              const SizedBox(height: 6),
              Text(
                'Dieci tra lettere e cifre. Nel codice non compaiono I, O, 0 e 1.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _alLavoro ? null : _entra,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Entra', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.goldBorder, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- in party

  Widget _inParty() {
    final party = PartyService.instance;
    final host = party.isHost;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _riquadro(
          child: Column(
            children: [
              Text(
                'CODICE DEL PARTY',
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  party.code,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 32,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                host
                    ? 'Leggilo ad alta voce o invialo. Chi lo ha può entrare, fino a ${party.maxSize} dispositivi compreso il tuo.'
                    : 'Party di ${party.hostName}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: party.code));
                      AppNotice.show('Codice copiato');
                    },
                    icon: Icon(Icons.copy_rounded, size: 17, color: AppTheme.primary),
                    label: Text(
                      'Copia codice',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Share.share(
                        'Ascolta con me su DovvoPlay: apri "Ascolta insieme" e '
                        'inserisci il codice party ${party.code}\n'
                        '(dobbiamo essere sullo stesso Wi-Fi)',
                      );
                    },
                    icon: Icon(Icons.ios_share_rounded, size: 17, color: AppTheme.primary),
                    label: Text(
                      'Invita',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stato della sincronia (solo per gli ospiti)
        if (!host)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(
                  party.reconnecting
                      ? Icons.sync_problem_rounded
                      : (party.clockSynced ? Icons.sync_rounded : Icons.hourglass_top_rounded),
                  size: 16,
                  color: party.reconnecting ? Colors.orangeAccent : AppTheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    party.reconnecting
                        ? 'Riconnessione...'
                        : (party.clockSynced
                            ? 'In sincrono · ${party.rttMs} ms di andata e ritorno'
                            : 'Misurazione dell\'orologio...'),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

        // In riproduzione
        _riquadro(
          child: ListenableBuilder(
            listenable: AudioPlayerService.instance.currentTrackId,
            builder: (context, _) {
              final t = AudioPlayerService.instance.currentTrack;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titoletto('In riproduzione'),
                  const SizedBox(height: 10),
                  if (t == null)
                    Text(
                      host
                          ? 'Ancora nulla in riproduzione: avvia un brano e partirà per tutti.'
                          : 'Ancora nulla in riproduzione',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    )
                  else
                    Row(
                      children: [
                        TrackArtwork(
                          url: t.thumbnailUrl,
                          width: 52,
                          height: 52,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                t.displayArtist,
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
                      ],
                    ),
                  if (!host) ...[
                    const SizedBox(height: 8),
                    Text(
                      party.hostOnly
                          ? 'Solo l\'host può controllare la musica.'
                          : 'Puoi mettere in pausa, cambiare brano e aggiungere alla coda brani in streaming: dal menu di un brano scegli "Aggiungi alla coda".',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        // Chi c'e'
        _riquadro(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titoletto('In ascolto · ${party.members.length} di ${party.maxSize}'),
              const SizedBox(height: 6),
              for (final m in party.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    m.id == party.myId ? '${m.name} (tu)' : m.name,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5),
                  ),
                  subtitle: m.isHost
                      ? Text(
                          'Host',
                          style: TextStyle(color: AppTheme.secondary, fontSize: 11.5),
                        )
                      : null,
                  trailing: host && !m.isHost
                      ? IconButton(
                          icon: const Icon(
                            Icons.person_remove_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          tooltip: 'Rimuovi',
                          onPressed: () => party.removeMember(m.id),
                        )
                      : null,
                ),
              if (party.members.length <= 1 && host)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'In attesa degli amici...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                  ),
                ),
              if (host)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: party.hostOnly,
                  activeColor: AppTheme.primary,
                  onChanged: party.setHostOnly,
                  title: Text(
                    'Solo io controllo la musica',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),

        // Attivita'
        if (party.activity.isNotEmpty)
          _riquadro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titoletto('Attività recenti'),
                const SizedBox(height: 8),
                for (final a in party.activity.take(12))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${a.who}  ',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: a.what,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => party.leave(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(host ? 'Chiudi il party' : 'Esci dal party'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            host
                ? 'Chiudendo il party la musica si ferma per gli ospiti. I brani in streaming vengono caricati da ciascun telefono; i tuoi file locali vengono inviati agli ospiti da questo.'
                : 'Gli altri continuano ad ascoltare.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, height: 1.4),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PartyService.instance,
      builder: (context, _) {
        final party = PartyService.instance;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Ascolta insieme')),
          body: party.inParty ? _inParty() : _ingresso(),
        );
      },
    );
  }
}
