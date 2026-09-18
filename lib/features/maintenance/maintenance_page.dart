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
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final odoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Maintenance'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
              TextField(
                controller: odoController,
                decoration: const InputDecoration(labelText: 'Odometer'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final record = MaintenanceRecord(
                title: titleController.text,
                notes: notesController.text,
                date: DateTime.now(),
                odometer: int.tryParse(odoController.text) ?? 0,
              );

              await ref.read(maintenanceControllerProvider.notifier).addRecord(record);

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(maintenanceControllerProvider);
    final controller = ref.read(maintenanceControllerProvider.notifier);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (records.isEmpty)
            GlassCard(
              child: Text(
                'Belum ada catatan maintenance.',
                style: TextStyle(color: palette.muted),
              ),
            ),
          ...records.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;
            final synced = r.remoteId != null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Icon(
                          synced ? Icons.cloud_done : Icons.cloud_off,
                          size: 18,
                          color: synced ? AppColors.green : palette.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.notes),
                    const SizedBox(height: 8),
                    Text('Tanggal: ${Formatters.date(r.date)}'),
                    Text('Odometer: ${r.odometer} km'),
                    if (!synced) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => controller.retrySync(index, r),
                          icon: const Icon(Icons.cloud_upload, size: 16),
                          label: const Text('Sinkronkan'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
