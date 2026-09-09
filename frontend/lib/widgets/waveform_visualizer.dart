import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isRecording;

  const WaveformVisualizer({super.key, required this.isRecording});

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(24, (index) {
            double height = widget.isRecording
                ? 12.0 + _random.nextDouble() * 45.0
                : 6.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: widget.isRecording
                    ? AppColors.primary
                    : AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}
