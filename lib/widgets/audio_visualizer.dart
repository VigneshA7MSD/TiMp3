import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _barHeights = List.generate(32, (index) => Random().nextDouble() * 0.8 + 0.2);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    if (widget.isPlaying) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_barHeights.length, (index) {
            final baseHeight = _barHeights[index];
            final animatedHeight = widget.isPlaying
                ? baseHeight + (_animationController.value * 0.3)
                : baseHeight * 0.3;

            return Container(
              width: 4,
              height: animatedHeight * 60,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.isPlaying
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
