import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/recording_session.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class DataRecordingPage extends ConsumerStatefulWidget {
  const DataRecordingPage({super.key});

  @override
  ConsumerState<DataRecordingPage> createState() => _DataRecordingPageState();
}

class _DataRecordingPageState extends ConsumerState<DataRecordingPage> {
  RecordingSession? _lastSession;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(dataRecordingProvider);
    final recordingActive = ref.watch(dataRecordingActiveProvider);
    final palette = context.palette;
    final obdConnected = ref.watch(obdConnectionManagerProvider)?.isConnected == true;

    return AppPage(
      title: 'Data Recording',
      subtitle: 'Rekam sensor mentah untuk diagnosa',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: palette.primary,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (recordingActive)
                      const PulseDot(color: AppColors.red)
                    else
                      Icon(obdConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: palette.onPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recordingActive ? 'Sedang merekam' : (obdConnected ? 'OBD siap merekam' : 'OBD belum tersambung'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (recordingActive) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedNumber(
                        value: recorder.sampleCount.toDouble(),
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('sample', style: TextStyle(color: palette.onPrimary.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.onPrimary, foregroundColor: palette.primary),
                    onPressed: recordingActive
                        ? () {
                            final session = recorder.stop();
                            ref.read(dataRecordingActiveProvider.notifier).state = false;
                            setState(() => _lastSession = session);
                          }
                        : (obdConnected
                            ? () {
                                recorder.start();
                                ref.read(dataRecordingActiveProvider.notifier).state = true;
                                setState(() => _lastSession = null);
                              }
                            : null),
                    icon: Icon(recordingActive ? Icons.stop_rounded : Icons.fiber_manual_record_rounded),
                    label: Text(recordingActive ? 'Stop rekaman' : (obdConnected ? 'Mulai rekaman' : 'Hubungkan OBD dulu')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const NoticeCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Beda dari Trip',
          text: 'Merekam SETIAP pembacaan sensor mentah untuk diagnosa detail. Bisa dijalankan tanpa mobil berjalan (mis. idle di parkiran sambil mendiagnosa masalah).',
        ),
        if (_lastSession != null) ...[
          const SizedBox(height: 12),
          Reveal(
            index: 3,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBubble(icon: Icons.save_alt_rounded, color: AppColors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rekaman terakhir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              '${_lastSession!.samples.length} sample · ${Formatters.dateTime(_lastSession!.startedAt)}',
                              style: TextStyle(color: palette.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportCsv,
                      icon: const Icon(Icons.share_rounded),
                      label: Text(_exporting ? 'Menyiapkan…' : 'Export & bagikan CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _exportCsv() async {
    if (_lastSession == null) return;
    setState(() => _exporting = true);
    try {
      final recorder = ref.read(dataRecordingProvider);
      final path = await recorder.exportToFile(_lastSession!);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Rekaman OBD RushSense AI'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}