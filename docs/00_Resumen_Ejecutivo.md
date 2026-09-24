# 00 · Resumen ejecutivo — Monte Carlo Simulator

**Encargo:** enseñar simulación probabilística mediante experimentos computacionales (azar, riesgo, estimaciones), en tres módulos —Concepto Monte Carlo, Simulación, Análisis— con un **analista de resultados** de IA. Entregar Flutter, GitHub, APK y ZIP.

**Tesis del producto:** el problema no es correr una simulación sino **leerla**. Una planilla con 10 000 filas no enseña que el error baja con √n, que el escenario promedio no es el promedio de los escenarios, ni que «0 casos» no significa «imposible». La app hace que el estudiante *prediga*, *vea fallar su intuición* y *explique* por qué.

## Qué se entregó

| Elemento | Cantidad |
|---|---|
| Módulos (los pedidos, en su orden) | 3 |
| Lecciones / tarjetas | 12 / 48 |
| Laboratorios / experimentos Predice → Simula → Explica | 6 / 16 |
| Plantillas del simulador libre | 8 (+ 9 modelos de casos) |
| Ítems de práctica (opción, numérico, decisión 60/40, orden) | 36 |
| Casos profesionales (11 carreras × 3 pasos) | 11 / 33 |
| Confusiones catalogadas (todas producidas por algún distractor) | 25 |
| Errores numéricos reconocibles por su valor | 25 |
| Cifras del contenido calculadas por el motor y verificadas con SciPy | 114 |
| Glosario | 47 términos |
| Archivos Dart (lib + test) / líneas | 70 / ≈ 14 200 |
| Casos de prueba | 327 |

## Seis decisiones que definen la app

1. **Predice → Simula → Explica** en los 16 experimentos (controles bloqueados hasta predecir; hallazgo bloqueado hasta el mínimo de repeticiones; la primera predicción es «intuición inicial» y no resta).
2. **El azar es visible y reproducible:** xoshiro128** con semilla mostrada; «Otra semilla» es parte del aprendizaje, no un botón de reintento.
3. **Ningún número escrito a mano:** 114 cifras con `{{id}}`, calculadas por el motor y recalculadas por una réplica Python independiente (SciPy).
4. **El error se reconoce por su número:** si el estudiante escribe s en lugar de s/√n, o suma desviaciones, la app nombra la confusión.
5. **Analista híbrido:** motor determinista siempre; IA opcional que solo redacta y pasa por una guardia numérica.
6. **Cada color es un concepto** (verde = modelo, cian = muestras, dorado = estimación, naranja = riesgo, violeta = incertidumbre, rojo = confusión). Icono: lluvia de puntos sobre el cuarto de círculo.

## Estado

Construida y verificada sin SDK de Flutter en el entorno de generación (sin acceso a pub.dev ni a los binarios de Flutter): réplica numérica, integridad de contenido, sintaxis con parser real de Dart y argumentos con nombre contra las fuentes de Flutter 3.35.4. **Primera puerta real: el workflow `ci.yml`.** Pendiente antes de uso institucional: revisión de los casos por docentes de cada carrera, prueba en dispositivo, contraste WCAG AA y clave de firma de producción.
