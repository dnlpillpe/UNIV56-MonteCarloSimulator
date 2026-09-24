import '../../core/math/distributions.dart';
import '../../core/util/format.dart';

/// Tipos de distribución que el estudiante puede elegir en el simulador.
enum DistKind {
  constant('Constante', ['Valor']),
  uniform('Uniforme', ['Mínimo', 'Máximo']),
  triangular('Triangular', ['Mínimo', 'Más probable', 'Máximo']),
  normal('Normal', ['Media', 'Desviación']),
  lognormal('Lognormal', ['Media', 'Desviación']),
  exponential('Exponencial', ['Media']),
  bernoulli('Bernoulli', ['Probabilidad']);

  const DistKind(this.label, this.paramNames);
  final String label;
  final List<String> paramNames;

  /// Cuándo usarla: se muestra en el editor de entradas.
  String get hint => switch (this) {
        DistKind.constant => 'Un valor que no es incierto (inversión, capacidad, precio fijado).',
        DistKind.uniform => 'Solo conoces el rango y ningún valor es más creíble que otro.',
        DistKind.triangular => 'Un experto da mínimo, más probable y máximo. Muy usada en proyectos.',
        DistKind.normal => 'Errores y sumas de muchos efectos pequeños. Puede dar valores negativos.',
        DistKind.lognormal => 'Magnitudes positivas con cola a la derecha: costos, leyes, concentraciones.',
        DistKind.exponential => 'Tiempo hasta un evento que ocurre al azar a ritmo constante.',
        DistKind.bernoulli => 'Ocurre (1) o no ocurre (0): una falla, un evento, un acierto.',
      };
}

/// Una variable de entrada incierta del modelo.
class InputSpec {
  const InputSpec({
    required this.name,
    required this.kind,
    required this.params,
    this.description = '',
    this.unit = '',
  });

  final String name;
  final DistKind kind;
  final List<double> params;
  final String description;
  final String unit;

  /// Mensaje de error si los parámetros no son válidos; null si todo bien.
  String? validate() {
    if (params.length != kind.paramNames.length) {
      return 'Faltan parámetros para ${kind.label}.';
    }
    for (final p in params) {
      if (p.isNaN || p.isInfinite) return 'Hay un parámetro vacío o inválido.';
    }
    switch (kind) {
      case DistKind.constant:
        return null;
      case DistKind.uniform:
        return params[0] < params[1] ? null : 'El mínimo debe ser menor que el máximo.';
      case DistKind.triangular:
        if (!(params[0] < params[2])) return 'El mínimo debe ser menor que el máximo.';
        if (params[1] < params[0] || params[1] > params[2]) {
          return 'El valor más probable debe estar entre el mínimo y el máximo.';
        }
        return null;
      case DistKind.normal:
        return params[1] > 0 ? null : 'La desviación debe ser positiva.';
      case DistKind.lognormal:
        if (params[0] <= 0) return 'La media de una lognormal debe ser positiva.';
        return params[1] > 0 ? null : 'La desviación debe ser positiva.';
      case DistKind.exponential:
        return params[0] > 0 ? null : 'La media debe ser positiva.';
      case DistKind.bernoulli:
        return (params[0] >= 0 && params[0] <= 1)
            ? null
            : 'La probabilidad debe estar entre 0 y 1.';
    }
  }

  Distribution build() => switch (kind) {
        DistKind.constant => ConstantDist(params[0]),
        DistKind.uniform => UniformDist(params[0], params[1]),
        DistKind.triangular => TriangularDist(params[0], params[1], params[2]),
        DistKind.normal => NormalDist(params[0], params[1]),
        DistKind.lognormal => LogNormalDist.fromMeanSd(params[0], params[1]),
        DistKind.exponential => ExponentialDist(params[0]),
        DistKind.bernoulli => BernoulliDist(params[0]),
      };

  String get summary {
    final ps = params.map((p) => fmtNum(p)).join('; ');
    return '${kind.label}($ps)';
  }

  InputSpec copyWith({
    String? name,
    DistKind? kind,
    List<double>? params,
    String? description,
    String? unit,
  }) =>
      InputSpec(
        name: name ?? this.name,
        kind: kind ?? this.kind,
        params: params ?? this.params,
        description: description ?? this.description,
        unit: unit ?? this.unit,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'kind': kind.name,
        'params': params,
        'description': description,
        'unit': unit,
      };

