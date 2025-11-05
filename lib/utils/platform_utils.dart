import 'dart:io';

class PlatformUtils {
  const PlatformUtils._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static String get ytDlpBinaryName {
    if (Platform.isWindows) {
      return 'yt-dlp.exe';
    }
    if (Platform.isAndroid) {
      return 'yt-dlp';
    }
    return 'yt-dlp';
  }

  static String get ffmpegBinaryName {
    if (Platform.isWindows) {
      return 'ffmpeg.exe';
    }
    if (Platform.isAndroid) {
      return 'ffmpeg';
    }
    return 'ffmpeg';
  }
}
