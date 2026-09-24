import 'dart:math' as math;

import '../../core/math/distributions.dart';
import '../../core/math/special.dart';
import '../../core/math/stats.dart';
import '../../core/rng/random_source.dart';
import '../../core/util/format.dart';
import '../content/figures.dart';
import '../sim/result_summary.dart';
import '../sim/simulation_engine.dart';
import '../sim/templates.dart';

/// Lógica pura (sin Flutter) de los 16 experimentos. Cada clase guarda su
/// estado, avanza con `add`/acciones y expone observaciones formateadas que
/// reemplazan las marcas `[[clave]]` del hallazgo.
abstract class ExperimentLogic {
  ExperimentLogic(this.id);

  final String id;

  /// Intento actual: cambia la semilla al «Reiniciar con otra semilla».
  int attempt = 0;

  int get seed => seedFor(id, attempt);

  /// Avance que cuenta para desbloquear el hallazgo.
  int get progress;

  /// Reinicia con la semilla del intento actual.
  void reset();

  void newSeed() {
    attempt++;
    reset();
  }

  Map<String, String> get observations;

  /// Agrega k repeticiones (los experimentos por niveles usan otras acciones).
  void add(int k) {}

  static ExperimentLogic create(String id) => switch (id) {
        'e1_pi' => PiLogic(),
        'e2_area' => AreaLogic(),
        'e3_seeds' => SeedsLogic(),
        'e4_lcg' => GeneratorLogic(),
        'e5_inverse' => InverseExpLogic(),
        'e6_discrete' => DiscreteLogic(),
        'e7_npv' => NpvLogic(),
        'e8_capacity' => CapacityLogic(),
        'e9_merge' => MergeLogic(),
        'e10_corr' => CorrLogic(),
        'e11_shape' => ShapeLogic(),
        'e12_sqrt_n' => SqrtNLogic(),
        'e13_rare' => RareLogic(),
        'e14_scurve' => SCurveLogic(),
        'e15_compare' => CompareLogic(),
        'e16_tornado' => TornadoLogic(),
        _ => throw ArgumentError('Experimento desconocido: $id'),
      };
}

/// Punto dibujable con una categoría (0/1) para colorear.
class Dot {
  const Dot(this.x, this.y, this.inside);
  final double x;
  final double y;
  final bool inside;
}

const int _maxDots = 4000;

// ------------------------------------------------------------------ E1 · π
class PiLogic extends ExperimentLogic {
  PiLogic() : super('e1_pi') {
    reset();
  }

  late Xoshiro128 _rng;
  int n = 0;
  int hits = 0;
  final List<Dot> dots = [];
  final List<TracePoint> trace = [];

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    n = 0;
    hits = 0;
    dots.clear();
    trace.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      final x = _rng.nextDouble(), y = _rng.nextDouble();
      final inside = x * x + y * y <= 1;
      n++;
      if (inside) hits++;
      if (dots.length < _maxDots) dots.add(Dot(x, y, inside));
      if (traceCheckpoint(n)) trace.add(TracePoint(n, estimate));
    }
  }

  double get estimate => n == 0 ? double.nan : 4 * hits / n;
  double get theoreticalSe => figureValue('pi_se_coef') / math.sqrt(math.max(n, 1));

  @override
  int get progress => n;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(n),
        'est': fmtFixed(estimate, 4),
        'err': fmtFixed((estimate - math.pi).abs(), 4),
        'se': fmtFixed(theoreticalSe, 4),
      };
}

// --------------------------------------------------------------- E2 · área
class AreaLogic extends ExperimentLogic {
  AreaLogic() : super('e2_area') {
    reset();
  }

  static double f(double x) => math.exp(-x * x);

  late Xoshiro128 _rng;
  int n = 0;
  int hits = 0;
  final RunningStats meanStats = RunningStats();
  final List<Dot> dots = [];
  final List<TracePoint> traceHit = [];
  final List<TracePoint> traceMean = [];

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    n = 0;
    hits = 0;
    meanStats.reset();
    dots.clear();
    traceHit.clear();
    traceMean.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      final x = _rng.nextDouble(), y = _rng.nextDouble();
      final under = y <= f(x);
      n++;
      if (under) hits++;
      meanStats.add(f(x)); // valor medio con la misma x
      if (dots.length < _maxDots) dots.add(Dot(x, y, under));
      if (traceCheckpoint(n)) {
        traceHit.add(TracePoint(n, estHit));
        traceMean.add(TracePoint(n, estMean));
      }
    }
  }

  double get estHit => n == 0 ? double.nan : hits / n;
  double get estMean => meanStats.mean;

  @override
  int get progress => n;

  @override
  Map<String, String> get observations {
    final truth = figureValue('area_true');
    return {
      'n': fmtInt(n),
      'est_hit': fmtFixed(estHit, 4),
      'est_mean': fmtFixed(estMean, 4),
      'err_hit': fmtFixed((estHit - truth).abs(), 4),
      'err_mean': fmtFixed((estMean - truth).abs(), 4),
    };
  }
}

