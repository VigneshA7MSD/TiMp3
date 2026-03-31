import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/track.dart';

class LyricsResult {
  LyricsResult({
    required this.plainLyrics,
    required this.syncedLyrics,
    required this.instrumental,
  });

  final String? plainLyrics;
  final String? syncedLyrics;
  final bool instrumental;
}

class LyricsService {
  static const String _host = 'lrclib.net';
  static const String _getPath = '/api/get';

  Future<LyricsResult?> fetchLyrics(Track track) async {
    final uri = Uri.https(_host, _getPath, {
      'track_name': track.title,
      'artist_name': track.artist,
      'album_name': track.album,
      'duration': track.duration.inSeconds.toString(),
    });

    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'timp3player/1.0'},
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('Lyrics request failed with ${response.statusCode}');
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    return LyricsResult(
      plainLyrics: payload['plainLyrics'] as String?,
      syncedLyrics: payload['syncedLyrics'] as String?,
      instrumental: payload['instrumental'] == true,
    );
  }
}
