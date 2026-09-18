class DtcScanRecord {
  final DateTime scannedAt;
  final List<String> codes;

  const DtcScanRecord({required this.scannedAt, required this.codes});

  Map<String, dynamic> toJson() => {
        'scannedAt': scannedAt.toIso8601String(),
        'codes': codes,
      };

  factory DtcScanRecord.fromJson(Map<dynamic, dynamic> json) {
    return DtcScanRecord(
      scannedAt: DateTime.parse(json['scannedAt']),
      codes: List<String>.from(json['codes']),
    );
  }
}
