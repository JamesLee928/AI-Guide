import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/beacon_models.dart';

/// 以裝置廣播名稱判斷 A/B：
/// - 名稱包含 "STab"   => A
/// - 名稱包含 "Basilisk X" => B
class BleScanner {
  StreamSubscription<List<ScanResult>>? _sub;

  BeaconHit? lastA;
  BeaconHit? lastB;

  bool get scanning => _sub != null;

  Future<void> start({void Function(BeaconHit nearest)? onNearestUpdate}) async {
    // 確保藍牙開啟
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      throw Exception('藍牙未開啟');
    }

    await FlutterBluePlus.startScan(
      withServices: const [],
      androidScanMode: AndroidScanMode.lowLatency,
    );

    _sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        final ad = r.advertisementData;
        final name = (ad.advName.isNotEmpty == true)
            ? ad.advName
            : (d.platformName.isNotEmpty ? d.platformName : '');
        if (name.isEmpty) continue;

        BeaconKind? kind;
        if (name.contains('STab')) {
          kind = BeaconKind.A;
        } else if (name.contains('Basilisk X')) {
          kind = BeaconKind.B;
        } else {
          continue;
        }

        final hit = BeaconHit(kind: kind, deviceId: d.remoteId.str, name: name, rssi: r.rssi);
        if (kind == BeaconKind.A) {
          lastA = _pickStronger(lastA, hit);
        } else {
          lastB = _pickStronger(lastB, hit);
        }
      }

      final nearest = _chooseNearest(lastA, lastB);
      if (nearest != null && onNearestUpdate != null) {
        onNearestUpdate(nearest);
      }
    });
  }

  Future<void> stop() async {
    await FlutterBluePlus.stopScan();
    await _sub?.cancel();
    _sub = null;
  }

  BeaconHit? _pickStronger(BeaconHit? current, BeaconHit next) {
    if (current == null) return next;
    return (next.rssi > current.rssi) ? next : current;
    }

  BeaconHit? _chooseNearest(BeaconHit? a, BeaconHit? b) {
    if (a == null) return b;
    if (b == null) return a;
    return (a.rssi >= b.rssi) ? a : b;
  }
}