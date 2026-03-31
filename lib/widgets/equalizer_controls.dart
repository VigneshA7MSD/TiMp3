import 'package:flutter/material.dart';

class EqualizerControls extends StatelessWidget {
  final List<double> bands;
  final Function(int, double) onBandChanged;

  const EqualizerControls({
    super.key,
    required this.bands,
    required this.onBandChanged,
  });

  static const List<String> _frequencies = [
    '32Hz', '64Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Frequency labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _frequencies.map((freq) => SizedBox(
            width: 40,
            child: Text(
              freq,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),

        // Sliders
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(bands.length, (index) {
            return SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Value display
                  Text(
                    '${bands[index].toStringAsFixed(1)}dB',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 4),

                  // Slider
                  RotatedBox(
                    quarterTurns: 1,
                    child: Slider(
                      value: bands[index],
                      min: -12,
                      max: 12,
                      onChanged: (value) => onBandChanged(index, value),
                    ),
                  ),

                  // Frequency bar visualization
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 4,
                        height: ((bands[index] + 12) / 24) * 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        // Reset button
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            for (int i = 0; i < bands.length; i++) {
              onBandChanged(i, 0.0);
            }
          },
          child: const Text('Reset to Flat'),
        ),
      ],
    );
  }
}
