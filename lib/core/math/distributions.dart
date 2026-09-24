import 'dart:math' as math;

import '../rng/random_source.dart';
import 'special.dart';

/// Distribuciones de entrada del simulador.
///
/// Todas se muestrean por **transformada inversa**: x = F⁻¹(u). Es el mismo
/// método que el estudiante construye a mano en el laboratorio «Fábrica de
/// azar», y permite introducir correlación con una cópula gaussiana usando
/// una sola uniforme por variable.
abstract class Distribution {
  const Distribution();

  /// Cuantil F⁻¹(u), u en (0, 1).
  double quantile(double u);

  /// Función de distribución acumulada F(x).
  double cdf(double x);

  /// Densidad f(x); en distribuciones discretas, 0 (se usa [pmf]).
  double pdf(double x);

  double get mean;
  double get variance;
  double get sd => math.sqrt(variance);

  bool get isDiscrete => false;

  /// Rango razonable para dibujar (percentiles 0,1 y 99,9 aproximados).
  (double, double) get displayRange => (quantile(0.001), quantile(0.999));

  double sample(RandomSource r) => quantile(r.nextDouble());

  /// Descripción corta en español, p. ej. «Triangular(5; 8; 14)».
  String get label;
}

class UniformDist extends Distribution {
  const UniformDist(this.a, this.b);
  final double a;
  final double b;

  @override
  double quantile(double u) => a + (b - a) * u;
  @override
  double cdf(double x) => x <= a ? 0 : (x >= b ? 1 : (x - a) / (b - a));
  @override
  double pdf(double x) => (x < a || x > b) ? 0 : 1 / (b - a);
  @override
  double get mean => (a + b) / 2;
  @override
  double get variance => (b - a) * (b - a) / 12;
  @override
  (double, double) get displayRange => (a, b);
  @override
  String get label => 'Uniforme(${_n(a)}; ${_n(b)})';
}

class TriangularDist extends Distribution {
  const TriangularDist(this.a, this.m, this.b);
  final double a;
  final double m;
  final double b;

  double get _fc => b == a ? 0.5 : (m - a) / (b - a);

  @override
  double quantile(double u) {
    if (b == a) return a;
    if (u < _fc) return a + math.sqrt(u * (b - a) * (m - a));
    return b - math.sqrt((1 - u) * (b - a) * (b - m));
  }

  @override
  double cdf(double x) {
    if (x <= a) return 0;
    if (x >= b) return 1;
    if (x <= m) return (x - a) * (x - a) / ((b - a) * (m - a));
    return 1 - (b - x) * (b - x) / ((b - a) * (b - m));
  }

  @override
  double pdf(double x) {
    if (x < a || x > b || b == a) return 0;
    if (x < m) return 2 * (x - a) / ((b - a) * (m - a));
    if (x == m) return 2 / (b - a);
    return 2 * (b - x) / ((b - a) * (b - m));
  }

  @override
  double get mean => (a + m + b) / 3;
  @override
  double get variance => (a * a + m * m + b * b - a * m - a * b - m * b) / 18;
  @override
  (double, double) get displayRange => (a, b);
  @override
  String get label => 'Triangular(${_n(a)}; ${_n(m)}; ${_n(b)})';
}

class NormalDist extends Distribution {
  const NormalDist(this.mu, this.sigma);
  final double mu;
  final double sigma;

  @override
  double quantile(double u) => mu + sigma * normalQuantile(u);
  @override
  double cdf(double x) => normalCdf((x - mu) / sigma);
  @override
  double pdf(double x) => normalPdf((x - mu) / sigma) / sigma;
  @override
  double get mean => mu;
  @override
  double get variance => sigma * sigma;
  @override
  String get label => 'Normal(${_n(mu)}; ${_n(sigma)})';
}

/// Lognormal: ln X ~ Normal(mu, sigma). Se construye habitualmente a partir
/// de la media y la desviación de X, que son más intuitivas.
class LogNormalDist extends Distribution {
  const LogNormalDist(this.mu, this.sigma);

  factory LogNormalDist.fromMeanSd(double mean, double sd) {
    final s2 = math.log(1 + (sd * sd) / (mean * mean));
    return LogNormalDist(math.log(mean) - s2 / 2, math.sqrt(s2));
  }

