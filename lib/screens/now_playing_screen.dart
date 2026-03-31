import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/audio_provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../models/settings.dart' as app_settings;
import '../services/database_service.dart';
import '../services/lyrics_service.dart';
import '../widgets/track_artwork.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _waveController;
  bool _isDiscRotating = false;
  bool _showLyrics = false;
  double _lyricsDragOffset = 0.0;
  final LyricsService _lyricsService = LyricsService();
  String? _lyricsTrackId;
  String? _lyricsText;
  String? _lyricsError;
  bool _lyricsLoading = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        try {
          final currentTrack = audioProvider.currentTrack;
          if (currentTrack == null) {
            _syncRotation(false);
            return const Scaffold(
              body: Center(child: Text('No track playing')),
            );
          }

          final duration = audioProvider.duration;
          final hasValidDuration = duration > Duration.zero;
          final clampedPosition = hasValidDuration
              ? Duration(
                  milliseconds: audioProvider.position.inMilliseconds.clamp(
                    0,
                    duration.inMilliseconds,
                  ),
                )
              : Duration.zero;
          _syncRotation(audioProvider.isPlaying);
          final nowPlayingStyle = context
              .read<DatabaseService>()
              .getSettings()
              .nowPlayingStyle;
          if (_showLyrics &&
              !_lyricsLoading &&
              _lyricsTrackId != currentTrack.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _startLyricsLoad(currentTrack);
            });
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.equalizer),
                  onPressed: () {
                    if (kIsWeb || !Platform.isAndroid) {
                      _showAndroidOnlyMessage(context);
                      return;
                    }
                    Navigator.pushNamed(context, '/equalizer');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.queue_music),
                  onPressed: () => Navigator.pushNamed(context, '/queue'),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showTrackMenu(context, currentTrack),
                ),
              ],
            ),
            body: Stack(
              children: [
                // Background with blur effect
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Large album artwork
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.86,
                            height: MediaQuery.of(context).size.width * 0.86,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.maxWidth;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  fit: StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    ClipOval(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 4,
                                          sigmaY: 4,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: RepaintBoundary(
                                            child: ClipOval(
                                              child: TrackArtwork(
                                                track: currentTrack,
                                                size: size - 20,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      (size - 20) / 2,
                                                    ),
                                                fallbackIcon: Icons.music_note,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: RepaintBoundary(
                                        child: SizedBox(
                                          width: size * 1.24,
                                          height: size * 1.24,
                                          child: _buildStyleEffect(
                                            nowPlayingStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Song info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              currentTrack.title,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentTrack.artist,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            if (hasValidDuration)
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                  activeTrackColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  inactiveTrackColor: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: clampedPosition.inMilliseconds
                                      .toDouble(),
                                  max: duration.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    audioProvider.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );
                                  },
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: LinearProgressIndicator(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.15),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(clampedPosition),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Playback controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 36),
                            onPressed: audioProvider.skipToPrevious,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 32),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                audioProvider.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 36,
                              ),
                              onPressed: audioProvider.togglePlayPause,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 32),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 36),
                            onPressed: audioProvider.skipToNext,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Additional controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: audioProvider.playbackState.shuffleMode
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => audioProvider.setShuffleEnabled(
                              !audioProvider.playbackState.shuffleMode,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(
                              _getRepeatIcon(
                                audioProvider.playbackState.repeatMode,
                              ),
                              color:
                                  audioProvider.playbackState.repeatMode !=
                                      LoopMode.off
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => _cycleRepeatMode(audioProvider),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(
                              Icons.lyrics,
                              color: _showLyrics
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() => _showLyrics = !_showLyrics);
                              if (_showLyrics) {
                                _startLyricsLoad(currentTrack);
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Lyrics panel (slide up from bottom)
                if (_showLyrics)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy <= 0) return;
                        setState(() {
                          _lyricsDragOffset = (_lyricsDragOffset +
                                  details.delta.dy)
                              .clamp(0.0, 260.0);
                        });
                      },
                      onVerticalDragEnd: (details) {
                        final shouldClose =
                            _lyricsDragOffset > 80 ||
                                details.primaryVelocity != null &&
                                    details.primaryVelocity! > 600;
                        if (shouldClose) {
                          setState(() {
                            _showLyrics = false;
                            _lyricsDragOffset = 0.0;
                          });
                          return;
                        }
                        setState(() => _lyricsDragOffset = 0.0);
                      },
                      child: Transform.translate(
                        offset: Offset(0, _lyricsDragOffset),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.95),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Handle
                              Container(
                                width: 40,
                                height: 4,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant.withOpacity(
                                    0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Lyrics content
                              Expanded(
                                child: _buildLyricsContent(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        } catch (error, stackTrace) {
          debugPrint('NowPlayingScreen render error: $error');
          debugPrintStack(stackTrace: stackTrace);
          _syncRotation(false);
          return Scaffold(
            appBar: AppBar(title: const Text('Now Playing')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the now playing view.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildLyricsContent(BuildContext context) {
    if (_lyricsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lyricsError != null) {
      return Center(
        child: Text(
          _lyricsError!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_lyricsText == null || _lyricsText!.trim().isEmpty) {
      return Center(
        child: Text(
          'Lyrics not available',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        _lyricsText!,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _startLyricsLoad(Track track) {
    if (_lyricsTrackId == track.id && (_lyricsLoading || _lyricsText != null)) {
      return;
    }
    setState(() {
      _lyricsTrackId = track.id;
      _lyricsLoading = true;
      _lyricsError = null;
      _lyricsText = null;
    });

    _lyricsService.fetchLyrics(track).then((result) {
      if (!mounted) return;
      if (_lyricsTrackId != track.id) return;
      final resolved = result?.syncedLyrics ?? result?.plainLyrics;
      setState(() {
        _lyricsLoading = false;
        if (result == null) {
          _lyricsText = null;
          _lyricsError = null;
        } else if (result.instrumental) {
          _lyricsText = 'Instrumental';
          _lyricsError = null;
        } else if (resolved == null || resolved.trim().isEmpty) {
          _lyricsText = null;
          _lyricsError = null;
        } else {
          _lyricsText = resolved;
          _lyricsError = null;
        }
      });
    }).catchError((error) {
      if (!mounted) return;
      if (_lyricsTrackId != track.id) return;
      setState(() {
        _lyricsLoading = false;
        _lyricsError = 'Unable to load lyrics right now.';
      });
    });
  }

  void _cycleRepeatMode(AudioProvider audioProvider) {
    final currentMode = audioProvider.playbackState.repeatMode;
    LoopMode nextMode;
    if (currentMode == LoopMode.off) {
      nextMode = LoopMode.all;
    } else if (currentMode == LoopMode.all) {
      nextMode = LoopMode.one;
    } else {
      nextMode = LoopMode.off;
    }
    audioProvider.setRepeatMode(nextMode);
  }

  void _addBookmark(BuildContext context, AudioProvider audioProvider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bookmark added')));
  }

  void _showTrackMenu(BuildContext context, Track track) {
    final isRemoteTrack = _isRemoteTrack(track);

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isRemoteTrack)
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Change Artwork'),
              onTap: () async {
                Navigator.of(context).pop();
                await _changeArtwork(context, track);
              },
            ),
          if (!isRemoteTrack && _hasCustomArtwork(track))
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Remove Custom Artwork'),
              onTap: () async {
                Navigator.of(context).pop();
                await _removeCustomArtwork(context, track);
              },
            ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Add to Playlist'),
            onTap: () async {
              Navigator.of(context).pop();
              await _addToPlaylist(context, track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () async {
              Navigator.of(context).pop();
              await _shareTrack(context, track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Track Info'),
            onTap: () {
              Navigator.of(context).pop();
              _showTrackInfo(context, track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: const Text('Add Bookmark'),
            onTap: () {
              Navigator.of(context).pop();
              _addBookmark(context, context.read<AudioProvider>());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(BuildContext context, Track track) async {
    final databaseService = context.read<DatabaseService>();
    final playlists = databaseService
        .getAllPlaylists()
        .where((p) => p.smartType == null)
        .toList();

    if (playlists.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlist found. Create one first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Playlist>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Add to Playlist'), dense: true),
              ...playlists.map(
                (playlist) => ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.trackIds.length} tracks'),
                  onTap: () => Navigator.of(sheetContext).pop(playlist),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await databaseService.addTrackToPlaylist(selected.id, track.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added to ${selected.name}')));
  }

  Future<void> _shareTrack(BuildContext context, Track track) async {
    final shareText =
        '${track.title}\nArtist: ${track.artist}\nAlbum: ${track.album}';
    final file = File(track.path);
    if (!kIsWeb && await file.exists()) {
      await Share.shareXFiles(
        [XFile(track.path)],
        subject: track.title,
        text: shareText,
      );
      return;
    }

    await Share.share('$shareText\nPath: ${track.path}', subject: track.title);
  }

  Future<void> _changeArtwork(BuildContext context, Track track) async {
    final audioProvider = context.read<AudioProvider>();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final resolvedPath = await _cropArtworkPath(image);
    final updated = track.copyWith(albumArtPath: resolvedPath);
    await audioProvider.updateTrackMetadata(updated);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Artwork updated')));
  }

  Future<String> _cropArtworkPath(XFile image) async {
    if (kIsWeb) return image.path;
    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Artwork',
            lockAspectRatio: true,
            hideBottomControls: false,
            toolbarWidgetColor: Colors.white,
            toolbarColor: const Color(0xFF2B1530),
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop Artwork',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } catch (_) {
      cropped = null;
    }
    return cropped?.path ?? image.path;
  }

  Future<void> _removeCustomArtwork(BuildContext context, Track track) async {
    if (!_hasCustomArtwork(track)) return;
    final updated = track.copyWith(albumArtPath: null);
    await context.read<AudioProvider>().updateTrackMetadata(updated);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Custom artwork removed')));
  }

  void _showTrackInfo(BuildContext context, Track track) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Track Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Title: ${track.title}'),
                const SizedBox(height: 6),
                Text('Artist: ${track.artist}'),
                const SizedBox(height: 6),
                Text('Album: ${track.album}'),
                const SizedBox(height: 6),
                Text('Duration: ${_formatDuration(track.duration)}'),
                const SizedBox(height: 6),
                Text(
                  'Size: ${(track.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                ),
                const SizedBox(height: 6),
                Text('Path: ${track.path}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  bool _hasCustomArtwork(Track track) {
    final art = track.albumArtPath;
    return art != null &&
        art.isNotEmpty &&
        !art.startsWith('album_') &&
        !art.startsWith('http://') &&
        !art.startsWith('https://');
  }

  bool _isRemoteTrack(Track track) {
    final uri = Uri.tryParse(track.path);
    return uri != null && uri.hasScheme;
  }

  void _syncRotation(bool shouldRotate) {
    if (shouldRotate && !_isDiscRotating) {
      _rotationController.repeat();
      _waveController.repeat();
      _isDiscRotating = true;
      return;
    }
    if (!shouldRotate && _isDiscRotating) {
      _rotationController.stop();
      _waveController.stop();
      _isDiscRotating = false;
    }
  }

  IconData _getRepeatIcon(LoopMode repeatMode) {
    switch (repeatMode) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
      case LoopMode.all:
        return Icons.repeat;
    }
  }

  Widget _buildStyleEffect(app_settings.NowPlayingStyle style) {
    switch (style) {
      case app_settings.NowPlayingStyle.neonWave:
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _CircularWavePainter(progress: _waveController.value),
              );
            },
          ),
        );
      case app_settings.NowPlayingStyle.heartSnakeRing:
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: Listenable.merge([_waveController, _rotationController]),
            builder: (context, child) {
              return CustomPaint(
                painter: _HeartSnakeRingPainter(
                  waveProgress: _waveController.value,
                  spinProgress: _rotationController.value,
                ),
              );
            },
          ),
        );
      case app_settings.NowPlayingStyle.pulseRings:
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _PulseRingsPainter(progress: _waveController.value),
              );
            },
          ),
        );
      case app_settings.NowPlayingStyle.orbitDots:
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return CustomPaint(
                painter: _OrbitDotsPainter(progress: _rotationController.value),
              );
            },
          ),
        );
      case app_settings.NowPlayingStyle.radialBars:
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _RadialBarsPainter(progress: _waveController.value),
              );
            },
          ),
        );
    }
  }

  Widget _build3DButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPrimary
                ? [colorScheme.primary, colorScheme.tertiary]
                : [colorScheme.surface, colorScheme.surfaceVariant],
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? colorScheme.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              offset: const Offset(4, 4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: isPrimary
                  ? colorScheme.tertiary.withOpacity(0.3)
                  : theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.4,
            color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showAndroidOnlyMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Equalizer & Pitch are available on Android only.'),
      ),
    );
  }
}

class _CircularWavePainter extends CustomPainter {
  const _CircularWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.488;
    final baseAmplitude = size.shortestSide * 0.018;
    final phase = progress * math.pi * 2;
    const samples = 96;

    for (var layer = 0; layer < 2; layer++) {
      final layerPhase = phase + (layer * 0.9);
      final amplitude = baseAmplitude * (1 + layer * 0.42);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 - (layer * 1.6)
        ..color = Color.lerp(
          const Color(0x00FF4FB0),
          const Color(0xB2FF4FB0),
          1 - (layer * 0.25),
        )!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - (layer * 0.2)
        ..color = Color.lerp(
          const Color(0x22FF4FB0),
          const Color(0xEEFF4FB0),
          1 - (layer * 0.25),
        )!;

      final path = Path();
      for (var i = 0; i <= samples; i++) {
        final t = i / samples;
        final angle = t * math.pi * 2;
        final wave =
            (math.sin((angle * 6) + layerPhase) * 0.62) +
            (math.sin((angle * 11) - (layerPhase * 1.3)) * 0.38);
        final radius = baseRadius + (wave * amplitude);
        final point = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HeartSnakeRingPainter extends CustomPainter {
  const _HeartSnakeRingPainter({
    required this.waveProgress,
    required this.spinProgress,
  });

  final double waveProgress;
  final double spinProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortSide = size.shortestSide;
    final safeInset = shortSide * 0.12;
    final ringRadius = (shortSide / 2) - safeInset;
    final snakeRadius = (ringRadius + (shortSide * 0.03)).clamp(
      0.0,
      (shortSide / 2) - (shortSide * 0.075),
    );
    final headAngle = -math.pi / 2 + (spinProgress * math.pi * 2);
    final headPoint = Offset(
      center.dx + math.cos(headAngle) * snakeRadius,
      center.dy + math.sin(headAngle) * snakeRadius,
    );

    _drawWhiteRing(canvas, center, ringRadius);
    _drawRoundSnake(canvas, center, snakeRadius);
    _drawHeartWithMiniSnake(canvas, headPoint, shortSide);
  }

  void _drawWhiteRing(Canvas canvas, Offset center, double radius) {
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 1.2 + (math.sin(waveProgress * math.pi * 2) * 0.25);
    final start = (-math.pi / 2) + (spinProgress * math.pi * 2 * 0.8);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0x2EFFFFFF)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xCCFFFFFF);

    canvas.drawArc(ringRect, start, sweep, false, glowPaint);
    canvas.drawArc(ringRect, start, sweep, false, strokePaint);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x20FFFFFF);
    canvas.drawCircle(center, radius, basePaint);
  }

  void _drawRoundSnake(Canvas canvas, Offset center, double radius) {
    if (radius <= 0) return;
    final oval = Rect.fromCircle(center: center, radius: radius);
    final path = Path()..addOval(oval);
    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    final total = metric.length;
    if (total <= 0) return;
    final head = (spinProgress * total) % total;
    final segment = total * 0.42;
    final start = head - segment;

    final underlayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x8A0F0714)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final basePink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0x88FF2FA8);
    canvas.drawCircle(center, radius, basePink);

    _drawWrappedSegment(
      canvas: canvas,
      metric: metric,
      totalLength: total,
      start: start,
      end: head,
      glowPaint: underlayPaint,
      strokePaint: underlayPaint,
    );

    _drawWrappedSegment(
      canvas: canvas,
      metric: metric,
      totalLength: total,
      start: start,
      end: head,
      glowPaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xF0FF2FA8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      strokePaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF1EA1),
    );

    final headAngle = -math.pi / 2 + (spinProgress * math.pi * 2);
    final headPoint = Offset(
      center.dx + math.cos(headAngle) * radius,
      center.dy + math.sin(headAngle) * radius,
    );
    canvas.drawCircle(
      headPoint,
      4.2,
      Paint()
        ..color = const Color(0xFFFF1EA1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _drawHeartWithMiniSnake(Canvas canvas, Offset anchor, double shortSide) {
    final phase = waveProgress * math.pi * 2;
    final pulse = 1 + (math.sin(phase * 1.2) * 0.08);
    final auraRadius = shortSide * 0.052;
    final heartSize = shortSide * 0.036;
    final miniRadius = shortSide * 0.065;

    final heartContainerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x4AFF4FB0);
    canvas.drawCircle(anchor, auraRadius, heartContainerPaint);

    final heartPath = _buildHeartPath(anchor, heartSize * pulse);
    final heartGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xD9FF2FA8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final heartFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF2FA8);
    final heartStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFCD3EA);

    canvas.drawPath(heartPath, heartGlow);
    canvas.drawPath(heartPath, heartFill);
    canvas.drawPath(heartPath, heartStroke);

    final miniRect = Rect.fromCircle(center: anchor, radius: miniRadius);
    final miniPath = Path()..addOval(miniRect);
    final miniMetrics = miniPath.computeMetrics();
    if (miniMetrics.isEmpty) return;
    final miniMetric = miniMetrics.first;
    final miniTotal = miniMetric.length;
    if (miniTotal <= 0) return;
    final miniHead = ((spinProgress * 1.65) * miniTotal) % miniTotal;
    final miniSegment = miniTotal * 0.26;

    _drawWrappedSegment(
      canvas: canvas,
      metric: miniMetric,
      totalLength: miniTotal,
      start: miniHead - miniSegment,
      end: miniHead,
      glowPaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFF55B5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      strokePaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF55B5),
    );
  }

  Path _buildHeartPath(Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy + (size * 0.92));
    path.cubicTo(
      center.dx - (size * 1.24),
      center.dy + (size * 0.12),
      center.dx - (size * 1.24),
      center.dy - (size * 0.78),
      center.dx,
      center.dy - (size * 0.32),
    );
    path.cubicTo(
      center.dx + (size * 1.24),
      center.dy - (size * 0.78),
      center.dx + (size * 1.24),
      center.dy + (size * 0.12),
      center.dx,
      center.dy + (size * 0.92),
    );
    path.close();
    return path;
  }

  void _drawWrappedSegment({
    required Canvas canvas,
    required PathMetric metric,
    required double totalLength,
    required double start,
    required double end,
    required Paint glowPaint,
    required Paint strokePaint,
  }) {
    if (totalLength <= 0) return;

    var normalizedStart = start % totalLength;
    if (normalizedStart < 0) normalizedStart += totalLength;
    var normalizedEnd = end % totalLength;
    if (normalizedEnd < 0) normalizedEnd += totalLength;

    if (normalizedStart <= normalizedEnd) {
      final segment = metric.extractPath(normalizedStart, normalizedEnd);
      canvas.drawPath(segment, glowPaint);
      canvas.drawPath(segment, strokePaint);
      return;
    }

    final first = metric.extractPath(normalizedStart, totalLength);
    final second = metric.extractPath(0, normalizedEnd);
    canvas.drawPath(first, glowPaint);
    canvas.drawPath(first, strokePaint);
    canvas.drawPath(second, glowPaint);
    canvas.drawPath(second, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HeartSnakeRingPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.spinProgress != spinProgress;
  }
}

