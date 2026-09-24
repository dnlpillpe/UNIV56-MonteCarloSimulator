# 05 · Arquitectura técnica (fase 6)

## 1. Stack

| Capa | Elección | Por qué |
|---|---|---|
| UI | Flutter 3.35.4 (Material 3, tema oscuro único) | Estándar de la fábrica; un código para Android e iOS |
| Estado | `flutter_riverpod` 2.6 con `Notifier` (sin generación de código) | Sin `build_runner` en CI; pruebas con `ProviderContainer` |
| Persistencia | `shared_preferences` | Local-first; sin secretos |
| Gráficos | `CustomPainter` propios | La geometría es el contenido; sin librerías de gráficos |
| IA | `dart:io` `HttpClient` | Opcional, sin dependencias |
| Dependencias de producción | **2** (`flutter_riverpod`, `shared_preferences`) | Menos superficie de fallo en CI |

## 2. Capas

```
presentation  ──►  domain  ◄──  data
(pantallas,        (Dart puro:   (SharedPreferences,
 pintores,          motor,        HTTP de la IA)
 Riverpod)          contenido,
                    analista)
core: RNG, distribuciones, estadística, formato, tema
```

`domain/` y `core/math`, `core/rng`, `core/util` no importan Flutter: 5 de las 7 suites de prueba no dependen de widgets.

## 3. Módulos

```
lib/
├── main.dart · app.dart
├── core/
│   ├── rng/random_source.dart        xoshiro128**, SplitMix32, LCG del laboratorio, FNV-1a
│   ├── math/special.dart             Φ (Hart/West), Φ⁻¹ (Acklam + Halley), binomial
│   ├── math/distributions.dart       7 distribuciones por transformada inversa
│   ├── math/stats.dart               media, varianza, cuantiles, rangos, Spearman, Wilson, Welford
│   ├── theme/                        colores-concepto y tema
│   └── util/format.dart              coma decimal, miles, lectura de números del estudiante
├── domain/
│   ├── sim/expression.dart           tokenizador + parser descendente → cierres compilados
│   ├── sim/model_spec.dart           InputSpec, CorrelationSpec, ModelSpec (JSON)
│   ├── sim/simulation_engine.dart    CompiledModel (cópula gaussiana), SimulationRun
│   ├── sim/result_summary.dart       percentiles, umbral, cola, sensibilidad, n necesario
│   ├── sim/templates.dart            8 plantillas
│   ├── content/                      lecciones, labs, ejercicios, casos, confusiones, glosario, cifras
│   ├── labs/experiment_logic.dart    lógica pura de los 16 experimentos
│   ├── analyst/                      motor de hallazgos, router, guardia, analista híbrido
│   └── progress/                     estado, dominio, diagnóstico, corrección, práctica generativa
├── data/                             repositorios y clientes HTTP
└── presentation/
    ├── shell · home · learn · labs (+ 6 archivos de vistas) · simulator · analyst · practice · cases · glossary · about
    ├── painters/                     chart_base, point_painters, distribution_painters, brand_painter
    └── widgets/common.dart           tarjetas, fichas, alternativas, leyendas
```

## 4. Modelo de datos

- **Contenido** (`const`): `Module`, `Lesson`/`LessonCard`/`QuickCheck`, `Lab`, `ExperimentDef`/`PredictionOption`, `Exercise`/`Option`/`WrongPattern`, `CaseStudy`, `Confusion`, `GlossaryTerm`, `Figure`.
- **Modelo de simulación** (JSON): `ModelSpec { inputs: [InputSpec{name, kind, params}], expression, outputName, threshold, side, correlation }`.
- **Progreso** (JSON en `progress_v1`): lecciones vistas, hallazgos, predicciones iniciales, mejor puntaje y primer intento por ítem, evidencia por confusión, contadores.
- **Ajustes de IA** (`ai_settings_v1`): proveedor, clave, modelo, URL base.

## 5. Decisiones técnicas

1. **Transformada inversa para todo**: una uniforme por entrada → la correlación por cópula gaussiana es trivial y el método es el mismo que se enseña.
2. **Fórmulas compiladas a cierres**: se analiza una vez; cada iteración es una llamada directa (100 000 iteraciones en fracciones de segundo).
3. **Prefijos reproducibles**: la corrida de n+k iteraciones con la misma semilla contiene exactamente a la de n; los laboratorios «agregan» iteraciones re-simulando con la misma semilla.
4. **Cifras con `{{id}}`**: el texto nunca contiene un número calculado a mano; `renderFigures` los formatea.
5. **Observaciones con `[[clave]]`**: el hallazgo combina lo que observó el estudiante con lo teórico.
6. **Plataformas generadas en CI**: `android/` e `ios/` no se versionan; `tool/postcreate.py` las parchea (nombre, INTERNET, firma), probado contra las plantillas reales de `flutter create` 3.35.4 (Kotlin DSL).
7. **Flutter fijado, Gradle no**: se fija la versión de Flutter y se deja que su plantilla elija AGP/Gradle/Kotlin compatibles (decisión heredada de Probability Master).

## 6. Rendimiento

- Simulador: hasta 100 000 iteraciones; sensibilidad sobre submuestra de 20 000 pares.
- Laboratorios: el más pesado (réplicas de √n) ejecuta 40 × 8 500 dardos ≈ 340 000 pares.
- Pintores: submuestreo de la curva S a ~400 puntos y de nubes a 2 500–4 000 puntos.
