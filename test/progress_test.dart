import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/domain/content/exercises.dart';
import 'package:monte_carlo_simulator/domain/content/labs.dart';
import 'package:monte_carlo_simulator/domain/content/lessons.dart';
import 'package:monte_carlo_simulator/domain/progress/grading.dart';
import 'package:monte_carlo_simulator/domain/progress/progress.dart';

void main() {
  test('dominio 15/15/70 con umbral doble', () {
    final m1 = lessonsOf('m1').map((l) => l.id).toSet();
    final e1 = [for (final l in labsOf('m1')) ...l.experimentIds].toSet();
    final ex = exercisesOf('m1');
    // Todo visto y hecho, práctica perfecta.
    var s = ProgressState(
      lessonsDone: m1,
      experimentsDone: e1,
      exerciseScores: {for (final e in ex) e.id: 1.0},
    );
    var m = masteryOf('m1', s);
    expect(m.total, closeTo(1, 1e-12));
    expect(m.competent, isTrue);
    // Lecciones y labs completos, práctica 0,6: total 0,72 pero no competente.
    s = ProgressState(
      lessonsDone: m1,
      experimentsDone: e1,
      exerciseScores: {for (final e in ex) e.id: 0.6},
    );
    m = masteryOf('m1', s);
    expect(m.total, closeTo(0.15 + 0.15 + 0.7 * 0.6, 1e-12));
    expect(m.competent, isFalse);
    expect(masteryOf('m2', const ProgressState()).level, 'Sin empezar');
  });

  test('diagnóstico: +1 al cometer, −0,5 al evitar, ×0,97 por ítem', () {
    var d = updateDiagnosis({}, committed: {'error_lineal_n'}, avoided: {});
    expect(d['error_lineal_n'], 1);
    d = updateDiagnosis(d, committed: {}, avoided: {'error_lineal_n'});
    expect(d['error_lineal_n'], closeTo(0.97 - 0.5, 1e-12));
    d = updateDiagnosis(d, committed: {'error_lineal_n'}, avoided: {'error_lineal_n'});
    expect(d['error_lineal_n'], closeTo(0.47 * 0.97 + 1, 1e-12));
    for (var i = 0; i < 200; i++) {
      d = updateDiagnosis(d, committed: {}, avoided: {});
    }
    expect(d.containsKey('error_lineal_n'), isFalse);
  });

  test('confusiones activas ordenadas por evidencia', () {
    const s = ProgressState(confusionScores: {'a': 0.5, 'b': 2.0, 'c': 1.2});
    expect(activeConfusions(s).map((e) => e.key), ['b', 'c']);
  });

  test('acierto ciego y siguiente paso', () {
    const s = ProgressState(firstTryScores: {'x1': 1.0, 'x2': 0.0, 'x3': 0.6, 'x4': 1.0});
    expect(blindAccuracy(s), closeTo(0.5, 1e-12));
    expect(nextStepLabel(const ProgressState()), contains(lessons.first.title));
  });

  test('JSON de ida y vuelta', () {
    const s = ProgressState(
      lessonsDone: {'l1_1'},
      experimentsDone: {'e1_pi'},
      predictions: {'e1_pi': true},
      exerciseScores: {'x1_01': 1.0},
      firstTryScores: {'x1_01': 0.0},
      confusionScores: {'error_lineal_n': 1.5},
      simulationsRun: 3,
      generatedAnswered: 4,
      generatedCorrect: 2,
    );
    final b = ProgressState.fromJson(Map<String, dynamic>.from(s.toJson()));
    expect(b.lessonsDone, s.lessonsDone);
    expect(b.predictions, s.predictions);
    expect(b.exerciseScores, s.exerciseScores);
    expect(b.confusionScores, s.confusionScores);
    expect(b.simulationsRun, 3);
    expect(b.generatedCorrect, 2);
  });

  test('práctica generativa: respuestas correctas y errores típicos', () {
    for (final topic in generatorTopics) {
      for (var seed = 0; seed < 25; seed++) {
        final q = generateQuestion(topic, seed);
        final typed = q.isPercent ? q.answer * 100 : q.answer;
        expect(q.grade(typed).correct, isTrue, reason: '$topic/$seed');
        for (final w in q.wrongs) {
          if ((w.$1 - q.answer).abs() <= 0.03 * q.answer.abs()) continue;
          final r = q.grade(q.isPercent ? w.$1 * 100 : w.$1);
          expect(r.correct, isFalse);
          expect(r.committed, contains(w.$2));
        }
      }
    }
  });
}
