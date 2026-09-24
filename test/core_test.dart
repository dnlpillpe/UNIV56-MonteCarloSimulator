import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/core/math/distributions.dart';
import 'package:monte_carlo_simulator/core/math/special.dart';
import 'package:monte_carlo_simulator/core/math/stats.dart';
import 'package:monte_carlo_simulator/core/rng/random_source.dart';
import 'package:monte_carlo_simulator/core/util/format.dart';

void main() {
  group('Generadores', () {
    test('xoshiro128** es determinista con la misma semilla', () {
      final a = Xoshiro128(17), b = Xoshiro128(17), c = Xoshiro128(18);
      final sa = [for (var i = 0; i < 20; i++) a.nextDouble()];
      final sb = [for (var i = 0; i < 20; i++) b.nextDouble()];
      final sc = [for (var i = 0; i < 20; i++) c.nextDouble()];
      expect(sa, sb);
      expect(sa, isNot(sc));
    });

    test('uniformes en (0, 1) con media y varianza correctas', () {
      final r = Xoshiro128(2026);
      final xs = [for (var i = 0; i < 100000; i++) r.nextDouble()];
      expect(xs.every((x) => x > 0 && x < 1), isTrue);
      expect(mean(xs), closeTo(0.5, 0.005));
      expect(variance(xs), closeTo(1 / 12, 0.002));
    });

    test('pares consecutivos casi incorrelacionados en xoshiro', () {
      final r = Xoshiro128(5);
      final xs = [for (var i = 0; i < 20001; i++) r.nextDouble()];
      expect(pearson(xs.sublist(0, 20000), xs.sublist(1)).abs(), lessThan(0.03));
    });

    test('el congruencial del laboratorio tiene periodo 256', () {
      final g = Lcg(a: badLcgA, c: badLcgC, m: badLcgM, seed: 11);
      final xs = [for (var i = 0; i < 600; i++) g.nextDouble()];
      expect(xs[256], xs[0]);
      expect(xs[257], xs[1]);
      expect(xs.sublist(0, 256).toSet().length, 256);
    });

    test('FNV-1a estable', () {
      expect(fnv1a32(''), 0x811C9DC5);
      expect(fnv1a32('a'), 0xE40C292C);
      expect(seedFor('e1_pi', 0), seedFor('e1_pi', 0));
      expect(seedFor('e1_pi', 0), isNot(seedFor('e1_pi', 1)));
    });
  });

  group('Funciones especiales', () {
    test('Φ y Φ⁻¹', () {
      expect(normalCdf(0), closeTo(0.5, 1e-15));
      expect(normalCdf(1.959963984540054), closeTo(0.975, 1e-12));
      expect(normalCdf(-2), closeTo(0.022750131948179, 1e-12));
      for (final p in [1e-8, 0.001, 0.02425, 0.1, 0.5, 0.9, 0.975, 0.999999]) {
        expect(normalCdf(normalQuantile(p)), closeTo(p, 1e-9 * math.max(1, p)));
      }
    });

    test('cola binomial', () {
      expect(binomialUpperTail(20, 0.25, 0), closeTo(1, 1e-12));
      expect(binomialUpperTail(20, 0.25, 10), closeTo(0.013864, 1e-6));
    });
  });

  group('Distribuciones (transformada inversa)', () {
    final dists = <Distribution>[
      const UniformDist(2, 5),
      const TriangularDist(5, 8, 14),
      const NormalDist(100, 20),
      LogNormalDist.fromMeanSd(100, 50),
      const ExponentialDist(2),
    ];
    for (final d in dists) {
      test('${d.label}: F(F⁻¹(u)) = u y momentos por simulación', () {
        for (final u in [0.01, 0.2, 0.5, 0.8, 0.99]) {
          expect(d.cdf(d.quantile(u)), closeTo(u, 1e-9));
        }
        final r = Xoshiro128(9);
        final xs = [for (var i = 0; i < 60000; i++) d.sample(r)];
        expect(mean(xs), closeTo(d.mean, 4 * d.sd / math.sqrt(60000)));
        expect(stdDev(xs), closeTo(d.sd, 0.03 * d.sd));
      });
    }

    test('lognormal desde media y desviación', () {
      final d = LogNormalDist.fromMeanSd(0.8, 0.4);
      expect(d.mean, closeTo(0.8, 1e-12));
      expect(d.sd, closeTo(0.4, 1e-12));
      expect(d.median, lessThan(d.mean));
    });

    test('discreta por tramos', () {
      const d = DiscreteDist([1, 2, 3], [0.2, 0.5, 0.3]);
      expect(d.quantile(0.1), 1);
      expect(d.quantile(0.65), 2);
      expect(d.quantile(0.95), 3);
      expect(d.mean, closeTo(2.1, 1e-12));
      expect(BernoulliDist(0.3).mean, closeTo(0.3, 1e-12));
    });
  });

  group('Estadística', () {
    test('cuantiles, rangos y Spearman', () {
      final s = sortedCopy([5, 1, 4, 2, 3]);
      expect(quantileSorted(s, 0.5), 3);
      expect(quantileSorted(s, 0.25), 2);
      expect(ranks([10, 20, 20, 30]), [1, 2.5, 2.5, 4]);
      expect(spearman([1, 2, 3, 4], [1, 8, 27, 64]), closeTo(1, 1e-12));
    });

    test('Welford coincide con la fórmula directa', () {
      final xs = <double>[2, 4, 4, 4, 5, 5, 7, 9];
      final rs = RunningStats();
      xs.forEach(rs.add);
      expect(rs.mean, closeTo(mean(xs), 1e-12));
      expect(rs.variance, closeTo(variance(xs), 1e-12));
      expect(rs.se, closeTo(stdDev(xs) / math.sqrt(8), 1e-12));
    });

    test('Wilson', () {
      final (lo, hi) = wilson(0, 1000);
      expect(lo, 0);
      expect(hi, closeTo(0.00383, 0.0002));
    });
  });

  group('Formato', () {
    test('coma decimal y miles', () {
      expect(fmtFixed(3.14159, 2), '3,14');
      expect(fmtInt(10000), '10 000');
      expect(fmtInt(1000), '1000');
      expect(fmtPct(0.378), '37,8 %');
      expect(fmtFixed(-2.5, 1), '−2,5');
    });

    test('lectura de números del estudiante', () {
      expect(parseUserNumber('37,8'), 37.8);
      expect(parseUserNumber('1.234,5'), 1234.5);
      expect(parseUserNumber('0.05'), 0.05);
      expect(parseUserNumber('10 000'), 10000);
      expect(parseUserNumber('−3'), -3);
      expect(parseUserNumber('abc'), isNull);
    });
  });
}
