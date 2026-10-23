import 'dart:async';
import '../../models/dtc_code.dart';
import '../../models/telemetry_data.dart';
import '../trips/fuel_efficiency_calculator.dart';
import 'obd_command.dart';
import 'obd_connection_manager.dart';
import 'obd_parser.dart';
import 'dtc_parser.dart';
import 'obd_response_validator.dart';
import 'pid_support_checker.dart';
import 'pid_table.dart';

class ObdService {
  final ObdConnectionManager manager;
  final StreamController<TelemetryData> _telemetryController = StreamController.broadcast();
  final StreamController<Map<String, double>> _extraSensorsController =
      StreamController.broadcast();

  StreamSubscription<ObdLinkStatus>? _statusSub;
  Timer? _watchdogTimer;
  bool _polling = false;
  int _pollGeneration = 0;
  int _iteration = 0;
  int _slowIndex = 0;
  int _extendedIndex = 0;

  DateTime _lastValidData = DateTime.now();
  bool _ecuSilent = false;
  bool _emittedEmpty = true;
  bool _needPrime = true;
  bool _warm = false;
  bool _rpmOk = false;
  bool _speedOk = false;

  double _rpm = 0;
  double _speed = 0;
  double _coolant = 0;
  double _voltage = 0;
  double _load = 0;
  double _throttle = 0;
  double _intake = 0;

  double? _maf;
  double? _fuelRateDirect;
  double? _fuelLevel;
  int _fuelRateMissCount = 0;
  bool _fuelRatePidUnsupported = false;
  bool _mafUnsupported = false;
  bool _fuelLevelUnsupported = false;

  bool _mafFuelEstimateAllowed = true;

  void setFuelType(String? fuelType) {
    _mafFuelEstimateAllowed = fuelType != 'diesel' && fuelType != 'electric';
  }

  Set<String> supportedPids = {};
  List<PidDefinition> availableExtendedPids = [];
  final Map<String, double> _extraSensorReadings = {};

  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  Stream<Map<String, double>> get extraSensorsStream => _extraSensorsController.stream;

  bool get fuelLevelSupported => !_fuelLevelUnsupported;

  ObdService(this.manager) {
    manager.onReconnected = _handleReconnected;
    _statusSub = manager.statusStream.listen((status) {
      if (status != ObdLinkStatus.connected) {
        _clearValues();
        _publishEmpty();
      }
    });
  }

  Future<void> _handleReconnected() async {
    _clearValues();
    await initializeAdapter();
    _lastValidData = DateTime.now();
  }

  Future<void> initializeAdapter() async {
    await manager.queue!.send(ObdCommand.reset, timeout: const Duration(seconds: 4));
    await Future.delayed(const Duration(milliseconds: 800));
    await manager.queue!.send(ObdCommand.echoOff);
    await manager.queue!.send(ObdCommand.lineFeedOff);
    await manager.queue!.send(ObdCommand.spacesOff);
    await manager.queue!.send(ObdCommand.headersOff);
    await manager.queue!.send(ObdCommand.autoProtocol, timeout: const Duration(seconds: 4));

    await _discoverSupportedPids();
  }

  Future<void> _discoverSupportedPids() async {
    final supported = <String>{};

    try {
      final r1 = await manager.queue!.send('0100', timeout: const Duration(seconds: 3));
      if (!ObdResponseValidator.isValid(r1)) return;
      final group1 = PidSupportChecker.parseBitmask(r1, '4100', 0x00);
      supported.addAll(group1);

      if (PidSupportChecker.hasNextGroup(group1, 0x20)) {
        final r2 = await manager.queue!.send('0120', timeout: const Duration(seconds: 3));
        if (ObdResponseValidator.isValid(r2)) {
          final group2 = PidSupportChecker.parseBitmask(r2, '4120', 0x20);
          supported.addAll(group2);

          if (PidSupportChecker.hasNextGroup(group2, 0x40)) {
            final r3 = await manager.queue!.send('0140', timeout: const Duration(seconds: 3));
            if (ObdResponseValidator.isValid(r3)) {
              supported.addAll(PidSupportChecker.parseBitmask(r3, '4140', 0x40));
            }
          }
        }
      }
    } catch (_) {
      // Biarkan supportedPids apa adanya sejauh berhasil didapat.
    }

    supportedPids = supported;
    availableExtendedPids = PidTable.extended.where((p) => supported.contains(p.pid)).toList();

    if (supported.isNotEmpty) {
      _fuelLevelUnsupported = !supported.contains('2F');
      _fuelRatePidUnsupported = !supported.contains('5E');
      _mafUnsupported = !supported.contains('10');
    }
  }

