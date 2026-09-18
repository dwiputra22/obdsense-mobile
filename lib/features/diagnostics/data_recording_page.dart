import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/recording_session.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Recording')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rekam Sesi Mentah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Beda dari Trip - ini merekam SETIAP pembacaan sensor mentah '
                  'untuk diagnosa detail, bisa dijalankan tanpa mobil berjalan '
                  '(mis. sambil idle di parkiran mendiagnosa masalah).',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (recorder.isRecording) ...[
                  Text(
                    '● Merekam... ${recorder.sampleCount} sample',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final session = recorder.stop();
                        setState(() => _lastSession = session);
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Rekaman'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        recorder.start();
                        setState(() => _lastSession = null);
                      },
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Mulai Rekaman'),
                    ),
                  ),
              ],
            ),
          ),
          if (_lastSession != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rekaman Terakhir', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Mulai: ${Formatters.dateTime(_lastSession!.startedAt)}'),
                  Text('${_lastSession!.samples.length} sample tercatat'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _exportCsv,
                      icon: const Icon(Icons.share),
                      label: Text(_exporting ? 'Menyiapkan...' : 'Export & Bagikan CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
