import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

class GpsHealthMapPage extends ConsumerWidget {
  const GpsHealthMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripControllerProvider);
    final palette = context.palette;

    final allEvents = trips.expand((t) => t.healthEvents).toList();

    if (allEvents.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('GPS Vehicle Health Map')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Belum ada anomali geotagged. Titik muncul di sini kalau ada '
              'sensor menyimpang dari baseline selama trip berjalan '
              '(butuh VIN + baseline sudah reliable - lihat Vehicle Health).',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted),
            ),
          ),
        ),
      );
    }

    final points = allEvents.map((e) => LatLng(e.lat, e.lng)).toList();
    final bounds = _boundsFor(points);

    return Scaffold(
      appBar: AppBar(title: const Text('GPS Vehicle Health Map')),
      body: Column(
        children: [
          GlassCard(
            child: Text(
              '${allEvents.length} titik anomali dari ${trips.length} trip.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: points.first, zoom: 11),
              onMapCreated: (controller) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
                });
              },
              markers: {
                for (var i = 0; i < allEvents.length; i++)
                  Marker(
                    markerId: MarkerId('health_$i'),
                    position: LatLng(allEvents[i].lat, allEvents[i].lng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      allEvents[i].severity == 'warning' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
                    ),
                    infoWindow: InfoWindow(title: allEvents[i].sensorLabel, snippet: allEvents[i].severity),
                  ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ],
      ),
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
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }
}
