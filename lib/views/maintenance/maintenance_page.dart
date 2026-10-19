import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';
import '../../core/i18n/translations.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  int _filter = 0;

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final record = await showDialog<MaintenanceRecord>(
      context: context,
      builder: (_) => const _AddMaintenanceDialog(),
    );
    if (record == null || !mounted) return;
    await ref.read(maintenanceControllerProvider.notifier).addRecord(record);
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(maintenanceControllerProvider);
    final controller = ref.read(maintenanceControllerProvider.notifier);
    final palette = context.palette;
    final totalCost = records.fold<double>(0, (sum, r) => sum + r.cost);
    final scheduled = records.where((r) => r.status == 'Terjadwal').length;
    final next = records.where((r) => r.nextDate != null || r.nextOdometer != null).toList()
      ..sort((a, b) => (a.nextDate ?? DateTime(2999)).compareTo(b.nextDate ?? DateTime(2999)));
    final visible = records.asMap().entries.where((e) {
      if (_filter == 1) return e.value.status == 'Terjadwal';
      if (_filter == 2) return e.value.status == 'Selesai';
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Reveal(
              index: 0,
              child: ScreenHeader(
                title: 'Maintenance',
                subtitle: records.isEmpty
                    ? 'Belum ada riwayat servis'
                    : '${records.length} riwayat · ${_compactRupiah(totalCost)}',
                trailing: RoundIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Tambah servis',
                  onTap: () => _showAddDialog(context, ref),
                ),
              ),
            ),
            Reveal(
              index: 1,
              child: Row(children: [
                Expanded(child: _summaryCard('Riwayat', '${records.length}', Icons.history_rounded, AppColors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard('Terjadwal', '$scheduled', Icons.event_available_rounded, AppColors.orange)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard('Biaya', _compactRupiah(totalCost), Icons.payments_rounded, AppColors.green)),
              ]),
            ),
            const SizedBox(height: 14),
            if (next.isNotEmpty) ...[
              Reveal(
                index: 2,
                child: GlassCard(
                  color: palette.primary,
                  radius: 28,
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.onPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: palette.onPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Servis berikutnya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          _nextText(next.first),
                          style: TextStyle(color: palette.onPrimary.withValues(alpha: 0.75), fontSize: 12.5),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Reveal(
              index: 3,
              child: PillTabs(
                labels: const ['Semua', 'Terjadwal', 'Selesai'],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              GlassCard(
                child: Row(children: [
                  IconBubble(icon: Icons.build_rounded, color: palette.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      records.isEmpty
                          ? 'Belum ada histori maintenance. Tambahkan data servis agar aplikasi bisa membantu memantau biaya dan jadwal servis berikutnya.'
                          : 'Tidak ada servis pada filter ini.',
                      style: TextStyle(color: palette.muted, height: 1.35),
                    ),
                  ),
                ]),
              ),
            ...visible.map((entry) {
              final index = entry.key;
              final r = entry.value;
              final synced = r.remoteId != null;
              final statusColor = _statusColor(r.status);

              return Padding(
                key: ValueKey('${r.date.microsecondsSinceEpoch}-${r.title}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconBubble(icon: Icons.build_rounded, color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                          const SizedBox(height: 3),
                          Text(Formatters.date(r.date), style: TextStyle(color: palette.muted, fontSize: 12)),
                        ]),
                      ),
                      StatusChip(text: r.status, color: statusColor),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      _chip(r.category, Icons.category_rounded),
                      _chip('${r.odometer} km', Icons.speed_rounded),
                      if (r.cost > 0) _chip(_rupiah(r.cost), Icons.payments_rounded),
                    ]),
                    if (r.workshop.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Bengkel: ${r.workshop}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if (r.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(r.notes, style: TextStyle(color: palette.muted, height: 1.35)),
                    ],
                    if (r.nextOdometer != null || r.nextDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_nextText(r), style: TextStyle(color: palette.muted, fontSize: 12)),
                      ),
                    if (!synced)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => controller.retrySync(index, r),
                          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: const Text('Sinkronkan'),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Terjadwal':
        return AppColors.orange;
      case 'Selesai':
        return AppColors.green;
      default:
        return AppColors.blue;
    }
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) => GlassCard(
    radius: 20,
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IconBubble(icon: icon, color: color, size: 32),
      const SizedBox(height: 10),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11.5, color: context.palette.muted, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chip(String text, IconData icon) => Chip(
    avatar: Icon(icon, size: 14),
    label: Text(text, style: const TextStyle(fontSize: 11)),
    visualDensity: VisualDensity.compact,
  );

  String _nextText(MaintenanceRecord r) {
    final parts = <String>[];
    if (r.nextOdometer != null) parts.add('${r.nextOdometer} km');
    if (r.nextDate != null) parts.add(Formatters.date(r.nextDate!));
    return parts.isEmpty ? 'Belum ada jadwal servis berikutnya' : 'Berikutnya: ${parts.join(' / ')}';
  }

  String _rupiah(double value) => 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => '.')}' ;
  String _compactRupiah(double value) => value >= 1000000 ? 'Rp ${(value / 1000000).toStringAsFixed(1)} jt' : value >= 1000 ? 'Rp ${(value / 1000).toStringAsFixed(0)} rb' : 'Rp ${value.toStringAsFixed(0)}';
}

class _AddMaintenanceDialog extends StatefulWidget {
  const _AddMaintenanceDialog();

  @override
  State<_AddMaintenanceDialog> createState() => _AddMaintenanceDialogState();
}

class _AddMaintenanceDialogState extends State<_AddMaintenanceDialog> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _odo = TextEditingController();
  final _cost = TextEditingController();
  final _workshop = TextEditingController();
  final _nextOdo = TextEditingController();
  String _category = 'Servis Berkala';
  String _status = 'Selesai';

  @override
  void dispose() {
    for (final c in [_title, _notes, _odo, _cost, _workshop, _nextOdo]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: tr(label),
          prefixIcon: Icon(icon, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    );
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      MaintenanceRecord(
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        date: DateTime.now(),
        odometer: int.tryParse(_odo.text.trim()) ?? 0,
        category: _category,
        status: _status,
        cost: double.tryParse(_cost.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0,
        workshop: _workshop.text.trim(),
        nextOdometer: int.tryParse(_nextOdo.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Riwayat Maintenance'),
      content: SingleChildScrollView(
        child: Column(children: [
          _field(_title, 'Judul servis', Icons.build_rounded),
          _field(_notes, 'Catatan / part yang diganti', Icons.notes_rounded, maxLines: 3),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: tr('Kategori')),
            items: const [
              'Servis Berkala', 'Oli & Filter', 'Rem', 'Ban', 'Kelistrikan',
              'Mesin', 'AC', 'Suspensi', 'Perbaikan', 'Lainnya',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: tr('Status')),
            items: const ['Selesai', 'Terjadwal', 'Ditunda']
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 12),
          _field(_odo, 'Odometer saat servis (km)', Icons.speed_rounded, keyboard: TextInputType.number),
          _field(_cost, 'Biaya (Rp)', Icons.payments_rounded, keyboard: TextInputType.number),
          _field(_workshop, 'Bengkel / teknisi', Icons.store_rounded),
          _field(_nextOdo, 'Servis berikutnya pada km (opsional)', Icons.event_repeat_rounded, keyboard: TextInputType.number),
          const SizedBox(height: 4),
          Text(
            'Data ini dipakai untuk melihat histori, biaya, status servis, dan pengingat servis berikutnya.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}