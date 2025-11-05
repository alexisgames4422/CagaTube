import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LoggerService {
  LoggerService() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        lineLength: 80,
        printEmojis: false,
        printTime: false,
      ),
      output: _StreamLoggerOutput(_logController),
    );
  }

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  late final Logger _logger;
  IOSink? _fileSink;
  File? _logFile;

  Stream<String> get logStream => _logController.stream;

  Future<void> initialize() async {
    final dir = await _logsDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
    _logFile = File(p.join(dir.path, 'eli_player_$timestamp.log'));
    _fileSink = _logFile!.openWrite(mode: FileMode.append);
  }

  void dispose() {
    _fileSink?.close();
    _logController.close();
  }

  Future<Directory> _logsDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'logs'));
  }

  void d(String message) {
    _write('DEBUG', message);
    _logger.d(message);
  }

  void i(String message) {
    _write('INFO', message);
    _logger.i(message);
  }

  void w(String message) {
    _write('WARN', message);
    _logger.w(message);
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _write('ERROR', message);
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void _write(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[$timestamp][$level] $message';
    _fileSink?.writeln(formatted);
  }
}

class _StreamLoggerOutput extends LogOutput {
  _StreamLoggerOutput(this.controller);
  final StreamController<String> controller;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      controller.add(line);
    }
  }
}
