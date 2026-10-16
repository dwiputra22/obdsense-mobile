import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = 'gear_settings_v1';

class GearInput {
  const GearInput({required this.rpm, required this.speed, required this.connected});

  final double rpm;
  final double speed;
  final bool connected;
}

enum GearState { off, standstill, learning, shifting, gear }

@immutable
class GearReading {
  const GearReading({
    required this.state,
    required this.automatic,
    this.gear,
    this.known = 0,
    this.total = 0,
  });

  final GearState state;
  final bool automatic;
  final int? gear;

  /// Jumlah gigi yang rasionya sudah diketahui / jumlah gigi total.
  final int known;
  final int total;

  /// Teks besar di panel tengah gauge.
  String get label {
    switch (state) {
      case GearState.off:
        return '–';
      case GearState.standstill:
        return automatic ? 'P/N' : 'N';
      case GearState.learning:
        return '?';
      case GearState.shifting:
        return '–';
      case GearState.gear:
        return '${gear ?? '–'}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GearReading &&
      other.state == state &&
      other.automatic == automatic &&
      other.gear == gear &&
      other.known == known &&
      other.total == total;

  @override
  int get hashCode => Object.hash(state, automatic, gear, known, total);
}

/// Profil satu jenis transmisi: jumlah gigi + rasio tiap gigi dalam satuan
/// "rpm per km/j" (rpm ÷ kecepatan saat gigi itu terpasang).
class GearProfile {
  GearProfile({required this.count, List<double?>? ratios})
      : ratios = _fit(ratios ?? const <double?>[], count);

  int count;
  List<double?> ratios;

  static List<double?> _fit(List<double?> src, int n) =>
      List<double?>.generate(n, (i) => i < src.length ? src[i] : null);

  void resize(int n) {
    count = n;
    ratios = _fit(ratios, n);
  }

  int get known => ratios.where((r) => r != null).length;

  Map<String, dynamic> toJson() => {'count': count, 'ratios': ratios};

  static GearProfile fromJson(Map<String, dynamic>? j, int defaultCount) {
    final count = ((j?['count'] as num?)?.toInt() ?? defaultCount).clamp(3, 8);
    final raw = (j?['ratios'] as List?) ?? const [];
    return GearProfile(
      count: count,
      ratios: raw.map((e) => (e as num?)?.toDouble()).toList(),
    );
  }
}

class GearEstimator extends ChangeNotifier {
  GearEstimator({required GearInput Function() readInput}) : _readInput = readInput {
    _load();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  final GearInput Function() _readInput;
  Timer? _timer;
  Timer? _messageTimer;

  bool automatic = true;
  bool learning = true;
  final GearProfile _manual = GearProfile(count: 5);
  final GearProfile _auto = GearProfile(count: 4);
  GearProfile get profile => automatic ? _auto : _manual;

  GearReading reading = const GearReading(state: GearState.off, automatic: true);

  int learnedPeaks = 0;

  String? message;
  bool messageIsError = false;

  bool _loaded = false;
  double _lastSpeed = 0;
  double _lastRpm = 0;
  int? _shown;
  int? _cand;
  int _candTicks = 0;
  int _miss = 0;

  static const int _bins = 140;
  static const double _base = 15.0;
  static final double _lnStep = math.log(1.02);
  final List<double> _hist = List<double>.filled(_bins, 0);
  int _sinceExtract = 0;

  // ---------------------------------------------------------------- storage
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        automatic = j['automatic'] as bool? ?? true;
        learning = j['learning'] as bool? ?? true;
        final m = GearProfile.fromJson(j['manual'] as Map<String, dynamic>?, 5);
        final a = GearProfile.fromJson(j['auto'] as Map<String, dynamic>?, 4);
        _manual
          ..count = m.count
          ..ratios = m.ratios;
        _auto
          ..count = a.count
          ..ratios = a.ratios;
      }
    } catch (_) {
      // Pengaturan rusak/tidak terbaca.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'automatic': automatic,
          'learning': learning,
          'manual': _manual.toJson(),
          'auto': _auto.toJson(),
        }),
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------------- actions
  void setAutomatic(bool value) {
    if (automatic == value) return;
    automatic = value;
    _onProfileChanged();
  }

