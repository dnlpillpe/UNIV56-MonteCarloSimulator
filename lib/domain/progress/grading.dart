import 'dart:math' as math;

import '../../core/rng/random_source.dart';
import '../../core/util/format.dart';
import '../content/figures.dart';
import '../models/content_models.dart';

/// Resultado de corregir un ítem.
class GradeResult {
  const GradeResult({
    required this.score,
    required this.feedback,
    this.committed = const {},
    this.recognized = false,
  });

  /// Puntaje 0..1.
  final double score;
  final String feedback;

  /// Confusiones que la respuesta revela.
  final Set<String> committed;

  /// true si un número incorrecto coincidió con un error típico conocido.
  final bool recognized;

  bool get correct => score >= 0.999;
}

bool _close(double x, double target, double relTol) {
  if (target == 0) return x.abs() < 1e-9;
  return (x - target).abs() <= relTol * target.abs();
}

GradeResult gradeChoice(Exercise e, int index) {
  final o = e.options[index];
  return GradeResult(
    score: o.correct ? 1 : 0,
    feedback: renderFigures(o.feedback),
    committed: {if (o.confusion != null) o.confusion!},
  );
}

/// Regla 60/40: la decisión vale 0,6 y la justificación 0,4.
GradeResult gradeDecision(Exercise e, int option, int justification) {
  final o = e.options[option];
  final j = e.justifications[justification];
  final score = (o.correct ? 0.6 : 0.0) + (j.correct ? 0.4 : 0.0);
  final committed = <String>{
    if (o.confusion != null) o.confusion!,
    if (j.confusion != null) j.confusion!,
  };
  // Decisión correcta con justificación incorrecta: acierto sin entender.
  if (o.correct && !j.correct) committed.add('acertar_sin_entender');
  return GradeResult(
    score: score,
    feedback: '${renderFigures(o.feedback)}\n${renderFigures(j.feedback)}',
    committed: committed,
  );
}

/// Valor que se compara: si la respuesta es un porcentaje, el estudiante
/// escribe 37,8 y la cifra vale 0,378.
double _asFigureScale(Exercise e, double typed) => e.answerIsPercent ? typed / 100 : typed;

GradeResult gradeNumeric(Exercise e, double typed) {
  final target = figureValue(e.answerFigure!);
  final x = _asFigureScale(e, typed);
  if (_close(x, target, e.relTolerance)) {
    return GradeResult(score: 1, feedback: 'Correcto: ${figures[e.answerFigure!]!.text}${e.unit.isEmpty || e.answerIsPercent ? '' : ' ${e.unit}'}.');
  }
  for (final w in e.wrongPatterns) {
    final v = figureValue(w.figure);
    if (_close(x, v, math.max(e.relTolerance, 0.01))) {
      return GradeResult(
        score: 0,
        feedback: renderFigures(w.feedback),
        committed: {w.confusion},
        recognized: true,
      );
    }
  }
  return const GradeResult(
    score: 0,
    feedback: 'No coincide con la respuesta. Revisa el procedimiento en la explicación.',
  );
}

/// Orden: fracción de posiciones correctas (1 solo si todo está en orden).
GradeResult gradeOrdering(Exercise e, List<String> order) {
  var ok = 0;
  for (var i = 0; i < e.steps.length && i < order.length; i++) {
    if (order[i] == e.steps[i]) ok++;
  }
  final score = e.steps.isEmpty ? 0.0 : ok / e.steps.length;
  return GradeResult(
    score: score,
    feedback: score >= 0.999
        ? 'Correcto: el orden es el de un estudio profesional.'
        : '$ok de ${e.steps.length} pasos en su lugar.',
  );
}

/// Baraja los pasos de un ítem de ordenamiento, garantizando que no queden
/// en el orden correcto.
List<String> shuffledSteps(Exercise e, int seed) {
  final rng = Xoshiro128(seed);
  final list = List<String>.of(e.steps);
  for (var tries = 0; tries < 10; tries++) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = (rng.nextDouble() * (i + 1)).floor();
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    var same = true;
    for (var i = 0; i < list.length; i++) {
      if (list[i] != e.steps[i]) {
        same = false;
        break;
      }
    }
    if (!same) break;
  }
  return list;
}

// ============================================================ práctica generativa

/// Pregunta generada con parámetros aleatorios. Alimenta el diagnóstico,
/// no el dominio (para que repetir no infle la nota).
class GeneratedQuestion {
  const GeneratedQuestion({
    required this.topic,
    required this.prompt,
    required this.answer,
    required this.relTolerance,
    required this.explanation,
    this.unit = '',
    this.wrongs = const [],
    this.isPercent = false,
  });

