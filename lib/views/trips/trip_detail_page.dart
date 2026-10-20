import 'dart:math' as math;
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import '../../core/i18n/translations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/health_event.dart';
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
              ? _TripMapSection(trip: trip)
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
                if (trip.avgKmPerLiter > 0)
                  Row(
                    children: [
                      Expanded(child: _StatBlock(label: 'Konsumsi', value: trip.avgKmPerLiter.toStringAsFixed(1), unit: 'km/L', color: AppColors.orange)),
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

// ---------------------------------------------------------------------------
// Peta perjalanan
// ---------------------------------------------------------------------------
const _watchColor = Color(0xFFF2C94C);

class _EventCluster {
  _EventCluster({
    required this.sensorLabel,
    required this.severity,
    required this.lat,
    required this.lng,
  });

  final String sensorLabel;
  String severity;
  final double lat;
  final double lng;
  int count = 1;

  bool get isWarning => severity == 'warning';

  String get id => 'event_${sensorLabel}_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';

  String get title => switch (sensorLabel) {
        'Suhu Mesin' => 'Suhu mesin tidak biasa',
        'Voltase Aki' => 'Voltase aki tidak biasa',
        'Beban Mesin' => 'Beban mesin tidak biasa',
        'RPM Idle' => 'Putaran idle tidak stabil',
        _ => '$sensorLabel tidak biasa',
      };

  String get severityText => isWarning ? 'Peringatan' : 'Perlu dipantau';

  Color get color => isWarning ? AppColors.orange : _watchColor;

  String get description => count <= 1
      ? 'Terdeteksi 1 kali di titik ini. Nilai sensor menyimpang dari kebiasaan kendaraan Anda.'
      : 'Terdeteksi $count kali di sekitar titik ini. Nilai sensor menyimpang dari kebiasaan kendaraan Anda.';
}

double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

List<_EventCluster> _clusterEvents(List<HealthEvent> events) {
  const radiusMeters = 250.0;
  final clusters = <_EventCluster>[];
  for (final e in events) {
    _EventCluster? target;
    for (final c in clusters) {
      if (c.sensorLabel == e.sensorLabel &&
          _distanceMeters(c.lat, c.lng, e.lat, e.lng) <= radiusMeters) {
        target = c;
        break;
      }
    }
    if (target == null) {
      clusters.add(_EventCluster(
        sensorLabel: e.sensorLabel,
        severity: e.severity,
        lat: e.lat,
        lng: e.lng,
      ));
    } else {
      target.count++;
      if (e.severity == 'warning') target.severity = 'warning';
    }
  }
  clusters.sort((a, b) {
    if (a.isWarning != b.isWarning) return a.isWarning ? -1 : 1;
    return b.count.compareTo(a.count);
  });
  return clusters;
}

class _TripMapSection extends StatefulWidget {
  const _TripMapSection({required this.trip});

  final TripRecord trip;

  @override
  State<_TripMapSection> createState() => _TripMapSectionState();
}

class _TripMapSectionState extends State<_TripMapSection> {
  GoogleMapController? _controller;
  late final List<_EventCluster> _clusters = _clusterEvents(widget.trip.healthEvents);

  Future<void> _focusEvent(_EventCluster c) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(c.lat, c.lng), 16));
      await controller.showMarkerInfoWindow(MarkerId(c.id));
    } catch (_) {}
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenRoutePage(trip: widget.trip, clusters: _clusters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 320,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _RouteMapView(
                    trip: widget.trip,
                    clusters: _clusters,
                    onController: (c) => _controller = c,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _MapFab(icon: Icons.fullscreen_rounded, tooltip: 'Layar penuh', onTap: _openFullscreen),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _MapFab(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Tampilkan seluruh rute',
                    onTap: () => _fitRoute(_controller, widget.trip),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'Geser untuk menjelajah, cubit untuk zoom. Ketuk pin untuk melihat detailnya.',
            style: TextStyle(color: palette.muted, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 12),
        _MapLegend(hasEvents: _clusters.isNotEmpty),
        const SizedBox(height: 12),
        _EventList(clusters: _clusters, onTap: _focusEvent),
      ],
    );
  }
}

class _FullscreenRoutePage extends StatefulWidget {
  const _FullscreenRoutePage({required this.trip, required this.clusters});

  final TripRecord trip;
  final List<_EventCluster> clusters;

  @override
  State<_FullscreenRoutePage> createState() => _FullscreenRoutePageState();
}

