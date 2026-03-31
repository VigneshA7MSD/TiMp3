import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

class FileScannerService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.request();
      final storageStatus = await Permission.storage.request();
      final manageStatus = await Permission.manageExternalStorage.request();

      return audioStatus.isGranted ||
          storageStatus.isGranted ||
          manageStatus.isGranted;
    }
    return true; // iOS handles permissions differently
  }

  Future<List<Track>> scanForMusicFiles() async {
    if (kIsWeb) return <Track>[];
    if (!await requestStoragePermission()) {
      throw Exception('Storage permission denied');
    }

    try {
      final tracksByPath = <String, Track>{};

      final mediaStoreTracks = await _scanMediaStoreTracks();
      for (final track in mediaStoreTracks) {
        final key = _trackPathKey(track.path);
        if (key.isNotEmpty) {
          tracksByPath[key] = track;
        }
      }

      final fileSystemTracks = await _scanFileSystemTracks();
      for (final track in fileSystemTracks) {
        final key = _trackPathKey(track.path);
        if (key.isNotEmpty) {
          tracksByPath.putIfAbsent(key, () => track);
        }
      }

      final tracks = tracksByPath.values.toList()
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return tracks;
    } catch (e) {
      throw Exception('Failed to scan music files: $e');
    }
  }

  Future<List<Track>> _scanMediaStoreTracks() async {
    final songsExternal = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
    );

    final songsInternal = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.INTERNAL,
    );

    final tracks = <Track>[];
    for (final song in [...songsExternal, ...songsInternal]) {
      tracks.add(_trackFromSong(song));
    }
    return tracks;
  }

  Future<List<Track>> _scanFileSystemTracks() async {
    if (kIsWeb || !Platform.isAndroid) return <Track>[];

    final roots = <Directory>[
      Directory('/storage/emulated/0'),
      Directory('/sdcard'),
    ];

    final storageDir = Directory('/storage');
    if (await storageDir.exists()) {
      try {
        final candidates = await storageDir.list().toList();
        for (final entry in candidates) {
          if (entry is Directory) {
            roots.add(entry);
          }
        }
      } catch (_) {}
    }

    final seenPaths = <String>{};
    final tracks = <Track>[];

    for (final root in roots) {
      if (!await root.exists()) continue;

      await for (final entity in root
          .list(recursive: true, followLinks: false)
          .handleError((_) {})) {
        if (entity is! File) continue;

        final lowerPath = entity.path.toLowerCase();
        if (!lowerPath.endsWith('.mp3')) continue;
        if (_isExcludedPath(lowerPath)) continue;

        final normalizedPath = _trackPathKey(entity.path);
        if (normalizedPath.isEmpty || seenPaths.contains(normalizedPath)) {
          continue;
        }
        seenPaths.add(normalizedPath);

        try {
          final stat = await entity.stat();
          tracks.add(
            Track(
              id: 'fs_${entity.path.hashCode}',
              title: p.basenameWithoutExtension(entity.path),
              artist: 'Unknown Artist',
              album: 'Unknown Album',
              path: entity.path,
              duration: Duration.zero,
              size: stat.size,
              dateAdded: stat.modified,
              dateModified: stat.modified,
              genre: null,
              year: null,
              trackNumber: null,
              albumArtPath: null,
            ),
          );
        } catch (_) {
          // Ignore inaccessible files.
        }
      }
    }

    return tracks;
  }

  Track _trackFromSong(SongModel song) {
    final selectedPath = _resolveSongPath(song);

    return Track(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album ?? 'Unknown Album',
      path: selectedPath,
      duration: Duration(milliseconds: song.duration ?? 0),
      size: song.size,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(song.dateAdded ?? 0),
      dateModified: song.dateModified != null
          ? DateTime.fromMillisecondsSinceEpoch(song.dateModified!)
          : null,
      genre: song.genre,
      year: null,
      trackNumber: song.track,
      albumArtPath: song.albumId != null ? 'album_${song.albumId}' : null,
    );
  }

  String _resolveSongPath(SongModel song) {
    final dataPath = song.data.trim();
    if (dataPath.isNotEmpty) return dataPath;

    final rawUri = (song.uri ?? '').trim();
    if (rawUri.isEmpty) return '';

    final parsed = Uri.tryParse(rawUri);
    if (parsed != null && parsed.scheme.toLowerCase() == 'file') {
      final filePath = parsed.toFilePath();
      if (filePath.trim().isNotEmpty) return filePath.trim();
    }
    return rawUri;
  }

  String _trackPathKey(String path) {
    return path.replaceAll('\\', '/').trim().toLowerCase();
  }

  bool _isExcludedPath(String lowerPath) {
    return lowerPath.contains('/android/data/') ||
        lowerPath.contains('/android/obb/') ||
        lowerPath.contains('/android/media/') ||
        lowerPath.contains('/.thumbnails/');
  }

  Future<List<Track>> getSongsFromAlbum(int albumId) async {
    try {
      final songs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ALBUM_ID,
        albumId,
        sortType: SongSortType.TITLE,
      );

      return songs.map((song) => Track(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        album: song.album ?? 'Unknown Album',
        path: song.uri ?? '',
        duration: Duration(milliseconds: song.duration ?? 0),
        size: song.size,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(song.dateAdded ?? 0),
        dateModified: song.dateModified != null
            ? DateTime.fromMillisecondsSinceEpoch(song.dateModified!)
            : null,
        genre: song.genre,
        year: null,
        trackNumber: song.track,
        albumArtPath: song.albumId != null ? 'album_${song.albumId}' : null,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Track>> getSongsFromArtist(int artistId) async {
    try {
      final songs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ARTIST_ID,
        artistId,
        sortType: SongSortType.ALBUM,
      );

      return songs.map((song) => Track(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        album: song.album ?? 'Unknown Album',
        path: song.uri ?? '',
        duration: Duration(milliseconds: song.duration ?? 0),
        size: song.size,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(song.dateAdded ?? 0),
        dateModified: song.dateModified != null
            ? DateTime.fromMillisecondsSinceEpoch(song.dateModified!)
            : null,
        genre: song.genre,
        year: null,
        trackNumber: song.track,
        albumArtPath: song.albumId != null ? 'album_${song.albumId}' : null,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Uint8List?> getAlbumArtwork(int albumId) async {
    try {
      return await _audioQuery.queryArtwork(albumId, ArtworkType.AUDIO);
    } catch (e) {
      return null;
    }
  }

  Future<List<AlbumModel>> getAlbums() async {
    try {
      return await _audioQuery.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<ArtistModel>> getArtists() async {
    try {
      return await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<GenreModel>> getGenres() async {
    try {
      return await _audioQuery.queryGenres(
        sortType: GenreSortType.GENRE,
        orderType: OrderType.ASC_OR_SMALLER,
      );
    } catch (e) {
      return [];
    }
  }
}
