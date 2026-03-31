import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../services/online_music_service.dart';
import '../widgets/app_background.dart';
import '../widgets/track_artwork.dart';
import '../widgets/track_list_item.dart';

enum OnlineViewMode { list, grid }

const Color _onlineArtworkStrokePink = Color(0xFFFF4FA3);
const double _onlineLibraryBottomInset = 156;

class OnlineLibraryScreen extends StatefulWidget {
  const OnlineLibraryScreen({super.key});

  @override
  State<OnlineLibraryScreen> createState() => _OnlineLibraryScreenState();
}

class _OnlineLibraryScreenState extends State<OnlineLibraryScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _songsScrollController = ScrollController();
  final ScrollController _albumsScrollController = ScrollController();
  final ScrollController _artistsScrollController = ScrollController();

  late final TabController _tabController;
  Timer? _searchDebounce;

  List<Track> _tracks = [];
  Map<String, List<Track>> _albums = {};
  Map<String, List<Track>> _artists = {};
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;
  OnlineViewMode _viewMode = OnlineViewMode.list;
  int _searchGeneration = 0;
  List<Track> _catalog = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _songsScrollController.dispose();
    _albumsScrollController.dispose();
    _artistsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await context.read<OnlineMusicService>().fetchTracks();
      if (!mounted) return;
      setState(() {
        _catalog = results;
        _tracks = results;
        _albums = _groupByAlbum(results);
        _artists = _groupByArtist(results);
        _isSearching = false;
        _hasSearched = results.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _catalog = [];
        _tracks = [];
        _albums = {};
        _artists = {};
        _isSearching = false;
        _hasSearched = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _searchGeneration++;
      setState(() {
        _tracks = _catalog;
        _albums = _groupByAlbum(_catalog);
        _artists = _groupByArtist(_catalog);
        _isSearching = false;
        _hasSearched = _catalog.isNotEmpty;
        _errorMessage = null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _hasSearched = _catalog.isNotEmpty;
      _errorMessage = null;
    });

    try {
      final normalizedQuery = query.trim().toLowerCase();
      final results = _catalog
          .where((track) {
            return track.title.toLowerCase().contains(normalizedQuery) ||
                track.artist.toLowerCase().contains(normalizedQuery) ||
                track.album.toLowerCase().contains(normalizedQuery);
          })
          .toList(growable: false);
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _tracks = results;
        _albums = _groupByAlbum(results);
        _artists = _groupByArtist(results);
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _tracks = [];
        _albums = {};
        _artists = {};
        _isSearching = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.isEmpty) {
      return 'Unable to load cloud music right now.';
    }
    return text;
  }

  Map<String, List<Track>> _groupByAlbum(List<Track> tracks) {
    final grouped = <String, List<Track>>{};
    for (final track in tracks) {
      grouped.putIfAbsent(track.album, () => <Track>[]).add(track);
    }
    return grouped;
  }

  Map<String, List<Track>> _groupByArtist(List<Track> tracks) {
    final grouped = <String, List<Track>>{};
    for (final track in tracks) {
      grouped.putIfAbsent(track.artist, () => <Track>[]).add(track);
    }
    return grouped;
  }

  void _playTrack(Track track, List<Track> queue) {
    final audioProvider = context.read<AudioProvider>();
    final trackIndex = queue.indexOf(track);
    audioProvider.setQueue(queue, startIndex: trackIndex);
    audioProvider.play();
  }

  void _playCollection(List<Track> queue) {
    if (queue.isEmpty) return;
    final audioProvider = context.read<AudioProvider>();
    audioProvider.setQueue(queue, startIndex: 0);
    audioProvider.play();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchGeneration++;
    setState(() {
      _tracks = _catalog;
      _albums = _groupByAlbum(_catalog);
      _artists = _groupByArtist(_catalog);
      _isSearching = false;
      _hasSearched = _catalog.isNotEmpty;
      _errorMessage = null;
    });
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
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 8),
                  _OnlineControlPill(
                    icon: _viewMode == OnlineViewMode.list
                        ? Icons.grid_view_rounded
                        : Icons.view_list,
                    label: _viewMode == OnlineViewMode.list ? 'Grid' : 'List',
                    onTap: () {
                      setState(() {
                        _viewMode = _viewMode == OnlineViewMode.list
                            ? OnlineViewMode.grid
                            : OnlineViewMode.list;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _onlineArtworkStrokePink.withValues(alpha: 0.55),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Songs'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search online tracks...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: _onlineArtworkStrokePink.withValues(alpha: 0.55),
            width: 0.9,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: _onlineArtworkStrokePink.withValues(alpha: 0.55),
            width: 0.9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: _onlineArtworkStrokePink.withValues(alpha: 0.95),
            width: 1.2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.cloud_off,
        title: 'Online search unavailable',
        message: _errorMessage!,
      );
    }
    if (!_hasSearched) {
      return _buildMessageState(
        icon: Icons.cloud_queue,
        title: 'Online Library',
        message:
            'No cloud songs found yet. Upload songs to Supabase and they will appear here.',
      );
    }
    if (_tracks.isEmpty) {
      return _buildMessageState(
        icon: Icons.search_off,
        title: 'No online results',
        message: 'Try a different song, artist, or album name.',
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildSongsTab(), _buildAlbumsTab(), _buildArtistsTab()],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsTab() {
    if (_viewMode == OnlineViewMode.grid) {
      return GridView.builder(
        controller: _songsScrollController,
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          _onlineLibraryBottomInset,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          final track = _tracks[index];
          return _OnlineTrackCard(
            track: track,
            onTap: () => _openTrackPreview(track, _tracks),
          );
        },
      );
    }

    return ListView.separated(
      controller: _songsScrollController,
      padding: const EdgeInsets.only(bottom: _onlineLibraryBottomInset),
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return TrackListItem(
          track: track,
          onTap: () => _playTrack(track, _tracks),
          enableTrackMenu: false,
          trailing: const Icon(Icons.cloud_queue_outlined),
        );
      },
      separatorBuilder: (context, index) => _buildOnlineListDivider(),
    );
  }

  Widget _buildAlbumsTab() {
    final albumNames = _albums.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (_viewMode == OnlineViewMode.grid) {
      return GridView.builder(
        controller: _albumsScrollController,
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          _onlineLibraryBottomInset,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: albumNames.length,
        itemBuilder: (context, index) {
          final albumName = albumNames[index];
          final tracks = _albums[albumName]!;
          return _OnlineCollectionCard(
            title: albumName,
            subtitle: '${tracks.length} tracks',
            track: tracks.first,
            fallbackIcon: Icons.album,
            onTap: () => _openAlbum(albumName, tracks),
          );
        },
      );
    }

    return ListView.separated(
      controller: _albumsScrollController,
      padding: const EdgeInsets.only(bottom: _onlineLibraryBottomInset),
      itemCount: albumNames.length,
      itemBuilder: (context, index) {
        final albumName = albumNames[index];
        final tracks = _albums[albumName]!;
        final firstTrack = tracks.first;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: TrackArtwork(
              track: firstTrack,
              size: 52,
              borderRadius: BorderRadius.circular(10),
              fallbackIcon: Icons.album,
              borderColor: _onlineArtworkStrokePink,
              borderWidth: 1.2,
            ),
            title: Text(
              albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${firstTrack.artist} - ${tracks.length} tracks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openAlbum(albumName, tracks),
          ),
        );
      },
      separatorBuilder: (context, index) => _buildOnlineListDivider(),
    );
  }

  Widget _buildArtistsTab() {
    final artistNames = _artists.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (_viewMode == OnlineViewMode.grid) {
      return GridView.builder(
        controller: _artistsScrollController,
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          _onlineLibraryBottomInset,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: artistNames.length,
        itemBuilder: (context, index) {
          final artistName = artistNames[index];
          final tracks = _artists[artistName]!;
          return _OnlineCollectionCard(
            title: artistName,
            subtitle: '${tracks.length} tracks',
            track: tracks.first,
            fallbackIcon: Icons.person,
            onTap: () => _openArtist(artistName, tracks),
          );
        },
      );
    }

    return ListView.separated(
      controller: _artistsScrollController,
      padding: const EdgeInsets.only(bottom: _onlineLibraryBottomInset),
      itemCount: artistNames.length,
      itemBuilder: (context, index) {
        final artistName = artistNames[index];
        final tracks = _artists[artistName]!;
        final firstTrack = tracks.first;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: TrackArtwork(
              track: firstTrack,
              size: 52,
              borderRadius: BorderRadius.circular(10),
              fallbackIcon: Icons.person,
              borderColor: _onlineArtworkStrokePink,
              borderWidth: 1.2,
            ),
            title: Text(
              artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} tracks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openArtist(artistName, tracks),
          ),
        );
      },
      separatorBuilder: (context, index) => _buildOnlineListDivider(),
    );
  }

  Widget _buildOnlineListDivider() {
    return Divider(
      height: 1,
      indent: 84,
      endIndent: 16,
      thickness: 0.5,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }

  void _openAlbum(String albumName, List<Track> tracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineAlbumDetailScreen(
          albumName: albumName,
          tracks: tracks,
        ),
      ),
    );
  }

  void _openArtist(String artistName, List<Track> tracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineArtistDetailScreen(
          artistName: artistName,
          tracks: tracks,
        ),
      ),
    );
  }

  void _openTrackPreview(Track track, List<Track> queue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineTrackPreviewScreen(
          track: track,
          queue: queue,
        ),
      ),
    );
  }
}

