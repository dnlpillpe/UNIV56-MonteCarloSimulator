import 'dart:math' as math;

import '../../core/math/stats.dart';
import 'model_spec.dart';
import 'simulation_engine.dart';

/// Sensibilidad de la salida a una entrada (correlación de rangos).
class Sensitivity {
  const Sensitivity(this.name, this.rho);
  final String name;

  /// Correlación de Spearman entre la entrada y la salida.
  final double rho;

  /// Participación aproximada: ρ² normalizado entre todas las entradas.
  double share(double totalRho2) => totalRho2 == 0 ? 0 : rho * rho / totalRho2;
}

/// Todo lo que el analista y la interfaz necesitan saber de una corrida.
class ResultSummary {
  ResultSummary._({
    required this.run,
    required this.n,
    required this.mean,
    required this.sd,
    required this.se,
    required this.min,
    required this.max,
    required this.percentiles,
    required this.skew,
    required this.thresholdHits,
    required this.sensitivities,
    required this.outputAtMeans,
    required this.outputAtModes,
    required this.sorted,
    required this.tailMean,
    required this.inputNegativeShare,
  });

  factory ResultSummary.of(SimulationRun run) {
    final ys = run.outputs;
    final sorted = sortedCopy(ys);
    final rs = RunningStats();
    for (final y in ys) {
      rs.add(y);
    }
    final pct = <int, double>{
      for (final p in const [1, 5, 10, 25, 50, 75, 90, 95, 99])
        p: quantileSorted(sorted, p / 100),
    };
    final spec = run.spec;
    int? hits;
    final t = spec.threshold;
    if (t != null) {
      var h = 0;
      for (final y in ys) {
        if (spec.side == ThresholdSide.below ? y < t : y > t) h++;
      }
      hits = h;
    }
    // Media de la cola de riesgo (5 % peor, según el lado del umbral).
    final k = math.max(1, (sorted.length * 0.05).floor());
    double tail;
    if (spec.side == ThresholdSide.below) {
      tail = mean(sorted.sublist(0, k));
    } else {
      tail = mean(sorted.sublist(sorted.length - k));
    }
    // Sensibilidad: solo entradas que varían.
    final sens = <Sensitivity>[];
    final negShare = <String, double>{};
    for (var j = 0; j < spec.inputs.length; j++) {
      final xs = run.inputs[j];
      final kind = spec.inputs[j].kind;
      if (kind != DistKind.constant) {
        final sub = _subsample(xs, 20000);
        final suby = _subsample(ys, 20000);
        sens.add(Sensitivity(spec.inputs[j].name, spearman(sub, suby)));
      }
      if (kind == DistKind.normal) {
        var neg = 0;
        for (final x in xs) {
          if (x < 0) neg++;
        }
        negShare[spec.inputs[j].name] = xs.isEmpty ? 0 : neg / xs.length;
      }
    }
    sens.sort((a, b) => b.rho.abs().compareTo(a.rho.abs()));
    double atMeans, atModes;
    try {
      atMeans = run.model.outputAtMeans;
      atModes = run.model.outputAtModes;
    } catch (_) {
      atMeans = double.nan;
      atModes = double.nan;
    }
    return ResultSummary._(
      run: run,
      n: ys.length,
      mean: rs.mean,
      sd: rs.sd,
      se: rs.se,
      min: sorted.first,
      max: sorted.last,
      percentiles: pct,
      skew: skewness(ys),
      thresholdHits: hits,
      sensitivities: sens,
      outputAtMeans: atMeans,
      outputAtModes: atModes,
      sorted: sorted,
      tailMean: tail,
      inputNegativeShare: negShare,
    );
  }

  static List<double> _subsample(List<double> xs, int max) {
    if (xs.length <= max) return xs;
    final step = xs.length / max;
    return [for (var i = 0; i < max; i++) xs[(i * step).floor()]];
  }

  final SimulationRun run;
  final int n;
  final double mean;
  final double sd;

  /// Error estándar de la media: la **precisión** de la estimación, no el
  /// riesgo del proyecto (ese es [sd]).
  final double se;
  final double min;
  final double max;
  final Map<int, double> percentiles;
  final double skew;
  final int? thresholdHits;
  final List<Sensitivity> sensitivities;
  final double outputAtMeans;
  final double outputAtModes;
  final List<double> sorted;

  /// Media del 5 % de resultados del lado del riesgo (déficit esperado).
  final double tailMean;

  /// Fracción de muestras negativas de cada entrada normal.
  final Map<String, double> inputNegativeShare;

  ModelSpec get spec => run.spec;

  double get median => percentiles[50]!;
  double p(int q) => percentiles[q]!;

  /// Semiamplitud del IC 95 % de la media.
  double get halfWidth95 => 1.959963984540054 * se;

  double get ciLow => mean - halfWidth95;
  double get ciHigh => mean + halfWidth95;

  /// Precisión relativa: semiamplitud / |media|.
  double get relativePrecision => mean == 0 ? double.infinity : halfWidth95 / mean.abs();

  /// Probabilidad estimada de cruzar el umbral.
  double? get thresholdProb => thresholdHits == null ? null : thresholdHits! / n;

  (double, double)? get thresholdCi =>
      thresholdHits == null ? null : wilson(thresholdHits!, n);

  /// Iteraciones necesarias para que la semiamplitud del IC 95 % de la media
  /// sea [target] (en unidades de la salida).
  int iterationsForMeanHalfWidth(double target) {
    if (target <= 0 || sd == 0) return n;
    final req = math.pow(1.959963984540054 * sd / target, 2).toDouble();
    return req.ceil();
  }

  /// Iteraciones necesarias para estimar la probabilidad del umbral con
  /// semiamplitud [target] (p. ej. 0,01 = ±1 punto porcentual).
  int? iterationsForProbHalfWidth(double target) {
    final pr = thresholdProb;
    if (pr == null || target <= 0) return null;
    final pp = pr == 0 ? 0.5 : pr;
    final req = 3.8414588206941254 * pp * (1 - pp) / (target * target);
    return req.ceil();
  }

  /// Cota superior al 95 % cuando no hubo ningún caso: regla del tres.
  double get ruleOfThree => 3 / n;

  double get totalRho2 =>
      sensitivities.fold(0.0, (acc, s) => acc + s.rho * s.rho);

  /// Probabilidad empírica P(Y ≤ x) (curva S).
  double cdfAt(double x) {
    var lo = 0, hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid] <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo / sorted.length;
  }
}
