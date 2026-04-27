import 'dart:convert';
import 'dart:io';

class VideoInfo {
  final String title;
  final String thumbnailUrl;
  final String duration;

  VideoInfo({required this.title, required this.thumbnailUrl, required this.duration});
}

class YtDlpService {
  final String ytDlpPath;
  final String ffmpegPath;

  YtDlpService({required this.ytDlpPath, required this.ffmpegPath});

  Future<VideoInfo?> getVideoInfo(String url) async {
    try {
      final result = await Process.run(ytDlpPath, [
        '--dump-json',
        url
      ]);

      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout.toString());
        return VideoInfo(
          title: json['title'] ?? 'Unknown Title',
          thumbnailUrl: json['thumbnail'] ?? '',
          duration: json['duration_string'] ?? '',
        );
      }
    } catch (e) {
      // Ignored for prototype, handle properly in production
    }
    return null;
  }

  Future<void> downloadVideo({
    required String url,
    required String saveDirectory,
    required void Function(String) onLog,
    required void Function(double) onProgress,
  }) async {
    try {
      final process = await Process.start(ytDlpPath, [
        // Let yt-dlp use the system's ffmpeg for this prototype instead of providing a broken binary
        // '--ffmpeg-location',
        // ffmpegPath,
        '--newline', // Force newline to parse stdout easier
        '--progress',
        '-o',
        '$saveDirectory/%(title)s.%(ext)s',
        url
      ]);

      process.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          onLog(line);

          // Basic yt-dlp progress parsing
          // Example output: [download]  10.0% of 50.00MiB at  1.50MiB/s ETA 00:30
          if (line.contains('[download]') && line.contains('%')) {
             final progressMatch = RegExp(r'(\d+\.\d+)%').firstMatch(line);
             if (progressMatch != null) {
               final percentString = progressMatch.group(1);
               if (percentString != null) {
                  final percent = double.tryParse(percentString);
                  if (percent != null) {
                     onProgress(percent / 100.0);
                  }
               }
             }
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        onLog('ERROR: $data');
      });

      final exitCode = await process.exitCode;
      onLog('Process exited with code $exitCode');
    } catch (e) {
      onLog('Failed to start download process: $e');
    }
  }
}
