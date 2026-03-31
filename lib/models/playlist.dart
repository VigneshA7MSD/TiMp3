import 'package:hive/hive.dart';
import 'track.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<String> trackIds; // References to Track IDs

  @HiveField(4)
  final DateTime dateCreated;

  @HiveField(5)
  final DateTime? dateModified;

  @HiveField(6)
  final String? coverArtPath;

  @HiveField(7)
  final bool isSmartPlaylist;

  @HiveField(8)
  final SmartPlaylistType? smartType;

  @HiveField(9)
  final DateTime? createdAt;

  @HiveField(10)
  final DateTime? updatedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.dateCreated,
    this.description = '',
    this.dateModified,
    this.coverArtPath,
    this.isSmartPlaylist = false,
    this.smartType,
    this.createdAt,
    this.updatedAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? trackIds,
    DateTime? dateCreated,
    DateTime? dateModified,
    String? coverArtPath,
    bool? isSmartPlaylist,
    SmartPlaylistType? smartType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      coverArtPath: coverArtPath ?? this.coverArtPath,
      isSmartPlaylist: isSmartPlaylist ?? this.isSmartPlaylist,
      smartType: smartType ?? this.smartType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, tracks: ${trackIds.length}, smart: $isSmartPlaylist)';
  }
}

@HiveType(typeId: 2)
enum SmartPlaylistType {
  @HiveField(0)
  recentlyPlayed,

  @HiveField(1)
  mostPlayed,

  @HiveField(2)
  recentlyAdded,

  @HiveField(3)
  favorites,
}
