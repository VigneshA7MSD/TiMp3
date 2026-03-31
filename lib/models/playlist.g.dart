// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaylistAdapter extends TypeAdapter<Playlist> {
  @override
  final int typeId = 1;

  @override
  Playlist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Playlist(
      id: fields[0] as String,
      name: fields[1] as String,
      trackIds: (fields[3] as List).cast<String>(),
      dateCreated: fields[4] as DateTime,
      description: fields[2] as String,
      dateModified: fields[5] as DateTime?,
      coverArtPath: fields[6] as String?,
      isSmartPlaylist: fields[7] as bool,
      smartType: fields[8] as SmartPlaylistType?,
    );
  }

  @override
  void write(BinaryWriter writer, Playlist obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.trackIds)
      ..writeByte(4)
      ..write(obj.dateCreated)
      ..writeByte(5)
      ..write(obj.dateModified)
      ..writeByte(6)
      ..write(obj.coverArtPath)
      ..writeByte(7)
      ..write(obj.isSmartPlaylist)
      ..writeByte(8)
      ..write(obj.smartType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SmartPlaylistTypeAdapter extends TypeAdapter<SmartPlaylistType> {
  @override
  final int typeId = 2;

  @override
  SmartPlaylistType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SmartPlaylistType.recentlyPlayed;
      case 1:
        return SmartPlaylistType.mostPlayed;
      case 2:
        return SmartPlaylistType.recentlyAdded;
      case 3:
        return SmartPlaylistType.favorites;
      default:
        return SmartPlaylistType.recentlyPlayed;
    }
  }

  @override
  void write(BinaryWriter writer, SmartPlaylistType obj) {
    switch (obj) {
      case SmartPlaylistType.recentlyPlayed:
        writer.writeByte(0);
        break;
      case SmartPlaylistType.mostPlayed:
        writer.writeByte(1);
        break;
      case SmartPlaylistType.recentlyAdded:
        writer.writeByte(2);
        break;
      case SmartPlaylistType.favorites:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartPlaylistTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
