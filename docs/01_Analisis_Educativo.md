# 01 · Análisis educativo y validación académica (fases 1 y 2)

## 1. Problema real de aprendizaje

La simulación Monte Carlo aparece en Estadística, Investigación Operativa, Simulación de Sistemas, Evaluación de Proyectos, Finanzas, Gestión de Riesgos, Confiabilidad y Evaluación Ambiental. Se enseña casi siempre como **procedimiento en hoja de cálculo**: `ALEATORIO()`, una fórmula copiada hacia abajo, un promedio. El estudiante aprueba y sale sin poder responder:

- ¿Cuánto error tiene ese promedio? ¿Cuántas filas necesito?
- ¿Por qué el resultado no coincide con el «caso base»?
- ¿Qué significa P90? ¿Qué probabilidad hay de perder?
- ¿Y si dos entradas se mueven juntas? ¿Y si no vi ningún caso de falla?

## 2. Usuario objetivo

Estudiantes de pregrado (3.º a 8.º ciclo) de cualquier carrera con un curso de probabilidad o estadística aprobado; docentes que necesitan un laboratorio sin licencias. Uso en móvil, sin conexión, en sesiones de 10–20 minutos.

## 3. Fallos tratables (diagnóstico)

| Id | Fallo | Evidencia típica | Confusiones asociadas |
|---|---|---|---|
| F1 | Una corrida es «la» respuesta | Reporta π = 3,19 sin intervalo | `una_corrida_es_verdad`, `sin_semilla` |
| F2 | El error baja con n | Duplica n esperando la mitad de error | `error_lineal_n`, `se_vs_sd`, `estimadores_iguales` |
| F3 | Falacia de los promedios | Planifica ventas con la demanda media; plazo = máximo de medias | `promedio_de_entradas`, `mas_probable_es_esperado`, `paralelo_sin_sesgo` |
| F4 | Modelo de entradas pobre | Normal para costos; independencia por defecto; suma desviaciones | `normal_para_todo`, `ignorar_correlacion`, `sumar_desviaciones`, `uniforme_directa`, `inversa_con_densidad` |
| F5 | Lectura pobre de la salida | Solo la media; P90 al revés; media bajo el límite ⇒ «sin riesgo» | `solo_la_media`, `media_es_tipico`, `percentil_invertido`, `media_bajo_limite_seguro`, `decision_por_media` |
| F6 | Eventos raros | «0 fallas en 1 000 ⇒ imposible» | `cero_casos_cero_prob`, `eventos_raros_pocas_iter` |
| F7 | Precisión ≠ validez | «Con 100 000 iteraciones debe estar bien» | `mas_n_corrige_modelo`, `sensibilidad_por_rango`, `pseudo_es_azar_real`, `histograma_prueba_calidad` |
| F8 | Acertar sin entender | Elige bien por la razón equivocada | `acertar_sin_entender` |

## 4. Competencia profesional

*Construir, ejecutar y comunicar un estudio de simulación que cuantifique el riesgo de una decisión, con su precisión, sus supuestos y su sensibilidad.*

## 5. Validación académica

| Curso relacionado | Tópicos cubiertos |
|---|---|
| Probabilidad y Estadística | LGN, error estándar, IC, cuantiles, transformada inversa, suma de varianzas |
| Simulación de Sistemas / IO | Generadores, semillas, validación, número de réplicas, sesgo de fusión |
| Evaluación de Proyectos / Finanzas | VAN estocástico, P(VAN<0), VaR/P5, déficit esperado, comparación de alternativas |
| Gestión de Riesgos / Confiabilidad | Umbrales, eventos raros, regla del tres, correlación de riesgos |
| Gestión de Operaciones | Capacidad, inventario de un periodo (razón crítica) |

**Conceptos difíciles priorizados:** √n, precisión vs. riesgo (s/√n vs. s), no linealidad (E[g(X)] ≠ g(E[X])), forma de las colas, lectura de percentiles, cero casos.

**Aplicación profesional:** 11 casos (Minas, Sistemas, Electrónica, Ambiental, Administración, Economía, Contabilidad, Psicología, Biología, Humanidades, Desarrollo personal), cada uno con una decisión real y cifras calculadas.

## 6. Lugar en el catálogo

Probability Master (el azar) → Random Variables Lab (cantidades aleatorias) → **Monte Carlo Simulator (simular para decidir)** → Inferencia / Regression Lab. Es la primera app del catálogo donde el estudiante **construye sus propios modelos** además de explorar los preparados.
