import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/math/distributions.dart';
import '../../core/math/stats.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/sim/result_summary.dart';
import 'chart_base.dart';

/// Histograma de muestras (cian) con región de riesgo (naranja), densidad
/// teórica (verde) y marcadores. Admite una segunda serie superpuesta.
class HistogramPainter extends CustomPainter {
  HistogramPainter({
    required this.values,
    required this.lo,
    required this.hi,
    this.bins = 30,
    this.color = AppColors.sample,
    this.threshold,
    this.riskBelow = true,
    this.markers = const [],
    this.density,
    this.values2,
    this.color2 = AppColors.estimate,
  });

  final List<double> values;
  final double lo, hi;
  final int bins;
  final Color color;
  final double? threshold;

  /// true: el riesgo está a la izquierda del umbral.
  final bool riskBelow;
  final List<ChartMarker> markers;

  /// Densidad teórica f(x) para superponer (escalada al histograma).
  final double Function(double x)? density;
  final List<double>? values2;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 12, bottom: 22, top: 30);
    if (values.isEmpty || !(hi > lo)) {
      drawLabel(canvas, 'Simula para ver la distribución', r.center, size: 12);
      return;
    }
    final c1 = histogram(values, bins, lo, hi);
    final v2 = values2;
    final c2 = v2 == null ? null : histogram(v2, bins, lo, hi);
    final n1 = values.length.toDouble();
    final n2 = v2 == null ? 1.0 : v2.length.toDouble();
    final w = (hi - lo) / bins;
    var maxDens = 0.0;
    for (final c in c1) {
      maxDens = math.max(maxDens, c / n1 / w);
    }
    if (c2 != null) {
      for (final c in c2) {
        maxDens = math.max(maxDens, c / n2 / w);
      }
    }
    final f = density;
    if (f != null) {
      for (var i = 0; i <= 80; i++) {
        final y = f(lo + (hi - lo) * i / 80);
        if (y.isFinite) maxDens = math.max(maxDens, y);
      }
    }
    final s = ChartScale(r, lo, hi, 0, maxDens * 1.08);
    drawAxes(canvas, s, yTicks: false);
    final t = threshold;
    void bars(List<int> counts, double n, Color base, {bool outline = false}) {
      for (var i = 0; i < bins; i++) {
        if (counts[i] == 0) continue;
        final a = lo + i * w, b = a + w;
        final mid = (a + b) / 2;
        final inRisk = t != null && (riskBelow ? mid < t : mid > t);
        final col = inRisk ? AppColors.risk : base;
        final rect = Rect.fromLTRB(s.px(a) + 0.5, s.py(counts[i] / n / w), s.px(b) - 0.5, s.py(0));
        if (outline) {
          canvas.drawRect(
            rect,
            Paint()
              ..color = col
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        } else {
          canvas.drawRect(rect, Paint()..color = col.withValues(alpha: 0.85));
        }
      }
    }

    bars(c1, n1, color);
    if (c2 != null) bars(c2, n2, color2, outline: true);
    if (f != null) {
      final path = Path();
      for (var i = 0; i <= 120; i++) {
        final x = lo + (hi - lo) * i / 120;
        final y = f(x);
        final pt = s.p(x, y.isFinite ? y : 0);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.model
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    final all = <ChartMarker>[
      if (t != null) ChartMarker(t, 'umbral ${fmtNum(t)}', AppColors.risk, dashed: false),
      ...markers,
    ];
    drawMarkers(canvas, s, all);
  }

  @override
  bool shouldRepaint(covariant HistogramPainter old) => true;
}

/// Curva S (acumulada empírica) con umbral arrastrable y percentiles.
class CdfPainter extends CustomPainter {
  CdfPainter({
    required this.sorted,
    required this.lo,
    required this.hi,
    this.threshold,
    this.riskAbove = true,
    this.markers = const [],
  });

  final List<double> sorted;
  final double lo, hi;
  final double? threshold;
  final bool riskAbove;
  final List<ChartMarker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 36, bottom: 22, top: 30);
    final s = ChartScale(r, lo, hi, 0, 1);
    drawAxes(canvas, s);
    if (sorted.isEmpty) {
      drawLabel(canvas, 'Simula para ver la curva S', r.center, size: 12);
      return;
    }
    final n = sorted.length;
    final step = math.max(1, n ~/ 400);
    final path = Path()..moveTo(s.px(lo), s.py(0));
    for (var i = 0; i < n; i += step) {
      final x = math.min(hi, math.max(lo, sorted[i]));
      path.lineTo(s.px(x), s.py((i + 1) / n));
    }
    path.lineTo(s.px(hi), s.py(1));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.sample
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    final t = threshold;
    if (t != null) {
      var k = 0;
      while (k < n && sorted[k] <= t) {
        k++;
      }
      final p = k / n;
      final x = s.px(t);
      final y = s.py(p);
      final riskPaint = Paint()..color = AppColors.risk.withValues(alpha: 0.18);
      if (riskAbove) {
        canvas.drawRect(Rect.fromLTRB(x, r.top, r.right, r.bottom), riskPaint);
      } else {
        canvas.drawRect(Rect.fromLTRB(r.left, r.top, x, r.bottom), riskPaint);
      }
      final guide = Paint()
        ..color = AppColors.risk
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(x, r.bottom), Offset(x, y), guide);
      dashedLine(canvas, Offset(r.left, y), Offset(x, y), guide);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = AppColors.risk);
      drawLabel(canvas, 'P(≤ ${fmtNum(t)}) = ${fmtPct(p)}', Offset(r.left + 4, y - 14), color: AppColors.risk, align: TextAlign.left, weight: FontWeight.w600);
    }
    drawMarkers(canvas, s, markers);
  }

  @override
  bool shouldRepaint(covariant CdfPainter old) => true;
}

