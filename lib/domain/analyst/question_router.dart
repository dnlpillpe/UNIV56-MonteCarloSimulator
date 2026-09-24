import '../../core/util/format.dart';
import '../sim/model_spec.dart';
import 'analyst_engine.dart';

/// Responde preguntas en lenguaje natural sobre una corrida usando solo los
/// hallazgos del motor. Si la pregunta no se puede responder con la
/// corrida, lo dice (umbral de honestidad) en vez de improvisar.

class RoutedAnswer {
  const RoutedAnswer(this.intent, this.text, {this.lessonId});
  final String intent;
  final String text;
  final String? lessonId;
}

/// Preguntas sugeridas en la interfaz.
const List<String> suggestedQuestions = [
  '¿Cuál es el riesgo?',
  '¿Son suficientes las iteraciones?',
  '¿Qué entrada influye más?',
  '¿Por qué la media no coincide con el caso base?',
  '¿Qué significa el P90?',
  '¿Puedo confiar en este resultado?',
  '¿Qué decisión recomiendas?',
];

String _norm(String s) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ¿?¡!';
  const to = 'aeiouunAEIOUUN    ';
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final k = from.indexOf(ch);
    buf.write(k >= 0 ? to[k] : ch);
  }
  return buf.toString().toLowerCase();
}

class _Intent {
  const _Intent(this.id, this.keywords);
  final String id;
  final List<String> keywords;
}

const List<_Intent> _intents = [
  _Intent('decision', ['recomiend', 'conviene', 'decid', 'deberia', 'invertir', 'acepto', 'elegir', 'mejor opcion']),
  _Intent('precision', ['iteracion', 'suficiente', 'precision', 'cuantas', 'error estandar', 'ic ', 'intervalo', 'converg']),
  _Intent('riesgo', ['riesgo', 'perder', 'perdida', 'probabilidad', 'umbral', 'superar', 'atras', 'exceder', 'cumplir']),
  _Intent('percentil', ['p90', 'p10', 'p95', 'p5', 'percentil', 'curva s', 'cuantil']),
  _Intent('promedios', ['caso base', 'promedio', 'coincide', 'escenario', 'mas probable', 'falacia', 'determinist']),
  _Intent('sensibilidad', ['influye', 'sensibil', 'importa', 'tornado', 'entrada', 'variable', 'manda', 'pesa']),
  _Intent('forma', ['forma', 'asimetr', 'mediana', 'sesgo', 'cola', 'histograma', 'tipico']),
  _Intent('confianza', ['confiar', 'fiable', 'valido', 'validez', 'correcto', 'seguro que', 'realidad']),
  _Intent('dependencia', ['correlacion', 'dependencia', 'independ', 'juntas', 'juntos']),
  _Intent('semilla', ['semilla', 'reproduc', 'repetir', 'mismo resultado', 'generador']),
  _Intent('media', ['media', 'esperado', 'valor esperado']),
];

class QuestionRouter {
  const QuestionRouter();

  RoutedAnswer answer(String question, AnalystReport r) {
    final q = _norm(question);
    for (final intent in _intents) {
      if (intent.keywords.any(q.contains)) {
        final a = _answerFor(intent.id, r);
        if (a != null) return a;
      }
    }
    return RoutedAnswer(
      'fuera_de_alcance',
      'No puedo responder eso con los resultados de esta corrida sin inventar. Puedo explicarte el riesgo, la precisión, '
          'qué entrada manda, por qué la media difiere del caso base, cómo leer los percentiles o qué supuestos revisar.',
    );
  }

