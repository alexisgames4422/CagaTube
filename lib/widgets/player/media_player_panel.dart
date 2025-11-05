import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../services/playback_service.dart';
import 'audio_visualizer.dart';

class MediaPlayerPanel extends StatefulWidget {
  const MediaPlayerPanel({super.key});

  @override
  State<MediaPlayerPanel> createState() => _MediaPlayerPanelState();
}

class _MediaPlayerPanelState extends State<MediaPlayerPanel> {
  bool _isScrubbing = false;
  double _scrubValue = 0;
  double _speed = 1.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackService>(
      builder: (context, playback, _) {
        final entry = playback.currentEntry;
        if (entry == null) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        final duration = playback.duration ?? Duration.zero;
        _speed = playback.speed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: colors.outlineVariant.withOpacity(0.4)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPreview(playback),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.artist,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playback.positionLabel(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: playback.toggleShuffle,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playback.isShuffleEnabled
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    onPressed: playback.toggleLoopMode,
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: playback.loopMode == PlaybackLoopMode.one
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  if (!playback.isAudio && playback.videoController != null)
                    IconButton(
                      onPressed: () => _openFullScreen(playback),
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<Duration>(
                stream: playback.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final value = _isScrubbing
                      ? _scrubValue
                      : duration.inMilliseconds == 0
                          ? 0.0
                          : position.inMilliseconds / duration.inMilliseconds;
                  return Slider(
                    value: value.clamp(0, 1).toDouble(),
                    onChanged: duration.inMilliseconds == 0
                        ? null
                        : (newValue) {
                            setState(() {
                              _isScrubbing = true;
                              _scrubValue = newValue;
                            });
                          },
                    onChangeEnd: duration.inMilliseconds == 0
                        ? null
                        : (newValue) async {
                            final target = Duration(
                              milliseconds:
                                  (duration.inMilliseconds * newValue).round(),
                            );
                            await playback.seek(target);
                            setState(() {
                              _isScrubbing = false;
                            });
                          },
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => playback.seekRelative(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton(
                    iconSize: 40,
                    onPressed: playback.togglePlayPause,
                    icon: Icon(
                      playback.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: () => playback.seekRelative(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<double>(
                  value: _speed,
                  items: const [
                    DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                    DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                    DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _speed = value);
                      playback.setSpeed(value);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFullScreen(PlaybackService playback) async {
    final controller = playback.videoController;
    if (controller == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) =>
            _FullScreenVideoOverlay(controller: controller),
      ),
    );
  }

  Widget _buildPreview(PlaybackService playback) {
    if (playback.isAudio) {
      return SizedBox(
        width: 120,
        height: 72,
        child: AudioVisualizer(
          isActive: playback.isPlaying,
          color: Colors.tealAccent.withOpacity(0.8),
        ),
      );
    }
    final controller = playback.videoController;
    if (controller == null) {
      return Container(
        width: 120,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.movie_filter_outlined),
      );
    }
    return SizedBox(
      width: 160,
      height: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Video(
          controller: controller,
          controls: null,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _FullScreenVideoOverlay extends StatelessWidget {
  const _FullScreenVideoOverlay({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Video(
              controller: controller,
              fit: BoxFit.contain,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
