import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/library_entry.dart';
import '../utils/format_utils.dart';
import 'library_service.dart';
import 'logger_service.dart';

enum PlaybackLoopMode { off, one }

class PlaybackService extends ChangeNotifier {
  PlaybackService({
    required this.logger,
    required this.libraryService,
  }) : _player = Player();

  final LoggerService logger;
  final LibraryService libraryService;
  final Player _player;

  VideoController? _videoController;
  LibraryEntry? _currentEntry;
  bool _isAudio = true;
  bool _shuffle = false;
  PlaybackLoopMode _loopMode = PlaybackLoopMode.off;

  late final StreamSubscription<List<LibraryEntry>> _librarySub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<double>? _rateSub;

  List<LibraryEntry> _queue = const [];
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1.0;

  VideoController? get videoController => _videoController;
  LibraryEntry? get currentEntry => _currentEntry;
  bool get isAudio => _isAudio;
  bool get isPlaying => _player.state.playing;
  PlaybackLoopMode get loopMode => _loopMode;
  bool get isShuffleEnabled => _shuffle;
  List<LibraryEntry> get queue => List.unmodifiable(_queue);
  double get speed => _speed;

  Stream<Duration> get positionStream => _player.streams.position;

  Duration? get duration => _duration;
  Duration get position => _position;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    _librarySub = libraryService.entriesStream.listen((entries) {
      _queue = entries;
      notifyListeners();
    });

    _positionSub = _player.streams.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _player.streams.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _playingSub = _player.streams.playing.listen((_) {
      notifyListeners();
    });

    _rateSub = _player.streams.rate.listen((value) {
      _speed = value;
      notifyListeners();
    });
  }

  Future<void> playEntry(LibraryEntry entry) async {
    final isAudioEntry = _isAudioEntry(entry);
    _currentEntry = entry;
    _isAudio = isAudioEntry;
    _shuffle = false;

    if (!isAudioEntry) {
      _videoController = VideoController(_player);
    } else {
      _videoController = null;
    }

    notifyListeners();

    try {
      await _player.open(
        Media(entry.filePath),
        play: true,
      );
      await _applyLoopMode();
      logger.i(
        'Reproduciendo ${isAudioEntry ? 'audio' : 'video'} ${entry.title}',
      );
    } catch (error, stackTrace) {
      logger.e(
        'No se pudo reproducir ${isAudioEntry ? 'audio' : 'video'} ${entry.title}: $error',
        error,
        stackTrace,
      );
    }
  }

  bool _isAudioEntry(LibraryEntry entry) {
    final path = entry.filePath.toLowerCase();
    const audioExtensions = [
      '.mp3',
      '.m4a',
      '.aac',
      '.flac',
      '.wav',
      '.ogg',
      '.opus',
    ];
    const videoExtensions = [
      '.mp4',
      '.mkv',
      '.webm',
      '.mov',
      '.avi',
      '.flv',
    ];
    if (audioExtensions.any(path.endsWith)) {
      return true;
    }
    if (videoExtensions.any(path.endsWith)) {
      return false;
    }
    final label = entry.formatLabel.toLowerCase();
    if (audioExtensions.any((ext) => label.contains(ext.substring(1)))) {
      return true;
    }
    if (videoExtensions.any((ext) => label.contains(ext.substring(1)))) {
      return false;
    }
    return true;
  }

  Future<void> togglePlayPause() async {
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    await _player.seek(target);
    notifyListeners();
  }

  Future<void> seekRelative(Duration offset) async {
    final total = _duration ?? Duration.zero;
    var target = _position + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (total > Duration.zero && target > total) {
      target = total;
    }
    await seek(target);
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _player.setRate(value);
    notifyListeners();
  }

  Future<void> toggleLoopMode() async {
    _loopMode =
        _loopMode == PlaybackLoopMode.off ? PlaybackLoopMode.one : PlaybackLoopMode.off;
    await _applyLoopMode();
    notifyListeners();
  }

  Future<void> _applyLoopMode() async {
    final mode =
        _loopMode == PlaybackLoopMode.one ? PlaylistMode.single : PlaylistMode.none;
    await _player.setPlaylistMode(mode);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }

  void onLibraryEntryAdded(LibraryEntry entry) {
    _queue = [entry, ..._queue];
    notifyListeners();
  }

  String positionLabel() {
    final total = _duration ?? Duration.zero;
    return '${FormatUtils.humanDuration(_position)} / ${FormatUtils.humanDuration(total)}';
  }

  @override
  void dispose() {
    _librarySub.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _rateSub?.cancel();
    _videoController = null;
    _player.dispose();
    super.dispose();
  }
}
