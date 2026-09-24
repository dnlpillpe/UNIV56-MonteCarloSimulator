import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/format.dart';
import '../../../domain/content/figures.dart';
import '../../../domain/labs/experiment_logic.dart';
import '../../painters/chart_base.dart';
import '../../painters/distribution_painters.dart';
import '../../widgets/common.dart';
import 'experiment_views.dart';

// --------------------------------------------------------- E14 · curva S
class SCurveView extends StatelessWidget {
  const SCurveView({super.key, required this.logic, required this.onChanged});
  final SCurveLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final has = logic.samples.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 240,
          semanticLabel: 'Curva S del costo con el presupuesto marcado',
          painter: CdfPainter(
            sorted: logic.sorted,
            lo: 0,
            hi: 350,
            threshold: has ? logic.budget : null,
            riskAbove: true,
            markers: has
                ? [
                    ChartMarker(logic.q(0.1), 'P10', AppColors.uncertainty),
                    ChartMarker(logic.q(0.5), 'P50', AppColors.uncertainty),
                    ChartMarker(logic.q(0.9), 'P90', AppColors.uncertainty),
                    ChartMarker(mean(logic.samples), 'media', AppColors.estimate, dashed: false),
                  ]
                : const [],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Presupuesto'),
            Expanded(
              child: Slider(
                value: logic.budget,
                min: 40,
                max: 300,
                divisions: 52,
                label: fmtFixed(logic.budget, 0),
                onChanged: (v) {
                  logic.budget = v;
                  onChanged();
                },
              ),
            ),
            SizedBox(width: 36, child: Text(fmtFixed(logic.budget, 0), textAlign: TextAlign.right)),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            ActionChip(
              label: const Text('Presupuestar la media'),
              onPressed: has
                  ? () {
                      logic.budget = math.min(300.0, math.max(40.0, mean(logic.samples)));
                      onChanged();
                    }
                  : null,
            ),
            ActionChip(
              label: const Text('Presupuestar el P90'),
              onPressed: has
                  ? () {
                      logic.budget = math.min(300.0, math.max(40.0, logic.q(0.9)));
                      onChanged();
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatGrid(children: [
          StatTile(label: 'Media', value: has ? fmtFixed(mean(logic.samples), 1) : '—', color: AppColors.estimate),
          StatTile(label: 'Mediana (P50)', value: has ? fmtFixed(logic.q(0.5), 1) : '—', color: AppColors.uncertainty),
          StatTile(label: 'P90', value: has ? fmtFixed(logic.q(0.9), 1) : '—', color: AppColors.uncertainty),
          StatTile(label: 'P(sobrecosto)', value: has ? fmtPct(logic.pOverBudget) : '—', color: AppColors.risk),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [500, 2000, 10000], label: ' iter.'),
      ],
    );
  }
}

// ------------------------------------------------------ E15 · comparación
class CompareView extends StatelessWidget {
  const CompareView({super.key, required this.logic, required this.onChanged});
  final CompareLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final has = logic.a.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 230,
          semanticLabel: 'Histogramas superpuestos de las opciones A y B',
          painter: HistogramPainter(
            values: logic.b,
            values2: logic.a,
            color: AppColors.sample,
            color2: AppColors.estimate,
            lo: -150,
            hi: 400,
            bins: 44,
            threshold: 0,
            riskBelow: true,
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.sample, 'B: Normal(100; 15)'), (AppColors.estimate, 'A: Normal(120; 80), contorno'), (AppColors.risk, 'pérdida')]),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.3), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
          children: [
            _row('', 'Opción A', 'Opción B', header: true),
            _row('Media', has ? fmtFixed(mean(logic.a), 1) : '—', has ? fmtFixed(mean(logic.b), 1) : '—'),
            _row('P(pérdida)', has ? fmtPct(logic.ploss(logic.a)) : '—', has ? fmtPct(logic.ploss(logic.b), decimals: 2) : '—'),
            _row('P5 (valor en riesgo)', has ? fmtFixed(logic.p5(logic.a), 1) : '—', has ? fmtFixed(logic.p5(logic.b), 1) : '—'),
            _row('Teórico P(pérdida)', figures['cmp_a_ploss']!.text, figures['cmp_b_ploss']!.text),
          ],
        ),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [100, 1000, 5000]),
      ],
    );
  }

  static TableRow _row(String a, String b, String c, {bool header = false}) {
    TextStyle st(Color col) => TextStyle(fontWeight: header ? FontWeight.w800 : FontWeight.w500, color: col, fontSize: 13);
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(a, style: st(AppColors.textMuted))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(b, style: st(AppColors.estimate))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(c, style: st(AppColors.sample))),
    ]);
  }
}
