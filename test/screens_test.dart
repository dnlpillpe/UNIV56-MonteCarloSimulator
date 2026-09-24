import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/domain/content/cases.dart';
import 'package:monte_carlo_simulator/domain/content/labs.dart';
import 'package:monte_carlo_simulator/domain/content/lessons.dart';
import 'package:monte_carlo_simulator/presentation/about/about_screen.dart';
import 'package:monte_carlo_simulator/presentation/cases/case_screen.dart';
import 'package:monte_carlo_simulator/presentation/glossary/glossary_screen.dart';
import 'package:monte_carlo_simulator/presentation/labs/experiment_screen.dart';
import 'package:monte_carlo_simulator/presentation/labs/lab_screen.dart';
import 'package:monte_carlo_simulator/presentation/learn/lesson_screen.dart';
import 'package:monte_carlo_simulator/presentation/learn/module_screen.dart';
import 'package:monte_carlo_simulator/presentation/practice/generated_practice_screen.dart';
import 'package:monte_carlo_simulator/presentation/practice/practice_screen.dart';
import 'package:monte_carlo_simulator/presentation/providers.dart';
import 'package:monte_carlo_simulator/presentation/widgets/common.dart';

import 'test_helpers.dart';

/// Acciones para desbloquear cada experimento: (clave del botón, veces).
const Map<String, List<(String, int)>> unlockPlan = {
  'e1_pi': [('add_1000', 1)],
  'e2_area': [('add_1000', 1)],
  'e3_seeds': [('add_500', 1)],
  'e4_lcg': [('add_300', 1)],
  'e5_inverse': [('add_500', 1)],
  'e6_discrete': [('add_500', 2)],
  'e7_npv': [('add_2000', 1)],
  'e8_capacity': [('add_1000', 1)],
  'e9_merge': [('add_1000', 1)],
  'e10_corr': [('add_1000', 1)],
  'e11_shape': [('add_1000', 1)],
  'e12_sqrt_n': [('level_100', 1), ('level_400', 1), ('level_1600', 1)],
  'e13_rare': [('rare_100', 1), ('rare_1000', 1)],
  'e14_scurve': [('add_2000', 1)],
  'e15_compare': [('add_1000', 1)],
  'e16_tornado': [('add_2000', 1)],
};

void main() {
  test('el plan de desbloqueo cubre los 16 experimentos', () {
    expect(unlockPlan.keys.toSet(), experiments.map((e) => e.id).toSet());
  });

  for (final l in lessons) {
    testWidgets('lección ${l.id} se recorre y se marca como vista', (tester) async {
      final c = await pumpApp(tester, home: LessonScreen(lessonId: l.id));
      for (var i = 0; i < l.cards.length - 1; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
      expect(c.read(progressProvider).lessonsDone, contains(l.id));
      expect(find.text('Ir al laboratorio'), findsOneWidget);
    });
  }

  for (final def in experiments) {
    testWidgets('experimento ${def.id}: predice → simula → explica', (tester) async {
      final c = await pumpApp(tester, home: ExperimentScreen(experimentId: def.id));
      expect(find.text('Hallazgo'), findsNothing);
      // Controles bloqueados hasta predecir.
      expect(find.text('Registra tu predicción para desbloquear'), findsOneWidget);
      await tester.tap(find.byType(OptionTile).first);
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).predictions.containsKey(def.id), isTrue);
      for (final (key, times) in unlockPlan[def.id]!) {
        for (var i = 0; i < times; i++) {
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('Hallazgo'), findsOneWidget);
      expect(find.textContaining('[['), findsNothing);
      expect(c.read(progressProvider).experimentsDone, contains(def.id));
    });
  }

  for (final lab in labs) {
    testWidgets('laboratorio ${lab.id} lista sus experimentos', (tester) async {
      await pumpApp(tester, home: LabScreen(labId: lab.id));
      for (final id in lab.experimentIds) {
        expect(find.text(experimentById(id).title), findsOneWidget);
      }
    });
  }

  for (final m in modules) {
    testWidgets('módulo ${m.id} y su práctica', (tester) async {
      await pumpApp(tester, home: ModuleScreen(moduleId: m.id));
      expect(find.text(lessonsOf(m.id).first.title), findsOneWidget);
      await pumpApp(tester, home: ModulePracticeScreen(moduleId: m.id));
      expect(find.byKey(const ValueKey('check_answer')), findsOneWidget);
    });
  }

  testWidgets('responder un ejercicio registra puntaje y diagnóstico', (tester) async {
    final c = await pumpApp(tester, home: const ModulePracticeScreen(moduleId: 'm1'));
    // x1_01: la alternativa C es el distractor «una corrida es la verdad».
    await tester.tap(find.byType(OptionTile).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check_answer')));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no'), findsOneWidget);
    final s = c.read(progressProvider);
    expect(s.firstTryScores['x1_01'], 0);
    expect(s.confusionScores['una_corrida_es_verdad'], 1);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OptionTile).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check_answer')));
    await tester.pumpAndSettle();
    expect(find.text('Correcto'), findsOneWidget);
    expect(c.read(progressProvider).exerciseScores['x1_01'], 1);
  });

  testWidgets('respuesta numérica con error típico reconocido', (tester) async {
    final c = await pumpApp(tester, home: const ModulePracticeScreen(moduleId: 'm1'));
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    // x1_02: escribir la desviación de un dardo en vez del error estándar.
    await tester.enterText(find.byKey(const ValueKey('numeric_answer')), '1,642');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('check_answer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('reconocida por el número'), findsOneWidget);
    expect(c.read(progressProvider).confusionScores['se_vs_sd'], 1);
  });

  for (final cs in cases) {
    testWidgets('caso ${cs.id} se muestra completo', (tester) async {
      await pumpApp(tester, home: CaseScreen(caseId: cs.id));
      expect(find.text(cs.title), findsOneWidget);
      expect(find.byKey(const ValueKey('check_answer')), findsNWidgets(cs.steps.length));
      expect(find.byKey(const ValueKey('open_case_model')), cs.model == null ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('práctica generativa, glosario y acerca de', (tester) async {
    await pumpApp(tester, home: const GeneratedPracticeScreen());
    expect(find.byKey(const ValueKey('gen_answer')), findsOneWidget);
    await pumpApp(tester, home: const GlossaryScreen());
    expect(find.text('Glosario'), findsOneWidget);
    await pumpApp(tester, home: const AboutScreen());
    expect(find.text('Borrar mi progreso'), findsOneWidget);
  });
}
