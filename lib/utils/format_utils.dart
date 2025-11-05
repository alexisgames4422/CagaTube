import 'dart:math';

class FormatUtils {
  const FormatUtils._();

  static final _illegalFileNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  static String sanitizeFileName(String input) {
    return input.replaceAll(_illegalFileNameChars, '_').trim();
  }

  static Duration? parseEta(String raw) {
    final parts = raw.split(':').map(int.tryParse).whereType<int>().toList();
    if (parts.isEmpty) {
      return null;
    }
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration(seconds: parts[0]);
  }

  static double? parseDataRate(String value, String unit) {
    final numeric = double.tryParse(value);
    if (numeric == null) {
      return null;
    }
    final multiplier = _unitMultiplier(unit);
    return numeric * multiplier;
  }

  static int? parseDataSize(String value, String unit) {
    final numeric = double.tryParse(value);
    if (numeric == null) {
      return null;
    }
    final multiplier = _unitMultiplier(unit);
    return (numeric * multiplier).round();
  }

  static double _unitMultiplier(String unit) {
    final normalized = unit.toLowerCase();
    if (normalized.startsWith('k')) return pow(1024, 1).toDouble();
    if (normalized.startsWith('m')) return pow(1024, 2).toDouble();
    if (normalized.startsWith('g')) return pow(1024, 3).toDouble();
    if (normalized.startsWith('t')) return pow(1024, 4).toDouble();
    return 1;
  }

  static String humanSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '--';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  static String humanSpeed(double? bytesPerSecond) {
    if (bytesPerSecond == null || bytesPerSecond <= 0) {
      return '--';
    }
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
    var value = bytesPerSecond;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  static String humanDuration(Duration? duration) {
    if (duration == null) {
      return '--';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
