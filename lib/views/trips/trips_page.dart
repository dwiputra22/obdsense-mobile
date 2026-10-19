import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../services/trips/eco_driving_scorer.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  int _filter = 0;

  Color _ecoScoreColor(int score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.cyan;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripControllerProvider);
    final tripController = ref.read(tripControllerProvider.notifier);
    final tripActive = ref.watch(tripRecordingActiveProvider);
    final obdConnected = ref.watch(obdConnectionManagerProvider)?.isConnected == true;
    final palette = context.palette;

    final totalKm = trips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    // Simpan index asli karena retrySync memakai posisi di daftar penuh.
    final visible = trips.asMap().entries.where((e) {
      final synced = e.value.remoteId != null;
      if (_filter == 1) return synced;
      if (_filter == 2) return !synced;
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Reveal(
              index: 0,
              child: ScreenHeader(
                title: 'Trips',
                subtitle: trips.isEmpty
                    ? 'Belum ada perjalanan'
                    : '${trips.length} perjalanan · ${totalKm.toStringAsFixed(0)} km total',
              ),
            ),
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
                        if (tripActive)
                          const PulseDot(color: AppColors.red)
                        else
                          Icon(
                            obdConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: palette.onPrimary,
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tripActive
                                ? 'Trip sedang direkam'
                                : (obdConnected ? 'OBD siap merekam trip' : 'Hubungkan OBD untuk memulai trip'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.onPrimary,
                          foregroundColor: palette.primary,
                        ),
                        onPressed: tripActive
                            ? () async {
                                await tripController.stopTrip();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip disimpan.')));
                                }
                              }
                            : (obdConnected
                                ? () async {
                                    await tripController.startTrip();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Trip dimulai. Data OBD dan GPS sedang direkam.')),
                                      );
                                    }
                                  }
                                : null),
                        icon: Icon(tripActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        label: Text(tripActive ? 'Stop Trip' : (obdConnected ? 'Mulai Trip' : 'OBD belum tersambung')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: 2,
              child: Row(
                children: [
                  Expanded(child: _LinkTile(icon: Icons.compare_arrows_rounded, label: 'Compare', color: AppColors.blue, onTap: () => context.push('/trip-comparison'))),
                  const SizedBox(width: 10),
                  Expanded(child: _LinkTile(icon: Icons.map_rounded, label: 'Health Map', color: AppColors.green, onTap: () => context.push('/gps-health-map'))),
                  const SizedBox(width: 10),
                  Expanded(child: _LinkTile(icon: Icons.speed_rounded, label: 'Perf. Test', color: AppColors.orange, onTap: () => context.push('/performance-test'))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Reveal(
              index: 3,
              child: PillTabs(
                labels: const ['Semua', 'Tersinkron', 'Belum sinkron'],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              GlassCard(
                child: Row(
                  children: [
                    IconBubble(icon: Icons.route_rounded, color: palette.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trips.isEmpty
                            ? 'Belum ada riwayat trip. Hubungkan OBD lalu mulai trip untuk merekam data kendaraan.'
                            : 'Tidak ada trip pada filter ini.',
                        style: TextStyle(color: palette.muted, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ...visible.map((entry) {
              final index = entry.key;
              final trip = entry.value;
              final synced = trip.remoteId != null;
              final ecoColor = _ecoScoreColor(trip.ecoScore);
              return Padding(
                key: ValueKey(trip.startTime.microsecondsSinceEpoch),
                padding: const EdgeInsets.only(bottom: 12),
                child: PressScale(
                  child: GestureDetector(
                    onTap: () => context.push('/trip-detail', extra: trip),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconBubble(icon: Icons.route_rounded, color: ecoColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.startAddress != null && trip.endAddress != null
                                          ? '${trip.startAddress} → ${trip.endAddress}'
                                          : Formatters.dateTime(trip.startTime),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(Formatters.dateTime(trip.startTime), style: TextStyle(color: palette.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 20, color: synced ? AppColors.green : palette.muted),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _Stat(label: 'Jarak', value: '${trip.distanceKm.toStringAsFixed(1)} km')),
                              Expanded(child: _Stat(label: 'Rata-rata', value: '${trip.avgSpeed.toStringAsFixed(0)} km/j')),
                              Expanded(child: _Stat(label: 'Suhu maks', value: '${trip.maxCoolantTempC.toStringAsFixed(0)}°C')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              StatusChip(text: 'Eco ${trip.ecoScore} · ${EcoDrivingScorer.label(trip.ecoScore)}', color: ecoColor, icon: Icons.eco_rounded),
                              const Spacer(),
                              if (trip.avgFuelConsumptionL100km > 0)
                                Text(
                                  '${trip.avgFuelConsumptionL100km.toStringAsFixed(1)} L/100km',
                                  style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          if (!synced)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => tripController.retrySync(index, trip),
                                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                                label: const Text('Sinkronkan'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.palette.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.color, required this.onTap});

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
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              IconBubble(icon: icon, color: color, size: 38),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
