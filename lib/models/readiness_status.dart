class ReadinessMonitor {
  final String name;
  final bool supported;
  final bool ready;

  const ReadinessMonitor({
    required this.name,
    required this.supported,
    required this.ready,
  });
}

class ReadinessStatus {
  final bool milOn;
  final int dtcCount;
  final bool isCompressionIgnition; // false = bensin (spark), true = diesel
  final List<ReadinessMonitor> monitors;

  const ReadinessStatus({
    required this.milOn,
    required this.dtcCount,
    required this.isCompressionIgnition,
    required this.monitors,
  });

  bool get allReady => monitors.where((m) => m.supported).every((m) => m.ready);
}
