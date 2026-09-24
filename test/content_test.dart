import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/domain/content/cases.dart';
import 'package:monte_carlo_simulator/domain/content/confusions.dart';
import 'package:monte_carlo_simulator/domain/content/exercises.dart';
import 'package:monte_carlo_simulator/domain/content/figures.dart';
import 'package:monte_carlo_simulator/domain/content/glossary.dart';
import 'package:monte_carlo_simulator/domain/content/labs.dart';
import 'package:monte_carlo_simulator/domain/content/lessons.dart';
import 'package:monte_carlo_simulator/domain/labs/experiment_logic.dart';
import 'package:monte_carlo_simulator/domain/models/content_models.dart';
import 'package:monte_carlo_simulator/domain/progress/grading.dart';
import 'package:monte_carlo_simulator/domain/sim/templates.dart';

List<Exercise> get allItems => [...exercises, for (final c in cases) ...c.steps];

void main() {
  group('Cifras (motor Dart vs. réplica Python independiente)', () {
    final fixtures = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/figures.json').readAsStringSync()) as Map,
    );

    test('el registro y la réplica tienen las mismas cifras', () {
      expect(figures.keys.toSet(), fixtures.keys.toSet());
    });

    for (final f in figures.values) {
      test('cifra ${f.id}', () {
        final expected = (fixtures[f.id] as num).toDouble();
        final tol = f.tolerance * (expected.abs() > 1 ? expected.abs() : 1);
        expect(f.value, closeTo(expected, tol));
        expect(f.text, isNot(contains('NaN')));
      });
    }
  });

  group('Integridad del contenido', () {
    final allTexts = <String>[
      for (final l in lessons)
        for (final c in l.cards) ...[
          c.title,
          c.body,
          c.formula ?? '',
          c.keyIdea ?? '',
          if (c.check != null) ...[c.check!.question, c.check!.explanation, ...c.check!.options],
        ],
      for (final e in experiments) ...[e.setup, e.prediction, e.finding, e.explanation, for (final o in e.options) o.text],
      for (final x in allItems) ...[
        x.prompt,
        x.explanation,
        for (final o in x.options) ...[o.text, o.feedback],
        for (final o in x.justifications) ...[o.text, o.feedback],
        for (final w in x.wrongPatterns) w.feedback,
      ],
      for (final c in cases) ...[c.context, c.closing],
      for (final m in modelTemplates) m.description,
    ];

    test('todas las marcas {{id}} existen', () {
      for (final t in allTexts) {
        expect(renderFigures(t), isNot(contains('⟨')), reason: t);
      }
    });

    test('tres módulos, cuatro lecciones cada uno, en el orden pedido', () {
      expect(modules.map((m) => m.title), ['Concepto Monte Carlo', 'Simulación', 'Análisis']);
      for (final m in modules) {
        expect(lessonsOf(m.id).length, 4);
        expect(labsOf(m.id).length, 2);
        expect(exercisesOf(m.id).length, 12);
      }
      expect(experiments.length, 16);
      expect(cases.length, 11);
      expect(glossary.length, greaterThanOrEqualTo(40));
    });

    test('ids únicos', () {
      final ids = allItems.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      final eids = experiments.map((e) => e.id).toList();
      expect(eids.toSet().length, eids.length);
      final cids = confusions.map((c) => c.id).toList();
      expect(cids.toSet().length, cids.length);
    });

    test('cada confusión la produce algún distractor', () {
      final produced = <String>{'acertar_sin_entender'};
      for (final x in allItems) {
        for (final o in [...x.options, ...x.justifications]) {
          if (o.confusion != null) produced.add(o.confusion!);
        }
        for (final w in x.wrongPatterns) {
          produced.add(w.confusion);
        }
      }
      for (final e in experiments) {
        for (final o in e.options) {
          if (o.confusion != null) produced.add(o.confusion!);
        }
      }
      for (final c in confusions) {
        expect(produced, contains(c.id), reason: c.id);
        if (c.remedyLessonId != null) expect(lessonById(c.remedyLessonId!), isNotNull);
        if (c.remedyExperimentId != null) expect(() => experimentById(c.remedyExperimentId!), returnsNormally);
      }
    });

    test('cada experimento tiene exactamente una predicción correcta', () {
      for (final e in experiments) {
        expect(e.options.where((o) => o.correct).length, 1, reason: e.id);
      }
    });
  });

  group('Corrección de ítems', () {
    for (final x in allItems) {
      test('ítem ${x.id} (${x.type.name})', () {
        switch (x.type) {
          case ExerciseType.choice:
            {
              final i = x.options.indexWhere((o) => o.correct);
              expect(gradeChoice(x, i).score, 1);
              for (var k = 0; k < x.options.length; k++) {
                if (k != i) expect(gradeChoice(x, k).score, 0);
              }
            }
          case ExerciseType.decision:
            {
              final i = x.options.indexWhere((o) => o.correct);
              final j = x.justifications.indexWhere((o) => o.correct);
              expect(gradeDecision(x, i, j).score, closeTo(1, 1e-12));
              final wrongJ = j == 0 ? 1 : 0;
              final r = gradeDecision(x, i, wrongJ);
              expect(r.score, closeTo(0.6, 1e-12));
              expect(r.committed, contains('acertar_sin_entender'));
            }
          case ExerciseType.numeric:
            {
              final v = figureValue(x.answerFigure!);
              final typed = x.answerIsPercent ? v * 100 : v;
              expect(gradeNumeric(x, typed).score, 1);
              for (final w in x.wrongPatterns) {
                final wv = figureValue(w.figure);
                final r = gradeNumeric(x, x.answerIsPercent ? wv * 100 : wv);
                expect(r.score, 0, reason: '${x.id}: ${w.figure}');
                expect(r.committed, contains(w.confusion));
                expect(r.recognized, isTrue);
              }
            }
          case ExerciseType.ordering:
            {
              expect(gradeOrdering(x, x.steps).score, 1);
              final shuffled = shuffledSteps(x, 1);
              expect(shuffled, isNot(x.steps));
              expect(shuffled.toSet(), x.steps.toSet());
            }
        }
      });
    }
  });

  group('Laboratorios', () {
    for (final def in experiments) {
      test('experimento ${def.id} alcanza su mínimo y produce su hallazgo', () {
        final logic = ExperimentLogic.create(def.id);
        if (logic is SqrtNLogic) {
          for (final l in SqrtNLogic.levels) {
            logic.runLevel(l);
          }
        } else if (logic is RareLogic) {
          logic.runLevel(100);
          logic.runLevel(1000);
        } else {
          logic.add(def.minSamples);
        }
        expect(logic.progress, greaterThanOrEqualTo(def.minSamples));
        final text = renderFinding(def.finding, logic.observations);
        expect(text, isNot(contains('[[')));
        expect(text, isNot(contains('⟨')));
        expect(text, isNot(contains('NaN')));
        logic.newSeed();
        expect(logic.attempt, 1);
      });
    }

    test('π: la estimación con 20 000 dardos cae en ±4 EE', () {
      final l = PiLogic()..add(20000);
      expect((l.estimate - 3.141592653589793).abs(), lessThan(4 * l.theoreticalSe));
    });

    test('capacidad: las ventas medias se acercan a la cifra cerrada', () {
      final l = CapacityLogic()..add(40000);
      expect(l.meanSales, closeTo(figureValue('cap_expected_sales'), 0.5));
      l.capacity = 140;
      expect(l.meanSales, closeTo(l.theorySales, 0.5));
    });

    test('rutas paralelas: dos rutas cumplen menos que una', () {
      final l = MergeLogic()..add(20000);
      expect(l.onTime(two: false), closeTo(figureValue('merge_p_one'), 0.02));
      expect(l.onTime(two: true), closeTo(figureValue('merge_p_two'), 0.02));
    });

    test('√n: la dispersión se reduce a la mitad al cuadruplicar n', () {
      final l = SqrtNLogic()
        ..runLevel(400)
        ..runLevel(1600);
      final ratio = l.sdAt(400) / l.sdAt(1600);
      expect(ratio, inInclusiveRange(1.4, 2.8));
    });

    test('generador congruencial repite y xoshiro no', () {
      final g = GeneratorLogic()..add(600);
      expect(g.observedPeriod, 256);
      expect(g.reproduces(), isTrue);
      g.setGenerator(false);
      g.add(600);
      expect(g.observedPeriod, isNull);
    });
  });
}
