import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../utils/platform_utils.dart';
import '../logger_service.dart';

class YtDlpBinaryManager {
  YtDlpBinaryManager({required this.logger});

  final LoggerService logger;
  static const _ytDlpAssetMap = {
    'linux': 'assets/binaries/linux/yt-dlp',
    'windows': 'assets/binaries/windows/yt-dlp.exe',
    'android': 'assets/binaries/android/yt-dlp',
  };

  static const _ffmpegAssetMap = {
    'linux': 'assets/ffmpeg/linux/ffmpeg',
    'windows': 'assets/ffmpeg/windows/ffmpeg.exe',
    'android': 'assets/ffmpeg/android/ffmpeg',
  };

  Future<Directory> _binaryDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final binariesDir = Directory(p.join(supportDir.path, 'binaries'));
    if (!binariesDir.existsSync()) {
      await binariesDir.create(recursive: true);
    }
    return binariesDir;
  }

  Future<String> ensureYtDlp() async {
    final dir = await _binaryDirectory();
    final binary = File(p.join(dir.path, PlatformUtils.ytDlpBinaryName));
    if (!binary.existsSync()) {
      logger.w('yt-dlp binary missing. Attempting to install from assets.');
      final installed = await _installFromAssets(binary, _ytDlpAssetKey());
      if (!installed) {
        await _downloadLatest(binary, _latestYtDlpUrl());
      }
    }
    await _ensureExecutable(binary);
    return binary.path;
  }

  Future<String> ensureFfmpeg() async {
    final dir = await _binaryDirectory();
    final binary = File(p.join(dir.path, PlatformUtils.ffmpegBinaryName));
    if (binary.existsSync()) {
      if (_looksLikeExecutable(binary)) {
        await _ensureExecutable(binary);
        return binary.path;
      }
      logger.w(
        'Existing ffmpeg at ${binary.path} is not a valid executable. Reinstalling.',
      );
      try {
        await binary.delete();
      } catch (_) {
        // If we cannot delete, we will attempt to overwrite later.
      }
    }

    final systemBinary = await _findSystemBinary(
      Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
    );
    if (systemBinary != null && systemBinary.isNotEmpty) {
      logger.i('Using system ffmpeg at $systemBinary');
      return systemBinary;
    }

    logger.w('ffmpeg binary missing. Attempting to install from assets.');
    final installed = await _installFromAssets(binary, _ffmpegAssetKey());
    if (!installed) {
      await _downloadAndPrepareFfmpeg(binary);
    }
    await _ensureExecutable(binary);
    return binary.path;
  }

  Future<void> updateYtDlp() async {
    final dir = await _binaryDirectory();
    final binary = File(p.join(dir.path, PlatformUtils.ytDlpBinaryName));
    await _downloadLatest(binary, _latestYtDlpUrl());
    await _ensureExecutable(binary);
  }

  Future<void> updateFfmpeg() async {
    final dir = await _binaryDirectory();
    final binary = File(p.join(dir.path, PlatformUtils.ffmpegBinaryName));
    await _downloadAndPrepareFfmpeg(binary);
    await _ensureExecutable(binary);
  }

  Future<bool> _installFromAssets(File target, String? assetKey) async {
    if (assetKey == null) {
      return false;
    }
    try {
      final data = await rootBundle.load(assetKey);
      await target.writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
      logger.i('Installed ${p.basename(target.path)} from assets.');
      return true;
    } on FlutterError {
      logger.w('Asset $assetKey not found for ${p.basename(target.path)}');
      return false;
    }
  }

  Future<void> _downloadLatest(File target, Uri url) async {
    logger.i('Downloading ${p.basename(target.path)} from $url');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to download ${target.path} (${response.statusCode})');
    }
    await target.writeAsBytes(response.bodyBytes, flush: true);
    logger.i('Downloaded ${p.basename(target.path)}');
  }

  Future<String?> _findSystemBinary(String command) async {
    final executable = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(executable, [command]);
      if (result.exitCode == 0) {
        final output = (result.stdout as String?) ?? '';
        final candidate = output
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        if (candidate.isNotEmpty && File(candidate).existsSync()) {
          return candidate;
        }
      }
    } catch (_) {
      // Ignored: if lookup fails, we'll fall back to bundled/downloaded binary.
    }
    return null;
  }

  bool _looksLikeExecutable(File file) {
    if (!file.existsSync()) return false;
    RandomAccessFile? raf;
    try {
      raf = file.openSync(mode: FileMode.read);
      final signature = raf.readSync(4);
      if (signature.length < 4) {
        return false;
      }

      if (Platform.isWindows) {
        return signature[0] == 0x4D && signature[1] == 0x5A;
      }
      if (Platform.isMacOS) {
        return signature[0] == 0xCF &&
            signature[1] == 0xFA &&
            signature[2] == 0xED &&
            signature[3] == 0xFE;
      }
      return signature[0] == 0x7F &&
          signature[1] == 0x45 &&
          signature[2] == 0x4C &&
          signature[3] == 0x46;
    } catch (_) {
      return false;
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {
        // Ignore close errors.
      }
    }
  }

  Future<void> _downloadAndPrepareFfmpeg(File target) async {
    final url = _latestFfmpegUrl();
    logger.i('Downloading ${p.basename(target.path)} from $url');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download ${target.path} (${response.statusCode})',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('eli_ffmpeg');
    try {
      final archivePath = p.join(
        tempDir.path,
        Platform.isWindows ? 'ffmpeg.zip' : 'ffmpeg.tar.xz',
      );
      final archiveFile = File(archivePath);
      await archiveFile.writeAsBytes(response.bodyBytes, flush: true);

      final extractedBinary = Platform.isWindows
          ? await _extractFfmpegFromZip(archiveFile)
          : await _extractFfmpegFromTarXz(archiveFile);

      if (extractedBinary == null) {
        throw Exception('ffmpeg binary not found in downloaded archive.');
      }

      if (!target.parent.existsSync()) {
        await target.parent.create(recursive: true);
      }
      await extractedBinary.copy(target.path);
      logger.i('Extracted ffmpeg to ${target.path}');
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Best effort cleanup.
      }
    }
  }

  Future<File?> _extractFfmpegFromTarXz(File archive) async {
    final extractDir = Directory(p.join(archive.parent.path, 'extract'));
    await extractDir.create(recursive: true);
    final result = await Process.run(
      'tar',
      ['-xJf', archive.path, '-C', extractDir.path],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to extract ffmpeg archive: ${result.stderr}');
    }
    return _locateBinary(extractDir, 'ffmpeg');
  }

  Future<File?> _extractFfmpegFromZip(File archive) async {
    final extractDir = Directory(p.join(archive.parent.path, 'extract'));
    await extractDir.create(recursive: true);
    ProcessResult result;
    if (Platform.isWindows) {
      final powershellScript =
          'Expand-Archive -Path "${archive.path}" -DestinationPath "${extractDir.path}" -Force';
      result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', powershellScript],
        runInShell: false,
      );
    } else {
      result = await Process.run(
        'unzip',
        [archive.path, '-d', extractDir.path],
        runInShell: false,
      );
    }
    if (result.exitCode != 0) {
      throw Exception('Failed to extract ffmpeg archive: ${result.stderr}');
    }
    return _locateBinary(extractDir, Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg');
  }

  Future<File?> _locateBinary(Directory root, String binaryName) async {
    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == binaryName) {
        return entity;
      }
    }
    return null;
  }

  Future<void> _ensureExecutable(File file) async {
    if (!Platform.isWindows && file.existsSync()) {
      final process = await Process.start(
        'chmod',
        ['+x', file.path],
        runInShell: false,
      );
      final exit = await process.exitCode;
      if (exit != 0) {
        logger.w(
          'Failed to mark ${file.path} as executable (exit $exit). Manual intervention may be required.',
        );
      }
    }
  }

  String? _ytDlpAssetKey() {
    if (Platform.isLinux) return _ytDlpAssetMap['linux'];
    if (Platform.isWindows) return _ytDlpAssetMap['windows'];
    if (Platform.isAndroid) return _ytDlpAssetMap['android'];
    return null;
  }

  String? _ffmpegAssetKey() {
    if (Platform.isLinux) return _ffmpegAssetMap['linux'];
    if (Platform.isWindows) return _ffmpegAssetMap['windows'];
    if (Platform.isAndroid) return _ffmpegAssetMap['android'];
    return null;
  }

  Uri _latestYtDlpUrl() {
    if (Platform.isWindows) {
      return Uri.parse(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
      );
    }
    if (Platform.isLinux || Platform.isAndroid) {
      return Uri.parse(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
      );
    }
    return Uri.parse(
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
    );
  }

  Uri _latestFfmpegUrl() {
    if (Platform.isWindows) {
      return Uri.parse(
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
      );
    }
    if (Platform.isLinux || Platform.isAndroid) {
      return Uri.parse(
        'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz',
      );
    }
    return Uri.parse(
      'https://evermeet.cx/ffmpeg/getrelease',
    );
  }
}
