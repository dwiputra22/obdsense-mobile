import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/auto_trip_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final autoTripSettings = ref.watch(autoTripSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tampilan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistem'),
                      icon: Icon(Icons.smartphone),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    ref.read(themeModeProvider.notifier).setMode(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koneksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.push('/obd-connect'),
                  child: const Text('Pengaturan OBD-II'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kendaraan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.push('/vehicle-profile'),
                  child: const Text('Profil Kendaraan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-mulai Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bukan baca dari Google Maps (tidak ada API publik untuk '
                  'itu) - dua metode nyata di bawah ini.',
                  style: TextStyle(color: context.palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Saat adapter OBD connect'),
                  subtitle: const Text('Tanpa biaya baterai tambahan'),
                  value: autoTripSettings.autoStartOnObdConnect,
                  onChanged: (value) => ref
                      .read(autoTripSettingsProvider.notifier)
                      .setAutoStartOnObdConnect(value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Saat kecepatan GPS terdeteksi berkendara'),
                  subtitle: const Text('GPS jalan terus di background - lebih boros baterai'),
                  value: autoTripSettings.autoStartOnSpeedThreshold,
                  onChanged: (value) => ref
                      .read(autoTripSettingsProvider.notifier)
                      .setAutoStartOnSpeedThreshold(value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
