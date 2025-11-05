import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/download_models.dart';
import '../services/downloader_service.dart';
import '../widgets/download_tile.dart';
import '../widgets/empty_state.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloaderService>(
      builder: (context, service, _) {
        final tasks = service.tasks;
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.file_download_outlined,
            title: 'Sin descargas',
            subtitle: 'Empieza pegando una URL para descargar audio o video.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96, top: 16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return DownloadTile(
              key: ValueKey(task.id),
              task: task,
              onRetry: () => service.retry(task.id),
            ).animate().fade(duration: 350.ms).slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}
