import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/bookmark.dart';
import '../models/settings.dart';
import '../models/duration_adapter.dart';

class DatabaseService {
  static const String tracksBoxName = 'tracks';
  static const String playlistsBoxName = 'playlists';
  static const String bookmarksBoxName = 'bookmarks';
  static const String settingsBoxName = 'settings';

  late Box<Track> _tracksBox;
  late Box<Playlist> _playlistsBox;
  late Box<Bookmark> _bookmarksBox;
  late Box<AppSettings> _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(DurationAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TrackAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PlaylistAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SmartPlaylistTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(RepeatModeAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(EqualizerPresetAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ThemeModeAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(NowPlayingStyleAdapter());
    }

    // Open boxes
    _tracksBox = await Hive.openBox<Track>(tracksBoxName);
    _playlistsBox = await Hive.openBox<Playlist>(playlistsBoxName);
    _bookmarksBox = await Hive.openBox<Bookmark>(bookmarksBoxName);
    _settingsBox = await Hive.openBox<AppSettings>(settingsBoxName);

    // Initialize default settings if not exists
    if (_settingsBox.isEmpty) {
      await _settingsBox.put('settings', AppSettings());
    }
  }

  // Track operations
  Future<void> saveTrack(Track track) async {
    await _tracksBox.put(track.id, track);
  }

  Future<void> saveTracks(List<Track> tracks) async {
    final map = <String, Track>{};
    for (final track in tracks) {
      final existing = _tracksBox.get(track.id);
      final preservedAlbumArtPath = _resolveAlbumArtPath(
        existing: existing,
        scanned: track,
      );
      // Preserve user/runtime metadata that scanners don't know about.
      map[track.id] = track.copyWith(
        playCount: existing?.playCount ?? track.playCount,
        lastPlayed: existing?.lastPlayed ?? track.lastPlayed,
        albumArtPath: preservedAlbumArtPath,
      );
    }
    await _tracksBox.putAll(map);
  }

  Track? getTrack(String id) {
    return _tracksBox.get(id);
  }

  List<Track> getAllTracks() {
    final dedupedByPath = <String, Track>{};
    final fallbackById = <String, Track>{};

    for (final track in _tracksBox.values) {
      final pathKey = _trackPathKey(track.path);
      if (pathKey.isEmpty) {
        fallbackById[track.id] = track;
        continue;
      }

      final existing = dedupedByPath[pathKey];
      if (existing == null || _isBetterTrackCandidate(track, existing)) {
        dedupedByPath[pathKey] = track;
      }
    }

    return [...dedupedByPath.values, ...fallbackById.values];
  }

  Future<void> deleteTrack(String id) async {
    await _tracksBox.delete(id);
  }

  Future<void> updateTrackPlayCount(String trackId) async {
    final track = getTrack(trackId);
    if (track != null) {
      final updatedTrack = track.copyWith(
        playCount: track.playCount + 1,
        lastPlayed: DateTime.now(),
      );
      await saveTrack(updatedTrack);
    }
  }

  // Playlist operations
  Future<void> savePlaylist(Playlist playlist) async {
    await _playlistsBox.put(playlist.id, playlist);
  }

  Playlist? getPlaylist(String id) {
    return _playlistsBox.get(id);
  }

  List<Playlist> getAllPlaylists() {
    return _playlistsBox.values.toList();
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistsBox.delete(id);
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = getPlaylist(playlistId);
    if (playlist != null && !playlist.trackIds.contains(trackId)) {
      final updatedPlaylist = playlist.copyWith(
        trackIds: [...playlist.trackIds, trackId],
        dateModified: DateTime.now(),
      );
      await savePlaylist(updatedPlaylist);
    }
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    final playlist = getPlaylist(playlistId);
    if (playlist != null) {
      final updatedTrackIds = playlist.trackIds
          .where((id) => id != trackId)
          .toList();
      final updatedPlaylist = playlist.copyWith(
        trackIds: updatedTrackIds,
        dateModified: DateTime.now(),
      );
      await savePlaylist(updatedPlaylist);
    }
  }

  // Bookmark operations
  Future<void> saveBookmark(Bookmark bookmark) async {
    await _bookmarksBox.put(bookmark.id, bookmark);
  }

  List<Bookmark> getBookmarksForTrack(String trackId) {
    return _bookmarksBox.values
        .where((bookmark) => bookmark.trackId == trackId)
        .toList();
  }

  List<Bookmark> getAllBookmarks() {
    return _bookmarksBox.values.toList();
  }

  Future<void> deleteBookmark(String id) async {
    await _bookmarksBox.delete(id);
  }

  // Settings operations
  AppSettings getSettings() {
    return _settingsBox.get('settings') ?? AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put('settings', settings);
  }

  ValueListenable<Box<AppSettings>> getSettingsListenable() {
    return _settingsBox.listenable();
  }

  ValueListenable<Box<Track>> getTracksListenable() {
    return _tracksBox.listenable();
  }

  ValueListenable<Box<Playlist>> getPlaylistsListenable() {
    return _playlistsBox.listenable();
  }

  // Smart playlists
  List<Track> getRecentlyPlayed({int limit = 50}) {
    final tracks = getAllTracks()
      ..sort((a, b) {
        if (a.lastPlayed == null && b.lastPlayed == null) return 0;
        if (a.lastPlayed == null) return 1;
        if (b.lastPlayed == null) return -1;
        return b.lastPlayed!.compareTo(a.lastPlayed!);
      });
    return tracks.take(limit).toList();
  }

  List<Track> getMostPlayed({int limit = 50}) {
    final tracks = getAllTracks()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return tracks.take(limit).toList();
  }

  List<Track> getRecentlyAdded({int limit = 50}) {
    final tracks = getAllTracks()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return tracks.take(limit).toList();
  }

  Future<void> clearAllData() async {
    await _tracksBox.clear();
    await _playlistsBox.clear();
    await _bookmarksBox.clear();
    await _settingsBox.clear();
    await _settingsBox.put('settings', AppSettings());
  }

  Future<void> close() async {
    await _tracksBox.close();
    await _playlistsBox.close();
    await _bookmarksBox.close();
    await _settingsBox.close();
  }

  String _trackPathKey(String path) {
    return path.replaceAll('\\', '/').trim().toLowerCase();
  }

  bool _isBetterTrackCandidate(Track next, Track current) {
    final nextHasArt = _hasArtwork(next);
    final currentHasArt = _hasArtwork(current);
    if (nextHasArt != currentHasArt) return nextHasArt;

    final nextUnknown = _unknownMetadataCount(next);
    final currentUnknown = _unknownMetadataCount(current);
    if (nextUnknown != currentUnknown) return nextUnknown < currentUnknown;

    if (next.duration != current.duration) {
      return next.duration > current.duration;
    }

    // Prefer MediaStore ids over fallback fs_* ids when quality is equal.
    final nextIsFs = next.id.startsWith('fs_');
    final currentIsFs = current.id.startsWith('fs_');
    if (nextIsFs != currentIsFs) return !nextIsFs;

    return false;
  }

  bool _hasArtwork(Track track) {
    final art = track.albumArtPath;
    return art != null && art.trim().isNotEmpty;
  }

  int _unknownMetadataCount(Track track) {
    var score = 0;
    if (track.artist == 'Unknown Artist') score++;
    if (track.album == 'Unknown Album') score++;
    return score;
  }

  String? _resolveAlbumArtPath({
    required Track? existing,
    required Track scanned,
  }) {
    final existingArt = existing?.albumArtPath;
    if (_isCustomArtworkPath(existingArt)) {
      return existingArt;
    }
    return scanned.albumArtPath;
  }

  bool _isCustomArtworkPath(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    return !path.startsWith('album_');
  }
}