  RoutedAnswer? _answerFor(String intent, AnalystReport r) {
    final s = r.summary;
    final spec = s.spec;
    String body(String id) => r.byId(id)?.body ?? '';
    switch (intent) {
      case 'precision':
        return RoutedAnswer(intent, '${body('precision')} ${_precisionTip(r)}', lessonId: 'l3_3');
      case 'riesgo':
        {
          final f = r.byId('umbral');
          if (f == null) {
            return RoutedAnswer(intent,
                'Este modelo no tiene umbral de riesgo definido. Define uno (por ejemplo, VAN < 0) para estimar su probabilidad. Mientras tanto: ${body('cola')}',
                lessonId: 'l3_2');
          }
          return RoutedAnswer(intent, '${f.body} ${body('cola')}', lessonId: 'l3_2');
        }
      case 'percentil':
        return RoutedAnswer(
          intent,
          'P10 = ${fmtNum(s.p(10))}, P50 (mediana) = ${fmtNum(s.median)}, P90 = ${fmtNum(s.p(90))}. '
          'Se leen así: el 90 % de las iteraciones dio ${fmtNum(s.p(90))} o menos; solo 1 de cada 10 lo superó. '
          'No es «90 % de probabilidad de superarlo».',
          lessonId: 'l3_1',
        );
      case 'promedios':
        {
          final parts = [body('promedios'), body('modas')].where((x) => x.isNotEmpty).toList();
          if (parts.isEmpty) {
            return RoutedAnswer(
              intent,
              'Aquí el escenario promedio da ${fmtNum(s.outputAtMeans)} y el promedio simulado ${fmtNum(s.mean)}: la diferencia es pequeña frente al error de la simulación, '
              'así que el modelo se comporta casi linealmente. Aun así, el promedio no dice nada del riesgo: mira la dispersión y los percentiles.',
              lessonId: 'l2_3',
            );
          }
          return RoutedAnswer(intent, parts.join(' '), lessonId: 'l2_3');
        }
      case 'sensibilidad':
        {
          final f = r.byId('sensibilidad');
          if (f == null) {
            return RoutedAnswer(intent, 'Solo hay una entrada incierta: toda la variación viene de ella.', lessonId: 'l3_4');
          }
          return RoutedAnswer(intent, f.body, lessonId: 'l3_4');
        }
      case 'forma':
        {
          final f = r.byId('forma');
          return RoutedAnswer(
            intent,
            f?.body ??
                'La distribución es aproximadamente simétrica: media (${fmtNum(s.mean)}) y mediana (${fmtNum(s.median)}) casi coinciden. '
                    'Aun así, reporta un rango de percentiles, no solo la media.',
            lessonId: 'l3_1',
          );
        }
      case 'confianza':
        return RoutedAnswer(
          intent,
          '${body('precision')} Pero precisión no es validez: el resultado es tan bueno como el modelo. Revisa que '
          'las distribuciones de entrada tengan la forma correcta, que la fórmula esté verificada con valores conocidos y que el supuesto de dependencia sea razonable.'
          '${r.findings.any((f) => f.id.startsWith('negativos_')) ? ' Hay entradas normales que tomaron valores negativos: revísalas.' : ''}',
          lessonId: 'l3_4',
        );
      case 'dependencia':
        return RoutedAnswer(intent, body('dependencia').isEmpty ? 'Solo hay una entrada incierta: no hay dependencias que modelar.' : body('dependencia'), lessonId: 'l2_4');
      case 'semilla':
        return RoutedAnswer(intent, body('reproducible'), lessonId: 'l1_2');
      case 'media':
        return RoutedAnswer(intent, '${body('resumen')} ${body('forma')}'.trim(), lessonId: 'l3_1');
      case 'decision':
        {
          final risk = r.byId('umbral');
          final threshold = spec.threshold;
          final riskLine = risk == null || threshold == null
              ? ''
              : 'El dato clave es la probabilidad de ${spec.thresholdMeaning.isEmpty ? 'cruzar el umbral' : spec.thresholdMeaning}: ${fmtPct(s.thresholdProb!)}. ';
          return RoutedAnswer(
            intent,
            'No decido por ti: la simulación muestra el intercambio y el criterio lo pones tú. $riskLine'
            'Pregúntate: ¿qué probabilidad de ${spec.thresholdMeaning.isEmpty ? 'un mal resultado' : spec.thresholdMeaning} es aceptable para quien decide? '
            '¿El P${spec.side == ThresholdSide.below ? '5' : '95'} (${fmtNum(spec.side == ThresholdSide.below ? s.p(5) : s.p(95))}) es tolerable? '
            'Si la respuesta depende de una entrada dominante, reducir su incertidumbre antes de decidir puede valer más que decidir ya.',
            lessonId: 'l3_2',
          );
        }
    }
    return null;
  }

  String _precisionTip(AnalystReport r) {
    final s = r.summary;
    final req = s.iterationsForProbHalfWidth(0.01);
    if (req == null) return '';
    return 'Para estimar la probabilidad del umbral con ±1 punto porcentual se necesitan unas ${fmtInt(req)} iteraciones.';
  }
}
