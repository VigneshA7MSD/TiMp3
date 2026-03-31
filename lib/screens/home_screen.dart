import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/settings.dart';
import '../services/database_service.dart';
import '../services/file_scanner_service.dart';
import '../providers/audio_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/track_artwork.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _artworkStrokePink = Color(0xFFFF4FA3);

  bool _isLoading = true;
  bool _isScanning = false;
  bool _didStartAutoScan = false;
  Timer? _headerFadeTimer;
  bool _headerActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoScan();
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

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanForMusic({bool showMessage = false}) async {
    if (_isScanning) return;
    if (mounted) {
      setState(() => _isScanning = true);
    }

    try {
      final fileScanner = context.read<FileScannerService>();
      final databaseService = context.read<DatabaseService>();

      final scannedTracks = await fileScanner.scanForMusicFiles();
      await databaseService.saveTracks(scannedTracks);

      await _loadData(showLoading: false);

      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto scan complete: ${scannedTracks.length} tracks'),
          ),
        );
      }
    } catch (e) {
      if (mounted && showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _startAutoScan() {
    if (_didStartAutoScan) return;
    _didStartAutoScan = true;
    _scanForMusic();
  }

  void _playTrack(Track track, List<Track> queue) {
    final audioProvider = context.read<AudioProvider>();
    final trackIndex = queue.indexOf(track);
    audioProvider.setQueue(queue, startIndex: trackIndex);
    audioProvider.play();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final databaseService = context.read<DatabaseService>();

    return ValueListenableBuilder<Box<AppSettings>>(
      valueListenable: databaseService.getSettingsListenable(),
      builder: (context, box, child) {
        return ValueListenableBuilder<Box<Track>>(
          valueListenable: databaseService.getTracksListenable(),
          builder: (context, tracksBox, child) {
            return ValueListenableBuilder<Box<Playlist>>(
              valueListenable: databaseService.getPlaylistsListenable(),
              builder: (context, playlistsBox, child) {
                final tracks = databaseService.getAllTracks();
                final playlists = playlistsBox.values.toList();

                final recentlyPlayed =
                    tracks.where((t) => t.lastPlayed != null).toList()
                      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
                final recent = recentlyPlayed.take(20).toList();
                final recentDownloads = _buildRecentDownloads(
                  tracks,
                  limit: 20,
                );
                final topPlayed = tracks.where((t) => t.playCount > 0).toList()
                  ..sort((a, b) => b.playCount.compareTo(a.playCount));
                final top20Played = topPlayed.take(20).toList();

                final favPlaylist = playlists
                    .where((p) => p.smartType == SmartPlaylistType.favorites)
                    .firstOrNull;
                final favorites = favPlaylist != null
                    ? tracks
                          .where((t) => favPlaylist.trackIds.contains(t.id))
                          .toList()
                    : <Track>[];
                final userPlaylists = playlists
                    .where((p) => p.smartType == null)
                    .toList();

                return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 8,
                    automaticallyImplyLeading: false,
                    elevation: 0,
                  ),
                  body: AppBackground(
                    content: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: () => _scanForMusic(showMessage: true),
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollStartNotification ||
                                    notification is ScrollUpdateNotification ||
                                    notification is OverscrollNotification) {
                                  _bumpHeader();
                                }
                                return false;
                              },
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (_isScanning) ...[
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: LinearProgressIndicator(),
                                    ),
                                  ],
                                  if (recent.isNotEmpty) ...[
                                    _buildSectionHeader('Recently Played'),
                                    _buildRecentlyPlayedList(recent),
                                    const SizedBox(height: 24),
                                  ],
                                  if (recentDownloads.isNotEmpty) ...[
                                    _buildSectionHeader('Recently Added'),
                                    _buildRecentlyDownloadedList(
                                      recentDownloads,
                                    ),
                                    if (top20Played.isNotEmpty ||
                                        favorites.isNotEmpty ||
                                        userPlaylists.isNotEmpty)
                                      _buildSectionBreaker(),
                                    const SizedBox(height: 24),
                                  ],
                                  if (top20Played.isNotEmpty) ...[
                                    _buildSectionHeader('Top Played Songs'),
                                    _buildTopPlayedList(top20Played),
                                    const SizedBox(height: 24),
                                  ],
                                  if (favorites.isNotEmpty) ...[
                                    _buildSectionHeader('Favorites'),
                                    _buildFavoritesList(favorites),
                                    const SizedBox(height: 24),
                                  ],
                                  if (userPlaylists.isNotEmpty) ...[
                                    _buildSectionHeader('Playlists'),
                                    _buildPlaylistsList(userPlaylists),
                                    const SizedBox(height: 24),
                                  ],
                                  if (recent.isEmpty &&
                                      recentDownloads.isEmpty &&
                                      top20Played.isEmpty &&
                                      favorites.isEmpty &&
                                      userPlaylists.isEmpty)
                                    _buildEmptyState(),
                                ],
                              ),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Track> _buildRecentDownloads(List<Track> tracks, {int limit = 20}) {
    final bestByIdentity = <String, Track>{};
    for (final track in tracks) {
      final key =
          '${track.title.trim().toLowerCase()}|${track.artist.trim().toLowerCase()}|${track.album.trim().toLowerCase()}';
      final existing = bestByIdentity[key];
      if (existing == null || _isBetterRecentTrackCandidate(track, existing)) {
        bestByIdentity[key] = track;
      }
    }

    final recent = bestByIdentity.values.toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return recent.take(limit).toList();
  }

  bool _isBetterRecentTrackCandidate(Track next, Track current) {
    final nextHasArtwork = _hasPotentialArtwork(next);
    final currentHasArtwork = _hasPotentialArtwork(current);
    if (nextHasArtwork != currentHasArtwork) return nextHasArtwork;

    if (next.dateAdded != current.dateAdded) {
      return next.dateAdded.isAfter(current.dateAdded);
    }

    final nextIsFs = next.id.startsWith('fs_');
    final currentIsFs = current.id.startsWith('fs_');
    if (nextIsFs != currentIsFs) return !nextIsFs;

    return false;
  }

  bool _hasPotentialArtwork(Track track) {
    final art = track.albumArtPath;
    if (art != null && art.trim().isNotEmpty) return true;
    return int.tryParse(track.id) != null;
  }

  Widget _buildSectionBreaker() {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Divider(height: 1, thickness: 1, color: dividerColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayedList(List<Track> recentTracks) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentTracks.length,
        itemBuilder: (context, index) {
          final track = recentTracks[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: InkWell(
                onTap: () => _playTrack(track, recentTracks),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TrackArtwork(
                        track: track,
                        size: 80,
                        borderRadius: BorderRadius.circular(12),
                        borderColor: _artworkStrokePink,
                        borderWidth: 1.2,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyDownloadedList(List<Track> recentTracks) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentTracks.length,
        itemBuilder: (context, index) {
          final track = recentTracks[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: InkWell(
                onTap: () => _playTrack(track, recentTracks),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TrackArtwork(
                        track: track,
                        size: 80,
                        borderRadius: BorderRadius.circular(12),
                        borderColor: _artworkStrokePink,
                        borderWidth: 1.2,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesList(List<Track> favorites) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final track = favorites[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: InkWell(
                onTap: () => _playTrack(track, favorites),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TrackArtwork(
                        track: track,
                        size: 80,
                        borderRadius: BorderRadius.circular(12),
                        fallbackIcon: Icons.favorite,
                        borderColor: _artworkStrokePink,
                        borderWidth: 1.2,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopPlayedList(List<Track> topPlayedTracks) {
    return SizedBox(
      height: 158,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topPlayedTracks.length,
        itemBuilder: (context, index) {
          final track = topPlayedTracks[index];
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              child: InkWell(
                onTap: () => _playTrack(track, topPlayedTracks),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TrackArtwork(
                        track: track,
                        size: 80,
                        borderRadius: BorderRadius.circular(12),
                        borderColor: _artworkStrokePink,
                        borderWidth: 1.2,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Played ${track.playCount} times',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList(List<Playlist> playlists) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.playlist_play),
            ),
            title: Text(playlist.name),
            subtitle: Text('${playlist.trackIds.length} tracks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to playlist screen
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No music found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Music scanning runs automatically on open.\nPull down to rescan.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
