import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class TrackStat {
  final String trackId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  int playCount;
  int repeatCount;
  int completionCount;
  int totalDurationSeconds;
  DateTime lastPlayedAt;
  DateTime firstPlayedAt;

  TrackStat({
    required this.trackId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.playCount = 0,
    this.repeatCount = 0,
    this.completionCount = 0,
    this.totalDurationSeconds = 0,
    DateTime? lastPlayedAt,
    DateTime? firstPlayedAt,
  })  : lastPlayedAt = lastPlayedAt ?? DateTime.now(),
        firstPlayedAt = firstPlayedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'playCount': playCount,
        'repeatCount': repeatCount,
        'completionCount': completionCount,
        'totalDurationSeconds': totalDurationSeconds,
        'lastPlayedAt': lastPlayedAt.toIso8601String(),
        'firstPlayedAt': firstPlayedAt.toIso8601String(),
      };

  factory TrackStat.fromJson(Map<String, dynamic> json) => TrackStat(
        trackId: json['trackId'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        thumbnailUrl: json['thumbnailUrl'],
        playCount: json['playCount'] ?? 0,
        repeatCount: json['repeatCount'] ?? 0,
        completionCount: json['completionCount'] ?? 0,
        totalDurationSeconds: json['totalDurationSeconds'] ?? 0,
        lastPlayedAt: json['lastPlayedAt'] != null
            ? DateTime.tryParse(json['lastPlayedAt']) ?? DateTime.now()
            : DateTime.now(),
        firstPlayedAt: json['firstPlayedAt'] != null
            ? DateTime.tryParse(json['firstPlayedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class StatsService extends ChangeNotifier {
  static final StatsService instance = StatsService._();
  StatsService._() {
    _loadStats();
  }

  static const String _prefsKey = 'sborraplay_track_stats_v1';
  final Map<String, TrackStat> _stats = {};
  String? _lastPlayedTrackId;
  bool _isLoaded = false;

  Map<String, TrackStat> get stats => Map.unmodifiable(_stats);
  bool get isLoaded => _isLoaded;

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, val) {
            if (val is Map) {
              _stats[key.toString()] =
                  TrackStat.fromJson(Map<String, dynamic>.from(val));
            }
          });
        }
      }
    } catch (e) {
      print('Errore caricamento statistiche: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = {
        for (var entry in _stats.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_prefsKey, jsonEncode(mapToSave));
    } catch (e) {
      print('Errore salvataggio statistiche: $e');
    }
  }

  /// Registra l'avvio della riproduzione di una traccia
  void recordTrackStart(Track track) {
    final now = DateTime.now();
    final stat = _stats.putIfAbsent(
      track.id,
      () => TrackStat(
        trackId: track.id,
        title: track.displayTitle,
        artist: track.displayArtist,
        thumbnailUrl: track.thumbnailUrl,
        firstPlayedAt: now,
        lastPlayedAt: now,
      ),
    );

    stat.playCount += 1;
    stat.lastPlayedAt = now;

    // Se la stessa canzone è stata suonata subito prima (loop o ripetuta)
    if (_lastPlayedTrackId == track.id) {
      stat.repeatCount += 1;
    }
    _lastPlayedTrackId = track.id;

    notifyListeners();
    _saveStats();
  }

  /// Registra il completamento di una traccia
  void recordTrackCompleted(Track track) {
    final stat = _stats[track.id];
    if (stat != null) {
      stat.completionCount += 1;
      stat.totalDurationSeconds += track.duration.inSeconds;
      notifyListeners();
      _saveStats();
    }
  }

  TrackStat? getStat(String trackId) => _stats[trackId];

  int getPlayCount(String trackId) => _stats[trackId]?.playCount ?? 0;
  int getRepeatCount(String trackId) => _stats[trackId]?.repeatCount ?? 0;

  // --- QUERY & CLASSIFICHE ---

  /// Canzoni più ascoltate
  List<Track> getMostPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final countA = getPlayCount(a.id);
      final countB = getPlayCount(b.id);
      return countB.compareTo(countA);
    });
    return list.where((t) => getPlayCount(t.id) > 0).take(limit).toList();
  }

  /// Canzoni più ripetute (in loop)
  List<Track> getMostRepeatedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final countA = getRepeatCount(a.id);
      final countB = getRepeatCount(b.id);
      return countB.compareTo(countA);
    });
    return list.where((t) => getRepeatCount(t.id) > 0).take(limit).toList();
  }

  /// Canzoni meno ascoltate o mai ascoltate (per riscoprirle)
  List<Track> getLeastPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final countA = getPlayCount(a.id);
      final countB = getPlayCount(b.id);
      return countA.compareTo(countB);
    });
    return list.take(limit).toList();
  }

  /// Canzoni nella fascia media di ascolti (né hit stra-ascoltate né mai sentite)
  List<Track> getMediumPlayedTracks(List<Track> library, {int limit = 30}) {
    if (library.length < 5) return List.from(library);

    final sorted = List<Track>.from(library)
      ..sort((a, b) => getPlayCount(b.id).compareTo(getPlayCount(a.id)));

    // Escludi il top 25% e il bottom 25%
    final startIndex = (sorted.length * 0.20).floor();
    final endIndex = (sorted.length * 0.80).ceil();
    final slice = sorted.sublist(
      startIndex.clamp(0, sorted.length),
      endIndex.clamp(0, sorted.length),
    );

    slice.shuffle();
    return slice.take(limit).toList();
  }

  /// Canzoni ascoltate di recente
  List<Track> getRecentlyPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final timeA = _stats[a.id]?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = _stats[b.id]?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
    return list.where((t) => _stats.containsKey(t.id)).take(limit).toList();
  }

  /// Statistiche globali aggregate
  int get totalListeningSeconds {
    return _stats.values.fold(0, (sum, stat) => sum + stat.totalDurationSeconds);
  }

  int get totalPlaysCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.playCount);
  }

  int get totalRepeatsCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.repeatCount);
  }

  String get topArtist {
    if (_stats.isEmpty) return 'Nessuno';
    final artistCounts = <String, int>{};
    for (var stat in _stats.values) {
      if (stat.artist.isNotEmpty && stat.artist != 'Artista sconosciuto') {
        artistCounts[stat.artist] = (artistCounts[stat.artist] ?? 0) + stat.playCount;
      }
    }
    if (artistCounts.isEmpty) return 'Nessuno';
    final sorted = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String formatDurationSummary() {
    final totalSec = totalListeningSeconds;
    if (totalSec < 60) return '$totalSec sec';
    final minutes = totalSec ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return '${hours}h ${remMin}m';
  }
}