  final String topic;
  final String prompt;
  final double answer;
  final double relTolerance;
  final String explanation;
  final String unit;
  final bool isPercent;

  /// Errores típicos: (valor, confusión, retroalimentación).
  final List<(double, String, String)> wrongs;

  GradeResult grade(double typed) {
    final x = isPercent ? typed / 100 : typed;
    if (_close(x, answer, relTolerance)) {
      return GradeResult(score: 1, feedback: 'Correcto. $explanation');
    }
    for (final w in wrongs) {
      if (_close(x, w.$1, math.max(relTolerance, 0.01))) {
        return GradeResult(score: 0, feedback: '${w.$3} $explanation', committed: {w.$2}, recognized: true);
      }
    }
    return GradeResult(score: 0, feedback: 'No coincide. $explanation');
  }
}

const List<String> generatorTopics = [
  'Error estándar',
  'Iteraciones necesarias',
  'Ley de √n',
  'Regla del tres',
];

GeneratedQuestion generateQuestion(String topic, int seed) {
  final r = Xoshiro128(seed);
  int pick(List<int> xs) => xs[(r.nextDouble() * xs.length).floor()];
  switch (topic) {
    case 'Error estándar':
      {
        final s = pick([20, 50, 80, 120, 150, 200, 300]).toDouble();
        final n = pick([100, 400, 900, 2500, 10000]);
        final se = s / math.sqrt(n);
        return GeneratedQuestion(
          topic: topic,
          prompt: 'La salida tiene desviación ${fmtNum(s)} y simulaste ${fmtInt(n)} iteraciones. ¿Cuál es el error estándar de la media?',
          answer: se,
          relTolerance: 0.02,
          explanation: 'EE = s/√n = ${fmtNum(s)}/${fmtNum(math.sqrt(n))} = ${fmtNum(se)}.',
          wrongs: [
            (s / n, 'error_lineal_n', 'Dividiste entre n, no entre √n.'),
            (s, 'se_vs_sd', 'Esa es la desviación de la salida, no el error de su media.'),
          ],
        );
      }
    case 'Iteraciones necesarias':
      {
        final s = pick([40, 60, 100, 140, 250]).toDouble();
        final e = pick([2, 4, 5, 10]).toDouble();
        final nReq = math.pow(1.959963984540054 * s / e, 2).toDouble();
        return GeneratedQuestion(
          topic: topic,
          prompt: 'Una corrida piloto da desviación ${fmtNum(s)}. ¿Cuántas iteraciones necesitas para que el IC 95 % de la media tenga semiamplitud ${fmtNum(e)}?',
          answer: nReq,
          relTolerance: 0.03,
          unit: 'iteraciones',
          explanation: 'n = (1,96·s/E)² = (1,96·${fmtNum(s)}/${fmtNum(e)})² ≈ ${fmtInt(nReq.ceil())}.',
          wrongs: [
            (1.959963984540054 * s / e, 'error_lineal_n', 'Faltó elevar al cuadrado.'),
          ],
        );
      }
    case 'Ley de √n':
      {
        final se = pick([4, 6, 8, 10, 12]).toDouble();
        final k = pick([4, 9, 16, 25]);
        final ans = se / math.sqrt(k);
        return GeneratedQuestion(
          topic: topic,
          prompt: 'Con n iteraciones el error estándar es ${fmtNum(se)}. ¿Cuál será con ${fmtInt(k)} veces más iteraciones?',
          answer: ans,
          relTolerance: 0.02,
          explanation: 'Se divide entre √$k = ${fmtNum(math.sqrt(k))}: ${fmtNum(ans)}.',
          wrongs: [
            (se / k, 'error_lineal_n', 'El error no baja en proporción a n sino a √n.'),
            (se, 'se_vs_sd', 'El error estándar sí baja con más iteraciones.'),
          ],
        );
      }
    default:
      {
        final n = pick([200, 300, 500, 600, 1000, 1500, 3000]);
        final ans = 3 / n;
        return GeneratedQuestion(
          topic: 'Regla del tres',
          prompt: 'En ${fmtInt(n)} iteraciones el evento no ocurrió nunca. ¿Cuál es la cota superior aproximada al 95 % de su probabilidad, en %?',
          answer: ans,
          relTolerance: 0.03,
          unit: '%',
          isPercent: true,
          explanation: '3/n = 3/${fmtInt(n)} = ${fmtPct(ans, decimals: 2)}.',
          wrongs: [
            (0.0, 'cero_casos_cero_prob', 'Cero casos no es probabilidad cero.'),
            (1 / n, 'cero_casos_cero_prob', '1/n supone que hubo un caso; con cero se usa 3/n.'),
          ],
        );
      }
  }
}