/// Transformada inversa: u en el eje vertical → acumulada F → x.
class InversePainter extends CustomPainter {
  InversePainter({required this.dist, required this.lo, required this.hi, this.lastU, this.lastX, this.recent = const []});

  final Distribution dist;
  final double lo, hi;
  final double? lastU;
  final double? lastX;

  /// Últimos valores generados (marcas en el eje x).
  final List<double> recent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 34, bottom: 22);
    final s = ChartScale(r, lo, hi, 0, 1);
    drawAxes(canvas, s);
    final path = Path();
    for (var i = 0; i <= 150; i++) {
      final x = lo + (hi - lo) * i / 150;
      final pt = s.p(x, dist.cdf(x));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.model
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    drawLabel(canvas, 'F(x)', Offset(r.right - 4, s.py(0.98) + 2), color: AppColors.model, align: TextAlign.right, weight: FontWeight.w600);
    final tick = Paint()
      ..color = AppColors.sample.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final x in recent) {
      if (x < lo || x > hi) continue;
      canvas.drawLine(Offset(s.px(x), r.bottom - 6), Offset(s.px(x), r.bottom), tick);
    }
    final u = lastU, x = lastX;
    if (u != null && x != null) {
      final paint = Paint()
        ..color = AppColors.estimate
        ..strokeWidth = 1.8;
      final xc = math.min(hi, x);
      canvas.drawCircle(Offset(r.left, s.py(u)), 4, Paint()..color = AppColors.estimate);
      canvas.drawLine(Offset(r.left, s.py(u)), Offset(s.px(xc), s.py(u)), paint);
      canvas.drawLine(Offset(s.px(xc), s.py(u)), Offset(s.px(xc), r.bottom), paint);
      canvas.drawCircle(Offset(s.px(xc), r.bottom), 4, Paint()..color = AppColors.sample);
      drawLabel(canvas, 'u = ${fmtFixed(u, 3)}', Offset(r.left + 6, s.py(u) - 14), color: AppColors.estimate, align: TextAlign.left);
      drawLabel(canvas, 'x = ${fmtFixed(x, 2)}', Offset(s.px(xc) + 4, r.bottom - 18), color: AppColors.sample, align: TextAlign.left);
    }
  }

  @override
  bool shouldRepaint(covariant InversePainter old) => true;
}

