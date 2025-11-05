import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logger_service.dart';

class SafeProcessRunner {
  SafeProcessRunner({
    required this.binaryPath,
    required this.logger,
  }) {
    if (!File(binaryPath).existsSync()) {
      throw ArgumentError('Binary not found at $binaryPath');
    }
  }

  final String binaryPath;
  final LoggerService logger;

  Future<Process> start(
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    _validateArguments(arguments);
    logger.d('Starting process: $binaryPath ${arguments.join(' ')}');
    return Process.start(
      binaryPath,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: false,
      includeParentEnvironment: true,
    );
  }

  void _validateArguments(List<String> args) {
    for (final arg in args) {
      if (arg.contains(';') || arg.contains('&&') || arg.contains('||')) {
        throw ArgumentError('Unsafe argument detected: $arg');
      }
    }
  }

  Future<ProcessResult> runAndCollect(
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final process = await start(
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    unawaited(
      process.stdout.transform(utf8.decoder).forEach(stdoutBuffer.write),
    );
    unawaited(
      process.stderr.transform(utf8.decoder).forEach(stderrBuffer.write),
    );

    final exitCode = await process.exitCode.timeout(timeout);
    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }
}
