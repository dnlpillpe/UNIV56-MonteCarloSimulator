import 'dart:math' as math;

import '../content/cases.dart';
import '../content/exercises.dart';
import '../content/labs.dart';
import '../content/lessons.dart';

/// Estado de aprendizaje del estudiante (inmutable; se persiste en JSON).
class ProgressState {
  const ProgressState({
    this.lessonsDone = const {},
    this.experimentsDone = const {},
    this.predictions = const {},
    this.exerciseScores = const {},
    this.firstTryScores = const {},
    this.confusionScores = const {},
    this.simulationsRun = 0,
    this.generatedAnswered = 0,
    this.generatedCorrect = 0,
  });

  final Set<String> lessonsDone;
  final Set<String> experimentsDone;

  /// Primera predicción de cada experimento: true si fue la correcta.
  /// Es la «intuición inicial»: se guarda, pero nunca resta.
  final Map<String, bool> predictions;

  /// Mejor puntaje (0..1) por ejercicio o paso de caso.
  final Map<String, double> exerciseScores;

  /// Puntaje del primer intento («acierto ciego»).
  final Map<String, double> firstTryScores;

  /// Evidencia acumulada por confusión (+1 al cometerla, −0,5 al evitarla,
  /// ×0,97 por cada ítem respondido).
  final Map<String, double> confusionScores;
  final int simulationsRun;
  final int generatedAnswered;
  final int generatedCorrect;

  ProgressState copyWith({
    Set<String>? lessonsDone,
    Set<String>? experimentsDone,
    Map<String, bool>? predictions,
    Map<String, double>? exerciseScores,
    Map<String, double>? firstTryScores,
    Map<String, double>? confusionScores,
    int? simulationsRun,
    int? generatedAnswered,
    int? generatedCorrect,
  }) =>
      ProgressState(
        lessonsDone: lessonsDone ?? this.lessonsDone,
        experimentsDone: experimentsDone ?? this.experimentsDone,
        predictions: predictions ?? this.predictions,
        exerciseScores: exerciseScores ?? this.exerciseScores,
        firstTryScores: firstTryScores ?? this.firstTryScores,
        confusionScores: confusionScores ?? this.confusionScores,
        simulationsRun: simulationsRun ?? this.simulationsRun,
        generatedAnswered: generatedAnswered ?? this.generatedAnswered,
        generatedCorrect: generatedCorrect ?? this.generatedCorrect,
      );

  Map<String, Object?> toJson() => {
        'lessonsDone': lessonsDone.toList(),
        'experimentsDone': experimentsDone.toList(),
        'predictions': predictions,
        'exerciseScores': exerciseScores,
        'firstTryScores': firstTryScores,
        'confusionScores': confusionScores,
        'simulationsRun': simulationsRun,
        'generatedAnswered': generatedAnswered,
        'generatedCorrect': generatedCorrect,
      };

  static ProgressState fromJson(Map<String, dynamic> j) {
    Map<String, double> dmap(Object? o) => o is Map
        ? {for (final e in o.entries) e.key.toString(): (e.value as num).toDouble()}
        : <String, double>{};
    Set<String> sset(Object? o) => o is List ? {for (final e in o) e.toString()} : <String>{};
    final preds = <String, bool>{};
    final p = j['predictions'];
    if (p is Map) {
      for (final e in p.entries) {
        preds[e.key.toString()] = e.value == true;
      }
    }
    return ProgressState(
      lessonsDone: sset(j['lessonsDone']),
      experimentsDone: sset(j['experimentsDone']),
      predictions: preds,
      exerciseScores: dmap(j['exerciseScores']),
      firstTryScores: dmap(j['firstTryScores']),
      confusionScores: dmap(j['confusionScores']),
      simulationsRun: (j['simulationsRun'] as num?)?.toInt() ?? 0,
      generatedAnswered: (j['generatedAnswered'] as num?)?.toInt() ?? 0,
      generatedCorrect: (j['generatedCorrect'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Dominio de un módulo: 15 % lecciones + 15 % laboratorios + 70 % práctica.
class Mastery {
  const Mastery({required this.lessons, required this.labs, required this.practice});
  final double lessons;
  final double labs;
  final double practice;

  double get total => 0.15 * lessons + 0.15 * labs + 0.70 * practice;

  /// Umbral doble: 0,70 en el total **y** en la práctica.
  bool get competent => total >= 0.70 && practice >= 0.70;

  String get level {
    if (competent) return 'Competente';
    if (total >= 0.40) return 'En progreso';
    if (total > 0) return 'Iniciado';
    return 'Sin empezar';
  }
}

Mastery masteryOf(String moduleId, ProgressState s) {
  final ls = lessonsOf(moduleId);
  final exps = [
    for (final lab in labsOf(moduleId)) ...lab.experimentIds,
  ];
  final exs = exercisesOf(moduleId);
  double frac(int done, int total) => total == 0 ? 0 : done / total;
  final lessonsFrac = frac(ls.where((l) => s.lessonsDone.contains(l.id)).length, ls.length);
  final labsFrac = frac(exps.where(s.experimentsDone.contains).length, exps.length);
  var practice = 0.0;
  for (final e in exs) {
    practice += s.exerciseScores[e.id] ?? 0;
  }
  practice = exs.isEmpty ? 0 : practice / exs.length;
  return Mastery(lessons: lessonsFrac, labs: labsFrac, practice: practice);
}

/// Promedio de casos resueltos (0..1) de un caso.
double caseScore(String caseId, ProgressState s) {
  final c = caseById(caseId);
  if (c == null || c.steps.isEmpty) return 0;
  var sum = 0.0;
  for (final st in c.steps) {
    sum += s.exerciseScores[st.id] ?? 0;
  }
  return sum / c.steps.length;
}

/// Tasa de acierto ciego: primeros intentos correctos / primeros intentos.
double blindAccuracy(ProgressState s) {
  if (s.firstTryScores.isEmpty) return double.nan;
  final ok = s.firstTryScores.values.where((v) => v >= 0.999).length;
  return ok / s.firstTryScores.length;
}

/// Aplica la evidencia de un ítem respondido al diagnóstico.
Map<String, double> updateDiagnosis(
  Map<String, double> current, {
  required Set<String> committed,
  required Set<String> avoided,
}) {
  final next = <String, double>{
    for (final e in current.entries) e.key: e.value * 0.97,
  };
  for (final c in committed) {
    next[c] = (next[c] ?? 0.0) + 1;
  }
  for (final a in avoided) {
    if (committed.contains(a)) continue;
    next[a] = math.max(0.0, (next[a] ?? 0.0) - 0.5);
  }
  next.removeWhere((k, v) => v < 0.05);
  return next;
}

/// Confusiones activas (evidencia ≥ 1), de mayor a menor.
List<MapEntry<String, double>> activeConfusions(ProgressState s, {double threshold = 1.0}) {
  final list = s.confusionScores.entries.where((e) => e.value >= threshold).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list;
}

/// Siguiente paso sugerido: primera lección no vista, luego primer
/// experimento sin hallazgo, luego primer ejercicio sin dominar.
String? nextStepLabel(ProgressState s) {
  for (final l in lessons) {
    if (!s.lessonsDone.contains(l.id)) return 'Lección: ${l.title}';
  }
  for (final e in experiments) {
    if (!s.experimentsDone.contains(e.id)) return 'Experimento: ${e.title}';
  }
  for (final x in exercises) {
    if ((s.exerciseScores[x.id] ?? 0) < 0.99) return 'Práctica del módulo ${x.moduleId.substring(1)}';
  }
  return null;
}
