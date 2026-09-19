import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/diagnostics/all_sensors_page.dart';
import 'features/diagnostics/data_recording_page.dart';
import 'features/diagnostics/diagnostics_page.dart';
import 'features/diagnostics/ecu_info_page.dart';
import 'features/diagnostics/freeze_frame_page.dart';
import 'features/diagnostics/readiness_page.dart';
import 'features/intelligence/ai_mechanic_page.dart';
import 'features/intelligence/baseline_status_page.dart';
import 'features/intelligence/dtc_timeline_page.dart';
import 'features/intelligence/gps_health_map_page.dart';
import 'features/intelligence/vehicle_health_page.dart';
import 'features/trips/performance_test_page.dart';
import 'features/trips/trip_comparison_page.dart';
import 'features/shell/main_page.dart';
import 'features/trips/trip_detail_page.dart';
import 'features/settings/obd_connection_page.dart';
import 'features/settings/vehicle_profile_page.dart';
import 'models/trip_record.dart';
import 'providers/theme_provider.dart';

class RushSenseApp extends ConsumerWidget {
  const RushSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const MainShell(),
        ),
        GoRoute(
          path: '/diagnostics',
          builder: (_, __) => const DiagnosticsPage(),
        ),
        GoRoute(
          path: '/all-sensors',
          builder: (_, __) => const AllSensorsPage(),
        ),
        GoRoute(
          path: '/readiness',
          builder: (_, __) => const ReadinessPage(),
        ),
        GoRoute(
          path: '/freeze-frame',
          builder: (_, __) => const FreezeFramePage(),
        ),
        GoRoute(
          path: '/ecu-info',
          builder: (_, __) => const EcuInfoPage(),
        ),
        GoRoute(
          path: '/data-recording',
          builder: (_, __) => const DataRecordingPage(),
        ),
        GoRoute(
          path: '/vehicle-health',
          builder: (_, __) => const VehicleHealthPage(),
        ),
        GoRoute(
          path: '/ai-mechanic',
          builder: (_, __) => const AiMechanicPage(),
        ),
        GoRoute(
          path: '/baseline-status',
          builder: (_, __) => const BaselineStatusPage(),
        ),
        GoRoute(
          path: '/dtc-timeline',
          builder: (_, __) => const DtcTimelinePage(),
        ),
        GoRoute(
          path: '/trip-comparison',
          builder: (_, __) => const TripComparisonPage(),
        ),
        GoRoute(
          path: '/gps-health-map',
          builder: (_, __) => const GpsHealthMapPage(),
        ),
        GoRoute(
          path: '/performance-test',
          builder: (_, __) => const PerformanceTestPage(),
        ),
        GoRoute(
          path: '/trip-detail',
          builder: (_, state) {
            final trip = state.extra as TripRecord;
            return TripDetailPage(trip: trip);
          },
        ),
        GoRoute(
          path: '/obd-connect',
          builder: (_, __) => const ObdConnectionPage(),
        ),
        GoRoute(
          path: '/vehicle-profile',
          builder: (_, __) => const VehicleProfilePage(),
        ),
      ],
    );

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RushSense AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}