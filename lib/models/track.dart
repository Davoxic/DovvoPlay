class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? filePath;
  final bool isOnline;
  final String? streamUrl;
  final String? thumbnailUrl;
  final int? fileSize;

  /// Battiti per minuto, dal tag TBPM. Lo scrive il PC durante il download,
  /// e serve all'effetto ambient per pulsare a tempo. null = sconosciuto.
  final double? bpm;
  final DateTime addedAt;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.duration,
    this.filePath,
    this.isOnline = false,
    this.streamUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.bpm,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get displayTitle => title.isEmpty ? 'Traccia sconosciuta' : title;
  String get displayArtist => artist.isEmpty ? 'Artista sconosciuto' : artist;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? filePath,
    bool? isOnline,
    String? streamUrl,
    String? thumbnailUrl,
    int? fileSize,
    double? bpm,
    DateTime? addedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      isOnline: isOnline ?? this.isOnline,
      streamUrl: streamUrl ?? this.streamUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSize: fileSize ?? this.fileSize,
      bpm: bpm ?? this.bpm,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration_ms': duration.inMilliseconds,
    'filePath': filePath,
    'isOnline': isOnline,
    'streamUrl': streamUrl,
    'thumbnailUrl': thumbnailUrl,
    'fileSize': fileSize,
    'bpm': bpm,
    'addedAt': addedAt.toIso8601String(),
    'file': filePath != null ? filePath!.split('/').last : id,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? json['file'] ?? '',
      title: json['title'] ?? json['name'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      duration: Duration(milliseconds: json['duration_ms'] ?? 0),
      filePath: json['filePath'],
      isOnline: json['isOnline'] ?? false,
      streamUrl: json['streamUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      fileSize: json['fileSize'],
      bpm: (json['bpm'] as num?)?.toDouble(),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