class _FullscreenRoutePageState extends State<_FullscreenRoutePage> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _RouteMapView(
              trip: widget.trip,
              clusters: widget.clusters,
              onController: (c) => _controller = c,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MapFab(icon: Icons.close_rounded, tooltip: 'Tutup', onTap: () => Navigator.of(context).pop()),
                  _MapFab(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Tampilkan seluruh rute',
                    onTap: () => _fitRoute(_controller, widget.trip),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

LatLngBounds _boundsFor(List<LatLng> points) {
  double minLat = points.first.latitude, maxLat = points.first.latitude;
  double minLng = points.first.longitude, maxLng = points.first.longitude;
  for (final p in points) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

Future<void> _fitRoute(GoogleMapController? controller, TripRecord trip) async {
  if (controller == null || trip.route.isEmpty) return;
  final points = trip.route.map((p) => LatLng(p.lat, p.lng)).toList();
  final b = _boundsFor(points);
  final degenerate = (b.northeast.latitude - b.southwest.latitude).abs() < 1e-5 &&
      (b.northeast.longitude - b.southwest.longitude).abs() < 1e-5;
  try {
    await controller.animateCamera(
      degenerate ? CameraUpdate.newLatLngZoom(points.first, 16) : CameraUpdate.newLatLngBounds(b, 56),
    );
  } catch (_) {
    // Peta belum selesai ukur layout; abaikan, pengguna bisa tekan lagi.
  }
}

class _RouteMapView extends StatelessWidget {
  const _RouteMapView({required this.trip, required this.clusters, this.onController});

  final TripRecord trip;
  final List<_EventCluster> clusters;
  final ValueChanged<GoogleMapController>? onController;

  @override
  Widget build(BuildContext context) {
    final points = trip.route.map((p) => LatLng(p.lat, p.lng)).toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
      onMapCreated: (controller) {
        onController?.call(controller);
        Future.delayed(const Duration(milliseconds: 300), () => _fitRoute(controller, trip));
      },
      // Gesture geser / cubit diambil oleh scroll halaman.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      polylines: {
        // Garis putih di bawah supaya rute tetap kontras di atas jalan/satelit.
        Polyline(
          polylineId: const PolylineId('route_outline'),
          points: points,
          color: Colors.white.withValues(alpha: 0.9),
          width: 9,
          zIndex: 1,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.cyan,
          width: 6,
          zIndex: 2,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: tr('Titik mulai'), snippet: trip.startAddress),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: tr('Titik selesai'), snippet: trip.endAddress),
        ),
        for (final c in clusters)
          Marker(
            markerId: MarkerId(c.id),
            position: LatLng(c.lat, c.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              c.isWarning ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueYellow,
            ),
            infoWindow: InfoWindow(
              title: tr(c.title),
              snippet: '${tr(c.severityText)} · ${tr(c.description)}',
            ),
          ),
      },
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr(tooltip),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: const Color(0xFF17261D)),
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.hasEvents});

  final bool hasEvents;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Keterangan peta', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              const _LegendItem(color: AppColors.cyan, label: 'Rute perjalanan', isLine: true),
              const _LegendItem(color: AppColors.green, label: 'Titik mulai'),
              const _LegendItem(color: AppColors.red, label: 'Titik selesai'),
              if (hasEvents) ...const [
                _LegendItem(color: AppColors.orange, label: 'Peringatan'),
                _LegendItem(color: _watchColor, label: 'Perlu dipantau'),
              ],
            ],
          ),
          if (hasEvents) ...[
            const SizedBox(height: 10),
            Text(
              'Pin oranye/kuning menandai tempat sensor kendaraan terbaca di luar kebiasaan normalnya (dibandingkan dengan pola mobil Anda sendiri). Ini indikasi untuk dipantau, bukan vonis kerusakan.',
              style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.isLine = false});

  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 20 : 12,
          height: isLine ? 5 : 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 3 : 6),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.clusters, required this.onTap});

  final List<_EventCluster> clusters;
  final void Function(_EventCluster) onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (clusters.isEmpty) {
      return const NoticeCard(
        icon: Icons.check_circle_outline_rounded,
        text: 'Tidak ada kejadian tidak biasa pada sensor kendaraan selama perjalanan ini.',
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catatan sepanjang rute (${clusters.length})',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Ketuk untuk melihat lokasinya di peta.', style: TextStyle(color: palette.muted, fontSize: 11.5)),
          const SizedBox(height: 8),
          for (final c in clusters)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onTap(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBubble(icon: Icons.location_on_rounded, color: c.color, size: 34),
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
                              Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              StatusChip(text: c.severityText, color: c.color),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(c.description, style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}