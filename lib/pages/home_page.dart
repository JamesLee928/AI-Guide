import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/beacon_models.dart';
import '../services/ble_scanner.dart';
import '../utils/dialogs.dart';
import 'player_page.dart';
import 'ai_chat_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scanner = BleScanner();
  bool _prompting = false;
  bool _playedA = false;
  bool _playedB = false;

  final Map<BeaconKind, List<String>> _videos = const {
    BeaconKind.A: ['iE0ngCQ-Sdg', 'P5G_MaoGN-M'],
    BeaconKind.B: ['BynztZe1aRE', 'X__fe6kCYmE'],
  };
  final Map<BeaconKind, int> _nextIndex = {BeaconKind.A: 0, BeaconKind.B: 0};

  @override
  void initState() {
    super.initState();
    _resetPlayedOnLaunch(); // ★ 每次啟動重置為未讀
  }

  Future<void> _resetPlayedOnLaunch() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('playedA');
    await sp.remove('playedB');
    setState(() {
      _playedA = false;
      _playedB = false;
    });
  }

  Future<void> _savePlayedState() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('playedA', _playedA);
    await sp.setBool('playedB', _playedB);
  }

  Future<void> _startScan() async {
    final ok = await _ensurePerms();
    if (!ok) return;

    await _scanner.start(onNearestUpdate: (hit) async {
      if (_prompting) return;

      final label = hit.kind == BeaconKind.A ? 'A' : 'B';
      if (hit.kind == BeaconKind.A && _playedA) return;
      if (hit.kind == BeaconKind.B && _playedB) return;

      _prompting = true;
      final yes = await showPlayConfirmDialog(context, beaconLabel: label, name: hit.name);
      _prompting = false;

      if (yes == true) {
        await _scanner.stop();
        final vid = _pickVideo(hit.kind);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerPage(videoId: vid, title: 'Beacon $label 影片'),
          ),
        );

        setState(() {
          if (hit.kind == BeaconKind.A) {
            _playedA = true;
          } else {
            _playedB = true;
          }
        });
        await _savePlayedState();

        final other = (hit.kind == BeaconKind.A) ? BeaconKind.B : BeaconKind.A;
        final otherLabel = other == BeaconKind.A ? 'A' : 'B';
        final otherPlayed = (other == BeaconKind.A) ? _playedA : _playedB;

        if (!otherPlayed && mounted) {
          final yes2 = await showPlayOtherDialog(context, otherLabel);
          if (yes2 == true) {
            final vid2 = _pickVideo(other);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPage(videoId: vid2, title: 'Beacon $otherLabel 影片'),
              ),
            );
            setState(() {
              if (other == BeaconKind.A) {
                _playedA = true;
              } else {
                _playedB = true;
              }
            });
            await _savePlayedState();
          }
        }

        await _scanner.start();
      }
    });
  }

  String _pickVideo(BeaconKind kind) {
    final list = _videos[kind]!;
    final i = _nextIndex[kind] ?? 0;
    _nextIndex[kind] = (i + 1) % list.length;
    return list[i];
  }

  Future<void> _stopScan() async {
    await _scanner.stop();
  }

  Future<bool> _ensurePerms() async {
    final req = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final ok = req.values.every((s) => s.isGranted);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請允許藍牙與定位權限')),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Guide Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'AI 問答',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatPage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _scanner.scanning ? null : _startScan,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開始掃描'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _scanner.scanning ? _stopScan : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statusTile('Beacon A', _playedA),
            const SizedBox(height: 8),
            _statusTile('Beacon B', _playedB),
            const SizedBox(height: 24),
            const Text('提示：請讓 Beacon 開啟廣播、手機藍牙與定位權限皆已允許，並儘量靠近目標裝置。'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatPage()),
        ),
        icon: const Icon(Icons.psychology_alt),
        label: const Text('AI 問答'),
      ),
    );
  }

  Widget _statusTile(String title, bool played) {
    return ListTile(
      leading: Icon(
        played ? Icons.check_circle : Icons.fiber_manual_record,
        color: played ? Colors.green : Colors.orange,
      ),
      title: Text(title),
      subtitle: Text(played ? '已讀 / 已播放' : '未讀 / 尚未播放'),
    );
  }
}
