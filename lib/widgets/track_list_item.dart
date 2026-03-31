import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../services/database_service.dart';
import 'track_artwork.dart';

class TrackListItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isPlaying;
  final bool enableTrackMenu;
  final bool showDelete;
  final VoidCallback? onDeleted;

  const TrackListItem({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.isPlaying = false,
    this.enableTrackMenu = true,
    this.showDelete = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final menuButton = enableTrackMenu
        ? TrackMoreButton(
            track: track,
            showDelete: showDelete,
            onDeleted: onDeleted,
          )
        : const SizedBox.shrink();

    final combinedTrailing = trailing == null
        ? (enableTrackMenu ? menuButton : null)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              trailing!,
              if (enableTrackMenu) menuButton,
            ],
          );

    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          TrackArtwork(
            track: track,
            size: 44,
            borderRadius: BorderRadius.circular(8),
          ),
          if (isPlaying)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${track.artist} - ${track.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: combinedTrailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

enum _TrackAction {
  playNext,
  addToPlaylist,
  enqueue,
  ringtone,
  changeArtwork,
  removeCustomArtwork,
  share,
  delete,
}

class TrackMoreButton extends StatelessWidget {
  final Track track;
  final bool showDelete;
  final VoidCallback? onDeleted;

  const TrackMoreButton({
    super.key,
    required this.track,
    this.showDelete = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TrackAction>(
      tooltip: 'Track options',
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _TrackAction.playNext,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.skip_next),
            title: Text('Play Next'),
          ),
        ),
        const PopupMenuItem(
          value: _TrackAction.addToPlaylist,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.playlist_add),
            title: Text('Add to Playlist'),
          ),
        ),
        const PopupMenuItem(
          value: _TrackAction.enqueue,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.queue_music),
            title: Text('Enqueue'),
          ),
        ),
        const PopupMenuItem(
          value: _TrackAction.ringtone,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.ring_volume),
            title: Text('Set as Ringtone'),
          ),
        ),
        const PopupMenuItem(
          value: _TrackAction.changeArtwork,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.image),
            title: Text('Change Artwork'),
          ),
        ),
        if (_hasCustomArtwork(track))
          const PopupMenuItem(
            value: _TrackAction.removeCustomArtwork,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.hide_image_outlined),
              title: Text('Remove Custom Artwork'),
            ),
          ),
        const PopupMenuItem(
          value: _TrackAction.share,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share),
            title: Text('Share'),
          ),
        ),
        if (showDelete)
          const PopupMenuItem(
            value: _TrackAction.delete,
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

  Future<void> _handleAction(BuildContext context, _TrackAction action) async {
    switch (action) {
      case _TrackAction.playNext:
        await context.read<AudioProvider>().playNext(track);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${track.title} will play next')),
        );
        break;
      case _TrackAction.addToPlaylist:
        await _addToPlaylist(context);
        break;
      case _TrackAction.enqueue:
        await context.read<AudioProvider>().addToQueue(track);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enqueued ${track.title}')),
        );
        break;
      case _TrackAction.ringtone:
        _setAsRingtone(context);
        break;
      case _TrackAction.changeArtwork:
        await _changeArtwork(context);
        break;
      case _TrackAction.removeCustomArtwork:
        await _removeCustomArtwork(context);
        break;
      case _TrackAction.share:
        await _shareTrack(context);
        break;
      case _TrackAction.delete:
        await _deleteTrack(context);
        break;
    }
  }

  Future<void> _addToPlaylist(BuildContext context) async {
    final databaseService = context.read<DatabaseService>();
    final playlists = databaseService
        .getAllPlaylists()
        .where((p) => p.smartType == null)
        .toList();

    if (playlists.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlist found. Create one first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Playlist>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Add to Playlist'), dense: true),
              ...playlists.map(
                (playlist) => ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.trackIds.length} tracks'),
                  onTap: () => Navigator.of(sheetContext).pop(playlist),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await databaseService.addTrackToPlaylist(selected.id, track.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to ${selected.name}')),
    );
  }

  void _setAsRingtone(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringtone is available on Android only.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set ringtone requires native integration.')),
    );
  }

  Future<void> _changeArtwork(BuildContext context) async {
    final audioProvider = context.read<AudioProvider>();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final resolvedPath = await _cropArtworkPath(image);
    final updated = track.copyWith(albumArtPath: resolvedPath);
    await audioProvider.updateTrackMetadata(updated);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Artwork updated')),
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

  Future<void> _removeCustomArtwork(BuildContext context) async {
    if (!_hasCustomArtwork(track)) return;
    final updated = track.copyWith(albumArtPath: null);
    await context.read<AudioProvider>().updateTrackMetadata(updated);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom artwork removed')),
    );
  }

  Future<void> _shareTrack(BuildContext context) async {
    final shareText =
        '${track.title}\nArtist: ${track.artist}\nAlbum: ${track.album}';
    final file = File(track.path);
    if (!kIsWeb && await file.exists()) {
      await Share.shareXFiles(
        [XFile(track.path)],
        subject: track.title,
        text: shareText,
      );
      return;
    }

    await Share.share(
      '$shareText\nPath: ${track.path}',
      subject: track.title,
    );
    if (!context.mounted) return;
  }

  Future<void> _deleteTrack(BuildContext context) async {
    final databaseService = context.read<DatabaseService>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete song'),
        content: Text('Delete "${track.title}" from your library?'),
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
    await databaseService.deleteTrack(track.id);
    if (!context.mounted) return;
    onDeleted?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${track.title}')),
    );
  }

  bool _hasCustomArtwork(Track track) {
    final art = track.albumArtPath;
    return art != null && art.isNotEmpty && !art.startsWith('album_');
  }
}
