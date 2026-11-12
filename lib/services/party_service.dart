import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'app_notice.dart';
import 'audio_player_service.dart';

enum PartyRole { none, host, guest }

class PartyMember {
  final String id;
  final String name;
  final bool isHost;
  const PartyMember({required this.id, required this.name, this.isHost = false});
}

class PartyActivity {
  final String who;
  final String what;
  final DateTime at;
  const PartyActivity({required this.who, required this.what, required this.at});
}

/// "Ascolta insieme": piu' telefoni sulla stessa rete suonano lo stesso
/// brano, in sincrono.
///
/// Non c'e' un server esterno: chi crea il party fa da centro, e il codice
/// da condividere contiene il suo indirizzo sulla rete locale piu' tre
/// caratteri casuali che fanno da PIN. Funziona quindi tra dispositivi
/// collegati allo stesso Wi-Fi (o alla stessa VPN).
///
/// I brani in streaming vengono caricati da ciascun telefono per conto suo;
/// i file locali dell'host vengono serviti agli ospiti direttamente da lui.
class PartyService extends ChangeNotifier {
  static final PartyService instance = PartyService._();
  PartyService._();

  static const int port = 8765;
  static const int maxQueueFromGuests = 50;

  /// Trentadue simboli, senza I, O, 0 e 1: letti ad alta voce non si
  /// confondono tra loro.
  static const String _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const String _kNome = 'dovvoplay_party_name';

  PartyRole _role = PartyRole.none;
  String _code = '';
  String _pin = '';
  String _hostIp = '';
  String _myName = '';
  String _hostName = '';
  String _myId = '';
  bool _hostOnly = false;
  int _maxSize = 6;
  bool _reconnecting = false;
  bool _uscendo = false;
  int _rttMs = 0;
  int _offsetMs = 0;
  bool _clockSynced = false;

  List<PartyMember> _members = [];
  final List<PartyActivity> _activity = [];

  // --- lato host
  HttpServer? _server;
  final Map<String, WebSocket> _sockets = {};
  final Map<String, String> _names = {};
  int _contatore = 1;
  Timer? _battito;
  String? _ultimoId;
  bool _ultimoPlaying = false;
  int _ultimaPos = 0;
  int _ultimoInvio = 0;

  /// chiave -> brano locale che gli ospiti possono chiedere.
  final Map<String, Track> _serviti = {};

  /// id del brano -> chiave.
  final Map<String, String> _chiavi = {};

  // --- lato ospite
  WebSocket? _ws;
  Timer? _orologio;
  Map<String, dynamic>? _ultimoStato;
  bool _daAllineare = false;
  bool _ascoltoPlayer = false;

  PartyRole get role => _role;
  bool get inParty => _role != PartyRole.none;
  bool get isHost => _role == PartyRole.host;
  bool get isGuest => _role == PartyRole.guest;
  String get code => format(_code);
  String get rawCode => _code;
  String get myName => _myName;
  String get hostName => _hostName;
  String get myId => _myId;
  bool get hostOnly => _hostOnly;
  int get maxSize => _maxSize;
  bool get reconnecting => _reconnecting;
  int get rttMs => _rttMs;
  bool get clockSynced => _clockSynced;
  List<PartyMember> get members => List.unmodifiable(_members);
  List<PartyActivity> get activity => List.unmodifiable(_activity);

  /// true se da questo telefono si puo' comandare la musica.
  bool get canControl => _role != PartyRole.guest || !_hostOnly;

  // ----------------------------------------------------------------- codice

  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String format(String codice) => codice.length == 10
      ? '${codice.substring(0, 5)}-${codice.substring(5)}'
      : codice;

  static String _codifica(String ip, String pin) {
    final parti = ip.split('.');
    if (parti.length != 4) return '';
    var n = 0;
    for (final p in parti) {
      n = (n << 8) | ((int.tryParse(p) ?? 0) & 0xFF);
    }
    final sb = StringBuffer();
    for (var i = 6; i >= 0; i--) {
      sb.write(_alfabeto[(n >> (5 * i)) & 31]);
    }
    sb.write(pin);
    return sb.toString();
  }

