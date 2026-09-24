import 'dart:convert';

import 'analyst_engine.dart';
import 'numeric_guard.dart';
import 'question_router.dart';

/// Proveedor de IA generativa opcional (implementado en data/).
abstract class TextGenerator {
  String get label;
  Future<String> complete({required String system, required String user});
}

enum AnswerSource { engine, ai, engineFallback }

class AnalystAnswer {
  const AnalystAnswer({required this.text, required this.source, this.note, this.lessonId});
  final String text;
  final AnswerSource source;

  /// Explicación de por qué se usó el motor en lugar de la IA.
  final String? note;
  final String? lessonId;
}

const String analystSystemPrompt = '''
Eres el «Analista de resultados» de una app universitaria de simulación Monte Carlo.
Hablas en español, con claridad y en máximo 170 palabras.
Reglas estrictas:
1. NO calcules nada. Usa solo las cifras del JSON y de la respuesta del motor, tal como aparecen.
2. Si una cifra no está en los datos, no la escribas. No inventes porcentajes, promedios ni iteraciones.
3. No tomes la decisión por el estudiante: explica el intercambio entre media y riesgo y qué criterio falta.
4. Distingue precisión (error estándar, iteraciones) de riesgo (dispersión, percentiles, probabilidad del umbral).
5. Si la pregunta no se puede responder con los datos, dilo y sugiere qué simular.
6. Termina con una pregunta breve que haga pensar al estudiante.
''';

/// Analista híbrido: el motor responde siempre; la IA, si está configurada,
/// redacta sobre la respuesta del motor y pasa por la guardia numérica.
class HybridAnalyst {
  const HybridAnalyst({this.router = const QuestionRouter(), this.guard = const NumericGuard()});

  final QuestionRouter router;
  final NumericGuard guard;

  Future<AnalystAnswer> answer(String question, AnalystReport report, {TextGenerator? ai}) async {
    final base = router.answer(question, report);
    if (ai == null) {
      return AnalystAnswer(text: base.text, source: AnswerSource.engine, lessonId: base.lessonId);
    }
    final payload = const JsonEncoder.withIndent(' ').convert({
      'pregunta': question,
      'datos': report.factSheet(),
      'hallazgos': [for (final f in report.findings) '${f.title}: ${f.body}'],
      'respuesta_del_motor': base.text,
    });
    try {
      final text = (await ai.complete(system: analystSystemPrompt, user: payload)).trim();
      if (text.isEmpty) {
        return AnalystAnswer(
          text: base.text,
          source: AnswerSource.engineFallback,
          note: 'La IA no respondió; se muestra la respuesta del motor.',
          lessonId: base.lessonId,
        );
      }
      final g = guard.check(text, [...report.allowedNumbers, ..._numbersIn(question)]);
      if (!g.ok) {
        return AnalystAnswer(
          text: base.text,
          source: AnswerSource.engineFallback,
          note: 'La IA escribió cifras que el motor no calculó (${g.unknownNumbers.take(3).join(', ')}); se descartó su respuesta.',
          lessonId: base.lessonId,
        );
      }
      return AnalystAnswer(text: text, source: AnswerSource.ai, lessonId: base.lessonId);
    } catch (e) {
      return AnalystAnswer(
        text: base.text,
        source: AnswerSource.engineFallback,
        note: 'Sin conexión con la IA (${_short(e)}); responde el motor.',
        lessonId: base.lessonId,
      );
    }
  }

  static List<double> _numbersIn(String text) => [
        for (final raw in NumericGuard.extract(text)) ...NumericGuard.candidates(raw),
      ];

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
}
