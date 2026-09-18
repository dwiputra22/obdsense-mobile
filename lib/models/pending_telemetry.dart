class PendingTelemetry {
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingTelemetry({
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingTelemetry.fromJson(Map<dynamic, dynamic> json) {
    return PendingTelemetry(
      payload: Map<String, dynamic>.from(json['payload']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}