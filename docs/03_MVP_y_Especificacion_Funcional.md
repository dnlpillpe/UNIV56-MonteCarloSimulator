# 03 · MVP y especificación funcional (fase 4)

## 1. Alcance del MVP (incluido)

| Id | Funcionalidad | Criterio de aceptación |
|---|---|---|
| RF-01 | 3 módulos con 4 lecciones cada uno | La lección se marca vista al llegar a la última tarjeta |
| RF-02 | 16 experimentos Predice → Simula → Explica | Controles bloqueados hasta predecir; hallazgo al mínimo de repeticiones; semilla visible y cambiable |
| RF-03 | Simulador libre | Hasta N entradas con 7 distribuciones; fórmula con 10 funciones; umbral; una correlación; 1 000–100 000 iteraciones; semilla |
| RF-04 | Resultados | Histograma con cola de riesgo, curva S con sonda, convergencia ±2·EE, tornado; 9 indicadores |
| RF-05 | Analista determinista | ≥ 10 tipos de hallazgo; 11 intenciones de pregunta; umbral de honestidad |
| RF-06 | IA opcional | Anthropic u OpenAI-compatible; guardia numérica; respaldo del motor ante error o cifra inventada |
| RF-07 | Práctica | 36 ítems en 4 formatos con retroalimentación por alternativa |
| RF-08 | Práctica generativa | 4 temas, parámetros aleatorios, alimenta solo el diagnóstico |
| RF-09 | Casos | 11 carreras × 3 pasos; «Abrir en el simulador» cuando el modelo es expresable |
| RF-10 | Progreso y diagnóstico | Persistencia local; dominio 15/15/70; confusiones con remedio |
| RF-11 | Glosario y Acerca de | 47 términos con búsqueda; explicación del icono y la paleta |

## 2. Fuera del MVP (futuro)

- Cuentas, sincronización y panel docente (Firebase) — se difiere para que CI compile sin secretos.
- Más de una correlación (matriz completa con Cholesky) y distribuciones empíricas cargadas desde CSV.
- Técnicas de reducción de varianza como laboratorio propio (variables antitéticas, muestreo estratificado).
- Simulación de colas y eventos discretos (merece su propia app).
- Exportar informe PDF de una corrida.

## 3. Especificación del simulador

**Distribuciones:** Constante(v) · Uniforme(mín; máx) · Triangular(mín; más probable; máx) · Normal(media; desviación) · Lognormal(media; desviación) · Exponencial(media) · Bernoulli(p). Todas por transformada inversa.

**Fórmula:** números con punto decimal, variables, `+ − * / ^`, comparaciones `< <= > >=` (1/0), `pi`, `e`, y `min`, `max`, `pos`, `abs`, `sqrt`, `exp`, `ln`, `round`, `si(c; a; b)`, `anualidad(r; n)`. Argumentos separados por `;` o `,`. Errores con posición.

**Correlación:** una pareja de entradas con ρ ∈ (−0,95; 0,95) por cópula gaussiana; conserva las distribuciones marginales.

**Salida:** media, IC 95 % de la media, desviación, mediana, P1–P99, asimetría, P(umbral) con IC de Wilson, déficit esperado del 5 % del lado del riesgo, salida con entradas en su media y en su moda, sensibilidad (Spearman), fracción de negativos en entradas normales, iteraciones inválidas descartadas.

## 4. Reglas de negocio

- La misma semilla produce exactamente la misma corrida; una corrida más larga con la misma semilla extiende a la corta.
- Una fórmula que da NaN o infinito descarta la iteración y lo informa.
- Cambiar el modelo marca los resultados como desactualizados.
- La predicción de un experimento se registra una sola vez como intuición inicial.
- El mejor puntaje de cada ítem cuenta para el dominio; el primero, para el acierto ciego.

## 5. Validación del MVP (cómo saber que funciona)

- Pre/post de 8 preguntas (una por fallo F1–F8) en dos secciones de un curso.
- Métrica principal: reducción de la evidencia media por confusión tras dos semanas de uso.
- Métrica secundaria: acierto ciego en la segunda mitad de los ítems vs. la primera.
