import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/trip_record.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';
import '../../core/i18n/translations.dart';

class TripComparisonPage extends ConsumerStatefulWidget {
  const TripComparisonPage({super.key});

  @override
  ConsumerState<TripComparisonPage> createState() => _TripComparisonPageState();
}

class _TripComparisonPageState extends ConsumerState<TripComparisonPage> {
  TripRecord? _a;
  TripRecord? _b;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripControllerProvider);
    final palette = context.palette;

    return AppPage(
      title: 'Trip Comparison',
      subtitle: 'Bandingkan dua perjalanan',
      children: [
        Reveal(
          index: 1,
          child: Row(
            children: [
              Expanded(child: _tripPicker('Trip A', trips, _a, (t) => setState(() => _a = t))),
              const SizedBox(width: 12),
              Expanded(child: _tripPicker('Trip B', trips, _b, (t) => setState(() => _b = t))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          child: (_a != null && _b != null)
              ? GlassCard(
                  key: const ValueKey('table'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(child: Center(child: StatusChip(text: 'A', color: AppColors.cyan))),
                          Expanded(child: Center(child: StatusChip(text: 'B', color: AppColors.purple))),
                        ],
                      ),
                      Divider(color: palette.border, height: 20),
                      _row('Tanggal', Formatters.date(_a!.startTime), Formatters.date(_b!.startTime)),
                      _row('Jarak', '${_a!.distanceKm.toStringAsFixed(1)} km', '${_b!.distanceKm.toStringAsFixed(1)} km'),
                      _row('Kec. rata-rata', '${_a!.avgSpeed.toStringAsFixed(0)} km/j', '${_b!.avgSpeed.toStringAsFixed(0)} km/j'),
                      _row('Kec. maksimum', '${_a!.maxSpeed.toStringAsFixed(0)} km/j', '${_b!.maxSpeed.toStringAsFixed(0)} km/j'),
                      _row('Suhu maks', '${_a!.maxCoolantTempC.toStringAsFixed(0)}°C', '${_b!.maxCoolantTempC.toStringAsFixed(0)}°C'),
                      _row('Konsumsi BBM', '${_a!.avgFuelConsumptionL100km.toStringAsFixed(1)} L/100km',
                          '${_b!.avgFuelConsumptionL100km.toStringAsFixed(1)} L/100km',
                          betterIsLower: true),
                      _row('Eco Score', '${_a!.ecoScore}', '${_b!.ecoScore}', betterIsLower: false),
                      _row('Anomali', '${_a!.healthEvents.length}', '${_b!.healthEvents.length}', betterIsLower: true),
                    ],
                  ),
                )
              : const NoticeCard(
                  key: ValueKey('hint'),
                  icon: Icons.compare_arrows_rounded,
                  text: 'Pilih 2 trip untuk dibandingkan.',
                ),
        ),
      ],
    );
  }

  Widget _tripPicker(String label, List<TripRecord> trips, TripRecord? selected, void Function(TripRecord) onPick) {
    return DropdownButtonFormField<TripRecord>(
      decoration: InputDecoration(labelText: tr(label)),
      initialValue: selected,
      isExpanded: true,
      items: trips
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(Formatters.dateTime(t.startTime), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (t) {
        if (t != null) onPick(t);
      },
    );
  }

  Widget _row(String label, String a, String b, {bool? betterIsLower}) {
    Color colorFor(String raw, String other) {
      if (betterIsLower == null) return context.palette.text;
      final va = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      final vb = double.tryParse(other.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (va == null || vb == null || va == vb) return context.palette.text;
      final aIsBetter = betterIsLower ? va < vb : va > vb;
      return aIsBetter ? AppColors.green : AppColors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: context.palette.muted, fontSize: 12.5))),
          Expanded(child: Text(a, style: TextStyle(color: colorFor(a, b), fontWeight: FontWeight.w800, fontSize: 13), textAlign: TextAlign.center)),
          Expanded(child: Text(b, style: TextStyle(color: colorFor(b, a), fontWeight: FontWeight.w800, fontSize: 13), textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
