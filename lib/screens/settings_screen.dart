import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_scanner_service.dart';
import '../models/settings.dart' as app_settings;
import '../providers/audio_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  app_settings.AppSettings? _settings;
  Timer? _headerFadeTimer;
  bool _headerActive = false;

  @override
  void initState() {
    super.initState();
    // Settings are loaded in didChangeDependencies to safely access context.
  }

  @override
  void dispose() {
    _headerFadeTimer?.cancel();
    super.dispose();
  }

  void _bumpHeader() {
    if (!mounted) return;
    if (!_headerActive) {
      setState(() => _headerActive = true);
    }
    _headerFadeTimer?.cancel();
    _headerFadeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _headerActive = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings == null) {
      _loadSettings();
    }
  }

  void _loadSettings() {
    final databaseService = context.read<DatabaseService>();
    setState(() {
      _settings = databaseService.getSettings();
    });
  }

  Future<void> _saveSettings(app_settings.AppSettings settings) async {
    final databaseService = context.read<DatabaseService>();
    await databaseService.saveSettings(settings);
    setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 8,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 8,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: AppBackground(
        content: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification ||
                notification is ScrollUpdateNotification ||
                notification is OverscrollNotification) {
              _bumpHeader();
            }
            return false;
          },
          child: ListView(
            children: [
            // Playback settings
            _buildSectionHeader('Playback'),
            SwitchListTile(
              title: const Text('Shuffle'),
              subtitle: const Text('Play tracks in random order'),
              value: _settings!.shuffleEnabled,
              onChanged: (value) async {
                setState(() {
                  _settings = _settings!.copyWith(shuffleEnabled: value);
                });
                await context.read<AudioProvider>().setShuffleEnabled(value);
              },
            ),
            ListTile(
              title: const Text('Repeat Mode'),
              subtitle: Text(_getRepeatModeText(_settings!.repeatMode)),
              onTap: () => _showRepeatModeDialog(),
            ),

            // Audio settings
            _buildSectionHeader('Audio'),
            ListTile(
              title: const Text('Volume'),
              subtitle: Slider(
                value: _settings!.volume,
                onChanged: (value) async {
                  setState(() {
                    _settings = _settings!.copyWith(volume: value);
                  });
                  await context.read<AudioProvider>().setVolume(value);
                },
              ),
            ),
            ListTile(
              title: const Text('Equalizer'),
              subtitle: const Text('Adjust audio frequencies'),
              trailing: const Icon(Icons.equalizer),
              onTap: () => Navigator.pushNamed(context, '/equalizer'),
            ),
            ListTile(
              title: const Text('Equalizer Presets'),
              subtitle: Text(
                _getEqualizerPresetText(_settings!.equalizerPreset),
              ),
              onTap: () => _showEqualizerPresetDialog(),
            ),

            // Appearance settings
            _buildSectionHeader('Appearance'),
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(_getThemeModeText(_settings!.themeMode)),
              onTap: () => _showThemeModeDialog(),
            ),
            ListTile(
              title: const Text('Now Playing Style'),
              subtitle: Text(
                _getNowPlayingStyleText(_settings!.nowPlayingStyle),
              ),
              onTap: () => _showNowPlayingStyleDialog(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: _StylePreviewStrip(
                selected: _settings!.nowPlayingStyle,
                labelOfStyle: _getNowPlayingStyleText,
                onSelected: (style) {
                  final newSettings = _settings!.copyWith(
                    nowPlayingStyle: style,
                  );
                  _saveSettings(newSettings);
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Custom Background'),
              subtitle: Text(
                _settings!.backgroundImagePath != null
                    ? 'Image set'
                    : 'No image selected',
              ),
              value: _settings!.backgroundImagePath != null,
              onChanged: (value) {
                if (!value) {
                  final newSettings = _settings!.copyWith(
                    backgroundImagePath: null,
                  );
                  _saveSettings(newSettings);
                } else {
                  _showBackgroundImageDialog();
                }
              },
            ),
            if (_settings!.backgroundImagePath != null)
              ListTile(
                title: const Text('Change Background Image'),
                subtitle: Text(_settings!.backgroundImagePath!),
                onTap: () => _showBackgroundImageDialog(),
                trailing: const Icon(Icons.image),
              ),
            if (_settings!.backgroundImagePath != null)
              ListTile(
                title: const Text('Background Image Opacity'),
                subtitle: Slider(
                  value: _settings!.backgroundImageOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  label: '${(_settings!.backgroundImageOpacity * 100).round()}%',
                  onChanged: (value) {
                    final newSettings = _settings!.copyWith(
                      backgroundImageOpacity: value,
                    );
                    _saveSettings(newSettings);
                  },
                ),
              ),
            SwitchListTile(
              title: const Text('Dynamic Theme'),
              subtitle: const Text('Use album art colors for theme'),
              value: _settings!.dynamicThemeEnabled,
              onChanged: (value) {
                final newSettings = _settings!.copyWith(
                  dynamicThemeEnabled: value,
                );
                _saveSettings(newSettings);
              },
            ),

            // Behavior settings
            _buildSectionHeader('Behavior'),
            SwitchListTile(
              title: const Text('Haptic Feedback'),
              subtitle: const Text('Vibrate on button presses'),
              value: _settings!.hapticsEnabled,
              onChanged: (value) {
                final newSettings = _settings!.copyWith(hapticsEnabled: value);
                _saveSettings(newSettings);
              },
            ),
            SwitchListTile(
              title: const Text('Background Playback'),
              subtitle: const Text('Continue playing when app is closed'),
              value: _settings!.backgroundPlaybackEnabled,
              onChanged: (value) {
                final newSettings = _settings!.copyWith(
                  backgroundPlaybackEnabled: value,
                );
                _saveSettings(newSettings);
              },
            ),
            SwitchListTile(
              title: const Text('Lockscreen Controls'),
              subtitle: const Text('Show playback controls on lockscreen'),
              value: _settings!.lockscreenControlsEnabled,
              onChanged: (value) async {
                setState(() {
                  _settings = _settings!.copyWith(
                    lockscreenControlsEnabled: value,
                  );
                });
                await context.read<AudioProvider>().setLockscreenControlsEnabled(
                  value,
                );
              },
            ),

            // Sleep timer
            _buildSectionHeader('Sleep Timer'),
            SwitchListTile(
              title: const Text('Sleep Timer'),
              subtitle: _settings!.sleepTimerEnabled
                  ? Text(
                      'Will stop playback in ${_settings!.sleepTimerDuration?.inMinutes ?? 0} minutes',
                    )
                  : const Text('Automatically stop playback after a set time'),
              value: _settings!.sleepTimerEnabled,
              onChanged: (value) async {
                final duration =
                    _settings!.sleepTimerDuration ?? const Duration(minutes: 30);
                if (value) {
                  await context.read<AudioProvider>().startSleepTimer(duration);
                } else {
                  context.read<AudioProvider>().cancelSleepTimer();
                  final settings = context.read<DatabaseService>().getSettings();
                  await context.read<DatabaseService>().saveSettings(
                    settings.copyWith(sleepTimerEnabled: false),
                  );
                }
                setState(() {
                  _settings = _settings!.copyWith(sleepTimerEnabled: value);
                });
              },
            ),
            if (_settings!.sleepTimerEnabled)
              ListTile(
                title: const Text('Timer Duration'),
                subtitle: Text(
                  '${_settings!.sleepTimerDuration?.inMinutes ?? 30} minutes',
                ),
                onTap: () => _showSleepTimerDialog(),
              ),

            // Data management
            _buildSectionHeader('Data'),
            ListTile(
              title: const Text('Rescan Storage'),
              subtitle: const Text('Scan device for new music files'),
              trailing: const Icon(Icons.refresh),
              onTap: () async {
                // Trigger rescan
                final fileScanner = context.read<FileScannerService>();
                final databaseService = context.read<DatabaseService>();
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final scannedTracks = await fileScanner.scanForMusicFiles();
                  await databaseService.saveTracks(scannedTracks);

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Found ${scannedTracks.length} tracks'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error scanning: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text('Clear All Data'),
              subtitle: const Text(
                'Remove all tracks, playlists, and settings',
              ),
              onTap: () => _showClearDataDialog(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text(
                  'Developed by vicky_adv7',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getRepeatModeText(app_settings.RepeatMode mode) {
    switch (mode) {
      case app_settings.RepeatMode.off:
        return 'Off';
      case app_settings.RepeatMode.all:
        return 'All';
      case app_settings.RepeatMode.one:
        return 'One';
    }
  }

  String _getThemeModeText(app_settings.ThemeMode mode) {
    switch (mode) {
      case app_settings.ThemeMode.system:
        return 'System';
      case app_settings.ThemeMode.light:
        return 'Light';
      case app_settings.ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getEqualizerPresetText(app_settings.EqualizerPreset preset) {
    switch (preset) {
      case app_settings.EqualizerPreset.flat:
        return 'Flat';
      case app_settings.EqualizerPreset.rock:
        return 'Rock';
      case app_settings.EqualizerPreset.pop:
        return 'Pop';
      case app_settings.EqualizerPreset.jazz:
        return 'Jazz';
      case app_settings.EqualizerPreset.bassBoost:
        return 'Bass Boost';
      case app_settings.EqualizerPreset.classical:
        return 'Classical';
      case app_settings.EqualizerPreset.custom:
        return 'Custom';
    }
  }

  String _getNowPlayingStyleText(app_settings.NowPlayingStyle style) {
    switch (style) {
      case app_settings.NowPlayingStyle.neonWave:
        return 'Neon Wave';
      case app_settings.NowPlayingStyle.pulseRings:
        return 'Pulse Rings';
      case app_settings.NowPlayingStyle.orbitDots:
        return 'Orbit Dots';
      case app_settings.NowPlayingStyle.radialBars:
        return 'Radial Bars';
      case app_settings.NowPlayingStyle.heartSnakeRing:
        return 'Heart Snake Ring';
    }
  }

  void _showRepeatModeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Repeat Mode'),
        children: app_settings.RepeatMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _settings = _settings!.copyWith(repeatMode: mode);
              });
              context.read<AudioProvider>().setRepeatMode(
                _loopModeFromSetting(mode),
              );
              Navigator.of(context).pop();
            },
            child: Text(_getRepeatModeText(mode)),
          );
        }).toList(),
      ),
    );
  }

  void _showThemeModeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: app_settings.ThemeMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              final newSettings = _settings!.copyWith(themeMode: mode);
              _saveSettings(newSettings);
              Navigator.of(context).pop();
            },
            child: Text(_getThemeModeText(mode)),
          );
        }).toList(),
      ),
    );
  }

  void _showNowPlayingStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Now Playing Style'),
        children: app_settings.NowPlayingStyle.values.map((style) {
          return SimpleDialogOption(
            onPressed: () {
              final newSettings = _settings!.copyWith(nowPlayingStyle: style);
              _saveSettings(newSettings);
              Navigator.of(context).pop();
            },
            child: Text(_getNowPlayingStyleText(style)),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Background',
            lockAspectRatio: false,
            hideBottomControls: false,
            toolbarWidgetColor: Colors.white,
            toolbarColor: const Color(0xFF2B1530),
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
          ),
          IOSUiSettings(
            title: 'Crop Background',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );
    } catch (_) {
      cropped = null;
    }

    final resolvedPath = cropped?.path ?? image.path;
    final newSettings = _settings!.copyWith(
      backgroundImagePath: resolvedPath,
      backgroundImageOpacity: _settings!.backgroundImageOpacity,
    );
    await _saveSettings(newSettings);
  }

  void _showBackgroundImageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Background Image'),
        content: const Text(
          'Select an image from your gallery. You can crop it before applying.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _pickBackgroundImage();
            },
            child: const Text('Select Image'),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog() {
    final durations = [15, 30, 45, 60, 90, 120]; // minutes

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sleep Timer'),
        children: durations.map((minutes) {
          return SimpleDialogOption(
            onPressed: () {
              final duration = Duration(minutes: minutes);
              setState(() {
                _settings = _settings!.copyWith(sleepTimerDuration: duration);
              });
              if (_settings!.sleepTimerEnabled) {
                context.read<AudioProvider>().startSleepTimer(duration);
              } else {
                _saveSettings(_settings!);
              }
              Navigator.of(context).pop();
            },
            child: Text('$minutes minutes'),
          );
        }).toList(),
      ),
    );
  }

  void _showEqualizerPresetDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Equalizer Preset'),
        children: app_settings.EqualizerPreset.values.map((preset) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _settings = _settings!.copyWith(equalizerPreset: preset);
              });
              context.read<AudioProvider>().applyEqualizerPreset(preset);
              Navigator.of(context).pop();
            },
            child: Text(_getEqualizerPresetText(preset)),
          );
        }).toList(),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all tracks, playlists, bookmarks, and settings. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final databaseService = context.read<DatabaseService>();
              await databaseService.clearAllData();
              if (!mounted) return;
              _loadSettings();
              navigator.pop();

              messenger.showSnackBar(
                const SnackBar(content: Text('All data cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  LoopMode _loopModeFromSetting(app_settings.RepeatMode mode) {
    switch (mode) {
      case app_settings.RepeatMode.off:
        return LoopMode.off;
      case app_settings.RepeatMode.all:
        return LoopMode.all;
      case app_settings.RepeatMode.one:
        return LoopMode.one;
    }
  }
}

class _StylePreviewStrip extends StatefulWidget {
  final app_settings.NowPlayingStyle selected;
  final String Function(app_settings.NowPlayingStyle) labelOfStyle;
  final ValueChanged<app_settings.NowPlayingStyle> onSelected;

  const _StylePreviewStrip({
    required this.selected,
    required this.labelOfStyle,
    required this.onSelected,
  });

  @override
  State<_StylePreviewStrip> createState() => _StylePreviewStripState();
}

class _StylePreviewStripState extends State<_StylePreviewStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styles = app_settings.NowPlayingStyle.values;
    return SizedBox(
      height: 104,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: styles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final style = styles[index];
              final selected = style == widget.selected;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onSelected(style),
                child: Container(
                  width: 116,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: selected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _NowPlayingStyleMiniPainter(
                            style: style,
                            progress: _controller.value,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.labelOfStyle(style),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NowPlayingStyleMiniPainter extends CustomPainter {
  final app_settings.NowPlayingStyle style;
  final double progress;
  final Color color;

  const _NowPlayingStyleMiniPainter({
    required this.style,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.34;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Tiny album placeholder.
    canvas.drawCircle(
      center,
      size.shortestSide * 0.22,
      Paint()..color = color.withValues(alpha: 0.18),
    );

    switch (style) {
      case app_settings.NowPlayingStyle.neonWave:
        paint
          ..strokeWidth = 1.7
          ..color = color.withValues(alpha: 0.9);
        final path = Path();
        const samples = 80;
        for (var i = 0; i <= samples; i++) {
          final t = i / samples;
          final ang = t * math.pi * 2;
          final wave = math.sin((ang * 5) + (progress * math.pi * 2)) * 0.12;
          final r = base * (1.08 + wave);
          final p = Offset(
            center.dx + math.cos(ang) * r,
            center.dy + math.sin(ang) * r,
          );
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
      case app_settings.NowPlayingStyle.pulseRings:
        for (var i = 0; i < 3; i++) {
          final t = (progress + i * 0.28) % 1.0;
          paint
            ..strokeWidth = 1.5 - (i * 0.2)
            ..color = color.withValues(alpha: (1 - t) * 0.9);
          canvas.drawCircle(center, base + (t * 8), paint);
        }
        break;
      case app_settings.NowPlayingStyle.orbitDots:
        for (var i = 0; i < 18; i++) {
          final t = i / 18;
          final angle = t * math.pi * 2 + (progress * math.pi * 2);
          final p = Offset(
            center.dx + math.cos(angle) * (base + 3),
            center.dy + math.sin(angle) * (base + 3),
          );
          canvas.drawCircle(
            p,
            1.3 + (math.sin((progress * math.pi * 2) + i) * 0.35 + 0.35),
            Paint()..color = color.withValues(alpha: 0.85),
          );
        }
        break;
      case app_settings.NowPlayingStyle.radialBars:
        for (var i = 0; i < 24; i++) {
          final t = i / 24;
          final angle = t * math.pi * 2;
          final amp = 3 +
              ((math.sin((angle * 6) + (progress * math.pi * 2)) + 1) * 2.4);
          final start = Offset(
            center.dx + math.cos(angle) * (base - 1),
            center.dy + math.sin(angle) * (base - 1),
          );
          final end = Offset(
            center.dx + math.cos(angle) * (base + amp),
            center.dy + math.sin(angle) * (base + amp),
          );
          canvas.drawLine(
            start,
            end,
            Paint()
              ..color = color.withValues(alpha: 0.92)
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round,
          );
        }
        break;
      case app_settings.NowPlayingStyle.heartSnakeRing:
        final ringRadius = base * 1.12;
        final snakeRadius = base * 1.22;
        final headAngle = -math.pi / 2 + (progress * math.pi * 2);
        final heartCenter = Offset(
          center.dx + math.cos(headAngle) * snakeRadius,
          center.dy + math.sin(headAngle) * snakeRadius,
        );

        final whiteBase = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: 0.35);
        canvas.drawCircle(center, ringRadius, whiteBase);

        final whiteArc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.95);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ringRadius),
          headAngle - 0.6,
          1.1,
          false,
          whiteArc,
        );

        final snakePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.95);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: snakeRadius),
          headAngle - 1.45,
          1.2,
          false,
          snakePaint,
        );

        final heart = Path()
          ..moveTo(heartCenter.dx, heartCenter.dy + 3.8)
          ..cubicTo(
            heartCenter.dx - 5,
            heartCenter.dy - 0.7,
            heartCenter.dx - 5,
            heartCenter.dy - 5,
            heartCenter.dx,
            heartCenter.dy - 3,
          )
          ..cubicTo(
            heartCenter.dx + 5,
            heartCenter.dy - 5,
            heartCenter.dx + 5,
            heartCenter.dy - 0.7,
            heartCenter.dx,
            heartCenter.dy + 3.8,
          )
          ..close();
        canvas.drawPath(
          heart,
          Paint()..color = color.withValues(alpha: 0.95),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NowPlayingStyleMiniPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.style != style ||
        oldDelegate.color != color;
  }
}
