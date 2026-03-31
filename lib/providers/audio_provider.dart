import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../models/settings.dart' as app_settings;
import '../services/audio_service.dart';
import '../services/database_service.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayerService _audioService;
  final DatabaseService _databaseService;

  Track? _currentTrack;
  List<Track> _queue = [];
  PlaybackState _playbackState = PlaybackState(
    playing: false,
    processingState: ProcessingState.idle,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
    speed: 1.0,
    queueIndex: -1,
    shuffleMode: false,
    repeatMode: LoopMode.off,
  );
  Duration _position = Duration.zero;
  Duration _lastPositionNotified = Duration.zero;
  static const Duration _positionNotifyStep = Duration(milliseconds: 220);

  StreamSubscription<Track?>? _currentTrackSubscription;
  StreamSubscription<List<Track>>? _queueSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  final StreamController<List<Track>> _queueController =
      StreamController<List<Track>>.broadcast();

  Timer? _sleepTimer;

  AudioProvider(this._audioService, this._databaseService) {
    _init();
  }

  void _init() {
    _currentTrackSubscription = _audioService.currentTrackStream.listen((
      track,
    ) {
      final previousTrack = _currentTrack;
      _currentTrack = track;
      if (!_sameTrackPresentation(previousTrack, track)) {
        notifyListeners();
      }
    });

    _queueSubscription = _audioService.queueStream.listen((queue) {
      if (_sameQueue(_queue, queue)) return;
      _queue = queue;
      notifyListeners();
    });

    _playbackStateSubscription = _audioService.playbackStateStream.listen((
      state,
    ) {
      final previous = _playbackState;
      _playbackState = state;
      if (_shouldNotifyPlaybackState(previous, state)) {
        notifyListeners();
      }
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      _position = position;
      final deltaMs =
          (position - _lastPositionNotified).inMilliseconds.abs();
      if (deltaMs >= _positionNotifyStep.inMilliseconds ||
          position == Duration.zero) {
        _lastPositionNotified = position;
        notifyListeners();
      }
    });

    _queueController.stream.listen((queue) {
      if (_sameQueue(_queue, queue)) return;
      _queue = queue;
      notifyListeners();
    });

    unawaited(_applySavedSettings());
  }

  Future<void> _applySavedSettings() async {
    final settings = _databaseService.getSettings();
    _audioService.setShuffleEnabled(settings.shuffleEnabled);

    switch (settings.repeatMode) {
      case app_settings.RepeatMode.off:
        _audioService.setRepeatMode(LoopMode.off);
        break;
      case app_settings.RepeatMode.one:
        _audioService.setRepeatMode(LoopMode.one);
        break;
      case app_settings.RepeatMode.all:
        _audioService.setRepeatMode(LoopMode.all);
        break;
    }

    await _audioService.setVolume(settings.volume);
    await _audioService.setPitch(settings.pitch);
    await _audioService.setSpeed(settings.tempo);
    await _audioService.applyEqualizerPreset(settings.equalizerPreset);
    await _audioService.setEqualizerBands(settings.customEqualizerBands);

    if (settings.sleepTimerEnabled && settings.sleepTimerDuration != null) {
      await startSleepTimer(settings.sleepTimerDuration!);
    }
  }

  // Getters
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  PlaybackState get playbackState => _playbackState;
  Duration get position => _position;
  Duration get duration => _audioService.duration;
  bool get isPlaying => _playbackState.playing;
  bool get isBuffering =>
      _playbackState.processingState == ProcessingState.buffering;

  // Queue management
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    await _audioService.setQueue(tracks, startIndex: startIndex);
  }

  Future<void> addToQueue(Track track) async {
    await _audioService.addToQueue(track);
  }

  Future<void> playNext(Track track) async {
    if (_queue.isEmpty) {
      await setQueue([track], startIndex: 0);
      await play();
      return;
    }

    final wasPlaying = isPlaying;
    final currentIndex = _playbackState.queueIndex >= 0
        ? _playbackState.queueIndex
        : 0;
    final newQueue = List<Track>.from(_queue);
    final insertAt = (currentIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertAt, track);

    await setQueue(newQueue, startIndex: currentIndex);
    if (wasPlaying) {
      await play();
    }
  }

  Future<void> addMultipleToQueue(List<Track> tracks) async {
    await _audioService.addMultipleToQueue(tracks);
  }

  Future<void> removeFromQueue(int index) async {
    await _audioService.removeFromQueue(index);
  }

  Future<void> clearQueue() async {
    await _audioService.clearQueue();
  }

  // Queue reordering
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);

    // Update current index if necessary
    if (oldIndex == _audioService.currentIndex) {
      // Note: currentIndex is read-only, so we can't modify it directly
      // This logic needs to be handled differently, perhaps by re-setting the queue
    } else if (oldIndex < _audioService.currentIndex &&
        newIndex >= _audioService.currentIndex) {
      // Adjust for removed item before current
    } else if (oldIndex > _audioService.currentIndex &&
        newIndex <= _audioService.currentIndex) {
      // Adjust for inserted item before current
    }

    // Re-set the queue with the new order
    final newQueue = List<Track>.from(_queue);
    await setQueue(newQueue, startIndex: _audioService.currentIndex);
    _queueController.add(_queue);
    notifyListeners();
  }

  // Playback controls
  Future<void> play() async {
    await _audioService.play();
  }

  Future<void> pause() async {
    await _audioService.pause();
  }

  Future<void> stop() async {
    await _audioService.stop();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> skipToNext() async {
    await _audioService.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _audioService.skipToPrevious();
  }

  Future<void> skipToIndex(int index) async {
    await _audioService.skipToIndex(index);
  }

  // Settings
  Future<void> setShuffleEnabled(bool enabled) async {
    _audioService.setShuffleEnabled(enabled);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(
      settings.copyWith(shuffleEnabled: enabled),
    );
    notifyListeners();
  }

  Future<void> setRepeatMode(LoopMode mode) async {
    _audioService.setRepeatMode(mode);
    final settings = _databaseService.getSettings();
    app_settings.RepeatMode settingsMode;
    switch (mode) {
      case LoopMode.off:
        settingsMode = app_settings.RepeatMode.off;
        break;
      case LoopMode.one:
        settingsMode = app_settings.RepeatMode.one;
        break;
      case LoopMode.all:
        settingsMode = app_settings.RepeatMode.all;
        break;
    }
    await _databaseService.saveSettings(
      settings.copyWith(repeatMode: settingsMode),
    );
    notifyListeners();
  }

  Future<void> applyEqualizerPreset(app_settings.EqualizerPreset preset) async {
    await _audioService.applyEqualizerPreset(preset);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(
      settings.copyWith(equalizerPreset: preset),
    );
    notifyListeners();
  }

  Future<void> setEqualizerBands(List<double> bands) async {
    await _audioService.setEqualizerBands(bands);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(
      settings.copyWith(customEqualizerBands: bands),
    );
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(settings.copyWith(volume: volume));
  }

  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(settings.copyWith(tempo: speed));
  }

  Future<void> setPitch(double pitch) async {
    await _audioService.setPitch(pitch);
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(settings.copyWith(pitch: pitch));
  }

  Future<void> setLockscreenControlsEnabled(bool enabled) async {
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(
      settings.copyWith(lockscreenControlsEnabled: enabled),
    );
    await _audioService.refreshCurrentTrackSource();
    notifyListeners();
  }

  Future<void> updateTrackMetadata(Track updatedTrack) async {
    await _databaseService.saveTrack(updatedTrack);
    await _audioService.updateTrackInQueue(updatedTrack);
    notifyListeners();
  }

  // Sleep timer
  Future<void> startSleepTimer(Duration duration) async {
    cancelSleepTimer();
    _sleepTimer = Timer(duration, () async {
      await pause();
      final settings = _databaseService.getSettings();
      await _databaseService.saveSettings(
        settings.copyWith(sleepTimerEnabled: false),
      );
      notifyListeners();
    });
    final settings = _databaseService.getSettings();
    await _databaseService.saveSettings(
      settings.copyWith(sleepTimerEnabled: true, sleepTimerDuration: duration),
    );
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;

  @override
  void dispose() {
    _currentTrackSubscription?.cancel();
    _queueSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _positionSubscription?.cancel();
    cancelSleepTimer();
    _audioService.dispose();
    super.dispose();
  }

  bool _shouldNotifyPlaybackState(PlaybackState previous, PlaybackState next) {
    return previous.playing != next.playing ||
        previous.processingState != next.processingState ||
        previous.speed != next.speed ||
        previous.queueIndex != next.queueIndex ||
        previous.shuffleMode != next.shuffleMode ||
        previous.repeatMode != next.repeatMode;
  }

  bool _sameQueue(List<Track> a, List<Track> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameTrackPresentation(a[i], b[i])) return false;
    }
    return true;
  }

  bool _sameTrackPresentation(Track? a, Track? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.title == b.title &&
        a.artist == b.artist &&
        a.album == b.album &&
        a.path == b.path &&
        a.albumArtPath == b.albumArtPath;
  }
}
