import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/gauge_templates.dart';
import '../../providers/app_providers.dart';
import '../../providers/gauge_template_provider.dart';
import '../../providers/gear_provider.dart';
import '../../providers/live_history_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/series_chart.dart';
import '../../widgets/speedometer_gauge.dart';
import '../../services/gear/gear_estimator.dart';
import '../../widgets/ui_kit.dart';
import 'gear_settings_sheet.dart';

class LiveMonitorPage extends ConsumerStatefulWidget {
  const LiveMonitorPage({super.key});

  @override
  ConsumerState<LiveMonitorPage> createState() => _LiveMonitorPageState();
}

class _LiveMonitorPageState extends ConsumerState<LiveMonitorPage> {
  static const List<String> _rangeLabels = ['1m', '5m', '10m', '30m'];
  static const List<Duration> _ranges = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
  ];
  int _rangeIdx = 0;

  static String _thousands(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  List<ChartPoint> _series(List<LiveSample> samples, double Function(LiveSample) pick, DateTime start) =>
      [for (final x in samples) if (!x.t.isBefore(start)) ChartPoint(x.t, pick(x))];

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(telemetryProvider);
    final template = ref.watch(gaugeTemplateProvider);
    final history = ref.watch(liveHistoryProvider);
    final obdConnected = ref.watch(obdConnectedProvider);
    final gear = ref.watch(gearEstimatorProvider);

    final live = obdConnected && data.hasData;
    final tempColor = live && data.coolantTempC >= 100 ? AppColors.red : AppColors.cyan;
    final voltColor = live && data.batteryVoltage < 12.3 ? AppColors.orange : AppColors.purple;
    final fuelLevel = data.fuelLevelPercent;
    final fuelKnown = live && fuelLevel != null;

    final stats = <Widget>[
      _MiniStat(
        icon: Icons.thermostat_rounded,
        color: tempColor,
        label: 'Suhu mesin',
        value: live ? data.coolantTempC : null,
        unit: '°C',
        progress: data.coolantTempC / 130,
      ),
      _MiniStat(
        icon: Icons.battery_charging_full_rounded,
        color: voltColor,
        label: 'Voltase aki',
        value: live ? data.batteryVoltage : null,
        decimals: 1,
        unit: 'V',
        progress: (data.batteryVoltage - 10) / 5,
      ),
      _MiniStat(
        icon: Icons.local_gas_station_rounded,
        color: AppColors.blue,
        label: 'Level BBM',
        value: fuelKnown ? fuelLevel : null,
        unit: '%',
        progress: (fuelLevel ?? 0) / 100,
        unknownHint: live ? 'Tidak dilaporkan ECU' : null,
      ),
      _ObdStatusStat(connected: obdConnected),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Reveal(
              index: 0,
              child: ScreenHeader(
                title: 'Live Monitor',
                subtitle: obdConnected ? 'Data OBD-II real-time' : 'OBD belum tersambung',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (obdConnected) ...[
                      const PulseDot(color: AppColors.green, size: 8),
                      const SizedBox(width: 6),
                    ],
                    RoundIconButton(
                      icon: Icons.palette_outlined,
                      tooltip: 'Ganti tampilan speedometer',
                      onTap: () => _showTemplatePicker(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            // Kartu 1: gauge + kartu status di bawahnya.
            Reveal(
              index: 1,
              child: GlassCard(
                radius: 28,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        const centerW = 60.0;
                        final g = (c.maxWidth - centerW) / 2;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: g,
                              child: SpeedometerGauge(
                                value: data.rpm,
                                min: 0,
                                max: 7000,
                                redlineFrom: 6000,
                                label: 'RPM',
                                unit: 'rpm',
                                template: template,
                                tickDivisor: 1000,
                                majorTicks: const [0, 1000, 2000, 3000, 4000, 5000, 6000, 7000],
                              ),
                            ),
                            SizedBox(
                              width: centerW,
                              child: _CenterPanel(
                                estimator: gear,
                                connected: obdConnected,
                                onTap: () => showGearSettings(context, gear),
                              ),
                            ),
                            SizedBox(
                              width: g,
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
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Layar lebar: 4 kartu sebaris (seperti desain). Ponsel: 2 x 2
                    // supaya label & angka tetap terbaca.
                    LayoutBuilder(
                      builder: (context, c) {
                        if (c.maxWidth >= 520) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < stats.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(child: stats[i]),
                                ],
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: stats[0]),
                                  const SizedBox(width: 10),
                                  Expanded(child: stats[1]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: stats[2]),
                                  const SizedBox(width: 10),
                                  Expanded(child: stats[3]),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Kartu 2: Grafik Real-time (4 grafik mini + pilihan rentang waktu).
            Reveal(
              index: 2,
              child: GlassCard(
                radius: 28,
                padding: const EdgeInsets.all(12),
                child: AnimatedBuilder(
                  animation: history,
                  builder: (context, _) {
                    final window = _ranges[_rangeIdx];
                    final end = DateTime.now();
                    final start = end.subtract(window);
                    final s = history.samples;

                    Widget panel({
                      required String title,
                      required IconData icon,
                      required Color color,
                      required String value,
                      required String unit,
                      required double Function(LiveSample) pick,
                      required double yMin,
                      required double yMax,
                      required List<String> yLabels,
                    }) {
                      return _ChartPanel(
                        title: title,
                        icon: icon,
                        color: color,
                        value: obdConnected ? value : '—',
                        unit: unit,
                        chart: SeriesChart(
                          points: _series(s, pick, start),
                          color: color,
                          yMin: yMin,
                          yMax: yMax,
                          yLabels: yLabels,
                          window: window,
                          end: end,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            const IconBubble(icon: Icons.show_chart_rounded, size: 34),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Grafik Real-time',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                              ),
                            ),
                            _RangePills(
                              labels: _rangeLabels,
                              index: _rangeIdx,
                              onChanged: (i) => setState(() => _rangeIdx = i),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: panel(
                                  title: 'RPM',
                                  icon: Icons.av_timer_rounded,
                                  color: AppColors.green,
                                  value: _thousands(data.rpm),
                                  unit: 'RPM',
                                  pick: (x) => x.rpm,
                                  yMin: 0,
                                  yMax: 8000,
                                  yLabels: const ['8k', '4k', '0'],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: panel(
                                  title: 'Kecepatan',
                                  icon: Icons.speed_rounded,
                                  color: AppColors.cyan,
                                  value: data.speed.round().toString(),
                                  unit: 'KM/J',
                                  pick: (x) => x.speed,
                                  yMin: 0,
                                  yMax: 200,
                                  yLabels: const ['200', '100', '0'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: panel(
                                  title: 'Suhu mesin',
                                  icon: Icons.thermostat_rounded,
                                  color: AppColors.orange,
                                  value: data.coolantTempC.round().toString(),
                                  unit: '°C',
                                  pick: (x) => x.temp,
                                  yMin: 40,
                                  yMax: 120,
                                  yLabels: const ['120', '80', '40'],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: panel(
                                  title: 'Voltase aki',
                                  icon: Icons.battery_charging_full_rounded,
                                  color: AppColors.blue,
                                  value: data.batteryVoltage.toStringAsFixed(1),
                                  unit: 'V',
                                  pick: (x) => x.volt,
                                  yMin: 10,
                                  yMax: 16,
                                  yLabels: const ['16', '13', '10'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplatePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(gaugeTemplateProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplateSheet(
        initial: current,
        onApply: (t) => ref.read(gaugeTemplateProvider.notifier).setTemplate(t),
      ),
    );
  }
}

/// Pil rentang waktu kecil (1m / 5m / 10m / 30m) dengan highlight meluncur.
class _RangePills extends StatelessWidget {
  const _RangePills({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const seg = 36.0;
    return Container(
      width: seg * labels.length + 8,
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: index * seg,
            top: 0,
            bottom: 0,
            width: seg,
            child: DecoratedBox(
              decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(15)),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(
                  width: seg,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: i == index ? palette.onPrimary : palette.muted,
                        ),
                        child: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu panel grafik mini: ikon + nama, nilai saat ini di kanan, grafik di bawah.
class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.chart,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String unit;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(icon: icon, color: color, size: 26),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.1)),
                  Text(unit, style: TextStyle(color: palette.muted, fontSize: 9.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 96, child: chart),
        ],
      ),
    );
  }
}

/// Kartu status kecil di bawah gauge: ikon, label, angka, dan bar progres.
/// [value] null = tidak tersedia (ditampilkan "—").
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    this.decimals = 0,
    this.unknownHint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double? value;
  final String unit;
  final double progress;
  final int decimals;
  final String? unknownHint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = progress.isFinite ? progress.clamp(0.0, 1.0).toDouble() : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: icon, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (value == null)
            Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: palette.muted, height: 1.0))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedNumber(
                  value: value!,
                  decimals: decimals,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, height: 1.0, letterSpacing: -0.5),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (value == null && unknownHint != null)
            Text(unknownHint!, style: TextStyle(color: palette.muted, fontSize: 10.5))
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value == null ? 0 : p),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: palette.border,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu "Status OBD": titik berdenyut + Terhubung / Terputus (tanpa bar).
class _ObdStatusStat extends StatelessWidget {
  const _ObdStatusStat({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = connected ? AppColors.green : palette.muted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: Icons.memory_rounded, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status OBD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (connected)
                const PulseDot(color: AppColors.green, size: 7)
              else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: palette.muted)),
                ),
              Expanded(
                child: Text(
                  connected ? 'Terhubung' : 'Terputus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel tengah di antara dua gauge: gigi yang sedang terpasang (estimasi dari
/// rasio RPM/kecepatan, lihat GearEstimator), penanda AT/MT, dan titik OBD.
/// Ketuk untuk membuka pengaturan (Manual/Automatic, jumlah gigi, kalibrasi).
class _CenterPanel extends StatelessWidget {
  const _CenterPanel({required this.estimator, required this.connected, required this.onTap});

  final GearEstimator estimator;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: estimator,
      builder: (context, _) {
        final r = estimator.reading;
        final isGear = r.state == GearState.gear;
        final label = r.label;
        final color = isGear ? AppColors.cyan : palette.muted;
        return PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GIGI',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: palette.muted),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 30,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: TextStyle(
                          fontSize: label.length > 1 ? 16 : 26,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  if (r.state == GearState.learning)
                    Text('belajar', style: TextStyle(fontSize: 8.5, color: palette.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: palette.panel2, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      estimator.automatic ? 'AT' : 'MT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: palette.muted),
                    ),
                  ),
                  const SizedBox(height: 7),
                  connected
                      ? const PulseDot(color: AppColors.green, size: 6)
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: palette.muted),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet pilih template: pratinjau gauge nyata, nama, deskripsi,
/// radio, dan tombol "Terapkan" (pilihan baru berlaku setelah ditekan).
class _TemplateSheet extends StatefulWidget {
  const _TemplateSheet({required this.initial, required this.onApply});

  final GaugeTemplate initial;
  final ValueChanged<GaugeTemplate> onApply;

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  late GaugeTemplate _selected = widget.initial;

  static const Map<String, String> _desc = {
    'Neon Arc': 'Busur bergradasi dengan glow lembut. Bersih dan mudah dibaca untuk pemakaian sehari-hari.',
    'Classic Analog': 'Jarum analog dengan zona oranye-merah. Terasa seperti dasbor mobil sungguhan.',
    'Minimal': 'Busur tipis tanpa angka skala. Tampilan paling ringan dan lapang.',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBubble(icon: Icons.speed_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih template gauge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Pilih tampilan gauge yang sesuai preferensi Anda.',
                          style: TextStyle(color: palette.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final t in GaugeTemplates.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TemplateTile(
                  template: t,
                  description: _desc[t.name] ?? '',
                  recommended: t == GaugeTemplates.neonArc,
                  selected: t == _selected,
                  onTap: () => setState(() => _selected = t),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selected);
                  Navigator.of(context).pop();
                },
                child: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.description,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  final GaugeTemplate template;
  final String description;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? palette.soft : palette.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? palette.primary : palette.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: IgnorePointer(
                child: Row(
                  children: [
                    Expanded(child: SpeedometerGauge(value: 62, min: 0, max: 100, label: '', unit: '', template: template, redlineFrom: 85)),
                    Expanded(child: SpeedometerGauge(value: 38, min: 0, max: 100, label: '', unit: '', template: template)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(template.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (recommended) const StatusChip(text: 'Direkomendasikan', color: AppColors.cyan),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: palette.muted, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: Motion.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? palette.primary : Colors.transparent,
                border: Border.all(color: selected ? palette.primary : palette.muted.withValues(alpha: 0.5), width: 2),
              ),
              child: selected ? Icon(Icons.check_rounded, size: 15, color: palette.onPrimary) : null,
            ),
          ],
        ),
      ),
    );
  }
}