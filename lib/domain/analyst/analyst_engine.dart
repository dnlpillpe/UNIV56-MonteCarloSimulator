import 'dart:math' as math;

import '../../core/util/format.dart';
import '../sim/model_spec.dart';
import '../sim/result_summary.dart';

/// Analista de resultados determinista.
///
/// Lee una corrida y emite hallazgos con nivel y remedio. **Todo número que
/// aparece en sus textos sale de la corrida**; esos mismos números forman la
/// lista blanca con la que se verifica a la IA opcional.

enum FindingLevel { ok, info, warning, risk }

class Finding {
  const Finding({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    this.lessonId,
  });

  final String id;
  final FindingLevel level;
  final String title;
  final String body;

  /// Lección que remedia o amplía el hallazgo.
  final String? lessonId;
}

class AnalystReport {
  const AnalystReport({
    required this.summary,
    required this.headline,
    required this.findings,
    required this.allowedNumbers,
  });

  final ResultSummary summary;
  final String headline;
  final List<Finding> findings;

  /// Cifras que el motor conoce (lista blanca de la guardia numérica).
  final List<double> allowedNumbers;

  Finding? byId(String id) {
    for (final f in findings) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Hechos numéricos en formato clave → valor, para la IA.
  Map<String, Object?> factSheet() {
    final s = summary;
    final spec = s.spec;
    return {
      'modelo': spec.title,
      'formula': spec.expression,
      'salida': spec.outputName,
      'unidad': spec.outputUnit,
      'iteraciones': s.n,
      'semilla': s.run.seed,
      'media': _r(s.mean),
      'ic95_media': [_r(s.ciLow), _r(s.ciHigh)],
      'desviacion': _r(s.sd),
      'error_estandar': _r(s.se),
      'mediana': _r(s.median),
      'p5': _r(s.p(5)),
      'p10': _r(s.p(10)),
      'p90': _r(s.p(90)),
      'p95': _r(s.p(95)),
      'minimo': _r(s.min),
      'maximo': _r(s.max),
      'asimetria': _r(s.skew),
      if (spec.threshold != null) ...{
        'umbral': spec.threshold,
        'lado_riesgo': spec.side.label,
        'significado_umbral': spec.thresholdMeaning,
        'prob_umbral': _r(s.thresholdProb!),
        'ic95_prob': [_r(s.thresholdCi!.$1), _r(s.thresholdCi!.$2)],
      },
      'salida_con_entradas_en_su_media': _r(s.outputAtMeans),
      'entradas': [
        for (final i in spec.inputs) {'nombre': i.name, 'descripcion': i.description, 'distribucion': i.summary},
      ],
      'sensibilidad_spearman': {for (final x in s.sensitivities) x.name: _r(x.rho)},
      if (spec.correlation != null)
        'correlacion': '${spec.correlation!.a}–${spec.correlation!.b}: ${spec.correlation!.rho}',
    };
  }

  static double? _r(double x) => x.isFinite ? double.parse(x.toStringAsPrecision(5)) : null;
}

class AnalystEngine {
  const AnalystEngine();

