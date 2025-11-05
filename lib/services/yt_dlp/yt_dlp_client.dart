import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/download_models.dart';
import '../../utils/format_utils.dart';
import '../logger_service.dart';
import 'safe_process_runner.dart';
import 'yt_dlp_binary_manager.dart';

class YtDlpProgress {
  const YtDlpProgress({
    required this.status,
    this.percent,
    this.downloadedBytes,
    this.totalBytes,
    this.speedBytesPerSecond,
    this.eta,
    this.message,
  });

  final DownloadStatus status;
  final double? percent;
  final int? downloadedBytes;
  final int? totalBytes;
  final double? speedBytesPerSecond;
  final Duration? eta;
  final String? message;
}

class YtDlpClient {
  YtDlpClient({
    required this.binaryManager,
    required this.logger,
  });

  final YtDlpBinaryManager binaryManager;
  final LoggerService logger;

  Future<List<MediaMetadata>> resolveMetadata(String url) async {
    final binary = await binaryManager.ensureYtDlp();
    final runner = SafeProcessRunner(binaryPath: binary, logger: logger);
    final result = await runner.runAndCollect(
      [
        '--dump-single-json',
        '--no-warnings',
        '--skip-download',
        url,
      ],
      timeout: const Duration(minutes: 2),
    );

    if (result.exitCode != 0) {
      logger.e('Metadata request failed: ${result.stderr}');
      throw Exception('No se pudo obtener metadatos: ${result.stderr}');
    }

    final raw = jsonDecode(result.stdout);
    final List<MediaMetadata> entries = [];

    if (raw is Map<String, dynamic> && raw['entries'] is List) {
      final playlistTitle = raw['title'] as String?;
      var index = 0;
      for (final entry in raw['entries'] as List<dynamic>) {
        index++;
        if (entry == null) continue;
        final map = Map<String, dynamic>.from(entry as Map);
        final id = map['id'] as String? ??
            '${index}_${DateTime.now().millisecondsSinceEpoch}';
        entries.add(
            _metadataFromMap(map, playlistTitle: playlistTitle, index: index));
      }
      return entries;
    }

    if (raw is Map<String, dynamic>) {
      entries.add(_metadataFromMap(raw));
      return entries;
    }

    throw Exception('Respuesta inesperada de yt-dlp');
  }

  MediaMetadata _metadataFromMap(
    Map<String, dynamic> map, {
    String? playlistTitle,
    int? index,
  }) {
    final durationSeconds =
        map['duration'] is num ? (map['duration'] as num).toDouble() : null;
    return MediaMetadata(
      id: map['id'] as String? ??
          map['nid'] as String? ??
          map['title'] as String? ??
          '',
      url: map['webpage_url'] as String? ??
          map['original_url'] as String? ??
          map['url'] as String? ??
          '',
      title: map['title'] as String? ?? 'Sin título',
      uploader: map['uploader'] as String? ??
          map['artist'] as String? ??
          'Desconocido',
      duration: durationSeconds != null
          ? Duration(seconds: durationSeconds.round())
          : null,
      thumbnailUrl: map['thumbnail'] as String?,
      channel: map['channel'] as String?,
      playlistTitle: playlistTitle ?? map['playlist_title'] as String?,
      playlistIndex: index ?? map['playlist_index'] as int?,
    );
  }

