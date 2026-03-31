import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import 'track_artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        final currentTrack = audioProvider.currentTrack;

        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _navigateToNowPlaying(context),
          child: Container(
            height: 72,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: 0.65,
                ),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Row(
              children: [
                // Album artwork
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: RotatingArtwork(
                    isPlaying: audioProvider.isPlaying,
                    duration: const Duration(seconds: 12),
                    child: TrackArtwork(
                      track: currentTrack,
                      size: 50,
                      borderRadius: BorderRadius.circular(999),
                      fallbackIcon: Icons.music_note,
                      borderColor: Theme.of(context).colorScheme.primary,
                      borderWidth: 1,
                    ),
                  ),
                ),

                // Track info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarqueeText(
                        text: currentTrack.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        currentTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Previous button
                IconButton(
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: audioProvider.skipToPrevious,
                ),

                // Play/Pause button
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 1.0,
                    end: audioProvider.isPlaying ? 1.08 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: IconButton(
                    icon: Icon(
                      audioProvider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: audioProvider.togglePlayPause,
                  ),
                ),

                // Next button
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: audioProvider.skipToNext,
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToNowPlaying(BuildContext context) {
    Navigator.of(context).pushNamed('/now-playing');
  }
}

class RotatingArtwork extends StatefulWidget {
  const RotatingArtwork({
    super.key,
    required this.child,
    required this.isPlaying,
    this.duration = const Duration(seconds: 12),
  });

  final Widget child;
  final bool isPlaying;
  final Duration duration;

  @override
  State<RotatingArtwork> createState() => _RotatingArtworkState();
}

class _RotatingArtworkState extends State<RotatingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.isPlaying) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 24,
    this.velocity = 34,
  });

  final String text;
  final TextStyle style;
  final double gap;
  final double velocity;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _boxWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _textWidth = 0;
      _boxWidth = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final textWidth = painter.width;
        final boxWidth = constraints.maxWidth;
        final shouldScroll = textWidth > boxWidth;

        if (!shouldScroll) {
          _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }

        if (_textWidth != textWidth || _boxWidth != boxWidth) {
          _textWidth = textWidth;
          _boxWidth = boxWidth;
          final distance = textWidth + widget.gap;
          final durationMs = (distance / widget.velocity * 1000).round();
          _controller.duration = Duration(
            milliseconds: durationMs.clamp(1200, 20000).toInt(),
          );
          if (!_controller.isAnimating) {
            _controller.repeat();
          }
        } else if (!_controller.isAnimating) {
          _controller.repeat();
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = _controller.value * (_textWidth + widget.gap);
              return Transform.translate(
                offset: Offset(-offset, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.text, style: widget.style, maxLines: 1),
                    SizedBox(width: widget.gap),
                    Text(widget.text, style: widget.style, maxLines: 1),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