  AnalystReport analyze(ResultSummary s) {
    final spec = s.spec;
    final u = spec.outputUnit.isEmpty ? '' : ' ${spec.outputUnit}';
    final nums = <double>[];
    String n(double x, {int? d}) {
      nums.add(x);
      return fmtNum(x, decimals: d);
    }

    String pct(double p, {int d = 1}) {
      nums.add(p);
      nums.add(p * 100);
      return fmtPct(p, decimals: d);
    }

    String i(int x) {
      nums.add(x.toDouble());
      return fmtInt(x);
    }

    final findings = <Finding>[];

    // 1 · Resumen
    findings.add(Finding(
      id: 'resumen',
      level: FindingLevel.info,
      title: 'Resumen de la corrida',
      body: 'Con ${i(s.n)} iteraciones (semilla ${i(s.run.seed)}), «${spec.outputName}» tiene media ${n(s.mean)}$u '
          '(IC 95 %: ${n(s.ciLow)} a ${n(s.ciHigh)}) y mediana ${n(s.median)}$u. '
          'El 80 % central de los resultados está entre ${n(s.p(10))} (P10) y ${n(s.p(90))} (P90).',
      lessonId: 'l3_1',
    ));

    // 2 · Precisión
    final rel = s.relativePrecision;
    final nearZero = s.mean.abs() < 2 * s.se;
    if (s.n < 1000) {
      findings.add(Finding(
        id: 'precision',
        level: FindingLevel.warning,
        title: 'Pocas iteraciones',
        body: 'Solo ${i(s.n)} iteraciones: la media puede moverse ±${n(s.halfWidth95)}$u y los percentiles extremos son inestables. '
            'Corre al menos 1 000 antes de interpretar colas.',
        lessonId: 'l3_3',
      ));
    } else if (!nearZero && rel > 0.02) {
      final target = 0.01 * s.mean.abs();
      findings.add(Finding(
        id: 'precision',
        level: FindingLevel.warning,
        title: 'Precisión mejorable',
        body: 'La media está estimada con ±${n(s.halfWidth95)}$u (±${pct(rel)} de su valor). '
            'Para ±1 % harían falta unas ${i(s.iterationsForMeanHalfWidth(target))} iteraciones: el error baja con √n.',
        lessonId: 'l3_3',
      ));
    } else {
      findings.add(Finding(
        id: 'precision',
        level: FindingLevel.ok,
        title: 'Precisión suficiente para la media',
        body: 'Semiamplitud del IC 95 %: ±${n(s.halfWidth95)}$u. Recuerda que esto mide la precisión respecto del modelo; '
            'la desviación de la salida (${n(s.sd)}$u) es el riesgo, y no baja con más iteraciones.',
        lessonId: 'l1_4',
      ));
    }

    // 3 · Umbral
    final t = spec.threshold;
    if (t != null) {
      final k = s.thresholdHits!;
      final p = s.thresholdProb!;
      final ci = s.thresholdCi!;
      final cond = '${spec.outputName} ${spec.side.symbol} ${n(t)}';
      final meaning = spec.thresholdMeaning.isEmpty ? 'cruzar el umbral' : spec.thresholdMeaning;
      if (k == 0) {
        findings.add(Finding(
          id: 'umbral',
          level: FindingLevel.warning,
          title: 'Ningún caso de riesgo… todavía',
          body: 'En ${i(s.n)} iteraciones nunca ocurrió $cond. Eso no prueba que sea imposible: '
              'con 95 % de confianza, P < ${pct(s.ruleOfThree, d: 2)} (regla del tres).',
          lessonId: 'l3_3',
        ));
      } else {
        final level = p >= 0.2
            ? FindingLevel.risk
            : (p >= 0.05 ? FindingLevel.warning : FindingLevel.info);
        final few = k < 20;
        final req = s.iterationsForProbHalfWidth(0.01);
        findings.add(Finding(
          id: 'umbral',
          level: level,
          title: 'Probabilidad de $meaning',
          body: 'P($cond) = ${pct(p)} (IC 95 %: ${pct(ci.$1)} a ${pct(ci.$2)}): ocurre en ${i(k)} de ${i(s.n)} iteraciones.'
              '${few ? ' Son pocos casos: la estimación es imprecisa; para ±1 punto porcentual harían falta unas ${i(req!)} iteraciones.' : ''}'
              '${s.mean.isFinite && _meanSafe(s) && p > 0.01 ? ' Ojo: la media está del lado seguro del umbral y aun así el riesgo existe.' : ''}',
          lessonId: 'l3_2',
        ));
      }
    }

    // 4 · Forma
    if (s.skew.abs() > 0.5 && s.sd > 0) {
      final below = s.cdfAt(s.mean);
      findings.add(Finding(
        id: 'forma',
        level: FindingLevel.info,
        title: s.skew > 0 ? 'Cola a la derecha' : 'Cola a la izquierda',
        body: 'La distribución es asimétrica (coeficiente ${n(s.skew, d: 2)}): la media (${n(s.mean)}) y la mediana (${n(s.median)}) se separan. '
            'El ${pct(below)} de los resultados queda por debajo de la media, así que la media no es el valor típico. Reporta percentiles.',
        lessonId: 'l3_1',
      ));
    }

    // 5 · Cola de riesgo
    if (s.sd > 0) {
      final below = spec.side == ThresholdSide.below;
      final q = below ? s.p(5) : s.p(95);
      findings.add(Finding(
        id: 'cola',
        level: FindingLevel.info,
        title: below ? 'El 5 % peor (lado bajo)' : 'El 5 % peor (lado alto)',
        body: below
            ? 'En 1 de cada 20 iteraciones la salida es menor que ${n(q)}$u (P5); cuando eso ocurre, el promedio es ${n(s.tailMean)}$u (déficit esperado).'
            : 'En 1 de cada 20 iteraciones la salida supera ${n(q)}$u (P95); cuando eso ocurre, el promedio es ${n(s.tailMean)}$u.',
        lessonId: 'l3_2',
      ));
    }

    // 6 · Falacia de los promedios
    if (s.outputAtMeans.isFinite && s.sd > 0) {
      final diff = s.mean - s.outputAtMeans;
      if (diff.abs() > math.max(3 * s.se, 0.05 * s.sd)) {
        findings.add(Finding(
          id: 'promedios',
          level: FindingLevel.warning,
          title: 'El escenario promedio no es el promedio de los escenarios',
          body: 'Con cada entrada en su media, la fórmula da ${n(s.outputAtMeans)}$u; el promedio simulado es ${n(s.mean)}$u '
              '(diferencia ${n(diff)}$u). El modelo no es lineal (mínimos, máximos, umbrales o productos): planificar con promedios sesga el resultado.',
          lessonId: 'l2_3',
        ));
      }
    }
    final hasTriangular = spec.inputs.any((x) => x.kind == DistKind.triangular);
    if (hasTriangular && s.outputAtModes.isFinite && s.sd > 0) {
      final diff = s.outputAtModes - s.mean;
      if (diff.abs() > math.max(3 * s.se, 0.1 * s.sd)) {
        findings.add(Finding(
          id: 'modas',
          level: FindingLevel.warning,
          title: 'El escenario más probable engaña',
          body: 'Con cada entrada en su valor más probable, la fórmula da ${n(s.outputAtModes)}$u, pero el promedio simulado es ${n(s.mean)}$u. '
              'Las triangulares asimétricas mueven la media lejos de la moda.',
          lessonId: 'l2_3',
        ));
      }
    }

    // 7 · Sensibilidad
    final sens = s.sensitivities.where((x) => x.rho.isFinite).toList();
    if (sens.length >= 2) {
      final total = s.totalRho2;
      final top = sens.first;
      final share = top.share(total);
      final weak = sens.where((x) => x.rho.abs() < 0.05).map((x) => x.name).toList();
      final ranking = sens.take(4).map((x) => '${x.name} (${n(x.rho, d: 2)})').join(', ');
      findings.add(Finding(
        id: 'sensibilidad',
        level: FindingLevel.info,
        title: share > 0.6 ? '«${top.name}» domina el resultado' : 'Qué entradas mueven la salida',
        body: 'Correlación de rangos con la salida: $ranking. '
            '${share > 0.6 ? '«${top.name}» concentra cerca del ${pct(share, d: 0)} de la variación explicada: reducir su incertidumbre es lo más rentable. ' : ''}'
            '${weak.isNotEmpty ? 'Apenas influyen: ${weak.join(', ')}; podrías fijarlas en su valor medio.' : ''}',
        lessonId: 'l3_4',
      ));
    }

    // 8 · Entradas normales con negativos
    for (final e in s.inputNegativeShare.entries) {
      if (e.value > 0.005) {
        findings.add(Finding(
          id: 'negativos_${e.key}',
          level: FindingLevel.warning,
          title: '«${e.key}» tomó valores negativos',
          body: 'La entrada normal «${e.key}» fue negativa en el ${pct(e.value, d: 2)} de las iteraciones. '
              'Si no puede ser negativa (precio, costo, tiempo, concentración), usa lognormal o triangular.',
          lessonId: 'l2_2',
        ));
      }
    }

    // 9 · Dependencia
    final uncertain = spec.inputs.where((x) => x.kind != DistKind.constant).length;
    if (uncertain >= 2) {
      final c = spec.correlation;
      findings.add(Finding(
        id: 'dependencia',
        level: FindingLevel.info,
        title: c == null || c.rho == 0 ? 'Supuesto: entradas independientes' : 'Correlación incluida',
        body: c == null || c.rho == 0
            ? 'Se simuló como si ninguna entrada influyera en otra. Si alguna pareja se mueve junta (inflación, clima, demanda y precio), agrégala: una correlación positiva ensancha la cola.'
            : 'Se incluyó ρ = ${n(c.rho, d: 2)} entre ${c.a} y ${c.b}. Compara con ρ = 0 para ver cuánto riesgo aporta la dependencia.',
        lessonId: 'l2_4',
      ));
    }

    // 10 · Iteraciones inválidas
    if (s.run.invalidCount > 0) {
      findings.add(Finding(
        id: 'invalidas',
        level: FindingLevel.warning,
        title: 'Iteraciones descartadas',
        body: '${i(s.run.invalidCount)} iteraciones dieron un resultado no numérico (división entre cero, raíz o logaritmo de un negativo) y se descartaron. '
            'Revisa la fórmula: puede estar sesgando el resultado.',
        lessonId: 'l3_4',
      ));
    }

    // 11 · Reproducibilidad y validez
    findings.add(Finding(
      id: 'reproducible',
      level: FindingLevel.ok,
      title: 'Reproducible y auditable',
      body: 'Generador xoshiro128**, semilla ${i(s.run.seed)}, ${i(s.n)} iteraciones: con estos datos cualquiera obtiene exactamente estos resultados. '
          'Recuerda que la precisión es respecto del modelo: valida las distribuciones y la fórmula antes de decidir.',
      lessonId: 'l1_2',
    ));

    // Lista blanca: además de lo citado, todas las cifras del resumen.
    nums.addAll([
      s.n.toDouble(), s.run.seed.toDouble(), s.mean, s.sd, s.se, s.min, s.max, s.median,
      s.ciLow, s.ciHigh, s.halfWidth95, s.skew, s.tailMean, s.outputAtMeans, s.outputAtModes,
      ...s.percentiles.values,
      for (final x in s.sensitivities) ...[x.rho, x.share(s.totalRho2), x.share(s.totalRho2) * 100],
      for (final inp in spec.inputs) ...inp.params,
      if (t != null) t,
      if (s.thresholdProb != null) ...[s.thresholdProb!, s.thresholdProb! * 100],
      if (s.thresholdCi != null) ...[s.thresholdCi!.$1, s.thresholdCi!.$2, s.thresholdCi!.$1 * 100, s.thresholdCi!.$2 * 100],
      s.ruleOfThree, s.ruleOfThree * 100,
      if (s.iterationsForProbHalfWidth(0.01) != null) s.iterationsForProbHalfWidth(0.01)!.toDouble(),
      if (s.mean != 0) s.iterationsForMeanHalfWidth(0.01 * s.mean.abs()).toDouble(),
      s.cdfAt(s.mean), s.cdfAt(s.mean) * 100,
    ]);

    return AnalystReport(
      summary: s,
      headline: _headline(s),
      findings: findings,
      allowedNumbers: nums.where((x) => x.isFinite).toList(),
    );
  }

  static bool _meanSafe(ResultSummary s) {
    final t = s.spec.threshold;
    if (t == null) return false;
    return s.spec.side == ThresholdSide.below ? s.mean > t : s.mean < t;
  }

  String _headline(ResultSummary s) {
    final spec = s.spec;
    final u = spec.outputUnit.isEmpty ? '' : ' ${spec.outputUnit}';
    final base = '${spec.outputName}: media ${fmtNum(s.mean)}$u, P10–P90 de ${fmtNum(s.p(10))} a ${fmtNum(s.p(90))}';
    if (spec.threshold != null) {
      return '$base; P(${spec.side.symbol} ${fmtNum(spec.threshold!)}) = ${fmtPct(s.thresholdProb!)}.';
    }
    return '$base.';
  }
}
