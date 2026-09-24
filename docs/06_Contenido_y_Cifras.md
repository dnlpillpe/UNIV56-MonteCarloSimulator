# 06 · Catálogo de contenido y cifras

Las cifras entre llaves se calculan en `lib/domain/content/figures.dart` y se verifican contra `tool/replica.py` (SciPy). Los valores mostrados aquí son los de la réplica, redondeados.

## 1. Laboratorios y experimentos

| Lab | Experimento | Se manipula | Hallazgo (cifras del motor) |
|---|---|---|---|
| Lluvia de puntos | Dardos para π | +dardos, animación, semilla | s = 1,642 por dardo; EE con 1 000 = 0,052; ±0,01 exige ≈ 103 600 dardos |
| | Dos estimadores, una misma área | +iteraciones | Área 0,7468; s acierto-fallo 0,435 vs. valor medio 0,201 ⇒ equivale a 4,7× iteraciones |
| | Cinco semillas | +dardos | Con 500 dardos, 95 % de las corridas a menos de ±0,14 |
| Fábrica de azar | Un generador defectuoso | LCG (a = 37, c = 1, m = 256) vs. xoshiro | Histograma plano, pares en rectas, periodo 256; misma semilla = misma secuencia |
| | Transformada inversa | u → F → x | Exponencial media 2 h: 63,2 % bajo la media; mediana 1,39 h |
| | Dado cargado | tramos de [0, 1) | P(6) = 0,5 por tramos, no escalando u |
| Riesgo en proyectos | VAN de un proyecto | +iteraciones | Más probable 208; media 47; P(VAN < 0) = 37,8 % |
| | Dos rutas en paralelo | una / dos rutas | Cumplir 14 días: 53,7 % → 28,8 %; plazo medio 15,07 |
| Trampas del modelo | Falacia: capacidad | capacidad 60–160 | Ventas medias 90,0 (no 100): −10,0 %; utilidad 1 201 (no 1 500) |
| | Riesgos que se mueven juntos | ρ −0,9 a 0,9 | σ total 28,3 → 37,9; P95 246,5 → 262,4 (ρ = 0,8); 232,9 con ρ = −0,5 |
| | La forma de la entrada | normal / lognormal | P(X > 200): 2,28 % vs. 4,42 %; la normal da 2,28 % de negativos |
| Precisión y eventos raros | ¿Cuánto mejora con n? | 40 réplicas por n | EE 0,164 → 0,082 → 0,041 → 0,021 |
| | Eventos raros | n = 100 / 1 000 / 10 000 | p = 0,002: sin casos el 81,9 % (n = 100) y el 13,5 % (n = 1 000); error relativo 71 % y 22 % |
| Leer y decidir | Curva S y percentiles | presupuesto | Lognormal mediana 100: media 119,7; P90 215,7; presupuestar la media deja 38,2 % de sobrecosto |
| | Dos opciones, dos riesgos | +iteraciones | A: P(pérdida) 6,68 %, P5 −11,6; B: P5 75,3 |
| | ¿Qué entrada manda? | +iteraciones | Varianza explicada: precio 58 %, volumen 26 %, costo 15 % |

## 2. Casos profesionales

| Carrera | Caso | Cifras clave | Simulable |
|---|---|---|---|
| Ing. de Minas | ¿Mineral o desmonte? | P(ley < 0,5 %) = 22,4 %; mediana 0,72 % | Sí |
| Ing. de Sistemas | Tres microservicios y un SLA | P(≤ 200 ms) = 82,8 %; mejorar C → 90,3 %; mejorar B → 85,3 % | Sí |
| Ing. Electrónica | Tolerancia en serie | σ total 0,5 (no 0,866); fuera de ±1 kΩ: 4,17 % | Sí |
| Ing. Ambiental | Media bajo el límite | P(C > 50) = 15,3 % ⇒ ≈ 56 días/año | Sí |
| Administración | ¿Cuánto pedir? | Razón crítica 0,667; q* = 80 (no 70); utilidad 180 vs. 176,25 | Sí |
| Economía | Diez años con riesgo | P(pérdida) = 10,3 %; mediana 1,82 vs. media 2,04 | Sí |
| Contabilidad | Cero errores en la muestra | Cota 3/150 = 2 %; P(0 | 3 %) = 1,04 % | No (cálculo) |
| Psicología | Aprobar adivinando | P(≥ 10 de 20) = 1,39 %; 6,9 de 500 | Sí (20 Bernoulli) |
| Biología | Crecer y desaparecer | P(N20 < N0/2) = 11,1 % | Sí |
| Humanidades | Coincidencia en un archivo | P(cumpleaños, 30) = 70,6 %; 23 personas para 50 % | No (cálculo) |
| Desarrollo personal | Meta de ahorro | σ anual 346 (no 1 200); P(meta) = 61,4 %; P10–P90 3 156–4 044 | Sí (12 normales) |

## 3. Confusiones (25)

`una_corrida_es_verdad`, `error_lineal_n`, `mas_n_corrige_modelo`, `pseudo_es_azar_real`, `histograma_prueba_calidad`, `uniforme_directa`, `inversa_con_densidad`, `promedio_de_entradas`, `mas_probable_es_esperado`, `paralelo_sin_sesgo`, `ignorar_correlacion`, `sumar_desviaciones`, `normal_para_todo`, `media_es_tipico`, `solo_la_media`, `media_bajo_limite_seguro`, `cero_casos_cero_prob`, `percentil_invertido`, `se_vs_sd`, `sensibilidad_por_rango`, `decision_por_media`, `estimadores_iguales`, `eventos_raros_pocas_iter`, `sin_semilla`, `acertar_sin_entender`.

Cada una tiene nombre, descripción, remedio y enlaces a lección y experimento; `tool/verify_content.py` exige que todas las produzca al menos un distractor.

## 4. Reglas de redacción

- Español neutro, coma decimal, espacio fino de miles.
- Ninguna cifra calculada escrita a mano: se usa `{{id}}`.
- Cada distractor tiene retroalimentación propia que explica **por qué** es tentador.
- Las predicciones nunca se califican: se contrastan.
