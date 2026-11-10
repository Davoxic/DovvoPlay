import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'library_service.dart';
import 'spotify_service.dart';
import 'youtube_service.dart';

class PcDownloadTask {
  final String id;
  final String title;
  final String artist;
  final String service; // 'youtube', 'spotify', 'soundcloud'
  final String status;  // 'queued', 'downloading', 'completed', 'failed'
  final double progress;
  final String? downloadUrl;

  const PcDownloadTask({
    required this.id,
    required this.title,
    required this.artist,
    required this.service,
    required this.status,
    this.progress = 0.0,
    this.downloadUrl,
  });

  factory PcDownloadTask.fromJson(Map<String, dynamic> json) => PcDownloadTask(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Brano',
        artist: json['artist']?.toString() ?? 'Artista',
        service: json['service']?.toString() ?? 'youtube',
        status: json['status']?.toString() ?? 'queued',
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        downloadUrl: json['downloadUrl']?.toString(),
      );
}

class PcSyncService extends ChangeNotifier {
  static final PcSyncService instance = PcSyncService._();
  PcSyncService._() {
    _loadSavedConfig();
  }

  static const String _prefHostKey = 'sborraplay_pc_host_ip_v2';
  static const String _prefPortKey = 'sborraplay_pc_port_v2';

  String _pcHost = '';
  int _pcPort = 8080;
  bool _isConnected = false;
  bool _isSearching = false;
  String _statusMessage = 'Nessun computer connesso';
  final List<PcDownloadTask> _activeTasks = [];

  String get pcHost => _pcHost;
  int get pcPort => _pcPort;
  bool get isConnected => _isConnected;
  bool get isSearching => _isSearching;
  String get statusMessage => _statusMessage;
  List<PcDownloadTask> get activeTasks => List.unmodifiable(_activeTasks);

  String get baseUrl => 'http://$_pcHost:$_pcPort';

