import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_background.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_artwork.dart';
import '../widgets/track_list_item.dart';

enum SongSortMode { titleAsc, titleDesc, artistAsc, newest, oldest }

enum AlbumSortMode { nameAsc, nameDesc, tracksDesc }

enum LibraryViewMode { list, grid }

enum _CollectionAction { share, changeArtwork, delete }

const Color _artworkStrokePink = Color(0xFFFF4FA3);

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _songsScrollController = ScrollController();
  final ScrollController _albumsScrollController = ScrollController();
  final ScrollController _artistsScrollController = ScrollController();
  final ScrollController _foldersScrollController = ScrollController();

  List<Track> _tracks = [];
  Map<String, List<Track>> _albums = {};
  Map<String, List<Track>> _artists = {};
  Map<String, List<Track>> _folders = {};
  bool _isLoading = true;

  SongSortMode _songSortMode = SongSortMode.titleAsc;
  AlbumSortMode _albumSortMode = AlbumSortMode.nameAsc;
  LibraryViewMode _libraryViewMode = LibraryViewMode.list;
  late final TabController _tabController;
  final Set<String> _selectedSongIds = {};
  final Set<String> _selectedAlbumNames = {};
  final Set<String> _selectedArtistNames = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<DatabaseService>().getSettings();
    _libraryViewMode = settings.libraryViewIsGrid
        ? LibraryViewMode.grid
        : LibraryViewMode.list;
    final initialTab = settings.libraryTabIndex.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialTab);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _songsScrollController.dispose();
    _albumsScrollController.dispose();
    _artistsScrollController.dispose();
    _foldersScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _clearSelection();
    _saveLibraryUiState(tabIndex: _tabController.index);
  }

  Future<void> _saveLibraryUiState({
    LibraryViewMode? viewMode,
    int? tabIndex,
  }) async {
    final databaseService = context.read<DatabaseService>();
    final current = databaseService.getSettings();
    await databaseService.saveSettings(
      current.copyWith(
        libraryViewIsGrid:
            (viewMode ?? _libraryViewMode) == LibraryViewMode.grid,
        libraryTabIndex: (tabIndex ?? _tabController.index).clamp(0, 3),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final databaseService = context.read<DatabaseService>();
    final tracks = databaseService.getAllTracks();

    final albums = <String, List<Track>>{};
    final artists = <String, List<Track>>{};
    final folders = <String, List<Track>>{};

    for (final track in tracks) {
      albums.putIfAbsent(track.album, () => <Track>[]).add(track);
      artists.putIfAbsent(track.artist, () => <Track>[]).add(track);

      final normalizedPath = track.path.replaceAll('\\', '/');
      final lastSlash = normalizedPath.lastIndexOf('/');
      final folderPath = lastSlash > 0
          ? normalizedPath.substring(0, lastSlash)
          : normalizedPath;
      folders.putIfAbsent(folderPath, () => <Track>[]).add(track);
    }

    setState(() {
      _tracks = tracks;
      _albums = albums;
      _artists = artists;
      _folders = folders;
      _isLoading = false;
    });
  }

  void _playTrack(Track track, List<Track> queue) {
    final audioProvider = context.read<AudioProvider>();
    final trackIndex = queue.indexOf(track);
    audioProvider.setQueue(queue, startIndex: trackIndex);
    audioProvider.play();
  }

  List<Track> _getSortedSongs() {
    final songs = List<Track>.from(_tracks);
    switch (_songSortMode) {
      case SongSortMode.titleAsc:
        songs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SongSortMode.titleDesc:
        songs.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case SongSortMode.artistAsc:
        songs.sort((a, b) {
          final artistCmp = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          if (artistCmp != 0) return artistCmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SongSortMode.newest:
        songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SongSortMode.oldest:
        songs.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
    }
    return songs;
  }

  List<String> _getSortedAlbumNames() {
    final albumNames = _albums.keys.toList();
    switch (_albumSortMode) {
      case AlbumSortMode.nameAsc:
        albumNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        break;
      case AlbumSortMode.nameDesc:
        albumNames.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
        break;
      case AlbumSortMode.tracksDesc:
        albumNames.sort((a, b) {
          final countCmp = _albums[b]!.length.compareTo(_albums[a]!.length);
          if (countCmp != 0) return countCmp;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
        break;
    }
    return albumNames;
  }

  Map<String, int> _buildLetterIndex<T>({
    required List<T> items,
    required String Function(T) label,
  }) {
    final index = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final text = label(items[i]).trim();
      final key = text.isEmpty ? '#' : text[0].toUpperCase();
      final letter = RegExp(r'[A-Z]').hasMatch(key) ? key : '#';
      index.putIfAbsent(letter, () => i);
    }
    return index;
  }

  void _jumpToIndex({
    required ScrollController controller,
    required int index,
    required int totalItems,
    int itemsPerRow = 1,
  }) {
    if (!controller.hasClients) return;
    if (totalItems <= 0 || itemsPerRow <= 0) return;
    final totalRows = (totalItems / itemsPerRow).ceil();
    final targetRow = (index ~/ itemsPerRow).clamp(0, totalRows - 1);
    final ratio = totalRows <= 1 ? 0.0 : targetRow / (totalRows - 1);
    final max = controller.position.maxScrollExtent;
    controller.animateTo(
      (ratio * max).clamp(0, max),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _toggleViewMode() {
    setState(() {
      _libraryViewMode = _libraryViewMode == LibraryViewMode.list
          ? LibraryViewMode.grid
          : LibraryViewMode.list;
    });
    _saveLibraryUiState(viewMode: _libraryViewMode);
  }

  bool get _isSongsTab => _tabController.index == 0;
  bool get _isAlbumsTab => _tabController.index == 1;
  bool get _isArtistsTab => _tabController.index == 2;

  bool get _selectionActive {
    if (_isSongsTab) return _selectedSongIds.isNotEmpty;
    if (_isAlbumsTab) return _selectedAlbumNames.isNotEmpty;
    if (_isArtistsTab) return _selectedArtistNames.isNotEmpty;
    return false;
  }

  int get _selectionCount {
    if (_isSongsTab) return _selectedSongIds.length;
    if (_isAlbumsTab) return _selectedAlbumNames.length;
    if (_isArtistsTab) return _selectedArtistNames.length;
    return 0;
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectedSongIds.clear();
      _selectedAlbumNames.clear();
      _selectedArtistNames.clear();
    });
  }

  void _toggleSongSelection(Track track) {
    setState(() {
      if (!_selectedSongIds.add(track.id)) {
        _selectedSongIds.remove(track.id);
      }
    });
  }

  void _toggleAlbumSelection(String albumName) {
    setState(() {
      if (!_selectedAlbumNames.add(albumName)) {
        _selectedAlbumNames.remove(albumName);
      }
    });
  }

  void _toggleArtistSelection(String artistName) {
    setState(() {
      if (!_selectedArtistNames.add(artistName)) {
        _selectedArtistNames.remove(artistName);
      }
    });
  }

  void _applySortSelection(String value) {
    setState(() {
      switch (value) {
        case 'song_title_asc':
          _songSortMode = SongSortMode.titleAsc;
          break;
        case 'song_title_desc':
          _songSortMode = SongSortMode.titleDesc;
          break;
        case 'song_artist':
          _songSortMode = SongSortMode.artistAsc;
          break;
        case 'song_newest':
          _songSortMode = SongSortMode.newest;
          break;
        case 'song_oldest':
          _songSortMode = SongSortMode.oldest;
          break;
        case 'album_name_asc':
          _albumSortMode = AlbumSortMode.nameAsc;
          break;
        case 'album_name_desc':
          _albumSortMode = AlbumSortMode.nameDesc;
          break;
        case 'album_tracks_desc':
          _albumSortMode = AlbumSortMode.tracksDesc;
          break;
      }
    });
  }

  List<PopupMenuEntry<String>> _buildSortMenuItems() => const [
    PopupMenuItem(enabled: false, child: Text('Songs')),
    PopupMenuItem(value: 'song_title_asc', child: Text('Title A-Z')),
    PopupMenuItem(value: 'song_title_desc', child: Text('Title Z-A')),
    PopupMenuItem(value: 'song_artist', child: Text('Artist A-Z')),
    PopupMenuItem(value: 'song_newest', child: Text('Newest First')),
    PopupMenuItem(value: 'song_oldest', child: Text('Oldest First')),
    PopupMenuDivider(),
    PopupMenuItem(enabled: false, child: Text('Albums')),
    PopupMenuItem(value: 'album_name_asc', child: Text('Name A-Z')),
    PopupMenuItem(value: 'album_name_desc', child: Text('Name Z-A')),
    PopupMenuItem(value: 'album_tracks_desc', child: Text('Most Tracks')),
  ];

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
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
                        onPressed: () => Navigator.pushNamed(context, '/search'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Sort options',
                      onSelected: _applySortSelection,
                      itemBuilder: (_) => _buildSortMenuItems(),
                      child: const _LibraryControlPill(
                        icon: Icons.sort,
                        label: 'Sort',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LibraryControlPill(
                      icon: _libraryViewMode == LibraryViewMode.list
                          ? Icons.grid_view_rounded
                          : Icons.view_list,
                      label: _libraryViewMode == LibraryViewMode.list
                          ? 'Grid'
                          : 'List',
                      onTap: _toggleViewMode,
                    ),
                  ],
                ),
              ),
              if (_selectionActive) _buildSelectionBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _artworkStrokePink.withValues(alpha: 0.55),
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
                      Tab(text: 'Folders'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSongsTab(),
                          _buildAlbumsTab(),
                          _buildArtistsTab(),
                          _buildFoldersTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildSongsTab() {
    if (_tracks.isEmpty) return _buildEmptyState();
    final songs = _getSortedSongs();
    if (_libraryViewMode == LibraryViewMode.grid) {
      return _buildSongsGrid(songs);
    }
    final indexMap = _buildLetterIndex<Track>(
      items: songs,
      label: (track) => track.title,
    );

    final selectionMode = _selectedSongIds.isNotEmpty;
    return Stack(
      children: [
        ListView.builder(
          controller: _songsScrollController,
          itemCount: songs.length,
          itemBuilder: (context, i) {
            final track = songs[i];
            final isSelected = _selectedSongIds.contains(track.id);
            return _buildLibraryListRow(
              context,
              leading: TrackArtwork(
                track: track,
                size: 44,
                borderRadius: BorderRadius.circular(8),
                borderColor: _artworkStrokePink,
                borderWidth: 1.2,
              ),
              title: track.title,
              subtitle: '${track.artist} - ${track.album}',
              trailing: selectionMode
                  ? Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    )
                  : TrackMoreButton(
                      track: track,
                      showDelete: true,
                      onDeleted: () => _loadData(),
                    ),
              onTap: () => selectionMode
                  ? _toggleSongSelection(track)
                  : _playTrack(track, songs),
              onLongPress: () => _toggleSongSelection(track),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _songsScrollController,
                index: index,
                totalItems: songs.length,
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildAlbumsTab() {
    if (_albums.isEmpty) return _buildEmptyState();
    final sortedAlbums = _getSortedAlbumNames();
    if (_libraryViewMode == LibraryViewMode.grid) {
      return _buildAlbumsGrid(sortedAlbums);
    }
    final indexMap = _buildLetterIndex<String>(
      items: sortedAlbums,
      label: (album) => album,
    );

    final selectionMode = _selectedAlbumNames.isNotEmpty;
    return Stack(
      children: [
        ListView.builder(
          controller: _albumsScrollController,
          itemCount: sortedAlbums.length,
          itemBuilder: (context, i) {
            final albumName = sortedAlbums[i];
            final tracks = _albums[albumName]!;
            final firstTrack = tracks.first;
            final isSelected = _selectedAlbumNames.contains(albumName);

            return _buildLibraryListRow(
              context,
              leading: TrackArtwork(
                track: firstTrack,
                size: 44,
                borderRadius: BorderRadius.circular(8),
                fallbackIcon: Icons.album,
                borderColor: _artworkStrokePink,
                borderWidth: 1.2,
              ),
              title: albumName,
              subtitle: '${firstTrack.artist} - ${tracks.length} tracks',
              trailing: selectionMode
                  ? Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCollectionMenuButton(
                          title: albumName,
                          shareText:
                              'Album: $albumName\nArtist: ${firstTrack.artist}\nTracks: ${tracks.length}',
                          tracks: tracks,
                          deleteLabel: 'Delete album',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
              onTap: () => selectionMode
                  ? _toggleAlbumSelection(albumName)
                  : _openAlbum(albumName, tracks),
              onLongPress: () => _toggleAlbumSelection(albumName),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _albumsScrollController,
                index: index,
                totalItems: sortedAlbums.length,
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildArtistsTab() {
    if (_artists.isEmpty) return _buildEmptyState();
    final sortedArtists = _artists.keys.toList()..sort();

    if (_libraryViewMode == LibraryViewMode.grid) {
      return _buildArtistsGrid(sortedArtists);
    }

    final indexMap = _buildLetterIndex<String>(
      items: sortedArtists,
      label: (artist) => artist,
    );

    final selectionMode = _selectedArtistNames.isNotEmpty;
    return Stack(
      children: [
        ListView.builder(
          controller: _artistsScrollController,
          itemCount: sortedArtists.length,
          itemBuilder: (context, index) {
            final artistName = sortedArtists[index];
            final tracks = _artists[artistName]!;
            final albumCount = tracks.map((t) => t.album).toSet().length;
            final isSelected = _selectedArtistNames.contains(artistName);

            return _buildLibraryListRow(
              context,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _artworkStrokePink.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.person),
              ),
              title: artistName,
              subtitle: '${tracks.length} tracks - $albumCount albums',
              trailing: selectionMode
                  ? Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCollectionMenuButton(
                          title: artistName,
                          shareText:
                              'Artist: $artistName\nTracks: ${tracks.length}\nAlbums: $albumCount',
                          tracks: tracks,
                          deleteLabel: 'Delete artist',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
              onTap: () {
                if (selectionMode) {
                  _toggleArtistSelection(artistName);
                  return;
                }
                final audioProvider = context.read<AudioProvider>();
                audioProvider.setQueue(tracks);
                audioProvider.play();
              },
              onLongPress: () => _toggleArtistSelection(artistName),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _artistsScrollController,
                index: index,
                totalItems: sortedArtists.length,
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildFoldersTab() {
    if (_folders.isEmpty) return _buildEmptyState();
    final sortedFolders = _folders.keys.toList()..sort();

    if (_libraryViewMode == LibraryViewMode.grid) {
      return _buildFoldersGrid(sortedFolders);
    }

    final indexMap = _buildLetterIndex<String>(
      items: sortedFolders,
      label: (folder) => folder.split('/').last,
    );

    return Stack(
      children: [
        ListView.builder(
          controller: _foldersScrollController,
          itemCount: sortedFolders.length,
          itemBuilder: (context, index) {
            final folderPath = sortedFolders[index];
            final tracks = _folders[folderPath]!;
            final folderName = folderPath.split('/').last;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder),
                ),
                title: Text(
                  folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${tracks.length} tracks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final audioProvider = context.read<AudioProvider>();
                  audioProvider.setQueue(tracks);
                  audioProvider.play();
                },
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _foldersScrollController,
                index: index,
                totalItems: sortedFolders.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryListRow(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    VoidCallback? onLongPress,
    bool selected = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: leading,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: trailing,
          onTap: onTap,
          onLongPress: onLongPress,
          selected: selected,
          selectedTileColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 1,
            thickness: 1,
            color: _artworkStrokePink.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _artworkStrokePink.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
            ),
            Text(
              '$_selectionCount selected',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Share selected',
              onPressed: _shareSelection,
              icon: const Icon(Icons.share),
            ),
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _deleteSelection,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSelection() async {
    if (_isSongsTab) {
      await _shareSelectedSongs();
      return;
    }
    if (_isAlbumsTab) {
      final names = _selectedAlbumNames.toList()..sort();
      if (names.isEmpty) return;
      await Share.share(
        'Albums:\n${names.join('\n')}',
        subject: 'Albums',
      );
      return;
    }
    if (_isArtistsTab) {
      final names = _selectedArtistNames.toList()..sort();
      if (names.isEmpty) return;
      await Share.share(
        'Artists:\n${names.join('\n')}',
        subject: 'Artists',
      );
    }
  }

  Future<void> _shareSelectedSongs() async {
    final selectedTracks = _tracks
        .where((track) => _selectedSongIds.contains(track.id))
        .toList();
    if (selectedTracks.isEmpty) return;
    final shareText = selectedTracks
        .map((track) => '${track.title} - ${track.artist}')
        .join('\n');

    if (!kIsWeb) {
      final files = <XFile>[];
      for (final track in selectedTracks) {
        final file = File(track.path);
        if (await file.exists()) {
          files.add(XFile(track.path));
        }
      }
      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          subject: 'Songs',
          text: shareText,
        );
        return;
      }
    }

    await Share.share(
      shareText,
      subject: 'Songs',
    );
  }

  Future<void> _deleteSelection() async {
    if (_selectionCount == 0) return;
    final label = _isSongsTab
        ? 'Delete songs'
        : _isAlbumsTab
            ? 'Delete albums'
            : 'Delete artists';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: Text('Delete $_selectionCount selected item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final databaseService = context.read<DatabaseService>();
    final trackIdsToDelete = <String>{};
    if (_isSongsTab) {
      trackIdsToDelete.addAll(_selectedSongIds);
    } else if (_isAlbumsTab) {
      for (final albumName in _selectedAlbumNames) {
        final tracks = _albums[albumName] ?? [];
        trackIdsToDelete.addAll(tracks.map((track) => track.id));
      }
    } else if (_isArtistsTab) {
      for (final artistName in _selectedArtistNames) {
        final tracks = _artists[artistName] ?? [];
        trackIdsToDelete.addAll(tracks.map((track) => track.id));
      }
    }

    for (final trackId in trackIdsToDelete) {
      await databaseService.deleteTrack(trackId);
    }
    if (!mounted) return;
    _clearSelection();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selection deleted')),
    );
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No music in library',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your device to add music to your library',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSongsGrid(List<Track> songs) {
    final indexMap = _buildLetterIndex<Track>(
      items: songs,
      label: (track) => track.title,
    );
    return Stack(
      children: [
        GridView.builder(
          controller: _songsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final track = songs[index];
            final selectionMode = _selectedSongIds.isNotEmpty;
            final isSelected = _selectedSongIds.contains(track.id);
            return _buildPinkGridTile(
              context,
              track: track,
              title: track.title,
              subtitle: track.artist,
              fallbackIcon: Icons.music_note,
              menu: selectionMode
                  ? null
                  : TrackMoreButton(
                      track: track,
                      showDelete: true,
                      onDeleted: () => _loadData(),
                    ),
              onTap: () => selectionMode
                  ? _toggleSongSelection(track)
                  : _playTrack(track, songs),
              onLongPress: () => _toggleSongSelection(track),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _songsScrollController,
                index: index,
                totalItems: songs.length,
                itemsPerRow: 2,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsGrid(List<String> sortedAlbums) {
    final indexMap = _buildLetterIndex<String>(
      items: sortedAlbums,
      label: (album) => album,
    );
    return Stack(
      children: [
        GridView.builder(
          controller: _albumsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: sortedAlbums.length,
          itemBuilder: (context, index) {
            final albumName = sortedAlbums[index];
            final tracks = _albums[albumName]!;
            final firstTrack = tracks.first;
            final selectionMode = _selectedAlbumNames.isNotEmpty;
            final isSelected = _selectedAlbumNames.contains(albumName);
            return _buildPinkGridTile(
              context,
              track: firstTrack,
              title: albumName,
              subtitle: '${tracks.length} tracks',
              fallbackIcon: Icons.album,
              menu: selectionMode
                  ? null
                  : _buildCollectionMenuButton(
                      title: albumName,
                      shareText:
                          'Album: $albumName\nArtist: ${firstTrack.artist}\nTracks: ${tracks.length}',
                      tracks: tracks,
                      deleteLabel: 'Delete album',
                      compact: true,
                    ),
              onTap: () => selectionMode
                  ? _toggleAlbumSelection(albumName)
                  : _openAlbum(albumName, tracks),
              onLongPress: () => _toggleAlbumSelection(albumName),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _albumsScrollController,
                index: index,
                totalItems: sortedAlbums.length,
                itemsPerRow: 2,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPinkGridTile(
    BuildContext context, {
    required Track track,
    required String title,
    required String subtitle,
    required IconData fallbackIcon,
    required VoidCallback onTap,
    Widget? menu,
    VoidCallback? onLongPress,
    bool selected = false,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? _artworkStrokePink.withValues(alpha: 0.22)
              : _artworkStrokePink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _artworkStrokePink
                : _artworkStrokePink.withValues(alpha: 0.72),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artSize = constraints.maxWidth.floorToDouble();
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: artSize,
                      height: artSize,
                      child: TrackArtwork(
                        track: track,
                        size: artSize,
                        borderRadius: BorderRadius.circular(10),
                        fallbackIcon: fallbackIcon,
                        borderColor: _artworkStrokePink,
                        borderWidth: 1.2,
                        keepOldArtwork: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (menu != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: menu,
                  ),
                if (selected)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildArtistsGrid(List<String> sortedArtists) {
    final indexMap = _buildLetterIndex<String>(
      items: sortedArtists,
      label: (artist) => artist,
    );

    return Stack(
      children: [
        GridView.builder(
          controller: _artistsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: sortedArtists.length,
          itemBuilder: (context, index) {
            final artistName = sortedArtists[index];
            final tracks = _artists[artistName]!;
            final albumCount = tracks.map((t) => t.album).toSet().length;
            final firstTrack = tracks.first;
            final selectionMode = _selectedArtistNames.isNotEmpty;
            final isSelected = _selectedArtistNames.contains(artistName);

            return _buildPinkGridTile(
              context,
              track: firstTrack,
              title: artistName,
              subtitle: '${tracks.length} tracks - $albumCount albums',
              fallbackIcon: Icons.person,
              menu: selectionMode
                  ? null
                  : _buildCollectionMenuButton(
                      title: artistName,
                      shareText:
                          'Artist: $artistName\nTracks: ${tracks.length}\nAlbums: $albumCount',
                      tracks: tracks,
                      deleteLabel: 'Delete artist',
                      compact: true,
                    ),
              onTap: () {
                if (selectionMode) {
                  _toggleArtistSelection(artistName);
                  return;
                }
                final audioProvider = context.read<AudioProvider>();
                audioProvider.setQueue(tracks);
                audioProvider.play();
              },
              onLongPress: () => _toggleArtistSelection(artistName),
              selected: isSelected,
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _artistsScrollController,
                index: index,
                totalItems: sortedArtists.length,
                itemsPerRow: 2,
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildFoldersGrid(List<String> sortedFolders) {
    final indexMap = _buildLetterIndex<String>(
      items: sortedFolders,
      label: (folder) => folder.split('/').last,
    );

    return Stack(
      children: [
        GridView.builder(
          controller: _foldersScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: sortedFolders.length,
          itemBuilder: (context, index) {
            final folderPath = sortedFolders[index];
            final tracks = _folders[folderPath]!;
            final folderName = folderPath.split('/').last;

            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  final audioProvider = context.read<AudioProvider>();
                  audioProvider.setQueue(tracks);
                  audioProvider.play();
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.folder, size: 48),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        folderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tracks.length} tracks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _AlphabetSideBar(
            onLetterChanged: (letter) {
              final index = indexMap[letter];
              if (index == null) return;
              _jumpToIndex(
                controller: _foldersScrollController,
                index: index,
                totalItems: sortedFolders.length,
                itemsPerRow: 2,
              );
            },
          ),
        ),
      ],
    );
  }

  PopupMenuButton<_CollectionAction> _buildCollectionMenuButton({
    required String title,
    required String shareText,
    required List<Track> tracks,
    required String deleteLabel,
    bool compact = false,
  }) {
    return PopupMenuButton<_CollectionAction>(
      tooltip: '$title options',
      iconSize: compact ? 18 : 20,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      onSelected: (action) => _handleCollectionAction(
        action,
        title: title,
        shareText: shareText,
        tracks: tracks,
        deleteLabel: deleteLabel,
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _CollectionAction.share,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share),
            title: Text('Share'),
          ),
        ),
        PopupMenuItem(
          value: _CollectionAction.changeArtwork,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.image),
            title: Text('Change Artwork'),
          ),
        ),
        PopupMenuItem(
          value: _CollectionAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete'),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Future<void> _handleCollectionAction(
    _CollectionAction action, {
    required String title,
    required String shareText,
    required List<Track> tracks,
    required String deleteLabel,
  }) async {
    switch (action) {
      case _CollectionAction.share:
        await Share.share(shareText, subject: title);
        break;
      case _CollectionAction.changeArtwork:
        await _changeCollectionArtwork(title: title, tracks: tracks);
        break;
      case _CollectionAction.delete:
        await _deleteCollection(
          title: title,
          tracks: tracks,
          deleteLabel: deleteLabel,
        );
        break;
    }
  }

  Future<void> _changeCollectionArtwork({
    required String title,
    required List<Track> tracks,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final databaseService = context.read<DatabaseService>();
    final resolvedPath = await _cropArtworkPath(image);
    final updatedTracks =
        tracks
            .map((track) => track.copyWith(albumArtPath: resolvedPath))
            .toList();
    await databaseService.saveTracks(updatedTracks);
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Artwork updated for $title')),
    );
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

  Future<void> _deleteCollection({
    required String title,
    required List<Track> tracks,
    required String deleteLabel,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deleteLabel),
        content: Text('Delete "$title" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final databaseService = context.read<DatabaseService>();
    for (final track in tracks) {
      await databaseService.deleteTrack(track.id);
    }
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "$title"')),
    );
  }

  void _openAlbum(String albumName, List<Track> tracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(albumName: albumName, tracks: tracks),
      ),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final List<Track> tracks;

  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.tracks,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _largeIcons = false;

  @override
  Widget build(BuildContext context) {
    final sortedTracks = List<Track>.from(widget.tracks)
      ..sort((a, b) {
        final aNum = a.trackNumber ?? 0;
        final bNum = b.trackNumber ?? 0;
        if (aNum != bNum) return aNum.compareTo(bNum);
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

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
        content: Stack(
          children: [
            Padding(
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
                          return _buildLargeTrackTile(track, onTap);
                        }
                        return TrackListItem(track: track, onTap: onTap);
                      },
                    ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeTrackTile(Track track, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: TrackArtwork(
          track: track,
          size: 64,
          borderRadius: BorderRadius.circular(12),
          borderColor: _artworkStrokePink,
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
}

class _AlphabetSideBar extends StatefulWidget {
  static const List<String> _letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  final ValueChanged<String> onLetterChanged;

  const _AlphabetSideBar({required this.onLetterChanged});

  @override
  State<_AlphabetSideBar> createState() => _AlphabetSideBarState();
}

class _AlphabetSideBarState extends State<_AlphabetSideBar> {
  static const double _idleOpacity = 0.25;
  static const double _activeOpacity = 1.0;
  static const double _itemHeight = 14.0;
  static const double _lensSize = 40.0;
  Timer? _fadeTimer;
  Timer? _lensTimer;
  bool _active = false;
  bool _showLens = false;
  String _currentLetter = 'A';
  double _lensY = 0;

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _lensTimer?.cancel();
    super.dispose();
  }

  void _bump() {
    if (!_active) {
      setState(() => _active = true);
    }
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _active = false);
    });
  }

  void _selectAt({
    required String letter,
    required double localY,
    required double totalHeight,
  }) {
    _lensTimer?.cancel();
    setState(() {
      _currentLetter = letter;
      _lensY = localY.clamp(0.0, totalHeight - _itemHeight).toDouble();
      _showLens = true;
    });
    _lensTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() => _showLens = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = _AlphabetSideBar._letters.length * _itemHeight;

    String letterAt(Offset localPosition) {
      final y = localPosition.dy.clamp(0, totalHeight - 1);
      final index = (y / _itemHeight)
          .floor()
          .clamp(0, _AlphabetSideBar._letters.length - 1);
      return _AlphabetSideBar._letters[index];
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: MouseRegion(
        onEnter: (_) => _bump(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragDown: (details) {
            _bump();
            final letter = letterAt(details.localPosition);
            widget.onLetterChanged(letter);
            _selectAt(
              letter: letter,
              localY: details.localPosition.dy,
              totalHeight: totalHeight,
            );
          },
          onVerticalDragUpdate: (details) {
            _bump();
            final letter = letterAt(details.localPosition);
            widget.onLetterChanged(letter);
            _selectAt(
              letter: letter,
              localY: details.localPosition.dy,
              totalHeight: totalHeight,
            );
          },
          onVerticalDragEnd: (_) {
            _lensTimer?.cancel();
            _lensTimer = Timer(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              setState(() => _showLens = false);
            });
          },
          onTapDown: (details) {
            _bump();
            final letter = letterAt(details.localPosition);
            widget.onLetterChanged(letter);
            _selectAt(
              letter: letter,
              localY: details.localPosition.dy,
              totalHeight: totalHeight,
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedOpacity(
                opacity: _active ? _activeOpacity : _idleOpacity,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 22,
                  height: totalHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _AlphabetSideBar._letters.map((letter) {
                      return SizedBox(
                        height: _itemHeight,
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_showLens)
                Positioned(
                  right: 28,
                  top: (_lensY - (_lensSize / 2))
                      .clamp(0.0, totalHeight - _lensSize)
                      .toDouble(),
                  child: Container(
                    width: _lensSize,
                    height: _lensSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentLetter,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
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
}

class _LibraryControlPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _LibraryControlPill({
    required this.icon,
    required this.label,
    this.onTap,
  });

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
