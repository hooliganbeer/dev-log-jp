import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/dependency_manager.dart';
import '../services/ytdlp_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final DependencyManager _depManager = DependencyManager();

  bool _isCheckingDeps = true;
  String _depStatus = 'Checking dependencies...';
  double _depDownloadProgress = 0.0;

  YtDlpService? _ytDlpService;
  VideoInfo? _videoInfo;
  bool _isFetchingInfo = false;

  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initDependencies();
  }

  Future<void> _initDependencies() async {
    setState(() {
      _isCheckingDeps = true;
      _depStatus = 'Checking dependencies...';
    });

    final hasDeps = await _depManager.checkDependencies();
    if (!hasDeps) {
      setState(() {
        _depStatus = 'Downloading yt-dlp & ffmpeg...';
      });
      await _depManager.downloadDependencies((progress) {
        setState(() {
          _depDownloadProgress = progress;
        });
      });
    }

    final ytPath = await _depManager.getYtDlpPath();
    final ffPath = await _depManager.getFfmpegPath();

    _ytDlpService = YtDlpService(ytDlpPath: ytPath, ffmpegPath: ffPath);

    setState(() {
      _isCheckingDeps = false;
      _depStatus = 'Ready to download';
    });
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _ytDlpService == null) return;

    setState(() {
      _isFetchingInfo = true;
      _videoInfo = null;
    });

    final info = await _ytDlpService!.getVideoInfo(url);

    setState(() {
      _isFetchingInfo = false;
      _videoInfo = info;
    });
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _ytDlpService == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _logs.clear();
    });

    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

    await _ytDlpService!.downloadVideo(
      url: url,
      saveDirectory: dir.path,
      onLog: (log) {
        setState(() {
          _logs.add(log);
        });
      },
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    setState(() {
      _isDownloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VortexDL'),
        elevation: 0,
      ),
      body: _isCheckingDeps
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_depStatus),
                  if (_depDownloadProgress > 0)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _depDownloadProgress),
                    )
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'Video URL',
                            border: OutlineInputBorder(),
                            hintText: 'https://...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isFetchingInfo ? null : _fetchVideoInfo,
                        style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
                        ),
                        child: _isFetchingInfo
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Parse'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_videoInfo != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            if (_videoInfo!.thumbnailUrl.isNotEmpty)
                              Image.network(
                                _videoInfo!.thumbnailUrl,
                                width: 120,
                                height: 68,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 68),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _videoInfo!.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Duration: ${_videoInfo!.duration}'),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isDownloading ? null : _startDownload,
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_isDownloading || _logs.isNotEmpty) ...[
                     Text('Progress: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                     const SizedBox(height: 8),
                     LinearProgressIndicator(value: _downloadProgress),
                     const SizedBox(height: 16),
                     const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     Expanded(
                        child: Container(
                           decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                           ),
                           child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                 return Text(
                                    _logs[_logs.length - 1 - index],
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                 );
                              },
                           ),
                        ),
                     ),
                  ]
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
