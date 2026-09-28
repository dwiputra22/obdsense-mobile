import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/vehicle_health_score_calculator.dart';
import '../../widgets/glass_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Mechanic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Text(
              'Menganalisa DTC, anomali, dan health score mobil Anda lewat '
              'AI, lalu menjelaskannya dalam bahasa manusia. Setiap analisa '
              'memanggil API berbayar - dipicu manual, bukan otomatis.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.psychology),
              label: Text(_loading ? 'Menganalisa...' : 'Analisa Sekarang'),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            GlassCard(child: Text(_error!, style: const TextStyle(color: AppColors.red))),
          if (_result != null)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      const Text('Penjelasan AI Mechanic', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_result!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