class _OnlineControlPill extends StatelessWidget {
  const _OnlineControlPill({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineTrackCard extends StatelessWidget {
  const _OnlineTrackCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OnlinePinkGridTile(
      track: track,
      title: track.title,
      subtitle: track.artist,
      fallbackIcon: Icons.music_note,
      onTap: onTap,
    );
  }
}

class _OnlineCollectionCard extends StatelessWidget {
  const _OnlineCollectionCard({
    required this.title,
    required this.subtitle,
    required this.track,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Track track;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OnlinePinkGridTile(
      track: track,
      title: title,
      subtitle: subtitle,
      fallbackIcon: fallbackIcon,
      onTap: onTap,
    );
  }
}

class _OnlinePinkGridTile extends StatelessWidget {
  const _OnlinePinkGridTile({
    required this.track,
    required this.title,
    required this.subtitle,
    required this.fallbackIcon,
    required this.onTap,
  });

  final Track track;
  final String title;
  final String subtitle;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _onlineArtworkStrokePink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _onlineArtworkStrokePink.withValues(alpha: 0.72),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artSize = (constraints.maxWidth * 0.78).floorToDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: SizedBox(
                    width: artSize,
                    height: artSize,
                    child: TrackArtwork(
                      track: track,
                      size: artSize,
                      borderRadius: BorderRadius.circular(10),
                      fallbackIcon: fallbackIcon,
                      borderColor: _onlineArtworkStrokePink,
                      borderWidth: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OnlineAlbumDetailScreen extends StatefulWidget {
  const OnlineAlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.tracks,
  });

  final String albumName;
  final List<Track> tracks;

  @override
  State<OnlineAlbumDetailScreen> createState() => _OnlineAlbumDetailScreenState();
}

class _OnlineAlbumDetailScreenState extends State<OnlineAlbumDetailScreen> {
  bool _largeIcons = false;

  @override
  Widget build(BuildContext context) {
    final sortedTracks = List<Track>.from(widget.tracks)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.albumName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(_largeIcons ? Icons.view_list : Icons.grid_view_rounded),
            tooltip: _largeIcons ? 'Small icons' : 'Large icons',
            onPressed: () => setState(() => _largeIcons = !_largeIcons),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play album',
            onPressed: sortedTracks.isEmpty
                ? null
                : () {
                    final audioProvider = context.read<AudioProvider>();
                    audioProvider.setQueue(sortedTracks);
                    audioProvider.play();
                  },
          ),
        ],
      ),
      body: AppBackground(
        content: Padding(
          padding: const EdgeInsets.only(bottom: 84),
          child: sortedTracks.isEmpty
              ? const Center(child: Text('No songs in this album'))
              : ListView.builder(
                  itemCount: sortedTracks.length,
                  itemBuilder: (context, index) {
                    final track = sortedTracks[index];
                    void onTap() {
                      final audioProvider = context.read<AudioProvider>();
                      audioProvider.setQueue(sortedTracks, startIndex: index);
                      audioProvider.play();
                    }

                    if (_largeIcons) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: TrackArtwork(
                            track: track,
                            size: 64,
                            borderRadius: BorderRadius.circular(12),
                            borderColor: _onlineArtworkStrokePink,
                            borderWidth: 1.2,
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${track.artist} • ${track.album}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: onTap,
                        ),
                      );
                    }

                    return TrackListItem(
                      track: track,
                      onTap: onTap,
                      enableTrackMenu: false,
                      trailing: const Icon(Icons.cloud_queue_outlined),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class OnlineArtistDetailScreen extends StatefulWidget {
  const OnlineArtistDetailScreen({
    super.key,
    required this.artistName,
    required this.tracks,
  });

  final String artistName;
  final List<Track> tracks;

  @override
  State<OnlineArtistDetailScreen> createState() =>
      _OnlineArtistDetailScreenState();
}

class _OnlineArtistDetailScreenState extends State<OnlineArtistDetailScreen> {
  bool _largeIcons = false;

  @override
  Widget build(BuildContext context) {
    final sortedTracks = List<Track>.from(widget.tracks)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(_largeIcons ? Icons.view_list : Icons.grid_view_rounded),
            tooltip: _largeIcons ? 'Small icons' : 'Large icons',
            onPressed: () => setState(() => _largeIcons = !_largeIcons),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play artist',
            onPressed: sortedTracks.isEmpty
                ? null
                : () {
                    final audioProvider = context.read<AudioProvider>();
                    audioProvider.setQueue(sortedTracks);
                    audioProvider.play();
                  },
          ),
        ],
      ),
      body: AppBackground(
        content: Padding(
          padding: const EdgeInsets.only(bottom: 84),
          child: sortedTracks.isEmpty
              ? const Center(child: Text('No songs for this artist'))
              : ListView.builder(
                  itemCount: sortedTracks.length,
                  itemBuilder: (context, index) {
                    final track = sortedTracks[index];
                    void onTap() {
                      final audioProvider = context.read<AudioProvider>();
                      audioProvider.setQueue(sortedTracks, startIndex: index);
                      audioProvider.play();
                    }

                    if (_largeIcons) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: TrackArtwork(
                            track: track,
                            size: 64,
                            borderRadius: BorderRadius.circular(12),
                            borderColor: _onlineArtworkStrokePink,
                            borderWidth: 1.2,
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${track.artist} • ${track.album}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: onTap,
                        ),
                      );
                    }

                    return TrackListItem(
                      track: track,
                      onTap: onTap,
                      enableTrackMenu: false,
                      trailing: const Icon(Icons.cloud_queue_outlined),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class OnlineTrackPreviewScreen extends StatelessWidget {
  const OnlineTrackPreviewScreen({
    super.key,
    required this.track,
    required this.queue,
  });

  final Track track;
  final List<Track> queue;

  @override
  Widget build(BuildContext context) {
    final index = queue.indexOf(track);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Preview'),
      ),
      body: AppBackground(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 108),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TrackArtwork(
                track: track,
                size: 220,
                borderRadius: BorderRadius.circular(24),
                borderColor: _onlineArtworkStrokePink,
                borderWidth: 1.4,
              ),
              const SizedBox(height: 24),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                track.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatDuration(track.duration),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: index < 0
                      ? null
                      : () {
                          final audioProvider = context.read<AudioProvider>();
                          audioProvider.setQueue(queue, startIndex: index);
                          audioProvider.play();
                          Navigator.of(context).pushNamed('/now-playing');
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Now'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AudioProvider>().addToQueue(track);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enqueued ${track.title}')),
                    );
                  },
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Add To Queue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
