import 'dart:io';

import 'package:flutter/services.dart';

import '../services/logger_service.dart';

class SystemLauncher {
  SystemLauncher._();

  static const MethodChannel _channel = MethodChannel('eli_player/system');

  static Future<void> revealFile(
    String filePath, {
    LoggerService? logger,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('revealFile', {'path': filePath});
      } else if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [File(filePath).parent.path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', filePath]);
      }
    } catch (error) {
      logger?.w('No se pudo abrir la carpeta: $error');
    }
  }
}