class _PulseRingsPainter extends CustomPainter {
  const _PulseRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.486;

    for (var i = 0; i < 3; i++) {
      final t = ((progress + (i * 0.28)) % 1.0);
      final radius = baseRadius + (t * size.shortestSide * 0.095);
      final alpha = (1.0 - t).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9 - (i * 2.0)
        ..color = Color.lerp(
          const Color(0x00FF5AB6),
          const Color(0x88FF5AB6),
          alpha,
        )!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 - (i * 0.35)
        ..color = Color.lerp(
          const Color(0x00FF67BC),
          const Color(0xEEFF67BC),
          alpha,
        )!;

      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OrbitDotsPainter extends CustomPainter {
  const _OrbitDotsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.495;
    const dotCount = 20;
    final phase = progress * math.pi * 2;

    for (var i = 0; i < dotCount; i++) {
      final t = i / dotCount;
      final angle = (t * math.pi * 2) + phase;
      final pulse = 0.55 + (math.sin((t * 12) + (phase * 2)) * 0.45);
      final dotRadius = 2.2 + (pulse * 2.1);
      final alpha = 0.35 + (pulse * 0.65);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0x40FF5CB1),
          const Color(0xFFFF5CB1),
          alpha,
        )!;
      canvas.drawCircle(point, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RadialBarsPainter extends CustomPainter {
  const _RadialBarsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.486;
    const bars = 48;
    final phase = progress * math.pi * 2;

    for (var i = 0; i < bars; i++) {
      final t = i / bars;
      final angle = t * math.pi * 2;
      final wave =
          (math.sin((angle * 8) + phase) * 0.6) +
          (math.sin((angle * 13) - (phase * 1.7)) * 0.4);
      final barLength = 10 + ((wave + 1) * 8.0);

      final start = Offset(
        center.dx + math.cos(angle) * baseRadius,
        center.dy + math.sin(angle) * baseRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (baseRadius + barLength),
        center.dy + math.sin(angle) * (baseRadius + barLength),
      );

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x66FF58B0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          const Color(0x66FF58B0),
          const Color(0xFFFF58B0),
          (barLength - 7) / 13.0,
        )!;

      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialBarsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
