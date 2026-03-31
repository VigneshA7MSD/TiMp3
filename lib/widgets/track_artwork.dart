import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/track.dart';

class TrackArtwork extends StatelessWidget {
  final Track track;
  final double size;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final Color? borderColor;
  final double borderWidth;
  final bool keepOldArtwork;

  const TrackArtwork({
    super.key,
    required this.track,
    this.size = 48,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.fallbackIcon = Icons.music_note,
    this.borderColor,
    this.borderWidth = 0,
    this.keepOldArtwork = true,
  });

  @override
  Widget build(BuildContext context) {
    final albumId = _albumIdFromTrack(track);
    final audioId = int.tryParse(track.id);
    final customArtworkPath = _customArtworkPathFromTrack(track);
    final remoteArtworkUrl = _remoteArtworkUrlFromTrack(track);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final pixelSize = (size * devicePixelRatio).round();

    final Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: Icon(fallbackIcon),
    );

    final Widget artwork;
    if (customArtworkPath != null) {
      artwork = ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(customArtworkPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixelSize,
          cacheHeight: pixelSize,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } else if (remoteArtworkUrl != null) {
      artwork = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          remoteArtworkUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixelSize,
          cacheHeight: pixelSize,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    } else {
      final Widget queryArtwork;
      if (audioId != null) {
        final Widget albumFallback = albumId == null
            ? fallback
            : QueryArtworkWidget(
                key: ValueKey('art-album-$albumId-${size.toStringAsFixed(2)}'),
                id: albumId,
                type: ArtworkType.ALBUM,
                artworkFit: BoxFit.cover,
                artworkHeight: size,
                artworkWidth: size,
                keepOldArtwork: keepOldArtwork,
                nullArtworkWidget: fallback,
              );
        queryArtwork = QueryArtworkWidget(
          key: ValueKey('art-audio-$audioId-${size.toStringAsFixed(2)}'),
          id: audioId,
          type: ArtworkType.AUDIO,
          artworkFit: BoxFit.cover,
          artworkHeight: size,
          artworkWidth: size,
          keepOldArtwork: keepOldArtwork,
          nullArtworkWidget: albumFallback,
        );
      } else if (albumId != null) {
        queryArtwork = QueryArtworkWidget(
          key: ValueKey('art-album-$albumId-${size.toStringAsFixed(2)}'),
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkHeight: size,
          artworkWidth: size,
          keepOldArtwork: keepOldArtwork,
          nullArtworkWidget: fallback,
        );
      } else {
        queryArtwork = fallback;
      }

      artwork = RepaintBoundary(
        child: ClipRRect(borderRadius: borderRadius, child: queryArtwork),
      );
    }

    final hasBorder = borderColor != null && borderWidth > 0;
    if (!hasBorder) return artwork;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          artwork,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: borderColor!, width: borderWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? _albumIdFromTrack(Track track) {
    final raw = track.albumArtPath;
    if (raw == null || raw.isEmpty || !raw.startsWith('album_')) return null;
    return int.tryParse(raw.substring('album_'.length));
  }

  String? _customArtworkPathFromTrack(Track track) {
    final raw = track.albumArtPath;
    if (raw == null || raw.isEmpty || raw.startsWith('album_')) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
    if (kIsWeb) return null;
    final file = File(raw);
    if (!file.existsSync()) return null;
    return raw;
  }

  String? _remoteArtworkUrlFromTrack(Track track) {
    final raw = track.albumArtPath;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }
}
