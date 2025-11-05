import 'package:equatable/equatable.dart';

class LibraryEntry extends Equatable {
  const LibraryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.filePath,
    required this.formatLabel,
    required this.createdAt,
    this.thumbnailPath,
    this.fileSize,
  });

  final String id;
  final String url;
  final String title;
  final String artist;
  final int durationMs;
  final String filePath;
  final String formatLabel;
  final DateTime createdAt;
  final String? thumbnailPath;
  final int? fileSize;

  LibraryEntry copyWith({
    String? title,
    String? artist,
    int? durationMs,
    String? filePath,
    String? formatLabel,
    String? thumbnailPath,
    int? fileSize,
  }) {
    return LibraryEntry(
      id: id,
      url: url,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationMs: durationMs ?? this.durationMs,
      filePath: filePath ?? this.filePath,
      formatLabel: formatLabel ?? this.formatLabel,
      createdAt: createdAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  List<Object?> get props => [
        id,
        url,
        title,
        artist,
        durationMs,
        filePath,
        formatLabel,
        createdAt,
        thumbnailPath,
        fileSize,
      ];
}
