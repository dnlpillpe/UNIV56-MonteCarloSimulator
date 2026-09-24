import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/sim/model_spec.dart';
import '../../domain/sim/result_summary.dart';
import '../labs/views/experiment_views.dart';
import '../painters/chart_base.dart';
import '../painters/distribution_painters.dart';
import '../painters/point_painters.dart';
import '../widgets/common.dart';

enum ResultView { histogram, scurve, convergence, tornado }

/// Resultados de una corrida: indicadores y cuatro vistas.
class ResultsPanel extends StatefulWidget {
  const ResultsPanel({super.key, required this.summary});
  final ResultSummary summary;

  @override
  State<ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends State<ResultsPanel> {
  ResultView _view = ResultView.histogram;
  double? _probe;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final spec = s.spec;
    final u = spec.outputUnit.isEmpty ? '' : ' ${spec.outputUnit}';
    final (lo, hi) = displayRangeOf(s.run.outputs);
    final t = spec.threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ResultView>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ResultView.histogram, icon: Icon(Icons.bar_chart), tooltip: 'Histograma'),
            ButtonSegment(value: ResultView.scurve, icon: Icon(Icons.show_chart), tooltip: 'Curva S'),
            ButtonSegment(value: ResultView.convergence, icon: Icon(Icons.timeline), tooltip: 'Convergencia'),
            ButtonSegment(value: ResultView.tornado, icon: Icon(Icons.align_horizontal_center), tooltip: 'Sensibilidad'),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
        const SizedBox(height: 6),
        Text(
          switch (_view) {
            ResultView.histogram => 'Histograma de «${spec.outputName}»',
            ResultView.scurve => 'Curva S: probabilidad de no superar cada valor',
            ResultView.convergence => 'Convergencia de la media (±2 EE)',
            ResultView.tornado => 'Sensibilidad: correlación de rangos con la salida',
          },
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        switch (_view) {
          ResultView.histogram => ChartBox(
              height: 230,
              semanticLabel: 'Histograma de la salida',
              painter: HistogramPainter(
                values: s.run.outputs,
                lo: lo,
                hi: hi,
                bins: 36,
                threshold: t,
                riskBelow: spec.side == ThresholdSide.below,
                markers: [
                  ChartMarker(s.mean, 'media', AppColors.estimate, dashed: false),
                  ChartMarker(s.median, 'P50', AppColors.uncertainty),
                ],
              ),
            ),
          ResultView.scurve => Column(
              children: [
                ChartBox(
                  height: 230,
                  semanticLabel: 'Curva S de la salida',
                  painter: CdfPainter(
                    sorted: s.sorted,
                    lo: lo,
                    hi: hi,
                    threshold: _probe ?? t ?? s.median,
                    riskAbove: spec.side == ThresholdSide.above,
                    markers: [
                      ChartMarker(s.p(10), 'P10', AppColors.uncertainty),
                      ChartMarker(s.p(90), 'P90', AppColors.uncertainty),
                    ],
                  ),
                ),
                Slider(
                  value: math.min(hi, math.max(lo, _probe ?? t ?? s.median)),
                  min: lo,
                  max: hi,
                  onChanged: (v) => setState(() => _probe = v),
                ),
              ],
            ),
          ResultView.convergence => ChartBox(
              height: 230,
              semanticLabel: 'Convergencia de la media',
              painter: ConvergencePainter(
                traces: [s.run.trace],
                truth: s.mean,
                seCoef: s.sd,
                yLo: s.mean - 4 * s.sd / math.sqrt(math.max(10, math.min(s.n, 50))),
                yHi: s.mean + 4 * s.sd / math.sqrt(math.max(10, math.min(s.n, 50))),
                nMax: s.n,
              ),
            ),
          ResultView.tornado => ChartBox(
              height: math.max(120.0, 44.0 * s.sensitivities.length + 30),
              semanticLabel: 'Gráfico de tornado',
              painter: TornadoPainter(items: s.sensitivities),
            ),
        },
        if (_view == ResultView.convergence)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'La línea verde es la media final; las violetas, el margen ±2·s/√n que se estrecha con más iteraciones.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        StatGrid(children: [
          StatTile(label: 'Media', value: '${fmtNum(s.mean)}$u', color: AppColors.estimate),
          StatTile(label: 'IC 95 % de la media', value: '±${fmtNum(s.halfWidth95)}', color: AppColors.uncertainty, hint: 'Precisión de la estimación: baja con √n'),
          StatTile(label: 'Desviación', value: fmtNum(s.sd), color: AppColors.risk, hint: 'Variabilidad del resultado: el riesgo'),
          StatTile(label: 'Mediana (P50)', value: fmtNum(s.median)),
          StatTile(label: 'P10', value: fmtNum(s.p(10))),
          StatTile(label: 'P90', value: fmtNum(s.p(90))),
          if (t != null)
            StatTile(
              label: 'P(${spec.side.symbol} ${fmtNum(t)})',
              value: fmtPct(s.thresholdProb!),
              color: AppColors.risk,
            ),
          StatTile(label: 'Iteraciones', value: fmtInt(s.n)),
          StatTile(label: 'Semilla', value: '${s.run.seed}'),
        ]),
        if (s.run.invalidCount > 0) ...[
          const SizedBox(height: 8),
          InfoBanner(
            text: '${fmtInt(s.run.invalidCount)} iteraciones dieron un valor no numérico y se descartaron. Revisa la fórmula.',
            color: AppColors.confusion,
            icon: Icons.warning_amber,
          ),
        ],
      ],
    );
  }
}
