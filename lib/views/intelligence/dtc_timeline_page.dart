import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class DtcTimelinePage extends ConsumerWidget {
  const DtcTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vin = ref.watch(vehicleProfileProvider).vin;
    final palette = context.palette;

    if (vin == null) {
      return const AppPage(
        title: 'Riwayat DTC',
        subtitle: 'Linimasa kode error',
        children: [
          NoticeCard(icon: Icons.qr_code_scanner_rounded, color: AppColors.orange, text: 'Belum ada VIN - scan dulu di Vehicle Profile.'),
        ],
      );
    }

    final history = ref.read(dtcHistoryProvider).getHistory(vin);

    return AppPage(
      title: 'Riwayat DTC',
      subtitle: history.isEmpty ? 'Linimasa kode error' : '${history.length} kali scan',
      children: [
        if (history.isEmpty)
          const NoticeCard(
            icon: Icons.history_rounded,
            text: 'Belum ada riwayat scan DTC. Riwayat terkumpul tiap kali Anda tekan "Scan sekarang" di halaman Diagnostics.',
          )
        else
          for (var i = 0; i < history.length; i++)
            Reveal(
              index: 1 + (i > 8 ? 8 : i),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(top: 18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: history[i].codes.isEmpty ? AppColors.green : AppColors.red,
                              border: Border.all(color: palette.bg, width: 3),
                            ),
                          ),
                          if (i != history.length - 1)
                            Expanded(child: Container(width: 2, color: palette.border)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          radius: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Formatters.dateTime(history[i].scannedAt),
                                style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (history[i].codes.isEmpty)
                                const StatusChip(text: 'Bersih - tidak ada DTC', color: AppColors.green, icon: Icons.verified_rounded)
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: history[i].codes.map((c) => StatusChip(text: c, color: AppColors.red)).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}