  factory LogNormalDist.fromMedian(double median, double sigmaLog) =>
      LogNormalDist(math.log(median), sigmaLog);

  final double mu;
  final double sigma;

  @override
  double quantile(double u) => math.exp(mu + sigma * normalQuantile(u));
  @override
  double cdf(double x) =>
      x <= 0 ? 0 : normalCdf((math.log(x) - mu) / sigma);
  @override
  double pdf(double x) => x <= 0
      ? 0
      : normalPdf((math.log(x) - mu) / sigma) / (x * sigma);
  @override
  double get mean => math.exp(mu + sigma * sigma / 2);
  @override
  double get variance =>
      (math.exp(sigma * sigma) - 1) * math.exp(2 * mu + sigma * sigma);
  double get median => math.exp(mu);
  @override
  String get label => 'Lognormal(media ${_n(mean)}; desv. ${_n(sd)})';
}

class ExponentialDist extends Distribution {
  const ExponentialDist(this.meanValue);
  final double meanValue;

  @override
  double quantile(double u) => -meanValue * math.log(1 - u);
  @override
  double cdf(double x) => x <= 0 ? 0 : 1 - math.exp(-x / meanValue);
  @override
  double pdf(double x) => x < 0 ? 0 : math.exp(-x / meanValue) / meanValue;
  @override
  double get mean => meanValue;
  @override
  double get variance => meanValue * meanValue;
  @override
  (double, double) get displayRange => (0, quantile(0.995));
  @override
  String get label => 'Exponencial(media ${_n(meanValue)})';
}

/// Discreta finita con valores y probabilidades (transformada inversa por
/// tramos acumulados).
class DiscreteDist extends Distribution {
  const DiscreteDist(this.values, this.probs);
  final List<double> values;
  final List<double> probs;

  @override
  bool get isDiscrete => true;

  @override
  double quantile(double u) {
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      acc += probs[i];
      if (u < acc) return values[i];
    }
    return values.last;
  }

  /// Índice del tramo en el que cae u (para dibujar la regla de tramos).
  int indexFor(double u) {
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      acc += probs[i];
      if (u < acc) return i;
    }
    return values.length - 1;
  }

  @override
  double cdf(double x) {
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= x) acc += probs[i];
    }
    return acc;
  }

  @override
  double pdf(double x) => 0;

  double pmf(double x) {
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == x) acc += probs[i];
    }
    return acc;
  }

  @override
  double get mean {
    var s = 0.0;
    for (var i = 0; i < values.length; i++) {
      s += values[i] * probs[i];
    }
    return s;
  }

  @override
  double get variance {
    final mu = mean;
    var s = 0.0;
    for (var i = 0; i < values.length; i++) {
      s += (values[i] - mu) * (values[i] - mu) * probs[i];
    }
    return s;
  }

  @override
  (double, double) get displayRange => (values.reduce(math.min), values.reduce(math.max));

  @override
  String get label => 'Discreta (${values.length} valores)';
}

/// Bernoulli(p): 1 con probabilidad p, 0 si no.
class BernoulliDist extends DiscreteDist {
  BernoulliDist(this.p) : super(const [0, 1], [1 - p, p]);
  final double p;
  @override
  String get label => 'Bernoulli(${_n(p)})';
}

class ConstantDist extends Distribution {
  const ConstantDist(this.value);
  final double value;
  @override
  double quantile(double u) => value;
  @override
  double cdf(double x) => x < value ? 0 : 1;
  @override
  double pdf(double x) => 0;
  @override
  double get mean => value;
  @override
  double get variance => 0;
  @override
  bool get isDiscrete => true;
  @override
  (double, double) get displayRange => (value - 1, value + 1);
  @override
  String get label => 'Constante ${_n(value)}';
}

String _n(double x) {
  if (x == x.roundToDouble() && x.abs() < 1e9) return x.toInt().toString();
  final s = x.toStringAsFixed(x.abs() >= 100 ? 1 : (x.abs() >= 1 ? 2 : 3));
  var t = s;
  if (t.contains('.')) {
    while (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  }
  return t.replaceAll('.', ',');
}
