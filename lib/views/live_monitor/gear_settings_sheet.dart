import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';

import '../../core/theme/app_colors.dart';
import '../../services/gear/gear_estimator.dart';
import '../../widgets/ui_kit.dart';
import '../../core/i18n/translations.dart';

Future<void> showGearSettings(BuildContext context, GearEstimator estimator) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => GearSettingsSheet(estimator: estimator),
  );
}

/// Pengaturan estimasi gigi.
class GearSettingsSheet extends StatelessWidget {
  const GearSettingsSheet({super.key, required this.estimator});

  final GearEstimator estimator;

  Future<void> _edit(
    BuildContext context,
    String title,
    double? current,
    ValueChanged<double> onSave,
  ) async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _RatioDialog(title: title, initial: current),
    );
    if (v != null) onSave(v);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AnimatedBuilder(
            animation: estimator,
            builder: (context, _) {
              final p = estimator.profile;
              final r = estimator.reading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const IconBubble(icon: Icons.settings_suggest_rounded, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pengaturan gigi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('Sesuaikan dengan transmisi mobil Anda.', style: TextStyle(color: palette.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      StatusChip(
                        text: 'Terbaca: ${r.label}',
                        color: r.state == GearState.gear ? AppColors.cyan : palette.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PillTabs(
                    labels: const ['Manual', 'Automatic'],
                    index: estimator.automatic ? 1 : 0,
                    onChanged: (i) => estimator.setAutomatic(i == 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bawaan mengikuti Toyota Rush 1.5: Manual 5 gigi, Automatic 4 gigi. Ubah jumlah gigi bila mobil Anda berbeda.',
                    style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: palette.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'OBD-II standar tidak menyediakan posisi gigi maupun posisi tuas. Gigi diestimasi dari rasio RPM ÷ kecepatan, '
                            'jadi rasio tiap gigi perlu dipelajari (otomatis saat berkendara) atau dikalibrasi manual. '
                            'Hasil bisa meleset saat pindah gigi, kopling ditekan, atau ada selip.',
                            style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (estimator.message != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (estimator.messageIsError ? AppColors.orange : AppColors.green).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        estimator.message!,
                        style: TextStyle(
                          color: estimator.messageIsError ? AppColors.orange : AppColors.green,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Text('Jumlah gigi', style: TextStyle(fontWeight: FontWeight.w700))),
                      _Stepper(
                        value: p.count,
                        onMinus: p.count > 3 ? () => estimator.setGearCount(p.count - 1) : null,
                        onPlus: p.count < 8 ? () => estimator.setGearCount(p.count + 1) : null,
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Belajar otomatis saat berkendara', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      p.known >= p.count
                          ? 'Semua rasio gigi sudah diketahui.'
                          : 'Pola terdeteksi: ${estimator.learnedPeaks}/${p.count} gigi. Butuh kecepatan stabil di tiap gigi.',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                    value: estimator.learning,
                    onChanged: estimator.setLearning,
                  ),
                  const SectionTitle('Rasio per gigi'),
                  for (var i = 0; i < p.count; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GearRow(
                        badge: '${i + 1}',
                        title: 'Gigi ${i + 1}',
                        calibrateTooltip: 'Kalibrasi: rekam rasio sekarang sebagai gigi ini',
                        ratio: p.ratios[i],
                        onCalibrate: () => estimator.calibrate(i),
                        onEdit: () => _edit(context, 'Rasio gigi ${i + 1}', p.ratios[i], (v) => estimator.setRatio(i, v)),
                        onClear: () => estimator.setRatio(i, null),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GearRow(
                      badge: 'R',
                      title: 'Mundur (R)',
                      calibrateTooltip: 'Kalibrasi: rekam rasio saat memundurkan mobil',
                      ratio: p.reverse,
                      onCalibrate: estimator.calibrateReverse,
                      onEdit: () => _edit(context, 'Rasio mundur (R)', p.reverse, estimator.setReverse),
                      onClear: () => estimator.setReverse(null),
                    ),
                  ),
                  if (estimator.automatic)
                    const _InfoRow(
                      badge: 'P/N',
                      title: 'Status tuas (P · R · N · D · L/S)',
                      text: 'Tidak terbaca dari OBD-II standar. P dan N tidak bisa dibedakan, R dikenali setelah rasio mundur dikalibrasi, dan L/S belum bisa dideteksi. Saat melaju tampil D + gigi aktif.',
                    )
                  else
                    const _InfoRow(
                      badge: 'N',
                      title: 'Netral (N)',
                      text: 'Terdeteksi otomatis: mobil diam, atau melaju dengan RPM jauh di bawah gigi tertinggi (netral atau kopling ditekan).',
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: estimator.resetAll,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset semua rasio'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onMinus, required this.onPlus});

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
          color: palette.bg,
          shape: CircleBorder(side: BorderSide(color: palette.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: onTap == null ? palette.muted.withValues(alpha: 0.4) : palette.text),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 40,
          child: Center(
            child: Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
        btn(Icons.add_rounded, onPlus),
      ],
    );
  }
}

class _GearRow extends StatelessWidget {
  const _GearRow({
    required this.badge,
    required this.title,
    required this.calibrateTooltip,
    required this.ratio,
    required this.onCalibrate,
    required this.onEdit,
    required this.onClear,
  });

  final String badge;
  final String title;
  final String calibrateTooltip;
  final double? ratio;
  final VoidCallback onCalibrate;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final known = ratio != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: known ? AppColors.cyan.withValues(alpha: 0.14) : palette.panel2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                badge,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: known ? AppColors.cyan : palette.muted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  known
                      ? '${ratio!.toStringAsFixed(1)} rpm per km/j · ≈ ${(2000 / ratio!).round()} km/j pada 2000 rpm'
                      : 'Belum dipelajari',
                  style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr(calibrateTooltip),
            icon: const Icon(Icons.my_location_rounded, size: 20),
            onPressed: onCalibrate,
          ),
          PopupMenuButton<String>(
            tooltip: tr('Opsi'),
            onSelected: (v) {
              if (v == 'edit') {
                onEdit();
              } else {
                onClear();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Ubah manual')),
              if (known) const PopupMenuItem(value: 'clear', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.badge, required this.title, required this.text});

  final String badge;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: palette.panel2, borderRadius: BorderRadius.circular(13)),
            child: Center(
              child: Text(badge, style: TextStyle(fontWeight: FontWeight.w800, fontSize: badge.length > 1 ? 11.5 : 16, color: palette.muted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog input rasio manual. Controller dimiliki State-nya sendiri (dibuang
/// setelah dialog benar-benar hilang).
class _RatioDialog extends StatefulWidget {
  const _RatioDialog({required this.title, this.initial});

  final String title;
  final double? initial;

  @override
  State<_RatioDialog> createState() => _RatioDialogState();
}

class _RatioDialogState extends State<_RatioDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial?.toStringAsFixed(1) ?? '');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v < 5 || v > 300) {
      setState(() => _error = 'Masukkan angka 5 - 300 (rpm per km/j).');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('rpm per km/j'), errorText: _error == null ? null : tr(_error!)),
          ),
          const SizedBox(height: 10),
          Text(
            'Contoh: 3000 rpm pada 100 km/j = 30,0',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}