import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import 'metadata_service.dart';

class LibraryService extends ChangeNotifier {
  static final LibraryService instance = LibraryService._();
  LibraryService._();

  List<Track> _tracks = [];
  List<Playlist> _playlists = [];
  bool _isLoading = false;

  /// Brani in streaming a cui punta una playlist.
  ///
  /// Stanno a parte, fuori da [_tracks]: cosi' una playlist puo' contenere
  /// brani online senza che questi compaiano nell'elenco dei file della
  /// libreria e senza falsarne i conteggi.
  final Map<String, Track> _onlineTracks = {};

  List<Track> get tracks => _tracks;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  Future<Directory> get musicDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Music');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _libraryFile async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/library.json');
  }

  Future<File> get _playlistsFile async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/playlists.json');
  }

  Future<File> get _onlineFile async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/online_tracks.json');
  }

  List<Track> get onlineTracks => _onlineTracks.values.toList();

  /// Ricorda un brano in streaming, cosi' le playlist che lo contengono
  /// sanno come mostrarlo e riprodurlo.
  Future<void> rememberOnlineTrack(Track track) async {
    if (!track.isOnline || track.id.isEmpty) return;
    if (_onlineTracks.containsKey(track.id)) return;
    _onlineTracks[track.id] = track;
    await _saveOnlineTracks();
  }

  /// Aggiunge in blocco, per il ripristino di un backup.
  Future<int> importOnlineTracks(List lista) async {
    var aggiunti = 0;
    for (final e in lista) {
      if (e is! Map) continue;
      try {
        final t = Track.fromJson(Map<String, dynamic>.from(e));
        if (t.isOnline && t.id.isNotEmpty && !_onlineTracks.containsKey(t.id)) {
          _onlineTracks[t.id] = t;
          aggiunti++;
        }
      } catch (_) {}
    }
    if (aggiunti > 0) await _saveOnlineTracks();
    return aggiunti;
  }

  Future<void> _saveOnlineTracks() async {
    try {
      final file = await _onlineFile;
      await file.writeAsString(
        jsonEncode(_onlineTracks.values.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      print('Errore salvataggio online_tracks.json: $e');
    }
  }

  /// Inserisce subito in libreria un brano appena scaricato, con titolo,
  /// artista e copertina gia' noti.
  ///
  /// I file .m4a di YouTube non hanno tag: lasciati alla sola scansione
  /// comparirebbero col nome del file come titolo e senza artista.
  Future<void> registerDownloadedTrack(Track track) async {
    if (track.filePath == null) return;
    _tracks.removeWhere((t) => t.filePath == track.filePath || t.id == track.id);
    _tracks.add(track);
    await saveLibrary();
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadSavedData();
      await scanLibrary();
    } catch (e) {
      print('Errore caricamento libreria: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final libFile = await _libraryFile;
      if (await libFile.exists()) {
        final content = await libFile.readAsString();
        final data = jsonDecode(content);
        if (data is Map && data['tracks'] is List) {
          _tracks = (data['tracks'] as List)
              .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      final plFile = await _playlistsFile;
      if (await plFile.exists()) {
        final content = await plFile.readAsString();
        final data = jsonDecode(content);
        if (data is List) {
          _playlists = data
              .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      final onFile = await _onlineFile;
      if (await onFile.exists()) {
        final data = jsonDecode(await onFile.readAsString());
        if (data is List) {
          for (final e in data) {
            if (e is! Map) continue;
            final t = Track.fromJson(Map<String, dynamic>.from(e));
            if (t.id.isNotEmpty) _onlineTracks[t.id] = t;
          }
        }
      }
    } catch (e) {
      print('Errore lettura file indice: $e');
    }
  }

  /// Scansiona la cartella Music per rilevare file aggiunti, rimossi e estrarre copertine/metadati ID3
  Future<void> scanLibrary() async {
    final dir = await musicDirectory;
    final docs = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${docs.path}/Covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final validExts = {'.mp3', '.m4a', '.aac', '.wav', '.flac', '.aif', '.aiff', '.caf', '.alac'};

    final foundFiles = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final dotIdx = entity.path.lastIndexOf('.');
        if (dotIdx != -1) {
          final ext = entity.path.toLowerCase().substring(dotIdx);
          if (validExts.contains(ext)) {
            foundFiles.add(entity);
          }
        }
      }
    }

    final existingMap = {for (var t in _tracks) if (t.filePath != null) t.filePath!: t};
    final existingByName = <String, Track>{};
    for (final t in _tracks) {
      final fp = t.filePath;
      if (fp != null) existingByName[_nomeFile(fp)] = t;
    }
    final newTracks = <Track>[];

    for (final file in foundFiles) {
      final path = file.path;
      var existing = existingMap[path];

      // Dopo una reinstallazione iOS rinomina la cartella Documents: il
      // percorso salvato non combacia piu', ma il file e' lo stesso. Lo si
      // riconosce dal nome, cosi' titolo e artista gia' noti non vanno persi
      // (i download da YouTube non hanno tag da cui rileggerli).
      if (existing == null) {
        final perNome = existingByName[_nomeFile(path)];
        if (perNome != null) {
          var cover = perNome.thumbnailUrl ?? '';
          if (cover.isNotEmpty && !cover.startsWith('http')) {
            final spostata = '${coversDir.path}/${_nomeFile(cover)}';
            cover = File(spostata).existsSync() ? spostata : '';
          }
          existing = perNome.copyWith(id: path, filePath: path, thumbnailUrl: cover);
        }
      }

      // Se già esiste e ha già copertina salvata, mantienilo per velocità
      if (existing != null && existing.thumbnailUrl != null && existing.thumbnailUrl!.isNotEmpty) {
        newTracks.add(existing);
        continue;
      }

      // Estrai metadati ID3 / M4A / FLAC e copertina incorporata
      final meta = await MetadataService.instance.extractMetadata(file, coversDir);

      final name = file.path.split(Platform.pathSeparator).last;
      final dotIdx = name.lastIndexOf('.');
      final nameWithoutExt = dotIdx != -1 ? name.substring(0, dotIdx) : name;

      String artist = (meta.artist != null && meta.artist!.isNotEmpty) ? meta.artist! : (existing?.artist ?? '');
      String title = (meta.title != null && meta.title!.isNotEmpty) ? meta.title! : (existing?.title ?? nameWithoutExt);
      String album = (meta.album != null && meta.album!.isNotEmpty) ? meta.album! : (existing?.album ?? '');
      String? cover = meta.coverPath ?? existing?.thumbnailUrl;

      // Se i metadati ID3 non contenevano artista, prova a splittare "Artista - Titolo"
      if (artist.isEmpty && nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        artist = parts[0].trim();
        if (title == nameWithoutExt) {
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      int size = 0;
      try {
        size = await file.length();
      } catch (_) {}

      newTracks.add(Track(
        id: path,
        title: title.isNotEmpty ? title : nameWithoutExt,
        artist: artist.isNotEmpty ? artist : 'Artista sconosciuto',
        album: album,
        filePath: path,
        fileSize: size,
        thumbnailUrl: cover,
        duration: meta.duration ?? existing?.duration ?? Duration.zero,
        bpm: meta.bpm ?? existing?.bpm,
      ));
    }

    // Conserva anche tracce online marcate esplicitamente o nei preferiti
    for (final t in _tracks) {
      if (t.isOnline && !newTracks.any((x) => x.id == t.id)) {
        newTracks.add(t);
      }
    }

    _tracks = newTracks;
    await saveLibrary();
    notifyListeners();
  }

  Future<void> saveLibrary() async {
    try {
      final file = await _libraryFile;
      final map = {
        'version': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'tracks': _tracks.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      print('Errore salvataggio library.json: $e');
    }
  }

  Future<void> savePlaylists() async {
    try {
      final file = await _playlistsFile;
      await file.writeAsString(jsonEncode(_playlists.map((e) => e.toJson()).toList()));
    } catch (e) {
      print('Errore salvataggio playlists.json: $e');
    }
  }

  Future<Playlist> createPlaylist(String name, [List<String>? trackIds]) async {
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final pl = Playlist(id: id, name: name, trackIds: trackIds ?? []);
    _playlists.add(pl);
    await savePlaylists();
    notifyListeners();
    return pl;
  }

  /// Crea una playlist gia' piena, salvando una volta sola.
  ///
  /// Serve per importare un album o una playlist online: aggiungendo i
  /// brani uno alla volta si riscriverebbero i file a ogni brano.
  Future<Playlist> createPlaylistWithTracks(String name, List<Track> tracks) async {
    final ids = <String>[];
    final visti = <String>{};
    for (final t in tracks) {
      if (t.id.isEmpty || !visti.add(t.id)) continue;
      ids.add(t.id);
      if (t.isOnline) _onlineTracks.putIfAbsent(t.id, () => t);
    }
    await _saveOnlineTracks();
    return createPlaylist(name, ids);
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final pl = _playlists.firstWhere((p) => p.id == id, orElse: () => Playlist(id: '', name: ''));
    if (pl.id.isNotEmpty) {
      pl.name = newName;
      pl.updatedAt = DateTime.now();
      await savePlaylists();
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await savePlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId, orElse: () => Playlist(id: '', name: ''));
    if (pl.id.isNotEmpty && !pl.trackIds.contains(trackId)) {
      pl.trackIds.add(trackId);
      pl.updatedAt = DateTime.now();
      await savePlaylists();
      notifyListeners();
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final pl = _playlists.firstWhere((p) => p.id == playlistId, orElse: () => Playlist(id: '', name: ''));
    if (pl.id.isNotEmpty) {
      pl.trackIds.remove(trackId);
      pl.updatedAt = DateTime.now();
      await savePlaylists();
      notifyListeners();
    }
  }

  Future<void> deleteTrack(Track track) async {
    if (track.filePath != null) {
      try {
        final f = File(track.filePath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        print('Errore cancellazione file: $e');
      }
    }
    _tracks.removeWhere((t) => t.id == track.id);
    for (final pl in _playlists) {
      pl.trackIds.remove(track.id);
    }
    await saveLibrary();
    await savePlaylists();
    notifyListeners();
  }

  /// Solo il nome del file, senza cartelle: e' la parte stabile di un id.
  static String _nomeFile(String percorso) {
    // Niente regex: una classe di caratteri con la barra rovesciata va
    // sfuggita, ed e' facile sbagliarla. Due ricerche sono piu' chiare.
    final slash = percorso.lastIndexOf('/');
    final backslash = percorso.lastIndexOf('\\');
    final i = slash > backslash ? slash : backslash;
    return i == -1 ? percorso : percorso.substring(i + 1);
  }

  /// Cerca una traccia per id, con una rete di sicurezza sul nome del file.
  ///
  /// Gli id delle tracce locali sono percorsi assoluti, e su iOS il percorso
  /// della cartella Documents contiene un UUID che cambia a ogni
  /// reinstallazione dell'app. Dopo un aggiornamento dell'IPA le playlist
  /// salvate contengono quindi percorsi che non esistono piu': il confronto
  /// esatto non trova nulla e la playlist risulta vuota, mentre il conteggio
  /// resta giusto perche' legge trackIds.length. Confrontando anche il solo
  /// nome del file le playlist sopravvivono ai reinstalli.
  Track? getTrackById(String id) {
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    final online = _onlineTracks[id];
    if (online != null) return online;
    final nome = _nomeFile(id);
    if (nome.isEmpty) return null;
    for (final t in _tracks) {
      if (_nomeFile(t.id) == nome) return t;
      final fp = t.filePath;
      if (fp != null && _nomeFile(fp) == nome) return t;
    }
    return null;
  }

  List<Track> getTracksForPlaylist(Playlist playlist) {
    return playlist.trackIds
        .map((id) => getTrackById(id))
        .whereType<Track>()
        .toList();
  }

  String exportBackupJson() {
    final backup = {
      'app': 'DovvoPlay',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'tracks': _tracks.map((t) => t.toJson()).toList(),
      'playlists': _playlists.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<void> importBackupJson(String jsonString, {bool replace = false}) async {
    final data = jsonDecode(jsonString);
    if (data is! Map) return;

    if (replace) {
      _playlists.clear();
    }

    if (data['playlists'] is List) {
      for (final item in data['playlists']) {
        final p = Playlist.fromJson(Map<String, dynamic>.from(item));
        final existingIdx = _playlists.indexWhere((x) => x.name.toLowerCase() == p.name.toLowerCase());
        if (existingIdx >= 0) {
          // Unisci i brani
          for (final tId in p.trackIds) {
            if (!_playlists[existingIdx].trackIds.contains(tId)) {
              _playlists[existingIdx].trackIds.add(tId);
            }
          }
        } else {
          _playlists.add(p);
        }
      }
    }
    await savePlaylists();
    notifyListeners();
  }
}
