import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/math/stats.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/labs/experiment_logic.dart';
import 'chart_base.dart';

/// Nube de puntos en un rectángulo (dardos, pares de un generador, pares
/// correlacionados). Opcionalmente dibuja el cuarto de círculo o una curva.
class ScatterPainter extends CustomPainter {
  ScatterPainter({
    required this.dots,
    this.x0 = 0,
    this.x1 = 1,
    this.y0 = 0,
    this.y1 = 1,
    this.quarterCircle = false,
    this.curve,
    this.insideColor = AppColors.sample,
    this.outsideColor = AppColors.risk,
    this.dotRadius = 1.6,
    this.version = 0,
    this.showAxes = true,
  });

  final List<Dot> dots;
  final double x0, x1, y0, y1;
  final bool quarterCircle;
  final double Function(double x)? curve;
  final Color insideColor;
  final Color outsideColor;
  final double dotRadius;

  /// Cambia cuando cambian los datos (las listas se mutan en su lugar).
  final int version;
  final bool showAxes;

  @override
  void paint(Canvas canvas, Size size) {
    final r = showAxes ? plotRect(size, left: 30, bottom: 20) : Offset.zero & size;
    final s = ChartScale(r, x0, x1, y0, y1);
    canvas.drawRect(r, Paint()..color = AppColors.night);
    if (showAxes) drawAxes(canvas, s);
    final pIn = Paint()..color = insideColor.withValues(alpha: 0.85);
    final pOut = Paint()..color = outsideColor.withValues(alpha: 0.85);
    for (final d in dots) {
      if (d.x < x0 || d.x > x1 || d.y < y0 || d.y > y1) continue;
      canvas.drawCircle(s.p(d.x, d.y), dotRadius, d.inside ? pIn : pOut);
    }
    final line = Paint()
      ..color = AppColors.model
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (quarterCircle) {
      final path = Path();
      for (var i = 0; i <= 90; i++) {
        final a = i / 90 * math.pi / 2;
        final pt = s.p(math.cos(a), math.sin(a));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, line);
    }
    final f = curve;
    if (f != null) {
      final path = Path();
      for (var i = 0; i <= 100; i++) {
        final x = x0 + (x1 - x0) * i / 100;
        final pt = s.p(x, f(x));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant ScatterPainter old) => true;
}

/// Trayectorias de la estimación acumulada contra n (escala logarítmica),
/// con el valor verdadero (verde) y el embudo ±2·EE (violeta).
class ConvergencePainter extends CustomPainter {
  ConvergencePainter({
    required this.traces,
    this.colors = const [AppColors.estimate],
    this.truth,
    this.seCoef,
    required this.yLo,
    required this.yHi,
    this.nMax = 10000,
    this.version = 0,
  });

  final List<List<TracePoint>> traces;
  final List<Color> colors;
  final double? truth;

  /// Desviación por iteración: el embudo es truth ± 2·seCoef/√n.
  final double? seCoef;
  final double yLo, yHi;
  final int nMax;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 44);
    var maxN = nMax;
    for (final t in traces) {
      if (t.isNotEmpty && t.last.n > maxN) maxN = t.last.n;
    }
    final s = ChartScale(r, 1, maxN.toDouble(), yLo, yHi, logX: true);
    final ticks = <double>[
      for (var v = 1; v <= maxN; v *= 10) v.toDouble(),
    ];
    drawAxes(canvas, s, xTickValues: ticks);
    canvas.save();
    canvas.clipRect(r);
    final t = truth;
    final c = seCoef;
    if (t != null && c != null) {
      final upper = Path(), lower = Path();
      for (var i = 0; i <= 120; i++) {
        final n = math.pow(maxN.toDouble(), i / 120).toDouble();
        final h = 2 * c / math.sqrt(n);
        final pu = s.p(n, t + h), pl = s.p(n, t - h);
        if (i == 0) {
          upper.moveTo(pu.dx, pu.dy);
          lower.moveTo(pl.dx, pl.dy);
        } else {
          upper.lineTo(pu.dx, pu.dy);
          lower.lineTo(pl.dx, pl.dy);
        }
      }
      final band = Paint()
        ..color = AppColors.uncertainty.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(upper, band);
      canvas.drawPath(lower, band);
    }
    if (t != null) {
      final p = Paint()
        ..color = AppColors.model
        ..strokeWidth = 1.4;
      dashedLine(canvas, Offset(r.left, s.py(t)), Offset(r.right, s.py(t)), p);
    }
    for (var k = 0; k < traces.length; k++) {
      final tr = traces[k];
      if (tr.length < 2) continue;
      final path = Path();
      for (var i = 0; i < tr.length; i++) {
        final pt = s.p(tr[i].n.toDouble(), tr[i].value);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[k % colors.length]
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
    drawLabel(canvas, 'n (escala log)', Offset(r.right, r.bottom + 14), align: TextAlign.right, size: 9);
  }

  @override
  bool shouldRepaint(covariant ConvergencePainter old) => true;
}

/// Réplicas como puntos en filas (una fila por n), con el valor verdadero.
class StripPainter extends CustomPainter {
  StripPainter({required this.rows, required this.truth, required this.lo, required this.hi, this.color = AppColors.estimate});

  /// Etiqueta de fila → estimaciones (vacío si no se ha corrido).
  final List<MapEntry<String, List<double>>> rows;
  final double truth;
  final double lo, hi;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = plotRect(size, left: 64, bottom: 22);
    final s = ChartScale(r, lo, hi, 0, rows.length.toDouble());
    drawAxes(canvas, s, yTicks: false);
    final truthPaint = Paint()
      ..color = AppColors.model
      ..strokeWidth = 1.4;
    dashedLine(canvas, Offset(s.px(truth), r.top), Offset(s.px(truth), r.bottom), truthPaint);
    final dot = Paint()..color = color.withValues(alpha: 0.8);
    for (var i = 0; i < rows.length; i++) {
      final y = s.py(rows.length - i - 0.5);
      drawLabel(canvas, rows[i].key, Offset(r.left - 6, y - 6), align: TextAlign.right, size: 10);
      final xs = rows[i].value;
      if (xs.isEmpty) {
        drawLabel(canvas, 'toca «Correr»', Offset(r.center.dx, y - 6), size: 10);
        continue;
      }
      for (var k = 0; k < xs.length; k++) {
        final jitter = ((k * 37) % 11 - 5) * 1.3;
        final x = s.px(math.min(hi, math.max(lo, xs[k])));
        canvas.drawCircle(Offset(x, y + jitter), 2.6, dot);
      }
      // Banda ±1 desviación de las réplicas.
      if (xs.length >= 3) {
        final m = mean(xs), sd = stdDev(xs);
        final band = Paint()
          ..color = AppColors.uncertainty
          ..strokeWidth = 2;
        canvas.drawLine(Offset(s.px(math.max(lo, m - sd)), y + 10), Offset(s.px(math.min(hi, m + sd)), y + 10), band);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StripPainter old) => true;
}
