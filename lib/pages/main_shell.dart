import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../services/downloader_service.dart';
import '../theme/app_theme.dart';
import '../widgets/new_download_sheet.dart';
import '../widgets/log_console_sheet.dart';
import 'downloads_page.dart';
import 'library_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showNewDownloadSheet() async {
    final downloader = context.read<DownloaderService>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NewDownloadSheet(
          onSubmit: (url, options) =>
              downloader.enqueueFromInput(url, overrideOptions: options),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tabs = [
      Tab(
        icon: const Icon(Icons.download_rounded),
        text: 'Descargas',
      ),
      Tab(
        icon: const Icon(Icons.video_library_rounded),
        text: 'Biblioteca',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: 'Ver consola',
            icon: const Icon(Icons.terminal_rounded),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const LogConsoleSheet(),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colors.secondaryContainer.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              labelColor: colors.onSecondaryContainer,
              unselectedLabelColor: colors.onSurfaceVariant,
              tabs: tabs,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDownloadSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva descarga'),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DownloadsPage(),
          LibraryPage(),
        ],
      ),
    );
  }
}