// ------------------------------------------------------------ E3 · semillas
class SeedsLogic extends ExperimentLogic {
  SeedsLogic() : super('e3_seeds') {
    reset();
  }

  static const int analysts = 5;
  final List<Xoshiro128> _rngs = [];
  final List<int> _hits = List<int>.filled(analysts, 0);
  final List<List<TracePoint>> traces = List.generate(analysts, (_) => <TracePoint>[]);
  int n = 0;

  List<int> get seeds => [for (var i = 0; i < analysts; i++) seedFor('$id/$i', attempt)];

  @override
  void reset() {
    _rngs
      ..clear()
      ..addAll([for (final s in seeds) Xoshiro128(s)]);
    for (var i = 0; i < analysts; i++) {
      _hits[i] = 0;
      traces[i].clear();
    }
    n = 0;
  }

  @override
  void add(int k) {
    for (var j = 0; j < k; j++) {
      n++;
      for (var i = 0; i < analysts; i++) {
        final x = _rngs[i].nextDouble(), y = _rngs[i].nextDouble();
        if (x * x + y * y <= 1) _hits[i]++;
        if (traceCheckpoint(n)) traces[i].add(TracePoint(n, 4 * _hits[i] / n));
      }
    }
  }

  List<double> get estimates => [for (final h in _hits) n == 0 ? double.nan : 4 * h / n];

  @override
  int get progress => n;

  @override
  Map<String, String> get observations {
    final e = estimates;
    final lo = e.reduce(math.min), hi = e.reduce(math.max);
    return {
      'n': fmtInt(n),
      'min': fmtFixed(lo, 3),
      'max': fmtFixed(hi, 3),
      'spread': fmtFixed(hi - lo, 3),
    };
  }
}

// ---------------------------------------------------------- E4 · generador
class GeneratorLogic extends ExperimentLogic {
  GeneratorLogic() : super('e4_lcg') {
    reset();
  }

  bool useLcg = true;
  late RandomSource _rng;
  final List<double> values = [];

  /// Primeros valores de la secuencia con la semilla actual.
  List<double> firstValues = const [];

  int get lcgSeed => seed % badLcgM;

  RandomSource _make() => useLcg
      ? Lcg(a: badLcgA, c: badLcgC, m: badLcgM, seed: lcgSeed)
      : Xoshiro128(seed);

  @override
  void reset() {
    _rng = _make();
    values.clear();
    final probe = _make();
    firstValues = [for (var i = 0; i < 4; i++) probe.nextDouble()];
  }

  void setGenerator(bool lcg) {
    if (lcg == useLcg) return;
    useLcg = lcg;
    reset();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      if (values.length >= 6000) break;
      values.add(_rng.nextDouble());
    }
  }

  /// Comprueba la reproducibilidad: regenera con la misma semilla.
  bool reproduces() {
    final again = _make();
    for (var i = 0; i < values.length && i < 50; i++) {
      if (again.nextDouble() != values[i]) return false;
    }
    return true;
  }

  /// Primera posición en la que la secuencia vuelve a empezar (periodo
  /// observado), o null si no se ha repetido todavía.
  int? get observedPeriod {
    if (values.length < 3) return null;
    for (var p = 1; p < values.length - 1; p++) {
      if (values[p] == values[0] && values[p + 1] == values[1]) return p;
    }
    return null;
  }

  String get generatorName => _rng.name;

  @override
  int get progress => values.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(values.length),
        'first': firstValues.map((v) => fmtFixed(v, 4)).join('; '),
        'period': observedPeriod == null ? 'sin repetición' : fmtInt(observedPeriod!),
      };
}

// -------------------------------------------------- E5 · inversa exponencial
class InverseExpLogic extends ExperimentLogic {
  InverseExpLogic() : super('e5_inverse') {
    reset();
  }

