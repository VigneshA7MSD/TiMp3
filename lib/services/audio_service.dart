import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../models/track.dart';
import '../models/settings.dart';
import 'database_service.dart';

class AudioPlayerService {
  late final AudioPlayer _player;
  final DatabaseService _databaseService;
  final AndroidEqualizer? _equalizer;

  final StreamController<Track?> _currentTrackController =
      StreamController<Track?>.broadcast();
  final StreamController<List<Track>> _queueController =
      StreamController<List<Track>>.broadcast();
  final StreamController<PlaybackState> _playbackStateController =
      StreamController<PlaybackState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  List<int> _shuffleIndices = [];

  int get currentIndex => _currentIndex;

  AudioPlayerService(this._databaseService)
      : _equalizer =
            (!kIsWeb && Platform.isAndroid) ? AndroidEqualizer() : null {
    _player = AudioPlayer(
      audioPipeline: _equalizer == null
          ? null
          : AudioPipeline(androidAudioEffects: [_equalizer]),
    );
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen((event) {
      _playbackStateController.add(
        PlaybackState(
          playing: _player.playing,
          processingState: event.processingState,
          position: event.updatePosition,
          bufferedPosition: event.bufferedPosition,
          speed: _player.speed,
          queueIndex: _currentIndex,
          shuffleMode: _shuffleEnabled,
          repeatMode: _player.loopMode,
        ),
      );
    });

    _player.positionStream.listen((position) {
      _positionController.add(position);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
    });
  }

  // Streams
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;
  Stream<List<Track>> get queueStream => _queueController.stream;
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;

  // Current state
  Track? get currentTrack => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  List<Track> get queue => _queue;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  // Queue management
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = List.from(tracks);
    if (_queue.isEmpty) {
      _currentIndex = -1;
      _queueController.add(_queue);
      _currentTrackController.add(null);
      await _player.stop();
      return;
    }
    _currentIndex = startIndex.clamp(0, _queue.length - 1).toInt();
    _updateShuffleIndices();
    _queueController.add(_queue);
    _currentTrackController.add(currentTrack);

