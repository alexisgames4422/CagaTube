import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.isActive,
    this.barCount = 20,
    this.color,
  });

  final bool isActive;
  final int barCount;
  final Color? color;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  late List<double> _levels;
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _levels = List<double>.filled(widget.barCount, 0.1);
    _updateTimer();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _updateTimer();
    }
  }

  void _updateTimer() {
    _timer?.cancel();
    if (widget.isActive) {
      _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        setState(() {
          for (var i = 0; i < _levels.length; i++) {
            _levels[i] = _random.nextDouble();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / (widget.barCount * 1.5);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final level in _levels)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: constraints.maxHeight * (widget.isActive ? level : 0.1),
                    margin: EdgeInsets.symmetric(horizontal: barWidth * 0.2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
