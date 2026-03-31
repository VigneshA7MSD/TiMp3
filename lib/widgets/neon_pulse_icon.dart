import 'package:flutter/material.dart';

class NeonPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const NeonPulseIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  State<NeonPulseIcon> createState() => _NeonPulseIconState();
}

class _NeonPulseIconState extends State<NeonPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1.0 + (t * 0.1);
        final glow = 8 + (t * 12);

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.55),
                  blurRadius: glow,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: Icon(widget.icon, size: widget.size, color: widget.color),
          ),
        );
      },
    );
  }
}
