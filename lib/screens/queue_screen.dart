import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/track_list_item.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          Consumer<AudioProvider>(
            builder: (context, audioProvider, child) {
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: audioProvider.queue.isEmpty
                    ? null
                    : () => _showClearQueueDialog(context),
                tooltip: 'Clear queue',
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        content: Consumer<AudioProvider>(
          builder: (context, audioProvider, child) {
            final queue = audioProvider.queue;
            final currentTrack = audioProvider.currentTrack;

            if (queue.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.queue_music, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Queue is empty',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      'Add some tracks to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: (oldIndex, newIndex) {
                _reorderQueue(context, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final track = queue[index];
                final isCurrentTrack = track == currentTrack;
                final enableTrackMenu = !_isRemoteTrack(track);

                return TrackListItem(
                  key: ValueKey(track.id),
                  track: track,
                  onTap: () => audioProvider.skipToIndex(index),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => audioProvider.removeFromQueue(index),
                    tooltip: 'Remove from queue',
                  ),
                  enableTrackMenu: enableTrackMenu,
                  isPlaying: isCurrentTrack && audioProvider.isPlaying,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _reorderQueue(BuildContext context, int oldIndex, int newIndex) {
    final audioProvider = context.read<AudioProvider>();
    final queue = List<Track>.from(audioProvider.queue);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final track = queue.removeAt(oldIndex);
    queue.insert(newIndex, track);

    // Update the queue in the provider
    // Note: This is a simplified implementation
    // In a real app, you'd want to update the audio service's queue
    audioProvider.clearQueue();
    audioProvider.setQueue(
      queue,
      startIndex: audioProvider.playbackState.queueIndex,
    );
  }

  void _showClearQueueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Queue'),
        content: const Text('Are you sure you want to clear the entire queue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AudioProvider>().clearQueue();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  bool _isRemoteTrack(Track track) {
    final uri = Uri.tryParse(track.path);
    return uri != null && uri.hasScheme;
  }
}
