import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../providers/audio_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/track_list_item.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with AutomaticKeepAliveClientMixin {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  Timer? _headerFadeTimer;
  bool _headerActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
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

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);

    final databaseService = context.read<DatabaseService>();
    final playlists = databaseService.getAllPlaylists();

    // Filter out smart playlists (favorites, recently played, etc.)
    _playlists = playlists.where((p) => p.smartType == null).toList();

    setState(() => _isLoading = false);
  }

  Future<void> _createPlaylist() async {
    final TextEditingController controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter playlist name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final databaseService = context.read<DatabaseService>();
      final playlist = Playlist(
        id: const Uuid().v4(),
        name: result,
        trackIds: [],
        dateCreated: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await databaseService.savePlaylist(playlist);
      await _loadPlaylists();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Created playlist "$result"')));
      }
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final databaseService = context.read<DatabaseService>();
      await databaseService.deletePlaylist(playlist.id);
      await _loadPlaylists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted playlist "${playlist.name}"')),
        );
      }
    }
  }

  void _playPlaylist(Playlist playlist) {
    final databaseService = context.read<DatabaseService>();
    final tracks = databaseService.getAllTracks();
    final playlistTracks = tracks
        .where((t) => playlist.trackIds.contains(t.id))
        .toList();

    if (playlistTracks.isNotEmpty) {
      final audioProvider = context.read<AudioProvider>();
      audioProvider.setQueue(playlistTracks);
      audioProvider.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 8,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: AppBackground(
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _playlists.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadPlaylists,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification ||
                        notification is ScrollUpdateNotification ||
                        notification is OverscrollNotification) {
                      _bumpHeader();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.playlist_play, size: 28),
                          ),
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.trackIds.length} tracks'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'play':
                                  _playPlaylist(playlist);
                                  break;
                                case 'rename':
                                  _renamePlaylist(playlist);
                                  break;
                                case 'delete':
                                  _deletePlaylist(playlist);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'play',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow),
                                    SizedBox(width: 8),
                                    Text('Play'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Rename'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _openPlaylist(playlist),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final TextEditingController controller = TextEditingController(
      text: playlist.name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != playlist.name) {
      final databaseService = context.read<DatabaseService>();
      final updatedPlaylist = playlist.copyWith(
        name: result,
        updatedAt: DateTime.now(),
      );

      await databaseService.savePlaylist(updatedPlaylist);
      await _loadPlaylists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed playlist to "$result"')),
        );
      }
    }
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.playlist_add, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No playlists yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first playlist to organize your music',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add),
            label: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);

    final databaseService = context.read<DatabaseService>();
    final allTracks = databaseService.getAllTracks();
    _tracks = allTracks
        .where((t) => _playlist.trackIds.contains(t.id))
        .toList();

    setState(() => _isLoading = false);
  }

  void _playTrack(Track track) {
    final audioProvider = context.read<AudioProvider>();
    final trackIndex = _tracks.indexOf(track);
    audioProvider.setQueue(_tracks, startIndex: trackIndex);
    audioProvider.play();
  }

  Future<void> _addSongs() async {
    final databaseService = context.read<DatabaseService>();
    final allTracks = databaseService.getAllTracks();
    final existingIds = _playlist.trackIds.toSet();
    final availableTracks =
        allTracks.where((track) => !existingIds.contains(track.id)).toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

    if (availableTracks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All songs are already in this playlist')),
      );
      return;
    }

    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Songs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).pop(selected.toList(growable: false)),
                            child: Text('Add (${selected.length})'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableTracks.length,
                        itemBuilder: (context, index) {
                          final track = availableTracks[index];
                          final isSelected = selected.contains(track.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(track.id);
                                } else {
                                  selected.remove(track.id);
                                }
                              });
                            },
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${track.artist} • ${track.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedIds == null || selectedIds.isEmpty) {
      return;
    }

    final updatedPlaylist = _playlist.copyWith(
      trackIds: [..._playlist.trackIds, ...selectedIds],
      updatedAt: DateTime.now(),
    );
    await databaseService.savePlaylist(updatedPlaylist);
    if (!mounted) return;
    setState(() => _playlist = updatedPlaylist);
    await _loadTracks();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${selectedIds.length} songs to playlist')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSongs,
            tooltip: 'Add songs',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _tracks.isNotEmpty
                ? () => _playTrack(_tracks.first)
                : null,
            tooltip: 'Play playlist',
          ),
        ],
      ),
      body: AppBackground(
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _tracks.isEmpty
            ? _buildEmptyPlaylist()
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tracks.length,
                onReorder: _reorderTracks,
                itemBuilder: (context, index) {
                  final track = _tracks[index];
                  return TrackListItem(
                    key: ValueKey(track.id),
                    track: track,
                    onTap: () => _playTrack(track),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeTrack(track),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _reorderTracks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final track = _tracks.removeAt(oldIndex);
    _tracks.insert(newIndex, track);

    // Update playlist track order
    final databaseService = context.read<DatabaseService>();
    final updatedPlaylist = _playlist.copyWith(
      trackIds: _tracks.map((t) => t.id).toList(),
      updatedAt: DateTime.now(),
    );

    await databaseService.savePlaylist(updatedPlaylist);
    setState(() => _playlist = updatedPlaylist);
  }

  Future<void> _removeTrack(Track track) async {
    final databaseService = context.read<DatabaseService>();
    final updatedTrackIds = _playlist.trackIds
        .where((id) => id != track.id)
        .toList();

    final updatedPlaylist = _playlist.copyWith(
      trackIds: updatedTrackIds,
      updatedAt: DateTime.now(),
    );

    await databaseService.savePlaylist(updatedPlaylist);
    setState(() => _playlist = updatedPlaylist);
    await _loadTracks();
  }

  Widget _buildEmptyPlaylist() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No songs in this playlist',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add songs to start building your playlist',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSongs,
            icon: const Icon(Icons.add),
            label: const Text('Add Songs'),
          ),
        ],
      ),
    );
  }
}
