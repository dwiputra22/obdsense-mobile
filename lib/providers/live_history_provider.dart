import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

class LiveSample {
  const LiveSample(this.t, this.rpm, this.speed, this.temp, this.volt);

  final DateTime t;
  final double rpm;
  final double speed;
  final double temp;
  final double volt;
}

/// Riwayat sensor 1 sampel/detik (maks. 30 menit) untuk grafik Live Monitor.
/// Disimpan di provider (bukan State halaman) supaya tidak hilang saat pindah
/// tab. Hanya merekam saat OBD tersambung, jadi grafik tidak terisi nol palsu.
class LiveHistory extends ChangeNotifier {
  LiveHistory(this._ref) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  static const Duration maxAge = Duration(minutes: 30);

  final Ref _ref;
  Timer? _timer;
  final List<LiveSample> samples = [];
  bool _wasLive = false;

  void _tick() {
    final connected = _ref.read(obdConnectedProvider);
    final d = _ref.read(telemetryProvider);
    final live = connected && d.hasData;
    if (!live) {
      if (_wasLive || samples.isNotEmpty) {
        _wasLive = false;
        samples.clear();
        notifyListeners();
      }
      return;
    }
    _wasLive = true;
    final now = DateTime.now();
    samples.add(LiveSample(now, d.rpm, d.speed, d.coolantTempC, d.batteryVoltage));

    final cutoff = now.subtract(maxAge);
    var drop = 0;
    while (drop < samples.length && samples[drop].t.isBefore(cutoff)) {
      drop++;
    }
    if (drop > 0) samples.removeRange(0, drop);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveHistoryProvider = Provider<LiveHistory>((ref) {
  final history = LiveHistory(ref);
  ref.onDispose(history.dispose);
  return history;
});