import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auto_trip_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final autoTripSettings = ref.watch(autoTripSettingsProvider);
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            const Reveal(
              index: 0,
              child: ScreenHeader(title: 'Settings', subtitle: 'Tampilan, koneksi, dan kendaraan'),
            ),
            const Reveal(index: 1, child: SectionTitle('Tampilan')),
            Reveal(
              index: 2,
              child: PillTabs(
                labels: const ['Terang', 'Gelap', 'Sistem'],
                index: _modes.indexOf(themeMode).clamp(0, 2).toInt(),
                onChanged: (i) => ref.read(themeModeProvider.notifier).setMode(_modes[i]),
              ),
            ),
            const SizedBox(height: 20),
            const Reveal(index: 3, child: SectionTitle('Koneksi & kendaraan')),
            Reveal(
              index: 4,
              child: _SettingTile(
                icon: Icons.bluetooth_searching_rounded,
                color: AppColors.blue,
                title: 'Pengaturan OBD-II',
                subtitle: 'Hubungkan dan atur adapter ELM327',
                onTap: () => context.push('/obd-connect'),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: 5,
              child: _SettingTile(
                icon: Icons.directions_car_filled_rounded,
                color: AppColors.cyan,
                title: 'Profil Kendaraan',
                subtitle: 'Merek, model, tahun, dan VIN',
                onTap: () => context.push('/vehicle-profile'),
              ),
            ),
            const SizedBox(height: 20),
            const Reveal(index: 6, child: SectionTitle('Auto-mulai trip')),
            Reveal(
              index: 7,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Saat adapter OBD connect', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Tanpa biaya baterai tambahan', style: TextStyle(color: palette.muted, fontSize: 12)),
                      value: autoTripSettings.autoStartOnObdConnect,
                      onChanged: (value) =>
                          ref.read(autoTripSettingsProvider.notifier).setAutoStartOnObdConnect(value),
                    ),
                    Divider(color: palette.border, height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Saat GPS mendeteksi berkendara', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('GPS jalan terus di background', style: TextStyle(color: palette.muted, fontSize: 12)),
                      value: autoTripSettings.autoStartOnSpeedThreshold,
                      onChanged: (value) =>
                          ref.read(autoTripSettingsProvider.notifier).setAutoStartOnSpeedThreshold(value),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          child: Row(
            children: [
              IconBubble(icon: icon, color: color, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}