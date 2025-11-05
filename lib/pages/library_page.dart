import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/library_entry.dart';
import '../services/library_service.dart';
import '../services/logger_service.dart';
import '../services/playback_service.dart';
import '../utils/system_launcher.dart';
import '../widgets/empty_state.dart';
import '../widgets/library_tile.dart';
import '../widgets/player/media_player_panel.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<LibraryEntry>>? _subscription;
  List<LibraryEntry> _entries = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final library = context.read<LibraryService>();
    _entries = library.entries;
    _subscription = library.entriesStream.listen((entries) {
      if (!_isSearching) {
        setState(() {
          _entries = entries;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    final library = context.read<LibraryService>();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _entries = library.entries;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await library.search(query);
    if (mounted) {
      setState(() => _entries = results);
    }
  }

  Future<void> _deleteEntry(LibraryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
          '¿Seguro que quieres eliminar "${entry.title}" del disco y del historial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final logger = context.read<LoggerService>();
    try {
      final file = File(entry.filePath);
      if (file.existsSync()) {
        await file.delete();
      }
      if (entry.thumbnailPath != null) {
        final thumb = File(entry.thumbnailPath!);
        if (thumb.existsSync()) {
          await thumb.delete();
        }
      }
      await context.read<LibraryService>().remove(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo eliminado')),
        );
      }
    } catch (error) {
      logger.e('No se pudo eliminar archivo: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reveal(LibraryEntry entry) async {
    final logger = context.read<LoggerService>();
    await SystemLauncher.revealFile(entry.filePath, logger: logger);
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackService>();
    final content = _entries.isEmpty
        ? const EmptyState(
            icon: Icons.video_library_outlined,
            title: 'Biblioteca vacía',
            subtitle: 'Tus descargas aparecerán aquí para reproducirlas al instante.',
          )
        : ListView.builder(
            padding: EdgeInsets.only(bottom: playback.currentEntry != null ? 220 : 24),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return LibraryTile(
                entry: entry,
                onPlay: () => playback.playEntry(entry),
                onDelete: () => _deleteEntry(entry),
                onReveal: () => _reveal(entry),
              );
            },
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar en biblioteca',
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(child: content),
        const MediaPlayerPanel(),
      ],
    );
  }
}
