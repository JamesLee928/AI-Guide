import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  const PlayerPage({super.key, required this.videoId, required this.title});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  @override
  void initState() {
    super.initState();
    // 進頁面後自動嘗試外部開啟
    WidgetsBinding.instance.addPostFrameCallback((_) => _openExternally());
  }

  Future<void> _openExternally() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    // 先嘗試外部 App（YouTube / 瀏覽器）
    final ok = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    if (!ok) {
      // 退而求其次：App 內瀏覽器視窗
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.ondemand_video, size: 80),
              const SizedBox(height: 16),
              Text(
                '已嘗試以 YouTube App/瀏覽器播放影片',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '若未自動開啟，請按下方按鈕重新開啟。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: const Text('在 YouTube 播放'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
