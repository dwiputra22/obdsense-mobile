import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/dashboard_page.dart';
import '../live_monitor/live_monitor_page.dart';
import '../maintenance/maintenance_page.dart';
import '../settings/settings_page.dart';
import '../trips/trips_page.dart';
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
  Timer? _exitPromptTimer;
  bool _exitPromptVisible = false;

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
    _exitPromptTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBack() {
    final currentIndex = ref.read(currentTabIndexProvider);

    // Any tab other than Home goes back to Dashboard first.
    if (currentIndex != 0) {
      ref.read(currentTabIndexProvider.notifier).state = 0;
      return;
    }

    // On Dashboard, require a second back press before leaving the app.
    if (_exitPromptVisible) {
      _exitPromptTimer?.cancel();
      _exitPromptVisible = false;
      SystemNavigator.pop();
      return;
    }

    _exitPromptVisible = true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tekan sekali lagi untuk keluar dari aplikasi.'),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    _exitPromptTimer?.cancel();
    _exitPromptTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _exitPromptVisible = false;
      }
    });
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

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
