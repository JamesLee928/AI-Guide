import 'package:flutter/material.dart';

Future<bool?> showPlayConfirmDialog(
  BuildContext context, {
  required String beaconLabel,
  required String name,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('偵測到 Beacon $beaconLabel'),
      content: Text('裝置：$beaconLabel\n要播放這個地點的影片嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('先不要')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('播放')),
      ],
    ),
  );
}

Future<bool?> showPlayOtherDialog(BuildContext context, String otherLabel) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('要接著看另一個嗎？'),
      content: Text('要播放 Beacon $otherLabel 的影片嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('先不要')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('播放')),
      ],
    ),
  );
}