import 'package:hive/hive.dart';

part 'bookmark.g.dart';

@HiveType(typeId: 3)
class Bookmark extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String trackId;

  @HiveField(2)
  final Duration position;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final DateTime dateCreated;

  Bookmark({
    required this.id,
    required this.trackId,
    required this.position,
    required this.name,
    required this.dateCreated,
  });

  Bookmark copyWith({
    String? id,
    String? trackId,
    Duration? position,
    String? name,
    DateTime? dateCreated,
  }) {
    return Bookmark(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      name: name ?? this.name,
      dateCreated: dateCreated ?? this.dateCreated,
    );
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, trackId: $trackId, position: $position, name: $name)';
  }
}
