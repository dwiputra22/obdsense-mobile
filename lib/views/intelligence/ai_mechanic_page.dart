import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/vehicle_health_score_calculator.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class AiMechanicPage extends ConsumerStatefulWidget {
  const AiMechanicPage({super.key});

  @override
  ConsumerState<AiMechanicPage> createState() => _AiMechanicPageState();
}

class _AiMechanicPageState extends ConsumerState<AiMechanicPage> {
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final vin = ref.read(vehicleProfileProvider).vin;
      final anomalies = ref.read(currentAnomaliesProvider);
      final vehicleId = ref.read(activeVehicleIdProvider);

      List<String> dtcCodes = [];
      if (vin != null) {
        final history = ref.read(dtcHistoryProvider).getHistory(vin);
        if (history.isNotEmpty) dtcCodes = history.first.codes;
      }

      final healthScore = VehicleHealthScoreCalculator.calculate(
        dtcCount: dtcCodes.length,
        milOn: dtcCodes.isNotEmpty,
        recentAnomalies: anomalies,
      );

      final context = {
        'dtc_codes': dtcCodes,
        'anomalies': anomalies
            .map((a) => {
                  'label': a.label,
                  'actual_value': a.actualValue,
                  'expected_mean': a.expectedMean,
                  'severity': a.severity,
                })
            .toList(),
        'health_score': healthScore,
      };

      final api = ref.read(apiServiceProvider);
      final explanation = await api.analyzeWithAiMechanic(vehicleId, context);
      setState(() => _result = explanation);
    } catch (e) {
      setState(() => _error = 'Gagal memanggil AI Mechanic: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildResult() {
    if (_error != null) {
      return NoticeCard(
        key: const ValueKey('error'),
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        text: _error!,
      );
    }
    if (_result != null) {
      return GlassCard(
        key: ValueKey(_result),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                IconBubble(icon: Icons.psychology_rounded, color: AppColors.cyan, size: 36),
                SizedBox(width: 10),
                Text('Penjelasan AI Mechanic', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Text(_result!, style: const TextStyle(height: 1.45)),
          ],
        ),
      );
    }
    return const SizedBox.shrink(key: ValueKey('empty'));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppPage(
      title: 'AI Mechanic',
      subtitle: 'Penjelasan kondisi mobil dalam bahasa manusia',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: palette.primary,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.onPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.psychology_rounded, color: palette.onPrimary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Analisa dengan AI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Menganalisa DTC, anomali, dan health score mobil Anda lewat AI, lalu menjelaskannya dalam bahasa manusia. Dipicu manual, bukan otomatis.',
                  style: TextStyle(color: palette.onPrimary.withValues(alpha: 0.78), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.onPrimary, foregroundColor: palette.primary),
                    onPressed: _loading ? null : _analyze,
                    icon: _loading
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.primary))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_loading ? 'Menganalisa…' : 'Analisa sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            child: _buildResult(),
          ),
        ),
      ],
    );
  }
}