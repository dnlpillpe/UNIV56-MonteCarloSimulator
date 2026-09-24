import 'package:flutter/material.dart';

import '../../../core/math/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/format.dart';
import '../../../domain/labs/experiment_logic.dart';
import '../../painters/chart_base.dart';
import '../../painters/distribution_painters.dart';
import '../../painters/point_painters.dart';
import '../../widgets/common.dart';
import 'experiment_views.dart';

// ---------------------------------------------------------- E4 · generador
class GeneratorView extends StatelessWidget {
  const GeneratorView({super.key, required this.logic, required this.onChanged});
  final GeneratorLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final v = logic.values;
    final pairs = <Dot>[
      for (var i = 0; i + 1 < v.length && i < 3000; i++) Dot(v[i], v[i + 1], true),
    ];
    final period = logic.observedPeriod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceRow<bool>(
          options: const [(true, 'Congruencial pobre (m = 256)'), (false, 'xoshiro128**')],
          selected: logic.useLcg,
          onSelected: (v) {
            logic.setGenerator(v);
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        const Text('Histograma de los valores', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        ChartBox(
          height: 140,
          semanticLabel: 'Histograma de los números generados',
          painter: HistogramPainter(values: v, lo: 0, hi: 1, bins: 20),
        ),
        const SizedBox(height: 10),
        const Text('Pares consecutivos (uₖ, uₖ₊₁)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        SquareChart(
          maxSide: 280,
          semanticLabel: 'Pares consecutivos del generador',
          painter: ScatterPainter(dots: pairs, dotRadius: 1.8, version: v.length),
        ),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Números', value: fmtInt(v.length)),
          StatTile(
            label: 'Periodo observado',
            value: period == null ? 'no se repite' : fmtInt(period),
            color: period == null ? AppColors.model : AppColors.risk,
          ),
          StatTile(label: 'Media', value: v.isEmpty ? '—' : fmtFixed(mean(v), 3), color: AppColors.sample),
        ]),
        const SizedBox(height: 10),
        Text('Primeros valores con esta semilla: ${logic.firstValues.map((x) => fmtFixed(x, 4)).join('; ')}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RunBar(onAdd: (k) {
              logic.add(k);
              onChanged();
            }, steps: const [50, 300, 1000]),
            OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('¿Se repite con la misma semilla?'),
              onPressed: v.isEmpty
                  ? null
                  : () {
                      final ok = logic.reproduces();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Sí: regenerado con la misma semilla, la secuencia es idéntica. Eso es reproducibilidad.'
                            : 'La secuencia difiere.'),
                      ));
                    },
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------- E5 · inversa continua
class InverseView extends StatelessWidget {
  const InverseView({super.key, required this.logic, required this.onChanged, required this.onAnimate});
  final InverseExpLogic logic;
  final VoidCallback onChanged;
  final void Function(int) onAnimate;

  @override
  Widget build(BuildContext context) {
    final s = logic.samples;
    final recent = s.length <= 60 ? s : s.sublist(s.length - 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 210,
          semanticLabel: 'Acumulada de la exponencial con la proyección del último u',
          painter: InversePainter(dist: logic.dist, lo: 0, hi: 10, lastU: logic.lastU, lastX: logic.lastX, recent: recent),
        ),
        const SizedBox(height: 8),
        ChartBox(
          height: 150,
          semanticLabel: 'Histograma de tiempos simulados con la densidad teórica',
          painter: HistogramPainter(
            values: s,
            lo: 0,
            hi: 10,
            bins: 25,
            density: logic.dist.pdf,
            markers: [ChartMarker(logic.dist.mean, 'media 2 h', AppColors.estimate)],
          ),
        ),
        const SizedBox(height: 8),
        StatGrid(children: [
          StatTile(label: 'Tiempos', value: fmtInt(s.length)),
          StatTile(label: 'Menores que la media', value: s.isEmpty ? '—' : fmtPct(logic.fracBelowMean), color: AppColors.sample),
          StatTile(label: 'Último u → x', value: logic.lastU == null ? '—' : '${fmtFixed(logic.lastU!, 2)} → ${fmtFixed(logic.lastX!, 2)}', color: AppColors.estimate),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [1, 10, 100, 500], onAnimate: onAnimate, animateTotal: 500),
      ],
    );
  }
}

// -------------------------------------------------- E6 · inversa discreta
class DiscreteView extends StatelessWidget {
  const DiscreteView({super.key, required this.logic, required this.onChanged});
  final DiscreteLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final n = logic.n;
    final observed = [for (final c in logic.counts) n == 0 ? 0.0 : c / n];
    final hi = logic.lastFace == null ? null : logic.lastFace! - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tramos de [0, 1): cada cara recibe un largo igual a su probabilidad', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        SizedBox(
          height: 80,
          child: CustomPaint(
            painter: SegmentPainter(probs: logic.die.probs, labels: const ['1', '2', '3', '4', '5', '6'], lastU: logic.lastU, highlight: hi),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 10),
        ChartBox(
          height: 170,
          semanticLabel: 'Frecuencia observada de cada cara frente a la esperada',
          painter: BarsPainter(labels: const ['1', '2', '3', '4', '5', '6'], observed: observed, expected: logic.die.probs, highlight: hi),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.sample, 'frecuencia observada'), (AppColors.model, 'probabilidad'), (AppColors.estimate, 'último lanzamiento')]),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Lanzamientos', value: fmtInt(n)),
          StatTile(label: 'Frecuencia del 6', value: n == 0 ? '—' : fmtPct(observed[5]), color: AppColors.sample),
          StatTile(label: 'Último', value: logic.lastFace == null ? '—' : 'u = ${fmtFixed(logic.lastU!, 3)} → ${logic.lastFace}', color: AppColors.estimate),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [1, 10, 100, 500]),
      ],
    );
  }
}
