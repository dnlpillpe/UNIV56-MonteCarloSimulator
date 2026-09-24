import 'model_spec.dart';

/// Plantillas del simulador libre. Cada una encarna una idea del curso y
/// es el punto de partida para que el estudiante modifique entradas y
/// fórmula.
const List<ModelSpec> modelTemplates = [
  ModelSpec(
    id: 'proyecto_van',
    title: 'Proyecto de inversión (VAN)',
    description:
        'Un proyecto a 5 años con tasa de descuento del 10 %. El precio, el costo '
        'unitario y el volumen son inciertos; la inversión es conocida. '
        '¿Cuál es la probabilidad de perder dinero?',
    inputs: [
      InputSpec(name: 'P', kind: DistKind.triangular, params: [8, 10, 11], description: 'Precio de venta', unit: 'S/ por unidad'),
      InputSpec(name: 'c', kind: DistKind.triangular, params: [5.5, 6, 7], description: 'Costo unitario', unit: 'S/ por unidad'),
      InputSpec(name: 'Q', kind: DistKind.triangular, params: [30, 50, 55], description: 'Volumen anual', unit: 'miles de unidades'),
      InputSpec(name: 'I', kind: DistKind.constant, params: [550], description: 'Inversión inicial', unit: 'miles de S/'),
    ],
    expression: 'anualidad(0.10; 5) * (P - c) * Q - I',
    outputName: 'VAN',
    outputUnit: 'miles de S/',
    threshold: 0,
    side: ThresholdSide.below,
    thresholdMeaning: 'perder dinero (VAN negativo)',
  ),
  ModelSpec(
    id: 'capacidad',
    title: 'Capacidad de planta',
    description:
        'La demanda diaria es incierta y la planta no puede producir más de su '
        'capacidad. Las ventas son min(D; C). ¿Cuánto se gana en promedio?',
    inputs: [
      InputSpec(name: 'D', kind: DistKind.normal, params: [100, 25], description: 'Demanda diaria', unit: 'unidades'),
      InputSpec(name: 'C', kind: DistKind.constant, params: [100], description: 'Capacidad', unit: 'unidades'),
      InputSpec(name: 'm', kind: DistKind.constant, params: [30], description: 'Margen por unidad', unit: 'S/'),
      InputSpec(name: 'F', kind: DistKind.constant, params: [1500], description: 'Costo fijo diario', unit: 'S/'),
    ],
    expression: 'm * min(D; C) - F',
    outputName: 'Utilidad diaria',
    outputUnit: 'S/',
    threshold: 0,
    side: ThresholdSide.below,
    thresholdMeaning: 'tener pérdida en el día',
  ),
  ModelSpec(
    id: 'plazo_paralelo',
    title: 'Plazo con tareas en paralelo',
    description:
        'Dos cuadrillas trabajan en paralelo (A y B) y después viene la tarea C. '
        'La obra termina cuando terminan ambas. El plan dice 14 días.',
    inputs: [
      InputSpec(name: 'A', kind: DistKind.triangular, params: [5, 8, 14], description: 'Tarea A', unit: 'días'),
      InputSpec(name: 'B', kind: DistKind.triangular, params: [5, 8, 14], description: 'Tarea B', unit: 'días'),
      InputSpec(name: 'C', kind: DistKind.constant, params: [5], description: 'Tarea C', unit: 'días'),
    ],
    expression: 'max(A; B) + C',
    outputName: 'Plazo total',
    outputUnit: 'días',
    threshold: 14,
    side: ThresholdSide.above,
    thresholdMeaning: 'atrasarse respecto del plan de 14 días',
  ),
  ModelSpec(
    id: 'costos_correlacionados',
    title: 'Presupuesto con costos correlacionados',
    description:
        'Mano de obra y materiales suben y bajan juntos (inflación, tipo de '
        'cambio). Cambia la correlación y observa el percentil 95.',
    inputs: [
      InputSpec(name: 'X1', kind: DistKind.normal, params: [100, 20], description: 'Mano de obra', unit: 'miles de S/'),
      InputSpec(name: 'X2', kind: DistKind.normal, params: [100, 20], description: 'Materiales', unit: 'miles de S/'),
    ],
    expression: 'X1 + X2',
    outputName: 'Costo total',
    outputUnit: 'miles de S/',
    threshold: 250,
    side: ThresholdSide.above,
    thresholdMeaning: 'superar el presupuesto de 250',
    correlation: CorrelationSpec('X1', 'X2', 0.6),
  ),
  ModelSpec(
    id: 'inventario',
    title: 'Inventario de un solo periodo',
    description:
        'Compras q unidades a S/ 2, vendes a S/ 5 y lo que sobra se remata a '
        'S/ 0,50. La demanda es incierta. ¿Conviene pedir la demanda media?',
    inputs: [
      InputSpec(name: 'D', kind: DistKind.triangular, params: [40, 60, 100], description: 'Demanda', unit: 'unidades'),
      InputSpec(name: 'q', kind: DistKind.constant, params: [70], description: 'Cantidad pedida', unit: 'unidades'),
    ],
    expression: '5 * min(D; q) + 0.5 * pos(q - D) - 2 * q',
    outputName: 'Utilidad',
    outputUnit: 'S/',
    threshold: 0,
    side: ThresholdSide.below,
    thresholdMeaning: 'perder dinero',
  ),
  ModelSpec(
    id: 'estimar_pi',
    title: 'Estimar π con dardos',
    description:
        'U y V son un punto al azar en el cuadrado unitario. La fórmula vale 4 '
        'si el punto cae dentro del cuarto de círculo y 0 si no: su media es π.',
    inputs: [
      InputSpec(name: 'U', kind: DistKind.uniform, params: [0, 1], description: 'Coordenada x'),
      InputSpec(name: 'V', kind: DistKind.uniform, params: [0, 1], description: 'Coordenada y'),
    ],
    expression: '4 * (U^2 + V^2 <= 1)',
    outputName: 'Estimación de π',
  ),
  ModelSpec(
    id: 'riesgo_ambiental',
    title: 'Concentración de un contaminante',
    description:
        'La emisión es positiva y asimétrica (lognormal) y la dispersión depende '
        'del clima. ¿Con qué frecuencia se supera el límite de 80?',
    inputs: [
      InputSpec(name: 'E', kind: DistKind.lognormal, params: [50, 20], description: 'Emisión', unit: 'µg/m³ equivalentes'),
      InputSpec(name: 'k', kind: DistKind.uniform, params: [0.5, 1.5], description: 'Factor de dispersión'),
    ],
    expression: 'E * k',
    outputName: 'Concentración',
    outputUnit: 'µg/m³',
    threshold: 80,
    side: ThresholdSide.above,
    thresholdMeaning: 'superar el límite ambiental',
  ),
  ModelSpec(
    id: 'libre',
    title: 'Modelo en blanco',
    description:
        'Dos uniformes sumadas. Cambia las distribuciones, agrega variables y '
        'escribe tu propia fórmula.',
    inputs: [
      InputSpec(name: 'X1', kind: DistKind.uniform, params: [0, 1]),
      InputSpec(name: 'X2', kind: DistKind.uniform, params: [0, 1]),
    ],
    expression: 'X1 + X2',
    outputName: 'Y',
  ),
];

ModelSpec templateById(String id) =>
    modelTemplates.firstWhere((m) => m.id == id, orElse: () => modelTemplates.first);
