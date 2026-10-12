import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/readiness_status.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/obd_response_validator.dart';
import '../../services/obd/readiness_parser.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class ReadinessPage extends ConsumerStatefulWidget {
  const ReadinessPage({super.key});

  @override
  ConsumerState<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends ConsumerState<ReadinessPage> {
  bool _loading = false;
  ReadinessStatus? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final manager = ref.read(obdConnectionManagerProvider);
    if (manager?.queue == null) {
      setState(() {
        _loading = false;
        _error = 'Belum terhubung ke adaptor OBD-II.';
      });
      return;
    }

    try {
      final response = await manager!.queue!.send('0101');
      if (!ObdResponseValidator.isValid(response)) {
        setState(() {
          _error = 'ECU tidak merespons permintaan status readiness.';
        });
        return;
      }
      final parsed = ReadinessParser.parse(response);
      setState(() {
        _status = parsed;
        if (parsed == null) _error = 'Gagal membaca data readiness.';
      });
    } catch (e) {
      setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final st = _status;
    final supported = st?.monitors.where((m) => m.supported).toList() ?? const [];
    final readyCount = supported.where((m) => m.ready).length;
    final fraction = supported.isEmpty ? 0.0 : readyCount / supported.length;
    final allReady = st?.allReady == true;
    final ringColor = allReady ? AppColors.green : AppColors.orange;

    return AppPage(
      title: 'Readiness',
      subtitle: 'Kesiapan uji emisi',
      trailing: RoundIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'Muat ulang',
        onTap: () {
          if (!_loading) _load();
        },
      ),
      children: [
        if (_loading)
          const LoadingBlock(label: 'Membaca monitor emisi…')
        else if (_error != null)
          NoticeCard(icon: Icons.info_outline_rounded, color: AppColors.orange, text: _error!)
        else if (st != null) ...[
          Reveal(
            index: 1,
            child: GlassCard(
              child: Row(
                children: [
                  ProgressRing(
                    value: fraction,
                    size: 88,
                    strokeWidth: 9,
                    color: ringColor,
                    child: Text('$readyCount/${supported.length}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ringColor)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allReady ? 'Semua monitor siap' : 'Ada monitor belum siap',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: ringColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allReady
                              ? 'Kemungkinan besar lolos uji emisi.'
                              : 'Kendarai mobil dengan pola normal beberapa hari supaya monitor selesai sebelum uji emisi.',
                          style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Reveal(
            index: 2,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(text: 'MIL ${st.milOn ? "menyala" : "mati"}', color: st.milOn ? AppColors.red : AppColors.green, icon: Icons.warning_amber_rounded),
                StatusChip(text: '${st.dtcCount} DTC tersimpan', color: st.dtcCount > 0 ? AppColors.orange : AppColors.green),
                StatusChip(text: st.isCompressionIgnition ? 'Diesel' : 'Bensin', color: AppColors.blue, icon: Icons.local_gas_station_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Monitor'),
          ...supported.asMap().entries.map((e) {
            final m = e.value;
            final color = m.ready ? AppColors.green : AppColors.orange;
            return Reveal(
              index: 3 + (e.key > 8 ? 8 : e.key),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  radius: 20,
                  child: Row(
                    children: [
                      IconBubble(icon: m.ready ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: color, size: 38),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      StatusChip(text: m.ready ? 'Siap' : 'Belum siap', color: color),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}