import '../models/content_models.dart';
import '../sim/model_spec.dart';

/// Casos profesionales: 11 carreras, 3 pasos evaluados cada uno. Cuando el
/// modelo es expresable, el caso se abre en el simulador con un toque.

List<InputSpec> _series(String prefix, int count, DistKind kind, List<double> params, String description) => [
      for (var i = 1; i <= count; i++)
        InputSpec(name: '$prefix$i', kind: kind, params: params, description: '$description $i'),
    ];

String _sumOf(String prefix, int count) => [for (var i = 1; i <= count; i++) '$prefix$i'].join(' + ');

final List<CaseStudy> cases = [
  // ----------------------------------------------------------- Minas
  const CaseStudy(
    id: 'c_minas',
    career: 'Ingeniería de Minas',
    title: '¿Mineral o desmonte?',
    context: 'La ley de cobre de los bloques de un banco tiene media 0,8 % y desviación 0,4 % según los sondajes. '
        'Un bloque con ley menor a 0,5 % (ley de corte) va a desmonte. Planificación quiere saber qué fracción del banco no pagará el proceso.',
    model: ModelSpec(
      id: 'case_minas',
      title: 'Ley de un bloque',
      description: 'Ley de cobre (%) lognormal con media 0,8 y desviación 0,4. Umbral: ley de corte 0,5 %.',
      inputs: [InputSpec(name: 'g', kind: DistKind.lognormal, params: [0.8, 0.4], description: 'Ley de cobre', unit: '% Cu')],
      expression: 'g',
      outputName: 'Ley del bloque',
      outputUnit: '% Cu',
      threshold: 0.5,
      side: ThresholdSide.below,
      thresholdMeaning: 'quedar bajo la ley de corte (desmonte)',
      career: 'Minas',
    ),
    steps: [
      Exercise(
        id: 'c_minas_1',
        moduleId: 'cases',
        type: ExerciseType.decision,
        prompt: '¿Qué distribución usas para la ley de cada bloque?',
        options: [
          Option('Normal(0,8; 0,4)', feedback: 'Daría leyes negativas el {{min_normal_neg}} de las veces.', confusion: 'normal_para_todo'),
          Option('Lognormal con media 0,8 y desviación 0,4', correct: true, feedback: 'Correcto.'),
        ],
        justifications: [
          Option('La ley es positiva y tiene cola derecha (bloques muy ricos, pocos)', correct: true, feedback: 'Forma y soporte: la razón que se transfiere.'),
          Option('La lognormal da leyes más altas, lo que favorece al proyecto', feedback: 'Con la misma media, la elección no «favorece» a nadie: describe mejor la forma.', confusion: 'acertar_sin_entender'),
        ],
        explanation: 'Las leyes minerales son el ejemplo clásico de variable lognormal: positivas y con unos pocos valores muy altos.',
        targets: ['normal_para_todo'],
      ),
      Exercise(
        id: 'c_minas_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: 'Simula (o calcula) la fracción de bloques con ley menor a 0,5 %, en %.',
        answerFigure: 'min_p_below',
        answerIsPercent: true,
        relTolerance: 0.05,
        unit: '%',
        explanation: 'P(g < 0,5) = {{min_p_below}}: casi uno de cada cuatro bloques va a desmonte, aunque la ley media (0,8) supere holgadamente el corte.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_minas_3',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: '¿Qué ley es «típica» de un bloque del banco?',
        options: [
          Option('0,8 %, la media', feedback: 'Con cola derecha, la media está por encima de la mayoría de los bloques.', confusion: 'media_es_tipico'),
          Option('La mediana, {{min_median}} %: la mitad de los bloques está por debajo', correct: true, feedback: 'Correcto.'),
          Option('0,5 %, la ley de corte', feedback: 'La ley de corte es una decisión económica, no una propiedad del depósito.'),
        ],
        explanation: 'Mediana = {{min_median}} % < media = 0,8 %. Unos pocos bloques ricos levantan la media.',
        targets: ['media_es_tipico'],
      ),
    ],
    closing: 'Planificar con la ley media esconde que {{min_p_below}} del banco es desmonte. La simulación permite planificar el destino de cada bloque y el riesgo de la alimentación a planta.',
  ),

  // --------------------------------------------------------- Sistemas
  const CaseStudy(
    id: 'c_sistemas',
    career: 'Ingeniería de Sistemas',
    title: 'Tres microservicios y un SLA',
    context: 'Una API llama en paralelo a tres microservicios cuyos tiempos de respuesta son exponenciales con medias 40, 60 y 100 ms. '
        'La API responde cuando llegan los tres. El contrato (SLA) exige responder en 200 ms o menos.',
    model: ModelSpec(
      id: 'case_sistemas',
      title: 'Latencia de la API',
      description: 'Tres llamadas en paralelo; la API espera a la más lenta. SLA: 200 ms.',
      inputs: [
        InputSpec(name: 'A', kind: DistKind.exponential, params: [40], description: 'Servicio A', unit: 'ms'),
        InputSpec(name: 'B', kind: DistKind.exponential, params: [60], description: 'Servicio B', unit: 'ms'),
        InputSpec(name: 'C', kind: DistKind.exponential, params: [100], description: 'Servicio C', unit: 'ms'),
      ],
      expression: 'max(A; B; C)',
      outputName: 'Latencia',
      outputUnit: 'ms',
      threshold: 200,
      side: ThresholdSide.above,
      thresholdMeaning: 'incumplir el SLA de 200 ms',
      career: 'Sistemas',
    ),
    steps: [
      Exercise(
        id: 'c_sistemas_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'El servicio más lento tarda 100 ms en promedio y el SLA es 200 ms. ¿Está garantizado el cumplimiento?',
        options: [
          Option('Sí: el doble del promedio más lento da margen de sobra', feedback: 'La API espera al máximo de tres tiempos aleatorios, y la exponencial tiene cola larga.', confusion: 'paralelo_sin_sesgo'),
          Option('No: hay que estimar P(max(A, B, C) ≤ 200)', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'El tiempo de respuesta es el máximo de tres variables: la media del más lento no lo resume.',
        targets: ['paralelo_sin_sesgo', 'media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_sistemas_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Qué porcentaje de las solicitudes cumple el SLA de 200 ms?',
        answerFigure: 'sis_p_sla',
        answerIsPercent: true,
        relTolerance: 0.02,
        unit: '%',
        explanation: 'P = (1 − e^(−200/40))(1 − e^(−200/60))(1 − e^(−200/100)) = {{sis_p_sla}}. Casi 1 de cada 6 solicitudes incumple.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_sistemas_3',
        moduleId: 'cases',
        type: ExerciseType.decision,
        prompt: 'Hay presupuesto para una mejora: bajar el servicio C de 100 a 70 ms, o bajar B de 60 a 40 ms. ¿Cuál priorizas?',
        options: [
          Option('Mejorar C (100 → 70 ms)', correct: true, feedback: 'Correcto: el cumplimiento sube a {{sis_p_sla_fast}}.'),
          Option('Mejorar B (60 → 40 ms)', feedback: 'Solo sube a {{sis_p_sla_other}}.'),
        ],
        justifications: [
          Option('La cola del servicio más lento domina el máximo; recortarla mueve más la probabilidad de cumplir', correct: true, feedback: 'Esa es la lógica de la sensibilidad.'),
          Option('Porque 30 ms de ahorro es más que 20 ms', feedback: 'El ahorro en la media no es el criterio: lo es el efecto sobre P(cumplir).', confusion: 'acertar_sin_entender'),
        ],
        explanation: 'Simula ambas variantes en el simulador cambiando la media de C o de B y compara P(latencia > 200).',
        targets: ['sensibilidad_por_rango'],
      ),
    ],
    closing: 'En sistemas distribuidos, las colas de los tiempos (p95, p99) mandan. Monte Carlo permite probar mejoras antes de implementarlas.',
  ),

  // ------------------------------------------------------ Electrónica
  const CaseStudy(
    id: 'c_electronica',
    career: 'Ingeniería Electrónica',
    title: 'Tolerancia de tres resistencias en serie',
    context: 'Tres resistencias de 10 kΩ ± 5 % (uniformes entre 9,5 y 10,5 kΩ) se conectan en serie. El circuito funciona si el total está a menos de 1 kΩ de 30 kΩ. '
        'El análisis de peor caso dice que el total puede desviarse hasta 1,5 kΩ.',
    model: ModelSpec(
      id: 'case_electronica',
      title: 'Resistencias en serie',
      description: 'Desviación del total respecto de 30 kΩ. Umbral: 1 kΩ.',
      inputs: [
        InputSpec(name: 'R1', kind: DistKind.uniform, params: [9.5, 10.5], description: 'Resistencia 1', unit: 'kΩ'),
        InputSpec(name: 'R2', kind: DistKind.uniform, params: [9.5, 10.5], description: 'Resistencia 2', unit: 'kΩ'),
        InputSpec(name: 'R3', kind: DistKind.uniform, params: [9.5, 10.5], description: 'Resistencia 3', unit: 'kΩ'),
      ],
      expression: 'abs(R1 + R2 + R3 - 30)',
      outputName: 'Desviación del total',
      outputUnit: 'kΩ',
      threshold: 1,
      side: ThresholdSide.above,
      thresholdMeaning: 'salir de tolerancia',
      career: 'Electrónica',
    ),
    steps: [
      Exercise(
        id: 'c_electronica_1',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: 'Cada resistencia uniforme de ancho 1 kΩ tiene desviación {{ele_sd_one}} kΩ. ¿Cuál es la desviación del total de las tres (independientes)?',
        answerFigure: 'ele_sd_sum',
        relTolerance: 0.02,
        unit: 'kΩ',
        wrongPatterns: [
          WrongPattern(figure: 'ele_sd_wrong', confusion: 'sumar_desviaciones', feedback: 'Sumaste desviaciones; se suman varianzas: √3 · {{ele_sd_one}}.'),
        ],
        explanation: '√3 · {{ele_sd_one}} = {{ele_sd_sum}} kΩ.',
        targets: ['sumar_desviaciones'],
      ),
      Exercise(
        id: 'c_electronica_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Qué porcentaje de circuitos queda fuera de ±1 kΩ?',
        answerFigure: 'ele_p_out',
        answerIsPercent: true,
        relTolerance: 0.06,
        unit: '%',
        explanation: 'La suma de tres uniformes tiene forma de campana sobre [28,5; 31,5]. La fracción fuera de ±1 es {{ele_p_out}} (la aproximación normal da {{ele_normal_approx}}).',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_electronica_3',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: '¿Qué le dices a quien diseñó con peor caso (±1,5 kΩ)?',
        options: [
          Option('El peor caso es imposible y puede ignorarse', feedback: 'Es posible, solo muy improbable. Ignorarlo es otra forma de error.'),
          Option('El peor caso es muy improbable: el criterio estadístico permite tolerancias más baratas con un riesgo cuantificado de {{ele_p_out}}', correct: true, feedback: 'Correcto.'),
          Option('Que sume las tolerancias individuales para ir a lo seguro', feedback: 'Sumar tolerancias es suponer que todas se desvían al máximo a la vez.', confusion: 'sumar_desviaciones'),
        ],
        explanation: 'El análisis estadístico de tolerancias cambia «nunca falla» (caro) por «falla el {{ele_p_out}}» (decidible).',
        targets: ['sumar_desviaciones'],
      ),
    ],
    closing: 'El diseño por tolerancia estadística es Monte Carlo en la industria electrónica: se simula el lote antes de fabricarlo.',
  ),

  // --------------------------------------------------------- Ambiental
  const CaseStudy(
    id: 'c_ambiental',
    career: 'Ingeniería Ambiental',
    title: 'Media bajo el límite, días sobre el límite',
    context: 'La concentración diaria de PM10 cerca de una planta es lognormal con mediana 30 µg/m³ y σ_ln = 0,5. El límite diario es 50 µg/m³. '
        'El estudio de impacto reporta solo la concentración media.',
    model: ModelSpec(
      id: 'case_ambiental',
      title: 'Concentración diaria',
      description: 'Lognormal con mediana 30 y σ_ln 0,5 (media {{amb_mean}}). Límite: 50 µg/m³.',
      inputs: [
        InputSpec(name: 'Cd', kind: DistKind.lognormal, params: [33.99445359200479, 18.117015996326433], description: 'Concentración diaria', unit: 'µg/m³'),
      ],
      expression: 'Cd',
      outputName: 'Concentración',
      outputUnit: 'µg/m³',
      threshold: 50,
      side: ThresholdSide.above,
      thresholdMeaning: 'superar el límite diario',
      career: 'Ambiental',
    ),
    steps: [
      Exercise(
        id: 'c_ambiental_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'La media es {{amb_mean}} µg/m³, bajo el límite de 50. ¿El estudio puede concluir que se cumple la norma?',
        options: [
          Option('Sí: la media está bajo el límite', feedback: 'El límite es diario: importa cuántos días se supera.', confusion: 'media_bajo_limite_seguro'),
          Option('No: hay que estimar la probabilidad diaria de superar 50', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'Un límite diario se evalúa con la distribución diaria, no con su media.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_ambiental_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad de que un día supere 50 µg/m³, en %?',
        answerFigure: 'amb_p_exceed',
        answerIsPercent: true,
        relTolerance: 0.04,
        unit: '%',
        wrongPatterns: [
          WrongPattern(figure: 'zero', confusion: 'media_bajo_limite_seguro', feedback: 'La media está bajo el límite, pero la cola derecha lo supera con frecuencia.'),
        ],
        explanation: 'P(C > 50) = 1 − Φ(ln(50/30)/0,5) = {{amb_p_exceed}}.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_ambiental_3',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuántos días al año se esperaría superar el límite (365 días, suponiendo días independientes)?',
        answerFigure: 'amb_days',
        relTolerance: 0.05,
        unit: 'días',
        wrongPatterns: [
          WrongPattern(figure: 'zero', confusion: 'media_bajo_limite_seguro', feedback: 'Con la media bajo el límite no se deduce que ningún día lo supere.'),
        ],
        explanation: '365 · {{amb_p_exceed}} ≈ {{amb_days}} días. Supuesto a declarar: días consecutivos contaminados tienden a agruparse (no son independientes).',
        targets: ['media_bajo_limite_seguro'],
      ),
    ],
    closing: 'Con la media bajo la norma, el límite se supera unos {{amb_days}} días al año. En gestión ambiental, la cola es el impacto.',
  ),

  // ----------------------------------------------------- Administración
  const CaseStudy(
    id: 'c_administracion',
    career: 'Administración',
    title: '¿Cuánto pedir para la campaña?',
    context: 'Una tienda compra un producto de temporada a S/ 2, lo vende a S/ 5 y remata lo que sobra a S/ 0,50. La demanda es uniforme entre 40 y 100 unidades (media 70). '
        'El gerente propone pedir la demanda media.',
    model: ModelSpec(
      id: 'case_administracion',
      title: 'Inventario de temporada',
      description: 'Cambia q y compara la utilidad media. Demanda Uniforme(40; 100).',
      inputs: [
        InputSpec(name: 'D', kind: DistKind.uniform, params: [40, 100], description: 'Demanda', unit: 'unidades'),
        InputSpec(name: 'q', kind: DistKind.constant, params: [70], description: 'Cantidad pedida', unit: 'unidades'),
      ],
      expression: '5 * min(D; q) + 0.5 * pos(q - D) - 2 * q',
      outputName: 'Utilidad',
      outputUnit: 'S/',
      threshold: 0,
      side: ThresholdSide.below,
      thresholdMeaning: 'perder dinero',
      career: 'Administración',
    ),
    steps: [
      Exercise(
        id: 'c_administracion_1',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: 'Faltar cuesta 5 − 2 = 3 por unidad; sobrar cuesta 2 − 0,5 = 1,5. ¿Cuál es la razón crítica 3/(3 + 1,5)?',
        answerFigure: 'adm_cr',
        relTolerance: 0.01,
        explanation: 'Razón crítica = {{adm_cr}}: conviene pedir el percentil {{adm_cr}} de la demanda.',
      ),
      Exercise(
        id: 'c_administracion_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Qué cantidad maximiza la utilidad esperada? (percentil de la razón crítica en la Uniforme(40; 100))',
        answerFigure: 'adm_qstar',
        relTolerance: 0.01,
        unit: 'unidades',
        wrongPatterns: [
          WrongPattern(figure: 'adm_mean_demand', confusion: 'promedio_de_entradas', feedback: 'Esa es la demanda media. Como faltar cuesta más que sobrar, conviene pedir más.'),
        ],
        explanation: 'q* = 40 + {{adm_cr}} · 60 = {{adm_qstar}}. Pruébalo en el simulador cambiando q.',
        targets: ['promedio_de_entradas'],
      ),
      Exercise(
        id: 'c_administracion_3',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'Con q = 70 la utilidad media es {{adm_profit_q70}}; con q = {{adm_qstar}}, {{adm_profit_q80}}. ¿Por qué pedir la media no es lo mejor?',
        options: [
          Option('Porque faltar cuesta más que sobrar: conviene cubrir más de la mitad de los escenarios', correct: true, feedback: 'Correcto.'),
          Option('Pedir la media siempre es óptimo; la diferencia es error de simulación', feedback: 'La diferencia es exacta (cálculo cerrado), no ruido.', confusion: 'promedio_de_entradas'),
          Option('Porque la demanda media está mal calculada', feedback: 'La media es 70; el problema es usar solo la media para decidir.', confusion: 'solo_la_media'),
        ],
        explanation: 'La decisión óptima depende de la asimetría de costos y de toda la distribución de la demanda, no de su promedio.',
        targets: ['promedio_de_entradas'],
      ),
    ],
    closing: 'El problema del vendedor de periódicos es la puerta de entrada a la gestión de inventarios bajo incertidumbre: la media nunca basta para decidir cuánto comprar.',
  ),

  // ---------------------------------------------------------- Economía
  const CaseStudy(
    id: 'c_economia',
    career: 'Economía',
    title: 'Diez años de una inversión con riesgo',
    context: 'Un fondo tiene rendimiento logarítmico anual Normal(6 %; 15 %), independiente entre años. Un sol invertido hoy vale e^(L) en 10 años, con L = suma de los 10 rendimientos.',
    model: ModelSpec(
      id: 'case_economia',
      title: 'Riqueza tras 10 años',
      description: 'L ~ Normal(0,6; 0,15·√10). Umbral: terminar con menos de lo invertido.',
      inputs: [
        InputSpec(name: 'L', kind: DistKind.normal, params: [0.6, 0.4743416490252569], description: 'Rendimiento log acumulado a 10 años'),
      ],
      expression: 'exp(L)',
      outputName: 'Riqueza por sol invertido',
      outputUnit: 'S/',
      threshold: 1,
      side: ThresholdSide.below,
      thresholdMeaning: 'perder capital en 10 años',
      career: 'Economía',
    ),
    steps: [
      Exercise(
        id: 'c_economia_1',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la desviación del rendimiento logarítmico acumulado en 10 años (años independientes con desviación 0,15)?',
        answerFigure: 'eco_sd_log',
        relTolerance: 0.02,
        wrongPatterns: [
          WrongPattern(figure: 'eco_sd_wrong', confusion: 'sumar_desviaciones', feedback: 'Multiplicar 0,15 por 10 es sumar desviaciones; la dispersión crece con √10.'),
        ],
        explanation: '0,15 · √10 = {{eco_sd_log}}.',
        targets: ['sumar_desviaciones'],
      ),
      Exercise(
        id: 'c_economia_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad, en %, de terminar con menos de lo invertido al cabo de 10 años?',
        answerFigure: 'eco_p_loss',
        answerIsPercent: true,
        relTolerance: 0.04,
        unit: '%',
        explanation: 'P(L < 0) = Φ(−0,6/{{eco_sd_log}}) = {{eco_p_loss}}.',
        targets: ['solo_la_media'],
      ),
      Exercise(
        id: 'c_economia_3',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'La riqueza media simulada es {{eco_mean}} por sol y la mediana {{eco_median}}. ¿Cuál describe mejor lo que obtendrá un inversionista típico?',
        options: [
          Option('La media, {{eco_mean}}', feedback: 'La media la levantan pocos escenarios muy buenos.', confusion: 'media_es_tipico'),
          Option('La mediana, {{eco_median}}: la mitad de los escenarios termina por debajo', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'La riqueza compuesta es lognormal: media > mediana. Los folletos que anuncian la media prometen algo que la mayoría no obtendrá.',
        targets: ['media_es_tipico'],
      ),
    ],
    closing: 'El interés compuesto con riesgo produce distribuciones asimétricas. Monte Carlo es la herramienta estándar para planes de pensiones y carteras.',
  ),

  // ------------------------------------------------------ Contabilidad
  const CaseStudy(
    id: 'c_contabilidad',
    career: 'Contabilidad',
    title: 'Cero errores en la muestra de auditoría',
    context: 'Un auditor revisa una muestra aleatoria de 150 facturas y no encuentra ningún error. La gerencia quiere afirmar en el informe que «la tasa de error es 0 %». '
        'La tasa tolerable para la auditoría es 3 %.',
    steps: [
      Exercise(
        id: 'c_contabilidad_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: '¿Se puede afirmar que la tasa de error es 0 %?',
        options: [
          Option('Sí: no se encontró ningún error', feedback: 'Cero casos en la muestra no prueba cero en la población.', confusion: 'cero_casos_cero_prob'),
          Option('No: solo se puede acotar la tasa por arriba', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'Con 0 errores en n, la cota superior al 95 % es ≈ 3/n.',
        targets: ['cero_casos_cero_prob'],
      ),
      Exercise(
        id: 'c_contabilidad_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la cota superior aproximada al 95 % de la tasa de error, en %?',
        answerFigure: 'con_rule3',
        answerIsPercent: true,
        relTolerance: 0.03,
        unit: '%',
        wrongPatterns: [
          WrongPattern(figure: 'zero', confusion: 'cero_casos_cero_prob', feedback: '0 % es la estimación puntual; la cota es 3/150.'),
        ],
        explanation: '3/150 = {{con_rule3}}.',
        targets: ['cero_casos_cero_prob'],
      ),
      Exercise(
        id: 'c_contabilidad_3',
        moduleId: 'cases',
        type: ExerciseType.decision,
        prompt: 'Si la tasa real fuera 3 %, la probabilidad de ver 0 errores en 150 sería {{con_p0_3pct}}. ¿Qué concluye el auditor?',
        options: [
          Option('La evidencia respalda que la tasa está por debajo del 3 % tolerable', correct: true, feedback: 'Correcto.'),
          Option('No se puede concluir nada sin encontrar errores', feedback: 'Precisamente, no encontrar ninguno es evidencia fuerte si la muestra es grande.'),
        ],
        justifications: [
          Option('Con 3 % de error, ver 0 en 150 ocurriría solo {{con_p0_3pct}} de las veces: es muy improbable', correct: true, feedback: 'Así razona el muestreo de auditoría.'),
          Option('Porque 0 errores significa tasa 0', feedback: 'La conclusión es correcta, la razón no: la tasa se acota, no se anula.', confusion: 'acertar_sin_entender'),
        ],
        explanation: '0,97^150 = {{con_p0_3pct}}. El informe correcto: «tasa de error inferior al {{con_rule3}} con 95 % de confianza».',
        targets: ['cero_casos_cero_prob'],
      ),
    ],
    closing: 'El muestreo estadístico de auditoría usa exactamente este razonamiento; la simulación permite comprobarlo generando miles de muestras de facturas.',
  ),

  // ------------------------------------------------------- Psicología
  CaseStudy(
    id: 'c_psicologia',
    career: 'Psicología',
    title: 'Aprobar adivinando',
    context: 'Una prueba de selección tiene 20 preguntas de 4 alternativas y se aprueba con 10 aciertos. Un postulante responde completamente al azar. '
        'El comité cree que «nadie puede aprobar adivinando».',
    model: ModelSpec(
      id: 'case_psicologia',
      title: 'Aciertos por azar',
      description: '20 preguntas, cada una acertada con probabilidad 0,25. Aprobar: 10 aciertos o más.',
      inputs: _series('A', 20, DistKind.bernoulli, const [0.25], 'Pregunta'),
      expression: _sumOf('A', 20),
      outputName: 'Aciertos',
      threshold: 9.5,
      side: ThresholdSide.above,
      thresholdMeaning: 'aprobar (10 o más aciertos) adivinando',
      career: 'Psicología',
    ),
    steps: const [
      Exercise(
        id: 'c_psicologia_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: '¿Cuántos aciertos espera, en promedio, alguien que adivina?',
        options: [
          Option('5', correct: true, feedback: 'Correcto: 20 · 0,25.'),
          Option('10', feedback: 'Eso sería con probabilidad 0,5 por pregunta.'),
          Option('0', feedback: 'Adivinar también acierta a veces.'),
        ],
        explanation: 'E[aciertos] = n·p = 20 · 0,25 = 5.',
      ),
      Exercise(
        id: 'c_psicologia_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad, en %, de aprobar (10 o más aciertos) respondiendo al azar?',
        answerFigure: 'psi_p10',
        answerIsPercent: true,
        relTolerance: 0.05,
        unit: '%',
        wrongPatterns: [
          WrongPattern(figure: 'zero', confusion: 'cero_casos_cero_prob', feedback: 'Es poco probable, no imposible.'),
        ],
        explanation: 'P(X ≥ 10) con X ~ Binomial(20; 0,25) = {{psi_p10}}.',
        targets: ['cero_casos_cero_prob'],
      ),
      Exercise(
        id: 'c_psicologia_3',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: 'Si 500 postulantes respondieran completamente al azar, ¿cuántos aprobarían en promedio?',
        answerFigure: 'psi_pass_500',
        relTolerance: 0.05,
        unit: 'postulantes',
        explanation: '500 · {{psi_p10}} ≈ {{psi_pass_500}}. Con muchos postulantes, lo raro deja de serlo: la prueba necesita un punto de corte más alto o más preguntas.',
        targets: ['cero_casos_cero_prob'],
      ),
    ],
    closing: 'Simular respuestas al azar es la forma más directa de calibrar puntos de corte y detectar que una prueba discrimina poco.',
  ),

  // --------------------------------------------------------- Biología
  const CaseStudy(
    id: 'c_biologia',
    career: 'Biología',
    title: 'Crecer en promedio y aun así desaparecer',
    context: 'Una población de aves tiene crecimiento logarítmico anual Normal(0,02; 0,2) por la variabilidad climática. En 20 años, el tamaño relativo es e^(L), con L = suma de los 20 crecimientos.',
    model: ModelSpec(
      id: 'case_biologia',
      title: 'Tamaño relativo en 20 años',
      description: 'L ~ Normal(0,4; 0,2·√20). Umbral: caer por debajo de la mitad.',
      inputs: [InputSpec(name: 'L', kind: DistKind.normal, params: [0.4, 0.894427190999916], description: 'Crecimiento log acumulado')],
      expression: 'exp(L)',
      outputName: 'N20 / N0',
      threshold: 0.5,
      side: ThresholdSide.below,
      thresholdMeaning: 'reducirse a menos de la mitad',
      career: 'Biología',
    ),
    steps: [
      Exercise(
        id: 'c_biologia_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'El crecimiento medio es positivo (+2 % anual). ¿Está la población a salvo?',
        options: [
          Option('Sí: en promedio crece', feedback: 'La variabilidad hace que muchas trayectorias caigan aunque la media suba.', confusion: 'media_bajo_limite_seguro'),
          Option('No necesariamente: hay que estimar la probabilidad de caer bajo un umbral crítico', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'En viabilidad poblacional se simulan trayectorias y se estima la probabilidad de cuasi-extinción.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_biologia_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad, en %, de que en 20 años la población sea menor que la mitad de la actual?',
        answerFigure: 'bio_p_half',
        answerIsPercent: true,
        relTolerance: 0.04,
        unit: '%',
        explanation: 'P(L < ln 0,5) = Φ((ln 0,5 − 0,4)/{{bio_sd_log}}) = {{bio_p_half}}.',
        targets: ['media_bajo_limite_seguro'],
      ),
      Exercise(
        id: 'c_biologia_3',
        moduleId: 'cases',
        type: ExerciseType.decision,
        prompt: '¿Qué medida de conservación reduce más ese riesgo?',
        options: [
          Option('Reducir la variabilidad anual (refugios ante eventos climáticos)', correct: true, feedback: 'Correcto: con menor σ, la cola baja se encoge mucho.'),
          Option('Subir un poco el crecimiento medio', feedback: 'Ayuda, pero la cola la domina la dispersión acumulada ({{bio_sd_log}}).'),
        ],
        justifications: [
          Option('El riesgo de caer está en la cola, que crece con σ·√20; reducir σ la achica directamente', correct: true, feedback: 'Ese es el mecanismo.'),
          Option('Porque la media no importa en biología', feedback: 'La media importa; aquí la dispersión pesa más para este riesgo.', confusion: 'acertar_sin_entender'),
        ],
        explanation: 'Compruébalo en el simulador: baja la desviación de L o sube su media y compara P(N20/N0 < 0,5).',
        targets: ['solo_la_media'],
      ),
    ],
    closing: 'Los análisis de viabilidad poblacional (PVA) son simulaciones Monte Carlo: la varianza ambiental, no la media, suele decidir la supervivencia.',
  ),

  // ------------------------------------------------------ Humanidades
  const CaseStudy(
    id: 'c_humanidades',
    career: 'Humanidades',
    title: '¿Coincidencia sospechosa en un archivo?',
    context: 'Una historiadora encuentra que en un registro parroquial de 30 personas, dos nacieron el mismo día del año. Un colega sugiere que el registro fue alterado: «es demasiada coincidencia».',
    steps: [
      Exercise(
        id: 'c_humanidades_1',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: 'Antes de calcular: ¿qué tan probable crees que es una coincidencia de cumpleaños entre 30 personas?',
        options: [
          Option('Muy improbable: hay 365 días', feedback: 'La intuición cuenta pares con una persona fija; hay 435 pares posibles.'),
          Option('Más probable que improbable', correct: true, feedback: 'Correcto.'),
        ],
        explanation: 'Con 30 personas hay 30·29/2 = 435 pares; cada uno puede coincidir.',
      ),
      Exercise(
        id: 'c_humanidades_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad, en %, de que al menos dos de 30 personas compartan cumpleaños (365 días equiprobables)?',
        answerFigure: 'hum_p30',
        answerIsPercent: true,
        relTolerance: 0.02,
        unit: '%',
        explanation: '1 − (365·364·…·336)/365³⁰ = {{hum_p30}}.',
      ),
      Exercise(
        id: 'c_humanidades_3',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Con cuántas personas la probabilidad de coincidencia supera por primera vez el 50 %?',
        answerFigure: 'hum_n50',
        relTolerance: 0.001,
        unit: 'personas',
        explanation: 'Con {{hum_n50}} personas la probabilidad es {{hum_p23}}.',
      ),
    ],
    closing: 'Simular «qué pasaría por azar» es la base de las pruebas de permutación que se usan en estilometría y análisis de corpus: antes de ver un patrón, se mide cuán frecuente es por azar.',
  ),

  // ------------------------------------------------ Desarrollo personal
  CaseStudy(
    id: 'c_desarrollo',
    career: 'Desarrollo personal',
    title: 'Una meta de ahorro realista',
    context: 'Ahorras cada mes un monto incierto: Normal(300; 100) soles, independiente entre meses. Tu meta anual es 3 500 soles.',
    model: ModelSpec(
      id: 'case_desarrollo',
      title: 'Ahorro anual',
      description: '12 meses Normal(300; 100). Umbral: no llegar a la meta de 3 500.',
      inputs: _series('M', 12, DistKind.normal, const [300, 100], 'Mes'),
      expression: _sumOf('M', 12),
      outputName: 'Ahorro anual',
      outputUnit: 'S/',
      threshold: 3500,
      side: ThresholdSide.below,
      thresholdMeaning: 'no alcanzar la meta',
      career: 'Desarrollo personal',
    ),
    steps: const [
      Exercise(
        id: 'c_desarrollo_1',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la desviación del ahorro anual (12 meses independientes con desviación 100)?',
        answerFigure: 'dev_sd_total',
        relTolerance: 0.02,
        unit: 'S/',
        wrongPatterns: [
          WrongPattern(figure: 'dev_sd_wrong', confusion: 'sumar_desviaciones', feedback: 'Sumaste 12 desviaciones; se suman varianzas: 100·√12.'),
        ],
        explanation: '100 · √12 = {{dev_sd_total}}.',
        targets: ['sumar_desviaciones'],
      ),
      Exercise(
        id: 'c_desarrollo_2',
        moduleId: 'cases',
        type: ExerciseType.numeric,
        prompt: '¿Cuál es la probabilidad, en %, de alcanzar la meta de 3 500?',
        answerFigure: 'dev_p_goal',
        answerIsPercent: true,
        relTolerance: 0.03,
        unit: '%',
        wrongPatterns: [
          WrongPattern(figure: 'dev_p_goal_wrong', confusion: 'sumar_desviaciones', feedback: 'Usaste desviación 1 200; con la correcta ({{dev_sd_total}}) la probabilidad es mayor.'),
        ],
        explanation: 'P(T ≥ 3 500) = Φ(100/{{dev_sd_total}}) = {{dev_p_goal}}.',
        targets: ['sumar_desviaciones'],
      ),
      Exercise(
        id: 'c_desarrollo_3',
        moduleId: 'cases',
        type: ExerciseType.choice,
        prompt: '¿Cómo conviene expresar tu meta?',
        options: [
          Option('«Ahorraré 3 600», la media', feedback: 'Un solo número se incumple casi la mitad de las veces.', confusion: 'solo_la_media'),
          Option('«Entre {{dev_p10}} y {{dev_p90}} con 80 % de probabilidad»', correct: true, feedback: 'Correcto: un rango P10–P90 es honesto y planificable.'),
          Option('«Ahorraré 4 800», sumando el mejor caso de cada mes', feedback: 'Todos los meses buenos a la vez es casi imposible.', confusion: 'sumar_desviaciones'),
        ],
        explanation: 'P10 = {{dev_p10}}, P90 = {{dev_p90}}. Planificar con rangos reduce la frustración y permite ajustar a tiempo.',
        targets: ['solo_la_media'],
      ),
    ],
    closing: 'Tus metas personales también tienen incertidumbre. Pensarlas como distribuciones, no como números, es la lección de Monte Carlo para la vida diaria.',
  ),
];

CaseStudy? caseById(String id) {
  for (final c in cases) {
    if (c.id == id) return c;
  }
  return null;
}
