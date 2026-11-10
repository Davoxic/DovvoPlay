import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import '../models/youtube_track.dart';
import 'stats_service.dart';
import 'youtube_service.dart';

enum PlayerLoopMode { off, all, one }

enum ShuffleMode {
  off('Disattivo', Icons.shuffle_rounded, 'Ordine sequenziale'),
  magic('Magico', Icons.auto_awesome_rounded, 'Mix intelligente tra preferite, medie e da riscoprire'),
  standard('Casuale 100%', Icons.shuffle_rounded, 'Mescola tutti i brani casualmente'),
  mostPlayed('Hit Parade', Icons.local_fire_department_rounded, 'Priorità ai brani più ascoltati e ripetuti'),
  leastPlayed('Riscopri', Icons.explore_rounded, 'Ascolta le canzoni mai o meno ascoltate'),
  mediumPlayed('Equilibrato', Icons.balance_rounded, 'Canzoni nella fascia media di ascolto'),
  recent('Freschi & Recenti', Icons.history_rounded, 'Brani recenti o aggiunti ultimamente');

  final String label;
  final IconData icon;
  final String description;
  const ShuffleMode(this.label, this.icon, this.description);
}

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._() {
    _initListeners();
  }

  // AudioPlayer standard senza proxy header custom su iOS
  // (permette ad AVPlayer di riprodurre HLS ed m4a senza interferenze proxy)
  final AudioPlayer _player = AudioPlayer();

  Track? _currentTrack;
  List<Track> _queue = [];
  List<Track> _originalQueue = [];
  int _currentIndex = -1;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerLoopMode _loopMode = PlayerLoopMode.off;
  ShuffleMode _shuffleMode = ShuffleMode.off;
  int _playRequestId = 0;
  String? _lastErrorMessage;

  AudioPlayer get player => _player;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerLoopMode get loopMode => _loopMode;
  ShuffleMode get shuffleMode => _shuffleMode;
  bool get isShuffle => _shuffleMode != ShuffleMode.off;
  String? get lastErrorMessage => _lastErrorMessage;

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      _isBuffering = state.processingState == ProcessingState.buffering ||
                     state.processingState == ProcessingState.loading;

      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
      notifyListeners();
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print('Errore stream riproduzione: $e');
        _lastErrorMessage = 'Errore riproduzione iOS ($e)';
        _isBuffering = false;
        notifyListeners();
      },
    );

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  void _onTrackCompleted() {
    if (_currentTrack != null) {
      StatsService.instance.recordTrackCompleted(_currentTrack!);
    }

    if (_loopMode == PlayerLoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (hasNext) {
      next();
    } else if (_loopMode == PlayerLoopMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      playTrack(_queue[0]);
    } else {
      _player.pause();
    }
  }

  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    final requestId = ++_playRequestId;

    if (newQueue != null) {
      _originalQueue = List.from(newQueue);
      _queue = List.from(newQueue);
      if (_shuffleMode != ShuffleMode.off) {
        _applyShuffleLogic(_shuffleMode, keepCurrentTrack: track);
      } else {
        _currentIndex = _queue.indexWhere((t) => t.id == track.id);
        if (_currentIndex == -1) {
          _queue.insert(0, track);
          _currentIndex = 0;
        }
      }
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _originalQueue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _currentTrack = track;
    _position = Duration.zero;
    _duration = track.duration > Duration.zero ? track.duration : Duration.zero;
    _isBuffering = true;
    _lastErrorMessage = null;
    notifyListeners();

    // Registra statistiche di avvio riproduzione
    StatsService.instance.recordTrackStart(track);

    try {
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : (track.isOnline ? 'YouTube' : 'SborraPlay'),
        title: track.displayTitle,
        artist: track.displayArtist,
        artUri: track.thumbnailUrl != null ? Uri.tryParse(track.thumbnailUrl!) : null,
        duration: track.duration > Duration.zero ? track.duration : null,
      );

      if (track.isOnline) {
        final videoId = track.id.replaceFirst('yt_', '');

        // 1. Controlla se la canzone è già scaricata o in cache locale
        final localFile = await YouTubeService.instance.getLocalAudioFile(track.id);
        if (localFile != null && await localFile.exists()) {
          final audioSource = AudioSource.uri(Uri.file(localFile.path), tag: mediaItem);
          await _player.setAudioSource(audioSource);
          if (_playRequestId != requestId) return;
          await _player.play();
          return;
        }

        // 2. Prova prima lo stream HLS (.m3u8) nativo per iOS (zero download del file, streaming istantaneo)
        final hlsUrl = await YouTubeService.instance.getHlsStreamUrl(videoId);
        if (_playRequestId != requestId) return;

        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          try {
            final audioSource = AudioSource.uri(Uri.parse(hlsUrl), tag: mediaItem);
            await _player.setAudioSource(audioSource);
            if (_playRequestId != requestId) return;
            await _player.play();
            return;
          } catch (hlsErr) {
            print('Streaming HLS non riuscito ($hlsErr), procedo al download in cache...');
          }
        }

        // 3. Fallback: scarica i chunk audio AAC (.m4a) in cache con youtube_explode
        // (completamente immune al blocco 403 Forbidden di Google Video CDN)
        final cached = await YouTubeService.instance.downloadToCache(videoId, track.title);
        if (_playRequestId != requestId) return;

        if (cached != null && await cached.exists()) {
          final audioSource = AudioSource.uri(Uri.file(cached.path), tag: mediaItem);
          await _player.setAudioSource(audioSource);
          if (_playRequestId != requestId) return;
          await _player.play();
          return;
        }

        throw Exception('Impossibile ottenere il flusso audio compatibile per iOS.');
      } else if (track.filePath != null) {
        final audioSource = AudioSource.uri(Uri.file(track.filePath!), tag: mediaItem);
        await _player.setAudioSource(audioSource);
        if (_playRequestId != requestId) return;
        await _player.play();
      } else if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        final audioSource = AudioSource.uri(Uri.parse(track.streamUrl!), tag: mediaItem);
        await _player.setAudioSource(audioSource);
        if (_playRequestId != requestId) return;
        await _player.play();
      } else {
        throw Exception('Percorso audio non valido.');
      }
    } catch (e, stack) {
      _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
      print('Errore riproduzione: $e\n$stack');
    } finally {
      if (_playRequestId == requestId) {
        _isBuffering = false;
        notifyListeners();
      }
    }
  }

  Future<void> playYouTubeTrack(YouTubeTrack ytTrack) async {
    final track = ytTrack.toTrack();
    await playTrack(track);
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (hasNext) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    } else if (_loopMode == PlayerLoopMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      await playTrack(_queue[0]);
    }
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (hasPrevious) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleLoopMode() {
    switch (_loopMode) {
      case PlayerLoopMode.off:
        _loopMode = PlayerLoopMode.all;
        break;
      case PlayerLoopMode.all:
        _loopMode = PlayerLoopMode.one;
        break;
      case PlayerLoopMode.one:
        _loopMode = PlayerLoopMode.off;
        break;
    }
    notifyListeners();
  }

  // --- LOGICA SHUFFLE AVANZATA & SHUFFLE MAGICO ---

  void setShuffleMode(ShuffleMode mode, {List<Track>? baseList}) {
    _shuffleMode = mode;
    if (baseList != null && baseList.isNotEmpty) {
      _originalQueue = List.from(baseList);
      _queue = List.from(baseList);
    }

    if (_shuffleMode == ShuffleMode.off) {
      if (_originalQueue.isNotEmpty) {
        _queue = List.from(_originalQueue);
        if (_currentTrack != null) {
          _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
          if (_currentIndex == -1) _currentIndex = 0;
        }
      }
    } else {
      _applyShuffleLogic(_shuffleMode, keepCurrentTrack: _currentTrack);
    }
    notifyListeners();
  }

  void cycleShuffleMode() {
    final values = ShuffleMode.values;
    final nextIdx = (values.indexOf(_shuffleMode) + 1) % values.length;
    setShuffleMode(values[nextIdx]);
  }

  void toggleShuffle() {
    if (_shuffleMode == ShuffleMode.off) {
      setShuffleMode(ShuffleMode.magic);
    } else {
      setShuffleMode(ShuffleMode.off);
    }
  }

  /// Applica l'algoritmo di riordinamento a seconda della modalità scelta
  void _applyShuffleLogic(ShuffleMode mode, {Track? keepCurrentTrack}) {
    if (_queue.length <= 1) return;

    final pool = List<Track>.from(_originalQueue.isNotEmpty ? _originalQueue : _queue);
    final stats = StatsService.instance;
    final rand = Random();

    List<Track> result = [];

    switch (mode) {
      case ShuffleMode.off:
        result = pool;
        break;

      case ShuffleMode.standard:
        result = List.from(pool)..shuffle(rand);
        break;

      case ShuffleMode.magic:
        // Algoritmo Shuffle Magico:
        // Divide in 3 categorie (Top preferite, Medie, Meno ascoltate / Mai sentite)
        // e le interfaccia con pesatura intelligente, evitando due canzoni dello stesso artista di seguito
        final sortedByPlays = List<Track>.from(pool)
          ..sort((a, b) => stats.getPlayCount(b.id).compareTo(stats.getPlayCount(a.id)));

        final count = sortedByPlays.length;
        final topCut = (count * 0.25).ceil().clamp(1, count);
        final medCut = (count * 0.70).ceil().clamp(topCut, count);

        final topTier = sortedByPlays.sublist(0, topCut)..shuffle(rand);
        final medTier = sortedByPlays.sublist(topCut, medCut)..shuffle(rand);
        final leastTier = sortedByPlays.sublist(medCut)..shuffle(rand);

        final combined = <Track>[];
        while (topTier.isNotEmpty || medTier.isNotEmpty || leastTier.isNotEmpty) {
          if (topTier.isNotEmpty) combined.add(topTier.removeLast());
          if (medTier.isNotEmpty) combined.add(medTier.removeLast());
          if (leastTier.isNotEmpty) combined.add(leastTier.removeLast());
          if (medTier.isNotEmpty) combined.add(medTier.removeLast());
        }

        // Anti-consecutive artist smoothing
        result = _smoothArtistCollisions(combined);
        break;

      case ShuffleMode.mostPlayed:
        // Priorità ai brani più ascoltati con un tocco di casualità
        final list = List<Track>.from(pool);
        list.sort((a, b) {
          final countA = stats.getPlayCount(a.id) * 10 + stats.getRepeatCount(a.id) * 5 + rand.nextInt(5);
          final countB = stats.getPlayCount(b.id) * 10 + stats.getRepeatCount(b.id) * 5 + rand.nextInt(5);
          return countB.compareTo(countA);
        });
        result = list;
        break;

      case ShuffleMode.leastPlayed:
        // Priorità assoluta a brani mai ascoltati o meno ascoltati
        final list = List<Track>.from(pool);
        list.sort((a, b) {
          final countA = stats.getPlayCount(a.id) * 10 + rand.nextInt(4);
          final countB = stats.getPlayCount(b.id) * 10 + rand.nextInt(4);
          return countA.compareTo(countB);
        });
        result = list;
        break;

      case ShuffleMode.mediumPlayed:
        // Brani nella fascia media
        final list = List<Track>.from(pool);
        list.sort((a, b) => stats.getPlayCount(b.id).compareTo(stats.getPlayCount(a.id)));
        final start = (list.length * 0.20).floor();
        final end = (list.length * 0.80).ceil();
        final middle = list.sublist(start.clamp(0, list.length), end.clamp(0, list.length))..shuffle(rand);
        final remaining = list.where((t) => !middle.contains(t)).toList()..shuffle(rand);
        result = [...middle, ...remaining];
        break;

      case ShuffleMode.recent:
        // Canzoni aggiunte o ascoltate di recente
        final list = List<Track>.from(pool);
        list.sort((a, b) {
          final timeA = stats.getStat(a.id)?.lastPlayedAt ?? a.addedAt;
          final timeB = stats.getStat(b.id)?.lastPlayedAt ?? b.addedAt;
          return timeB.compareTo(timeA);
        });
        // Aggiungi un leggero jitter per non renderlo identico ogni volta
        for (int i = 0; i < list.length - 1; i += 2) {
          if (rand.nextBool()) {
            final tmp = list[i];
            list[i] = list[i + 1];
            list[i + 1] = tmp;
          }
        }
        result = list;
        break;
    }

    // Assicura che la canzone attualmente in riproduzione rimanga al primo posto
    if (keepCurrentTrack != null) {
      result.removeWhere((t) => t.id == keepCurrentTrack.id);
      result.insert(0, keepCurrentTrack);
      _currentIndex = 0;
    }

    _queue = result;
  }

  List<Track> _smoothArtistCollisions(List<Track> list) {
    if (list.length <= 2) return list;
    final smoothed = <Track>[list.first];
    final remaining = List<Track>.from(list.sublist(1));

    while (remaining.isNotEmpty) {
      final lastArtist = smoothed.last.displayArtist.toLowerCase();
      int foundIndex = -1;

      for (int i = 0; i < remaining.length; i++) {
        if (remaining[i].displayArtist.toLowerCase() != lastArtist) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        smoothed.add(remaining.removeAt(foundIndex));
      } else {
        // Nessun artista diverso disponibile
        smoothed.addAll(remaining);
        break;
      }
    }
    return smoothed;
  }
}
