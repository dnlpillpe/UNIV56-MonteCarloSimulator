import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rng/random_source.dart';
import '../../core/theme/app_colors.dart';

/// Marca de la app: lluvia de puntos sobre el cuarto de círculo (la
/// estimación de π) y el último dardo en dorado.
///
/// `tool/generate_icon.py` reproduce exactamente este dibujo —mismos
/// puntos, xoshiro128** con semilla 2026— para generar el icono.
class BrandPainter extends CustomPainter {
  const BrandPainter({this.withBackground = true});

  final bool withBackground;

  static const int dots = 80;
  static const int seed = 2026;
  static const Offset goldDart = Offset(0.56, 0.52);

  static List<(double, double, bool)> brandDots() {
    final rng = Xoshiro128(seed);
    return [
      for (var i = 0; i < dots; i++)
        () {
          final x = rng.nextDouble(), y = rng.nextDouble();
          return (x, y, x * x + y * y <= 1);
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    if (withBackground) {
      final rect = origin & Size(s, s);
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF155C4C), Color(0xFF081C19)],
        ).createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(0.22 * s)), paint);
    }
    final side = 0.64 * s;
    final left = origin.dx + 0.18 * s, top = origin.dy + 0.18 * s;
    Offset p(double x, double y) => Offset(left + x * side, top + side - y * side);

    canvas.drawRect(
      Rect.fromLTWH(left, top, side, side),
      Paint()
        ..color = AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 0.010 * s),
    );
    final r = 0.021 * s;
    final pIn = Paint()..color = AppColors.sample;
    final pOut = Paint()..color = AppColors.risk;
    for (final d in brandDots()) {
      canvas.drawCircle(p(d.$1, d.$2), r, d.$3 ? pIn : pOut);
    }
    final arcRect = Rect.fromCircle(center: p(0, 0), radius: side);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi / 2,
      false,
      Paint()
        ..color = AppColors.model
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.030 * s,
    );
    final g = p(goldDart.dx, goldDart.dy);
    final big = 0.046 * s;
    canvas.drawCircle(
      g,
      big * 1.55,
      Paint()
        ..color = AppColors.estimate
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, 0.012 * s),
    );
    canvas.drawCircle(g, big, Paint()..color = AppColors.estimate);
  }

  @override
  bool shouldRepaint(covariant BrandPainter old) => old.withBackground != withBackground;
}

/// Marca lista para usar como widget.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: BrandPainter()),
      );
}
