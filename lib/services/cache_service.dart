import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'playback_settings.dart';

/// Spazio occupato dalle cache e pulizia.
///
/// Lo streaming scarica ogni brano in una cartella temporanea prima di
/// suonarlo: e' comodo, perche' riascoltarlo e' immediato, ma senza un limite
/// la cartella cresce all'infinito.
class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  Future<Directory> get _cartellaBrani async {
    final temp = await getTemporaryDirectory();
    return Directory('${temp.path}/yt_cache');
  }

  /// Byte occupati dall'audio in cache.
  Future<int> songCacheBytes() async {
    try {
      final dir = await _cartellaBrani;
      if (!await dir.exists()) return 0;
      var totale = 0;
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) {
          try {
            totale += await e.length();
          } catch (_) {}
        }
      }
      return totale;
    } catch (_) {
      return 0;
    }
  }

  /// Cancella l'audio in cache. [tieni] e' un pezzo di nome da non toccare:
  /// serve a non togliere il file del brano in riproduzione.
  Future<void> clearSongCache({String? tieni}) async {
    try {
      final dir = await _cartellaBrani;
      if (!await dir.exists()) return;
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        if (tieni != null && tieni.isNotEmpty && e.path.contains(tieni)) continue;
        try {
          await e.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Avviso pulizia cache brani: $e');
    }
  }

  /// Riporta la cache sotto il limite scelto, togliendo i file piu' vecchi.
  Future<void> enforceLimit({String? tieni}) async {
    try {
      final limite = PlaybackSettings.instance.cacheLimitMb * 1024 * 1024;
      final dir = await _cartellaBrani;
      if (!await dir.exists()) return;

      final file = <File>[];
      final pesi = <String, int>{};
      final date = <String, DateTime>{};
      var totale = 0;
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        try {
          final st = await e.stat();
          file.add(e);
          pesi[e.path] = st.size;
          date[e.path] = st.modified;
          totale += st.size;
        } catch (_) {}
      }
      if (totale <= limite) return;

      file.sort((a, b) => date[a.path]!.compareTo(date[b.path]!));
      for (final f in file) {
        if (totale <= limite) break;
        if (tieni != null && tieni.isNotEmpty && f.path.contains(tieni)) continue;
        try {
          await f.delete();
          totale -= pesi[f.path] ?? 0;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Avviso limite cache: $e');
    }
  }

  /// Svuota le copertine scaricate dalla rete.
  Future<void> clearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      debugPrint('Avviso pulizia cache immagini: $e');
    }
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
}
