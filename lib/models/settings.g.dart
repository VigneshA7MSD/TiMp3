// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 4;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      shuffleEnabled: fields[0] as bool,
      repeatMode: fields[1] as RepeatMode,
      volume: fields[2] as double,
      equalizerPreset: fields[3] as EqualizerPreset,
      customEqualizerBands: (fields[4] as List).cast<double>(),
      pitch: fields[5] as double,
      tempo: fields[6] as double,
      crossfadeDuration: fields[7] as double,
      sleepTimerEnabled: fields[8] as bool,
      sleepTimerDuration: fields[9] as Duration?,
      themeMode: fields[10] as ThemeMode,
      dynamicThemeEnabled: fields[11] as bool,
      hapticsEnabled: fields[12] as bool,
      backgroundPlaybackEnabled: fields[13] as bool,
      lockscreenControlsEnabled: fields[14] as bool,
      backgroundImagePath: fields[15] as String?,
      nowPlayingStyle:
          (fields[16] as NowPlayingStyle?) ?? NowPlayingStyle.neonWave,
      libraryViewIsGrid: (fields[17] as bool?) ?? false,
      libraryTabIndex: (fields[18] as int?) ?? 0,
      backgroundImageOpacity: (fields[19] as double?) ?? 0.65,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.shuffleEnabled)
      ..writeByte(1)
      ..write(obj.repeatMode)
      ..writeByte(2)
      ..write(obj.volume)
      ..writeByte(3)
      ..write(obj.equalizerPreset)
      ..writeByte(4)
      ..write(obj.customEqualizerBands)
      ..writeByte(5)
      ..write(obj.pitch)
      ..writeByte(6)
      ..write(obj.tempo)
      ..writeByte(7)
      ..write(obj.crossfadeDuration)
      ..writeByte(8)
      ..write(obj.sleepTimerEnabled)
      ..writeByte(9)
      ..write(obj.sleepTimerDuration)
      ..writeByte(10)
      ..write(obj.themeMode)
      ..writeByte(11)
      ..write(obj.dynamicThemeEnabled)
      ..writeByte(12)
      ..write(obj.hapticsEnabled)
      ..writeByte(13)
      ..write(obj.backgroundPlaybackEnabled)
      ..writeByte(14)
      ..write(obj.lockscreenControlsEnabled)
      ..writeByte(15)
      ..write(obj.backgroundImagePath)
      ..writeByte(16)
      ..write(obj.nowPlayingStyle)
      ..writeByte(17)
      ..write(obj.libraryViewIsGrid)
      ..writeByte(18)
      ..write(obj.libraryTabIndex)
      ..writeByte(19)
      ..write(obj.backgroundImageOpacity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepeatModeAdapter extends TypeAdapter<RepeatMode> {
  @override
  final int typeId = 5;

  @override
  RepeatMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatMode.off;
      case 1:
        return RepeatMode.all;
      case 2:
        return RepeatMode.one;
      default:
        return RepeatMode.off;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatMode obj) {
    switch (obj) {
      case RepeatMode.off:
        writer.writeByte(0);
        break;
      case RepeatMode.all:
        writer.writeByte(1);
        break;
      case RepeatMode.one:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EqualizerPresetAdapter extends TypeAdapter<EqualizerPreset> {
  @override
  final int typeId = 6;

  @override
  EqualizerPreset read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EqualizerPreset.flat;
      case 1:
        return EqualizerPreset.bassBoost;
      case 2:
        return EqualizerPreset.rock;
      case 3:
        return EqualizerPreset.jazz;
      case 4:
        return EqualizerPreset.pop;
      case 5:
        return EqualizerPreset.classical;
      case 6:
        return EqualizerPreset.custom;
      default:
        return EqualizerPreset.flat;
    }
  }

  @override
  void write(BinaryWriter writer, EqualizerPreset obj) {
    switch (obj) {
      case EqualizerPreset.flat:
        writer.writeByte(0);
        break;
      case EqualizerPreset.bassBoost:
        writer.writeByte(1);
        break;
      case EqualizerPreset.rock:
        writer.writeByte(2);
        break;
      case EqualizerPreset.jazz:
        writer.writeByte(3);
        break;
      case EqualizerPreset.pop:
        writer.writeByte(4);
        break;
      case EqualizerPreset.classical:
        writer.writeByte(5);
        break;
      case EqualizerPreset.custom:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqualizerPresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThemeModeAdapter extends TypeAdapter<ThemeMode> {
  @override
  final int typeId = 7;

  @override
  ThemeMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThemeMode.system;
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  void write(BinaryWriter writer, ThemeMode obj) {
    switch (obj) {
      case ThemeMode.system:
        writer.writeByte(0);
        break;
      case ThemeMode.light:
        writer.writeByte(1);
        break;
      case ThemeMode.dark:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NowPlayingStyleAdapter extends TypeAdapter<NowPlayingStyle> {
  @override
  final int typeId = 9;

  @override
  NowPlayingStyle read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NowPlayingStyle.neonWave;
      case 1:
        return NowPlayingStyle.pulseRings;
      case 2:
        return NowPlayingStyle.orbitDots;
      case 3:
        return NowPlayingStyle.radialBars;
      case 4:
        return NowPlayingStyle.heartSnakeRing;
      default:
        return NowPlayingStyle.neonWave;
    }
  }

  @override
  void write(BinaryWriter writer, NowPlayingStyle obj) {
    switch (obj) {
      case NowPlayingStyle.neonWave:
        writer.writeByte(0);
        break;
      case NowPlayingStyle.pulseRings:
        writer.writeByte(1);
        break;
      case NowPlayingStyle.orbitDots:
        writer.writeByte(2);
        break;
      case NowPlayingStyle.radialBars:
        writer.writeByte(3);
        break;
      case NowPlayingStyle.heartSnakeRing:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NowPlayingStyleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
