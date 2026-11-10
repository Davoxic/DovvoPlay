import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'stats_service.dart';

class BackupResult {
  final bool success;
  final String message;
  final int restoredStats;
  final int restoredPlaylists;
  final int restoredTracks;

  const BackupResult({
    required this.success,
    required this.message,
    this.restoredStats = 0,
    this.restoredPlaylists = 0,
    this.restoredTracks = 0,
  });
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  static const String _autoBackupFileName = 'sborraplay_full_backup.json';

  Future<Directory> get _backupDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _autoBackupFile async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$_autoBackupFileName');
  }

  /// Esporta tutti i dati (statistiche d'ascolto, cronologia, playlist e tracce) in formato Map
  Map<String, dynamic> createBackupData() {
    final stats = StatsService.instance;
    final lib = LibraryService.instance;

    return {
      'app': 'SborraPlay',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'stats': {
        for (var entry in stats.stats.entries) entry.key: entry.value.toJson(),
      },
      'playlists': lib.playlists.map((p) => p.toJson()).toList(),
      'tracks': lib.tracks.map((t) => t.toJson()).toList(),
    };
  }

  /// Esporta come stringa JSON formattata
  String createBackupJsonString() {
    return const JsonEncoder.withIndent('  ').convert(createBackupData());
  }

  /// Salva il backup su file nel filesystem accessibile tramite l'app File di iOS
  Future<File> exportToFile() async {
    final dir = await _backupDirectory;
    final now = DateTime.now();
    final filename =
        'SborraPlay_Backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
    final target = File('${dir.path}/$filename');
    final jsonStr = createBackupJsonString();

    await target.writeAsString(jsonStr);

    // Salva anche una copia permanente automatica
    final autoFile = await _autoBackupFile;
    await autoFile.writeAsString(jsonStr);

    return target;
  }

  /// Importa e unisce tutti i dati da una stringa JSON
  Future<BackupResult> importFromJsonString(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return const BackupResult(
          success: false,
          message: 'Formato backup non valido (non è un oggetto JSON).',
        );
      }

      int restoredStats = 0;
      int restoredPlaylists = 0;
      int restoredTracks = 0;

      // 1. Ripristina Statistiche
      if (decoded['stats'] is Map) {
        final statsMap = decoded['stats'] as Map;
        final statsService = StatsService.instance;

        statsMap.forEach((key, val) {
          if (val is Map) {
            try {
              final importedStat = TrackStat.fromJson(Map<String, dynamic>.from(val));
              statsService.restoreOrMergeStat(importedStat);
              restoredStats++;
            } catch (e) {
              print('Errore restore singola statistica: $e');
            }
          }
        });

        // Forza notifica e salvataggio
        await statsService.saveAndNotify();
      }

      // 2. Ripristina Playlist
      if (decoded['playlists'] is List) {
        final plList = decoded['playlists'] as List;
        final lib = LibraryService.instance;
        for (final item in plList) {
          if (item is Map) {
            try {
              final pl = Playlist.fromJson(Map<String, dynamic>.from(item));
              final existingIdx = lib.playlists.indexWhere((p) => p.id == pl.id || p.name == pl.name);
              if (existingIdx != -1) {
                // Unisci i trackIds
                final existing = lib.playlists[existingIdx];
                final mergedTracks = {...existing.trackIds, ...pl.trackIds}.toList();
                lib.playlists[existingIdx] = existing.copyWith(trackIds: mergedTracks);
              } else {
                lib.playlists.add(pl);
              }
              restoredPlaylists++;
            } catch (e) {
              print('Errore restore singola playlist: $e');
            }
          }
        }
        await lib.savePlaylists();
      }

      // 3. Ripristina Tracce Online / Preferiti
      if (decoded['tracks'] is List) {
        final trList = decoded['tracks'] as List;
        final lib = LibraryService.instance;
        for (final item in trList) {
          if (item is Map) {
            try {
              final t = Track.fromJson(Map<String, dynamic>.from(item));
              if (t.isOnline && !lib.tracks.any((x) => x.id == t.id)) {
                lib.tracks.add(t);
                restoredTracks++;
              }
            } catch (_) {}
          }
        }
        await lib.saveLibrary();
      }

      // Salva copia aggiornata
      final autoFile = await _autoBackupFile;
      await autoFile.writeAsString(createBackupJsonString());

      return BackupResult(
        success: true,
        message: 'Ripristino completato con successo!',
        restoredStats: restoredStats,
        restoredPlaylists: restoredPlaylists,
        restoredTracks: restoredTracks,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Errore durante il ripristino: $e',
      );
    }
  }

  /// Importa da file
  Future<BackupResult> importFromFile(File file) async {
    if (!await file.exists()) {
      return const BackupResult(success: false, message: 'File non trovato.');
    }
    final content = await file.readAsString();
    return await importFromJsonString(content);
  }

  /// Auto-ripristino all'avvio dopo aggiornamento app:
  /// Se non ci sono statistiche ma esiste il file di backup automatico salvato in precedenza,
  /// ripristina automaticamente i dati!
  Future<void> autoRestoreIfEmpty() async {
    try {
      final autoFile = await _autoBackupFile;
      if (await autoFile.exists()) {
        final stats = StatsService.instance;
        if (stats.stats.isEmpty) {
          print('Rilevato auto-backup dopo aggiornamento. Ripristino in corso...');
          final content = await autoFile.readAsString();
          await importFromJsonString(content);
        }
      }
    } catch (e) {
      print('Avviso autoRestoreIfEmpty: $e');
    }
  }
}
