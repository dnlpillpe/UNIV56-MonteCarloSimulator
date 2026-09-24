# 07 · Pruebas y control de calidad

## 1. Suites (`flutter test`)

| Archivo | Qué prueba | Casos |
|---|---|---|
| `core_test.dart` | xoshiro128** (determinismo, uniformidad, independencia), LCG de periodo 256, FNV-1a, Φ y Φ⁻¹, binomial, 5 distribuciones (F(F⁻¹(u)) = u y momentos simulados), cuantiles, rangos, Spearman, Welford, Wilson, formato y lectura de números | 19 |
| `sim_test.dart` | Lenguaje de fórmulas (precedencia, funciones, errores), 17 modelos (plantillas + casos) compilan y corren, reproducibilidad por semilla y prefijo, π, VAN, capacidad, correlación (conserva marginales), rutas paralelas, casos ambiental y psicología contra cifras cerradas, errores de modelo, iteraciones inválidas, n necesario (4× para la mitad de error), JSON | 18 |
| `content_test.dart` | **114 cifras del motor Dart contra la réplica SciPy**, todas las marcas `{{id}}`, estructura de 3 módulos, ids únicos, confusiones producidas, **los 69 ítems** (respuesta correcta = 1, distractores = 0, regla 60/40, errores numéricos reconocidos, orden barajado), **los 16 experimentos** hasta su mínimo, y 5 comprobaciones estadísticas de laboratorios | 210 |
| `analyst_test.dart` | Hallazgos (riesgo, modas, promedios, pocas iteraciones, regla del tres, negativos, forma), router de 11 intenciones y umbral de honestidad, **las cifras del motor pasan su propia guardia**, extracción de números en formato español, IA verificada aceptada, IA que inventa descartada, sin red → motor | 16 |
| `progress_test.dart` | Dominio 15/15/70 y umbral doble, diagnóstico +1/−0,5/×0,97, confusiones activas, acierto ciego, JSON, práctica generativa (100 preguntas) | 6 |
| `widget_test.dart` | Arranque, 5 pestañas, **simular → analizar → preguntar**, fórmula inválida, editor de entradas, plantillas | 6 |
| `screens_test.dart` | **12 lecciones** recorridas, **16 experimentos predice → simula → explica en pantalla**, 6 laboratorios, 3 módulos con su práctica, ejercicio con distractor y reintento, error numérico reconocido en pantalla, **11 casos**, práctica generativa, glosario, acerca de | 52 |
| **Total** | | **327** |

Las pruebas de pantalla usan una vista de **360 px lógicos** de ancho (1080 × 18000 físicos a 3×): cualquier desborde en teléfono hace fallar la prueba.

## 2. Verificación previa sin SDK (Python)

| Herramienta | Qué hace |
|---|---|
| `tool/replica.py` | Recalcula las 114 cifras con métodos distintos (SciPy: distribuciones exactas, `quad`, binomial exacta) y escribe `test/fixtures/figures.json` |
| `tool/verify_content.py` | Cifras y confusiones citadas existen; ninguna confusión sin distractor; referencias a lecciones/labs/experimentos; ids únicos; una sola alternativa correcta; cada error numérico se distingue de la respuesta; cada `[[clave]]` la produce su lógica |
| `tool/static_check.py` | Parser real de Dart (tree-sitter): sintaxis, imports, símbolos del proyecto importados en cada archivo, argumentos con nombre y `required` de constructores, miembros estáticos (`Icons.x`, `AppColors.x`, enums). Con `--ref` usa las fuentes de Flutter, Riverpod y el SDK de Dart |

Resultados de esta entrega: réplica 114/114; transliteración de los algoritmos Dart (Φ de Hart, Φ⁻¹ de Acklam, cuadratura del VAN, Simpson del máximo) a Python: 0 discrepancias; error máximo de Φ 2·10⁻¹⁶ y de Φ⁻¹ 5·10⁻¹⁰ frente a SciPy; contenido íntegro; verificación estática sin problemas contra las fuentes de Flutter 3.35.4, Riverpod 2.6.1, Dart 3.9.2 y shared_preferences.

## 3. Hallazgos corregidos durante el desarrollo

- `ShowValueIndicator.always` está obsoleto en Flutter 3.35 → `onDrag` (detectado al contrastar con las fuentes).
- `math.max(0, x)` devolvía `num` en el intervalo de Wilson, en el diagnóstico y en el pintor de marca → literales `0.0`.
- `(next[c] ?? 0) + 1` producía `num` en un `Map<String, double>`.
- El congruencial del laboratorio se eligió (a = 37, m = 256) tras dibujar sus pares: 8 rectas visibles y periodo completo.
- La figura `amb_days` se redondeaba en la réplica y no en Dart.
- `SegmentedButton` con textos largos desbordaba a 360 px → `ChoiceRow` con fichas que saltan de línea.
- Las declaraciones de firma en Kotlin DSL deben ir **después** del bloque `plugins {}`.
- Un umbral de 0,6 de participación coincidía con el valor real del precio (0,599): la prueba ahora verifica el orden de sensibilidad, no el título.

## 4. Limitaciones conocidas

- No se ha compilado ni ejecutado en dispositivo desde el entorno de generación: la primera puerta es `ci.yml`.
- El verificador estático no infiere tipos; los riesgos int/double se revisaron a mano.
- Los laboratorios con azar se verifican contra cifras cerradas con tolerancias de 4–5 errores estándar.
- El router del analista es léxico: preguntas muy alejadas del vocabulario reciben la respuesta honesta de «fuera de alcance».
