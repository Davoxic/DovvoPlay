import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

enum ListenTier {
  skipped,    // 0% - 15%
  brief,      // 15% - 35%
  half,       // 35% - 70%
  completed,  // 70% - 100%
}

class TrackStat {
  final String trackId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  int playCount;       // Brani ascoltati al 70-100%
  int completedCount;  // Brani ascoltati al 70-100%
  int halfCount;       // Brani ascoltati al 35-70%
  int briefCount;      // Brani ascoltati al 15-35%
  int skipCount;       // Brani skippati al 0-15%
  int repeatCount;     // Loop e ripetizioni complete
  int totalDurationSeconds; // Secondi effettivi d'ascolto registrati secondo per secondo
  DateTime lastPlayedAt;
  DateTime firstPlayedAt;

  TrackStat({
    required this.trackId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.playCount = 0,
    this.completedCount = 0,
    this.halfCount = 0,
    this.briefCount = 0,
    this.skipCount = 0,
    this.repeatCount = 0,
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
        'completedCount': completedCount,
        'halfCount': halfCount,
        'briefCount': briefCount,
        'skipCount': skipCount,
        'repeatCount': repeatCount,
        'totalDurationSeconds': totalDurationSeconds,
        'lastPlayedAt': lastPlayedAt.toIso8601String(),
        'firstPlayedAt': firstPlayedAt.toIso8601String(),
      };

  factory TrackStat.fromJson(Map<String, dynamic> json) {
    final cCount = json['completedCount'] ?? json['playCount'] ?? 0;
    return TrackStat(
      trackId: json['trackId'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      playCount: cCount,
      completedCount: cCount,
      halfCount: json['halfCount'] ?? 0,
      briefCount: json['briefCount'] ?? 0,
      skipCount: json['skipCount'] ?? 0,
      repeatCount: json['repeatCount'] ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] ?? 0,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.tryParse(json['lastPlayedAt']) ?? DateTime.now()
          : DateTime.now(),
      firstPlayedAt: json['firstPlayedAt'] != null
          ? DateTime.tryParse(json['firstPlayedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DayStat {
  final String dateKey; // YYYY-MM-DD
  int listeningSeconds;
  int skipsCount;
  int briefCount;
  int halfCount;
  int completedCount;
  final Map<String, int> trackPlays; // trackId -> plays
  final Map<String, int> trackSkips; // trackId -> skips

  DayStat({
    required this.dateKey,
    this.listeningSeconds = 0,
    this.skipsCount = 0,
    this.briefCount = 0,
    this.halfCount = 0,
    this.completedCount = 0,
    Map<String, int>? trackPlays,
    Map<String, int>? trackSkips,
  })  : trackPlays = trackPlays ?? {},
        trackSkips = trackSkips ?? {};

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'listeningSeconds': listeningSeconds,
        'skipsCount': skipsCount,
        'briefCount': briefCount,
        'halfCount': halfCount,
        'completedCount': completedCount,
        'trackPlays': trackPlays,
        'trackSkips': trackSkips,
      };

  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
        dateKey: json['dateKey'] ?? '',
        listeningSeconds: json['listeningSeconds'] ?? 0,
        skipsCount: json['skipsCount'] ?? 0,
        briefCount: json['briefCount'] ?? 0,
        halfCount: json['halfCount'] ?? 0,
        completedCount: json['completedCount'] ?? 0,
        trackPlays: Map<String, int>.from(json['trackPlays'] ?? {}),
        trackSkips: Map<String, int>.from(json['trackSkips'] ?? {}),
      );
}

class DailyMoodOutcome {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final bool isPositive;

  const DailyMoodOutcome({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.isPositive,
  });
}

class StatsService extends ChangeNotifier {
  static final StatsService instance = StatsService._();
  StatsService._() {
    _loadStats();
  }

  static const String _prefsKey = 'sborraplay_track_stats_v3';
  static const String _daysKey = 'sborraplay_daily_stats_v3';

  final Map<String, TrackStat> _stats = {};
  final Map<String, DayStat> _days = {};
  String? _lastPlayedTrackId;
  bool _isLoaded = false;
  int _secondsSinceLastSave = 0;

  Map<String, TrackStat> get stats => Map.unmodifiable(_stats);
  Map<String, DayStat> get days => Map.unmodifiable(_days);
  bool get isLoaded => _isLoaded;

  String _getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  DayStat _getOrCreateTodayStat() {
    final key = _getTodayKey();
    return _days.putIfAbsent(key, () => DayStat(dateKey: key));
  }

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

      final rawDays = prefs.getString(_daysKey);
      if (rawDays != null && rawDays.isNotEmpty) {
        final decodedDays = jsonDecode(rawDays);
        if (decodedDays is Map) {
          decodedDays.forEach((key, val) {
            if (val is Map) {
              _days[key.toString()] =
                  DayStat.fromJson(Map<String, dynamic>.from(val));
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

      final daysToSave = {
        for (var entry in _days.entries) entry.key: entry.value.toJson(),
      };
      await prefs.setString(_daysKey, jsonEncode(daysToSave));
    } catch (e) {
      print('Errore salvataggio statistiche: $e');
    }
  }

  /// Salva e notifica per aggiornamenti esterni (es. ripristino backup)
  Future<void> saveAndNotify() async {
    await _saveStats();
    notifyListeners();
  }

  /// Unisce o ripristina una statistica da un backup
  void restoreOrMergeStat(TrackStat importedStat) {
    final existing = _stats[importedStat.trackId];
    if (existing != null) {
      existing.completedCount = existing.completedCount > importedStat.completedCount
          ? existing.completedCount
          : importedStat.completedCount;
      existing.playCount = existing.completedCount;
      existing.halfCount = existing.halfCount > importedStat.halfCount
          ? existing.halfCount
          : importedStat.halfCount;
      existing.briefCount = existing.briefCount > importedStat.briefCount
          ? existing.briefCount
          : importedStat.briefCount;
      existing.skipCount = existing.skipCount > importedStat.skipCount
          ? existing.skipCount
          : importedStat.skipCount;
      existing.repeatCount = existing.repeatCount > importedStat.repeatCount
          ? existing.repeatCount
          : importedStat.repeatCount;
      existing.totalDurationSeconds = existing.totalDurationSeconds > importedStat.totalDurationSeconds
          ? existing.totalDurationSeconds
          : importedStat.totalDurationSeconds;
      if (importedStat.lastPlayedAt.isAfter(existing.lastPlayedAt)) {
        existing.lastPlayedAt = importedStat.lastPlayedAt;
      }
    } else {
      _stats[importedStat.trackId] = importedStat;
    }
  }

  // --- REGISTRAZIONE SECONDO PER SECONDO ---

  /// Aggiunge secondi d'ascolto effettivi in tempo reale per la traccia corrente
  void addListeningSeconds(Track track, {int seconds = 1}) {
    if (seconds <= 0) return;

    final stat = _stats.putIfAbsent(
      track.id,
      () => TrackStat(
        trackId: track.id,
        title: track.displayTitle,
        artist: track.displayArtist,
        thumbnailUrl: track.thumbnailUrl,
      ),
    );

    stat.totalDurationSeconds += seconds;
    stat.lastPlayedAt = DateTime.now();

    final today = _getOrCreateTodayStat();
    today.listeningSeconds += seconds;

    _secondsSinceLastSave += seconds;
    if (_secondsSinceLastSave >= 6) {
      _secondsSinceLastSave = 0;
      _saveStats();
      notifyListeners();
    }
  }

  // --- REGISTRAZIONE GRANULARE PERCENTUALE (0-15%, 15-35%, 35-70%, 70-100%) ---

  /// Valuta la percentuale massima di ascolto raggiunta da una canzone
  void recordTrackByPercentage(Track track, double percentage) {
    final now = DateTime.now();
    final today = _getOrCreateTodayStat();
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

    stat.lastPlayedAt = now;

    if (percentage < 15.0) {
      // 0% - 15%: SKIPPATA
      stat.skipCount += 1;
      today.skipsCount += 1;
      today.trackSkips[track.id] = (today.trackSkips[track.id] ?? 0) + 1;
    } else if (percentage < 35.0) {
      // 15% - 35%: ASCOLTATA POCO
      stat.briefCount += 1;
      today.briefCount += 1;
    } else if (percentage < 70.0) {
      // 35% - 70%: ASCOLTATA A METÀ
      stat.halfCount += 1;
      today.halfCount += 1;
    } else {
      // 70% - 100%: ASCOLTATA COMPLETA
      stat.completedCount += 1;
      stat.playCount += 1;
      today.completedCount += 1;
      today.trackPlays[track.id] = (today.trackPlays[track.id] ?? 0) + 1;

      // Ripetizione consecutiva
      if (_lastPlayedTrackId == track.id) {
        stat.repeatCount += 1;
      }
      _lastPlayedTrackId = track.id;
    }

    _saveStats();
    notifyListeners();
  }

  // Alias retrocompatibili
  void recordTrackStart(Track track) {
    _stats.putIfAbsent(
      track.id,
      () => TrackStat(
        trackId: track.id,
        title: track.displayTitle,
        artist: track.displayArtist,
        thumbnailUrl: track.thumbnailUrl,
      ),
    );
  }

  void recordTrackPlayed(Track track) => recordTrackByPercentage(track, 100.0);
  void recordTrackSkipped(Track track) => recordTrackByPercentage(track, 5.0);
  void recordTrackCompleted(Track track) => recordTrackByPercentage(track, 100.0);

  // --- STATISTICHE OGGI & ESITO DEL GIORNO ---

  DayStat get todayStat => _getOrCreateTodayStat();

  DailyMoodOutcome getDailyMood() {
    final today = todayStat;
    final totalInteractions = today.skipsCount + today.briefCount + today.halfCount + today.completedCount;

    if (totalInteractions == 0) {
      return const DailyMoodOutcome(
        title: 'Inizia ad ascoltare!',
        message: 'Non hai ancora ascoltato canzoni oggi. Fai partire la tua musica preferita!',
        icon: Icons.headphones_rounded,
        color: Color(0xFF64B5F6),
        isPositive: true,
      );
    }

    final realListening = today.halfCount + today.completedCount;
    if (today.skipsCount > realListening) {
      return const DailyMoodOutcome(
        title: 'Oggi non te ne va bene una! 🙃',
        message: 'La percentuale di skip è più alta di quella delle canzoni ascoltate. Prova lo Shuffle Magico o una nuova playlist!',
        icon: Icons.sentiment_dissatisfied_rounded,
        color: Color(0xFFFF5252),
        isPositive: false,
      );
    } else {
      return const DailyMoodOutcome(
        title: 'Oggi ti va tutto a gonfie vele, grande! 🔥',
        message: 'Stai ascoltando i tuoi brani con entusiasmo e pochissimi skip. Ottima sessione musicale!',
        icon: Icons.local_fire_department_rounded,
        color: Color(0xFFFFD700),
        isPositive: true,
      );
    }
  }

  // --- STATISTICHE SETTIMANALI ---

  int getWeeklyMinutes() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);

    int totalSec = 0;
    for (var day in _days.values) {
      final date = DateTime.tryParse(day.dateKey);
      if (date != null && !date.isBefore(startOfWeek)) {
        totalSec += day.listeningSeconds;
      }
    }
    return totalSec ~/ 60;
  }

  Map<int, int> getWeeklyDayMinutes() {
    // 1 (Lun) .. 7 (Dom) -> minuti
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);

    for (var day in _days.values) {
      final date = DateTime.tryParse(day.dateKey);
      if (date != null && !date.isBefore(startOfWeek)) {
        final weekday = date.weekday;
        map[weekday] = (map[weekday] ?? 0) + (day.listeningSeconds ~/ 60);
      }
    }
    return map;
  }

  // --- STATISTICHE MENSILI & GLOBALI ---

  int get monthlyListeningMinutes {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    int totalSec = 0;
    for (var day in _days.values) {
      final date = DateTime.tryParse(day.dateKey);
      if (date != null && !date.isBefore(startOfMonth)) {
        totalSec += day.listeningSeconds;
      }
    }
    return totalSec ~/ 60;
  }

  int get totalListeningSeconds {
    return _stats.values.fold(0, (sum, stat) => sum + stat.totalDurationSeconds);
  }

  int get totalPlaysCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.completedCount);
  }

  int get totalHalfCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.halfCount);
  }

  int get totalBriefCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.briefCount);
  }

  int get totalSkipsCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.skipCount);
  }

  int get totalRepeatsCount {
    return _stats.values.fold(0, (sum, stat) => sum + stat.repeatCount);
  }

  TrackStat? getStat(String trackId) => _stats[trackId];
  int getPlayCount(String trackId) => _stats[trackId]?.completedCount ?? 0;
  int getRepeatCount(String trackId) => _stats[trackId]?.repeatCount ?? 0;
  int getSkipCount(String trackId) => _stats[trackId]?.skipCount ?? 0;

  // --- CLASSIFICHE TRACCE ---

  /// Top brani più ascoltati (70% - 100%)
  List<Track> getMostPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final countA = getPlayCount(a.id);
      final countB = getPlayCount(b.id);
      return countB.compareTo(countA);
    });
    return list.where((t) => getPlayCount(t.id) > 0).take(limit).toList();
  }

  /// Top 5 brani più ascoltati (70% - 100%)
  List<Track> getTop5PlayedTracks(List<Track> library) =>
      getMostPlayedTracks(library, limit: 5);

  /// Top brani più skippati (0% - 15%)
  List<Track> getMostSkippedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final countA = getSkipCount(a.id);
      final countB = getSkipCount(b.id);
      return countB.compareTo(countA);
    });
    return list.where((t) => getSkipCount(t.id) > 0).take(limit).toList();
  }

  /// Brani più ripetuti (in loop)
  List<Track> getMostRepeatedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) => getRepeatCount(b.id).compareTo(getRepeatCount(a.id)));
    return list.where((t) => getRepeatCount(t.id) > 0).take(limit).toList();
  }

  /// Brani meno ascoltati o mai ascoltati
  List<Track> getLeastPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) => getPlayCount(a.id).compareTo(getPlayCount(b.id)));
    return list.take(limit).toList();
  }

  /// Brani nella fascia media di ascolto
  List<Track> getMediumPlayedTracks(List<Track> library, {int limit = 30}) {
    if (library.length < 5) return List.from(library);
    final sorted = List<Track>.from(library)
      ..sort((a, b) => getPlayCount(b.id).compareTo(getPlayCount(a.id)));
    final startIndex = (sorted.length * 0.20).floor();
    final endIndex = (sorted.length * 0.80).ceil();
    final slice = sorted.sublist(
      startIndex.clamp(0, sorted.length),
      endIndex.clamp(0, sorted.length),
    );
    slice.shuffle();
    return slice.take(limit).toList();
  }

  /// Brani ascoltati di recente
  List<Track> getRecentlyPlayedTracks(List<Track> library, {int limit = 30}) {
    final list = List<Track>.from(library);
    list.sort((a, b) {
      final timeA = _stats[a.id]?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = _stats[b.id]?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
    return list.where((t) => _stats.containsKey(t.id)).take(limit).toList();
  }

  /// Top Artista generale e mensile
  String get topArtist {
    if (_stats.isEmpty) return 'Nessun dato';
    final artistCounts = <String, int>{};
    for (var stat in _stats.values) {
      if (stat.artist.isNotEmpty && stat.artist != 'Artista sconosciuto') {
        artistCounts[stat.artist] = (artistCounts[stat.artist] ?? 0) + stat.completedCount;
      }
    }
    if (artistCounts.isEmpty) return 'Nessun dato';
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

  // --- AZZERAMENTO COMPLETO STATISTICHE ---

  Future<void> resetAllStats() async {
    _stats.clear();
    _days.clear();
    _lastPlayedTrackId = null;
    _secondsSinceLastSave = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_daysKey);

    notifyListeners();
  }
}