  void setGearCount(int n) {
    final c = n.clamp(3, 8);
    if (profile.count == c) return;
    profile.resize(c);
    _onProfileChanged();
  }

  void setLearning(bool value) {
    learning = value;
    _save();
    notifyListeners();
  }

  void setRatio(int index, double? value) {
    if (index < 0 || index >= profile.count) return;
    profile.ratios[index] = value;
    _shown = null;
    _save();
    notifyListeners();
  }

  /// Merekam rasio SAAT INI sebagai rasio gigi.
  String? calibrate(int index) {
    final inp = _readInput();
    if (!inp.connected) {
      return _setMessage('OBD belum tersambung.', true);
    }
    if (inp.speed < 10 || inp.rpm < 800) {
      return _setMessage(
        'Kalibrasi saat mobil berjalan stabil di gigi ${index + 1} (kecepatan ≥ 10 km/j).',
        true,
      );
    }
    final ratio = inp.rpm / inp.speed;
    setRatio(index, ratio);
    _setMessage('Gigi ${index + 1} tersimpan: ${ratio.toStringAsFixed(1)} rpm per km/j.', false);
    return null;
  }

  void resetAll() {
    profile.ratios = List<double?>.filled(profile.count, null);
    _onProfileChanged();
    _setMessage('Rasio direset. Berkendaralah agar dipelajari ulang.', false);
  }

  void _onProfileChanged() {
    _hist.fillRange(0, _bins, 0);
    _sinceExtract = 0;
    learnedPeaks = 0;
    _resetTracking();
    _save();
    notifyListeners();
  }

