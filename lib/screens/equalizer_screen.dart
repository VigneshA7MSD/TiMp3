import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../providers/audio_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_background.dart';
import '../widgets/equalizer_controls.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final databaseService = context.read<DatabaseService>();
    _settings = databaseService.getSettings();
    setState(() {});
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final databaseService = context.read<DatabaseService>();
    await databaseService.saveSettings(settings);
    final audioProvider = context.read<AudioProvider>();
    await audioProvider.applyEqualizerPreset(settings.equalizerPreset);
    await audioProvider.setEqualizerBands(settings.customEqualizerBands);
    await audioProvider.setPitch(settings.pitch);
    await audioProvider.setSpeed(settings.tempo);
    setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Equalizer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reset audio effects',
              onPressed: _resetAudioEffects,
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset audio effects',
            onPressed: _resetAudioEffects,
          ),
        ],
      ),
      body: AppBackground(
        content: AbsorbPointer(
          absorbing: kIsWeb || !Platform.isAndroid,
          child: Opacity(
            opacity: (!kIsWeb && Platform.isAndroid) ? 1.0 : 0.6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kIsWeb || !Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Equalizer and Pitch are available on Android only.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),

                  // Preset selector
                  const Text(
                    'Presets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: EqualizerPreset.values.map((preset) {
                      return ChoiceChip(
                        label: Text(_getPresetName(preset)),
                        selected: settings.equalizerPreset == preset,
                        onSelected: (selected) {
                          if (selected) {
                            final newSettings = settings.copyWith(
                              equalizerPreset: preset,
                              customEqualizerBands: _getPresetBands(
                                settings,
                                preset,
                              ),
                            );
                            _saveSettings(newSettings);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Equalizer bands
                  const Text(
                    'Frequency Bands',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  EqualizerControls(
                    bands: settings.customEqualizerBands,
                    onBandChanged: (index, value) {
                      final newBands = List<double>.from(
                        settings.customEqualizerBands,
                      );
                      newBands[index] = value;
                      final newSettings = settings.copyWith(
                        equalizerPreset: EqualizerPreset.custom,
                        customEqualizerBands: newBands,
                      );
                      _saveSettings(newSettings);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Additional controls
                  const Text(
                    'Audio Effects',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Pitch control
                  _buildSliderControl(
                    title: 'Pitch',
                    value: settings.pitch,
                    min: -20,
                    max: 20,
                    onChanged: (value) {
                      final newSettings = settings.copyWith(pitch: value);
                      _saveSettings(newSettings);
                    },
                  ),

                  // Tempo control
                  _buildSliderControl(
                    title: 'Tempo',
                    value: settings.tempo,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (value) {
                      final newSettings = settings.copyWith(tempo: value);
                      _saveSettings(newSettings);
                    },
                  ),

                  // Crossfade
                  _buildSliderControl(
                    title: 'Crossfade',
                    value: settings.crossfadeDuration,
                    min: 0,
                    max: 5,
                    onChanged: (value) {
                      final newSettings = settings.copyWith(
                        crossfadeDuration: value,
                      );
                      _saveSettings(newSettings);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetAudioEffects() async {
    final settings = _settings;
    if (settings == null) return;

    final resetSettings = settings.copyWith(
      equalizerPreset: EqualizerPreset.flat,
      customEqualizerBands: _getPresetBands(settings, EqualizerPreset.flat),
      pitch: 0.0,
      tempo: 1.0,
      crossfadeDuration: 0.0,
    );

    await _saveSettings(resetSettings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio effects reset to default')),
    );
  }

  Widget _buildSliderControl({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(title), Text(value.toStringAsFixed(1))],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getPresetName(EqualizerPreset preset) {
    switch (preset) {
      case EqualizerPreset.flat:
        return 'Flat';
      case EqualizerPreset.bassBoost:
        return 'Bass Boost';
      case EqualizerPreset.rock:
        return 'Rock';
      case EqualizerPreset.jazz:
        return 'Jazz';
      case EqualizerPreset.pop:
        return 'Pop';
      case EqualizerPreset.classical:
        return 'Classical';
      case EqualizerPreset.custom:
        return 'Custom';
    }
  }

  List<double> _getPresetBands(AppSettings settings, EqualizerPreset preset) {
    switch (preset) {
      case EqualizerPreset.flat:
        return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      case EqualizerPreset.bassBoost:
        return [6, 4, 2, 0, -2, -2, 0, 2, 4, 6];
      case EqualizerPreset.rock:
        return [4, 2, -2, -4, -2, 2, 4, 6, 6, 6];
      case EqualizerPreset.jazz:
        return [4, 3, 1, 2, -2, -2, 0, 2, 3, 4];
      case EqualizerPreset.pop:
        return [-2, 0, 2, 4, 4, 2, 0, -2, -2, 0];
      case EqualizerPreset.classical:
        return [4, 3, 2, 1, -1, -1, 0, 2, 3, 4];
      case EqualizerPreset.custom:
        return settings.customEqualizerBands;
    }
  }
}
