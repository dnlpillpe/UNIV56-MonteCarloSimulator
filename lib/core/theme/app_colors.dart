import 'package:flutter/material.dart';

/// Identidad visual: noche de tapete verde (Monte Carlo) + nube de puntos.
///
/// **Cada color es un concepto** y significa lo mismo en toda la app:
/// verde menta = modelo/valor teórico, cian = muestras observadas,
/// dorado = estimación Monte Carlo, naranja = riesgo (colas, pérdidas,
/// umbral), violeta = incertidumbre de la estimación (error estándar, IC),
/// rojo rosado = solo confusiones detectadas.
class AppColors {
  AppColors._();

  // Superficies
  static const Color night = Color(0xFF0B2521);
  static const Color surface = Color(0xFF10312C);
  static const Color surfaceHigh = Color(0xFF174039);
  static const Color outline = Color(0xFF2C5A51);
  static const Color grid = Color(0xFF214A42);

  // Marca
  static const Color felt = Color(0xFF2BB38A);
  static const Color feltDeep = Color(0xFF12644F);
  static const Color chip = Color(0xFFF5B83D);

  // Conceptos
  static const Color model = Color(0xFF3DDC97);
  static const Color sample = Color(0xFF45C4E0);
  static const Color estimate = Color(0xFFF5B83D);
  static const Color risk = Color(0xFFFF8A4C);
  static const Color uncertainty = Color(0xFFA58BFF);
  static const Color confusion = Color(0xFFFF5C7A);

  // Texto
  static const Color text = Color(0xFFE9F5F1);
  static const Color textMuted = Color(0xFFA3C2BA);
  static const Color onFelt = Color(0xFF04201A);

  /// Colores por módulo (tema: azar, riesgo, estimaciones).
  static const List<Color> module = [sample, risk, uncertainty];

  /// Serie de trazas para varias semillas.
  static const List<Color> seeds = [estimate, sample, model, uncertainty, risk];
}
