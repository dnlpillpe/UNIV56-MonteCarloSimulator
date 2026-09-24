import '../models/content_models.dart';

/// Seis laboratorios, dos por módulo, con 16 experimentos en total.
/// Cada experimento sigue Predice → Simula → Explica: los controles se
/// bloquean hasta registrar la predicción y el hallazgo hasta alcanzar el
/// mínimo de repeticiones.
const List<Lab> labs = [
  Lab(
    id: 'lab_rain',
    moduleId: 'm1',
    title: 'Lluvia de puntos',
    subtitle: 'Estimar π y un área lanzando puntos al azar; ver cómo se encoge el error.',
    experimentIds: ['e1_pi', 'e2_area', 'e3_seeds'],
  ),
  Lab(
    id: 'lab_generator',
    moduleId: 'm1',
    title: 'Fábrica de azar',
    subtitle: 'Generadores, semillas y transformada inversa: de números uniformes a cualquier variable.',
    experimentIds: ['e4_lcg', 'e5_inverse', 'e6_discrete'],
  ),
  Lab(
    id: 'lab_project',
    moduleId: 'm2',
    title: 'Riesgo en proyectos',
    subtitle: 'El VAN de un proyecto y el plazo de una obra cuando las entradas son inciertas.',
    experimentIds: ['e7_npv', 'e9_merge'],
  ),
  Lab(
    id: 'lab_traps',
    moduleId: 'm2',
    title: 'Trampas del modelo',
    subtitle: 'Falacia de los promedios, correlación ignorada y distribuciones mal elegidas.',
    experimentIds: ['e8_capacity', 'e10_corr', 'e11_shape'],
  ),
  Lab(
    id: 'lab_precision',
    moduleId: 'm3',
    title: 'Precisión y eventos raros',
    subtitle: 'Cuánto mejora la estimación con n y qué pasa con probabilidades pequeñas.',
    experimentIds: ['e12_sqrt_n', 'e13_rare'],
  ),
  Lab(
    id: 'lab_reading',
    moduleId: 'm3',
    title: 'Leer y decidir',
    subtitle: 'Curva S, percentiles, comparación de alternativas y sensibilidad.',
    experimentIds: ['e14_scurve', 'e15_compare', 'e16_tornado'],
  ),
];

