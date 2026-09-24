import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/core/math/stats.dart';
import 'package:monte_carlo_simulator/domain/content/cases.dart';
import 'package:monte_carlo_simulator/domain/content/figures.dart';
import 'package:monte_carlo_simulator/domain/sim/expression.dart';
import 'package:monte_carlo_simulator/domain/sim/model_spec.dart';
import 'package:monte_carlo_simulator/domain/sim/result_summary.dart';
import 'package:monte_carlo_simulator/domain/sim/simulation_engine.dart';
import 'package:monte_carlo_simulator/domain/sim/templates.dart';

double ev(String src, [Map<String, double> vars = const {}]) {
  final names = vars.keys.toList();
  final c = compileExpression(src, names);
  return c.evaluate([for (final n in names) vars[n]!]);
}

void main() {
  group('Lenguaje de fórmulas', () {
    test('aritmética, precedencia y potencia asociativa a la derecha', () {
      expect(ev('1 + 2 * 3'), 7);
      expect(ev('(1 + 2) * 3'), 9);
      expect(ev('2 ^ 3 ^ 2'), 512);
      expect(ev('-2 ^ 2'), -4);
      expect(ev('10 / 4'), 2.5);
      expect(ev('1.5e2'), 150);
    });

    test('variables, funciones y comparaciones', () {
      expect(ev('min(D; C)', {'D': 120, 'C': 100}), 100);
      expect(ev('max(A, B, C)', {'A': 1, 'B': 7, 'C': 3}), 7);
      expect(ev('pos(q - D)', {'q': 70, 'D': 80}), 0);
      expect(ev('4 * (U^2 + V^2 <= 1)', {'U': 0.3, 'V': 0.4}), 4);
      expect(ev('si(x > 0; 1; -1)', {'x': -3}), -1);
      expect(ev('abs(-3) + sqrt(16) + round(2.6)'), 10);
      expect(ev('ln(exp(2))'), closeTo(2, 1e-12));
      expect(ev('anualidad(0.10; 5)'), closeTo(3.790786769408448, 1e-12));
      expect(ev('pi'), math.pi);
    });

    test('errores claros', () {
      expect(() => compileExpression('A + ', ['A']), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('A + Z', ['A']), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('min()', []), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('foo(1)', []), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('(1 + 2', []), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('', []), throwsA(isA<ExpressionError>()));
      expect(() => compileExpression('1 # 2', []), throwsA(isA<ExpressionError>()));
    });

    test('nombres de variables', () {
      expect(isValidVariableName('X1'), isTrue);
      expect(isValidVariableName('costo_total'), isTrue);
      expect(isValidVariableName('1X'), isFalse);
      expect(isValidVariableName('año'), isFalse);
      expect(isValidVariableName('min'), isFalse);
    });
  });

  group('Motor de simulación', () {
    const engine = SimulationEngine();

    test('todas las plantillas y modelos de casos compilan y corren', () {
      final all = [...modelTemplates, for (final c in cases) if (c.model != null) c.model!];
      for (final m in all) {
        final run = engine.run(m, iterations: 2000, seed: 3);
        expect(run.n, 2000, reason: m.id);
        expect(run.invalidCount, 0, reason: m.id);
        final s = ResultSummary.of(run);
        expect(s.mean.isFinite, isTrue, reason: m.id);
      }
    });

    test('misma semilla, mismo resultado; otra semilla, otro', () {
      final m = templateById('proyecto_van');
      final a = engine.run(m, iterations: 500, seed: 1);
      final b = engine.run(m, iterations: 500, seed: 1);
      final c = engine.run(m, iterations: 500, seed: 2);
      expect(a.outputs, b.outputs);
      expect(a.outputs, isNot(c.outputs));
    });

    test('una corrida más larga extiende a la corta (prefijo idéntico)', () {
      final m = templateById('capacidad');
      final a = engine.run(m, iterations: 300, seed: 8);
      final b = engine.run(m, iterations: 900, seed: 8);
      expect(b.outputs.sublist(0, 300), a.outputs);
    });

    test('π con dardos converge dentro del error estándar', () {
      final s = ResultSummary.of(engine.run(templateById('estimar_pi'), iterations: 100000, seed: 42));
      expect(s.mean, closeTo(math.pi, 4 * figureValue('pi_se_coef') / math.sqrt(100000)));
    });

    test('proyecto: media y P(VAN < 0) coinciden con las cifras cerradas', () {
      final s = ResultSummary.of(engine.run(templateById('proyecto_van'), iterations: 100000, seed: 11));
      expect(s.mean, closeTo(figureValue('npv_mean'), 4 * s.se));
      final p = figureValue('npv_ploss');
      expect(s.thresholdProb!, closeTo(p, 4 * math.sqrt(p * (1 - p) / 100000)));
      expect(s.outputAtModes, closeTo(figureValue('npv_mode'), 1e-9));
      expect(s.sensitivities.first.name, 'P');
    });

    test('capacidad: falacia de los promedios', () {
      final s = ResultSummary.of(engine.run(templateById('capacidad'), iterations: 100000, seed: 5));
      expect(s.outputAtMeans, closeTo(figureValue('cap_profit_plan'), 1e-9));
      expect(s.mean, closeTo(figureValue('cap_profit_expected'), 4 * s.se));
    });

    test('correlación: el P95 del total crece con ρ', () {
      final base = templateById('costos_correlacionados');
      final indep = base.copyWith(clearCorrelation: true);
      final corr = base.copyWith(correlation: const CorrelationSpec('X1', 'X2', 0.8));
      final s0 = ResultSummary.of(engine.run(indep, iterations: 60000, seed: 4));
      final s8 = ResultSummary.of(engine.run(corr, iterations: 60000, seed: 4));
      expect(s0.sd, closeTo(figureValue('corr_sd_0'), 0.5));
      expect(s8.sd, closeTo(figureValue('corr_sd_08'), 0.6));
      expect(s8.p(95), greaterThan(s0.p(95) + 10));
      // Las marginales se conservan con la cópula.
      final x2 = ResultSummary.of(engine.run(corr, iterations: 60000, seed: 4)).run.inputs[1];
      expect(mean(x2), closeTo(100, 0.5));
      expect(stdDev(x2), closeTo(20, 0.4));
    });

    test('tareas en paralelo: probabilidad de cumplir', () {
      final s = ResultSummary.of(engine.run(templateById('plazo_paralelo'), iterations: 80000, seed: 6));
      final pTwo = figureValue('merge_p_two');
      expect(1 - s.thresholdProb!, closeTo(pTwo, 4 * math.sqrt(pTwo * (1 - pTwo) / 80000)));
      expect(s.mean, closeTo(figureValue('merge_mean_total'), 4 * s.se));
    });

    test('caso ambiental: parámetros del modelo coinciden con las cifras', () {
      final m = caseById('c_ambiental')!.model!;
      expect(m.inputs.first.params[0], closeTo(figureValue('amb_mean'), 1e-9));
      expect(m.inputs.first.params[1], closeTo(figureValue('amb_model_sd'), 1e-9));
      final s = ResultSummary.of(engine.run(m, iterations: 80000, seed: 9));
      final p = figureValue('amb_p_exceed');
      expect(s.thresholdProb!, closeTo(p, 4 * math.sqrt(p * (1 - p) / 80000)));
    });

    test('caso de psicología: aprobar adivinando (20 Bernoulli)', () {
      final s = ResultSummary.of(engine.run(caseById('c_psicologia')!.model!, iterations: 60000, seed: 12));
      final p = figureValue('psi_p10');
      expect(s.thresholdProb!, closeTo(p, 5 * math.sqrt(p * (1 - p) / 60000)));
      expect(s.mean, closeTo(5, 0.05));
    });

    test('errores de modelo', () {
      const bad = ModelSpec(
        id: 'x',
        title: 'x',
        description: '',
        inputs: [InputSpec(name: 'A', kind: DistKind.uniform, params: [5, 1])],
        expression: 'A',
        outputName: 'Y',
      );
      expect(() => engine.run(bad, iterations: 10, seed: 1), throwsA(isA<ModelError>()));
      const dup = ModelSpec(
        id: 'x',
        title: 'x',
        description: '',
        inputs: [
          InputSpec(name: 'A', kind: DistKind.constant, params: [1]),
          InputSpec(name: 'A', kind: DistKind.constant, params: [2]),
        ],
        expression: 'A',
        outputName: 'Y',
      );
      expect(() => engine.run(dup, iterations: 10, seed: 1), throwsA(isA<ModelError>()));
    });

    test('iteraciones inválidas se descartan y se informan', () {
      const m = ModelSpec(
        id: 'x',
        title: 'x',
        description: '',
        inputs: [InputSpec(name: 'X', kind: DistKind.normal, params: [0, 1])],
        expression: 'ln(X)',
        outputName: 'Y',
      );
      final run = engine.run(m, iterations: 2000, seed: 1);
      expect(run.invalidCount, greaterThan(800));
      expect(run.n + run.invalidCount, 2000);
    });

    test('resumen: iteraciones necesarias y regla del tres', () {
      final s = ResultSummary.of(engine.run(templateById('proyecto_van'), iterations: 10000, seed: 2));
      final need = s.iterationsForMeanHalfWidth(s.halfWidth95 / 2);
      expect(need / 10000, closeTo(4, 0.05)); // mitad de error → 4× iteraciones
      expect(s.ruleOfThree, closeTo(3 / 10000, 1e-15));
      expect(s.cdfAt(s.median), closeTo(0.5, 0.01));
    });

    test('ModelSpec se serializa y deserializa', () {
      for (final m in modelTemplates) {
        final back = ModelSpec.fromJson(Map<String, dynamic>.from(m.toJson()));
        expect(back.expression, m.expression);
        expect(back.inputs.length, m.inputs.length);
        expect(back.threshold, m.threshold);
        expect(back.correlation?.rho, m.correlation?.rho);
      }
    });
  });
}
