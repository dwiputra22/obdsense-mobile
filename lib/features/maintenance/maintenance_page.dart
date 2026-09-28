import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';
import '../../widgets/glass_card.dart';

class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final notes = TextEditingController();
    final odo = TextEditingController();
    final cost = TextEditingController();
    final workshop = TextEditingController();
    final nextOdo = TextEditingController();
    String category = 'Servis Berkala';
    String status = 'Selesai';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Riwayat Maintenance'),
          content: SingleChildScrollView(
            child: Column(children: [
              _field(title, 'Judul servis', Icons.build),
              _field(notes, 'Catatan / part yang diganti', Icons.notes, maxLines: 3),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                items: const [
                  'Servis Berkala', 'Oli & Filter', 'Rem', 'Ban', 'Kelistrikan',
                  'Mesin', 'AC', 'Suspensi', 'Perbaikan', 'Lainnya',
                ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const ['Selesai', 'Terjadwal', 'Ditunda']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setDialogState(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              _field(odo, 'Odometer saat servis (km)', Icons.speed, keyboard: TextInputType.number),
              _field(cost, 'Biaya (Rp)', Icons.payments, keyboard: TextInputType.number),
              _field(workshop, 'Bengkel / teknisi', Icons.store),
              _field(nextOdo, 'Servis berikutnya pada km (opsional)', Icons.event_repeat, keyboard: TextInputType.number),
              const SizedBox(height: 4),
              Text('Data ini dipakai untuk melihat histori, biaya, status servis, dan pengingat servis berikutnya.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final record = MaintenanceRecord(
                  title: title.text.trim(),
                  notes: notes.text.trim(),
                  date: DateTime.now(),
                  odometer: int.tryParse(odo.text.trim()) ?? 0,
                  category: category,
                  status: status,
                  cost: double.tryParse(cost.text.replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0,
                  workshop: workshop.text.trim(),
                  nextOdometer: int.tryParse(nextOdo.text.trim()),
                );
                await ref.read(maintenanceControllerProvider.notifier).addRecord(record);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    for (final c in [title, notes, odo, cost, workshop, nextOdo]) c.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(maintenanceControllerProvider);
    final controller = ref.read(maintenanceControllerProvider.notifier);
    final palette = context.palette;
    final totalCost = records.fold<double>(0, (sum, r) => sum + r.cost);
    final scheduled = records.where((r) => r.status == 'Terjadwal').length;
    final next = records.where((r) => r.nextDate != null || r.nextOdometer != null).toList()
      ..sort((a, b) => (a.nextDate ?? DateTime(2999)).compareTo(b.nextDate ?? DateTime(2999)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        actions: [IconButton(onPressed: () => _showAddDialog(context, ref), icon: const Icon(Icons.add))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _summaryCard('Riwayat', '${records.length}', Icons.history)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('Terjadwal', '$scheduled', Icons.event_available)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('Biaya', _compactRupiah(totalCost), Icons.payments)),
          ]),
          const SizedBox(height: 14),
          if (next.isNotEmpty)
            GlassCard(child: Row(children: [
              const Icon(Icons.notification_important, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Servis berikutnya', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(_nextText(next.first), style: TextStyle(color: palette.muted, fontSize: 12)),
              ])),
            ])),
          if (next.isNotEmpty) const SizedBox(height: 12),
          if (records.isEmpty)
            GlassCard(child: Text('Belum ada histori maintenance. Tambahkan data servis agar aplikasi bisa membantu memantau biaya dan jadwal servis berikutnya.', style: TextStyle(color: palette.muted))),
          ...records.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;
            final synced = r.remoteId != null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  _statusChip(r.status),
                ]),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _chip(r.category, Icons.category),
                  _chip('${r.odometer} km', Icons.speed),
                  if (r.cost > 0) _chip(_rupiah(r.cost), Icons.payments),
                ]),
                if (r.workshop.isNotEmpty) ...[const SizedBox(height: 8), Text('Bengkel: ${r.workshop}')],
                if (r.notes.isNotEmpty) ...[const SizedBox(height: 8), Text(r.notes)],
                const SizedBox(height: 8),
                Text('Tanggal: ${Formatters.date(r.date)}', style: TextStyle(color: palette.muted, fontSize: 12)),
                if (r.nextOdometer != null || r.nextDate != null)
                  Padding(padding: const EdgeInsets.only(top: 3), child: Text(_nextText(r), style: TextStyle(color: palette.muted, fontSize: 12))),
                if (!synced) Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: () => controller.retrySync(index, r), icon: const Icon(Icons.cloud_upload, size: 16), label: const Text('Sinkronkan')),
                ),
              ])),
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18), const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 11)),
    ]),
  );

  Widget _chip(String text, IconData icon) => Chip(avatar: Icon(icon, size: 14), label: Text(text, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact);

  Widget _statusChip(String status) => Chip(label: Text(status, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact);

  String _nextText(MaintenanceRecord r) {
    final parts = <String>[];
    if (r.nextOdometer != null) parts.add('${r.nextOdometer} km');
    if (r.nextDate != null) parts.add(Formatters.date(r.nextDate!));
    return parts.isEmpty ? 'Belum ada jadwal servis berikutnya' : 'Berikutnya: ${parts.join(' / ')}';
  }

  String _rupiah(double value) => 'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => '.')}' ;
  String _compactRupiah(double value) => value >= 1000000 ? 'Rp ${(value / 1000000).toStringAsFixed(1)} jt' : value >= 1000 ? 'Rp ${(value / 1000).toStringAsFixed(0)} rb' : 'Rp ${value.toStringAsFixed(0)}';
}
