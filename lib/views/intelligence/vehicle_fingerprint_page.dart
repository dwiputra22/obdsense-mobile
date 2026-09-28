import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/driving_state_classifier.dart';
import '../../services/intelligence/drift_detector.dart';
import '../../widgets/glass_card.dart';

const _sensorLabels = {
  'rpm': 'RPM Idle',
  'coolantTempC': 'Suhu Mesin',
  'batteryVoltage': 'Voltase Aki',
  'engineLoad': 'Beban Mesin',
};

class VehicleFingerprintPage extends ConsumerStatefulWidget {
  const VehicleFingerprintPage({super.key});

  @override
  ConsumerState<VehicleFingerprintPage> createState() => _VehicleFingerprintPageState();
}

class _VehicleFingerprintPageState extends ConsumerState<VehicleFingerprintPage> {
  bool _loadingNarration = false;
  String? _narration;
  String? _error;

  Future<void> _askAiToNarrate(List<DriftSignal> allDrifts) async {
    setState(() {
      _loadingNarration = true;
      _error = null;
      _narration = null;
    });
    try {
      final vehicleId = ref.read(activeVehicleIdProvider);
      final api = ref.read(apiServiceProvider);
      final result = await api.analyzeWithAiMechanic(vehicleId, {
        'drift_signals': allDrifts
            .map((d) => {
                  'sensor_label': d.sensorLabel,
                  'state_label': d.stateLabel,
                  'old_mean': d.oldMean,
                  'new_mean': d.newMean,
                  'change_percent': d.changePercent,
                  'direction': d.direction,
                })
            .toList(),
      });
      setState(() => _narration = result);
    } catch (e) {
      setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loadingNarration = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vin = ref.watch(vehicleProfileProvider).vin;
    final palette = context.palette;

    if (vin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Fingerprint')),
        body: Center(
          child: Text('Belum ada VIN - scan dulu di Vehicle Profile.',
              style: TextStyle(color: palette.muted)),
        ),
      );
    }

    final baselineService = ref.read(vehicleBaselineProvider);
    final baselines = baselineService.getAllBaselines(vin);

    final allDrifts = <DriftSignal>[];
    for (final state in DrivingState.values) {
      for (final sensor in VehicleBaselineServiceSensors.list) {
        if (sensor == 'rpm' && state != DrivingState.idle) continue;
        final history = baselineService.getSnapshotHistory(vin, sensor, state);
        allDrifts.addAll(DriftDetector.detect(history, sensor, state.name));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Fingerprint')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Text(
              'Ini "kepribadian" mobil Anda - kebiasaan normalnya, dipelajari '
              'dari riwayat berkendara mobil ini sendiri, bukan standar pabrik.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ...baselines.entries.expand((stateEntry) {
            return stateEntry.value.entries.where((e) => e.value?.isReliable ?? false).map((sensorEntry) {
              final stat = sensorEntry.value!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_sensorLabels[sensorEntry.key]} (${stateEntry.key})'),
                      Text(
                        '${stat.mean.toStringAsFixed(1)} ± ${stat.stdDev.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan),
                      ),
                    ],
                  ),
                ),
              );
            });
          }),
          const SizedBox(height: 16),
          Text('Tren Jangka Panjang (Drift)', style: TextStyle(color: palette.text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (allDrifts.isEmpty)
            GlassCard(
              child: Text(
                'Belum ada drift terdeteksi - baik belum cukup riwayat trip '
                '(butuh minimal 5 checkpoint), atau memang stabil.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            )
          else
            ...allDrifts.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Text(
                      '${d.sensorLabel} saat ${d.stateLabel}: ${d.direction} '
                      '${d.changePercent.toStringAsFixed(1)}% (dari ${d.oldMean.toStringAsFixed(1)} '
                      'ke ${d.newMean.toStringAsFixed(1)})',
                      style: const TextStyle(color: AppColors.orange),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingNarration ? null : () => _askAiToNarrate(allDrifts),
              icon: _loadingNarration
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loadingNarration ? 'Menganalisa...' : 'Minta AI Jelaskan Tren Ini'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            GlassCard(child: Text(_error!, style: const TextStyle(color: AppColors.red))),
          ],
          if (_narration != null) ...[
            const SizedBox(height: 12),
            GlassCard(child: Text(_narration!)),
          ],
        ],
      ),
    );
  }
}

class VehicleBaselineServiceSensors {
  static const list = ['rpm', 'coolantTempC', 'batteryVoltage', 'engineLoad'];
}