  void startPolling() {
    stopPolling();
    _polling = true;
    final gen = ++_pollGeneration;
    _iteration = 0;
    _needPrime = true;
    _lastValidData = DateTime.now();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) => _watchdog());
    unawaited(_pollLoop(gen));
  }

  bool _alive(int gen) => _polling && gen == _pollGeneration;

  bool _canPoll() => manager.queue != null && manager.isConnected;

  Future<void> _pollLoop(int gen) async {
    while (_alive(gen)) {
      if (!_canPoll()) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      try {
        await _pollOnce(gen);
      } catch (_) {
        // Satu siklus gagal tidak boleh menghentikan loop.
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _pollOnce(int gen) async {
    _iteration++;

    // 1) Sensor cepat: RPM + kecepatan + sumber laju BBM, tiap siklus.
    await _readPid(ObdCommand.rpm, '410C', (r) {
      final v = ObdParser.parseRpm(r);
      if (v != null) {
        _rpm = v;
        _rpmOk = true;
      }
    }, timeout: const Duration(milliseconds: 900));
    if (!_alive(gen) || !_canPoll()) return;

    await _readPid(ObdCommand.speed, '410D', (r) {
      final v = ObdParser.parseSpeed(r);
      if (v != null) {
        _speed = v;
        _speedOk = true;
      }
    }, timeout: const Duration(milliseconds: 900));
    if (!_alive(gen) || !_canPoll()) return;

    await _readFuelSource();
    if (!_alive(gen) || !_canPoll()) return;

    // 2) Sensor lambat: satu per siklus, bergiliran.
    if (_needPrime && _rpmOk) {
      await _primeCore(gen);
    } else if (availableExtendedPids.isNotEmpty && _iteration % 4 == 3) {
      await _readNextExtended();
    } else {
      await _readNextCore();
    }
    if (!_alive(gen) || !_canPoll()) return;

    _publish();
  }

  /// Laju BBM: PID 015E langsung bila didukung, kalau tidak turunan dari MAF.
  Future<void> _readFuelSource() async {
    if (!_fuelRatePidUnsupported) {
      final ok = await _readPid(ObdCommand.fuelRate, '415E', (r) {
        _fuelRateDirect = ObdParser.parseFuelRate(r);
      });
      if (!ok || _fuelRateDirect == null) {
        _fuelRateMissCount++;
        if (_fuelRateMissCount >= 3) _fuelRatePidUnsupported = true;
      } else {
        _fuelRateMissCount = 0;
      }
    }
    if (_fuelRatePidUnsupported && !_mafUnsupported && _mafFuelEstimateAllowed) {
      await _readPid(ObdCommand.maf, '4110', (r) => _maf = ObdParser.parseMaf(r) ?? _maf);
    }
  }

  late final List<Future<void> Function()> _coreTasks = [
    _readCoolant,
    _readLoad,
    _readThrottle,
    _readIntake,
    _readFuelLevel,
    _readVoltage,
  ];

  Future<void> _readCoolant() => _readPid(ObdCommand.coolantTemp, '4105', (r) {
        final v = ObdParser.parseCoolantTempC(r);
        if (v != null) _coolant = v;
      });

  Future<void> _readLoad() =>
      _readPid(ObdCommand.engineLoad, '4104', (r) => _load = ObdParser.parseEngineLoad(r) ?? _load);

  Future<void> _readThrottle() => _readPid(
      ObdCommand.throttlePosition, '4111', (r) => _throttle = ObdParser.parseThrottle(r) ?? _throttle);

  Future<void> _readIntake() =>
      _readPid(ObdCommand.intakeTemp, '410F', (r) => _intake = ObdParser.parseIntakeTempC(r) ?? _intake);

  Future<void> _readFuelLevel() async {
    if (_fuelLevelUnsupported) return;
    await _readPid(ObdCommand.fuelLevel, '412F', (r) {
      final v = ObdParser.parseFuelLevel(r);
      if (v == null || v < 0 || v > 100) return;
      final prev = _fuelLevel;
      _fuelLevel = prev == null ? v : (prev * 0.7 + v * 0.3);
    });
  }

  Future<void> _readVoltage() async {
    try {
      final response = await manager.queue!.send(ObdCommand.voltage, timeout: const Duration(milliseconds: 900));
        if (ObdResponseValidator.isValid(response)) {
        _voltage = ObdParser.parseVoltage(response) ?? _voltage;
      }
    } catch (_) {}
  }

  Future<void> _readNextCore() async {
    if (_slowIndex >= _coreTasks.length) _slowIndex = 0;
    await _coreTasks[_slowIndex++]();
  }

  Future<void> _primeCore(int gen) async {
    for (final task in _coreTasks) {
      if (!_alive(gen) || !_canPoll()) return;
      await task();
    }
    _slowIndex = 0;
    _warm = true;
    _needPrime = false;
  }

  Future<void> _readNextExtended() async {
    if (availableExtendedPids.isEmpty) return;
    if (_extendedIndex >= availableExtendedPids.length) _extendedIndex = 0;
    final pidDef = availableExtendedPids[_extendedIndex++];
    try {
      final response = await manager.queue!.send('01${pidDef.pid}', timeout: const Duration(milliseconds: 1100));
        if (ObdResponseValidator.isValid(response)) {
        final bytes = _extractDataBytes(response, pidDef.pid, pidDef.expectedBytes);
        if (bytes != null) _extraSensorReadings[pidDef.pid] = pidDef.decode(bytes);
      }
    } catch (_) {
      // Satu PID gagal tidak boleh menghentikan seluruh siklus.
    }
    if (!_extraSensorsController.isClosed) {
      _extraSensorsController.add(Map.unmodifiable(_extraSensorReadings));
    }
  }

  List<int>? _extractDataBytes(String raw, String pidHex, int expectedBytes) {
    final s = ObdParser.sanitize(raw);
    final header = '41$pidHex';
    final idx = s.indexOf(header);
    if (idx == -1) return null;

    final dataStart = idx + header.length;
    final dataEnd = dataStart + (expectedBytes * 2);
    if (s.length < dataEnd) return null;

    final bytes = <int>[];
    for (int i = dataStart; i < dataEnd; i += 2) {
      bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<bool> _readPid(
    String command,
    String expectedHeader,
    void Function(String raw) onSuccess, {
    Duration timeout = const Duration(milliseconds: 1100),
  }) async {
    try {
      final response = await manager.queue!.send(command, timeout: timeout);
        if (!ObdResponseValidator.isValid(response)) return false;
      if (!ObdResponseValidator.containsPidResponse(response, expectedHeader)) return false;
      onSuccess(response);
      _lastValidData = DateTime.now();
      if (_ecuSilent) {
        _ecuSilent = false;
        _needPrime = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _watchdog() {
    if (!_polling) return;
    if (manager.status != ObdLinkStatus.connected) return;

    final now = DateTime.now();

    final lastReply = manager.lastReplyAt ?? now;
    if (now.difference(lastReply) > const Duration(seconds: 8)) {
      manager.reportLinkLost();
      return;
    }

    if (!_ecuSilent && now.difference(_lastValidData) > const Duration(seconds: 10)) {
      _ecuSilent = true;
      _clearValues();
      _publishEmpty();
    }
  }

  void _clearValues() {
    _rpm = 0;
    _speed = 0;
    _coolant = 0;
    _voltage = 0;
    _load = 0;
    _throttle = 0;
    _intake = 0;
    _maf = null;
    _fuelRateDirect = null;
    _fuelLevel = null;
    _fuelRateMissCount = 0;
    _rpmOk = false;
    _speedOk = false;
    _warm = false;
    _needPrime = true;
    _extraSensorReadings.clear();
    if (!_extraSensorsController.isClosed) {
      _extraSensorsController.add(const <String, double>{});
    }
  }

  void _publishEmpty() {
    if (_telemetryController.isClosed || _emittedEmpty) return;
    _emittedEmpty = true;
    _telemetryController.add(TelemetryData.empty());
  }

  void _publish() {
    if (_telemetryController.isClosed) return;
    final ready = _warm && _rpmOk && _speedOk && !_ecuSilent;
    if (!ready) {
      _publishEmpty();
      return;
    }
    _emittedEmpty = false;

    final fuelRate = _fuelRateDirect ??
        (_mafFuelEstimateAllowed ? FuelEfficiencyCalculator.fuelRateFromMaf(_maf) : null) ??
        0;
    _telemetryController.add(TelemetryData(
      rpm: _rpm,
      speed: _speed,
      coolantTempC: _coolant,
      batteryVoltage: _voltage,
      engineLoad: _load,
      throttlePosition: _throttle,
      intakeTempC: _intake,
      timestamp: DateTime.now(),
      fuelRateLph: fuelRate,
      fuelLevelPercent: _fuelLevel,
      hasData: true,
    ));
  }

  Future<List<DtcCode>> readDtc() async {
    try {
      final response = await manager.queue!.send(ObdCommand.readDtc);
      if (!ObdResponseValidator.isValid(response)) return [];
      return DtcParser.parse(response);
    } catch (_) {
      return [];
    }
  }

  void stopPolling() {
    _polling = false;
    _pollGeneration++;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void dispose() {
    stopPolling();
    _statusSub?.cancel();
    if (manager.onReconnected == _handleReconnected) {
      manager.onReconnected = null;
    }
    _telemetryController.close();
    _extraSensorsController.close();
  }
}