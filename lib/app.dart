import 'package:flutter/material.dart';
import 'package:animated_splash_themes/animated_splash_themes.dart';
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
import 'features/intelligence/vehicle_fingerprint_page.dart';
import 'features/intelligence/vehicle_health_page.dart';
import 'features/trips/performance_test_page.dart';
import 'features/trips/trip_comparison_page.dart';
import 'features/shell/main_page.dart';
import 'features/trips/trip_detail_page.dart';
import 'features/settings/obd_connection_page.dart';
import 'features/settings/vehicle_profile_page.dart';
import 'models/trip_record.dart';
import 'providers/theme_provider.dart';

// Import service untuk inisialisasi di latar belakang splash
import 'services/intelligence/dtc_history_service.dart';
import 'services/intelligence/vehicle_baseline_service.dart';
import 'services/notifications/notification_service.dart';

class RushSenseApp extends StatefulWidget {
  const RushSenseApp({super.key});

  @override
  State<RushSenseApp> createState() => _RushSenseAppState();
}

class _RushSenseAppState extends State<RushSenseApp> {
  // Status untuk menentukan apakah aplikasi sudah selesai menampilkan splash
  bool _isSplashFinished = false;

  // Fungsi inisialisasi async agar berjalan serentak saat animasi splash aktif
  Future<void> _initializeAppServices() async {
    await VehicleBaselineService().init();
    await VehicleBaselineService().initSnapshots();
    await DtcHistoryService().init();
    final notifications = NotificationService();
    await notifications.init();
    
    // Tunggu sedikit ekstra agar animasi transisi selesai dengan mulus
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      setState(() {
        _isSplashFinished = true; // Hancurkan splash, aktifkan aplikasi utama
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAppServices(); // Mulai memuat data begitu aplikasi start
  }

  @override
  Widget build(BuildContext context) {
    // KONDISI 1: Jika belum selesai inisialisasi/durasi splash, tampilkan layar animasi saja
    if (!_isSplashFinished) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedSplashScreen(
          appName: 'RushSense AI',
          appSubtitle: 'INTELLIGENT OBD VEHICLE MONITOR',
          iconPath: 'assets/icon/icon-rushsense.png',
          theme: SplashStyle.neon,
          duration: const Duration(milliseconds: 2400),
          transitionDuration: const Duration(milliseconds: 700),
          backgroundColors: const [Color(0xFF020817), Color(0xFF06142F)],
          accentColor: const Color(0xFF22D3EE),
          nextScreen: const SizedBox.shrink(), // Dummy widget karena di-handle oleh status state
        ),
      );
    }

    // KONDISI 2: Jika splash selesai, tampilkan aplikasi utama secara permanen menggunakan GoRouter asli
    return const _MainAppContent();
  }
}

// Widget terpisah untuk Aplikasi Utama agar ConsumerWidget (Riverpod) berjalan normal tanpa mengganggu splash
class _MainAppContent extends ConsumerWidget {
  const _MainAppContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
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