import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/gauge_templates.dart';
import '../../providers/app_providers.dart';
import '../../providers/gauge_template_provider.dart';
import '../../widgets/live_line_chart.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/speedometer_gauge.dart';

class LiveMonitorPage extends ConsumerStatefulWidget {
  const LiveMonitorPage({super.key});

  @override
  ConsumerState<LiveMonitorPage> createState() => _LiveMonitorPageState();
}

class _LiveMonitorPageState extends ConsumerState<LiveMonitorPage> {
  final List<double> tempHistory = [];
  final List<double> rpmHistory = [];

  @override
  Widget build(BuildContext context) {
    ref.listen(telemetryProvider, (previous, next) {
      setState(() {
        tempHistory.add(next.coolantTempC);
        rpmHistory.add(next.rpm);
        if (tempHistory.length > 20) tempHistory.removeAt(0);
        if (rpmHistory.length > 20) rpmHistory.removeAt(0);
      });
    });

    final data = ref.watch(telemetryProvider);
    final template = ref.watch(gaugeTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Ganti tampilan speedometer',
            onPressed: () => _showTemplatePicker(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SpeedometerGauge(
                  value: data.rpm,
                  min: 0,
                  max: 7000,
                  redlineFrom: 6000,
                  label: 'RPM',
                  unit: 'rpm',
                  template: template,
                  majorTicks: const [0, 1000, 2000, 3000, 4000, 5000, 6000, 7000],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SpeedometerGauge(
                  value: data.speed,
                  min: 0,
                  max: 220,
                  label: 'Kecepatan',
                  unit: 'km/j',
                  template: template,
                  majorTicks: const [0, 40, 80, 120, 160, 200],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              MetricTile(
                label: 'Suhu Mesin',
                value: data.coolantTempC.toStringAsFixed(0),
                unit: '°C',
                color: data.coolantTempC >= 100 ? AppColors.red : AppColors.cyan,
              ),
              MetricTile(
                label: 'Voltase',
                value: data.batteryVoltage.toStringAsFixed(1),
                unit: 'V',
                color: AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiveLineChart(
            values: tempHistory,
            title: 'Grafik Suhu Mesin',
            color: AppColors.cyan,
          ),
          const SizedBox(height: 16),
          LiveLineChart(
            values: rpmHistory,
            title: 'Grafik RPM',
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }

  void _showTemplatePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(gaugeTemplateProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GaugeTemplates.all.map((t) {
              return RadioListTile<GaugeTemplate>(
                title: Text(t.name),
                value: t,
                groupValue: current,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(gaugeTemplateProvider.notifier).setTemplate(value);
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
