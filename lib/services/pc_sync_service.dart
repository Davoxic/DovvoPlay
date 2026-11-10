import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
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
    _pcHost = host.trim();
    _pcPort = port;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefHostKey, _pcHost);
      await prefs.setInt(_prefPortKey, _pcPort);
    } catch (_) {}
    await testConnection();
  }

  /// Esegue un ping di verifica verso l'indirizzo configurato
  Future<bool> testConnection() async {
    if (_pcHost.isEmpty) {
      _isConnected = false;
      _statusMessage = 'Nessun indirizzo PC configurato';
      notifyListeners();
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/ping');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        _isConnected = true;
        _statusMessage = 'Connesso a PC ($_pcHost:$_pcPort)';
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isConnected = false;
    _statusMessage = 'PC non raggiungibile su $_pcHost:$_pcPort';
    notifyListeners();
    return false;
  }

  /// Scansiona la subnet locale (es. 192.168.1.x o 192.168.0.x) alla ricerca del server PC
  Future<String?> discoverPcOnLan({int port = 8080}) async {
    _isSearching = true;
    _statusMessage = 'Ricerca PC sulla rete Wi-Fi in corso...';
    notifyListeners();

    try {
      // 1. Trova l'IP locale del dispositivo
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? subnetPrefix;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
        if (subnetPrefix != null) break;
      }

      subnetPrefix ??= '192.168.1';

      // 2. Prova subito i candidati più probabili (.1, .2.. .50) in parallelo
      final futures = <Future<String?>>[];
      for (int i = 1; i <= 60; i++) {
        final targetIp = '$subnetPrefix.$i';
        futures.add(() async {
          try {
            final uri = Uri.parse('http://$targetIp:$port/ping');
            final res = await http.get(uri).timeout(const Duration(milliseconds: 1400));
            if (res.statusCode == 200) {
              return targetIp;
            }
          } catch (_) {}
          return null;
        }());
      }

      final results = await Future.wait(futures);
      for (final ip in results) {
        if (ip != null) {
          await setHostAndPort(ip, port);
          _isSearching = false;
          _statusMessage = 'PC trovato: $ip:$port!';
          notifyListeners();
          return ip;
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