  static InputSpec fromJson(Map<String, dynamic> j) => InputSpec(
        name: j['name'] as String,
        kind: DistKind.values.byName(j['kind'] as String),
        params: (j['params'] as List).map((e) => (e as num).toDouble()).toList(),
        description: (j['description'] as String?) ?? '',
        unit: (j['unit'] as String?) ?? '',
      );

  /// Parámetros por defecto al cambiar de distribución (conservando la
  /// escala de lo que ya había escrito el estudiante).
  static List<double> defaultParams(DistKind kind, double center) {
    final c = center == 0 ? 10.0 : center.abs();
    return switch (kind) {
      DistKind.constant => [center],
      DistKind.uniform => [c * 0.8, c * 1.2],
      DistKind.triangular => [c * 0.8, c, c * 1.3],
      DistKind.normal => [c, c * 0.1],
      DistKind.lognormal => [c, c * 0.3],
      DistKind.exponential => [c],
      DistKind.bernoulli => [0.1],
    };
  }
}

/// Correlación entre dos entradas (cópula gaussiana, coeficiente ρ).
class CorrelationSpec {
  const CorrelationSpec(this.a, this.b, this.rho);
  final String a;
  final String b;
  final double rho;

  Map<String, Object?> toJson() => {'a': a, 'b': b, 'rho': rho};
  static CorrelationSpec fromJson(Map<String, dynamic> j) => CorrelationSpec(
        j['a'] as String,
        j['b'] as String,
        (j['rho'] as num).toDouble(),
      );
}

/// Lado del umbral que interesa medir.
enum ThresholdSide {
  below('menor que', '<'),
  above('mayor que', '>');

  const ThresholdSide(this.label, this.symbol);
  final String label;
  final String symbol;
}

/// Un modelo de simulación completo: entradas inciertas + fórmula de salida.
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.inputs,
    required this.expression,
    required this.outputName,
    this.outputUnit = '',
    this.threshold,
    this.side = ThresholdSide.below,
    this.thresholdMeaning = '',
    this.correlation,
    this.career = '',
  });

  final String id;
  final String title;
  final String description;
  final List<InputSpec> inputs;
  final String expression;
  final String outputName;
  final String outputUnit;

  /// Umbral de interés (p. ej. VAN = 0) y el lado que representa el riesgo.
  final double? threshold;
  final ThresholdSide side;

  /// Qué significa cruzar el umbral, p. ej. «perder dinero».
  final String thresholdMeaning;
  final CorrelationSpec? correlation;
  final String career;

  List<String> get variableNames => [for (final i in inputs) i.name];

  ModelSpec copyWith({
    String? title,
    String? description,
    List<InputSpec>? inputs,
    String? expression,
    String? outputName,
    String? outputUnit,
    double? threshold,
    bool clearThreshold = false,
    ThresholdSide? side,
    String? thresholdMeaning,
    CorrelationSpec? correlation,
    bool clearCorrelation = false,
  }) =>
      ModelSpec(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        inputs: inputs ?? this.inputs,
        expression: expression ?? this.expression,
        outputName: outputName ?? this.outputName,
        outputUnit: outputUnit ?? this.outputUnit,
        threshold: clearThreshold ? null : (threshold ?? this.threshold),
        side: side ?? this.side,
        thresholdMeaning: thresholdMeaning ?? this.thresholdMeaning,
        correlation: clearCorrelation ? null : (correlation ?? this.correlation),
        career: career,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'inputs': [for (final i in inputs) i.toJson()],
        'expression': expression,
        'outputName': outputName,
        'outputUnit': outputUnit,
        'threshold': threshold,
        'side': side.name,
        'thresholdMeaning': thresholdMeaning,
        'correlation': correlation?.toJson(),
        'career': career,
      };

  static ModelSpec fromJson(Map<String, dynamic> j) => ModelSpec(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        inputs: [
          for (final e in (j['inputs'] as List))
            InputSpec.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        expression: j['expression'] as String,
        outputName: (j['outputName'] as String?) ?? 'Salida',
        outputUnit: (j['outputUnit'] as String?) ?? '',
        threshold: (j['threshold'] as num?)?.toDouble(),
        side: ThresholdSide.values.byName((j['side'] as String?) ?? 'below'),
        thresholdMeaning: (j['thresholdMeaning'] as String?) ?? '',
        correlation: j['correlation'] == null
            ? null
            : CorrelationSpec.fromJson(
                Map<String, dynamic>.from(j['correlation'] as Map)),
        career: (j['career'] as String?) ?? '',
      );
}
