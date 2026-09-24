import '../models/content_models.dart';

/// Los tres módulos pedidos, en el orden pedido.
const List<Module> modules = [
  Module(
    id: 'm1',
    number: 1,
    title: 'Concepto Monte Carlo',
    theme: 'Azar',
    question: '¿Cómo se estima un número con azar controlado, y cuánto error tiene?',
    summary: 'Estimar con puntos al azar, fabricar el azar con una semilla, transformar uniformes en cualquier distribución y medir el error.',
  ),
  Module(
    id: 'm2',
    number: 2,
    title: 'Simulación',
    theme: 'Riesgo',
    question: '¿Cómo se construye un modelo que muestre el riesgo que un cálculo con promedios esconde?',
    summary: 'Entradas inciertas → modelo → salida. Elegir distribuciones, evitar la falacia de los promedios y modelar la dependencia.',
  ),
  Module(
    id: 'm3',
    number: 3,
    title: 'Análisis',
    theme: 'Estimaciones',
    question: '¿Qué dice la distribución de resultados, cuánto confiar en ella y cómo decidir con ella?',
    summary: 'Percentiles, curva S y probabilidad de riesgo; cuántas iteraciones bastan; eventos raros; sensibilidad y validación.',
  ),
];

const List<Lesson> lessons = [
  // =========================================================== MÓDULO 1
  Lesson(
    id: 'l1_1',
    moduleId: 'm1',
    title: 'Estimar con azar',
    goal: 'Entender por qué lanzar puntos al azar permite calcular un número que no es aleatorio.',
    labId: 'lab_rain',
    cards: [
      LessonCard(
        title: 'Un número desconocido, un experimento',
        body: 'El método Monte Carlo convierte una cantidad que no sabemos calcular en el promedio de un experimento aleatorio que sí sabemos repetir. '
            'Si lanzamos puntos al azar en un cuadrado de lado 1, la fracción que cae dentro del cuarto de círculo tiende a su área, π/4. '
            'Multiplicando por 4 obtenemos π sin usar una sola fórmula de geometría.',
        formula: 'π ≈ 4 · (puntos dentro) / (puntos totales)',
        keyIdea: 'Monte Carlo = expresar lo que buscas como un promedio y estimar ese promedio repitiendo el azar.',
      ),
      LessonCard(
        title: 'Por qué funciona: ley de los grandes números',
        body: 'Cada punto es una variable indicadora: vale 1 si cae dentro y 0 si no. Su valor esperado es exactamente el área. '
            'La ley de los grandes números garantiza que el promedio de muchas indicadoras se acerca a ese valor esperado. '
            'No garantiza cuándo: con pocas repeticiones, el promedio todavía oscila.',
        formula: 'Ȳₙ = (Y₁ + … + Yₙ)/n  →  E[Y]  cuando n → ∞',
      ),
      LessonCard(
        title: 'Para qué sirve en tu carrera',
        body: 'Nadie usa Monte Carlo para calcular π. Se usa cuando la cantidad de interés depende de muchas entradas inciertas y no hay fórmula: '
            'la probabilidad de que un proyecto minero pierda dinero, el plazo real de una obra, la concentración de un contaminante, '
            'el tiempo de respuesta de un sistema o el riesgo de una cartera. π es el laboratorio donde se ve el método sin distracciones.',
        keyIdea: 'Si puedes simular un escenario, puedes estimar su probabilidad y su promedio.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Antes de ir al laboratorio, comprueba la idea central.',
        check: QuickCheck(
          question: 'De 1 000 puntos, 790 cayeron dentro del cuarto de círculo. ¿Cuál es la estimación de π?',
          options: ['0,79', '3,16', '3,14 exactamente'],
          correct: 1,
          explanation: '4 · 790/1 000 = 3,16. Es una estimación: otra corrida daría otro valor cercano.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l1_2',
    moduleId: 'm1',
    title: 'Fabricar el azar: generadores y semillas',
    goal: 'Saber de dónde salen los números aleatorios de una computadora y por qué la semilla importa.',
    labId: 'lab_generator',
    cards: [
      LessonCard(
        title: 'Pseudoaleatorios: una regla que parece azar',
        body: 'Una computadora no lanza dados. Aplica una regla determinista a un estado interno y produce una secuencia que pasa las pruebas estadísticas de azar. '
            'El estado inicial es la semilla: con la misma semilla, la secuencia es idéntica.',
        formula: 'LCG:  xₖ₊₁ = (a·xₖ + c) mod m,   uₖ = xₖ / m',
        keyIdea: 'Pseudoaleatorio no es un defecto: es lo que permite repetir y auditar una simulación.',
      ),
      LessonCard(
        title: 'Un buen generador pasa más que el histograma',
        body: 'Que los valores se repartan parejo entre 0 y 1 es necesario, no suficiente. También deben ser independientes: conocer uₖ no debe decir nada de uₖ₊₁. '
            'Los generadores congruenciales con parámetros pobres producen histogramas planos, pero sus pares consecutivos caen sobre pocas rectas y la secuencia se repite cada m números. '
            'Esta app usa xoshiro128**, con periodo 2¹²⁸ − 1.',
      ),
      LessonCard(
        title: 'La semilla en un informe profesional',
        body: 'Un resultado de simulación se reporta con el generador, la semilla y el número de iteraciones. Así otra persona puede reproducirlo exactamente. '
            'Cambiar la semilla no es hacer trampa: es obtener otra muestra, y ver cuánto cambia el resultado es una forma directa de medir su error.',
        keyIdea: 'Semilla fija = reproducible. Varias semillas = una idea del error.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Una pregunta sobre semillas.',
        check: QuickCheck(
          question: 'Dos analistas corren el mismo modelo con la misma semilla y el mismo generador. ¿Qué obtienen?',
          options: ['Resultados parecidos', 'Exactamente el mismo resultado', 'Resultados independientes'],
          correct: 1,
          explanation: 'La secuencia pseudoaleatoria es la misma, así que cada iteración es idéntica.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l1_3',
    moduleId: 'm1',
    title: 'De la uniforme a cualquier distribución',
    goal: 'Transformar números uniformes en tiempos de falla, dados cargados o cualquier variable con distribución conocida.',
    labId: 'lab_generator',
    cards: [
      LessonCard(
        title: 'La transformada inversa',
        body: 'Si U es uniforme en (0, 1) y F es la función de distribución acumulada de la variable que quieres, entonces X = F⁻¹(U) tiene exactamente esa distribución. '
            'Gráficamente: marcas u en el eje vertical, vas horizontalmente hasta la curva F y bajas al eje x.',
        formula: 'X = F⁻¹(U)     ⇔     P(X ≤ x) = P(U ≤ F(x)) = F(x)',
        keyIdea: 'Se invierte la acumulada F, que va de 0 a 1, nunca la densidad f.',
      ),
      LessonCard(
        title: 'Ejemplo: tiempo entre fallas',
        body: 'Para una exponencial con media 2 h, F(x) = 1 − e^(−x/2). Despejando, x = −2·ln(1 − u). '
            'Donde la acumulada sube rápido (tiempos cortos) caen muchos valores de u: por eso la exponencial produce muchos tiempos cortos y pocos largos. '
            'La mediana es {{exp_median}} h, menor que la media.',
        formula: 'x = −media · ln(1 − u)',
      ),
      LessonCard(
        title: 'Variables discretas: tramos',
        body: 'Para un dado cargado con P(6) = 0,5 y 0,1 para las demás caras, se parte [0, 1) en tramos de largo 0,1; 0,1; 0,1; 0,1; 0,1 y 0,5. '
            'La cara es la del tramo donde cae u. Multiplicar u por 6 y redondear produciría un dado equilibrado: ignoraría las probabilidades.',
        keyIdea: 'Cada valor recibe un tramo de [0, 1) tan largo como su probabilidad.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Transformada inversa en acción.',
        check: QuickCheck(
          question: 'Con la exponencial de media 2 h, u = 0,5 produce x = −2·ln(0,5). ¿Qué representa ese valor?',
          options: ['La media', 'La mediana', 'El valor más probable'],
          correct: 1,
          explanation: 'u = 0,5 deja la mitad de la probabilidad a cada lado: es la mediana, {{exp_median}} h.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l1_4',
    moduleId: 'm1',
    title: 'Toda estimación tiene error',
    goal: 'Cuantificar el error de una estimación Monte Carlo y reportarla con su intervalo.',
    labId: 'lab_rain',
    cards: [
      LessonCard(
        title: 'El error estándar',
        body: 'La estimación Monte Carlo es un promedio de n valores independientes. Su desviación típica, el error estándar, es s/√n, donde s es la desviación de un valor individual. '
            'Para π con dardos, s = {{pi_se_coef}}; con 1 000 dardos el error estándar es {{pi_se_1000}}.',
        formula: 'EE = s / √n        IC 95 % ≈ Ȳ ± 1,96 · s/√n',
        keyIdea: 'Reporta «3,15 ± 0,10 (IC 95 %)», no «π = 3,15».',
      ),
      LessonCard(
        title: 'Precisión no es riesgo',
        body: 'El error estándar mide cuánto confiar en la estimación de la media; baja con más iteraciones. '
            'La desviación de la salida mide cuánto varía el resultado del sistema real (el riesgo); no baja con más iteraciones, solo se estima mejor.',
        formula: 's → riesgo del sistema     s/√n → precisión de tu estimación',
      ),
      LessonCard(
        title: 'No todos los estimadores son iguales',
        body: 'El área bajo e^(−x²) entre 0 y 1 ({{area_true}}) puede estimarse lanzando puntos (acierto-fallo, s = {{area_sd_hit}}) o promediando f(U) (valor medio, s = {{area_sd_mean}}). '
            'Con el mismo n, el segundo tiene menor error: equivale a usar {{area_var_ratio}} veces más iteraciones con el primero.',
        keyIdea: 'La precisión depende de n y de la varianza del estimador.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Precisión y n.',
        check: QuickCheck(
          question: 'Una estimación tiene error estándar 0,08 con 400 iteraciones. ¿Qué error estándar esperas con 1 600?',
          options: ['0,02', '0,04', '0,08'],
          correct: 1,
          explanation: 'Cuatro veces más iteraciones divide el error entre √4 = 2.',
        ),
      ),
    ],
  ),

  // =========================================================== MÓDULO 2
  Lesson(
    id: 'l2_1',
    moduleId: 'm2',
    title: 'Anatomía de un modelo de simulación',
    goal: 'Construir un modelo: entradas inciertas, fórmula y salidas que responden una pregunta de decisión.',
    labId: 'lab_project',
    cards: [
      LessonCard(
        title: 'Entradas → modelo → salida',
        body: 'Un modelo de simulación tiene tres partes. Las entradas inciertas se describen con distribuciones (precio, demanda, duración). '
            'El modelo es la fórmula o la lógica que las combina (VAN, plazo, utilidad). La salida es lo que interesa decidir. '
            'Cada iteración toma una muestra de cada entrada, calcula la salida y la guarda.',
        formula: 'para k = 1..n:  xₖ ~ entradas;  yₖ = g(xₖ);  guardar yₖ',
      ),
      LessonCard(
        title: 'Los cinco pasos',
        body: '1) Formular la pregunta de decisión (¿probabilidad de perder?, ¿plazo con 90 % de confianza?). '
            '2) Construir el modelo determinista y verificarlo con valores conocidos. '
            '3) Reemplazar las entradas inciertas por distribuciones. '
            '4) Simular n iteraciones con semilla registrada. '
            '5) Analizar la distribución de la salida y comunicar con percentiles y probabilidades.',
        keyIdea: 'La pregunta de decisión define qué salida mirar y con qué umbral.',
      ),
      LessonCard(
        title: 'Ejemplo guía: un proyecto de inversión',
        body: 'Un proyecto invierte 550 mil soles y durante 5 años vende Q miles de unidades con margen P − c. Con tasa del 10 %, el factor de anualidad es {{npv_annuity}}. '
            'El VAN es g = {{npv_annuity}}·(P − c)·Q − 550. Precio, costo y volumen son triangulares, estimados por expertos.',
        formula: 'VAN = anualidad(10 %; 5) · (P − c) · Q − I',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Partes del modelo.',
        check: QuickCheck(
          question: 'En el modelo del proyecto, ¿cuál es la salida?',
          options: ['El precio P', 'El VAN', 'La tasa de descuento'],
          correct: 1,
          explanation: 'P es una entrada incierta; la tasa es un parámetro fijo; el VAN es lo que se decide.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l2_2',
    moduleId: 'm2',
    title: 'Elegir las distribuciones de entrada',
    goal: 'Escoger la distribución de cada entrada según lo que se sabe de ella, no por costumbre.',
    labId: 'lab_traps',
    cards: [
      LessonCard(
        title: 'Qué distribución y cuándo',
        body: 'Uniforme: solo se conoce el rango. Triangular: un experto da mínimo, más probable y máximo. '
            'Normal: sumas de muchos efectos pequeños, errores de medición. Lognormal: magnitudes positivas con cola a la derecha (costos, leyes de mineral, concentraciones). '
            'Exponencial: tiempo hasta un evento que ocurre al azar. Bernoulli: ocurre o no ocurre.',
        keyIdea: 'La distribución resume lo que sabes. Si no sabes la forma, empieza por lo que sí sabes: el rango y el valor más creíble.',
      ),
      LessonCard(
        title: 'La normal no sirve para todo',
        body: 'Una normal con media 100 y desviación 50 da valores negativos el {{shape_normal_neg}} de las veces, absurdo para un costo. '
            'Una lognormal con la misma media y desviación nunca es negativa y tiene una cola derecha más pesada: P(X > 200) es {{shape_lognormal_tail}}, frente a {{shape_normal_tail}} de la normal.',
        keyIdea: 'La forma de la entrada decide el tamaño de la cola, y la cola es el riesgo.',
      ),
      LessonCard(
        title: 'De datos o de expertos',
        body: 'Con datos históricos, se ajusta la distribución y se revisa el ajuste en las colas. Sin datos, se entrevista a expertos por mínimo, más probable y máximo, '
            'y se pregunta también «¿qué tan raro sería superar el máximo?»: los expertos suelen dar rangos demasiado estrechos.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Elegir distribución.',
        check: QuickCheck(
          question: 'La ley de cobre de un bloque es positiva y, de vez en cuando, muy alta. ¿Qué distribución es más razonable?',
          options: ['Normal', 'Lognormal', 'Uniforme'],
          correct: 1,
          explanation: 'Positiva y con cola derecha: lognormal. La normal daría leyes negativas.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l2_3',
    moduleId: 'm2',
    title: 'La falacia de los promedios',
    goal: 'Reconocer cuándo el escenario promedio no da el resultado promedio.',
    labId: 'lab_traps',
    cards: [
      LessonCard(
        title: 'g(promedio) ≠ promedio de g',
        body: 'Si el modelo es lineal, poner cada entrada en su media da la salida media. Si hay mínimos, máximos, umbrales o productos, no. '
            'Una planta con capacidad 100 y demanda media 100 no vende 100 en promedio: los días de demanda alta no puede venderlos y los de demanda baja no los recupera. '
            'Vende en promedio {{cap_expected_sales}}.',
        formula: 'E[min(D, C)] ≤ min(E[D], C)',
        keyIdea: 'Los planes basados en promedios fallan en promedio (Savage).',
      ),
      LessonCard(
        title: 'Más probable no es esperado',
        body: 'En el proyecto, el escenario más probable (precio 10, costo 6, volumen 50) da VAN {{npv_mode}}. Pero las triangulares son asimétricas: '
            'el precio puede bajar más de lo que sube y el volumen también. El VAN medio es {{npv_mean}} y la probabilidad de perder es {{npv_ploss}}.',
      ),
      LessonCard(
        title: 'El sesgo de las rutas paralelas',
        body: 'Dos cuadrillas en paralelo, cada una con duración media {{merge_task_mean}} días: el plan dice 9 + 5 = 14. '
            'Pero la obra espera a la más lenta. Con una ruta se cumple el {{merge_p_one}} de las veces; con dos, el {{merge_p_two}}. El plazo medio real es {{merge_mean_total}} días.',
        formula: 'E[max(A, B)] ≥ max(E[A], E[B])',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Detectar la falacia.',
        check: QuickCheck(
          question: '¿En cuál modelo el escenario promedio sí da la salida promedio (entradas independientes)?',
          options: ['Costo total = X₁ + X₂', 'Ventas = min(D, C)', 'Plazo = max(A, B) + C'],
          correct: 0,
          explanation: 'La suma es lineal: E[X₁ + X₂] = E[X₁] + E[X₂]. Mínimos y máximos no lo son.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l2_4',
    moduleId: 'm2',
    title: 'Dependencia entre entradas',
    goal: 'Incluir la correlación cuando las entradas se mueven juntas y entender su efecto en el riesgo.',
    labId: 'lab_traps',
    cards: [
      LessonCard(
        title: 'Varianzas que se suman',
        body: 'Para entradas independientes se suman las varianzas, no las desviaciones: dos costos con desviación 20 dan un total con desviación √(20² + 20²) = {{corr_sd_0}}, no 40. '
            'Sumar desviaciones exagera el riesgo de lo independiente; ignorar correlaciones lo subestima.',
        formula: 'Var(X₁ + X₂) = σ₁² + σ₂² + 2ρσ₁σ₂',
      ),
      LessonCard(
        title: 'Cuando suben juntas',
        body: 'Mano de obra y materiales suelen subir juntos por la inflación o el tipo de cambio. Con ρ = 0,8, la desviación del total sube a {{corr_sd_08}} y el percentil 95 pasa de {{corr_p95_0}} a {{corr_p95_08}}. '
            'Con correlación negativa (una cobertura), el riesgo baja.',
        keyIdea: 'Suponer independencia es una decisión de modelado, no un valor por defecto inocente.',
      ),
      LessonCard(
        title: 'Cómo se simula la correlación',
        body: 'El simulador usa una cópula gaussiana: convierte las uniformes de dos entradas en normales, las mezcla con z₂ = ρ·z₁ + √(1 − ρ²)·z y las devuelve a uniformes antes de la transformada inversa. '
            'Así cada entrada conserva su distribución y el par adquiere la dependencia pedida.',
        formula: 'z₂ = ρ·z₁ + √(1 − ρ²)·z',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Correlación y riesgo.',
        check: QuickCheck(
          question: 'Dos riesgos con correlación positiva se simulan como independientes. ¿Qué pasa con el P95 del total?',
          options: ['Se sobrestima', 'Se subestima', 'No cambia'],
          correct: 1,
          explanation: 'La correlación positiva ensancha la distribución del total; ignorarla estrecha la cola.',
        ),
      ),
    ],
  ),

  // =========================================================== MÓDULO 3
  Lesson(
    id: 'l3_1',
    moduleId: 'm3',
    title: 'Leer la distribución de resultados',
    goal: 'Describir una salida simulada con media, mediana, percentiles, histograma y curva S.',
    labId: 'lab_reading',
    cards: [
      LessonCard(
        title: 'Histograma y curva S',
        body: 'El histograma muestra dónde se concentran los resultados. La curva S (acumulada) responde directamente «¿qué probabilidad hay de quedar por debajo de x?». '
            'Se lee subiendo desde un valor del eje x hasta la curva, o entrando por una probabilidad y bajando al valor.',
        keyIdea: 'La curva S convierte montos en probabilidades y probabilidades en montos.',
      ),
      LessonCard(
        title: 'Percentiles: P10, P50, P90',
        body: 'P90 es el valor que no se supera en el 90 % de las iteraciones. No es un valor con 90 % de probabilidad de ser superado. '
            'Para un costo lognormal con mediana {{sc_median}}, P10 = {{sc_p10}} y P90 = {{sc_p90}}.',
        formula: 'P(Y ≤ P90) = 0,90',
      ),
      LessonCard(
        title: 'Media y mediana se separan',
        body: 'En salidas asimétricas, la media se va hacia la cola. En ese costo, la media es {{sc_mean}}, por encima de la mediana: presupuestar la media deja una probabilidad de sobrecosto de {{sc_p_over_mean}}, no de 50 %.',
        keyIdea: 'Reporta la media, la mediana y un rango de percentiles, nunca un solo número.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Percentiles.',
        check: QuickCheck(
          question: 'El P90 del plazo es 18 días. ¿Qué significa?',
          options: ['Hay 90 % de probabilidad de tardar más de 18 días', 'Hay 90 % de probabilidad de terminar en 18 días o menos', 'El plazo medio es 18 días'],
          correct: 1,
          explanation: 'P90 deja el 90 % de los resultados por debajo.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l3_2',
    moduleId: 'm3',
    title: 'Riesgo y decisión',
    goal: 'Traducir la simulación en probabilidades de riesgo y usarlas para decidir con criterio explícito.',
    labId: 'lab_reading',
    cards: [
      LessonCard(
        title: 'La probabilidad del umbral',
        body: 'La mayoría de las decisiones tiene un umbral: VAN < 0, plazo > contrato, concentración > límite. La simulación estima P(cruzar el umbral) como la fracción de iteraciones que lo cruzan. '
            'Que la media esté del lado seguro no dice nada de esa probabilidad.',
        formula: 'p̂ = (iteraciones que cruzan) / n',
      ),
      LessonCard(
        title: 'Medidas de cola',
        body: 'El percentil 5 de la utilidad (o 95 del costo) es el «valor en riesgo»: el resultado malo que se supera solo 1 de cada 20 veces. '
            'La media de ese 5 % peor es el déficit esperado: cuán malo es lo malo cuando ocurre.',
      ),
      LessonCard(
        title: 'Dos alternativas, dos perfiles',
        body: 'La opción A da utilidad media 120 con desviación 80; la B, media 100 con desviación 15. A pierde dinero el {{cmp_a_ploss}} de las veces y su P5 es {{cmp_a_p5}}; el P5 de B es {{cmp_b_p5}}. '
            'Ninguna es «la correcta»: depende de cuánto riesgo tolera quien decide. La simulación hace visible el intercambio; no decide por ti.',
        keyIdea: 'Decidir es elegir entre perfiles de riesgo con un criterio explícito, no maximizar la media.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Umbral y media.',
        check: QuickCheck(
          question: 'La concentración media es {{amb_mean}} y el límite es 50. ¿Qué puedes concluir sobre excedencias?',
          options: ['No hay excedencias', 'Hay que estimar P(C > 50) con la distribución', 'Las excedencias son el 34 %'],
          correct: 1,
          explanation: 'La media no dice cuánta probabilidad hay en la cola por encima del límite.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l3_3',
    moduleId: 'm3',
    title: '¿Cuántas iteraciones? Eventos raros',
    goal: 'Calcular cuántas iteraciones hacen falta para una precisión dada y tratar probabilidades pequeñas.',
    labId: 'lab_precision',
    cards: [
      LessonCard(
        title: 'La ley de √n',
        body: 'El error estándar es s/√n. Para reducir el error a la mitad hacen falta cuatro veces más iteraciones; para dividirlo entre 10, cien veces más. '
            'Con π: {{pi_se_100}} con 100 dardos, {{pi_se_400}} con 400, {{pi_se_1600}} con 1 600, {{pi_se_6400}} con 6 400.',
        formula: 'n necesario = (1,96 · s / E)²  para semiamplitud E',
        keyIdea: 'Precisión cuesta cuadráticamente: pide la precisión que la decisión necesita, no más.',
      ),
      LessonCard(
        title: 'Probabilidades: el error depende de p',
        body: 'Para una probabilidad, s = √(p(1 − p)). Con p = 0,002 y 1 000 iteraciones se esperan solo 2 casos: el error relativo es {{rare_relse_1000}} de p. '
            'Con 10 000 baja a {{rare_relse_10000}}. Para un error relativo del 10 % harían falta {{rare_n_rel10}} iteraciones.',
        formula: 'error relativo ≈ √((1 − p) / (n·p))',
      ),
      LessonCard(
        title: 'Cero casos no es probabilidad cero',
        body: 'Con p = 0,002 y 100 iteraciones, el {{rare_p0_100}} de las corridas no ve ningún caso. Si observas 0 casos en n iteraciones, la cota superior al 95 % es aproximadamente 3/n (regla del tres): '
            'con 1 000 iteraciones, p < {{rare_rule3_1000}}.',
        keyIdea: 'Reporta «p < 3/n», nunca «p = 0».',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Eventos raros.',
        check: QuickCheck(
          question: 'En 600 iteraciones no hubo ninguna falla. ¿Qué reportas?',
          options: ['P(falla) = 0', 'P(falla) < 0,5 % aproximadamente (3/600)', 'P(falla) = 1/600'],
          correct: 1,
          explanation: 'Regla del tres: 3/600 = 0,005.',
        ),
      ),
    ],
  ),
  Lesson(
    id: 'l3_4',
    moduleId: 'm3',
    title: 'Sensibilidad y validación',
    goal: 'Identificar qué entrada manda en el resultado y comprobar que el modelo representa el sistema.',
    labId: 'lab_reading',
    cards: [
      LessonCard(
        title: 'Gráfico de tornado',
        body: 'La correlación de rangos entre cada entrada y la salida indica cuánto la mueve. En el proyecto, el precio explica cerca de {{tornado_share_price}} de la varianza del VAN, '
            'el volumen {{tornado_share_volume}} y el costo {{tornado_share_cost}}, aunque el volumen tenga el mayor rango en unidades.',
        keyIdea: 'La influencia depende de la incertidumbre de la entrada y de cómo entra en el modelo, no de su rango en bruto.',
      ),
      LessonCard(
        title: 'Para qué sirve la sensibilidad',
        body: 'Dice dónde vale la pena reducir incertidumbre (un estudio de mercado del precio) y qué entradas pueden fijarse sin perder mucho. '
            'También detecta errores: si una entrada que debería importar no aparece, revisa la fórmula.',
      ),
      LessonCard(
        title: 'Validar antes de confiar',
        body: 'Más iteraciones hacen más precisa la respuesta del modelo, no la del mundo. Verifica la fórmula con valores conocidos, compara con datos históricos, revisa que las entradas no produzcan valores imposibles '
            'y declara los supuestos (independencia, distribuciones, horizonte). «Basura entra, basura sale» con 100 000 iteraciones sigue siendo basura.',
        keyIdea: 'Precisión (n) y validez (modelo) son problemas distintos.',
      ),
      LessonCard(
        title: 'Autocomprobación',
        body: 'Convergencia y validez.',
        check: QuickCheck(
          question: 'Una simulación con 100 000 iteraciones tiene un IC muy estrecho. ¿Garantiza que el resultado es correcto?',
          options: ['Sí, el IC lo garantiza', 'No: garantiza precisión respecto del modelo, no que el modelo sea correcto'],
          correct: 1,
          explanation: 'El IC mide el error de muestreo, no el error de especificación.',
        ),
      ),
    ],
  ),
];

Lesson? lessonById(String id) {
  for (final l in lessons) {
    if (l.id == id) return l;
  }
  return null;
}

Module moduleById(String id) => modules.firstWhere((m) => m.id == id);

List<Lesson> lessonsOf(String moduleId) =>
    [for (final l in lessons) if (l.moduleId == moduleId) l];
