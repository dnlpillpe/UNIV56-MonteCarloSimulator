import 'dart:math' as math;

/// Funciones especiales usadas por el motor. Dart puro, sin dependencias.

const double sqrt2Pi = 2.5066282746310002;

/// Densidad normal estándar φ(z).
double normalPdf(double z) => math.exp(-0.5 * z * z) / sqrt2Pi;

/// Distribución normal estándar Φ(z).
///
/// Algoritmo 5666 de Hart (1968) en la versión de West (2005): error
/// absoluto del orden de 1e-15 en todo el rango.
double normalCdf(double z) {
  final x = z.abs();
  double c;
  if (x > 37) {
    c = 0;
  } else {
    final e = math.exp(-x * x / 2);
    if (x < 7.07106781186547) {
      var b = 3.52624965998911e-02 * x + 0.700383064443688;
      b = b * x + 6.37396220353165;
      b = b * x + 33.912866078383;
      b = b * x + 112.079291497871;
      b = b * x + 221.213596169931;
      b = b * x + 220.206867912376;
      c = e * b;
      b = 8.83883476483184e-02 * x + 1.75566716318264;
      b = b * x + 16.064177579207;
      b = b * x + 86.7807322029461;
      b = b * x + 296.564248779674;
      b = b * x + 637.333633378831;
      b = b * x + 793.826512519948;
      b = b * x + 440.413735824752;
      c = c / b;
    } else {
      var b = x + 0.65;
      b = x + 4 / b;
      b = x + 3 / b;
      b = x + 2 / b;
      b = x + 1 / b;
      c = e / b / 2.506628274631;
    }
  }
  return z > 0 ? 1 - c : c;
}

/// Cuantil de la normal estándar Φ⁻¹(p).
///
/// Aproximación racional de Acklam más un paso de refinamiento de Halley:
/// error relativo < 1e-9 en todo (0, 1) (verificado contra SciPy).
double normalQuantile(double p) {
  if (p <= 0) return double.negativeInfinity;
  if (p >= 1) return double.infinity;
  const a = [
    -3.969683028665376e+01,
    2.209460984245205e+02,
    -2.759285104469687e+02,
    1.383577518672690e+02,
    -3.066479806614716e+01,
    2.506628277459239e+00,
  ];
  const b = [
    -5.447609879822406e+01,
    1.615858368580409e+02,
    -1.556989798598866e+02,
    6.680131188771972e+01,
    -1.328068155288572e+01,
  ];
  const c = [
    -7.784894002430293e-03,
    -3.223964580411365e-01,
    -2.400758277161838e+00,
    -2.549732539343734e+00,
    4.374664141464968e+00,
    2.938163982698783e+00,
  ];
  const d = [
    7.784695709041462e-03,
    3.224671290700398e-01,
    2.445134137142996e+00,
    3.754408661907416e+00,
  ];
  const plow = 0.02425;
  const phigh = 1 - plow;
  double x;
  if (p < plow) {
    final q = math.sqrt(-2 * math.log(p));
    x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  } else if (p <= phigh) {
    final q = p - 0.5;
    final r = q * q;
    x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
        q /
        (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  } else {
    final q = math.sqrt(-2 * math.log(1 - p));
    x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  // Un paso de Halley.
  final e = normalCdf(x) - p;
  final u = e * sqrt2Pi * math.exp(x * x / 2);
  x = x - u / (1 + x * u / 2);
  return x;
}

/// Coeficiente binomial como double (n pequeño).
double binomial(int n, int k) {
  if (k < 0 || k > n) return 0;
  var r = 1.0;
  final kk = k < n - k ? k : n - k;
  for (var i = 1; i <= kk; i++) {
    r = r * (n - kk + i) / i;
  }
  return r;
}

/// P(X ≥ k) para X ~ Binomial(n, p).
double binomialUpperTail(int n, double p, int k) {
  var s = 0.0;
  for (var i = k; i <= n; i++) {
    s += binomial(n, i) * math.pow(p, i) * math.pow(1 - p, n - i);
  }
  return s;
}