  final ExponentialDist dist = const ExponentialDist(2);
  late Xoshiro128 _rng;
  final List<double> samples = [];
  double? lastU;
  double? lastX;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    samples.clear();
    lastU = null;
    lastX = null;
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      final u = _rng.nextDouble();
      final x = dist.quantile(u);
      samples.add(x);
      lastU = u;
      lastX = x;
    }
  }

  double get fracBelowMean {
    if (samples.isEmpty) return double.nan;
    var c = 0;
    for (final x in samples) {
      if (x < dist.mean) c++;
    }
    return c / samples.length;
  }

  @override
  int get progress => samples.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(samples.length),
        'frac_below': fmtPct(fracBelowMean),
        'median': samples.isEmpty ? '—' : fmtFixed(quantileSorted(sortedCopy(samples), 0.5), 2),
      };
}

// ------------------------------------------------------ E6 · dado cargado
class DiscreteLogic extends ExperimentLogic {
  DiscreteLogic() : super('e6_discrete') {
    reset();
  }

  final DiscreteDist die = const DiscreteDist([1, 2, 3, 4, 5, 6], [0.1, 0.1, 0.1, 0.1, 0.1, 0.5]);
  late Xoshiro128 _rng;
  final List<int> counts = List<int>.filled(6, 0);
  int n = 0;
  double? lastU;
  int? lastFace;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    for (var i = 0; i < 6; i++) {
      counts[i] = 0;
    }
    n = 0;
    lastU = null;
    lastFace = null;
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      final u = _rng.nextDouble();
      final idx = die.indexFor(u);
      counts[idx]++;
      n++;
      lastU = u;
      lastFace = idx + 1;
    }
  }

  @override
  int get progress => n;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(n),
        'p6': n == 0 ? '—' : fmtPct(counts[5] / n),
      };
}

// ------------------------------------------------ Base: modelos del motor
abstract class _EngineLogic extends ExperimentLogic {
  _EngineLogic(super.id, this.templateId);

  final String templateId;
  ResultSummary? summary;
  int n = 0;

  @override
  void add(int k) {
    n = math.min(n + k, SimulationEngine.maxIterations);
    // Misma semilla: la corrida con n mayor extiende la anterior.
    final run = const SimulationEngine().run(templateById(templateId), iterations: n, seed: seed);
    summary = ResultSummary.of(run);
  }

  @override
  void reset() {
    n = 0;
    summary = null;
  }

  @override
  int get progress => n;
}

// ------------------------------------------------------------ E7 · VAN
class NpvLogic extends _EngineLogic {
  NpvLogic() : super('e7_npv', 'proyecto_van');

  double get modeNpv => figureValue('npv_mode');

  @override
  Map<String, String> get observations {
    final s = summary;
    if (s == null) return {'n': '0'};
    return {
      'n': fmtInt(s.n),
      'mean': fmtFixed(s.mean, 0),
      'ploss': fmtPct(s.thresholdProb ?? double.nan),
      'p5': fmtFixed(s.p(5), 0),
      'p95': fmtFixed(s.p(95), 0),
    };
  }
}

// ------------------------------------------------------- E16 · tornado
class TornadoLogic extends _EngineLogic {
  TornadoLogic() : super('e16_tornado', 'proyecto_van');

  double rhoOf(String name) {
    final s = summary;
    if (s == null) return double.nan;
    for (final x in s.sensitivities) {
      if (x.name == name) return x.rho;
    }
    return double.nan;
  }

  @override
  Map<String, String> get observations => {
        'n': fmtInt(n),
        'rho_p': fmtFixed(rhoOf('P'), 2),
        'rho_q': fmtFixed(rhoOf('Q'), 2),
        'rho_c': fmtFixed(rhoOf('c'), 2),
      };
}

// --------------------------------------------------------- E8 · capacidad
class CapacityLogic extends ExperimentLogic {
  CapacityLogic() : super('e8_capacity') {
    reset();
  }

  final NormalDist demand = const NormalDist(capMu, capSigma);
  late Xoshiro128 _rng;
  final List<double> demands = [];
  double capacity = capC;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    demands.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      demands.add(demand.sample(_rng));
    }
  }

  double get meanSales {
    if (demands.isEmpty) return double.nan;
    var s = 0.0;
    for (final d in demands) {
      s += math.min(d, capacity);
    }
    return s / demands.length;
  }

  double get planSales => math.min(capMu, capacity);
  double get theorySales => capExpectedSales(capacity);

  @override
  int get progress => demands.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(demands.length),
        'cap': fmtFixed(capacity, 0),
        'plan': fmtFixed(planSales, 1),
        'sales': fmtFixed(meanSales, 1),
        'theory': fmtFixed(theorySales, 1),
      };
}

// ------------------------------------------------------ E9 · rutas paralelas
class MergeLogic extends ExperimentLogic {
  MergeLogic() : super('e9_merge') {
    reset();
  }

