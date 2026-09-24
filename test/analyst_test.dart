import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/core/util/format.dart';
import 'package:monte_carlo_simulator/domain/analyst/analyst_engine.dart';
import 'package:monte_carlo_simulator/domain/analyst/hybrid_analyst.dart';
import 'package:monte_carlo_simulator/domain/analyst/numeric_guard.dart';
import 'package:monte_carlo_simulator/domain/analyst/question_router.dart';
import 'package:monte_carlo_simulator/domain/sim/model_spec.dart';
import 'package:monte_carlo_simulator/domain/sim/result_summary.dart';
import 'package:monte_carlo_simulator/domain/sim/simulation_engine.dart';
import 'package:monte_carlo_simulator/domain/sim/templates.dart';

AnalystReport reportFor(String id, {int n = 20000, int seed = 17}) {
  final run = const SimulationEngine().run(templateById(id), iterations: n, seed: seed);
  return const AnalystEngine().analyze(ResultSummary.of(run));
}

class FakeAi implements TextGenerator {
  FakeAi(this.reply, {this.fail = false});
  final String reply;
  final bool fail;
  @override
  String get label => 'falsa';
  @override
  Future<String> complete({required String system, required String user}) async {
    if (fail) throw Exception('sin red');
    return reply;
  }
}

void main() {
  group('Hallazgos del motor', () {
    test('proyecto: riesgo alto, modas engañosas y precio dominante', () {
      final r = reportFor('proyecto_van');
      expect(r.byId('umbral')!.level, FindingLevel.risk);
      expect(r.byId('modas'), isNotNull);
      expect(r.summary.sensitivities.first.name, 'P');
      expect(r.byId('sensibilidad')!.body, contains('P ('));
      expect(r.byId('dependencia')!.title, contains('independientes'));
      expect(r.headline, contains('VAN'));
    });

    test('capacidad: detecta la falacia de los promedios', () {
      final r = reportFor('capacidad');
      expect(r.byId('promedios'), isNotNull);
    });

    test('pocas iteraciones: advierte', () {
      final r = reportFor('proyecto_van', n: 300);
      expect(r.byId('precision')!.level, FindingLevel.warning);
      expect(r.byId('precision')!.title, contains('Pocas'));
    });

    test('cero casos: regla del tres, nunca «imposible»', () {
      final m = templateById('capacidad').copyWith(threshold: -5000);
      final run = const SimulationEngine().run(m, iterations: 5000, seed: 1);
      final r = const AnalystEngine().analyze(ResultSummary.of(run));
      final f = r.byId('umbral')!;
      expect(f.body, contains('regla del tres'));
      expect(f.body, contains(fmtPct(3 / 5000, decimals: 2)));
    });

    test('entrada normal con negativos: sugiere otra distribución', () {
      const m = ModelSpec(
        id: 'n',
        title: 'n',
        description: '',
        inputs: [InputSpec(name: 'Costo', kind: DistKind.normal, params: [100, 60])],
        expression: 'Costo',
        outputName: 'Costo',
      );
      final run = const SimulationEngine().run(m, iterations: 5000, seed: 1);
      final r = const AnalystEngine().analyze(ResultSummary.of(run));
      expect(r.byId('negativos_Costo'), isNotNull);
    });

    test('forma asimétrica: media y mediana', () {
      final r = reportFor('riesgo_ambiental');
      expect(r.byId('forma'), isNotNull);
    });

    test('la ficha de datos se puede serializar', () {
      final r = reportFor('costos_correlacionados');
      expect(r.factSheet()['iteraciones'], 20000);
      expect(r.factSheet().containsKey('correlacion'), isTrue);
    });
  });

  group('Router de preguntas', () {
    final r = reportFor('proyecto_van');
    const router = QuestionRouter();

    test('intenciones', () {
      expect(router.answer('¿Cuál es el riesgo de perder?', r).intent, 'riesgo');
      expect(router.answer('¿Son suficientes las iteraciones?', r).intent, 'precision');
      expect(router.answer('¿Qué entrada influye más?', r).intent, 'sensibilidad');
      expect(router.answer('¿Qué significa el P90?', r).intent, 'percentil');
      expect(router.answer('¿Qué me recomiendas decidir?', r).intent, 'decision');
      expect(router.answer('¿Puedo confiar en esto?', r).intent, 'confianza');
      expect(router.answer('¿Cuál es la capital de Francia?', r).intent, 'fuera_de_alcance');
    });

    test('la decisión no se toma por el estudiante', () {
      expect(router.answer('¿Conviene invertir?', r).text, contains('No decido por ti'));
    });

    test('todas las cifras del motor pasan su propia guardia', () {
      const guard = NumericGuard();
      for (final q in suggestedQuestions) {
        final a = router.answer(q, r);
        final g = guard.check(a.text, r.allowedNumbers);
        expect(g.ok, isTrue, reason: '$q → ${g.unknownNumbers}');
      }
      for (final f in r.findings) {
        final g = guard.check(f.body, r.allowedNumbers);
        expect(g.ok, isTrue, reason: '${f.id} → ${g.unknownNumbers}');
      }
    });
  });

  group('Guardia numérica', () {
    const guard = NumericGuard();
    test('extrae números en formato español e inglés', () {
      expect(NumericGuard.extract('media 1 234,5 y 37,8 % con n = 10 000; P90'), ['1 234,5', '10 000', '37,8']);
      expect(NumericGuard.candidates('1.234'), containsAll([1.234, 1234]));
      expect(NumericGuard.candidates('3,16'), [3.16]);
    });

    test('acepta cifras conocidas y rechaza inventadas', () {
      expect(guard.check('La probabilidad es 37,8 %.', [0.378]).ok, isTrue);
      expect(guard.check('La media es 47 y el P5 es −181.', [47.01, -181.4]).ok, isTrue);
      expect(guard.check('La probabilidad es 42 %.', [0.378]).ok, isFalse);
    });
  });

  group('Analista híbrido', () {
    final r = reportFor('proyecto_van');
    const analyst = HybridAnalyst();

    test('sin IA responde el motor', () async {
      final a = await analyst.answer('¿Cuál es el riesgo?', r);
      expect(a.source, AnswerSource.engine);
    });

    test('IA con cifras verificadas se acepta', () async {
      final p = fmtPct(r.summary.thresholdProb!);
      final a = await analyst.answer('¿Cuál es el riesgo?', r, ai: FakeAi('Perder dinero ocurre en el $p de las iteraciones. ¿Qué riesgo tolerarías?'));
      expect(a.source, AnswerSource.ai);
    });

    test('IA que inventa una cifra se descarta', () async {
      final a = await analyst.answer('¿Cuál es el riesgo?', r, ai: FakeAi('El riesgo es del 91,7 % según mis cálculos.'));
      expect(a.source, AnswerSource.engineFallback);
      expect(a.note, contains('91,7'));
    });

    test('sin conexión responde el motor', () async {
      final a = await analyst.answer('¿Cuál es el riesgo?', r, ai: FakeAi('', fail: true));
      expect(a.source, AnswerSource.engineFallback);
    });
  });
}
