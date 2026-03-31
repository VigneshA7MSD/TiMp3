import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/track.dart';

class OnlineMusicException implements Exception {
  const OnlineMusicException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnlineMusicService {
  OnlineMusicService({
    required SupabaseClient? client,
    required String projectUrl,
  }) : _client = client,
       _projectUrl = projectUrl;

  final SupabaseClient? _client;
  final String _projectUrl;

  bool get isConfigured => _client != null && _projectUrl.isNotEmpty;

  Future<List<Track>> fetchTracks({int limit = 200}) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('tracks')
          .select(
            'id, title, artist, album, audio_path, artwork_path, duration_sec, created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      return rows
          .whereType<Map<String, dynamic>>()
          .map<Track?>((row) => _mapRowToTrack(row))
          .whereType<Track>()
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw OnlineMusicException(
        error.message.isEmpty
            ? 'Cloud music is unavailable right now.'
            : error.message,
      );
    } catch (error) {
      throw _mapUnknownError(error);
    }
  }

  Future<List<Track>> searchSongs(String query, {int limit = 200}) async {
    final trimmedQuery = query.trim().toLowerCase();
    final tracks = await fetchTracks(limit: limit);
    if (trimmedQuery.isEmpty) return tracks;
    return tracks
        .where((track) {
          return track.title.toLowerCase().contains(trimmedQuery) ||
              track.artist.toLowerCase().contains(trimmedQuery) ||
              track.album.toLowerCase().contains(trimmedQuery);
        })
        .toList(growable: false);
  }

  Track? _mapRowToTrack(Map<String, dynamic> row) {
    final id = _stringValue(row['id']);
    final title = _stringValue(row['title']);
    final audioPath = _stringValue(row['audio_path']);
    if (id == null || title == null || audioPath == null) return null;

    final artist = _stringValue(row['artist']) ?? 'Unknown Artist';
    final album = _stringValue(row['album']) ?? 'Unknown Album';
    final durationSeconds = _intValue(row['duration_sec']) ?? 0;
    final artworkPath = _stringValue(row['artwork_path']);
    final createdAt = DateTime.tryParse(_stringValue(row['created_at']) ?? '');

    return Track(
      id: 'online_$id',
      title: title,
      artist: artist,
      album: album,
      path: _buildPublicUrl('audio', audioPath),
      duration: Duration(seconds: durationSeconds),
      size: 0,
      dateAdded: createdAt ?? DateTime.now(),
      albumArtPath: artworkPath == null
          ? null
          : _buildPublicUrl('artwork', artworkPath),
    );
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const OnlineMusicException(
        'Cloud music is not configured in this build.',
      );
    }
    return client;
  }

  OnlineMusicException _mapPostgrestError(PostgrestException error) {
    if (error.code == '42501') {
      return const OnlineMusicException(
        'Cloud music permission is not set correctly.',
      );
    }
    if (error.code == '401') {
      return const OnlineMusicException(
        'Cloud music authentication failed.',
      );
    }
    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection')) {
      return const OnlineMusicException(
        'No internet connection. Check your network and try again.',
      );
    }
    return const OnlineMusicException(
      'Unable to load cloud music right now.',
    );
  }

  OnlineMusicException _mapUnknownError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection')) {
      return const OnlineMusicException(
        'No internet connection. Check your network and try again.',
      );
    }
    return const OnlineMusicException(
      'Unable to load cloud music right now.',
    );
  }

  String _buildPublicUrl(String bucket, String path) {
    final normalizedBase = _projectUrl.endsWith('/')
        ? _projectUrl.substring(0, _projectUrl.length - 1)
        : _projectUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$normalizedBase/storage/v1/object/public/$bucket/$normalizedPath';
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void close() {}
}
