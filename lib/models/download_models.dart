import 'package:equatable/equatable.dart';

enum DownloadCategory { audio, video }

enum AudioFormat { mp3, m4a }

enum VideoFormat { mp4, mkv }

enum DownloadStatus {
  pending,
  preparing,
  downloading,
  merging,
  completed,
  paused,
  error,
}

class QualityOption extends Equatable {
  const QualityOption._({
    required this.id,
    required this.label,
    required this.category,
    this.height,
    this.bitrateKbps,
  });

  final String id;
  final String label;
  final DownloadCategory category;
  final int? height;
  final int? bitrateKbps;

  static const QualityOption audio320 = QualityOption._(
    id: 'audio-320',
    label: '320 kbps',
    category: DownloadCategory.audio,
    bitrateKbps: 320,
  );

  static const List<QualityOption> audioOptions = [
    audio320,
    QualityOption._(
      id: 'audio-256',
      label: '256 kbps',
      category: DownloadCategory.audio,
      bitrateKbps: 256,
    ),
    QualityOption._(
      id: 'audio-192',
      label: '192 kbps',
      category: DownloadCategory.audio,
      bitrateKbps: 192,
    ),
  ];

  static const List<QualityOption> videoOptions = [
    QualityOption._(
      id: 'video-1080',
      label: '1080p',
      category: DownloadCategory.video,
      height: 1080,
    ),
    QualityOption._(
      id: 'video-720',
      label: '720p',
      category: DownloadCategory.video,
      height: 720,
    ),
    QualityOption._(
      id: 'video-480',
      label: '480p',
      category: DownloadCategory.video,
      height: 480,
    ),
    QualityOption._(
      id: 'video-360',
      label: '360p',
      category: DownloadCategory.video,
      height: 360,
    ),
    QualityOption._(
      id: 'video-240',
      label: '240p',
      category: DownloadCategory.video,
      height: 240,
    ),
    QualityOption._(
      id: 'video-144',
      label: '144p',
      category: DownloadCategory.video,
      height: 144,
    ),
  ];

  static List<QualityOption> byCategory(DownloadCategory category) {
    return category == DownloadCategory.audio ? audioOptions : videoOptions;
  }

  @override
  List<Object?> get props => [id, label, category, height, bitrateKbps];
}

class DownloadOptions extends Equatable {
  const DownloadOptions({
    required this.category,
    required this.quality,
    this.audioFormat = AudioFormat.mp3,
    this.videoFormat = VideoFormat.mp4,
    this.embedMetadata = true,
  });

  final DownloadCategory category;
  final QualityOption quality;
  final AudioFormat audioFormat;
  final VideoFormat videoFormat;
  final bool embedMetadata;

  DownloadOptions copyWith({
    DownloadCategory? category,
    QualityOption? quality,
    AudioFormat? audioFormat,
    VideoFormat? videoFormat,
    bool? embedMetadata,
  }) {
    return DownloadOptions(
      category: category ?? this.category,
      quality: quality ?? this.quality,
      audioFormat: audioFormat ?? this.audioFormat,
      videoFormat: videoFormat ?? this.videoFormat,
      embedMetadata: embedMetadata ?? this.embedMetadata,
    );
  }

  @override
  List<Object?> get props => [
        category,
        quality,
        audioFormat,
        videoFormat,
        embedMetadata,
      ];
}

class MediaMetadata extends Equatable {
  const MediaMetadata({
    required this.id,
    required this.url,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnailUrl,
    required this.channel,
    required this.playlistTitle,
    this.playlistIndex,
  });

  final String id;
  final String url;
  final String title;
  final String uploader;
  final Duration? duration;
  final String? thumbnailUrl;
  final String? channel;
  final String? playlistTitle;
  final int? playlistIndex;

  MediaMetadata copyWith({
    String? id,
    String? url,
    String? title,
    String? uploader,
    Duration? duration,
    String? thumbnailUrl,
    String? channel,
    String? playlistTitle,
    int? playlistIndex,
  }) {
    return MediaMetadata(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channel: channel ?? this.channel,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      playlistIndex: playlistIndex ?? this.playlistIndex,
    );
  }

  @override
  List<Object?> get props => [
        id,
        url,
        title,
        uploader,
        duration,
        thumbnailUrl,
        channel,
        playlistTitle,
        playlistIndex,
      ];
}

class DownloadTask extends Equatable {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.status,
    required this.options,
    required this.createdAt,
    this.metadata,
    this.progress = 0,
    this.speed,
    this.eta,
    this.outputPath,
    this.errorMessage,
    this.thumbnailPath,
    this.fileSize,
    this.logs = const [],
    this.completedAt,
  });

  final String id;
  final String url;
  final DownloadStatus status;
  final DownloadOptions options;
  final double progress;
  final double? speed;
  final Duration? eta;
  final MediaMetadata? metadata;
  final String? outputPath;
  final String? errorMessage;
  final String? thumbnailPath;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> logs;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    double? speed,
    Duration? eta,
    MediaMetadata? metadata,
    String? outputPath,
    String? errorMessage,
    String? thumbnailPath,
    int? fileSize,
    List<String>? logs,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      status: status ?? this.status,
      options: options,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
      logs: logs ?? this.logs,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isAudio => options.category == DownloadCategory.audio;

  @override
  List<Object?> get props => [
        id,
        url,
        status,
        options,
        progress,
        speed,
        eta,
        metadata,
        outputPath,
        errorMessage,
        thumbnailPath,
        fileSize,
        createdAt,
        logs,
      ];
}
