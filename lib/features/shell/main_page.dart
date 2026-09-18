import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/live_monitor/live_monitor_page.dart';
import '../../features/maintenance/maintenance_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/trips/trips_page.dart';
import '../../providers/app_providers.dart';
import '../../providers/auto_trip_settings_provider.dart';
import '../../providers/navigation_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final PageController _pageController;

  static const _pages = [
    DashboardPage(),
    LiveMonitorPage(),
    TripsPage(),
    MaintenancePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(currentTabIndexProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    ref.read(currentTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(currentTabIndexProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });

    ref.listen<AutoTripSettings>(autoTripSettingsProvider, (previous, next) {
      final service = ref.read(autoTripDetectionProvider);
      if (next.autoStartOnSpeedThreshold) {
        service.start();
      } else {
        service.stop();
      }
    }, weak: true);

    final currentIndex = ref.watch(currentTabIndexProvider);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Service'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
