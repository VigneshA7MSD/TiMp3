import 'package:hive/hive.dart';

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 8;

  @override
  Duration read(BinaryReader reader) {
    final inMicroseconds = reader.readInt();
    return Duration(microseconds: inMicroseconds);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}
