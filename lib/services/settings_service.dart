import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/download_models.dart';
import '../utils/platform_utils.dart';
import 'logger_service.dart';

class SettingsService extends ChangeNotifier {
  SettingsService({required this.logger});

  final LoggerService logger;
  SharedPreferences? _prefs;
  late AppSettings _settings;

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  DownloadOptions get downloadOptions => _settings.options;
  String get downloadDirectory => _settings.downloadDirectory;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString('app_settings');
    if (stored != null) {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(map);
    } else {
      final defaultDir = await _defaultDownloadDirectory();
      _settings = AppSettings(
        downloadDirectory: defaultDir,
        options: const DownloadOptions(
          category: DownloadCategory.audio,
          quality: QualityOption.audio320,
          audioFormat: AudioFormat.mp3,
          videoFormat: VideoFormat.mp4,
        ),
        isDarkMode: true,
      );
      await _persist();
    }

    await _ensureDirectoryExists(_settings.downloadDirectory);
    logger.i('Settings loaded. Download folder: ${_settings.downloadDirectory}');
  }

  Future<String> _defaultDownloadDirectory() async {
    if (Platform.isAndroid) {
      final root = await getExternalStorageDirectory();
      return p.join(root?.path ?? '/storage/emulated/0', 'EliPlayer');
    }
    if (PlatformUtils.isDesktop) {
      final downloads = await getDownloadsDirectory();
      return p.join(downloads?.path ?? (await getApplicationDocumentsDirectory()).path, 'EliPlayer');
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'EliPlayer');
  }

  Future<void> updateDownloadDirectory(String directory) async {
    _settings = _settings.copyWith(downloadDirectory: directory);
    await _ensureDirectoryExists(directory);
    await _persist();
    notifyListeners();
  }

  Future<void> updateDownloadOptions(DownloadOptions options) async {
    _settings = _settings.copyWith(options: options);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _settings = _settings.copyWith(isDarkMode: isDarkMode);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_settings.toJson());
    await _prefs?.setString('app_settings', encoded);
  }

  Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }
}
