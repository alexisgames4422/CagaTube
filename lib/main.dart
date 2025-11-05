import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'pages/main_shell.dart';
import 'services/downloader_service.dart';
import 'services/library_service.dart';
import 'services/logger_service.dart';
import 'services/playback_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    MediaKit.ensureInitialized();
  }

  final logger = LoggerService();
  await logger.initialize();
  final settingsService = SettingsService(logger: logger);
  await settingsService.load();

  final libraryService = await LibraryService.create(logger: logger);
  final playbackService = PlaybackService(logger: logger, libraryService: libraryService);
  await playbackService.initialize();
  final downloaderService = DownloaderService(
    settingsService: settingsService,
    libraryService: libraryService,
    playbackService: playbackService,
    logger: logger,
  );
  await downloaderService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<LoggerService>.value(value: logger),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<DownloaderService>.value(
          value: downloaderService,
        ),
        ChangeNotifierProvider<LibraryService>.value(value: libraryService),
        ChangeNotifierProvider<PlaybackService>.value(value: playbackService),
      ],
      child: const EliPlayerApp(),
    ),
  );
}

class EliPlayerApp extends StatelessWidget {
  const EliPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eli Player',
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MainShellPage(),
    );
  }
}
