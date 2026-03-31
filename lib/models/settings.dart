import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 4)
class AppSettings extends HiveObject {
  static const Object _noChange = Object();
  @HiveField(0)
  final bool shuffleEnabled;

  @HiveField(1)
  final RepeatMode repeatMode;

  @HiveField(2)
  final double volume;

  @HiveField(3)
  final EqualizerPreset equalizerPreset;

  @HiveField(4)
  final List<double> customEqualizerBands;

  @HiveField(5)
  final double pitch; // -20 to +20

  @HiveField(6)
  final double tempo; // 0.5 to 2.0

  @HiveField(7)
  final double crossfadeDuration; // 0-5 seconds

  @HiveField(8)
  final bool sleepTimerEnabled;

  @HiveField(9)
  final Duration? sleepTimerDuration;

  @HiveField(10)
  final ThemeMode themeMode;

  @HiveField(11)
  final bool dynamicThemeEnabled;

  @HiveField(12)
  final bool hapticsEnabled;

  @HiveField(13)
  final bool backgroundPlaybackEnabled;

  @HiveField(14)
  final bool lockscreenControlsEnabled;

  @HiveField(15)
  final String? backgroundImagePath;

  @HiveField(16)
  final NowPlayingStyle nowPlayingStyle;

  @HiveField(17)
  final bool libraryViewIsGrid;

  @HiveField(18)
  final int libraryTabIndex;

  @HiveField(19)
  final double backgroundImageOpacity;

  AppSettings({
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.volume = 1.0,
    this.equalizerPreset = EqualizerPreset.flat,
    this.customEqualizerBands = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.pitch = 0.0,
    this.tempo = 1.0,
    this.crossfadeDuration = 0.0,
    this.sleepTimerEnabled = false,
    this.sleepTimerDuration,
    this.themeMode = ThemeMode.system,
    this.dynamicThemeEnabled = true,
    this.hapticsEnabled = true,
    this.backgroundPlaybackEnabled = true,
    this.lockscreenControlsEnabled = true,
    this.backgroundImagePath,
    this.nowPlayingStyle = NowPlayingStyle.neonWave,
    this.libraryViewIsGrid = false,
    this.libraryTabIndex = 0,
    this.backgroundImageOpacity = 0.65,
  });

  AppSettings copyWith({
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    double? volume,
    EqualizerPreset? equalizerPreset,
    List<double>? customEqualizerBands,
    double? pitch,
    double? tempo,
    double? crossfadeDuration,
    bool? sleepTimerEnabled,
    Object? sleepTimerDuration = _noChange,
    ThemeMode? themeMode,
    bool? dynamicThemeEnabled,
    bool? hapticsEnabled,
    bool? backgroundPlaybackEnabled,
    bool? lockscreenControlsEnabled,
    Object? backgroundImagePath = _noChange,
    NowPlayingStyle? nowPlayingStyle,
    bool? libraryViewIsGrid,
    int? libraryTabIndex,
    double? backgroundImageOpacity,
  }) {
    return AppSettings(
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      customEqualizerBands: customEqualizerBands ?? this.customEqualizerBands,
      pitch: pitch ?? this.pitch,
      tempo: tempo ?? this.tempo,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      sleepTimerEnabled: sleepTimerEnabled ?? this.sleepTimerEnabled,
      sleepTimerDuration: identical(sleepTimerDuration, _noChange)
          ? this.sleepTimerDuration
          : sleepTimerDuration as Duration?,
      themeMode: themeMode ?? this.themeMode,
      dynamicThemeEnabled: dynamicThemeEnabled ?? this.dynamicThemeEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      backgroundPlaybackEnabled:
          backgroundPlaybackEnabled ?? this.backgroundPlaybackEnabled,
      lockscreenControlsEnabled:
          lockscreenControlsEnabled ?? this.lockscreenControlsEnabled,
      backgroundImagePath: identical(backgroundImagePath, _noChange)
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      nowPlayingStyle: nowPlayingStyle ?? this.nowPlayingStyle,
      libraryViewIsGrid: libraryViewIsGrid ?? this.libraryViewIsGrid,
      libraryTabIndex: libraryTabIndex ?? this.libraryTabIndex,
      backgroundImageOpacity:
          backgroundImageOpacity ?? this.backgroundImageOpacity,
    );
  }
}

@HiveType(typeId: 5)
enum RepeatMode {
  @HiveField(0)
  off,

  @HiveField(1)
  all,

  @HiveField(2)
  one,
}

@HiveType(typeId: 6)
enum EqualizerPreset {
  @HiveField(0)
  flat,

  @HiveField(1)
  bassBoost,

  @HiveField(2)
  rock,

  @HiveField(3)
  jazz,

  @HiveField(4)
  pop,

  @HiveField(5)
  classical,

  @HiveField(6)
  custom,
}

@HiveType(typeId: 7)
enum ThemeMode {
  @HiveField(0)
  system,

  @HiveField(1)
  light,

  @HiveField(2)
  dark,
}

@HiveType(typeId: 9)
enum NowPlayingStyle {
  @HiveField(0)
  neonWave,

  @HiveField(1)
  pulseRings,

  @HiveField(2)
  orbitDots,

  @HiveField(3)
  radialBars,

  @HiveField(4)
  heartSnakeRing,
}