/// El intervalo [0, 1) partido en tramos: transformada inversa discreta.
class SegmentPainter extends CustomPainter {
  SegmentPainter({required this.probs, required this.labels, this.lastU, this.highlight});

  final List<double> probs;
  final List<String> labels;
  final double? lastU;
  final int? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(8, 18, size.width - 16, size.height - 40);
    var acc = 0.0;
    for (var i = 0; i < probs.length; i++) {
      final a = r.left + acc * r.width;
      acc += probs[i];
      final b = r.left + acc * r.width;
      final seg = Rect.fromLTRB(a, r.top, b, r.bottom);
      final col = i == highlight ? AppColors.estimate : (i.isEven ? AppColors.surfaceHigh : AppColors.feltDeep);
      canvas.drawRect(seg, Paint()..color = col);
      canvas.drawRect(
        seg,
        Paint()
          ..color = AppColors.outline
          ..style = PaintingStyle.stroke,
      );
      drawLabel(canvas, labels[i], seg.center - const Offset(0, 7), color: i == highlight ? AppColors.night : AppColors.text, size: 13, weight: FontWeight.w700);
      drawLabel(canvas, fmtFixed(acc, 1), Offset(b, r.bottom + 3), size: 9);
    }
    drawLabel(canvas, '0', Offset(r.left, r.bottom + 3), size: 9);
    final u = lastU;
    if (u != null) {
      final x = r.left + u * r.width;
      final p = Paint()
        ..color = AppColors.estimate
        ..strokeWidth = 2.4;
      canvas.drawLine(Offset(x, r.top - 10), Offset(x, r.bottom + 2), p);
      drawLabel(canvas, 'u = ${fmtFixed(u, 3)}', Offset(x, 2), color: AppColors.estimate, size: 10, weight: FontWeight.w600);
    }
  }

  @override
  bool shouldRepaint(covariant SegmentPainter old) => true;
}

/// Barras de frecuencias observadas (cian) frente a lo esperado (verde).
class BarsPainter extends CustomPainter {
  BarsPainter({required this.labels, required this.observed, required this.expected, this.highlight});

  final List<String> labels;
  final List<double> observed;
  final List<double> expected;
  final int? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 34, bottom: 22);
    final maxV = [...observed, ...expected].fold(0.01, (a, b) => math.max(a, b)) * 1.15;
    final s = ChartScale(r, 0, labels.length.toDouble(), 0, maxV);
    drawAxes(canvas, s, xTicks: false);
    for (var i = 0; i < labels.length; i++) {
      final a = s.px(i + 0.18), b = s.px(i + 0.82);
      final col = i == highlight ? AppColors.estimate : AppColors.sample;
      canvas.drawRect(Rect.fromLTRB(a, s.py(observed[i]), b, s.py(0)), Paint()..color = col.withValues(alpha: 0.85));
      final e = s.py(expected[i]);
      canvas.drawLine(
        Offset(a - 3, e),
        Offset(b + 3, e),
        Paint()
          ..color = AppColors.model
          ..strokeWidth = 2.4,
      );
      drawLabel(canvas, labels[i], Offset((a + b) / 2, r.bottom + 5), size: 11);
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter old) => true;
}