    if (_queue.isNotEmpty) {
      final loaded = await _loadCurrentTrack();
      if (!loaded) {
        await _skipToNextPlayableTrack();
      }
    }
  }

  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    _updateShuffleIndices();
    _queueController.add(_queue);
  }

  Future<void> addMultipleToQueue(List<Track> tracks) async {
    _queue.addAll(tracks);
    _updateShuffleIndices();
    _queueController.add(_queue);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _queue.removeAt(index);
    _updateShuffleIndices();

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      final loaded = await _loadCurrentTrack();
      if (!loaded) {
        await _skipToNextPlayableTrack();
      }
    }

    _queueController.add(_queue);
    _currentTrackController.add(currentTrack);
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = -1;
    _shuffleIndices.clear();
    _queueController.add(_queue);
    _currentTrackController.add(null);
    await _player.stop();
  }

  // Playback controls
  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> skipToNext() async {
    await _skipToIndex(_getNextIndex());
  }

  Future<void> skipToPrevious() async {
    await _skipToIndex(_getPreviousIndex());
  }

  Future<void> skipToIndex(int index) async {
    await _skipToIndex(index);
  }

  Future<void> _skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    _currentTrackController.add(currentTrack);
    final loaded = await _loadCurrentTrack();
    if (!loaded) {
      await _skipToNextPlayableTrack();
      return;
    }
    await play();
  }

  // Shuffle and repeat
  void setShuffleEnabled(bool enabled) {
    _shuffleEnabled = enabled;
    _updateShuffleIndices();
    _playbackStateController.add(
      PlaybackState(
        playing: _player.playing,
        processingState: _player.processingState,
        position: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        shuffleMode: _shuffleEnabled,
        repeatMode: _player.loopMode,
      ),
    );
  }

  Future<void> setRepeatMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  // Audio effects
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Future<void> setPitch(double pitch) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final factor = pow(2.0, pitch / 12.0).toDouble();
    await _player.setPitch(factor);
  }

  Future<void> applyEqualizerPreset(EqualizerPreset preset) async {
    final settings = _databaseService.getSettings();
    await _applyEqualizerBands(settings.customEqualizerBands);
  }

  Future<void> setEqualizerBands(List<double> bands) async {
    await _applyEqualizerBands(bands);
  }

  Future<void> _applyEqualizerBands(List<double> bands) async {
    if (kIsWeb || !Platform.isAndroid || _equalizer == null) return;
    final params = await _equalizer.parameters;
    final min = params.minDecibels;
    final max = params.maxDecibels;
    final count = minOf(bands.length, params.bands.length);
    for (var i = 0; i < count; i++) {
      final gain = bands[i].clamp(min, max).toDouble();
      await params.bands[i].setGain(gain);
    }
    final enabled = bands.any((value) => value.abs() > 0.01);
    await _equalizer.setEnabled(enabled);
  }

  int minOf(int a, int b) => a < b ? a : b;

  // Private methods
  Future<bool> _loadCurrentTrack({bool incrementPlayCount = true}) async {
    if (currentTrack == null) return false;

    try {
      final rawPath = currentTrack!.path;
      final parsedUri = Uri.tryParse(rawPath);
      final settings = _databaseService.getSettings();
      final mediaItem = settings.lockscreenControlsEnabled
          ? _buildMediaItem(currentTrack!)
          : null;
      if (parsedUri != null && parsedUri.hasScheme) {
        await _player.setAudioSource(
          AudioSource.uri(parsedUri, tag: mediaItem),
        );
      } else {
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(rawPath), tag: mediaItem),
        );
      }
      if (incrementPlayCount) {
        await _databaseService.updateTrackPlayCount(currentTrack!.id);
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to load track: ${currentTrack?.path} | $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> refreshCurrentTrackSource() async {
    if (currentTrack == null) return;
    final wasPlaying = _player.playing;
    final position = _player.position;
    final loaded = await _loadCurrentTrack(incrementPlayCount: false);
    if (!loaded) return;
    await _player.seek(position);
    if (wasPlaying) {
      await _player.play();
    }
  }

  Future<void> updateTrackInQueue(Track updatedTrack) async {
    var changed = false;
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].id != updatedTrack.id) continue;
      _queue[i] = updatedTrack;
      changed = true;
    }
    if (!changed) return;

    _queueController.add(List<Track>.from(_queue));
    _currentTrackController.add(currentTrack);
  }

  Future<void> _skipToNextPlayableTrack() async {
    if (_queue.isEmpty) {
      await _player.stop();
      return;
    }

    final tried = <int>{_currentIndex};
    var probe = _currentIndex;

    while (tried.length < _queue.length) {
      probe = (probe + 1) % _queue.length;
      if (tried.contains(probe)) break;
      tried.add(probe);
      _currentIndex = probe;
      _currentTrackController.add(currentTrack);
      final loaded = await _loadCurrentTrack();
      if (loaded) {
        await play();
        return;
      }
    }

    await _player.stop();
  }

  MediaItem _buildMediaItem(Track track) {
    final albumId = _albumIdFromTrack(track);
    final artUri = albumId != null
        ? Uri.parse('content://media/external/audio/albumart/$albumId')
        : null;

    return MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      artUri: artUri,
    );
  }

  int? _albumIdFromTrack(Track track) {
    final raw = track.albumArtPath;
    if (raw == null || raw.isEmpty || !raw.startsWith('album_')) return null;
    return int.tryParse(raw.substring('album_'.length));
  }

  void _updateShuffleIndices() {
    if (_shuffleEnabled) {
      _shuffleIndices = List.generate(_queue.length, (i) => i);
      _shuffleIndices.shuffle();
    } else {
      _shuffleIndices = List.generate(_queue.length, (i) => i);
    }
  }

  int _getNextIndex() {
    if (_queue.isEmpty) return -1;

    if (_shuffleEnabled) {
      final currentShuffleIndex = _shuffleIndices.indexOf(_currentIndex);
      final nextShuffleIndex =
          (currentShuffleIndex + 1) % _shuffleIndices.length;
      return _shuffleIndices[nextShuffleIndex];
    } else {
      return (_currentIndex + 1) % _queue.length;
    }
  }

  int _getPreviousIndex() {
    if (_queue.isEmpty) return -1;

    if (_shuffleEnabled) {
      final currentShuffleIndex = _shuffleIndices.indexOf(_currentIndex);
      final prevShuffleIndex = currentShuffleIndex > 0
          ? currentShuffleIndex - 1
          : _shuffleIndices.length - 1;
      return _shuffleIndices[prevShuffleIndex];
    } else {
      return _currentIndex > 0 ? _currentIndex - 1 : _queue.length - 1;
    }
  }

  void _onTrackCompleted() {
    // LoopMode.one is handled automatically by just_audio for single sources.
    // We only need to manually handle advancing the queue.
    if (_player.loopMode == LoopMode.all) {
      skipToNext();
    } else if (_player.loopMode == LoopMode.off) {
      // If not repeating all, advance only if there are more tracks.
      if (_currentIndex < _queue.length - 1) {
        skipToNext();
      }
    }
  }

  void dispose() {
    _player.dispose();
    _currentTrackController.close();
    _queueController.close();
    _playbackStateController.close();
    _positionController.close();
  }
}

class PlaybackState {
  final bool playing;
  final ProcessingState processingState;
  final Duration position;
  final Duration bufferedPosition;
  final double speed;
  final int queueIndex;
  final bool shuffleMode;
  final LoopMode repeatMode;

  const PlaybackState({
    required this.playing,
    required this.processingState,
    required this.position,
    required this.bufferedPosition,
    required this.speed,
    required this.queueIndex,
    required this.shuffleMode,
    required this.repeatMode,
  });
}
