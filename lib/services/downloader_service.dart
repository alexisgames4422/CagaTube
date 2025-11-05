import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/download_models.dart';
import '../models/library_entry.dart';
import '../utils/format_utils.dart';
import 'library_service.dart';
import 'logger_service.dart';
import 'playback_service.dart';
import 'settings_service.dart';
import 'yt_dlp/yt_dlp_binary_manager.dart';
import 'yt_dlp/yt_dlp_client.dart';

class DownloaderService extends ChangeNotifier {
  DownloaderService({
    required this.settingsService,
    required this.libraryService,
    required this.playbackService,
    required this.logger,
  });

  final SettingsService settingsService;
  final LibraryService libraryService;
  final PlaybackService playbackService;
  final LoggerService logger;

  late final YtDlpBinaryManager _binaryManager;
  late final YtDlpClient _client;

  final List<DownloadTask> _tasks = [];
  final Queue<String> _queue = Queue<String>();
  final Map<String, Completer<void>> _taskCompleters = {};
  bool _isProcessing = false;

  UnmodifiableListView<DownloadTask> get tasks =>
      UnmodifiableListView(_tasks);

  Stream<List<DownloadTask>> get taskStream => _controller.stream;
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

  Future<void> initialize() async {
    _binaryManager = YtDlpBinaryManager(logger: logger);
    _client = YtDlpClient(binaryManager: _binaryManager, logger: logger);
    await _binaryManager.ensureYtDlp();
    await _binaryManager.ensureFfmpeg();
    await _ensurePermissions();
    logger.i('DownloaderService ready');
  }

  Future<void> enqueueFromInput(
    String rawUrl, {
    DownloadOptions? overrideOptions,
  }) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return;
    }

    logger.i('Resolviendo metadatos para $url');
    final options = overrideOptions ?? settingsService.downloadOptions;
    final metadataList = await _client.resolveMetadata(url);
    if (metadataList.isEmpty) {
      throw Exception('No se encontró contenido para $url');
    }

    for (final metadata in metadataList) {
      final taskId = const Uuid().v4();
      final task = DownloadTask(
        id: taskId,
        url: metadata.url,
        status: DownloadStatus.pending,
        options: options,
        createdAt: DateTime.now(),
        metadata: metadata,
      );
      _tasks.insert(0, task);
      _queue.add(taskId);
      _taskCompleters[taskId] = Completer<void>();
    }
    _publish();
    _processQueue();
  }

  Future<void> retry(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;
    final updated = task.copyWith(
      status: DownloadStatus.pending,
      progress: 0,
      errorMessage: null,
    );
    _updateTask(updated);
    _queue.add(taskId);
    _taskCompleters[taskId] = Completer<void>();
    _processQueue();
  }

  Future<void> cancel(String taskId) async {
    // Graceful cancel: currently we do not support active process cancellation.
    // Placeholder for future implementation.
  }

  void _processQueue() {
    if (_isProcessing) return;
    _isProcessing = true;
    unawaited(_workLoop());
  }

  Future<void> _workLoop() async {
    while (_queue.isNotEmpty) {
      final taskId = _queue.removeFirst();
      final task = _findTask(taskId);
      if (task == null) {
        continue;
      }

      logger.i('Descargando ${task.metadata?.title}');
      _updateTask(
        task.copyWith(
          status: DownloadStatus.preparing,
          progress: 0,
          eta: null,
          speed: null,
        ),
      );

      try {
        final outputPath = await _runDownload(task);
        await _onDownloadCompleted(taskId, outputPath);
        final completer = _taskCompleters[taskId];
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      } catch (error, stackTrace) {
        logger.e('Error al descargar ${task.id}: $error', error, stackTrace);
        _updateTask(
          task.copyWith(
            status: DownloadStatus.error,
            errorMessage: error.toString(),
          ),
        );
        final completer = _taskCompleters[taskId];
        if (completer != null && !completer.isCompleted) {
          completer.completeError(error);
        }
      }
    }

    _isProcessing = false;
  }

  Future<String> _runDownload(DownloadTask task) async {
    final downloadDir = settingsService.downloadDirectory;
    await _ensureDirectory(downloadDir);
    final tempDir = await _tempDirectory();
    final logs = <String>[...task.logs];

    final output = await _client.download(
      task,
      downloadDirectory: downloadDir,
      tempDirectory: tempDir,
      onLog: (line) {
        logs.add(line);
        if (logs.length > 200) {
          logs.removeAt(0);
        }
        _updateTask(
          _findTask(task.id)?.copyWith(logs: List<String>.from(logs)) ??
              task,
        );
      },
      onProgress: (progress) {
        final current = _findTask(task.id);
        if (current == null) return;
        final normalizedProgress = progress.percent != null
            ? (progress.percent!.clamp(0, 100) / 100)
            : current.progress;
        _updateTask(
          current.copyWith(
            status: progress.status,
            progress: normalizedProgress,
            speed: progress.speedBytesPerSecond,
            eta: progress.eta,
            fileSize: progress.totalBytes ?? current.fileSize,
            errorMessage: progress.status == DownloadStatus.error
                ? progress.message
                : current.errorMessage,
          ),
        );
      },
    );
    return output;
  }

  Future<void> _onDownloadCompleted(String taskId, String outputPath) async {
    final task = _findTask(taskId);
    if (task == null) return;

    final thumbnail = await _cacheThumbnail(task);
    final metadata = task.metadata;

    _updateTask(
      task.copyWith(
        status: DownloadStatus.completed,
        progress: 1,
        outputPath: outputPath,
        thumbnailPath: thumbnail,
        completedAt: DateTime.now(),
      ),
    );

    if (metadata != null) {
      final entry = LibraryEntry(
        id: task.id,
        url: metadata.url,
        title: metadata.title,
        artist: metadata.uploader,
        durationMs: metadata.duration?.inMilliseconds ?? 0,
        filePath: outputPath,
        formatLabel: task.isAudio
            ? task.options.audioFormat.name.toUpperCase()
            : task.options.videoFormat.name.toUpperCase(),
        createdAt: DateTime.now(),
        thumbnailPath: thumbnail,
        fileSize: File(outputPath).existsSync()
            ? await File(outputPath).length()
            : task.fileSize,
      );
      await libraryService.addEntry(entry);
      playbackService.onLibraryEntryAdded(entry);
    }
  }

  DownloadTask? _findTask(String id) {
    try {
      return _tasks.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateTask(DownloadTask task) {
    final index = _tasks.indexWhere((element) => element.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      _publish();
    }
  }

  void _publish() {
    _controller.add(List<DownloadTask>.unmodifiable(_tasks));
    notifyListeners();
  }

  Future<void> _ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      if (storage.isDenied || storage.isPermanentlyDenied) {
        logger.w('Permiso de almacenamiento denegado. Las descargas podrían fallar.');
      }
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  Future<String> _tempDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'eli_player'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String?> _cacheThumbnail(DownloadTask task) async {
    final url = task.metadata?.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return null;
      }
      final support = await getApplicationSupportDirectory();
      final fileName = FormatUtils.sanitizeFileName('${task.id}.jpg');
      final file = File(p.join(support.path, 'thumbnails', fileName));
      if (!file.parent.existsSync()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (error) {
      logger.w('No se pudo descargar miniatura: $error');
      return null;
    }
  }

  Future<void> disposeTask(String taskId) async {
    _tasks.removeWhere((element) => element.id == taskId);
    _queue.remove(taskId);
    _taskCompleters.remove(taskId);
    _publish();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
