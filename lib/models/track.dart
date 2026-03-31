import 'package:hive/hive.dart';

part 'track.g.dart';

@HiveType(typeId: 0)
class Track extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String album;

  @HiveField(4)
  final String path;

  @HiveField(5)
  final Duration duration;

  @HiveField(6)
  final int size;

  @HiveField(7)
  final DateTime dateAdded;

  @HiveField(8)
  final DateTime? dateModified;

  @HiveField(9)
  final int playCount;

  @HiveField(10)
  final DateTime? lastPlayed;

  @HiveField(11)
  final String? albumArtPath;

  @HiveField(12)
  final String? genre;

  @HiveField(13)
  final int? year;

  @HiveField(14)
  final int? trackNumber;

  @HiveField(15)
  final String? lyricsPath;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.size,
    required this.dateAdded,
    this.dateModified,
    this.playCount = 0,
    this.lastPlayed,
    this.albumArtPath,
    this.genre,
    this.year,
    this.trackNumber,
    this.lyricsPath,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    Duration? duration,
    int? size,
    DateTime? dateAdded,
    DateTime? dateModified,
    int? playCount,
    DateTime? lastPlayed,
    String? albumArtPath,
    String? genre,
    int? year,
    int? trackNumber,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
    );
  }

  @override
  String toString() {
    return 'Track(id: $id, title: $title, artist: $artist, album: $album, duration: $duration)';
  }
}
