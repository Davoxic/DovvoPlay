import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? coverPath;
  final Duration? duration;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.coverPath,
    this.duration,
  });
}

class MetadataService {
  static final MetadataService instance = MetadataService._();
  MetadataService._();

  /// Estrae metadati e copertina incorporata da un file audio (MP3, M4A, FLAC, ecc.)
  Future<AudioMetadata> extractMetadata(File file, Directory coversDir) async {
    final path = file.path.toLowerCase();
    try {
      if (path.endsWith('.mp3')) {
        return await _parseMp3(file, coversDir);
      } else if (path.endsWith('.m4a') || path.endsWith('.mp4') || path.endsWith('.aac')) {
        return await _parseM4a(file, coversDir);
      } else if (path.endsWith('.flac')) {
        return await _parseFlac(file, coversDir);
      }
    } catch (e) {
      print('Errore lettura metadati per ${file.path}: $e');
    }

    return const AudioMetadata();
  }

  // --- PARSER MP3 ID3v2 ---

  Future<AudioMetadata> _parseMp3(File file, Directory coversDir) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(10);
      if (header.length < 10) return const AudioMetadata();

      // Controlla header "ID3"
      if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
        return const AudioMetadata();
      }

      final version = header[3]; // 2 per ID3v2.2, 3 per ID3v2.3, 4 per ID3v2.4
      final tagSize = ((header[6] & 0x7F) << 21) |
                      ((header[7] & 0x7F) << 14) |
                      ((header[8] & 0x7F) << 7) |
                      (header[9] & 0x7F);

      if (tagSize <= 0 || tagSize > 25 * 1024 * 1024) {
        return const AudioMetadata();
      }

      final tagBytes = await raf.read(tagSize);
      return _parseId3Frames(tagBytes, version, file, coversDir);
    } finally {
      await raf.close();
    }
  }

  AudioMetadata _parseId3Frames(
    Uint8List bytes,
    int version,
    File file,
    Directory coversDir,
  ) {
    String? title;
    String? artist;
    String? album;
    String? coverPath;

    int offset = 0;
    final idLen = version == 2 ? 3 : 4;

    while (offset + idLen + 6 <= bytes.length) {
      if (bytes[offset] == 0) break; // Padding

      final frameId = String.fromCharCodes(bytes.sublist(offset, offset + idLen));
      offset += idLen;

      int frameSize = 0;
      if (version == 2) {
        frameSize = (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
        offset += 3;
      } else if (version == 3) {
        frameSize = (bytes[offset] << 24) |
                    (bytes[offset + 1] << 16) |
                    (bytes[offset + 2] << 8) |
                    bytes[offset + 3];
        offset += 6; // 4 size + 2 flags
      } else {
        // v2.4 (synchsafe size)
        frameSize = ((bytes[offset] & 0x7F) << 21) |
                    ((bytes[offset + 1] & 0x7F) << 14) |
                    ((bytes[offset + 2] & 0x7F) << 7) |
                    (bytes[offset + 3] & 0x7F);
        offset += 6;
      }

      if (frameSize <= 0 || offset + frameSize > bytes.length) break;

      final frameData = bytes.sublist(offset, offset + frameSize);
      offset += frameSize;

      // Gestione tag testuali
      if (frameId == 'TIT2' || frameId == 'TT2') {
        title = _decodeId3Text(frameData);
      } else if (frameId == 'TPE1' || frameId == 'TP1') {
        artist = _decodeId3Text(frameData);
      } else if (frameId == 'TALB' || frameId == 'TAL') {
        album = _decodeId3Text(frameData);
      } else if (frameId == 'APIC' || frameId == 'PIC') {
        // Estrazione copertina
        if (coverPath == null) {
          coverPath = _extractAndSaveCover(frameData, file, coversDir);
        }
      }
    }

    return AudioMetadata(
      title: title,
      artist: artist,
      album: album,
      coverPath: coverPath,
    );
  }

  String _decodeId3Text(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final encoding = bytes[0];
    final data = bytes.sublist(1);
    if (data.isEmpty) return '';

    try {
      if (encoding == 0) {
        // ISO-8859-1 (Latin1)
        return latin1.decode(data).replaceAll('\x00', '').trim();
      } else if (encoding == 1) {
        // UTF-16 con BOM
        if (data.length >= 2) {
          if (data[0] == 0xFF && data[1] == 0xFE) {
            // Little Endian
            final chars = <int>[];
            for (int i = 2; i + 1 < data.length; i += 2) {
              final code = data[i] | (data[i + 1] << 8);
              if (code == 0) break;
              chars.add(code);
            }
            return String.fromCharCodes(chars).trim();
          } else if (data[0] == 0xFE && data[1] == 0xFF) {
            // Big Endian
            final chars = <int>[];
            for (int i = 2; i + 1 < data.length; i += 2) {
              final code = (data[i] << 8) | data[i + 1];
              if (code == 0) break;
              chars.add(code);
            }
            return String.fromCharCodes(chars).trim();
          }
        }
      } else if (encoding == 2) {
        // UTF-16BE senza BOM
        final chars = <int>[];
        for (int i = 0; i + 1 < data.length; i += 2) {
          final code = (data[i] << 8) | data[i + 1];
          if (code == 0) break;
          chars.add(code);
        }
        return String.fromCharCodes(chars).trim();
      } else if (encoding == 3) {
        // UTF-8
        return utf8.decode(data, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {}

    return utf8.decode(data, allowMalformed: true).replaceAll('\x00', '').trim();
  }

  String? _extractAndSaveCover(Uint8List frameData, File file, Directory coversDir) {
    try {
      // Cerca la firma JPEG (\xFF\xD8\xFF) o PNG (\x89PNG) all'interno del frame APIC
      int imgStart = -1;
      String ext = '.jpg';

      for (int i = 0; i < frameData.length - 4; i++) {
        if (frameData[i] == 0xFF && frameData[i + 1] == 0xD8 && frameData[i + 2] == 0xFF) {
          imgStart = i;
          ext = '.jpg';
          break;
        } else if (frameData[i] == 0x89 &&
                   frameData[i + 1] == 0x50 &&
                   frameData[i + 2] == 0x4E &&
                   frameData[i + 3] == 0x47) {
          imgStart = i;
          ext = '.png';
          break;
        }
      }

      if (imgStart != -1 && imgStart < frameData.length - 100) {
        final imgBytes = frameData.sublist(imgStart);
        final safeName = file.path.hashCode.abs().toString();
        final coverFile = File('${coversDir.path}/cover_$safeName$ext');
        coverFile.writeAsBytesSync(imgBytes);
        return coverFile.path;
      }
    } catch (e) {
      print('Errore salvataggio cover APIC: $e');
    }
    return null;
  }

  // --- PARSER M4A / MP4 / AAC ---

  Future<AudioMetadata> _parseM4a(File file, Directory coversDir) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final fileLength = await raf.length();
      // Leggi fino a 512KB per cercare atomi moov/udta/meta/ilst
      final readLen = fileLength < 600 * 1024 ? fileLength : 600 * 1024;
      final bytes = await raf.read(readLen);

      String? title;
      String? artist;
      String? album;
      String? coverPath;

      // Cerca 'covr' per l'immagine
      final covrIdx = _findPattern(bytes, [0x63, 0x6F, 0x76, 0x72]); // 'covr'
      if (covrIdx != -1 && covrIdx + 24 < bytes.length) {
        // Cerca signature 'data' dopo covr
        final dataIdx = _findPattern(bytes.sublist(covrIdx, (covrIdx + 64).clamp(0, bytes.length)), [0x64, 0x61, 0x74, 0x61]);
        if (dataIdx != -1) {
          final absDataIdx = covrIdx + dataIdx;
          if (absDataIdx + 16 < bytes.length) {
            final dataBoxSize = (bytes[absDataIdx - 4] << 24) |
                                (bytes[absDataIdx - 3] << 16) |
                                (bytes[absDataIdx - 2] << 8) |
                                bytes[absDataIdx - 1];
            final imgStart = absDataIdx + 12; // skip 'data' (4) + type flags (4) + reserved (4)
            final imgLen = dataBoxSize > 16 ? dataBoxSize - 16 : bytes.length - imgStart;
            if (imgStart + imgLen <= bytes.length && imgLen > 100) {
              final imgBytes = bytes.sublist(imgStart, imgStart + imgLen);
              final safeName = file.path.hashCode.abs().toString();
              final isPng = imgBytes.length > 4 && imgBytes[0] == 0x89 && imgBytes[1] == 0x50;
              final coverFile = File('${coversDir.path}/cover_$safeName${isPng ? ".png" : ".jpg"}');
              coverFile.writeAsBytesSync(imgBytes);
              coverPath = coverFile.path;
            }
          }
        }
      }

      // Cerca atomi testuali: \xa9nam (title), \xa9ART (artist), \xa9alb (album)
      title = _extractM4aText(bytes, [0xA9, 0x6E, 0x61, 0x6D]);
      artist = _extractM4aText(bytes, [0xA9, 0x41, 0x52, 0x54]);
      album = _extractM4aText(bytes, [0xA9, 0x61, 0x6C, 0x62]);

      return AudioMetadata(
        title: title,
        artist: artist,
        album: album,
        coverPath: coverPath,
      );
    } finally {
      await raf.close();
    }
  }

  String? _extractM4aText(Uint8List bytes, List<int> pattern) {
    final idx = _findPattern(bytes, pattern);
    if (idx != -1 && idx + 24 < bytes.length) {
      final dataIdx = _findPattern(bytes.sublist(idx, (idx + 32).clamp(0, bytes.length)), [0x64, 0x61, 0x74, 0x61]); // 'data'
      if (dataIdx != -1) {
        final absData = idx + dataIdx;
        final boxSize = (bytes[absData - 4] << 24) |
                        (bytes[absData - 3] << 16) |
                        (bytes[absData - 2] << 8) |
                        bytes[absData - 1];
        final textStart = absData + 12;
        final textLen = boxSize > 16 ? boxSize - 16 : 0;
        if (textStart + textLen <= bytes.length && textLen > 0) {
          final textBytes = bytes.sublist(textStart, textStart + textLen);
          return utf8.decode(textBytes, allowMalformed: true).replaceAll('\x00', '').trim();
        }
      }
    }
    return null;
  }

  // --- PARSER FLAC ---

  Future<AudioMetadata> _parseFlac(File file, Directory coversDir) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(4);
      if (header.length < 4 ||
          header[0] != 0x66 || header[1] != 0x4C || header[2] != 0x61 || header[3] != 0x43) {
        return const AudioMetadata();
      }

      String? title;
      String? artist;
      String? album;
      String? coverPath;

      bool isLast = false;
      while (!isLast) {
        final blockHdr = await raf.read(4);
        if (blockHdr.length < 4) break;

        isLast = (blockHdr[0] & 0x80) != 0;
        final blockType = blockHdr[0] & 0x7F;
        final blockSize = (blockHdr[1] << 16) | (blockHdr[2] << 8) | blockHdr[3];

        if (blockSize <= 0 || blockSize > 15 * 1024 * 1024) break;

        final blockData = await raf.read(blockSize);

        // VORBIS_COMMENT (Type 4)
        if (blockType == 4) {
          try {
            final str = utf8.decode(blockData, allowMalformed: true);
            for (final line in str.split('\n')) {
              final upper = line.toUpperCase();
              if (upper.startsWith('TITLE=')) {
                title = line.substring(6).trim();
              } else if (upper.startsWith('ARTIST=')) {
                artist = line.substring(7).trim();
              } else if (upper.startsWith('ALBUM=')) {
                album = line.substring(6).trim();
              }
            }
          } catch (_) {}
        }

        // PICTURE (Type 6)
        if (blockType == 6 && coverPath == null) {
          try {
            for (int i = 0; i < blockData.length - 4; i++) {
              if (blockData[i] == 0xFF && blockData[i + 1] == 0xD8 && blockData[i + 2] == 0xFF) {
                final safeName = file.path.hashCode.abs().toString();
                final coverFile = File('${coversDir.path}/cover_$safeName.jpg');
                coverFile.writeAsBytesSync(blockData.sublist(i));
                coverPath = coverFile.path;
                break;
              }
            }
          } catch (_) {}
        }
      }

      return AudioMetadata(
        title: title,
        artist: artist,
        album: album,
        coverPath: coverPath,
      );
    } finally {
      await raf.close();
    }
  }

  int _findPattern(Uint8List data, List<int> pattern) {
    if (data.length < pattern.length) return -1;
    for (int i = 0; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
}
