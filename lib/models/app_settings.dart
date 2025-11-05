import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'download_models.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.downloadDirectory,
    required this.options,
    required this.isDarkMode,
  });

  final String downloadDirectory;
  final DownloadOptions options;
  final bool isDarkMode;

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  AppSettings copyWith({
    String? downloadDirectory,
    DownloadOptions? options,
    bool? isDarkMode,
  }) {
    return AppSettings(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      options: options ?? this.options,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'downloadDirectory': downloadDirectory,
      'isDarkMode': isDarkMode,
      'options': {
        'category': options.category.name,
        'quality': options.quality.id,
        'audioFormat': options.audioFormat.name,
        'videoFormat': options.videoFormat.name,
        'embedMetadata': options.embedMetadata,
      },
    };
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    final category = DownloadCategory.values.firstWhere(
      (value) => value.name == json['options']['category'],
      orElse: () => DownloadCategory.audio,
    );

    final qualityId = json['options']['quality'] as String? ?? 'audio-320';
    final quality = [
      ...QualityOption.audioOptions,
      ...QualityOption.videoOptions,
    ].firstWhere(
      (opt) => opt.id == qualityId,
      orElse: () => QualityOption.audio320,
    );

    return AppSettings(
      downloadDirectory: json['downloadDirectory'] as String? ??
          (Platform.isWindows ? r'C:\EliPlayer' : '/storage/emulated/0/EliPlayer'),
      options: DownloadOptions(
        category: category,
        quality: quality,
        audioFormat: AudioFormat.values.firstWhere(
          (value) => value.name == json['options']['audioFormat'],
          orElse: () => AudioFormat.mp3,
        ),
        videoFormat: VideoFormat.values.firstWhere(
          (value) => value.name == json['options']['videoFormat'],
          orElse: () => VideoFormat.mp4,
        ),
        embedMetadata: json['options']['embedMetadata'] as bool? ?? true,
      ),
      isDarkMode: json['isDarkMode'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [downloadDirectory, options, isDarkMode];
}
