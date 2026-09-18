import 'package:hive/hive.dart';
import '../../models/dtc_scan_record.dart';

class DtcHistoryService {
  static const _boxName = 'dtc_history_box';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  String _key(String vin) => vin;

  Future<void> recordScan(String vin, List<String> codes) async {
    final box = Hive.box(_boxName);
    final key = _key(vin);
    final existingRaw = box.get(key) as List? ?? [];
    final history = existingRaw
        .map((e) => DtcScanRecord.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();

    history.add(DtcScanRecord(scannedAt: DateTime.now(), codes: codes));
    await box.put(key, history.map((e) => e.toJson()).toList());
  }

  List<DtcScanRecord> getHistory(String vin) {
    final box = Hive.box(_boxName);
    final raw = box.get(_key(vin)) as List? ?? [];
    return raw.map((e) => DtcScanRecord.fromJson(Map<dynamic, dynamic>.from(e))).toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  List<String> getNewlyAppeared(String vin) {
    final history = getHistory(vin);
    if (history.length < 2) return history.isEmpty ? [] : history.first.codes;
    final latest = history[0].codes.toSet();
    final previous = history[1].codes.toSet();
    return latest.difference(previous).toList();
  }

  List<String> getRecentlyCleared(String vin) {
    final history = getHistory(vin);
    if (history.length < 2) return [];
    final latest = history[0].codes.toSet();
    final previous = history[1].codes.toSet();
    return previous.difference(latest).toList();
  }
}
