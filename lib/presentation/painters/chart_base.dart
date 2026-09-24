import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';

/// Utilidades comunes de los gráficos propios (sin librerías de gráficos:
/// cada pintor expone la geometría que el concepto necesita).

class ChartScale {
  ChartScale(this.rect, this.x0, this.x1, this.y0, this.y1, {this.logX = false});

  final Rect rect;
  final double x0, x1, y0, y1;
  final bool logX;

  double px(double x) {
    if (logX) {
      final lx = math.log(math.max(x, 1e-12)) / math.ln10;
      final l0 = math.log(x0) / math.ln10, l1 = math.log(x1) / math.ln10;
      return rect.left + (lx - l0) / (l1 - l0) * rect.width;
    }
    if (x1 == x0) return rect.center.dx;
    return rect.left + (x - x0) / (x1 - x0) * rect.width;
  }

  double py(double y) {
    if (y1 == y0) return rect.center.dy;
    return rect.bottom - (y - y0) / (y1 - y0) * rect.height;
  }

  Offset p(double x, double y) => Offset(px(x), py(y));

  double xAt(double pxv) {
    final t = math.min(1.0, math.max(0.0, (pxv - rect.left) / rect.width));
    return x0 + t * (x1 - x0);
  }
}

/// Márgenes estándar para dejar sitio a las etiquetas.
Rect plotRect(Size size, {double left = 40, double right = 10, double top = 10, double bottom = 26}) =>
    Rect.fromLTRB(left, top, math.max(left + 10, size.width - right), math.max(top + 10, size.height - bottom));

/// Marcas «redondas» entre lo y hi.
List<double> niceTicks(double lo, double hi, {int count = 5}) {
  if (!(hi > lo) || !lo.isFinite || !hi.isFinite) return [lo];
  final span = hi - lo;
  final raw = span / count;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final step = (norm < 1.5 ? 1.0 : norm < 3 ? 2.0 : norm < 7 ? 5.0 : 10.0) * mag;
  final start = (lo / step).ceilToDouble() * step;
  final out = <double>[];
  for (var v = start; v <= hi + step * 1e-9; v += step) {
    out.add(v.abs() < step * 1e-9 ? 0.0 : v);
  }
  return out;
}

void drawLabel(
  Canvas canvas,
  String text,
  Offset at, {
  Color color = AppColors.textMuted,
  double size = 10,
  TextAlign align = TextAlign.center,
  bool above = false,
  FontWeight weight = FontWeight.w400,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: 160);
  var dx = at.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;
  final dy = above ? at.dy - tp.height : at.dy;
  tp.paint(canvas, Offset(dx, dy));
}

String tickLabel(double v, double span) {
  if (span >= 100) return fmtFixed(v, 0);
  if (span >= 10) return fmtFixed(v, v == v.roundToDouble() ? 0 : 1);
  if (span >= 1) return fmtFixed(v, 1);
  if (span >= 0.1) return fmtFixed(v, 2);
  return fmtFixed(v, 3);
}

/// Ejes con cuadrícula suave y marcas.
void drawAxes(Canvas canvas, ChartScale s, {bool yTicks = true, bool xTicks = true, List<double>? xTickValues}) {
  final grid = Paint()
    ..color = AppColors.grid
    ..strokeWidth = 0.6;
  final axis = Paint()
    ..color = AppColors.outline
    ..strokeWidth = 1;
  if (yTicks) {
    for (final t in niceTicks(s.y0, s.y1, count: 4)) {
      final y = s.py(t);
      canvas.drawLine(Offset(s.rect.left, y), Offset(s.rect.right, y), grid);
      drawLabel(canvas, tickLabel(t, s.y1 - s.y0), Offset(s.rect.left - 4, y - 6), align: TextAlign.right);
    }
  }
  if (xTicks) {
    final ticks = xTickValues ?? niceTicks(s.x0, s.x1, count: 5);
    for (final t in ticks) {
      final x = s.px(t);
      if (x < s.rect.left - 1 || x > s.rect.right + 1) continue;
      canvas.drawLine(Offset(x, s.rect.bottom), Offset(x, s.rect.bottom + 3), axis);
      drawLabel(
        canvas,
        s.logX ? fmtInt(t.round()) : tickLabel(t, s.x1 - s.x0),
        Offset(x, s.rect.bottom + 5),
      );
    }
  }
  canvas.drawLine(s.rect.bottomLeft, s.rect.bottomRight, axis);
  canvas.drawLine(s.rect.bottomLeft, s.rect.topLeft, axis);
}

/// Línea discontinua horizontal o vertical.
void dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 5, double gap = 4}) {
  final d = b - a;
  final len = d.distance;
  if (len == 0) return;
  final dir = d / len;
  var t = 0.0;
  while (t < len) {
    final e = math.min(t + dash, len);
    canvas.drawLine(a + dir * t, a + dir * e, paint);
    t = e + gap;
  }
}

/// Marcador vertical con etiqueta (media, percentil, umbral…).
class ChartMarker {
  const ChartMarker(this.x, this.label, this.color, {this.dashed = true});
  final double x;
  final String label;
  final Color color;
  final bool dashed;
}

void drawMarkers(Canvas canvas, ChartScale s, List<ChartMarker> markers) {
  var row = 0;
  for (final m in markers) {
    if (!m.x.isFinite) continue;
    final x = s.px(m.x);
    if (x < s.rect.left - 1 || x > s.rect.right + 1) continue;
    final paint = Paint()
      ..color = m.color
      ..strokeWidth = 1.6;
    if (m.dashed) {
      dashedLine(canvas, Offset(x, s.rect.top), Offset(x, s.rect.bottom), paint);
    } else {
      canvas.drawLine(Offset(x, s.rect.top), Offset(x, s.rect.bottom), paint);
    }
    final alignRight = x > s.rect.center.dx;
    drawLabel(
      canvas,
      m.label,
      Offset(alignRight ? x - 3 : x + 3, s.rect.top + 2 + 12.0 * row),
      color: m.color,
      align: alignRight ? TextAlign.right : TextAlign.left,
      weight: FontWeight.w600,
    );
    row = (row + 1) % 3;
  }
}
