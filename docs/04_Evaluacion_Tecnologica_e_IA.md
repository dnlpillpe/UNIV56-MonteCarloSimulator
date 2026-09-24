# 04 · Evaluación tecnológica e IA (fase 5)

## 1. Qué tecnología hace falta y cuál no

| Tecnología | Decisión | Razón |
|---|---|---|
| Simulación | **Sí, núcleo** | Es el objeto de aprendizaje. Motor propio en Dart puro: generador, 7 distribuciones, compilador de fórmulas, estadística |
| Visualización | **Sí, propia** | 9 pintores `CustomPainter`: la geometría es el concepto (embudo ±2·EE, cola coloreada, proyección u → F → x, tramos de [0, 1)) |
| Almacenamiento | Local | `shared_preferences`; local-first, sin cuentas en el MVP |
| Backend / Firebase | No en el MVP | Agregaría secretos al CI sin valor educativo inmediato |
| Realidad aumentada | No | No aporta a este tema |
| IA generativa | **Opcional, verificada** | Ver §2 |

## 2. El analista de resultados (IA pedida)

**Riesgo específico del tema:** en simulación, una cifra falsa luce igual de plausible que una verdadera (37,8 % y 42 % son ambas creíbles). Un modelo de lenguaje que calcula o redondea mal es peor que no tener asistente.

**Diseño híbrido:**

1. **Motor determinista (siempre, sin red).** `AnalystEngine` convierte la corrida en hallazgos con nivel y lección remedio: resumen; precisión (pocas iteraciones / mejorable / suficiente, con iteraciones necesarias para ±1 %); probabilidad del umbral con IC de Wilson y **regla del tres** si no hubo casos; asimetría (media vs. mediana); cola de riesgo (P5/P95 y déficit esperado); **falacia de los promedios** (salida con entradas en su media vs. media simulada); **escenario más probable** (modas vs. media); sensibilidad (Spearman, entrada dominante, entradas prescindibles); entradas normales con negativos; supuesto de independencia o correlación incluida; iteraciones inválidas; reproducibilidad y validez.
2. **Router de preguntas.** 11 intenciones (riesgo, precisión, percentiles, promedios, sensibilidad, forma, confianza, dependencia, semilla, media, decisión) con **umbral de honestidad**: si la pregunta no se responde con la corrida, lo dice. Ante «¿qué decido?» no decide: expone el intercambio y el criterio que falta.
3. **IA opcional (clave del usuario).** Anthropic Messages API o cualquier API compatible con OpenAI (incluido un proxy institucional), vía `dart:io`, sin dependencias. Recibe la ficha de datos en JSON, los hallazgos y la respuesta del motor, con la instrucción de no calcular.
4. **Guardia numérica.** Cada número del texto de la IA debe coincidir (±1,5 % o ±0,006; también como porcentaje de una proporción) con una cifra que el motor calculó. Si no, se descarta la respuesta y se muestra la del motor con una nota. Sin red o sin clave, responde el motor.

**Regla del proyecto:** *la IA redacta; el motor calcula.*

## 3. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| IA inventa cifras | Guardia numérica + respaldo del motor |
| IA decide por el estudiante | Instrucción de sistema + el motor responde «no decido por ti» |
| Clave expuesta | Solo en el dispositivo; se recomienda proxy institucional |
| Dependencia de red | La app completa funciona sin conexión |
| Costos | La IA solo se usa si el usuario la configura |
