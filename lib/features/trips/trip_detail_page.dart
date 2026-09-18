import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/trip_record.dart';
import '../../services/trips/eco_driving_scorer.dart';
import '../../widgets/glass_card.dart';

class TripDetailPage extends StatelessWidget {
  final TripRecord trip;

  const TripDetailPage({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final duration = trip.endTime.difference(trip.startTime);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (trip.route.length >= 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 240,
                child: _TripRouteMap(trip: trip),
              ),
            )
          else
            GlassCard(
              child: Text(
                'Rute GPS tidak tersedia untuk trip ini (izin lokasi belum '
                'diaktifkan saat trip berlangsung, atau GPS tidak menangkap '
                'cukup titik).',
                style: TextStyle(color: palette.muted),
              ),
            ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trip.startAddress != null) ...[
                  _AddressRow(icon: Icons.trip_origin, label: 'Dari', address: trip.startAddress!),
                  const SizedBox(height: 6),
                ],
                if (trip.endAddress != null)
                  _AddressRow(icon: Icons.location_on, label: 'Ke', address: trip.endAddress!),
                const Divider(height: 24),
                Text('Mulai: ${Formatters.dateTime(trip.startTime)}'),
                Text('Selesai: ${Formatters.dateTime(trip.endTime)}'),
                Text('Durasi: ${Formatters.duration(duration)}'),
                Text('Jarak tempuh: ${trip.distanceKm.toStringAsFixed(1)} km'),
                const SizedBox(height: 8),
                Text('Kecepatan rata-rata: ${trip.avgSpeed.toStringAsFixed(1)} km/j'),
                Text('Kecepatan maksimum: ${trip.maxSpeed.toStringAsFixed(1)} km/j'),
                Text('Suhu rata-rata: ${trip.avgCoolantTempC.toStringAsFixed(1)}°C'),
                Text('Suhu maksimum: ${trip.maxCoolantTempC.toStringAsFixed(1)}°C'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      trip.remoteId != null ? Icons.cloud_done : Icons.cloud_off,
                      size: 16,
                      color: trip.remoteId != null ? AppColors.green : palette.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trip.remoteId != null ? 'Tersinkron ke server' : 'Belum tersinkron',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konsumsi BBM & Eco-Driving',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (trip.avgFuelConsumptionL100km > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatBlock(
                          label: 'Konsumsi',
                          value: '${trip.avgFuelConsumptionL100km.toStringAsFixed(1)}',
                          unit: 'L/100km',
                          color: AppColors.orange,
                        ),
                      ),
                      Expanded(
                        child: _StatBlock(
                          label: 'BBM terpakai',
                          value: trip.fuelUsedLiters.toStringAsFixed(2),
                          unit: 'liter',
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else
                  Text(
                    'Data konsumsi BBM tidak tersedia untuk trip ini (ECU '
                    'kemungkinan tidak merespons PID MAF/fuel rate saat itu).',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                Row(
                  children: [
                    const Text('Eco score: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${trip.ecoScore}/100 - ${EcoDrivingScorer.label(trip.ecoScore)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _ecoScoreColor(trip.ecoScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimasi dari data RPM, throttle, dan kecepatan selama '
                  'trip - panduan kasar gaya berkendara, bukan penilaian '
                  'yang tersertifikasi.',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _ecoScoreColor(int score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.cyan;
    if (score >= 50) return AppColors.orange;
    return AppColors.red;
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
        Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
  final String label;
  final String address;

  const _AddressRow({required this.icon, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: address),
              ],
            ),
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
