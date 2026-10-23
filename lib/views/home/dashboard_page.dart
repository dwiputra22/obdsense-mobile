import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/navigation_provider.dart';
import '../../services/intelligence/vehicle_health_score_calculator.dart';
import '../../widgets/drive_scene.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/insight_card.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/scene_kit.dart';
import '../../widgets/ui_kit.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const double _overlap = 40;
  static const List<double> _previews = [7.5, 12.5, 16.8, 19.6, 23.5];

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _sceneHour = ValueNotifier<double>(hourNow());
  int _previewIdx = -1;
  double? _previewHour;

  @override
  void dispose() {
    _scroll.dispose();
    _sceneHour.dispose();
    super.dispose();
  }

  /// Tekan lama pada adegan: pratinjau kondisi hari.
  void _cyclePreview() {
    HapticFeedback.mediumImpact();
    setState(() {
      _previewIdx += 1;
      if (_previewIdx >= _previews.length) {
        _previewIdx = -1;
        _previewHour = null;
      } else {
        _previewHour = _previews[_previewIdx];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(telemetryProvider);
    final insights = ref.watch(aiInsightsProvider);
    final vehicle = ref.watch(vehicleProfileProvider);
    final anomalies = ref.watch(currentAnomaliesProvider);
    final obdConnected = ref.watch(obdConnectedProvider);
    final live = obdConnected && data.hasData;
    final palette = context.palette;

    final topPad = MediaQuery.paddingOf(context).top;
    final screenH = MediaQuery.sizeOf(context).height;
    final sceneH = topPad + 340;
    final visibleH = sceneH - _overlap;

    final hasVin = vehicle.vin != null;
    final score = hasVin
        ? VehicleHealthScoreCalculator.calculate(dtcCount: 0, milOn: false, recentAnomalies: anomalies)
        : 0;
    final scoreColor = score >= 70 ? AppColors.green : AppColors.orange;
    final vehicleName = [
      if (vehicle.brand.trim().isNotEmpty) vehicle.brand.trim(),
      if (vehicle.model.trim().isNotEmpty) vehicle.model.trim(),
      if (vehicle.year > 0) '${vehicle.year}',
    ].join(' ');

    return Scaffold(
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _scroll,
            builder: (context, _) {
              final off = _scroll.hasClients ? _scroll.offset.clamp(0.0, sceneH).toDouble() : 0.0;
              return Positioned(
                top: -off * 0.45,
                left: 0,
                right: 0,
                height: sceneH,
                child: DriveScene(
                  speedKmh: data.speed,
                  height: sceneH,
                  visibleHeight: visibleH,
                  hourOverride: _previewHour,
                  hourNotifier: _sceneHour,
                ),
              );
            },
          ),
          ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: visibleH,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: _cyclePreview,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 0),
                    child: ValueListenableBuilder<double>(
                      valueListenable: _sceneHour,
                      builder: (context, hour, _) {
                        final sky = SkyPalette.at(hour);
                        final phase = DayPhase.of(hour);
                        final ink = sky.onSky;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Reveal(
                              index: 0,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _previewHour != null ? '${phase.greeting} · pratinjau' : phase.greeting,
                                          style: TextStyle(color: ink.withValues(alpha: 0.82), fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          vehicleName.isEmpty ? 'Atur profil kendaraan' : vehicleName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  RoundIconButton(
                                    icon: Icons.settings_rounded,
                                    tooltip: 'Settings',
                                    onTap: () => ref.read(currentTabIndexProvider.notifier).state = 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Reveal(
                              index: 1,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AnimatedNumber(
                                    value: data.speed,
                                    style: TextStyle(color: ink, fontSize: 58, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -2),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text('km/j', style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 15, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Reveal(
                              index: 2,
                              child: Text(
                                live
                                    ? 'Mesin ${data.coolantTempC.toStringAsFixed(0)}°C · ${data.rpm.toStringAsFixed(0)} rpm'
                                    : (obdConnected ? 'Menunggu data kendaraan…' : 'OBD belum terhubung'),
                                style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(minHeight: screenH),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, -8)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      index: 1,
                      child: PressScale(
                        scale: 0.985,
                        child: GestureDetector(
                          onTap: () => context.push('/vehicle-health'),
                          child: GlassCard(
                            child: Row(
                              children: [
                                hasVin
                                    ? ProgressRing(
                                        value: score / 100,
                                        size: 78,
                                        strokeWidth: 8,
                                        color: scoreColor,
                                        child: AnimatedNumber(
                                          value: score.toDouble(),
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor),
                                        ),
                                      )
                                    : IconBubble(icon: Icons.favorite_border_rounded, color: palette.muted, size: 56),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kondisi kendaraan', style: TextStyle(color: palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(
                                        hasVin ? VehicleHealthScoreCalculator.label(score) : 'Belum aktif',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          StatusChip(
                                            text: obdConnected ? 'OBD terhubung' : 'OBD terputus',
                                            color: obdConnected ? AppColors.green : palette.muted,
                                            icon: obdConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                          ),
                                          if (hasVin)
                                            StatusChip(
                                              text: anomalies.isEmpty ? 'Tanpa anomali' : '${anomalies.length} anomali',
                                              color: anomalies.isEmpty ? AppColors.green : AppColors.orange,
                                            )
                                          else
                                            const StatusChip(text: 'Scan VIN dulu', color: AppColors.orange),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: palette.muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Reveal(index: 2, child: SectionTitle('Statistik langsung')),
                    GridView.count(
padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        Reveal(
                          index: 3,
                          child: MetricTile(
                            icon: Icons.thermostat_rounded,
                            numberValue: live ? data.coolantTempC : null,
                            label: 'Suhu mesin',
                            value: live ? data.coolantTempC.toStringAsFixed(0) : '-',
                            unit: '°C',
                            color: live && data.coolantTempC >= 100 ? AppColors.red : AppColors.cyan,
                          ),
                        ),
                        Reveal(
                          index: 4,
                          child: MetricTile(
                            icon: Icons.av_timer_rounded,
                            numberValue: live ? data.rpm : null,
                            label: 'RPM',
                            value: live ? data.rpm.toStringAsFixed(0) : '-',
                            unit: 'rpm',
                            color: AppColors.blue,
                          ),
                        ),
                        Reveal(
                          index: 5,
                          child: MetricTile(
                            icon: Icons.speed_rounded,
                            numberValue: live ? data.speed : null,
                            label: 'Kecepatan',
                            value: live ? data.speed.toStringAsFixed(0) : '-',
                            unit: 'km/j',
                            color: AppColors.green,
                          ),
                        ),
                        Reveal(
                          index: 6,
                          child: MetricTile(
                            icon: Icons.battery_charging_full_rounded,
                            numberValue: live ? data.batteryVoltage : null,
                            decimals: 1,
                            label: 'Voltase aki',
                            value: live ? data.batteryVoltage.toStringAsFixed(1) : '-',
                            unit: 'V',
                            color: live && data.batteryVoltage < 12.3 ? AppColors.orange : AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Reveal(index: 7, child: SectionTitle('Akses cepat')),
                    GridView.count(
padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.3,
                      children: [
                        Reveal(
                          index: 8,
                          child: _QuickTile(
                            icon: Icons.speed_rounded,
                            label: 'Live Monitor',
                            color: AppColors.cyan,
                            onTap: () => ref.read(currentTabIndexProvider.notifier).state = 1,
                          ),
                        ),
                        Reveal(
                          index: 9,
                          child: _QuickTile(
                            icon: Icons.car_repair_rounded,
                            label: 'Diagnostics',
                            color: AppColors.blue,
                            onTap: () => context.push('/diagnostics'),
                          ),
                        ),
                        Reveal(
                          index: 10,
                          child: _QuickTile(
                            icon: Icons.route_rounded,
                            label: 'Trips',
                            color: AppColors.orange,
                            onTap: () => ref.read(currentTabIndexProvider.notifier).state = 2,
                          ),
                        ),
                        Reveal(
                          index: 10,
                          child: _QuickTile(
                            icon: Icons.psychology_rounded,
                            label: 'AI Mechanic',
                            color: AppColors.purple,
                            onTap: () => context.push('/ai-mechanic'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('AI Insight'),
                    if (insights.isEmpty)
                      GlassCard(
                        child: Row(
                          children: [
                            IconBubble(icon: Icons.auto_awesome_rounded, color: palette.muted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Belum ada insight. Nyalakan Live Monitor sambil berkendara supaya AI punya data untuk dianalisis.',
                                style: TextStyle(color: palette.muted, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...insights.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InsightCard(insight: e),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Tahan adegan di atas untuk pratinjau pagi · siang · sore · malam',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.muted.withValues(alpha: 0.8), fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          radius: 20,
          child: Row(
            children: [
              IconBubble(icon: icon, color: color, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}