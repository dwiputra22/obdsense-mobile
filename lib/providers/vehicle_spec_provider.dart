import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle_profile.dart';
import '../services/gear/gear_estimator.dart';
import 'app_providers.dart';
import 'gear_provider.dart';

final vehicleSpecSyncProvider = Provider<void>((ref) {
  final gear = ref.read(gearEstimatorProvider);
  ref.listen<VehicleProfile>(
    vehicleProfileProvider,
    (_, profile) => _applyToGear(gear, profile),
    fireImmediately: true,
  );
});

void _applyToGear(GearEstimator gear, VehicleProfile p) {
  final t = p.transmission;
  if (t == null) return;
  final continuous = t == 'CVT' || t == 'ECVT' || t == 'EV';
  gear.applyVehicle(
    key: '${p.brand}|${p.model}|${p.engineName}|$t|${p.gearCount ?? ''}',
    automatic: t != 'MT',
    continuous: continuous,
    gears: p.gearCount,
  );
}