enum BeaconKind { A, B }

class BeaconHit {
  final BeaconKind kind;
  final String deviceId;      // MAC / GUID
  final String name;          // 廣播名稱
  final int rssi;             // 強度
  BeaconHit({required this.kind, required this.deviceId, required this.name, required this.rssi});
}