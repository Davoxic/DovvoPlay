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

  final AudioPlayer _player = AudioPlayer();
  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerLoopMode _loopMode = PlayerLoopMode.off;
  bool _isShuffle = false;

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

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      _isBuffering = state.processingState == ProcessingState.buffering ||
                     state.processingState == ProcessingState.loading;

      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
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
    _isBuffering = true;
    notifyListeners();

    try {
      Uri audioUri;
      if (track.isOnline) {
        String? streamUrl = track.streamUrl;
        if (streamUrl == null || streamUrl.isEmpty) {
          final videoId = track.id.replaceFirst('yt_', '');
          streamUrl = await YouTubeService.instance.getAudioStreamUrl(videoId);
          if (streamUrl == null) {
            _isBuffering = false;
            notifyListeners();
            throw Exception('Impossibile estrarre lo stream audio per questa canzone.');
          }
        }
        audioUri = Uri.parse(streamUrl);
      } else if (track.filePath != null) {
        audioUri = Uri.file(track.filePath!);
      } else {
        throw Exception('Percorso audio non valido.');
      }

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
      await _player.play();
    } catch (e) {
      print('Errore riproduzione: $e');
    } finally {
      _isBuffering = false;
      notifyListeners();
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