  late Xoshiro128 _rng;
  final List<double> a = [];
  final List<double> b = [];
  bool twoPaths = false;
  static const double taskC = 5;
  static const double plan = 14;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    a.clear();
    b.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      a.add(mergeTask.sample(_rng));
      b.add(mergeTask.sample(_rng));
    }
  }

  List<double> totals({bool? two}) {
    final t = two ?? twoPaths;
    return [for (var i = 0; i < a.length; i++) (t ? math.max(a[i], b[i]) : a[i]) + taskC];
  }

  double onTime({bool? two}) {
    final ts = totals(two: two);
    if (ts.isEmpty) return double.nan;
    return ts.where((t) => t <= plan).length / ts.length;
  }

  @override
  int get progress => a.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(a.length),
        'p_one': fmtPct(onTime(two: false)),
        'p_two': fmtPct(onTime(two: true)),
        'mean_two': fmtFixed(mean(totals(two: true)), 2),
      };
}

// ------------------------------------------------------ E10 · correlación
class CorrLogic extends ExperimentLogic {
  CorrLogic() : super('e10_corr') {
    reset();
  }

  late Xoshiro128 _rng;
  final List<double> z1 = [];
  final List<double> z = [];
  double rho = 0;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    z1.clear();
    z.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      z1.add(normalQuantile(_rng.nextDouble()));
      z.add(normalQuantile(_rng.nextDouble()));
    }
  }

  double x1(int i) => 100 + 20 * z1[i];
  double x2(int i) => 100 + 20 * (rho * z1[i] + math.sqrt(1 - rho * rho) * z[i]);

  List<double> get totals => [for (var i = 0; i < z1.length; i++) x1(i) + x2(i)];

  double get theorySd => 20 * math.sqrt(2 + 2 * rho);

  @override
  int get progress => z1.length;

  @override
  Map<String, String> get observations {
    final t = totals;
    return {
      'n': fmtInt(t.length),
      'rho': fmtFixed(rho, 1),
      'sd': fmtFixed(stdDev(t), 1),
      'theory_sd': fmtFixed(theorySd, 1),
      'p95': t.isEmpty ? '—' : fmtFixed(quantileSorted(sortedCopy(t), 0.95), 1),
    };
  }
}

// ------------------------------------------------------------ E11 · forma
class ShapeLogic extends ExperimentLogic {
  ShapeLogic() : super('e11_shape') {
    reset();
  }

  final NormalDist normal = const NormalDist(100, 50);
  final LogNormalDist lognormal = LogNormalDist.fromMeanSd(100, 50);
  late Xoshiro128 _rng;
  final List<double> us = [];

  /// true: se muestra la lognormal; false: la normal.
  bool showLognormal = false;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    us.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      us.add(_rng.nextDouble());
    }
  }

  List<double> get normalValues => [for (final u in us) normal.quantile(u)];
  List<double> get lognormalValues => [for (final u in us) lognormal.quantile(u)];

  double _frac(List<double> xs, bool Function(double) test) =>
      xs.isEmpty ? double.nan : xs.where(test).length / xs.length;

  @override
  int get progress => us.length;

  @override
  Map<String, String> get observations {
    final nv = normalValues, lv = lognormalValues;
    return {
      'n': fmtInt(us.length),
      'tail_n': fmtPct(_frac(nv, (x) => x > 200), decimals: 2),
      'tail_ln': fmtPct(_frac(lv, (x) => x > 200), decimals: 2),
      'neg': fmtPct(_frac(nv, (x) => x < 0), decimals: 2),
    };
  }
}

// --------------------------------------------------------- E12 · √n
class SqrtNLogic extends ExperimentLogic {
  SqrtNLogic() : super('e12_sqrt_n') {
    reset();
  }

  static const List<int> levels = [100, 400, 1600, 6400];
  static const int replicas = 40;

  /// Estimaciones por nivel (vacío si el nivel no se ha corrido).
  final Map<int, List<double>> results = {};

  @override
  void reset() => results.clear();

  void runLevel(int n) {
    final est = <double>[];
    for (var r = 0; r < replicas; r++) {
      final rng = Xoshiro128(seedFor('$id/$n/$r', attempt));
      var hits = 0;
      for (var i = 0; i < n; i++) {
        final x = rng.nextDouble(), y = rng.nextDouble();
        if (x * x + y * y <= 1) hits++;
      }
      est.add(4 * hits / n);
    }
    results[n] = est;
  }

  double sdAt(int n) => results[n] == null ? double.nan : stdDev(results[n]!);

  @override
  int get progress => results.length;

