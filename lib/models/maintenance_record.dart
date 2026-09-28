class MaintenanceRecord {
  final int? remoteId;
  final String title;
  final String notes;
  final DateTime date;
  final int odometer;
  final String category;
  final String status;
  final double cost;
  final String workshop;
  final int? nextOdometer;
  final DateTime? nextDate;

  const MaintenanceRecord({
    this.remoteId,
    required this.title,
    required this.notes,
    required this.date,
    required this.odometer,
    this.category = 'Servis Berkala',
    this.status = 'Selesai',
    this.cost = 0,
    this.workshop = '',
    this.nextOdometer,
    this.nextDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'remoteId': remoteId,
      'title': title,
      'notes': notes,
      'date': date.toIso8601String(),
      'odometer': odometer,
      'category': category,
      'status': status,
      'cost': cost,
      'workshop': workshop,
      'nextOdometer': nextOdometer,
      'nextDate': nextDate?.toIso8601String(),
    };
  }

  factory MaintenanceRecord.fromJson(Map<dynamic, dynamic> json) {
    final rawCost = json['cost'];
    return MaintenanceRecord(
      remoteId: json['remoteId'] as int?,
      title: (json['title'] ?? '') as String,
      notes: (json['notes'] ?? '') as String,
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      odometer: (json['odometer'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? 'Servis Berkala') as String,
      status: (json['status'] ?? 'Selesai') as String,
      cost: rawCost is num ? rawCost.toDouble() : double.tryParse('$rawCost') ?? 0,
      workshop: (json['workshop'] ?? '') as String,
      nextOdometer: (json['nextOdometer'] as num?)?.toInt(),
      nextDate: json['nextDate'] == null
          ? null
          : DateTime.tryParse(json['nextDate'].toString()),
    );
  }

  MaintenanceRecord copyWith({
    int? remoteId,
    String? title,
    String? notes,
    DateTime? date,
    int? odometer,
    String? category,
    String? status,
    double? cost,
    String? workshop,
    int? nextOdometer,
    DateTime? nextDate,
  }) {
    return MaintenanceRecord(
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      category: category ?? this.category,
      status: status ?? this.status,
      cost: cost ?? this.cost,
      workshop: workshop ?? this.workshop,
      nextOdometer: nextOdometer ?? this.nextOdometer,
      nextDate: nextDate ?? this.nextDate,
    );
  }
}