  Future<String> download(
    DownloadTask task, {
    required void Function(String line) onLog,
    required void Function(YtDlpProgress progress) onProgress,
    required String downloadDirectory,
    required String tempDirectory,
  }) async {
    final binary = await binaryManager.ensureYtDlp();
    final ffmpeg = await binaryManager.ensureFfmpeg();
    final runner = SafeProcessRunner(binaryPath: binary, logger: logger);

    final args = _buildArguments(
      task: task,
      downloadDirectory: downloadDirectory,
      tempDirectory: tempDirectory,
      ffmpegPath: ffmpeg,
    );
    final process = await runner.start(args);

    String? outputPath;
    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onLog(line);
      final parsed = _parseProgress(line);
      if (parsed != null) {
        onProgress(parsed);
      }
      final maybeOutput = _parseOutputPath(line);
      if (maybeOutput != null) {
        outputPath = maybeOutput;
      }
    });

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onLog(line);
      final parsed = _parseProgress(line);
      if (parsed != null) {
        onProgress(parsed);
      }
    });

    final exitCode = await process.exitCode;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      onProgress(
        YtDlpProgress(
          status: DownloadStatus.error,
          message: 'yt-dlp finalizó con código $exitCode',
        ),
      );
      throw Exception('yt-dlp falló con código $exitCode');
    }

    if (outputPath == null || outputPath!.isEmpty) {
      throw Exception('No se detectó la ruta de salida generada por yt-dlp');
    }

    return outputPath!;
  }

  List<String> _buildArguments({
    required DownloadTask task,
    required String ffmpegPath,
    required String downloadDirectory,
    required String tempDirectory,
  }) {
    // 🧠 Asegurar que las rutas sean absolutas (Dart no expande '~')
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final safeDownloadDir = downloadDirectory.replaceAll('~', home);
    final safeTempDir = tempDirectory.replaceAll('~', home);

    // 📁 Plantilla de salida (ruta final del archivo)
    final outputTemplate = '$safeDownloadDir/%(title)s.%(ext)s';

    final args = <String>[
      '--newline',
      '--ignore-errors',
      '--no-warnings',
      '--no-mtime',
      '--no-playlist',
      '--ffmpeg-location',
      ffmpegPath,
      '-o',
      outputTemplate,
      '--paths',
      'home:$safeDownloadDir',
      '--paths',
      'temp:$safeTempDir',
    ];

    // 🎵 Si es solo audio (MP3)
    if (task.options.category == DownloadCategory.audio) {
      args.addAll([
        '-f',
        'bestaudio',
        '--extract-audio',
        '--audio-format',
        task.options.audioFormat.name,
        '--audio-quality',
        _audioQualityArg(task.options.quality),
        '--prefer-ffmpeg',
      ]);
    }
    // 🎬 Si es video (MP4)
    else {
      final height = task.options.quality.height ?? 1080;
      args.addAll([
        '-f',
        'bv*[height<=${height}]+ba/b[height<=${height}]',
        '--merge-output-format',
        task.options.videoFormat.name,
      ]);
    }

    // 🧾 Metadatos opcionales
    if (task.options.embedMetadata) {
      args.addAll([
        '--embed-thumbnail',
        '--add-metadata',
        '--embed-metadata',
      ]);
    }

    // 📋 URL + modo debug (para logs)
    args.addAll(['--verbose', task.url]);

    return args;
  }

  String _buildOutputTemplate(DownloadTask task) {
    final base = task.metadata?.playlistTitle ?? 'EliPlayer';
    final sanitizedBase = FormatUtils.sanitizeFileName(base);
    final segments = ['%(paths.home)s', sanitizedBase, '%(title)s.%(ext)s'];
    return segments.join('/');
  }

  String _audioQualityArg(QualityOption option) {
    final bitrate = option.bitrateKbps ?? 320;
    switch (bitrate) {
      case >= 320:
        return '0';
      case >= 256:
        return '2';
      default:
        return '5';
    }
  }

  YtDlpProgress? _parseProgress(String line) {
    if (line.contains('[download]')) {
      final percentMatch =
          RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(line)?.group(1);
      final speedMatch = RegExp(r'at\s+([\d.]+)([KMG]?i?B)/s').firstMatch(line);
      final etaMatch = RegExp(r'ETA\s+([\d:]+)').firstMatch(line);
      final totalMatch = RegExp(r'of\s+([\d.]+)([KMG]?i?B)').firstMatch(line);

      final percent =
          percentMatch != null ? double.tryParse(percentMatch) : null;
      final speed = speedMatch != null
          ? FormatUtils.parseDataRate(
              speedMatch.group(1)!,
              speedMatch.group(2)!,
            )
          : null;
      final totalBytes = totalMatch != null
          ? FormatUtils.parseDataSize(
              totalMatch.group(1)!,
              totalMatch.group(2)!,
            )
          : null;
      final eta =
          etaMatch != null ? FormatUtils.parseEta(etaMatch.group(1)!) : null;

      return YtDlpProgress(
        status: DownloadStatus.downloading,
        percent: percent,
        totalBytes: totalBytes,
        speedBytesPerSecond: speed,
        eta: eta,
      );
    }

    if (line.contains('[Merger]') || line.contains('[ExtractAudio]')) {
      return YtDlpProgress(
        status: DownloadStatus.merging,
        message: line,
      );
    }

    if (line.contains('100%')) {
      return YtDlpProgress(
        status: DownloadStatus.completed,
        percent: 100,
      );
    }

    if (line.toLowerCase().contains('error')) {
      return YtDlpProgress(
        status: DownloadStatus.error,
        message: line,
      );
    }

    return null;
  }

  String? _parseOutputPath(String line) {
    final destinationMatch =
        RegExp(r'Destination:\s(.+)$').firstMatch(line)?.group(1);
    if (destinationMatch != null) {
      return destinationMatch.trim();
    }

    final mergingMatch =
        RegExp(r'Merging formats into\s"(.+)"').firstMatch(line)?.group(1);
    if (mergingMatch != null) {
      return mergingMatch.trim();
    }

    final alreadyDownloadedMatch = RegExp(
      r'\[download\]\s(.+)\s_has already been downloaded',
    ).firstMatch(line);
    if (alreadyDownloadedMatch != null) {
      return alreadyDownloadedMatch.group(1)?.trim();
    }
    return null;
  }
}
