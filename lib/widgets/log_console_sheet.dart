import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/logger_service.dart';

class LogConsoleSheet extends StatefulWidget {
  const LogConsoleSheet({super.key});

  @override
  State<LogConsoleSheet> createState() => _LogConsoleSheetState();
}

class _LogConsoleSheetState extends State<LogConsoleSheet> {
  final List<String> _lines = <String>[];
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    final logger = context.read<LoggerService>();
    _subscription = logger.logStream.listen((event) {
      setState(() {
        _lines.insert(0, event);
        if (_lines.length > 500) {
          _lines.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded),
              const SizedBox(width: 8),
              Text(
                'Consola en tiempo real',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
