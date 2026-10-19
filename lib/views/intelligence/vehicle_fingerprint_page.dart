import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/driving_state_classifier.dart';
import '../../services/intelligence/drift_detector.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

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
      return const AppPage(
        title: 'Vehicle Fingerprint',
        subtitle: 'Kepribadian mobil Anda',
        children: [
          NoticeCard(icon: Icons.qr_code_scanner_rounded, color: AppColors.orange, text: 'Belum ada VIN - scan dulu di Vehicle Profile.'),
        ],
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

    final stats = <Widget>[];
    var idx = 0;
    for (final stateEntry in baselines.entries) {
      for (final sensorEntry in stateEntry.value.entries.where((e) => e.value?.isReliable ?? false)) {
        final stat = sensorEntry.value!;
        stats.add(
          Reveal(
            index: 2 + (idx > 8 ? 8 : idx),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const IconBubble(icon: Icons.fingerprint_rounded, color: AppColors.cyan, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${_sensorLabels[sensorEntry.key]} (${stateEntry.key})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      '${stat.mean.toStringAsFixed(1)} ± ${stat.stdDev.toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.cyan),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        idx++;
      }
    }

    return AppPage(
      title: 'Vehicle Fingerprint',
      subtitle: 'Kepribadian mobil Anda',
      children: [
        const NoticeCard(
          icon: Icons.fingerprint_rounded,
          color: AppColors.cyan,
          text: 'Kebiasaan normal mobil ini, dipelajari dari riwayat berkendara mobil Anda sendiri, bukan standar pabrik.',
        ),
        const SizedBox(height: 14),
        if (stats.isEmpty)
          const NoticeCard(icon: Icons.hourglass_empty_rounded, text: 'Belum ada baseline yang cukup andal. Berkendara normal beberapa kali dulu.')
        else
          ...stats,
        const SizedBox(height: 8),
        const SectionTitle('Tren jangka panjang (drift)'),
        if (allDrifts.isEmpty)
          const NoticeCard(
            icon: Icons.timeline_rounded,
            text: 'Belum ada drift terdeteksi - baik belum cukup riwayat trip (butuh minimal 5 checkpoint), atau memang stabil.',
          )
        else
          ...allDrifts.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 20,
                child: Row(
                  children: [
                    IconBubble(
                      icon: d.newMean >= d.oldMean ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: AppColors.orange,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${d.sensorLabel} saat ${d.stateLabel}: ${d.direction} ${d.changePercent.toStringAsFixed(1)}% '
                        '(dari ${d.oldMean.toStringAsFixed(1)} ke ${d.newMean.toStringAsFixed(1)})',
                        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadingNarration ? null : () => _askAiToNarrate(allDrifts),
            icon: _loadingNarration
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.onPrimary))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_loadingNarration ? 'Menganalisa…' : 'Minta AI jelaskan tren ini'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            child: _error != null
                ? Padding(
                    key: const ValueKey('err'),
                    padding: const EdgeInsets.only(top: 12),
                    child: NoticeCard(icon: Icons.error_outline_rounded, color: AppColors.red, text: _error!),
                  )
                : _narration != null
                    ? Padding(
                        key: ValueKey(_narration),
                        padding: const EdgeInsets.only(top: 12),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.psychology_rounded, color: AppColors.cyan, size: 18),
                                  SizedBox(width: 8),
                                  Text('Penjelasan AI', style: TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(_narration!, style: const TextStyle(height: 1.4)),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ),
      ],
    );
  }
}

class VehicleBaselineServiceSensors {
  static const list = ['rpm', 'coolantTempC', 'batteryVoltage', 'engineLoad'];
}