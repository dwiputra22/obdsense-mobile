class MaintenanceRecord {
  final int? remoteId;
  final String title;
  final String notes;
  final DateTime date;
  final int odometer;

  const MaintenanceRecord({
    this.remoteId,
    required this.title,
    required this.notes,
    required this.date,
    required this.odometer,
  });

  Map<String, dynamic> toJson() {
    return {
      'remoteId': remoteId,
      'title': title,
      'notes': notes,
      'date': date.toIso8601String(),
      'odometer': odometer,
    };
  }

  factory MaintenanceRecord.fromJson(Map<dynamic, dynamic> json) {
    return MaintenanceRecord(
      remoteId: json['remoteId'] as int?,
      title: json['title'],
      notes: json['notes'],
      date: DateTime.parse(json['date']),
      odometer: json['odometer'],
    );
  }
}
