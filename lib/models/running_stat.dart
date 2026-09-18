import 'dart:math' as math;

class RunningStat {
  int count;
  double mean;
  double _m2;

  RunningStat({this.count = 0, this.mean = 0, double m2 = 0}) : _m2 = m2;

  void add(double value) {
    count++;
    final delta = value - mean;
    mean += delta / count;
    final delta2 = value - mean;
    _m2 += delta * delta2;
  }

  double get variance => count > 1 ? _m2 / (count - 1) : 0;
  double get stdDev => math.sqrt(variance);

  bool get isReliable => count >= 30;

  Map<String, dynamic> toJson() => {'count': count, 'mean': mean, 'm2': _m2};

  factory RunningStat.fromJson(Map<dynamic, dynamic> json) {
    return RunningStat(
      count: json['count'] as int,
      mean: (json['mean'] as num).toDouble(),
      m2: (json['m2'] as num).toDouble(),
    );
  }
}
