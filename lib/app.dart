import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'views/diagnostics/all_sensors_page.dart';
import 'views/diagnostics/data_recording_page.dart';
import 'views/diagnostics/diagnostics_page.dart';
import 'views/diagnostics/ecu_info_page.dart';
import 'views/diagnostics/freeze_frame_page.dart';
import 'views/diagnostics/readiness_page.dart';
import 'views/intelligence/ai_mechanic_page.dart';
import 'views/intelligence/baseline_status_page.dart';
import 'views/intelligence/dtc_timeline_page.dart';
import 'views/intelligence/gps_health_map_page.dart';
import 'views/intelligence/vehicle_fingerprint_page.dart';
import 'views/intelligence/vehicle_health_page.dart';
import 'views/trips/performance_test_page.dart';
import 'views/trips/trip_comparison_page.dart';
import 'views/shell/main_page.dart';
import 'views/trips/trip_detail_page.dart';
import 'views/settings/obd_connection_page.dart';
import 'views/settings/vehicle_profile_page.dart';
import 'models/trip_record.dart';
import 'views/splash/splash_page.dart';
import 'core/i18n/app_language.dart';
import 'providers/app_providers.dart';
import 'providers/gear_provider.dart';
import 'providers/live_history_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/vehicle_spec_provider.dart';
import 'providers/theme_provider.dart';

// Import service untuk inisialisasi di latar belakang splash
import 'services/intelligence/dtc_history_service.dart';
import 'services/intelligence/vehicle_baseline_service.dart';
import 'services/notifications/notification_service.dart';
import 'core/constants/app_constants.dart';

class RushSenseApp extends StatefulWidget {
  const RushSenseApp({super.key});

  @override
  State<RushSenseApp> createState() => _RushSenseAppState();
}

class _RushSenseAppState extends State<RushSenseApp> {
  // Progres inisialisasi NYATA (dipakai splash untuk menggerakkan mobil).
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool _ready = false;
  bool _splashDone = false;

  Future<void> _initializeAppServices() async {
    try {
      await VehicleBaselineService().init();
      await VehicleBaselineService().initSnapshots();
      _progress.value = 0.34;
      await DtcHistoryService().init();
      _progress.value = 0.67;
      await NotificationService().init();
      _progress.value = 1.0;
    } catch (e, st) {
      debugPrint('Inisialisasi service gagal: $e\n$st');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void initState() {
    super.initState();
    _initializeAppServices();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MainAppContent(
      ready: _ready,
      splashDone: _splashDone,
      progress: _progress,
      onSplashFinished: () {
        if (!mounted) return;
        setState(() => _splashDone = true);
        ProviderScope.containerOf(context, listen: false).read(splashDoneProvider.notifier).state = true;
      },
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const MainShell(),
    ),
    GoRoute(
      path: '/diagnostics',
      builder: (_, _) => const DiagnosticsPage(),
    ),
    GoRoute(
      path: '/all-sensors',
      builder: (_, _) => const AllSensorsPage(),
    ),
    GoRoute(
      path: '/readiness',
      builder: (_, _) => const ReadinessPage(),
    ),
    GoRoute(
      path: '/freeze-frame',
      builder: (_, _) => const FreezeFramePage(),
    ),
    GoRoute(
      path: '/ecu-info',
      builder: (_, _) => const EcuInfoPage(),
    ),
    GoRoute(
      path: '/data-recording',
      builder: (_, _) => const DataRecordingPage(),
    ),
    GoRoute(
      path: '/vehicle-health',
      builder: (_, _) => const VehicleHealthPage(),
    ),
    GoRoute(
      path: '/ai-mechanic',
      builder: (_, _) => const AiMechanicPage(),
    ),
    GoRoute(
      path: '/vehicle-fingerprint',
      builder: (_, _) => const VehicleFingerprintPage(),
    ),
    GoRoute(
      path: '/baseline-status',
      builder: (_, _) => const BaselineStatusPage(),
    ),
    GoRoute(
      path: '/dtc-timeline',
      builder: (_, _) => const DtcTimelinePage(),
    ),
    GoRoute(
      path: '/trip-comparison',
      builder: (_, _) => const TripComparisonPage(),
    ),
    GoRoute(
      path: '/gps-health-map',
      builder: (_, _) => const GpsHealthMapPage(),
    ),
    GoRoute(
      path: '/performance-test',
      builder: (_, _) => const PerformanceTestPage(),
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
      builder: (_, _) => const ObdConnectionPage(),
    ),
    GoRoute(
      path: '/vehicle-profile',
      builder: (_, _) => const VehicleProfilePage(),
    ),
  ],
);

class _MainAppContent extends ConsumerWidget {
  const _MainAppContent({
    required this.ready,
    required this.splashDone,
    required this.progress,
    required this.onSplashFinished,
  });

  final bool ready;
  final bool splashDone;
  final ValueListenable<double> progress;
  final VoidCallback onSplashFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    ref.read(liveHistoryProvider);
    ref.read(gearEstimatorProvider);
    ref.read(telemetryProvider);
    ref.read(vehicleSpecSyncProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: AppLanguage.instance,
          builder: (context, _) => AppLocaleScope(
            lang: AppLanguage.current,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ready) (child ?? const SizedBox.shrink()) else const SizedBox.shrink(),
                if (!splashDone)
                  SplashPage(progress: progress, ready: ready, onFinished: onSplashFinished),
              ],
            ),
          ),
        );
      },
    );
  }
}