import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

class DtcTimelinePage extends ConsumerWidget {
  const DtcTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vin = ref.watch(vehicleProfileProvider).vin;
    final palette = context.palette;

    if (vin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat DTC')),
        body: Center(
          child: Text('Belum ada VIN - scan dulu di Vehicle Profile.',
              style: TextStyle(color: palette.muted)),
        ),
      );
    }

    final history = ref.read(dtcHistoryProvider).getHistory(vin);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat DTC')),
      body: history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada riwayat scan DTC. Riwayat terkumpul tiap kali '
                  'Anda tekan "Scan DTC" di halaman Diagnostics.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final record = history[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.dateTime(record.scannedAt),
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        if (record.codes.isEmpty)
                          const Text('Bersih - tidak ada DTC',
                              style: TextStyle(color: AppColors.green))
                        else
                          Wrap(
                            spacing: 8,
                            children: record.codes
                                .map((c) => Chip(
                                      label: Text(c),
                                      backgroundColor: AppColors.red.withValues(alpha: 0.15),
                                      labelStyle: const TextStyle(color: AppColors.red),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
