import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'youtube_service.dart';

/// Flusso audio risolto con metadati e intestazioni HTTP dedicate
class ResolvedStream {
  final String url;
  final Map<String, String> headers;
  final int bitrate;
  final String format;
  final String source;

  const ResolvedStream({
    required this.url,
    required this.headers,
    required this.bitrate,
    required this.format,
    required this.source,
  });
}

// ---------------------------------------------------------------------------
// Algoritmo DES ECB puro per la decodifica istantanea degli stream JioSaavn (BitChord)
// ---------------------------------------------------------------------------
const List<int> _ip = [
  58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
  62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
  57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
  61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7
];

const List<int> _fp = [
  40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
  38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
  36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
  34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25
];

const List<int> _e = [
  32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11,
  12, 13, 12, 13, 14, 15, 16, 17, 16, 17, 18, 19, 20, 21, 20, 21,
  22, 23, 24, 25, 24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1
];

const List<int> _p = [
  16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
  2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25
];

const List<int> _sBoxes = [
  14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7, 0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8, 4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0, 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13,
  15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10, 3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5, 0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15, 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9,
  10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8, 13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1, 13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7, 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12,
  7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15, 13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9, 10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4, 3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14,
  2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9, 14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6, 4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14, 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3,
  12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11, 10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8, 9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6, 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13,
  4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1, 13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6, 1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2, 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12,
  13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7, 1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2, 7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8, 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11
];

const List<int> _pc1 = [
  57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, 10, 2,
  59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36, 63, 55, 47, 39,
  31, 23, 15, 7, 62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37,
  29, 21, 13, 5, 28, 20, 12, 4
];

const List<int> _pc2 = [
  14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4,
  26, 8, 16, 7, 27, 20, 13, 2, 41, 52, 31, 37, 47, 55, 30, 40,
  51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32
];

const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

class DesEcb {
  static const List<int> _defaultKey = [51, 56, 51, 52, 54, 53, 57, 49]; // '38346591'

  static List<int> _permute(List<int> block, List<int> table) {
    final out = List<int>.filled(table.length, 0);
    for (int i = 0; i < table.length; i++) {
      out[i] = block[table[i] - 1];
    }
    return out;
  }

  static List<int> _bytesToBits(List<int> bytes) {
    final bits = List<int>.filled(bytes.length * 8, 0);
    int idx = 0;
    for (final b in bytes) {
      for (int i = 7; i >= 0; i--) {
        bits[idx++] = (b >> i) & 1;
      }
    }
    return bits;
  }

  static Uint8List _bitsToBytes(List<int> bits) {
    final bytes = Uint8List(bits.length ~/ 8);
    for (int i = 0; i < bytes.length; i++) {
      int byte = 0;
      final start = i * 8;
      for (int j = 0; j < 8; j++) {
        byte = (byte << 1) | bits[start + j];
      }
      bytes[i] = byte;
    }
    return bytes;
  }

  static List<List<int>> _generateSubkeys(List<int> keyBytes) {
    final bits = _bytesToBits(keyBytes);
    final perm = _permute(bits, _pc1);
    var c = perm.sublist(0, 28);
    var d = perm.sublist(28, 56);
    final subkeys = <List<int>>[];
    for (final s in _shifts) {
      c = [...c.sublist(s), ...c.sublist(0, s)];
      d = [...d.sublist(s), ...d.sublist(0, s)];
      subkeys.add(_permute([...c, ...d], _pc2));
    }
    return subkeys;
  }

  static List<int> _feistel(List<int> r, List<int> subkey) {
    final er = _permute(r, _e);
    final x = List<int>.generate(48, (i) => er[i] ^ subkey[i]);
    final res = List<int>.filled(32, 0);
    int resIdx = 0;
    for (int i = 0; i < 8; i++) {
      final chunkStart = i * 6;
      final row = (x[chunkStart] << 1) | x[chunkStart + 5];
      final col = (x[chunkStart + 1] << 3) |
          (x[chunkStart + 2] << 2) |
          (x[chunkStart + 3] << 1) |
          x[chunkStart + 4];
      final val = _sBoxes[i * 64 + row * 16 + col];
      for (int j = 3; j >= 0; j--) {
        res[resIdx++] = (val >> j) & 1;
      }
    }
    return _permute(res, _p);
  }

  static List<int> _decryptBlock(List<int> blockBytes, List<List<int>> subkeys) {
    final bits = _bytesToBits(blockBytes);
    final perm = _permute(bits, _ip);
    var l = perm.sublist(0, 32);
    var r = perm.sublist(32, 64);

    for (int round = 15; round >= 0; round--) {
      final f = _feistel(r, subkeys[round]);
      final nextR = List<int>.generate(32, (i) => l[i] ^ f[i]);
      l = r;
      r = nextR;
    }

    final preOutput = [...r, ...l];
    final outBits = _permute(preOutput, _fp);
    return _bitsToBytes(outBits);
  }

