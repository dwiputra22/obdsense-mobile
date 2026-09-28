import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../services/trips/eco_driving_scorer.dart';
import '../../widgets/glass_card.dart';

class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  Color _ecoScoreColor(int score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.cyan;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripControllerProvider);
    final tripController = ref.read(tripControllerProvider.notifier);
    final tripActive = ref.watch(tripRecordingActiveProvider);
    final obdConnected = ref.watch(obdConnectionManagerProvider)?.isConnected == true;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(obdConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: obdConnected ? AppColors.green : palette.muted, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                tripActive ? 'Trip sedang direkam' : (obdConnected ? 'OBD siap merekam trip' : 'Hubungkan OBD untuk memulai trip'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
            ]),
            const SizedBox(height: 12),
            if (!tripActive)
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: obdConnected ? () async {
                  await tripController.startTrip();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip dimulai. Data OBD dan GPS sedang direkam.')));
                } : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(obdConnected ? 'Mulai Trip' : 'Mulai Trip • OBD Belum Tersambung'),
              ))
            else
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  await tripController.stopTrip();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip disimpan.')));
                },
                icon: const Icon(Icons.stop),
                label: const Text('Stop Trip'),
              )),
          ])),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/trip-comparison'), icon: const Icon(Icons.compare_arrows), label: const Text('Compare'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/gps-health-map'), icon: const Icon(Icons.map), label: const Text('Health Map'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/performance-test'), icon: const Icon(Icons.speed), label: const Text('Perf. Test'))),
          ]),
          const SizedBox(height: 16),
          if (trips.isEmpty)
            GlassCard(child: Text('Belum ada riwayat trip. Hubungkan OBD lalu mulai trip untuk merekam data kendaraan.', style: TextStyle(color: palette.muted))),
          ...trips.asMap().entries.map((entry) {
            final index = entry.key;
            final trip = entry.value;
            final synced = trip.remoteId != null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/trip-detail', extra: trip),
                child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(
                      trip.startAddress != null && trip.endAddress != null ? '${trip.startAddress} → ${trip.endAddress}' : Formatters.dateTime(trip.startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis,
                    )),
                    Icon(synced ? Icons.cloud_done : Icons.cloud_off, size: 18, color: synced ? AppColors.green : palette.muted),
                  ]),
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(trip.startTime), style: TextStyle(color: palette.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Jarak: ${trip.distanceKm.toStringAsFixed(1)} km'),
                  Text('Kecepatan rata-rata: ${trip.avgSpeed.toStringAsFixed(1)} km/j'),
                  Text('Suhu maksimum: ${trip.maxCoolantTempC.toStringAsFixed(1)}°C'),
                  if (trip.avgFuelConsumptionL100km > 0) Text('BBM: ${trip.avgFuelConsumptionL100km.toStringAsFixed(1)} L/100km (±${trip.fuelUsedLiters.toStringAsFixed(2)} L)'),
                  Row(children: [const Text('Eco score: '), Text('${trip.ecoScore} - ${EcoDrivingScorer.label(trip.ecoScore)}', style: TextStyle(fontWeight: FontWeight.bold, color: _ecoScoreColor(trip.ecoScore)))]),
                  if (!synced) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => tripController.retrySync(index, trip), icon: const Icon(Icons.cloud_upload, size: 16), label: const Text('Sinkronkan'))),
                ])),
              ),
            );
          }),
        ],
      ),
    );
  }
}