/// Gráfico de tornado: correlación de rangos de cada entrada con la salida.
class TornadoPainter extends CustomPainter {
  TornadoPainter({required this.items});
  final List<Sensitivity> items;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) {
      drawLabel(canvas, 'Simula para ver la sensibilidad', Offset(size.width / 2, size.height / 2 - 6), size: 12);
      return;
    }
    final r = Rect.fromLTRB(70, 8, size.width - 40, size.height - 18);
    final s = ChartScale(r, -1, 1, 0, items.length.toDouble());
    final axis = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(s.px(0), r.top), Offset(s.px(0), r.bottom), axis);
    for (final t in const [-1.0, -0.5, 0.5, 1.0]) {
      drawLabel(canvas, fmtFixed(t, 1), Offset(s.px(t), r.bottom + 3), size: 9);
    }
    final h = r.height / items.length;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final y0 = r.top + i * h + h * 0.18, y1 = r.top + (i + 1) * h - h * 0.18;
      final rho = it.rho.isFinite ? it.rho : 0.0;
      final col = rho >= 0 ? AppColors.sample : AppColors.risk;
      canvas.drawRect(Rect.fromLTRB(math.min(s.px(0), s.px(rho)), y0, math.max(s.px(0), s.px(rho)), y1), Paint()..color = col);
      drawLabel(canvas, it.name, Offset(r.left - 8, (y0 + y1) / 2 - 7), align: TextAlign.right, size: 12, color: AppColors.text, weight: FontWeight.w600);
      drawLabel(
        canvas,
        fmtFixed(rho, 2),
        Offset(rho >= 0 ? s.px(rho) + 4 : s.px(rho) - 4, (y0 + y1) / 2 - 6),
        align: rho >= 0 ? TextAlign.left : TextAlign.right,
        size: 10,
        color: col,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TornadoPainter old) => true;
}

/// Rango de dibujo razonable para una lista de valores (percentiles 0,5–99,5).
(double, double) displayRangeOf(List<double> values, {double pad = 0.04}) {
  if (values.isEmpty) return (0, 1);
  final sorted = sortedCopy(values);
  var lo = quantileSorted(sorted, 0.005), hi = quantileSorted(sorted, 0.995);
  if (hi <= lo) {
    lo -= 1;
    hi += 1;
  }
  final p = (hi - lo) * pad;
  return (lo - p, hi + p);
}

/// Vista previa de una distribución de entrada (densidad o barras).
class DensityPainter extends CustomPainter {
  DensityPainter(this.dist);
  final Distribution dist;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 8, right: 8, top: 6, bottom: 18);
    var (lo, hi) = dist.displayRange;
    if (!(hi > lo)) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    if (dist is DiscreteDist) {
      final d = dist as DiscreteDist;
      final maxP = d.probs.fold(0.0, (a, b) => math.max(a, b));
      final s = ChartScale(r, lo, hi, 0, maxP * 1.1);
      drawAxes(canvas, s, yTicks: false);
      for (var i = 0; i < d.values.length; i++) {
        final x = s.px(d.values[i]);
        canvas.drawLine(Offset(x, s.py(0)), Offset(x, s.py(d.probs[i])), Paint()
          ..color = AppColors.model
          ..strokeWidth = 6);
      }
      return;
    }
    if (dist is ConstantDist) {
      final s = ChartScale(r, lo, hi, 0, 1);
      drawAxes(canvas, s, yTicks: false);
      final x = s.px(dist.mean);
      canvas.drawLine(Offset(x, s.py(0)), Offset(x, s.py(1)), Paint()
        ..color = AppColors.model
        ..strokeWidth = 3);
      return;
    }
    var maxY = 0.0;
    final ys = <double>[];
    for (var i = 0; i <= 120; i++) {
      final y = dist.pdf(lo + (hi - lo) * i / 120);
      ys.add(y.isFinite ? y : 0);
      maxY = math.max(maxY, ys.last);
    }
    final s = ChartScale(r, lo, hi, 0, maxY <= 0 ? 1 : maxY * 1.1);
    drawAxes(canvas, s, yTicks: false);
    final path = Path()..moveTo(s.px(lo), s.py(0));
    for (var i = 0; i <= 120; i++) {
      path.lineTo(s.px(lo + (hi - lo) * i / 120), s.py(ys[i]));
    }
    path.lineTo(s.px(hi), s.py(0));
    canvas.drawPath(path, Paint()..color = AppColors.model.withValues(alpha: 0.25));
    canvas.drawPath(path, Paint()
      ..color = AppColors.model
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant DensityPainter old) => true;
}