  /// Decodifica il link Saavn crittografato in DES-ECB
  static String decrypt(String base64Enc, {List<int> keyBytes = _defaultKey}) {
    try {
      final ciphertext = base64.decode(base64Enc);
      final subkeys = _generateSubkeys(keyBytes);
      final decrypted = <int>[];

      for (int i = 0; i < ciphertext.length; i += 8) {
        if (i + 8 > ciphertext.length) break;
        final block = ciphertext.sublist(i, i + 8);
        decrypted.addAll(_decryptBlock(block, subkeys));
      }

      if (decrypted.isEmpty) return '';

      // Rimozione padding PKCS7
      final padLen = decrypted.last;
      if (padLen > 0 && padLen <= 8 && padLen <= decrypted.length) {
        bool valid = true;
        for (int i = decrypted.length - padLen; i < decrypted.length; i++) {
          if (decrypted[i] != padLen) {
            valid = false;
            break;
          }
        }
        if (valid) {
          decrypted.removeRange(decrypted.length - padLen, decrypted.length);
        }
      }

      return utf8.decode(decrypted, allowMalformed: true);
    } catch (e) {
      debugPrint('DesEcb decrypt error: $e');
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// JioSaavn Service: Riproduzione ad altissima fedeltà (BitChord)
// ---------------------------------------------------------------------------
class JioSaavnService {
  static final JioSaavnService instance = JioSaavnService._();
  JioSaavnService._();

  static const _apiBase = 'https://www.jiosaavn.com/api.php';
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
    'Cookie': 'explicit_content=1',
  };

  Future<ResolvedStream?> resolve(String title, {String? artist, bool highQuality = true}) async {
    try {
      final cleanTitle = StreamResolver._cleanTitle(title);
      final cleanArtist = artist != null ? StreamResolver._cleanArtist(artist) : null;

      final query = (cleanArtist != null &&
              cleanArtist.isNotEmpty &&
              !cleanArtist.toLowerCase().contains('unknown') &&
              !cleanArtist.toLowerCase().contains('youtube'))
          ? '$cleanArtist $cleanTitle'
          : cleanTitle;

      final uri = Uri.parse(_apiBase).replace(queryParameters: {
        '__call': 'search.getResults',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
        'n': '4',
        'p': '1',
        'q': query,
      });

      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      for (final item in results) {
        final moreInfo = item['more_info'] as Map<String, dynamic>?;
        final encrypted = moreInfo?['encrypted_media_url'] as String?;
        if (encrypted == null || encrypted.isEmpty) continue;

        final rawUrl = DesEcb.decrypt(encrypted);
        if (rawUrl.isEmpty || !rawUrl.startsWith('http')) continue;

        String streamUrl = rawUrl;
        if (highQuality) {
          streamUrl = streamUrl.replaceAll(RegExp(r'_(?:48|96|160)\.mp4'), '_320.mp4');
        } else {
          streamUrl = streamUrl.replaceAll(RegExp(r'_(?:48|96|320)\.mp4'), '_160.mp4');
        }

        return ResolvedStream(
          url: streamUrl,
          headers: {'User-Agent': _headers['User-Agent']!},
          bitrate: highQuality ? 320000 : 160000,
          format: 'm4a',
          source: 'jiosaavn',
        );
      }
    } catch (e) {
      debugPrint('JioSaavnService resolve error: $e');
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// InnerTube Service: Profili nativi ANDROID_VR e VISIONOS (Fonte BitChord)
// ---------------------------------------------------------------------------
class InnerTubeService {
  static final InnerTubeService instance = InnerTubeService._();
  InnerTubeService._();

  static const _endpoint = 'https://youtubei.googleapis.com/youtubei/v1/player';

  static const _clients = [
    {
      'name': 'ANDROID_VR',
      'version': '1.65.10',
      'ua': 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    },
    {
      'name': 'VISIONOS',
      'version': '1.02',
      'ua': 'com.google.visionos.youtube/1.02(RealityDevice14,1; U; CPU visionOS 25_6_0 like Mac OS X; US)',
    },
    {
      'name': 'ANDROID_VR',
      'version': '1.43.32',
      'ua': 'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    },
  ];

  Future<ResolvedStream?> resolve(String videoId) async {
    for (final c in _clients) {
      try {
        final clientName = c['name']!;
        final clientVersion = c['version']!;
        final ua = c['ua']!;

        final headers = {
          'User-Agent': ua,
          'Content-Type': 'application/json',
          'X-Goog-Api-Format-Version': '2',
        };

        final body = json.encode({
          'context': {
            'client': {
              'clientName': clientName,
              'clientVersion': clientVersion,
              'hl': 'en',
              'gl': 'US',
            }
          },
          'videoId': videoId,
          'playbackContext': {
            'contentPlaybackContext': {
              'html5Preference': 'HTML5_PREF_WANTS',
            }
          }
        });

        final res = await http.post(
          Uri.parse(_endpoint),
          headers: headers,
          body: body,
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode != 200) continue;

        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final playability = data['playabilityStatus'] as Map<String, dynamic>?;
        final status = playability?['status'] as String?;
        if (status != 'OK') continue;

        final streamingData = data['streamingData'] as Map<String, dynamic>?;
        if (streamingData == null) continue;

        final formats = <Map<String, dynamic>>[];
        if (streamingData['adaptiveFormats'] is List) {
          formats.addAll((streamingData['adaptiveFormats'] as List).cast<Map<String, dynamic>>());
        }
        if (streamingData['formats'] is List) {
          formats.addAll((streamingData['formats'] as List).cast<Map<String, dynamic>>());
        }

        // Cerca formati AAC in MP4/M4A (itag 140 m4a 128kbps o 139) con URL diretto
        final audioOnly = formats.where((f) {
          final mime = (f['mimeType'] as String? ?? '').toLowerCase();
          final hasUrl = f.containsKey('url') && (f['url'] as String).isNotEmpty;
          return mime.contains('audio') && mime.contains('mp4') && hasUrl;
        }).toList();

        if (audioOnly.isNotEmpty) {
          audioOnly.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
          final chosen = audioOnly.first;
          final streamUrl = chosen['url'] as String;
          final bitrate = (chosen['bitrate'] as num?)?.toInt() ?? 128000;

          return ResolvedStream(
            url: streamUrl,
            headers: {'User-Agent': ua},
            bitrate: bitrate,
            format: 'm4a',
            source: 'youtube_innertube',
          );
        }
      } catch (e) {
        debugPrint('InnerTube profile ${c['name']} error: $e');
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// StreamResolver Principale: Orchestrazione e Download
// ---------------------------------------------------------------------------
class StreamResolver {
  static final StreamResolver instance = StreamResolver._();
  StreamResolver._();

  Future<ResolvedStream?> resolve({
    required String videoId,
    String? title,
    String? artist,
    bool highQuality = true,
  }) async {
    // 1. Priorità BitChord: JioSaavn 320kbps AAC (flusso diretto senza token o blocchi bot)
    if (title != null && title.isNotEmpty) {
      final s = await JioSaavnService.instance.resolve(
        title,
        artist: artist,
        highQuality: highQuality,
      );
      if (s != null) return s;
    }

    // 2. Priorità BitChord: YouTube Innertube client profili nativi (ANDROID_VR / VISIONOS)
    final cleanId = videoId.replaceFirst('yt_', '');
    if (cleanId.isNotEmpty) {
      final ytStream = await InnerTubeService.instance.resolve(cleanId);
      if (ytStream != null) return ytStream;
    }

    // 3. Fallback: youtube_explode_dart se disponibile
    try {
      final yt = YouTubeService.instance.yt;
      final manifest = await yt.videos.streamsClient.getManifest(cleanId).timeout(const Duration(seconds: 5));
      final mp4Audio = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase().contains('mp4') || s.audioCodec.toLowerCase().contains('mp4a'))
          .toList();
      if (mp4Audio.isNotEmpty) {
        mp4Audio.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        return ResolvedStream(
          url: mp4Audio.first.url.toString(),
          headers: {},
          bitrate: mp4Audio.first.bitrate.bitsPerSecond,
          format: 'm4a',
          source: 'youtube_explode',
        );
      }
    } catch (_) {}

    return null;
  }

  /// Scarica un ResolvedStream direttamente su file con monitoraggio del progresso
  Future<File?> downloadToFile({
    required ResolvedStream stream,
    required File targetFile,
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(stream.url));
      req.headers.addAll(stream.headers);

      final tempFile = File('${targetFile.path}.tmp');
      if (await tempFile.exists()) await tempFile.delete();

      final res = await client.send(req);
      if (res.statusCode != 200 && res.statusCode != 206) return null;

      final total = res.contentLength ?? 0;
      int received = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.length() > 30000) {
        if (await targetFile.exists()) await targetFile.delete();
        await tempFile.rename(targetFile.path);
        return targetFile;
      } else {
        if (await tempFile.exists()) await tempFile.delete();
        return null;
      }
    } catch (e) {
      debugPrint('StreamResolver download error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static String _cleanArtist(String raw) {
    return raw
        .replaceAll(RegExp(r'\b(?:vevo|- topic|topic|official)\b', caseSensitive: false), '')
        .trim();
  }

  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\((?:official|lyric|lyrics|audio|video|visualizer|full song|hd|4k)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:official (?:video|audio|music video)|lyrical video|full video)\b', caseSensitive: false), '')
        .trim();
  }
}
