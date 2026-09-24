import 'dart:math' as math;

import 'special.dart';

/// Estadística descriptiva usada para analizar corridas de simulación.

double mean(List<double> xs) {
  if (xs.isEmpty) return double.nan;
  var s = 0.0;
  for (final x in xs) {
    s += x;
  }
  return s / xs.length;
}

/// Varianza muestral (divisor n − 1).
double variance(List<double> xs) {
  final n = xs.length;
  if (n < 2) return 0;
  final m = mean(xs);
  var s = 0.0;
  for (final x in xs) {
    s += (x - m) * (x - m);
  }
  return s / (n - 1);
}

double stdDev(List<double> xs) => math.sqrt(variance(xs));

/// Coeficiente de asimetría muestral (g1).
double skewness(List<double> xs) {
  final n = xs.length;
  if (n < 3) return 0;
  final m = mean(xs);
  var m2 = 0.0, m3 = 0.0;
  for (final x in xs) {
    final d = x - m;
    m2 += d * d;
    m3 += d * d * d;
  }
  m2 /= n;
  m3 /= n;
  if (m2 == 0) return 0;
  return m3 / math.pow(m2, 1.5);
}

/// Cuantil con interpolación lineal (tipo 7) sobre una lista **ordenada**.
double quantileSorted(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  if (sorted.length == 1) return sorted.first;
  final h = (sorted.length - 1) * p;
  final lo = h.floor();
  final hi = h.ceil();
  return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo]);
}

List<double> sortedCopy(List<double> xs) => List<double>.of(xs)..sort();

/// Rangos promedio (empates reciben el promedio de sus posiciones).
List<double> ranks(List<double> xs) {
  final n = xs.length;
  final idx = List<int>.generate(n, (i) => i)
    ..sort((a, b) => xs[a].compareTo(xs[b]));
  final r = List<double>.filled(n, 0);
  var i = 0;
  while (i < n) {
    var j = i;
    while (j + 1 < n && xs[idx[j + 1]] == xs[idx[i]]) {
      j++;
    }
    final avg = (i + j) / 2 + 1;
    for (var k = i; k <= j; k++) {
      r[idx[k]] = avg;
    }
    i = j + 1;
  }
  return r;
}

/// Correlación de Pearson.
double pearson(List<double> x, List<double> y) {
  final n = math.min(x.length, y.length);
  if (n < 3) return 0;
  final mx = mean(x.sublist(0, n));
  final my = mean(y.sublist(0, n));
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = x[i] - mx, dy = y[i] - my;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  if (sxx == 0 || syy == 0) return 0;
  return sxy / math.sqrt(sxx * syy);
}

/// Correlación de rangos de Spearman (base del gráfico de tornado).
double spearman(List<double> x, List<double> y) => pearson(ranks(x), ranks(y));

/// Conteos de histograma en [lo, hi] con [bins] clases iguales.
List<int> histogram(List<double> xs, int bins, double lo, double hi) {
  final counts = List<int>.filled(bins, 0);
  if (hi <= lo) {
    if (xs.isNotEmpty) counts[bins ~/ 2] = xs.length;
    return counts;
  }
  final w = (hi - lo) / bins;
  for (final x in xs) {
    if (x < lo || x > hi || x.isNaN) continue;
    var k = ((x - lo) / w).floor();
    if (k >= bins) k = bins - 1;
    counts[k]++;
  }
  return counts;
}

/// Intervalo de Wilson al 95 % para una proporción k/n.
(double, double) wilson(int k, int n, {double z = 1.959963984540054}) {
  if (n == 0) return (0, 1);
  final p = k / n;
  final z2 = z * z;
  final den = 1 + z2 / n;
  final center = (p + z2 / (2 * n)) / den;
  final half = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / den;
  return (math.max(0.0, center - half), math.min(1.0, center + half));
}

/// Media y varianza en línea (Welford): permite mostrar la convergencia
/// sin guardar todas las muestras.
class RunningStats {
  int n = 0;
  double _mean = 0;
  double _m2 = 0;

  void add(double x) {
    n++;
    final d = x - _mean;
    _mean += d / n;
    _m2 += d * (x - _mean);
  }

  double get mean => n == 0 ? double.nan : _mean;
  double get variance => n < 2 ? 0 : _m2 / (n - 1);
  double get sd => math.sqrt(variance);

  /// Error estándar de la media: s/√n.
  double get se => n < 2 ? double.nan : sd / math.sqrt(n);

  void reset() {
    n = 0;
    _mean = 0;
    _m2 = 0;
  }
}

/// Punto de una traza de convergencia.
class TracePoint {
  const TracePoint(this.n, this.value);
  final int n;
  final double value;
}

/// Decide si en la iteración n conviene guardar un punto de la traza
/// (espaciado aproximadamente logarítmico, ~40 puntos por década).
bool traceCheckpoint(int n) {
  if (n <= 50) return true;
  final step = math.max(1, (n / 40).floor());
  return n % step == 0;
}

/// z crítico para un nivel de confianza bilateral.
double zFor(double confidence) => normalQuantile(0.5 + confidence / 2);