  @override
  Map<String, String> get observations => {
        for (final l in levels) 'sd_$l': results[l] == null ? '(sin correr)' : fmtFixed(sdAt(l), 3),
      };
}

// ------------------------------------------------------ E13 · eventos raros
class RareLogic extends ExperimentLogic {
  RareLogic() : super('e13_rare') {
    reset();
  }

  static const double p = 0.002;
  static const List<int> levels = [100, 1000, 10000];
  static const int replicas = 30;

  /// Casos observados por réplica, por nivel.
  final Map<int, List<int>> results = {};
  int currentN = 100;

  @override
  void reset() => results.clear();

  void runLevel(int n) {
    currentN = n;
    final hits = <int>[];
    for (var r = 0; r < replicas; r++) {
      final rng = Xoshiro128(seedFor('$id/$n/$r', attempt));
      var h = 0;
      for (var i = 0; i < n; i++) {
        if (rng.nextDouble() < p) h++;
      }
      hits.add(h);
    }
    results[n] = hits;
  }

  int zerosAt(int n) => results[n]?.where((h) => h == 0).length ?? 0;

  List<double> estimatesAt(int n) => [for (final h in results[n] ?? const <int>[]) h / n];

  @override
  int get progress => results.length;

  @override
  Map<String, String> get observations {
    final est = estimatesAt(currentN);
    final m = est.isEmpty ? double.nan : mean(est);
    final rel = (est.isEmpty) ? double.nan : stdDev(est) / p;
    return {
      'n': fmtInt(currentN),
      'zeros': '${zerosAt(currentN)}',
      'mean_p': fmtPct(m, decimals: 2),
      'relse': fmtPct(rel, decimals: 0),
    };
  }
}

// ---------------------------------------------------------- E14 · curva S
class SCurveLogic extends ExperimentLogic {
  SCurveLogic() : super('e14_scurve') {
    reset();
  }

  late Xoshiro128 _rng;
  final List<double> samples = [];
  List<double> _sorted = const [];
  double budget = 120;

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    samples.clear();
    _sorted = const [];
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      samples.add(scCost.sample(_rng));
    }
    _sorted = sortedCopy(samples);
  }

  List<double> get sorted => _sorted;

  double q(double p) => _sorted.isEmpty ? double.nan : quantileSorted(_sorted, p);

  double get pOverBudget {
    if (_sorted.isEmpty) return double.nan;
    var c = 0;
    for (final x in _sorted) {
      if (x > budget) c++;
    }
    return c / _sorted.length;
  }

  @override
  int get progress => samples.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(samples.length),
        'mean': fmtFixed(mean(samples), 1),
        'median': fmtFixed(q(0.5), 1),
        'p10': fmtFixed(q(0.1), 1),
        'p90': fmtFixed(q(0.9), 1),
        'budget': fmtFixed(budget, 0),
        'p_over': fmtPct(pOverBudget),
      };
}

// ------------------------------------------------------ E15 · comparación
class CompareLogic extends ExperimentLogic {
  CompareLogic() : super('e15_compare') {
    reset();
  }

  final NormalDist optionA = const NormalDist(120, 80);
  final NormalDist optionB = const NormalDist(100, 15);
  late Xoshiro128 _rng;
  final List<double> a = [];
  final List<double> b = [];

  @override
  void reset() {
    _rng = Xoshiro128(seed);
    a.clear();
    b.clear();
  }

  @override
  void add(int k) {
    for (var i = 0; i < k; i++) {
      a.add(optionA.sample(_rng));
      b.add(optionB.sample(_rng));
    }
  }

  double ploss(List<double> xs) => xs.isEmpty ? double.nan : xs.where((x) => x < 0).length / xs.length;
  double p5(List<double> xs) => xs.isEmpty ? double.nan : quantileSorted(sortedCopy(xs), 0.05);

  @override
  int get progress => a.length;

  @override
  Map<String, String> get observations => {
        'n': fmtInt(a.length),
        'mean_a': fmtFixed(mean(a), 1),
        'mean_b': fmtFixed(mean(b), 1),
        'ploss_a': fmtPct(ploss(a)),
        'ploss_b': fmtPct(ploss(b), decimals: 2),
        'p5_a': fmtFixed(p5(a), 1),
        'p5_b': fmtFixed(p5(b), 1),
      };
}

/// Reemplaza `[[clave]]` por observaciones y `{{id}}` por cifras.
String renderFinding(String text, Map<String, String> obs) {
  final withObs = text.replaceAllMapped(RegExp(r'\[\[([a-z0-9_]+)\]\]'), (m) => obs[m.group(1)] ?? '—');
  return renderFigures(withObs);
}
