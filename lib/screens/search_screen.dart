import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/online_music_service.dart';
import '../providers/audio_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/track_list_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _allTracks = [];
  List<Track> _localResults = [];
  List<Track> _onlineResults = [];
  bool _isLoading = true;
  bool _isSearchingOnline = false;
  String? _onlineError;
  List<Track> _onlineCatalog = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);

    final databaseService = context.read<DatabaseService>();
    _allTracks = databaseService.getAllTracks();
    try {
      _onlineCatalog = await context.read<OnlineMusicService>().fetchTracks();
    } catch (error) {
      _onlineCatalog = [];
      _onlineError = error.toString().replaceFirst('Exception: ', '');
    }

    setState(() => _isLoading = false);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _onlineResults = [];
        _onlineError = null;
        _isSearchingOnline = false;
      });
      return;
    }

    final localResults = _allTracks.where((track) {
      return track.title.toLowerCase().contains(query) ||
          track.artist.toLowerCase().contains(query) ||
          track.album.toLowerCase().contains(query);
    }).toList();

    setState(() {
      _localResults = localResults;
      _onlineResults = _onlineCatalog
          .where((track) {
            return track.title.toLowerCase().contains(query) ||
                track.artist.toLowerCase().contains(query) ||
                track.album.toLowerCase().contains(query);
          })
          .toList(growable: false);
      _isSearchingOnline = false;
      _onlineError = null;
    });
  }

  void _playTrack(Track track, List<Track> queue) {
    final audioProvider = context.read<AudioProvider>();
    final trackIndex = queue.indexOf(track);
    audioProvider.setQueue(queue, startIndex: trackIndex);
    audioProvider.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
          autofocus: true,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _localResults = [];
                  _onlineResults = [];
                  _onlineError = null;
                  _isSearchingOnline = false;
                });
              },
            ),
        ],
      ),
      body: AppBackground(
        content: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _searchController.text.isEmpty
            ? _buildSearchSuggestions()
            : _localResults.isEmpty &&
                  _onlineResults.isEmpty &&
                  !_isSearchingOnline &&
                  _onlineError == null
            ? _buildNoResults()
            : _buildSearchResults(_searchController.text.trim()),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    // Get recent searches or popular tracks
    final recentTracks = _allTracks.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Tracks',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recentTracks.length,
            itemBuilder: (context, index) {
              final track = recentTracks[index];
              return TrackListItem(
                track: track,
                onTap: () => _playTrack(track, recentTracks),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for a different song, artist, or album',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    return ListView(
      children: [
        if (_localResults.isNotEmpty) ...[
          _buildResultHeader('On this device', _localResults.length),
          ..._localResults.map(
            (track) => TrackListItem(
              track: track,
              onTap: () => _playTrack(track, _localResults),
            ),
          ),
        ],
        _buildResultHeader('Online tracks', _onlineResults.length),
        if (_isSearchingOnline)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_onlineError != null)
          _buildInfoCard(_onlineError!)
        else if (_onlineResults.isEmpty)
          _buildInfoCard('No online matches found for "$query".')
        else
          ..._onlineResults.map(
            (track) => TrackListItem(
              track: track,
              onTap: () => _playTrack(track, _onlineResults),
              enableTrackMenu: false,
              trailing: const Icon(Icons.cloud_queue_outlined),
            ),
          ),
      ],
    );
  }

  Widget _buildResultHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
