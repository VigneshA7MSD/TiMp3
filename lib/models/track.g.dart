// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final int typeId = 0;

  @override
  Track read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Track(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      path: fields[4] as String,
      duration: fields[5] as Duration,
      size: fields[6] as int,
      dateAdded: fields[7] as DateTime,
      dateModified: fields[8] as DateTime?,
      playCount: fields[9] as int,
      lastPlayed: fields[10] as DateTime?,
      albumArtPath: fields[11] as String?,
      genre: fields[12] as String?,
      year: fields[13] as int?,
      trackNumber: fields[14] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.path)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.size)
      ..writeByte(7)
      ..write(obj.dateAdded)
      ..writeByte(8)
      ..write(obj.dateModified)
      ..writeByte(9)
      ..write(obj.playCount)
      ..writeByte(10)
      ..write(obj.lastPlayed)
      ..writeByte(11)
      ..write(obj.albumArtPath)
      ..writeByte(12)
      ..write(obj.genre)
      ..writeByte(13)
      ..write(obj.year)
      ..writeByte(14)
      ..write(obj.trackNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