const List<ExperimentDef> experiments = [
  // ------------------------------------------------------------ lab_rain
  ExperimentDef(
    id: 'e1_pi',
    labId: 'lab_rain',
    title: 'Dardos para π',
    setup: 'Cada dardo cae en un punto al azar del cuadrado. Si cae dentro del cuarto de círculo cuenta como acierto. La estimación es 4 · aciertos / dardos.',
    prediction: 'Con solo 100 dardos, ¿qué tan cerca de π esperas que quede la estimación?',
    options: [
      PredictionOption('Casi exacta: 3,14', confusion: 'una_corrida_es_verdad'),
      PredictionOption('Dentro de unas tres décimas, y distinta en cada intento', correct: true),
      PredictionOption('Lejísimos: con azar no se puede estimar nada'),
    ],
    minSamples: 1000,
    finding: 'Con [[n]] dardos tu estimación es [[est]] (error [[err]]). El error típico de un dardo es {{pi_se_coef}}, así que con n dardos el error estándar es {{pi_se_coef}}/√n: '
        'con 100 dardos, el IC 95 % tiene semiamplitud ±{{pi_half_100}}; con 1 000, el error estándar es {{pi_se_1000}}. Para ±0,01 harían falta unos {{pi_n_001}} dardos.',
    explanation: 'La estimación salta mucho al principio y luego se estabiliza dentro del embudo ±2·EE. El embudo se estrecha como 1/√n: rápido al inicio y cada vez más lento.',
    remedyFor: ['una_corrida_es_verdad'],
  ),
  ExperimentDef(
    id: 'e2_area',
    labId: 'lab_rain',
    title: 'Dos estimadores, una misma área',
    setup: 'Se estima el área bajo f(x) = e^(−x²) entre 0 y 1 de dos formas con los mismos n números: acierto-fallo (puntos bajo la curva) y valor medio (promedio de f(U)).',
    prediction: 'Con el mismo número de iteraciones, ¿cuál estimador tendrá menor error?',
    options: [
      PredictionOption('Los dos igual: solo importa n', confusion: 'estimadores_iguales'),
      PredictionOption('Acierto-fallo, porque usa dos números por punto'),
      PredictionOption('Valor medio, porque cada iteración aporta más información', correct: true),
    ],
    minSamples: 1000,
    finding: 'Tras [[n]] iteraciones: acierto-fallo = [[est_hit]] (error [[err_hit]]), valor medio = [[est_mean]] (error [[err_mean]]); el valor exacto es {{area_true}}. '
        'La desviación por iteración es {{area_sd_hit}} contra {{area_sd_mean}}: el valor medio equivale a tener {{area_var_ratio}} veces más iteraciones.',
    explanation: 'Acierto-fallo convierte cada punto en 0 o 1 y pierde información; el valor medio usa la altura exacta de la curva. Reducir la varianza del estimador es tan valioso como aumentar n.',
    remedyFor: ['estimadores_iguales'],
  ),
  ExperimentDef(
    id: 'e3_seeds',
    labId: 'lab_rain',
    title: 'Cinco semillas, cinco respuestas',
    setup: 'Cinco analistas estiman π con el mismo método y distinta semilla. Las cinco trayectorias se dibujan juntas.',
    prediction: 'Con 500 dardos cada uno, ¿qué obtendrán los cinco analistas?',
    options: [
      PredictionOption('El mismo resultado, porque el método es el mismo', confusion: 'una_corrida_es_verdad'),
      PredictionOption('Resultados distintos, casi todos a menos de ±0,15 de π', correct: true),
      PredictionOption('Resultados sin relación entre sí'),
    ],
    minSamples: 500,
    finding: 'Con [[n]] dardos por analista, las estimaciones van de [[min]] a [[max]] (rango [[spread]]). Con 500 dardos, el 95 % de las corridas cae a menos de ±{{pi_half_500}} de π.',
    explanation: 'Cada corrida es una muestra: su resultado tiene error. Por eso un informe dice «3,13 ± 0,14 (IC 95 %, n = 500, semilla 17)» y no «π = 3,13».',
    remedyFor: ['una_corrida_es_verdad', 'se_vs_sd'],
  ),

  // ------------------------------------------------------- lab_generator
  ExperimentDef(
    id: 'e4_lcg',
    labId: 'lab_generator',
    title: 'Un generador defectuoso',
    setup: 'Compara un generador congruencial con parámetros pequeños (a = 37, c = 1, m = 256) con xoshiro128**. Mira el histograma y los pares consecutivos (uₖ, uₖ₊₁).',
    prediction: 'El generador congruencial produce un histograma casi perfectamente plano. ¿Basta para confiar en él?',
    options: [
      PredictionOption('Sí: si es uniforme, es buen azar', confusion: 'histograma_prueba_calidad'),
      PredictionOption('No: también hay que revisar que los valores consecutivos sean independientes', correct: true),
      PredictionOption('No, porque los generadores de computadora nunca sirven', confusion: 'pseudo_es_azar_real'),
    ],
    minSamples: 300,
    finding: 'Con [[n]] números: el congruencial repite su secuencia cada 256 valores y sus pares caen sobre unas pocas rectas paralelas, aunque su histograma sea plano. '
        'Con la misma semilla, los primeros valores son idénticos: [[first]].',
    explanation: 'Un generador debe ser uniforme e independiente, con periodo enorme. La repetición con la misma semilla no es un defecto: es la reproducibilidad que exige un informe.',
    remedyFor: ['histograma_prueba_calidad', 'pseudo_es_azar_real', 'sin_semilla'],
  ),
  ExperimentDef(
    id: 'e5_inverse',
    labId: 'lab_generator',
    title: 'Transformada inversa: tiempos entre fallas',
    setup: 'Cada u uniforme se proyecta sobre la acumulada F(x) = 1 − e^(−x/2) de una exponencial con media 2 h y baja al eje x. Así se fabrican tiempos entre fallas.',
    prediction: 'Con media de 2 horas, ¿qué fracción de los tiempos será menor que la media?',
    options: [
      PredictionOption('La mitad, como siempre', confusion: 'media_es_tipico'),
      PredictionOption('Más de la mitad: la mayoría son tiempos cortos', correct: true),
      PredictionOption('Menos de la mitad'),
    ],
    minSamples: 500,
    finding: 'De [[n]] tiempos, el [[frac_below]] fue menor que la media (teórico: {{exp_below_mean}}). La mediana observada es [[median]] h (teórica: {{exp_median}} h).',
    explanation: 'La acumulada sube rápido cerca de 0: muchos valores de u caen en tiempos cortos. En distribuciones con cola a la derecha, la media queda por encima de la mediana.',
    remedyFor: ['inversa_con_densidad', 'media_es_tipico'],
  ),
  ExperimentDef(
    id: 'e6_discrete',
    labId: 'lab_generator',
    title: 'Un dado cargado con una sola uniforme',
    setup: 'El dado sale 6 con probabilidad 0,5 y cada otra cara con 0,1. El intervalo [0, 1) se parte en tramos del largo de cada probabilidad y la cara es la del tramo donde cae u.',
    prediction: '¿Cómo se obtiene una cara con las probabilidades correctas a partir de u?',
    options: [
      PredictionOption('Multiplicar u por 6 y redondear hacia arriba', confusion: 'uniforme_directa'),
      PredictionOption('Buscar el tramo de [0, 1) donde cae u; cada tramo mide lo que su probabilidad', correct: true),
      PredictionOption('Aplicar la densidad al valor de u', confusion: 'inversa_con_densidad'),
    ],
    minSamples: 600,
    finding: 'En [[n]] lanzamientos, el 6 salió el [[p6]] de las veces (esperado: 50 %). Cada cara recibe exactamente la fracción de u que ocupa su tramo.',
    explanation: 'Es la transformada inversa para variables discretas: la acumulada es una escalera y cada peldaño tiene el alto de una probabilidad.',
    remedyFor: ['uniforme_directa'],
  ),

  // --------------------------------------------------------- lab_project
  ExperimentDef(
    id: 'e7_npv',
    labId: 'lab_project',
    title: 'VAN de un proyecto',
    setup: 'Inversión 550 mil soles, 5 años, tasa 10 %. Precio Triangular(8; 10; 11), costo Triangular(5,5; 6; 7), volumen Triangular(30; 50; 55) miles de unidades.',
    prediction: 'El escenario más probable da VAN = {{npv_mode}}. ¿Qué esperas del VAN medio de la simulación?',
    options: [
      PredictionOption('Aproximadamente el mismo', confusion: 'mas_probable_es_esperado'),
      PredictionOption('Bastante menor, con una probabilidad de pérdida importante', correct: true),
      PredictionOption('Mayor, porque la simulación considera escenarios buenos'),
    ],
    minSamples: 2000,
    finding: 'Con [[n]] iteraciones: VAN medio [[mean]], P(VAN < 0) = [[ploss]], P5 = [[p5]], P95 = [[p95]]. Teórico: media {{npv_mean}} y P(VAN < 0) = {{npv_ploss}}.',
    explanation: 'Las tres triangulares tienen la cola hacia el lado malo: el precio puede bajar 2 y subir 1; el volumen, bajar 20 y subir 5. El escenario más probable no es el esperado, y aun con VAN medio positivo, perder dinero es muy posible.',
    remedyFor: ['mas_probable_es_esperado', 'solo_la_media'],
  ),
  ExperimentDef(
    id: 'e9_merge',
    labId: 'lab_project',
    title: 'Dos rutas en paralelo',
    setup: 'Las tareas A y B duran Triangular(5; 8; 14) días (media {{merge_task_mean}}); después viene C, de 5 días. El plan: 9 + 5 = 14 días. Alterna entre una ruta y dos rutas en paralelo.',
    prediction: 'Con dos rutas en paralelo, ¿cómo cambia la probabilidad de terminar en 14 días frente a una sola ruta?',
    options: [
      PredictionOption('Igual: cada ruta dura lo mismo en promedio', confusion: 'paralelo_sin_sesgo'),
      PredictionOption('Baja: la obra espera a la más lenta', correct: true),
      PredictionOption('Sube: hay dos cuadrillas trabajando'),
    ],
    minSamples: 1000,
    finding: 'Observado con [[n]] iteraciones: una ruta cumple el [[p_one]], dos rutas el [[p_two]]; plazo medio con dos rutas [[mean_two]] días. '
        'Teórico: {{merge_p_one}} frente a {{merge_p_two}}, con plazo medio {{merge_mean_total}} días.',
    explanation: 'El máximo de dos duraciones inciertas es, en promedio, mayor que cada una. Los cronogramas deterministas ignoran este «sesgo de fusión» y por eso las obras con muchas rutas paralelas se atrasan sistemáticamente.',
    remedyFor: ['paralelo_sin_sesgo', 'promedio_de_entradas'],
  ),

  // ----------------------------------------------------------- lab_traps
  ExperimentDef(
    id: 'e8_capacity',
    labId: 'lab_traps',
    title: 'Falacia de los promedios: capacidad',
    setup: 'La demanda diaria es Normal(100; 25) y la planta vende min(demanda, capacidad). Mueve la capacidad y compara lo que dice el plan con lo que se vende en promedio.',
    prediction: 'Con capacidad 100 e igual demanda media, ¿cuánto se vende en promedio?',
    options: [
      PredictionOption('100: capacidad y demanda coinciden', confusion: 'promedio_de_entradas'),
      PredictionOption('Alrededor de 90', correct: true),
      PredictionOption('Alrededor de 75'),
    ],
    minSamples: 1000,
    finding: 'Con capacidad [[cap]]: el plan con demanda media dice [[plan]], la simulación da [[sales]] (teórico [[theory]]). Con capacidad 100 se venden en promedio {{cap_expected_sales}}: '
        'el plan sobrestima ventas en {{cap_gap}} y la utilidad diaria esperada baja de {{cap_profit_plan}} a {{cap_profit_expected}}.',
    explanation: 'Los días de demanda alta no se pueden vender (el exceso se pierde) y los de demanda baja no se compensan. Cuando el modelo tiene un mínimo, el promedio de la salida es menor que la salida del promedio.',
    remedyFor: ['promedio_de_entradas'],
  ),
  ExperimentDef(
    id: 'e10_corr',
    labId: 'lab_traps',
    title: 'Riesgos que se mueven juntos',
    setup: 'Mano de obra y materiales son Normal(100; 20) cada uno. Mueve la correlación ρ y observa la nube de pares y el percentil 95 del costo total.',
    prediction: 'Si los dos costos suben y bajan juntos (ρ = 0,8), ¿qué pasa con el P95 del total frente a ρ = 0?',
    options: [
      PredictionOption('Igual: cada costo tiene la misma distribución', confusion: 'ignorar_correlacion'),
      PredictionOption('Mayor: los extremos se suman', correct: true),
      PredictionOption('Menor: se compensan'),
    ],
    minSamples: 1000,
    finding: 'Con ρ = [[rho]]: desviación del total [[sd]] (teórica [[theory_sd]]) y P95 = [[p95]]. Teórico: con ρ = 0, P95 = {{corr_p95_0}}; con ρ = 0,8, {{corr_p95_08}}; con ρ = −0,5, {{corr_p95_m05}}.',
    explanation: 'La varianza del total incluye el término 2ρσ₁σ₂. Con ρ = 0 la desviación es {{corr_sd_0}}, no 40: se suman varianzas, no desviaciones. Con ρ positivo, la cola crece.',
    remedyFor: ['ignorar_correlacion', 'sumar_desviaciones'],
  ),
  ExperimentDef(
    id: 'e11_shape',
    labId: 'lab_traps',
    title: 'La forma de la entrada importa',
    setup: 'Un costo con media 100 y desviación 50, modelado como normal o como lognormal. Mismos dos primeros momentos, distinta forma.',
    prediction: 'Con la misma media y desviación, ¿cuál da mayor probabilidad de que el costo supere 200?',
    options: [
      PredictionOption('Las dos igual: tienen la misma media y desviación', confusion: 'normal_para_todo'),
      PredictionOption('La lognormal, por su cola derecha', correct: true),
      PredictionOption('La normal, porque es simétrica'),
    ],
    minSamples: 1000,
    finding: 'Con [[n]] valores: P(X > 200) normal = [[tail_n]], lognormal = [[tail_ln]]; la normal dio [[neg]] de costos negativos. Teórico: {{shape_normal_tail}}, {{shape_lognormal_tail}} y {{shape_normal_neg}}.',
    explanation: 'Media y desviación no fijan la cola. Para magnitudes positivas y asimétricas, la normal inventa valores imposibles y subestima los extremos que más importan.',
    remedyFor: ['normal_para_todo'],
  ),

  // ------------------------------------------------------- lab_precision
  ExperimentDef(
    id: 'e12_sqrt_n',
    labId: 'lab_precision',
    title: '¿Cuánto mejora con más iteraciones?',
    setup: 'Se repite 40 veces la estimación de π con n = 100, 400, 1 600 y 6 400 dardos. Cada punto es una réplica completa.',
    prediction: 'Al pasar de 400 a 1 600 dardos (4 veces más), ¿qué pasa con la dispersión de las estimaciones?',
    options: [
      PredictionOption('Se divide entre 4', confusion: 'error_lineal_n'),
      PredictionOption('Se divide entre 2', correct: true),
      PredictionOption('No cambia: el azar es el azar', confusion: 'se_vs_sd'),
    ],
    minSamples: 3,
    finding: 'Desviación observada de las réplicas: n = 100 → [[sd_100]], 400 → [[sd_400]], 1 600 → [[sd_1600]], 6 400 → [[sd_6400]]. '
        'Teórica: {{pi_se_100}}, {{pi_se_400}}, {{pi_se_1600}}, {{pi_se_6400}}. Cada vez que n se multiplica por 4, el error se divide entre 2.',
    explanation: 'El error estándar es s/√n. La precisión cuesta cuadráticamente: una cifra decimal más requiere 100 veces más iteraciones.',
    remedyFor: ['error_lineal_n', 'se_vs_sd'],
  ),
  ExperimentDef(
    id: 'e13_rare',
    labId: 'lab_precision',
    title: 'Eventos raros',
    setup: 'Un evento con probabilidad 0,002 (una falla grave). Se hacen 30 réplicas con n = 100, 1 000 o 10 000 iteraciones y se cuenta cuántas no ven ningún caso.',
    prediction: 'Con 100 iteraciones por réplica, ¿cuántas de las 30 réplicas no verán ningún evento?',
    options: [
      PredictionOption('Ninguna: 100 intentos son bastantes'),
      PredictionOption('Unas pocas'),
      PredictionOption('La gran mayoría', correct: true),
    ],
    minSamples: 2,
    finding: 'Con n = [[n]]: [[zeros]] de 30 réplicas sin casos; p̂ promedio [[mean_p]]; error relativo observado [[relse]]. '
        'Teórico: sin casos el {{rare_p0_100}} de las veces con n = 100 y el {{rare_p0_1000}} con n = 1 000; error relativo {{rare_relse_1000}} con 1 000 y {{rare_relse_10000}} con 10 000.',
    explanation: 'Con cero casos la conclusión honesta es p < 3/n (regla del tres), no p = 0. Para eventos raros el error relativo manda: hacen falta del orden de 100/p iteraciones para un 10 %.',
    remedyFor: ['cero_casos_cero_prob', 'eventos_raros_pocas_iter'],
  ),

  // --------------------------------------------------------- lab_reading
  ExperimentDef(
    id: 'e14_scurve',
    labId: 'lab_reading',
    title: 'Curva S y percentiles',
    setup: 'El costo de una obra es lognormal con mediana {{sc_median}}. Mueve el presupuesto sobre la curva S y lee la probabilidad de sobrecosto.',
    prediction: 'Si presupuestas exactamente el costo medio, ¿cuál es la probabilidad de sobrecosto?',
    options: [
      PredictionOption('50 %: la media está en el centro', confusion: 'media_es_tipico'),
      PredictionOption('Menos de 50 %', correct: true),
      PredictionOption('Más de 50 %'),
      PredictionOption('0 %: la media cubre los casos normales', confusion: 'media_bajo_limite_seguro'),
    ],
    minSamples: 2000,
    finding: 'Con [[n]] iteraciones: media [[mean]], mediana [[median]], P10 [[p10]], P90 [[p90]]. Con presupuesto [[budget]], P(sobrecosto) = [[p_over]]. '
        'Teórico: presupuestar la media ({{sc_mean}}) deja {{sc_p_over_mean}} de sobrecosto; el P90 es {{sc_p90}}.',
    explanation: 'La cola derecha arrastra la media por encima de la mediana. Un presupuesto al P90 no se supera en 9 de cada 10 casos: esa es la lectura correcta de un percentil.',
    remedyFor: ['media_es_tipico', 'percentil_invertido', 'media_bajo_limite_seguro'],
  ),
  ExperimentDef(
    id: 'e15_compare',
    labId: 'lab_reading',
    title: 'Dos opciones, dos riesgos',
    setup: 'Opción A: utilidad Normal(120; 80). Opción B: utilidad Normal(100; 15). Se simulan juntas.',
    prediction: '¿Qué alternativa es mejor?',
    options: [
      PredictionOption('A, porque su media es mayor', confusion: 'decision_por_media'),
      PredictionOption('Depende de cuánto riesgo tolere quien decide', correct: true),
      PredictionOption('B, siempre', confusion: 'solo_la_media'),
    ],
    minSamples: 1000,
    finding: 'Con [[n]] iteraciones: A tiene media [[mean_a]], P(pérdida) [[ploss_a]] y P5 [[p5_a]]; B tiene media [[mean_b]], P(pérdida) [[ploss_b]] y P5 [[p5_b]]. '
        'Teórico: P(pérdida) de A = {{cmp_a_ploss}}; P5 de A = {{cmp_a_p5}} y de B = {{cmp_b_p5}}.',
    explanation: 'A ofrece 20 más en promedio a cambio de perder dinero cerca de 1 vez de cada 15. Una empresa que no puede absorber pérdidas elige B; una cartera diversificada puede preferir A. La simulación muestra el intercambio; el criterio lo pone quien decide.',
    remedyFor: ['decision_por_media', 'solo_la_media'],
  ),
  ExperimentDef(
    id: 'e16_tornado',
    labId: 'lab_reading',
    title: '¿Qué entrada manda?',
    setup: 'El mismo proyecto de VAN. Se mide la correlación de rangos entre cada entrada y el VAN y se dibuja el gráfico de tornado.',
    prediction: '¿Qué entrada influye más en el VAN?',
    options: [
      PredictionOption('El volumen, porque tiene el mayor rango (de 30 a 55)', confusion: 'sensibilidad_por_rango'),
      PredictionOption('El precio', correct: true),
      PredictionOption('El costo unitario'),
    ],
    minSamples: 2000,
    finding: 'Correlaciones de rangos con [[n]] iteraciones: precio [[rho_p]], volumen [[rho_q]], costo [[rho_c]]. '
        'Aproximación teórica de la varianza explicada: precio {{tornado_share_price}}, volumen {{tornado_share_volume}}, costo {{tornado_share_cost}}.',
    explanation: 'El volumen varía más en unidades, pero lo que importa es cuánto mueve el VAN: cada sol de precio se multiplica por unas {{npv_volume_mean}} mil unidades. Un estudio de mercado del precio reduce más incertidumbre que uno del volumen.',
    remedyFor: ['sensibilidad_por_rango'],
  ),
];

ExperimentDef experimentById(String id) => experiments.firstWhere((e) => e.id == id);
Lab labById(String id) => labs.firstWhere((l) => l.id == id);
List<Lab> labsOf(String moduleId) => [for (final l in labs) if (l.moduleId == moduleId) l];