  Future<void> _loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pcHost = prefs.getString(_prefHostKey) ?? '';
      _pcPort = prefs.getInt(_prefPortKey) ?? 8080;
      if (_pcHost.isNotEmpty) {
        testConnection();
      }
    } catch (_) {}
  }

  Future<void> setHostAndPort(String host, int port) async {
    String cleanHost = host.trim();
    // Rimuovi prefissi protocollo http:// o https://
    if (cleanHost.startsWith('http://')) cleanHost = cleanHost.substring(7);
    if (cleanHost.startsWith('https://')) cleanHost = cleanHost.substring(8);
    // Rimuovi percorsi trailing es. /ping o /
    if (cleanHost.contains('/')) {
      cleanHost = cleanHost.split('/').first.trim();
    }
    // Se l'utente ha scritto IP:PORTA (es. 192.168.1.174:8080)
    if (cleanHost.contains(':')) {
      final parts = cleanHost.split(':');
      cleanHost = parts[0].trim();
      if (parts.length > 1) {
        final parsedPort = int.tryParse(parts[1].trim());
        if (parsedPort != null && parsedPort > 0) port = parsedPort;
      }
    }

    _pcHost = cleanHost;
    _pcPort = port;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefHostKey, _pcHost);
      await prefs.setInt(_prefPortKey, _pcPort);
    } catch (_) {}

    await testConnection();
  }

  /// Esegue un ping di verifica verso l'indirizzo configurato con feedback dettagliato
  Future<bool> testConnection() async {
    if (_pcHost.isEmpty) {
      _isConnected = false;
      _statusMessage = 'Nessun indirizzo PC configurato';
      notifyListeners();
      return false;
    }

    _statusMessage = 'Verifica connessione con $_pcHost:$_pcPort...';
    notifyListeners();

    try {
      final uri = Uri.parse('$baseUrl/ping');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _isConnected = true;
        _statusMessage = 'Connesso al PC ($_pcHost:$_pcPort) 🟢';
        notifyListeners();
        return true;
      } else {
        _isConnected = false;
        _statusMessage = 'Il PC ha risposto con codice HTTP ${res.statusCode}';
        notifyListeners();
        return false;
      }
    } on SocketException catch (e) {
      _isConnected = false;
      final msg = e.message.toLowerCase();
      if (msg.contains('refused') || e.osError?.errorCode == 61) {
        _statusMessage = 'Connessione rifiutata: il server non è attivo su porta $_pcPort o l\'IP è errato.';
      } else if (msg.contains('unreachable') || msg.contains('host is down')) {
        _statusMessage = 'Host non raggiungibile: assicurati che iPhone e PC siano sullo stesso Wi-Fi.';
      } else {
        _statusMessage = 'Errore di rete: ${e.message}';
      }
    } on TimeoutException {
      _isConnected = false;
      _statusMessage = 'Timeout (4s): il PC non risponde. Assicurati che server.py sia avviato e che Windows Firewall non blocchi la porta $_pcPort.';
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'Errore: $e';
    }

    notifyListeners();
    return false;
  }

  /// Scansiona l'intera subnet locale (es. 192.168.1.1 - 254) alla ricerca del server PC
  Future<String?> discoverPcOnLan({int port = 8080}) async {
    _isSearching = true;
    _statusMessage = 'Ricerca automatica PC su rete locale (porta $port)...';
    notifyListeners();

    try {
      final subnets = <String>{};

      // 1. Trova l'IP locale del dispositivo
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
              }
            }
          }
        }
      } catch (_) {}

      if (subnets.isEmpty) {
        subnets.addAll(['192.168.1', '192.168.0', '192.168.178']);
      }

      for (final subnet in subnets) {
        // Range 1: Range DHCP più diffuso (100 -> 200) dove si posiziona tipicamente il PC
        final dhcpHosts = List.generate(101, (i) => 100 + i);
        final found1 = await _probeSubnet(subnet, dhcpHosts, port, 1200);
        if (found1 != null) {
          await setHostAndPort(found1, port);
          _isSearching = false;
          _statusMessage = 'PC trovato: $found1:$port! 🟢';
          notifyListeners();
          return found1;
        }

        // Range 2: Range numerico basso (1 -> 99)
        final lowHosts = List.generate(99, (i) => 1 + i);
        final found2 = await _probeSubnet(subnet, lowHosts, port, 1200);
        if (found2 != null) {
          await setHostAndPort(found2, port);
          _isSearching = false;
          _statusMessage = 'PC trovato: $found2:$port! 🟢';
          notifyListeners();
          return found2;
        }

        // Range 3: Range numerico alto (201 -> 254)
        final highHosts = List.generate(54, (i) => 201 + i);
        final found3 = await _probeSubnet(subnet, highHosts, port, 1200);
        if (found3 != null) {
          await setHostAndPort(found3, port);
          _isSearching = false;
          _statusMessage = 'PC trovato: $found3:$port! 🟢';
          notifyListeners();
          return found3;
        }
      }
    } catch (e) {
      print('Errore durante la ricerca LAN: $e');
    } finally {
      _isSearching = false;
      if (!_isConnected) {
        _statusMessage = 'Nessun server PC attivo trovato. Inserisci IP manualmente.';
      }
      notifyListeners();
    }
    return null;
  }

  /// Effettua probe parallelo su una lista di host con terminazione rapida al primo successo
  Future<String?> _probeSubnet(String subnet, List<int> hosts, int port, int timeoutMs) async {
    final completer = Completer<String?>();
    int pending = hosts.length;

    for (final h in hosts) {
      final target = '$subnet.$h';
      final uri = Uri.parse('http://$target:$port/ping');
      http.get(uri).timeout(Duration(milliseconds: timeoutMs)).then((res) {
        if (!completer.isCompleted && res.statusCode == 200) {
          completer.complete(target);
        } else {
          pending--;
          if (pending <= 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        pending--;
        if (pending <= 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future;
  }

  /// Invia una richiesta di download al backend PC per YouTube, Spotify o SoundCloud
  Future<bool> sendDownloadRequest({
    required String service,
    required String queryOrUrl,
    required String title,
    required String artist,
  }) async {
    if (!_isConnected) {
      final retested = await testConnection();
      if (!retested) return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/download');
      final body = jsonEncode({
        'service': service,
        'query': queryOrUrl,
        'title': title,
        'artist': artist,
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 202) {
        _activeTasks.insert(
          0,
          PcDownloadTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            artist: artist,
            service: service,
            status: 'downloading sul PC...',
          ),
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Errore sendDownloadRequest: $e');
    }
    return false;
  }

  /// Analizza una playlist Spotify ed esegue l'importazione
  /// Se [delegateToPc] è true: invia l'URL al PC per scaricare ed estrarre tutti i file
  /// Se [delegateToPc] è false: estrae i metadati in locale, cerca le canzoni su YouTube e crea la playlist
  Future<int> importSpotifyPlaylist(
    String spotifyUrl, {
    required bool delegateToPc,
    void Function(String step)? onStatus,
  }) async {
    final cleanUrl = spotifyUrl.trim();
    if (cleanUrl.isEmpty) return 0;

    if (delegateToPc) {
      onStatus?.call('Invio playlist Spotify al PC Companion...');
      try {
        final uri = Uri.parse('$baseUrl/api/spotify_playlist');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': cleanUrl}),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 || res.statusCode == 202) {
          onStatus?.call('Playlist presa in carico dal PC! Il download è in corso.');
          return 1;
        }
      } catch (e) {
        onStatus?.call('Errore comunicazione con PC: $e');
        return 0;
      }
    }

    // Modalità Analisi Locale
    onStatus?.call('Analisi della playlist Spotify in corso...');
    final plInfo = await SpotifyService.instance.parseSpotifyPlaylist(cleanUrl);
    if (plInfo == null || plInfo.tracks.isEmpty) {
      onStatus?.call('Impossibile estrarre brani dal link fornito.');
      return 0;
    }

    onStatus?.call('Creazione playlist "${plInfo.title}" (${plInfo.tracks.length} brani)...');
    final lib = LibraryService.instance;
    final createdPl = await lib.createPlaylist(plInfo.title);

    int foundAndAdded = 0;
    for (int i = 0; i < plInfo.tracks.length; i++) {
      final st = plInfo.tracks[i];
      onStatus?.call('Ricerca traccia ${i + 1}/${plInfo.tracks.length}: ${st.title}...');

      try {
        final query = '${st.artist} - ${st.title}';
        final ytTracks = await YouTubeService.instance.search(query);
        if (ytTracks.isNotEmpty) {
          final topYt = ytTracks.first;
          final track = topYt.toTrack();

          // Aggiungi alla libreria se assente
          if (!lib.tracks.any((x) => x.id == track.id)) {
            lib.tracks.add(track);
          }

          // Aggiungi alla playlist creata
          await lib.addTrackToPlaylist(createdPl.id, track.id);
          foundAndAdded++;
        }
      } catch (_) {}
    }

    onStatus?.call('Completato! $foundAndAdded brani aggiunti alla playlist "${plInfo.title}".');
    return foundAndAdded;
  }
}
