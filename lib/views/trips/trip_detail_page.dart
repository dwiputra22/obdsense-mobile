import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/trip_record.dart';
import '../../services/trips/eco_driving_scorer.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class TripDetailPage extends StatelessWidget {
  final TripRecord trip;

  const TripDetailPage({
    super.key,
    required this.trip,
  });

  Color _ecoScoreColor(int score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.cyan;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final duration = trip.endTime.difference(trip.startTime);
    final palette = context.palette;
    final synced = trip.remoteId != null;
    final ecoColor = _ecoScoreColor(trip.ecoScore);

    return AppPage(
      title: 'Trip Detail',
      subtitle: Formatters.dateTime(trip.startTime),
      trailing: StatusChip(
        text: synced ? 'Tersinkron' : 'Belum sinkron',
        color: synced ? AppColors.green : palette.muted,
        icon: synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
      ),
      children: [
        Reveal(
          index: 1,
          child: trip.route.length >= 2
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(height: 250, child: _TripRouteMap(trip: trip)),
                )
              : const NoticeCard(
                  icon: Icons.location_off_rounded,
                  text: 'Rute GPS tidak tersedia untuk trip ini (izin lokasi belum diaktifkan saat trip berlangsung, atau GPS tidak menangkap cukup titik).',
                ),
        ),
        const SizedBox(height: 14),
        if (trip.startAddress != null || trip.endAddress != null)
          Reveal(
            index: 2,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trip.startAddress != null)
                    _AddressRow(icon: Icons.trip_origin_rounded, color: AppColors.green, label: 'Dari', address: trip.startAddress!),
                  if (trip.startAddress != null && trip.endAddress != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 19, top: 2, bottom: 2),
                      child: Container(width: 2, height: 16, color: palette.border),
                    ),
                  if (trip.endAddress != null)
                    _AddressRow(icon: Icons.location_on_rounded, color: AppColors.red, label: 'Ke', address: trip.endAddress!),
                ],
              ),
            ),
          ),
        if (trip.startAddress != null || trip.endAddress != null) const SizedBox(height: 14),
        GridView.count(
padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            Reveal(index: 3, child: _StatTile(icon: Icons.route_rounded, color: AppColors.cyan, label: 'Jarak tempuh', value: trip.distanceKm, decimals: 1, unit: 'km')),
            Reveal(index: 4, child: _StatTile(icon: Icons.timer_rounded, color: AppColors.blue, label: 'Durasi', text: Formatters.duration(duration))),
            Reveal(index: 5, child: _StatTile(icon: Icons.speed_rounded, color: AppColors.green, label: 'Kec. rata-rata', value: trip.avgSpeed, decimals: 1, unit: 'km/j')),
            Reveal(index: 6, child: _StatTile(icon: Icons.bolt_rounded, color: AppColors.orange, label: 'Kec. maksimum', value: trip.maxSpeed, decimals: 1, unit: 'km/j')),
            Reveal(index: 7, child: _StatTile(icon: Icons.thermostat_rounded, color: AppColors.cyan, label: 'Suhu rata-rata', value: trip.avgCoolantTempC, decimals: 1, unit: '°C')),
            Reveal(
              index: 8,
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: trip.maxCoolantTempC >= 100 ? AppColors.red : AppColors.orange,
                label: 'Suhu maksimum',
                value: trip.maxCoolantTempC,
                decimals: 1,
                unit: '°C',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 9,
          child: GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Konsumsi BBM & Eco-Driving', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ProgressRing(
                      value: trip.ecoScore / 100,
                      size: 96,
                      strokeWidth: 10,
                      color: ecoColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedNumber(
                            value: trip.ecoScore.toDouble(),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ecoColor, height: 1.0),
                          ),
                          Text('eco', style: TextStyle(fontSize: 11, color: palette.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            EcoDrivingScorer.label(trip.ecoScore),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ecoColor, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estimasi dari RPM, throttle, dan kecepatan selama trip - panduan kasar, bukan penilaian tersertifikasi.',
                            style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (trip.avgFuelConsumptionL100km > 0)
                  Row(
                    children: [
                      Expanded(child: _StatBlock(label: 'Konsumsi', value: trip.avgFuelConsumptionL100km.toStringAsFixed(1), unit: 'L/100km', color: AppColors.orange)),
                      Expanded(child: _StatBlock(label: 'BBM terpakai', value: trip.fuelUsedLiters.toStringAsFixed(2), unit: 'liter', color: AppColors.cyan)),
                    ],
                  )
                else
                  Text(
                    'Data konsumsi BBM tidak tersedia untuk trip ini (ECU kemungkinan tidak merespons PID MAF/fuel rate saat itu).',
                    style: TextStyle(color: palette.muted, fontSize: 12, height: 1.35),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double? value;
  final int decimals;
  final String unit;
  final String? text;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.decimals = 0,
    this.unit = '',
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const style = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.0);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconBubble(icon: icon, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (value != null)
                AnimatedNumber(value: value!, decimals: decimals, style: style)
              else
                Text(text ?? '-', style: style),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(unit, style: TextStyle(color: palette.muted, fontSize: 11.5))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(color: context.palette.muted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _AddressRow({required this.icon, required this.color, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBubble(icon: icon, color: color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: context.palette.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripRouteMap extends StatelessWidget {
  final TripRecord trip;
  const _TripRouteMap({required this.trip});

  @override
  Widget build(BuildContext context) {
    final points = trip.route.map((p) => LatLng(p.lat, p.lng)).toList();

    final bounds = _boundsFor(points);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
      onMapCreated: (controller) {
        Future.delayed(const Duration(milliseconds: 300), () {
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
        });
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.cyan,
          width: 4,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Mulai', snippet: trip.startAddress),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Selesai', snippet: trip.endAddress),
        ),
        ...trip.healthEvents.map((e) => Marker(
              markerId: MarkerId('health_${e.lat}_${e.lng}_${e.sensorLabel}'),
              position: LatLng(e.lat, e.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                e.severity == 'warning' ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueYellow,
              ),
              infoWindow: InfoWindow(title: e.sensorLabel, snippet: 'Anomali (${e.severity})'),
            )),
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}