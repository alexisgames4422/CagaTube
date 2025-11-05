import 'dart:io';

import 'package:flutter/material.dart';

import '../models/library_entry.dart';
import '../utils/format_utils.dart';

class LibraryTile extends StatelessWidget {
  const LibraryTile({
    super.key,
    required this.entry,
    required this.onPlay,
    required this.onDelete,
    required this.onReveal,
  });

  final LibraryEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        minVerticalPadding: 12,
        leading: _thumbnail(colors),
        title: Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${entry.artist} · ${FormatUtils.humanDuration(Duration(milliseconds: entry.durationMs))}\n${entry.formatLabel} · ${FormatUtils.humanSize(entry.fileSize)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'play':
                onPlay();
                break;
              case 'reveal':
                onReveal();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'play', child: Text('Reproducir')),
            const PopupMenuItem(value: 'reveal', child: Text('Mostrar en carpeta')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar archivo'),
            ),
          ],
        ),
        onTap: onPlay,
      ),
    );
  }

  Widget _thumbnail(ColorScheme colors) {
    if (entry.thumbnailPath != null && File(entry.thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(entry.thumbnailPath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.secondaryContainer.withOpacity(0.6),
      ),
      child: Icon(
        entry.formatLabel.contains('MP') ? Icons.music_note : Icons.movie,
        color: colors.onSecondaryContainer,
      ),
    );
  }
}
