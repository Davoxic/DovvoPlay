import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import '../models/youtube_track.dart';
import 'youtube_service.dart';

enum PlayerLoopMode { off, all, one }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._() {
    _initListeners();
  }

  final AudioPlayer _player = AudioPlayer(
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
  );

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerLoopMode _loopMode = PlayerLoopMode.off;
  bool _isShuffle = false;
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
  bool get isShuffle => _isShuffle;
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
      _queue = List.from(newQueue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
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

    try {
      Uri audioUri;

      if (track.isOnline) {
        // 1. Controlla se il brano è già stato scaricato in locale
        final localFile = await YouTubeService.instance.getLocalDownloadedFile(track.id);
        if (localFile != null && await localFile.exists()) {
          audioUri = Uri.file(localFile.path);
        } else {
          // 2. Altrimenti recupera lo stream URL diretto (MP4/AAC nativo)
          final videoId = track.id.replaceFirst('yt_', '');
          final streamUrl = await YouTubeService.instance.getAudioStreamUrl(videoId);

          if (_playRequestId != requestId) return;

          if (streamUrl == null || streamUrl.isEmpty) {
            throw Exception('Impossibile estrarre lo stream audio per questa canzone.');
          }

          audioUri = Uri.parse(streamUrl);
        }
      } else if (track.filePath != null) {
        audioUri = Uri.file(track.filePath!);
      } else if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        audioUri = Uri.parse(track.streamUrl!);
      } else {
        throw Exception('Percorso audio non valido.');
      }

      if (_playRequestId != requestId) return;

      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : (track.isOnline ? 'YouTube' : 'SborraPlay'),
        title: track.displayTitle,
        artist: track.displayArtist,
        artUri: track.thumbnailUrl != null ? Uri.tryParse(track.thumbnailUrl!) : null,
        duration: track.duration > Duration.zero ? track.duration : null,
      );

      final audioSource = AudioSource.uri(audioUri, tag: mediaItem);
      await _player.setAudioSource(audioSource);

      if (_playRequestId != requestId) return;
      await _player.play();
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

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _queue.length > 1) {
      final current = _currentTrack;
      _queue.shuffle();
      if (current != null) {
        _queue.removeWhere((t) => t.id == current.id);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    }
    notifyListeners();
  }
}
