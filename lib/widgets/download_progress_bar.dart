import 'package:flutter/material.dart';

class DownloadProgressBar extends StatelessWidget {
  const DownloadProgressBar({
    super.key,
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 8,
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          backgroundColor: colors.surfaceVariant.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            colors.primaryContainer,
          ),
        ),
      ),
    );
  }
}
