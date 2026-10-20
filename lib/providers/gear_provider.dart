import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gear/gear_estimator.dart';
import 'app_providers.dart';

final gearEstimatorProvider = Provider<GearEstimator>((ref) {
  final estimator = GearEstimator(
    readInput: () {
      final connected = ref.read(obdConnectedProvider);
      final d = ref.read(telemetryProvider);
      return GearInput(rpm: d.rpm, speed: d.speed, connected: connected && d.hasData);
    },
  );
  ref.onDispose(estimator.dispose);
  return estimator;
});