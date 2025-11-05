import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/download_models.dart';
import '../utils/format_utils.dart';
import 'download_progress_bar.dart';

class DownloadTile extends StatelessWidget {
  const DownloadTile({
    super.key,
    required this.task,
    required this.onRetry,
  });

  final DownloadTask task;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.4),
        borderRadius: border,
        border: Border.all(
          color: colors.secondary.withOpacity(0.12),
        ),
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.metadata?.title ?? task.url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.metadata?.uploader ?? 'Autor desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatusChip(status: task.status),
                            const SizedBox(width: 12),
                            if (task.speed != null)
                              Row(
                                children: [
                                  const Icon(Icons.speed, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    FormatUtils.humanSpeed(task.speed),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: colors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            const Spacer(),
                            Text(
                              task.isAudio
                                  ? task.options.audioFormat.name.toUpperCase()
                                  : task.options.videoFormat.name.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: colors.secondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DownloadProgressBar(progress: task.progress),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _statusMessage(task),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                            if (task.status == DownloadStatus.error) ...[
                              const SizedBox(width: 12),
                              TextButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().shimmer(duration: task.status == DownloadStatus.downloading ? 1500.ms : 0.ms);
  }

  Widget _buildThumbnail(BorderRadius border) {
    Widget placeholder = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: border,
      ),
      child: Icon(
        task.isAudio ? Icons.audio_file_outlined : Icons.movie_filter_outlined,
        color: Colors.white54,
        size: 36,
      ),
    );

    if (task.thumbnailPath != null && File(task.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(task.thumbnailPath!),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = task.metadata?.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          url,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder;
          },
        ),
      );
    }

    return placeholder;
  }

  String _statusMessage(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.pending:
        return 'En cola';
      case DownloadStatus.preparing:
        return 'Preparando';
      case DownloadStatus.downloading:
        final eta = FormatUtils.humanDuration(task.eta);
        return eta == '--' ? 'Descargando' : 'Descargando · ETA $eta';
      case DownloadStatus.merging:
        return 'Procesando con ffmpeg';
      case DownloadStatus.completed:
        final size = FormatUtils.humanSize(task.fileSize);
        return 'Completado · $size';
      case DownloadStatus.paused:
        return 'Pausado';
      case DownloadStatus.error:
        return 'Error · ${task.errorMessage ?? 'Desconocido'}';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = _statusData(status, colors);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: data.foreground),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: data.foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  _ChipData _statusData(DownloadStatus status, ColorScheme colors) {
    switch (status) {
      case DownloadStatus.pending:
        return _ChipData(
          label: 'Pendiente',
          icon: Icons.schedule,
          background: colors.surfaceTint.withOpacity(0.1),
          foreground: colors.secondary,
        );
      case DownloadStatus.preparing:
        return _ChipData(
          label: 'Preparando',
          icon: Icons.build_circle_outlined,
          background: colors.tertiary.withOpacity(0.12),
          foreground: colors.tertiary,
        );
      case DownloadStatus.downloading:
        return _ChipData(
          label: 'Descargando',
          icon: Icons.download_rounded,
          background: colors.primary.withOpacity(0.14),
          foreground: colors.primary,
        );
      case DownloadStatus.merging:
        return _ChipData(
          label: 'Procesando',
          icon: Icons.motion_photos_on_rounded,
          background: colors.primaryContainer.withOpacity(0.18),
          foreground: colors.onPrimaryContainer,
        );
      case DownloadStatus.completed:
        return _ChipData(
          label: 'Completado',
          icon: Icons.check_circle_rounded,
          background: colors.secondaryContainer.withOpacity(0.2),
          foreground: colors.onSecondaryContainer,
        );
      case DownloadStatus.paused:
        return _ChipData(
          label: 'Pausado',
          icon: Icons.pause_circle_outline,
          background: colors.secondary.withOpacity(0.12),
          foreground: colors.secondary,
        );
      case DownloadStatus.error:
        return _ChipData(
          label: 'Error',
          icon: Icons.error_outline,
          background: colors.errorContainer.withOpacity(0.2),
          foreground: colors.onErrorContainer,
        );
    }
  }
}

class _ChipData {
  const _ChipData({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}
