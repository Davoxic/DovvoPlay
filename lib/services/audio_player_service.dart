import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import '../models/youtube_track.dart';
import 'app_notice.dart';
import 'history_service.dart';
import 'party_service.dart';
import 'playback_settings.dart';
import 'scrobble_service.dart';
import 'stats_service.dart';
import 'youtube_service.dart';
import 'ytmusic_service.dart';

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
  final Stopwatch _trackListenWatch = Stopwatch();

  Timer? _secondTicker;

  /// Il completamento di un brano e' gia' stato gestito: lo stato "finito"
  /// puo' essere notificato piu' volte e non deve far scattare due cambi.
  bool _fineGestita = false;

  // Volume: quello scelto dall'equalizzatore per la dissolvenza in corso.
  double _volumeBase = 1.0;
  double _fattoreDissolvenza = 1.0;

  double _speed = 1.0;

  // Timer di spegnimento.
  Timer? _timerSpegnimento;
  DateTime? _spegniAlle;
  bool _spegniAFineBrano = false;

  // AutoPlay.
  bool _autoplayInCorso = false;
  final Set<String> _autoplayVisti = {};

  // Dati della sorgente, per le "statistiche per nerd".
  String _formatoSorgente = '';
  int _byteSorgente = 0;
  String _notaSorgente = '';

  /// Id del brano in riproduzione. Chi deve solo evidenziare la riga
  /// corrente ascolta questo, che cambia a ogni brano, invece dell'intero
  /// player, che notifica piu' volte al secondo per l'avanzamento.
  final ValueNotifier<String?> currentTrackId = ValueNotifier<String?>(null);

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

  /// Velocita' di riproduzione, 1.0 = normale.
  double get speed => _speed;

  /// Tempo che manca allo spegnimento, null se non c'e' un timer a tempo.
  Duration? get sleepRemaining {
    final alle = _spegniAlle;
    if (alle == null) return null;
    final resto = alle.difference(DateTime.now());
    return resto.isNegative ? Duration.zero : resto;
  }

  /// true se la riproduzione si fermera' alla fine del brano corrente.
  bool get sleepAfterTrack => _spegniAFineBrano;
  bool get hasSleepTimer => _spegniAlle != null || _spegniAFineBrano;

  /// true mentre AutoPlay sta cercando altri brani.
  bool get isLoadingAutoplay => _autoplayInCorso;

  /// Formato, bitrate e peso di cio' che sta suonando, in una riga.
  String get nerdStatsLabel {
    if (_currentTrack == null) return '';
    final parti = <String>[];
    if (_formatoSorgente.isNotEmpty) parti.add(_formatoSorgente);
    final ms = _duration.inMilliseconds;
    if (_byteSorgente > 0) {
      if (ms > 0) parti.add('${(_byteSorgente * 8 / ms).round()} kbps');
      parti.add('${(_byteSorgente / (1024 * 1024)).toStringAsFixed(1)} MB');
    }
    if (_notaSorgente.isNotEmpty) parti.add(_notaSorgente);
    if ((_speed - 1.0).abs() > 0.01) parti.add('${formatSpeed(_speed)}x');
    return parti.join(' · ');
  }

  /// 1.0 -> "1.0", 1.25 -> "1.25".
  static String formatSpeed(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  void _initListeners() {
    // Ticker secondo per secondo per le statistiche reali
    _secondTicker?.cancel();
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.playing && _currentTrack != null && !_isBuffering) {
        StatsService.instance.addListeningSeconds(_currentTrack!, seconds: 1);
      }
    });

    _player.playerStateStream.listen((state) {
      _isBuffering = state.processingState == ProcessingState.buffering ||
                     state.processingState == ProcessingState.loading;

      if (_player.playing && !_isBuffering && _currentTrack != null) {
        if (!_trackListenWatch.isRunning) {
          _trackListenWatch.start();
        }
      } else {
        if (_trackListenWatch.isRunning) {
          _trackListenWatch.stop();
        }
      }

      if (state.processingState == ProcessingState.completed) {
        if (!_fineGestita) {
          _fineGestita = true;
          _onTrackCompleted();
        }
      } else if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.buffering) {
        _fineGestita = false;
      }
      notifyListeners();
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print('Errore stream riproduzione: $e');
        final s = e.toString();
        if (s.contains('(-1)') || s.toLowerCase().contains('unknown error')) {
          _lastErrorMessage = 'Riproduzione interrotta o errore di rete. Tocca per riprovare.';
        } else {
          _lastErrorMessage = 'Errore riproduzione ($e)';
        }
        _isBuffering = false;
        notifyListeners();
      },
    );

    _player.positionStream.listen((pos) {
      _position = pos;
      _aggiornaDissolvenza();
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  void _recordCurrentTrackStats() {
    if (_currentTrack == null) return;
    _trackListenWatch.stop();
    final listenedMs = _trackListenWatch.elapsedMilliseconds;
    _trackListenWatch.reset();

    // Se non è stato ascoltato nulla (0 ms), non registrare
    if (listenedMs <= 0) return;

    final totalDur = _duration > Duration.zero
        ? _duration
        : (_currentTrack!.duration > Duration.zero ? _currentTrack!.duration : Duration.zero);

    ScrobbleService.instance.onTrackEnd(_currentTrack!, listenedMs, totalDur);

    double percent = 0.0;
    if (totalDur.inMilliseconds > 0) {
      // Calcolo percentuale basato ESCLUSIVAMENTE sui millisecondi effettivi di ascolto
      percent = (listenedMs / totalDur.inMilliseconds) * 100.0;
    } else {
      // Durata sconosciuta: si stima, ma senza mai arrivare alla soglia del
      // "completo". Prima 120 secondi di ascolto valevano 85%, che superava
      // la vecchia soglia del 70%: qualsiasi brano lungo suonato due minuti
      // finiva contato come ascoltato per intero.
      final sec = listenedMs ~/ 1000;
      if (sec >= 120) {
        percent = 60.0;
      } else if (sec >= 60) {
        percent = 40.0;
      } else if (sec >= 20) {
        percent = 25.0;
      } else {
        percent = 5.0;
      }
    }
    StatsService.instance.recordTrackByPercentage(_currentTrack!, percent.clamp(0.0, 100.0));
  }

  void _onTrackCompleted() {
    if (_currentTrack != null) {
      _recordCurrentTrackStats();
    }

    // Timer "dopo questo brano": ci si ferma qui, col brano riportato
    // all'inizio cosi' il tasto play lo fa ripartire.
    if (_spegniAFineBrano) {
      _spegniAFineBrano = false;
      _player.pause();
      _player.seek(Duration.zero);
      AppNotice.show('Timer di spegnimento: riproduzione in pausa');
      notifyListeners();
      return;
    }

    // Da ospite di un party e' l'host a decidere cosa viene dopo.
    if (PartyService.instance.isGuest) {
      _player.pause();
      return;
    }

    if (_loopMode == PlayerLoopMode.one) {
      _trackListenWatch.reset();
      _trackListenWatch.start();
      _player.seek(Duration.zero);
      _player.play();
    } else if (hasNext) {
      next();
    } else if (_loopMode == PlayerLoopMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      playTrack(_queue[0]);
    } else if (PlaybackSettings.instance.autoplay && _currentTrack != null) {
      _continuaConAutoplay();
    } else {
      _player.pause();
    }
  }

  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;

  /// Il brano che verrebbe dopo, senza cambiare nulla.
  /// Serve al mini player per mostrarlo in anteprima durante lo swipe.
  Track? get nextTrack {
    if (_queue.isEmpty) return null;
    if (_currentIndex >= 0 && _currentIndex < _queue.length - 1) {
      return _queue[_currentIndex + 1];
    }
    if (_loopMode == PlayerLoopMode.all) return _queue.first;
    return null;
  }

  /// Il brano precedente, senza cambiare nulla.
  Track? get previousTrack {
    if (_queue.isEmpty) return null;
    if (_currentIndex > 0) return _queue[_currentIndex - 1];
    if (_loopMode == PlayerLoopMode.all) return _queue.last;
    return null;
  }

  /// Mette il brano subito dopo quello in riproduzione, scavalcando la coda.
  void playNext(Track track) {
    if (PartyService.instance.interceptAdd(track, next: true)) return;
    _queue.removeWhere((t) => t.id == track.id && t.id != currentTrack?.id);
    final pos = _currentIndex >= 0 ? _currentIndex + 1 : 0;
    _queue.insert(pos.clamp(0, _queue.length), track);
    _ultimoAccodato = pos;
    if (!_originalQueue.any((t) => t.id == track.id)) {
      _originalQueue.add(track);
    }
    notifyListeners();
  }

  /// Posizione dell'ultimo brano accodato a mano: serve a incatenarli.
  int _ultimoAccodato = -1;

  /// Accoda il brano subito dopo l'ultimo accodato a mano.
  ///
  /// Il primo finisce subito dopo quello in riproduzione, cioe' e' il
  /// prossimo; il secondo si mette dopo il primo, e cosi' via. Prima finivano
  /// tutti in fondo alla coda, che con una libreria lunga voleva dire dopo
  /// centinaia di brani.
  void addToQueue(Track track) {
    if (PartyService.instance.interceptAdd(track)) return;
    _queue.removeWhere((t) => t.id == track.id && t.id != currentTrack?.id);

    // Se l'ultimo accodato non e' piu' valido, si riparte da quello corrente.
    if (_ultimoAccodato < _currentIndex || _ultimoAccodato >= _queue.length) {
      _ultimoAccodato = _currentIndex;
    }

    final pos = (_ultimoAccodato + 1).clamp(0, _queue.length);
    _queue.insert(pos, track);
    _ultimoAccodato = pos;

    if (!_originalQueue.any((t) => t.id == track.id)) {
      _originalQueue.add(track);
    }
    notifyListeners();
  }

  /// Toglie un brano dalla coda, tenendo l'indice corrente allineato.
  void removeFromQueue(String trackId) {
    final i = _queue.indexWhere((t) => t.id == trackId);
    if (i == -1 || i == _currentIndex) return;
    _queue.removeAt(i);
    if (i < _currentIndex) _currentIndex--;
    notifyListeners();
  }
  bool get hasPrevious => _currentIndex > 0;

  /// Sposta un brano della coda da una posizione a un'altra.
  void moveQueueItem(int da, int a) {
    if (da < 0 || da >= _queue.length || a < 0 || a >= _queue.length || da == a) {
      return;
    }
    final corrente = _currentTrack;
    final brano = _queue.removeAt(da);
    _queue.insert(a, brano);
    if (corrente != null) {
      final i = _queue.indexWhere((t) => t.id == corrente.id);
      if (i != -1) _currentIndex = i;
    }
    _ultimoAccodato = -1;
    notifyListeners();
  }

  /// Toglie dalla coda il brano in [indice], se non e' quello che suona.
  void removeQueueAt(int indice) {
    if (indice < 0 || indice >= _queue.length || indice == _currentIndex) return;
    _queue.removeAt(indice);
    if (indice < _currentIndex) _currentIndex--;
    _ultimoAccodato = -1;
    notifyListeners();
  }

  /// Svuota tutto cio' che viene dopo il brano in riproduzione.
  void clearUpcoming() {
    if (_currentIndex >= 0 && _currentIndex < _queue.length - 1) {
      _queue.removeRange(_currentIndex + 1, _queue.length);
    }
    _ultimoAccodato = -1;
    notifyListeners();
  }

  /// Salta direttamente a un brano della coda.
  Future<void> jumpToQueueIndex(int indice) async {
    if (indice < 0 || indice >= _queue.length) return;
    if (PartyService.instance.isGuest) {
      AppNotice.show("Nel party e' l'host a scegliere i brani");
      return;
    }
    _currentIndex = indice;
    await playTrack(_queue[indice]);
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    final requestId = ++_playRequestId;

    // Registra le statistiche con percentuale di ascolto del brano precedente
    if (_currentTrack != null) {
      _recordCurrentTrackStats();
    }
    _trackListenWatch.reset();

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
    currentTrackId.value = track.id;
    _position = Duration.zero;
    _duration = track.duration > Duration.zero ? track.duration : Duration.zero;
    _isBuffering = true;
    _lastErrorMessage = null;
    _formatoSorgente = '';
    _byteSorgente = 0;
    _notaSorgente = '';
    notifyListeners();

    // Registra statistiche di avvio riproduzione
    StatsService.instance.recordTrackStart(track);
    HistoryService.instance.record(track);
    ScrobbleService.instance.onTrackStart(track);

    try {
      Uri? artUri;
      if (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty) {
        artUri = track.thumbnailUrl!.startsWith('http')
            ? Uri.tryParse(track.thumbnailUrl!)
            : Uri.file(track.thumbnailUrl!.replaceFirst('file://', ''));
      }

      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : (track.isOnline ? 'YouTube' : 'DovvoPlay'),
        title: track.displayTitle,
        artist: track.displayArtist,
        artUri: artUri,
        duration: track.duration > Duration.zero ? track.duration : null,
      );

      if (track.isOnline) {
        final videoId = track.id.replaceFirst('yt_', '');

        // 1. Controlla se la canzone è già scaricata o in cache locale completa
        final localFile = await YouTubeService.instance.getLocalAudioFile(track.id);
        if (localFile != null && await localFile.exists() && await localFile.length() > 50000) {
          _descriviSorgente(
            percorso: localFile.path,
            bytes: await localFile.length(),
            nota: localFile.path.contains('yt_cache') ? 'cache' : 'offline',
          );
          final audioSource = AudioSource.uri(Uri.file(localFile.path), tag: mediaItem);
          await _player.setAudioSource(audioSource);
          if (_playRequestId != requestId) return;
          await _player.play();
          return;
        }

        // 2. Scarica in cache locale via youtube_explode (evita 403 e (-1) unknown error di iOS AVPlayer)
        final cached = await YouTubeService.instance.downloadToCache(videoId, track.title);
        if (_playRequestId != requestId) return;

        if (cached != null && await cached.exists() && await cached.length() > 50000) {
          _descriviSorgente(
            percorso: cached.path,
            bytes: await cached.length(),
            nota: 'streaming',
          );
          final audioSource = AudioSource.uri(Uri.file(cached.path), tag: mediaItem);
          await _player.setAudioSource(audioSource);
          if (_playRequestId != requestId) return;
          await _player.play();
          return;
        }

        // 3. Fallback: tenta lo stream diretto se il download in cache ha fallito
        final streamInfo = await YouTubeService.instance.getPlayableStreamInfo(videoId);
        if (_playRequestId != requestId) return;

        if (streamInfo != null) {
          _formatoSorgente = 'AAC';
          _byteSorgente = streamInfo.size.totalBytes;
          _notaSorgente = 'streaming diretto';
          final audioSource = AudioSource.uri(streamInfo.url, tag: mediaItem);
          await _player.setAudioSource(audioSource);
          if (_playRequestId != requestId) return;
          await _player.play();
          return;
        }

        throw Exception('Impossibile ottenere il flusso audio compatibile per iOS.');
      } else if (track.filePath != null) {
        _descriviSorgente(
          percorso: track.filePath!,
          bytes: track.fileSize ?? 0,
          nota: 'file locale',
        );
        final audioSource = AudioSource.uri(Uri.file(track.filePath!), tag: mediaItem);
        await _player.setAudioSource(audioSource);
        if (_playRequestId != requestId) return;
        await _player.play();
      } else if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        _notaSorgente = 'dalla rete';
        final audioSource = AudioSource.uri(Uri.parse(track.streamUrl!), tag: mediaItem);
        await _player.setAudioSource(audioSource);
        if (_playRequestId != requestId) return;
        await _player.play();
      } else {
        throw Exception('Percorso audio non valido.');
      }
    } catch (e, stack) {
      final s = e.toString();
      if (s.contains('(-1)') || s.toLowerCase().contains('unknown error')) {
        _lastErrorMessage = 'Errore connessione audio. Riprova con un altro brano.';
      } else {
        _lastErrorMessage = s.replaceFirst('Exception: ', '');
      }
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
    if (PartyService.instance.interceptCommand('toggle')) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        // A coda finita il tasto play fa ripartire l'ultimo brano, invece
        // di non fare nulla.
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();

  Future<void> seek(Duration position) async {
    if (PartyService.instance.interceptCommand(
      'seek',
      positionMs: position.inMilliseconds,
    )) {
      return;
    }
    await _player.seek(position);
  }

  /// Sposta la riproduzione senza passare dal party: lo usa il party stesso
  /// per riallineare un ospite all'host.
  Future<void> seekDirect(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (PartyService.instance.interceptCommand('next')) return;
    if (hasNext) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    } else if (_loopMode == PlayerLoopMode.all && _queue.isNotEmpty) {
      _currentIndex = 0;
      await playTrack(_queue[0]);
    } else if (PlaybackSettings.instance.autoplay && _currentTrack != null) {
      await _continuaConAutoplay();
    }
  }

  Future<void> previous() async {
    if (PartyService.instance.interceptCommand('prev')) return;
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (hasPrevious) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  // --- VELOCITA', VOLUME E DISSOLVENZA ---

  Future<void> setSpeed(double velocita) async {
    _speed = velocita.clamp(0.5, 2.0);
    try {
      await _player.setSpeed(_speed);
    } catch (e) {
      print('Avviso velocita: $e');
    }
    notifyListeners();
  }

  /// Volume deciso dall'equalizzatore. La dissolvenza ci si moltiplica
  /// sopra: se ognuno impostasse il volume per conto suo si annullerebbero
  /// a vicenda.
  void setBaseVolume(double volume) {
    _volumeBase = volume.clamp(0.0, 1.0);
    _applicaVolume();
  }

  void _applicaVolume() {
    try {
      _player.setVolume((_volumeBase * _fattoreDissolvenza).clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// Abbassa il volume negli ultimi secondi di un brano e lo rialza
  /// all'inizio del successivo.
  ///
  /// Non e' una dissolvenza incrociata vera: servirebbero due lettori che
  /// suonano insieme, e i controlli da schermata di blocco ne reggono uno
  /// solo. L'effetto all'ascolto e' comunque un passaggio morbido.
  void _aggiornaDissolvenza() {
    final secondi = PlaybackSettings.instance.fadeSeconds;
    var fattore = 1.0;
    final totaleMs = _duration.inMilliseconds;
    if (secondi > 0 && totaleMs > secondi * 3000) {
      final uscitaMs = secondi * 1000;
      final ingressoMs = min(uscitaMs, 2500);
      final posMs = _position.inMilliseconds;
      final restoMs = totaleMs - posMs;
      if (restoMs < uscitaMs) {
        fattore = (restoMs / uscitaMs).clamp(0.0, 1.0);
      } else if (posMs < ingressoMs) {
        fattore = (0.25 + 0.75 * posMs / ingressoMs).clamp(0.0, 1.0);
      }
    }
    if ((fattore - _fattoreDissolvenza).abs() > 0.01) {
      _fattoreDissolvenza = fattore;
      _applicaVolume();
    }
  }

  // --- TIMER DI SPEGNIMENTO ---

  /// Mette in pausa la riproduzione dopo [durata].
  void startSleepTimer(Duration durata) {
    _timerSpegnimento?.cancel();
    _spegniAFineBrano = false;
    _spegniAlle = DateTime.now().add(durata);
    _timerSpegnimento = Timer(durata, () {
      _spegniAlle = null;
      _timerSpegnimento = null;
      _player.pause();
      AppNotice.show('Timer di spegnimento: riproduzione in pausa');
      notifyListeners();
    });
    notifyListeners();
  }

  /// Mette in pausa alla fine del brano in riproduzione.
  void sleepAfterCurrentTrack() {
    _timerSpegnimento?.cancel();
    _timerSpegnimento = null;
    _spegniAlle = null;
    _spegniAFineBrano = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _timerSpegnimento?.cancel();
    _timerSpegnimento = null;
    _spegniAlle = null;
    _spegniAFineBrano = false;
    notifyListeners();
  }

  // --- RADIO E AUTOPLAY ---

  void _descriviSorgente({
    required String percorso,
    required int bytes,
    required String nota,
  }) {
    final punto = percorso.lastIndexOf('.');
    final ext = punto == -1 ? '' : percorso.substring(punto + 1).toUpperCase();
    _formatoSorgente = ext == 'M4A' ? 'AAC' : ext;
    _byteSorgente = bytes;
    _notaSorgente = nota;
  }

  /// Avvia una radio: il brano scelto seguito da musica simile.
  Future<void> startRadio(Track seme) async {
    if (PartyService.instance.isGuest) {
      AppNotice.show("Nel party e' l'host a scegliere i brani");
      return;
    }
    AppNotice.show('Cerco brani simili a "${seme.displayTitle}"...');
    List<Track> simili;
    try {
      simili = await YtMusicService.instance.radioFor(seme);
    } catch (e) {
      AppNotice.show('Radio non disponibile: controlla la connessione.');
      return;
    }
    if (simili.isEmpty) {
      AppNotice.show('Nessun brano simile trovato.');
      return;
    }

    final coda = <Track>[seme, ...simili];
    for (final t in simili) {
      _autoplayVisti.add(t.id);
    }
    // L'ordine della radio e' gia' ragionato: mescolarlo lo rovinerebbe.
    _shuffleMode = ShuffleMode.off;

    if (_currentTrack?.id == seme.id) {
      // Sta gia' suonando: si cambia solo cio' che viene dopo.
      _queue = coda;
      _originalQueue = List.from(coda);
      _currentIndex = 0;
      _ultimoAccodato = -1;
      notifyListeners();
    } else {
      playTrack(seme, newQueue: coda);
    }
    AppNotice.show('Radio avviata: ${simili.length} brani simili in coda');
  }

  /// A coda finita, aggiunge musica simile all'ultimo brano e prosegue.
  Future<void> _continuaConAutoplay() async {
    if (_autoplayInCorso) return;
    final seme = _currentTrack;
    if (seme == null) return;

    _autoplayInCorso = true;
    notifyListeners();

    var aggiunti = 0;
    try {
      final simili = await YtMusicService.instance.radioFor(seme);
      final presenti = _queue.map((t) => t.id).toSet();
      final senzaRipetere = PlaybackSettings.instance.noRepeatAutoplay;
      for (final t in simili) {
        if (presenti.contains(t.id)) continue;
        if (senzaRipetere && _autoplayVisti.contains(t.id)) continue;
        _autoplayVisti.add(t.id);
        _queue.add(t);
        _originalQueue.add(t);
        aggiunti++;
        if (aggiunti >= 25) break;
      }
    } catch (e) {
      print('Avviso AutoPlay: $e');
    } finally {
      _autoplayInCorso = false;
    }

    // Nel frattempo si potrebbe aver scelto altro: in quel caso i brani
    // restano in coda e basta.
    if (aggiunti > 0 && _currentTrack?.id == seme.id && hasNext) {
      AppNotice.show('AutoPlay: continuo con musica simile');
      notifyListeners();
      next();
    } else {
      if (aggiunti == 0) _player.pause();
      notifyListeners();
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