  /// Restituisce [indirizzo, pin], oppure null se il codice non e' valido.
  static List<String>? _decodifica(String codice) {
    final c = normalize(codice);
    if (c.length != 10) return null;
    var n = 0;
    for (var i = 0; i < 7; i++) {
      final v = _alfabeto.indexOf(c[i]);
      if (v < 0) return null;
      n = (n << 5) | v;
    }
    if (n > 0xFFFFFFFF) return null;
    for (var i = 7; i < 10; i++) {
      if (!_alfabeto.contains(c[i])) return null;
    }
    final ip = '${(n >> 24) & 255}.${(n >> 16) & 255}.${(n >> 8) & 255}.${n & 255}';
    return [ip, c.substring(7)];
  }

  static bool isValidCode(String codice) => _decodifica(codice) != null;

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  // ------------------------------------------------------------------- nome

  Future<String> loadName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _myName = prefs.getString(_kNome) ?? '';
    } catch (_) {}
    return _myName;
  }

  Future<void> _salvaNome(String nome) async {
    _myName = nome;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNome, nome);
    } catch (_) {}
  }

  static String _pulisciNome(String nome, String ripiego) {
    var n = nome.trim();
    if (n.length > 24) n = n.substring(0, 24);
    return n.isEmpty ? ripiego : n;
  }

  // ------------------------------------------------------------------- rete

  Future<String?> _trovaIp() async {
    try {
      final interfacce = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      String? ripiego;
      for (final i in interfacce) {
        for (final a in i.addresses) {
          if (a.isLoopback || a.address.startsWith('169.254')) continue;
          // en0 e' il Wi-Fi su iPhone: va preferito alla rete cellulare.
          if (i.name == 'en0') return a.address;
          ripiego ??= a.address;
        }
      }
      return ripiego;
    } catch (e) {
      debugPrint('Avviso lettura IP: $e');
      return null;
    }
  }

  static String _mime(String percorso) {
    final p = percorso.toLowerCase();
    if (p.endsWith('.mp3')) return 'audio/mpeg';
    if (p.endsWith('.m4a') || p.endsWith('.alac')) return 'audio/mp4';
    if (p.endsWith('.aac')) return 'audio/aac';
    if (p.endsWith('.wav')) return 'audio/wav';
    if (p.endsWith('.flac')) return 'audio/flac';
    if (p.endsWith('.aif') || p.endsWith('.aiff')) return 'audio/aiff';
    if (p.endsWith('.caf')) return 'audio/x-caf';
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  static String _estensione(String percorso) {
    final punto = percorso.lastIndexOf('.');
    if (punto == -1 || punto < percorso.length - 6) return 'bin';
    return percorso.substring(punto + 1).toLowerCase();
  }

  /// Serve un file rispettando le richieste parziali: il lettore audio di
  /// iOS chiede i brani a pezzi e rifiuta un server che non lo consente.
  Future<void> _serviFile(HttpRequest req, File file) async {
    final res = req.response;
    try {
      if (!await file.exists()) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      final lunghezza = await file.length();
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.set(HttpHeaders.contentTypeHeader, _mime(file.path));

      var inizio = 0;
      var fine = lunghezza - 1;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=') && lunghezza > 0) {
        final spec = range.substring(6).split(',').first.trim();
        final trattino = spec.indexOf('-');
        if (trattino >= 0) {
          final a = spec.substring(0, trattino).trim();
          final b = spec.substring(trattino + 1).trim();
          if (a.isEmpty) {
            final ultimi = int.tryParse(b) ?? 0;
            inizio = lunghezza - ultimi;
            if (inizio < 0) inizio = 0;
          } else {
            inizio = int.tryParse(a) ?? 0;
            if (b.isNotEmpty) fine = int.tryParse(b) ?? fine;
          }
        }
        if (fine >= lunghezza) fine = lunghezza - 1;
        if (inizio > fine || inizio >= lunghezza) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$lunghezza');
          await res.close();
          return;
        }
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $inizio-$fine/$lunghezza',
        );
      }

      res.contentLength = lunghezza == 0 ? 0 : fine - inizio + 1;
      if (req.method == 'HEAD' || lunghezza == 0) {
        await res.close();
        return;
      }
      await res.addStream(file.openRead(inizio, fine + 1));
      await res.close();
    } catch (_) {
      // L'ospite ha chiuso la connessione a meta': succede a ogni cambio
      // brano e non e' un errore da segnalare.
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _gestisciRichiesta(HttpRequest req) async {
    try {
      final percorso = req.uri.path;
      final pin = req.uri.queryParameters['pin'] ?? '';
      if (pin != _pin || _role != PartyRole.host) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }

      if (percorso == '/party/ws') {
        if (!WebSocketTransformer.isUpgradeRequest(req)) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        _nuovoOspite(ws);
        return;
      }

      if (percorso.startsWith('/party/file/') || percorso.startsWith('/party/art/')) {
        final nome = percorso.substring(percorso.lastIndexOf('/') + 1);
        final punto = nome.indexOf('.');
        final chiave = punto == -1 ? nome : nome.substring(0, punto);
        final brano = _serviti[chiave];
        if (brano == null) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        if (percorso.startsWith('/party/file/')) {
          final fp = brano.filePath;
          if (fp == null) {
            req.response.statusCode = HttpStatus.notFound;
            await req.response.close();
            return;
          }
          await _serviFile(req, File(fp));
        } else {
          final cop = (brano.thumbnailUrl ?? '').replaceFirst('file://', '');
          await _serviFile(req, File(cop));
        }
        return;
      }

      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (e) {
      debugPrint('Avviso party, richiesta: $e');
    }
  }

  // ------------------------------------------------------------------- host

  /// Crea un party. Restituisce null se e' partito, altrimenti il motivo.
  Future<String?> createParty({
    required String name,
    bool hostOnly = false,
    int maxSize = 6,
  }) async {
    await leave();
    try {
      final ip = await _trovaIp();
      if (ip == null || ip.isEmpty) {
        return 'Nessuna rete trovata: collega il telefono allo stesso Wi-Fi degli amici.';
      }
      final nome = _pulisciNome(name, 'Host');
      await _salvaNome(nome);

      final rand = Random.secure();
      final sb = StringBuffer();
      for (var i = 0; i < 3; i++) {
        sb.write(_alfabeto[rand.nextInt(_alfabeto.length)]);
      }

      final server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server = server;
      _hostIp = ip;
      _pin = sb.toString();
      _code = _codifica(ip, _pin);
      _hostName = nome;
      _hostOnly = hostOnly;
      _maxSize = maxSize.clamp(2, 10);
      _myId = 'host';
      _role = PartyRole.host;
      _activity.clear();
      _ultimoId = null;
      _ultimoInvio = 0;
      _aggiornaMembriHost();

      server.listen(
        _gestisciRichiesta,
        onError: (Object e) => debugPrint('Avviso party, server: $e'),
      );

      AudioPlayerService.instance.addListener(_playerCambiatoHost);
      _ascoltoPlayer = true;
      _battito?.cancel();
      _battito = Timer.periodic(const Duration(seconds: 4), (_) => _trasmettiStato());

      notifyListeners();
      return null;
    } catch (e) {
      await _pulisci();
      return 'Impossibile avviare il party: $e';
    }
  }

  void _aggiornaMembriHost() {
    final lista = <PartyMember>[
      PartyMember(id: 'host', name: _hostName, isHost: true),
    ];
    for (final id in _sockets.keys) {
      lista.add(PartyMember(id: id, name: _names[id] ?? 'Ospite'));
    }
    _members = lista;
  }

  List<Map<String, dynamic>> _membriJson() => _members
      .map((m) => <String, dynamic>{'id': m.id, 'name': m.name, 'host': m.isHost})
      .toList();

  void _aOspite(String id, Map<String, dynamic> msg) {
    final ws = _sockets[id];
    if (ws == null) return;
    try {
      ws.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _aTutti(Map<String, dynamic> msg) {
    final testo = jsonEncode(msg);
    for (final ws in _sockets.values.toList()) {
      try {
        ws.add(testo);
      } catch (_) {}
    }
  }

  void _nuovoOspite(WebSocket ws) {
    // Il posto dell'host e' compreso nel conteggio.
    if (_sockets.length + 1 >= _maxSize) {
      try {
        ws.add(jsonEncode({'type': 'full'}));
        ws.close();
      } catch (_) {}
      return;
    }
    final id = 'm${_contatore++}';
    _sockets[id] = ws;
    _names[id] = 'Ospite';
    ws.pingInterval = const Duration(seconds: 10);
    ws.listen(
      (dynamic dati) => _messaggioDaOspite(id, dati),
      onDone: () => _ospiteUscito(id),
      onError: (Object _) => _ospiteUscito(id),
      cancelOnError: true,
    );
  }

  void _ospiteUscito(String id) {
    if (!_sockets.containsKey(id)) return;
    final nome = _names[id] ?? 'Ospite';
    _sockets.remove(id);
    _names.remove(id);
    if (_role != PartyRole.host) return;
    _aggiornaMembriHost();
    _registra(nome, "E' uscito dal party");
    _trasmettiStato();
    notifyListeners();
  }

  void _messaggioDaOspite(String id, dynamic dati) {
    if (dati is! String) return;
    dynamic m;
    try {
      m = jsonDecode(dati);
    } catch (_) {
      return;
    }
    if (m is! Map) return;
    final tipo = m['type'];

    if (tipo == 'hello') {
      final nome = _pulisciNome(m['name']?.toString() ?? '', 'Ospite');
      _names[id] = nome;
      _aggiornaMembriHost();
      _aOspite(id, {
        'type': 'welcome',
        'you': id,
        'host': _hostName,
        'hostOnly': _hostOnly,
        'maxSize': _maxSize,
      });
      _registra(nome, "E' entrato nel party");
      _trasmettiStato();
      notifyListeners();
    } else if (tipo == 'ping') {
      _aOspite(id, {
        'type': 'pong',
        't': m['t'],
        's': DateTime.now().millisecondsSinceEpoch,
      });
    } else if (tipo == 'cmd') {
      _comandoDaOspite(id, m);
    }
  }

  void _comandoDaOspite(String id, Map m) {
    if (_hostOnly) {
      _aOspite(id, {'type': 'denied'});
      return;
    }
    final p = AudioPlayerService.instance;
    final chi = _names[id] ?? 'Ospite';
    final azione = m['action'];

    if (azione == 'toggle') {
      _registra(chi, p.isPlaying ? 'Ha messo in pausa' : 'Ha avviato la riproduzione');
      p.togglePlayPause();
    } else if (azione == 'next') {
      _registra(chi, "E' andato avanti");
      p.next();
    } else if (azione == 'prev') {
      _registra(chi, "E' tornato indietro");
      p.previous();
    } else if (azione == 'seek') {
      final ms = m['positionMs'];
      if (ms is num) {
        _registra(chi, "Si e' spostato nel brano");
        p.seek(Duration(milliseconds: ms.toInt()));
      }
    } else if (azione == 'add' || azione == 'playNext') {
      final tj = m['track'];
      if (tj is! Map) return;
      if (p.queue.length - p.currentIndex > maxQueueFromGuests) {
        _aOspite(id, {'type': 'queueFull', 'max': maxQueueFromGuests});
        return;
      }
      final videoId = tj['videoId']?.toString() ?? '';
      if (videoId.isEmpty) return;
      final durata = tj['durationMs'];
      final brano = Track(
        id: 'yt_$videoId',
        title: tj['title']?.toString() ?? '',
        artist: tj['artist']?.toString() ?? '',
        album: tj['album']?.toString() ?? '',
        duration: Duration(milliseconds: durata is num ? durata.toInt() : 0),
        isOnline: true,
        thumbnailUrl: tj['art']?.toString(),
      );
      if (p.currentTrack == null) {
        p.playTrack(brano, newQueue: [brano]);
      } else if (azione == 'playNext') {
        p.playNext(brano);
      } else {
        p.addToQueue(brano);
      }
      _registra(chi, 'Ha aggiunto alla coda "${brano.displayTitle}"');
    }
  }

  /// Solo l'host: decide se gli ospiti possono comandare la musica.
  void setHostOnly(bool v) {
    if (_role != PartyRole.host) return;
    _hostOnly = v;
    _registra(_hostName, v ? 'Ora controlla la musica da solo' : 'Ha dato i controlli a tutti');
    _trasmettiStato();
    notifyListeners();
  }

  /// Solo l'host: allontana un ospite.
  void removeMember(String id) {
    if (_role != PartyRole.host) return;
    final ws = _sockets[id];
    if (ws == null) return;
    final nome = _names[id] ?? 'Ospite';
    try {
      ws.add(jsonEncode({'type': 'kicked'}));
      ws.close();
    } catch (_) {}
    _sockets.remove(id);
    _names.remove(id);
    _aggiornaMembriHost();
    _registra(_hostName, 'Ha rimosso $nome');
    _trasmettiStato();
    notifyListeners();
  }

  Map<String, dynamic> _descriviBrano(Track t) {
    final base = <String, dynamic>{
      'title': t.displayTitle,
      'artist': t.displayArtist,
      'album': t.album,
      'durationMs': t.duration.inMilliseconds,
    };
    if (t.id.startsWith('yt_')) {
      base['kind'] = 'yt';
      base['id'] = t.id;
      base['art'] = t.thumbnailUrl;
      return base;
    }

    // File locale: gli ospiti lo chiedono a questo telefono.
    var chiave = _chiavi[t.id];
    if (chiave == null) {
      chiave = 'k${_chiavi.length + 1}';
      _chiavi[t.id] = chiave;
    }
    _serviti[chiave] = t;
    base['kind'] = 'file';
    base['id'] = 'party_${_hash('${t.displayArtist}|${t.displayTitle}')}';
    final origine = t.filePath ?? '';
    base['url'] = '/party/file/$chiave.${_estensione(origine)}';
    final cop = t.thumbnailUrl ?? '';
    if (cop.startsWith('http')) {
      base['art'] = cop;
    } else if (cop.isNotEmpty) {
      base['art'] = '/party/art/$chiave.${_estensione(cop)}';
    }
    return base;
  }

  void _trasmettiStato() {
    if (_role != PartyRole.host) return;
    final p = AudioPlayerService.instance;
    final t = p.currentTrack;
    final suona = p.isPlaying && !p.isBuffering;
    final adesso = DateTime.now().millisecondsSinceEpoch;
    final pos = p.position.inMilliseconds;

    _ultimoId = t?.id;
    _ultimoPlaying = suona;
    _ultimaPos = pos;
    _ultimoInvio = adesso;

    if (_sockets.isEmpty) return;
    _aTutti({
      'type': 'state',
      'track': t == null ? null : _descriviBrano(t),
      'positionMs': pos,
      'playing': suona,
      'speed': p.speed,
      'at': adesso,
      'hostOnly': _hostOnly,
      'members': _membriJson(),
    });
  }

  void _playerCambiatoHost() {
    if (_role != PartyRole.host || _sockets.isEmpty) return;
    final p = AudioPlayerService.instance;
    final suona = p.isPlaying && !p.isBuffering;
    var cambiato = p.currentTrack?.id != _ultimoId || suona != _ultimoPlaying;
    if (!cambiato && _ultimoInvio > 0) {
      // Un salto di posizione che il tempo trascorso non spiega: qualcuno
      // ha spostato il cursore.
      final adesso = DateTime.now().millisecondsSinceEpoch;
      final trascorso = suona ? ((adesso - _ultimoInvio) * p.speed).round() : 0;
      final atteso = _ultimaPos + trascorso;
      if ((p.position.inMilliseconds - atteso).abs() > 1800) cambiato = true;
    }
    if (cambiato) _trasmettiStato();
  }

  void _registra(String chi, String cosa) {
    _activity.insert(0, PartyActivity(who: chi, what: cosa, at: DateTime.now()));
    if (_activity.length > 100) _activity.removeRange(100, _activity.length);
    if (_role == PartyRole.host) {
      _aTutti({'type': 'activity', 'who': chi, 'what': cosa});
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- ospite

  /// Entra in un party. Restituisce null se e' andata bene.
  Future<String?> joinParty({required String code, required String name}) async {
    final dec = _decodifica(code);
    if (dec == null) {
      return 'Codice non valido: sono dieci tra lettere e cifre.';
    }
    await leave();
    final nome = _pulisciNome(name, 'Ospite');
    await _salvaNome(nome);

    _hostIp = dec[0];
    _pin = dec[1];
    _code = normalize(code);
    final errore = await _collega();
    if (errore != null) {
      await _pulisci();
      return errore;
    }
    _role = PartyRole.guest;
    _activity.clear();
    if (!_ascoltoPlayer) {
      AudioPlayerService.instance.addListener(_playerCambiatoOspite);
      _ascoltoPlayer = true;
    }
    _orologio?.cancel();
    _orologio = Timer.periodic(const Duration(seconds: 5), (_) => _ping());
    _aHost({'type': 'hello', 'name': nome});
    _ping();
    notifyListeners();
    return null;
  }

  Future<String?> _collega() async {
    try {
      final ws = await WebSocket.connect(
        'ws://$_hostIp:$port/party/ws?pin=$_pin',
      ).timeout(const Duration(seconds: 8));
      ws.pingInterval = const Duration(seconds: 10);
      _ws = ws;
      ws.listen(
        _messaggioDaHost,
        onDone: _hostPerso,
        onError: (Object _) => _hostPerso(),
        cancelOnError: true,
      );
      return null;
    } catch (e) {
      return 'Party non raggiungibile. Controlla il codice e che siate sulla stessa rete Wi-Fi.';
    }
  }

  void _aHost(Map<String, dynamic> msg) {
    try {
      _ws?.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _ping() {
    if (_role != PartyRole.guest) return;
    _aHost({'type': 'ping', 't': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> _hostPerso() async {
    if (_uscendo || _role != PartyRole.guest || _reconnecting) return;
    _reconnecting = true;
    _ws = null;
    notifyListeners();

    for (var tentativo = 0; tentativo < 3; tentativo++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_role != PartyRole.guest || _uscendo) {
        _reconnecting = false;
        return;
      }
      final errore = await _collega();
      if (errore == null) {
        _reconnecting = false;
        _aHost({'type': 'hello', 'name': _myName});
        _ping();
        notifyListeners();
        return;
      }
    }
    _reconnecting = false;
    await leave(motivo: 'Party terminato: host non raggiungibile.');
  }

  void _messaggioDaHost(dynamic dati) {
    if (dati is! String) return;
    dynamic m;
    try {
      m = jsonDecode(dati);
    } catch (_) {
      return;
    }
    if (m is! Map) return;
    final tipo = m['type'];

    if (tipo == 'welcome') {
      _myId = m['you']?.toString() ?? '';
      _hostName = m['host']?.toString() ?? 'Host';
      _hostOnly = m['hostOnly'] == true;
      final max = m['maxSize'];
      if (max is num) _maxSize = max.toInt();
      notifyListeners();
    } else if (tipo == 'pong') {
      final t = m['t'];
      final s = m['s'];
      if (t is num && s is num) {
        final adesso = DateTime.now().millisecondsSinceEpoch;
        final rtt = adesso - t.toInt();
        if (rtt >= 0 && rtt < 5000) {
          // Si tiene la misura col giro piu' breve: e' la piu' affidabile.
          if (!_clockSynced || rtt <= _rttMs + 40) {
            _offsetMs = s.toInt() - (t.toInt() + rtt ~/ 2);
          }
          _rttMs = rtt;
          _clockSynced = true;
          notifyListeners();
        }
      }
    } else if (tipo == 'state') {
      _ultimoStato = Map<String, dynamic>.from(m);
      _applicaStato();
    } else if (tipo == 'activity') {
      _activity.insert(
        0,
        PartyActivity(
          who: m['who']?.toString() ?? '',
          what: m['what']?.toString() ?? '',
          at: DateTime.now(),
        ),
      );
      if (_activity.length > 100) _activity.removeRange(100, _activity.length);
      notifyListeners();
    } else if (tipo == 'denied') {
      AppNotice.show("Solo l'host può controllare la musica");
    } else if (tipo == 'queueFull') {
      AppNotice.show('La coda del party è piena');
    } else if (tipo == 'full') {
      leave(motivo: 'Questo party è al completo.');
    } else if (tipo == 'kicked') {
      leave(motivo: "L'host ti ha rimosso dal party.");
    } else if (tipo == 'bye') {
      leave(motivo: "L'host ha chiuso il party.");
    }
  }

  Track _branoDa(Map tj) {
    final durata = tj['durationMs'];
    final ms = durata is num ? durata.toInt() : 0;
    final titolo = tj['title']?.toString() ?? '';
    final artista = tj['artist']?.toString() ?? '';
    final album = tj['album']?.toString() ?? '';
    final id = tj['id']?.toString() ?? 'party_sconosciuto';
    String? cop = tj['art']?.toString();
    if (cop != null && cop.startsWith('/')) {
      cop = 'http://$_hostIp:$port$cop?pin=$_pin';
    }

    if (tj['kind'] == 'yt') {
      return Track(
        id: id,
        title: titolo,
        artist: artista,
        album: album,
        duration: Duration(milliseconds: ms),
        isOnline: true,
        thumbnailUrl: cop,
      );
    }
    final url = tj['url']?.toString() ?? '';
    return Track(
      id: id,
      title: titolo,
      artist: artista,
      album: album,
      duration: Duration(milliseconds: ms),
      streamUrl: 'http://$_hostIp:$port$url?pin=$_pin',
      thumbnailUrl: cop,
    );
  }

  /// Dove dovrebbe trovarsi adesso la riproduzione secondo l'host.
  int _posizioneAttesa(Map<String, dynamic> stato) {
    final base = stato['positionMs'];
    final at = stato['at'];
    final velocita = stato['speed'];
    var pos = base is num ? base.toInt() : 0;
    if (stato['playing'] == true && at is num) {
      final oraHost = DateTime.now().millisecondsSinceEpoch + _offsetMs;
      final v = velocita is num ? velocita.toDouble() : 1.0;
      final trascorso = ((oraHost - at.toInt()) * v).round();
      if (trascorso > 0) pos += trascorso;
    }
    return pos;
  }

  void _applicaStato() {
    final stato = _ultimoStato;
    if (stato == null || _role != PartyRole.guest) return;

    _hostOnly = stato['hostOnly'] == true;
    final membri = stato['members'];
    if (membri is List) {
      final lista = <PartyMember>[];
      for (final e in membri) {
        if (e is! Map) continue;
        lista.add(PartyMember(
          id: e['id']?.toString() ?? '',
          name: e['name']?.toString() ?? '',
          isHost: e['host'] == true,
        ));
      }
      _members = lista;
    }
    notifyListeners();

    final p = AudioPlayerService.instance;
    final tj = stato['track'];
    if (tj is! Map) {
      if (p.isPlaying) p.pause();
      return;
    }

    final brano = _branoDa(tj);
    final velocita = stato['speed'];
    if (velocita is num && (velocita.toDouble() - p.speed).abs() > 0.01) {
      p.setSpeed(velocita.toDouble());
    }

    if (p.currentTrack?.id != brano.id) {
      // Brano nuovo: lo si carica e ci si allinea appena e' pronto.
      _daAllineare = true;
      p.playTrack(brano, newQueue: [brano]);
      return;
    }
    if (p.isBuffering) {
      _daAllineare = true;
      return;
    }
    _allinea(stato);
  }

  void _allinea(Map<String, dynamic> stato) {
    final p = AudioPlayerService.instance;
    final suona = stato['playing'] == true;
    final atteso = _posizioneAttesa(stato);
    final durata = p.duration.inMilliseconds;
    final scarto = (p.position.inMilliseconds - atteso).abs();

    if (scarto > 1500 && (durata == 0 || atteso < durata - 1000)) {
      p.seekDirect(Duration(milliseconds: atteso < 0 ? 0 : atteso));
    }
    if (suona && !p.isPlaying) {
      p.play();
    } else if (!suona && p.isPlaying) {
      p.pause();
    }
  }

  void _playerCambiatoOspite() {
    if (_role != PartyRole.guest || !_daAllineare) return;
    final p = AudioPlayerService.instance;
    final stato = _ultimoStato;
    if (stato == null || p.isBuffering) return;
    if (p.duration <= Duration.zero) return;
    _daAllineare = false;
    _allinea(stato);
  }

  // ------------------------------------------------- comandi dall'interfaccia

  /// Chiamato dal player prima di eseguire un comando. Se restituisce true
  /// il comando e' stato preso in carico dal party e il player non deve fare
  /// nulla: un ospite non comanda il proprio lettore, chiede all'host.
  bool interceptCommand(String azione, {int? positionMs}) {
    if (_role != PartyRole.guest) return false;
    if (_hostOnly) {
      AppNotice.show("Solo l'host può controllare la musica");
      return true;
    }
    final m = <String, dynamic>{'type': 'cmd', 'action': azione};
    if (positionMs != null) m['positionMs'] = positionMs;
    _aHost(m);
    return true;
  }

  /// Come [interceptCommand], per l'aggiunta di un brano alla coda.
  bool interceptAdd(Track track, {bool next = false}) {
    if (_role != PartyRole.guest) return false;
    if (_hostOnly) {
      AppNotice.show("Solo l'host può controllare la musica");
      return true;
    }
    if (!track.id.startsWith('yt_')) {
      AppNotice.show('Da ospite puoi aggiungere al party solo brani in streaming');
      return true;
    }
    _aHost({
      'type': 'cmd',
      'action': next ? 'playNext' : 'add',
      'track': {
        'videoId': track.id.substring(3),
        'title': track.displayTitle,
        'artist': track.displayArtist,
        'album': track.album,
        'durationMs': track.duration.inMilliseconds,
        'art': track.thumbnailUrl,
      },
    });
    AppNotice.show('Aggiunto alla coda del party');
    return true;
  }

  // ------------------------------------------------------------------ uscita

  Future<void> _pulisci() async {
    _battito?.cancel();
    _battito = null;
    _orologio?.cancel();
    _orologio = null;

    if (_ascoltoPlayer) {
      AudioPlayerService.instance.removeListener(_playerCambiatoHost);
      AudioPlayerService.instance.removeListener(_playerCambiatoOspite);
      _ascoltoPlayer = false;
    }

    for (final ws in _sockets.values.toList()) {
      try {
        ws.add(jsonEncode({'type': 'bye'}));
        await ws.close();
      } catch (_) {}
    }
    _sockets.clear();
    _names.clear();

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;

    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;

    _serviti.clear();
    _chiavi.clear();
    _ultimoStato = null;
    _daAllineare = false;
    _members = [];
    _clockSynced = false;
    _reconnecting = false;
    _rttMs = 0;
    _offsetMs = 0;
    _code = '';
    _pin = '';
    _hostIp = '';
    _myId = '';
    _hostOnly = false;
  }

  /// Esce dal party. Se era l'host, il party si chiude per tutti.
  Future<void> leave({String? motivo}) async {
    if (_role == PartyRole.none && _server == null && _ws == null) return;
    _uscendo = true;
    final eraOspite = _role == PartyRole.guest;
    _role = PartyRole.none;
    await _pulisci();
    _uscendo = false;
    if (eraOspite) {
      // Il brano dell'host non ha senso senza di lui.
      try {
        await AudioPlayerService.instance.pause();
      } catch (_) {}
    }
    notifyListeners();
    if (motivo != null) AppNotice.show(motivo);
  }
}
