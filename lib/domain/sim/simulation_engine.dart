import 'dart:math' as math;

import '../../core/math/distributions.dart';
import '../../core/math/special.dart';
import '../../core/math/stats.dart';
import '../../core/rng/random_source.dart';
import 'expression.dart';
import 'model_spec.dart';

/// Error de configuración del modelo (entrada inválida, fórmula incorrecta…).
class ModelError implements Exception {
  ModelError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Modelo listo para simular: distribuciones construidas y fórmula compilada.
class CompiledModel {
  CompiledModel._(this.spec, this.dists, this.expr, this._corrA, this._corrB, this._rho);

  factory CompiledModel.compile(ModelSpec spec) {
    if (spec.inputs.isEmpty) throw ModelError('Agrega al menos una variable de entrada.');
    final seen = <String>{};
    for (final i in spec.inputs) {
      if (!isValidVariableName(i.name)) {
        throw ModelError('«${i.name}» no es un nombre válido: usa letras, dígitos o _, sin espacios ni tildes.');
      }
      if (!seen.add(i.name)) throw ModelError('La variable «${i.name}» está repetida.');
      final err = i.validate();
      if (err != null) throw ModelError('${i.name}: $err');
    }
    CompiledExpression expr;
    try {
      expr = compileExpression(spec.expression, spec.variableNames);
    } on ExpressionError catch (e) {
      throw ModelError('Fórmula: ${e.message} (posición ${e.position + 1}).');
    }
    var ca = -1, cb = -1;
    var rho = 0.0;
    final corr = spec.correlation;
    if (corr != null && corr.rho != 0) {
      ca = spec.variableNames.indexOf(corr.a);
      cb = spec.variableNames.indexOf(corr.b);
      if (ca < 0 || cb < 0 || ca == cb) {
        throw ModelError('La correlación debe unir dos variables distintas del modelo.');
      }
      if (corr.rho <= -1 || corr.rho >= 1) {
        throw ModelError('La correlación debe estar entre −1 y 1 (sin incluirlos).');
      }
      rho = corr.rho;
    }
    return CompiledModel._(spec, [for (final i in spec.inputs) i.build()], expr, ca, cb, rho);
  }

  final ModelSpec spec;
  final List<Distribution> dists;
  final CompiledExpression expr;
  final int _corrA;
  final int _corrB;
  final double _rho;

  bool get hasCorrelation => _corrA >= 0;

  /// Genera un vector de entradas usando una uniforme por variable.
  /// Con correlación, la segunda variable del par se obtiene de
  /// z₂ = ρ·z₁ + √(1−ρ²)·z, y u₂ = Φ(z₂) (cópula gaussiana).
  void sampleInputs(RandomSource rng, List<double> out) {
    final us = List<double>.generate(dists.length, (_) => rng.nextDouble());
    if (_corrA >= 0) {
      final z1 = normalQuantile(us[_corrA]);
      final z = normalQuantile(us[_corrB]);
      final z2 = _rho * z1 + math.sqrt(1 - _rho * _rho) * z;
      var u2 = normalCdf(z2);
      if (u2 <= 0) u2 = 1e-12;
      if (u2 >= 1) u2 = 1 - 1e-12;
      us[_corrB] = u2;
    }
    for (var i = 0; i < dists.length; i++) {
      out[i] = dists[i].quantile(us[i]);
    }
  }

  double evaluate(List<double> inputs) => expr.evaluate(inputs);

  /// Salida del modelo con cada entrada en su valor medio: el «escenario
  /// promedio» que usa la planificación determinista.
  double get outputAtMeans => evaluate([for (final d in dists) d.mean]);

  /// Salida con cada entrada en su valor más probable (moda), cuando la
  /// distribución la define (triangular, constante). Si no, se usa la media.
  double get outputAtModes => evaluate([
        for (var i = 0; i < dists.length; i++) _modeOf(spec.inputs[i], dists[i]),
      ]);

  static double _modeOf(InputSpec s, Distribution d) {
    if (d is LogNormalDist) return math.exp(d.mu - d.sigma * d.sigma);
    switch (s.kind) {
      case DistKind.triangular:
        return s.params[1];
      case DistKind.constant:
        return s.params[0];
      case DistKind.exponential:
        return 0.0;
      case DistKind.bernoulli:
        return s.params[0] >= 0.5 ? 1.0 : 0.0;
      case DistKind.lognormal:
      case DistKind.uniform:
      case DistKind.normal:
        return d.mean;
    }
  }
}

/// Una corrida: todas las muestras de entrada y salida, con su semilla.
class SimulationRun {
  SimulationRun({
    required this.model,
    required this.seed,
    required this.inputs,
    required this.outputs,
    required this.trace,
    required this.invalidCount,
  });

  final CompiledModel model;
  final int seed;

  /// inputs[j][k]: valor de la entrada j en la iteración k.
  final List<List<double>> inputs;
  final List<double> outputs;

  /// Media acumulada de la salida en puntos espaciados.
  final List<TracePoint> trace;

  /// Iteraciones descartadas porque la fórmula dio NaN o infinito
  /// (p. ej. dividir entre cero o ln de un negativo).
  final int invalidCount;

  int get n => outputs.length;
  ModelSpec get spec => model.spec;
}

/// Motor de simulación Monte Carlo.
class SimulationEngine {
  const SimulationEngine();

  static const int maxIterations = 100000;

  SimulationRun run(ModelSpec spec, {required int iterations, required int seed}) {
    final model = CompiledModel.compile(spec);
    return runCompiled(model, iterations: iterations, seed: seed);
  }

  SimulationRun runCompiled(CompiledModel model, {required int iterations, required int seed}) {
    final n = math.min(math.max(iterations, 1), maxIterations);
    final rng = Xoshiro128(seed);
    final k = model.dists.length;
    final ins = List<List<double>>.generate(k, (_) => <double>[]);
    final outs = <double>[];
    final trace = <TracePoint>[];
    final buf = List<double>.filled(k, 0);
    final rs = RunningStats();
    var invalid = 0;
    for (var it = 0; it < n; it++) {
      model.sampleInputs(rng, buf);
      final y = model.evaluate(buf);
      if (y.isNaN || y.isInfinite) {
        invalid++;
        continue;
      }
      for (var j = 0; j < k; j++) {
        ins[j].add(buf[j]);
      }
      outs.add(y);
      rs.add(y);
      if (traceCheckpoint(rs.n)) trace.add(TracePoint(rs.n, rs.mean));
    }
    if (outs.isEmpty) {
      throw ModelError('La fórmula no produjo ningún valor válido (revisa divisiones entre cero o logaritmos de negativos).');
    }
    if (trace.isEmpty || trace.last.n != rs.n) trace.add(TracePoint(rs.n, rs.mean));
    return SimulationRun(
      model: model,
      seed: seed,
      inputs: ins,
      outputs: outs,
      trace: trace,
      invalidCount: invalid,
    );
  }
}