  String _setMessage(String text, bool error) {
    message = text;
    messageIsError = error;
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      message = null;
      notifyListeners();
    });
    notifyListeners();
    return text;
  }

  // -------------------------------------------------------------------- tick
  void _resetTracking() {
    _shown = null;
    _cand = null;
    _candTicks = 0;
    _miss = 0;
  }

  void _tick() {
    if (!_loaded) return;
    final inp = _readInput();
    final prevSpeed = _lastSpeed;
    final prevRpm = _lastRpm;
    _lastSpeed = inp.speed;
    _lastRpm = inp.rpm;
    final p = profile;

    GearReading next;
    if (!inp.connected || inp.rpm < 400) {
      _resetTracking();
      next = GearReading(state: GearState.off, automatic: automatic, known: p.known, total: p.count);
    } else if (inp.speed < 3) {
      _resetTracking();
      next = GearReading(state: GearState.standstill, automatic: automatic, known: p.known, total: p.count);
    } else {
      final r = inp.rpm / inp.speed;
      final steady = inp.speed >= 15 &&
          inp.rpm >= 900 &&
          inp.rpm <= 6500 &&
          (inp.speed - prevSpeed).abs() <= 1.2 &&
          (inp.rpm - prevRpm).abs() <= 250;
      if (learning && steady && p.known < p.count) _addSample(r);

      if (p.known == 0) {
        next = GearReading(state: GearState.learning, automatic: automatic, known: 0, total: p.count);
      } else {
        _debounce(_match(r, inp.speed, p));
        next = _shown != null
            ? GearReading(state: GearState.gear, automatic: automatic, gear: _shown, known: p.known, total: p.count)
            : GearReading(state: GearState.shifting, automatic: automatic, known: p.known, total: p.count);
      }
    }

    if (next != reading) {
      reading = next;
      notifyListeners();
    }
  }

  int? _match(double r, double speed, GearProfile p) {
    final tol = automatic ? 0.13 : 0.09;
    int? best;
    var bestErr = double.infinity;
    for (var i = 0; i < p.count; i++) {
      final e = p.ratios[i];
      if (e == null || e <= 0) continue;
      final err = math.log(r / e).abs();
      if (err < bestErr) {
        bestErr = err;
        best = i;
      }
    }
    if (best != null && bestErr <= tol) return best + 1;

    // Automatic: pada kecepatan rendah, selip torque converter membuat rasio
    // lebih tinggi dari gigi 1 -> tetap dianggap gigi 1.
    if (automatic && speed < 25 && p.ratios.isNotEmpty) {
      final e1 = p.ratios[0];
      if (e1 != null && r > e1 * math.exp(-tol)) return 1;
    }
    return null;
  }

  /// Histeresis: gigi baru harus konsisten beberapa tick sebelum ditampilkan;
  /// bila tak cocok >2 detik (kopling/perpindahan) tampil "–".
  void _debounce(int? g) {
    if (g == null) {
      _cand = null;
      _candTicks = 0;
      _miss++;
      if (_miss >= 4) _shown = null;
      return;
    }
    _miss = 0;
    if (g == _shown) {
      _cand = null;
      _candTicks = 0;
      return;
    }
    if (g == _cand) {
      _candTicks++;
    } else {
      _cand = g;
      _candTicks = 1;
    }
    final need = _shown == null ? 2 : 3;
    if (_candTicks >= need) {
      _shown = g;
      _cand = null;
      _candTicks = 0;
    }
  }

  // ---------------------------------------------------------------- learning
  void _addSample(double r) {
    final idx = (math.log(r / _base) / _lnStep).floor();
    if (idx < 0 || idx >= _bins) return;
    _hist[idx] += 1;
    if (++_sinceExtract >= 20) {
      _sinceExtract = 0;
      _extract();
    }
  }

  void _extract() {
    final p = profile;
    final n = p.count;

    final smooth = List<double>.filled(_bins, 0);
    for (var i = 0; i < _bins; i++) {
      var sum = 0.0;
      for (var k = -2; k <= 2; k++) {
        final j = i + k;
        if (j >= 0 && j < _bins) sum += _hist[j];
      }
      smooth[i] = sum;
    }

    const minCount = 12.0;
    final cands = <int>[];
    for (var i = 0; i < _bins; i++) {
      if (smooth[i] < minCount) continue;
      final left = i > 0 ? smooth[i - 1] : 0.0;
      final right = i < _bins - 1 ? smooth[i + 1] : 0.0;
      if (smooth[i] >= left && smooth[i] > right) cands.add(i);
    }
    cands.sort((a, b) => smooth[b].compareTo(smooth[a]));

    // Gigi bertetangga minimal ±10% berbeda rasionya (5 bin).
    final picked = <int>[];
    for (final c in cands) {
      if (picked.every((q) => (q - c).abs() >= 5)) picked.add(c);
      if (picked.length == n) break;
    }

    if (picked.length != learnedPeaks) {
      learnedPeaks = picked.length;
      notifyListeners();
    }
    if (picked.length < n) return;

    final ratios = <double>[];
    for (final c in picked) {
      var wsum = 0.0;
      var rsum = 0.0;
      for (var k = -2; k <= 2; k++) {
        final j = c + k;
        if (j < 0 || j >= _bins) continue;
        final w = _hist[j];
        wsum += w;
        rsum += w * _base * math.exp(_lnStep * (j + 0.5));
      }
      ratios.add(rsum / wsum);
    }
    // Gigi 1 = rasio terbesar (rpm tinggi per km/j).
    ratios.sort((a, b) => b.compareTo(a));

    var changed = false;
    for (var i = 0; i < n; i++) {
      if (p.ratios[i] == null) {
        p.ratios[i] = ratios[i];
        changed = true;
      }
    }
    if (changed) {
      _shown = null;
      _save();
      _setMessage('Rasio gigi berhasil dipelajari dari data berkendara.', false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }
}