import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DependencyManager {
  final Dio _dio = Dio();

  Future<String> get _appSupportPath async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  String get _ytDlpExecutableName {
    if (Platform.isWindows) return 'yt-dlp.exe';
    if (Platform.isMacOS) return 'yt-dlp_macos';
    return 'yt-dlp'; // Linux
  }

  String get _ffmpegExecutableName {
    if (Platform.isWindows) return 'ffmpeg.exe';
    return 'ffmpeg';
  }

  Future<String> getYtDlpPath() async {
    final supportPath = await _appSupportPath;
    return '$supportPath${Platform.pathSeparator}$_ytDlpExecutableName';
  }

  Future<String> getFfmpegPath() async {
    final supportPath = await _appSupportPath;
    return '$supportPath${Platform.pathSeparator}$_ffmpegExecutableName';
  }

  Future<bool> checkDependencies() async {
    final ytDlpPath = await getYtDlpPath();
    final ffmpegPath = await getFfmpegPath();

    return File(ytDlpPath).existsSync() && File(ffmpegPath).existsSync();
  }

  Future<void> downloadDependencies(void Function(double) onProgress) async {
    final ytDlpPath = await getYtDlpPath();
    final ffmpegPath = await getFfmpegPath();

    if (!File(ytDlpPath).existsSync()) {
      await _downloadYtDlp(ytDlpPath, (p) => onProgress(p * 0.5)); // 50% of total progress
    }

    if (!File(ffmpegPath).existsSync()) {
      await _downloadFfmpeg(ffmpegPath, (p) => onProgress(0.5 + p * 0.5)); // 50%-100% of total progress
    }

    // Give execute permission on unix
    if (!Platform.isWindows) {
      if (File(ytDlpPath).existsSync()) {
         await Process.run('chmod', ['+x', ytDlpPath]);
      }
      if (File(ffmpegPath).existsSync()) {
         await Process.run('chmod', ['+x', ffmpegPath]);
      }
    }
  }

  Future<void> _downloadYtDlp(String savePath, void Function(double) onProgress) async {
    String downloadUrl;
    if (Platform.isWindows) {
      downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
    } else if (Platform.isMacOS) {
      downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
    } else {
      downloadUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
    }

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );
  }

  Future<void> _downloadFfmpeg(String savePath, void Function(double) onProgress) async {
    // IMPORTANT FIX: In our initial implementation, we downloaded `yt-dlp` and named it `ffmpeg`,
    // which caused `yt-dlp` to fail because it executed itself instead of `ffmpeg` during video merge.
    // Since we don't have an easy direct binary link for ffmpeg on all platforms right now without extracting,
    // we will skip downloading ffmpeg in this prototype and assume ffmpeg is already installed on the system,
    // or we will just use the system ffmpeg in YtDlpService.

    // Log skip action
    // ignore: avoid_print
    print('Please install ffmpeg on your system. Skipping automatic ffmpeg download for now.');
    onProgress(1.0);
  }
}
