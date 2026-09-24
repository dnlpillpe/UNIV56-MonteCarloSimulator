# 02 · Diseño de la experiencia educativa (fase 3) e identidad visual

## 1. Cómo aprende el estudiante

**Ciclo del laboratorio — Predice → Simula → Explica**

1. **Predice.** Pregunta cerrada con 3–4 alternativas; cada distractor representa una intuición habitual (catalogada). Los controles de simulación están bloqueados hasta elegir.
2. **Simula.** Botones de repeticiones (+10, +100, +1 000…), animación, deslizadores y «Otra semilla». Un indicador muestra cuántas repeticiones faltan.
3. **Explica.** Al llegar al mínimo, se desbloquea el hallazgo: combina las **cifras observadas** de la corrida del estudiante (`[[clave]]`) con las **cifras teóricas** del motor (`{{id}}`), una idea clave y la revisión de la predicción («tu intuición fue X; la intuición habitual se llama Y»).

La primera predicción de cada experimento se guarda como *intuición inicial* y nunca resta.

## 2. Navegación

| Pestaña | Contenido |
|---|---|
| Inicio | Marca, «continúa donde te quedaste», dominio por módulo, diagnóstico de confusiones con remedios, actividad |
| Aprender | 3 módulos → lecciones (tarjetas deslizables con autocomprobación) y laboratorios |
| Simulador | Modelo: entradas, fórmula, umbral, correlación; corrida (n, semilla); resultados en 4 vistas |
| Práctica | Ejercicios por módulo, práctica generativa, 11 casos por carrera |
| Analista | Hallazgos de la última corrida y conversación (motor + IA opcional) |

## 3. Actividades

| Tipo | Cantidad | Propósito |
|---|---|---|
| Lecciones | 12 (48 tarjetas) | Idea mínima + fórmula + idea clave + autocomprobación |
| Experimentos | 16 | Refutar intuiciones con evidencia propia |
| Simulador libre | 8 plantillas + 9 modelos de casos | Transferir: construir y modificar modelos |
| Ejercicios | 36 | Evaluar comprensión (4 formatos) |
| Práctica generativa | ilimitada | Automatizar: EE, n necesario, √n, regla del tres |
| Casos | 11 × 3 pasos | Decidir en contexto profesional |

## 4. Evaluación

- **Regla 60/40** en decisiones: elección 0,6 + justificación 0,4. Decisión correcta con justificación incorrecta registra `acertar_sin_entender`.
- **Errores numéricos reconocibles:** 25 patrones (s en lugar de s/√n, sumar desviaciones, olvidar el cuadrado en n, usar la media en vez de la razón crítica…).
- **Diagnóstico:** +1 al cometer una confusión, −0,5 al evitarla después, ×0,97 por ítem respondido. Evidencia ≥ 1 → aparece en Inicio con su remedio (lección y experimento).
- **Dominio por módulo:** 15 % lecciones + 15 % laboratorios + 70 % práctica; «Competente» exige 0,70 en el total **y** en la práctica.
- **Acierto ciego:** tasa de primeros intentos correctos.

## 5. Identidad visual

**Metáfora:** la noche de tapete verde del casino de Monte Carlo (que da nombre al método) + la nube de puntos computacional.

**Cada color es un concepto** y significa lo mismo en toda la app:

| Color | Hex | Concepto |
|---|---|---|
| Verde menta | `#3DDC97` | Modelo, valor teórico, curva exacta |
| Cian | `#45C4E0` | Muestras observadas, histogramas |
| Dorado | `#F5B83D` | Estimación Monte Carlo (trazas de convergencia, media simulada) |
| Naranja | `#FF8A4C` | Riesgo: colas, pérdidas, umbral |
| Violeta | `#A58BFF` | Incertidumbre de la estimación: EE, IC, bandas ±2·EE |
| Rojo rosado | `#FF5C7A` | Solo confusiones detectadas |
| Noche | `#0B2521` | Fondo |

**Colores por módulo:** 1 cian (azar), 2 naranja (riesgo), 3 violeta (estimaciones).

**Icono:** lluvia de puntos sobre el cuarto de círculo —el experimento con el que se explica el método— con los puntos dentro en cian, fuera en naranja, el arco en verde (el modelo) y el último dardo en dorado (la estimación). `tool/generate_icon.py` lo genera con los mismos puntos (xoshiro128**, semilla 2026) que dibuja `BrandPainter` dentro de la app.

## 6. Accesibilidad

Gráficos con etiqueta `Semantics`; los colores nunca son la única señal (las cifras acompañan a cada gráfico); objetivos táctiles ≥ 48 px; textos con ajuste de línea; probado en ancho de 360 px lógicos. Pendiente: auditoría de contraste WCAG AA.
