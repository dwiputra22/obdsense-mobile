import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/trip_record.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Comparison')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _tripPicker('Trip A', trips, _a, (t) => setState(() => _a = t))),
              const SizedBox(width: 12),
              Expanded(child: _tripPicker('Trip B', trips, _b, (t) => setState(() => _b = t))),
            ],
          ),
          const SizedBox(height: 16),
          if (_a != null && _b != null)
            GlassCard(
              child: Column(
                children: [
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
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Pilih 2 trip untuk dibandingkan.', style: TextStyle(color: palette.muted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tripPicker(String label, List<TripRecord> trips, TripRecord? selected, void Function(TripRecord) onPick) {
    return DropdownButtonFormField<TripRecord>(
      decoration: InputDecoration(labelText: label),
      value: selected,
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
      if (betterIsLower == null) return Colors.white;
      final va = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      final vb = double.tryParse(other.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (va == null || vb == null || va == vb) return Colors.white;
      final aIsBetter = betterIsLower ? va < vb : va > vb;
      return aIsBetter ? AppColors.green : AppColors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(a, style: TextStyle(color: colorFor(a, b)), textAlign: TextAlign.center)),
          Expanded(child: Text(b, style: TextStyle(color: colorFor(b, a)), textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
