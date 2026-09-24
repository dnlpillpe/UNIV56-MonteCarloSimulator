import 'dart:math' as math;

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

// --------------------------------------------------------- E8 · capacidad
class CapacityView extends StatelessWidget {
  const CapacityView({super.key, required this.logic, required this.onChanged});
  final CapacityLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final d = logic.demands;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 210,
          semanticLabel: 'Histograma de la demanda con la capacidad marcada',
          painter: HistogramPainter(
            values: d,
            lo: 20,
            hi: 180,
            bins: 32,
            threshold: logic.capacity,
            riskBelow: false,
            density: logic.demand.pdf,
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.sample, 'demanda atendida'), (AppColors.risk, 'demanda perdida'), (AppColors.model, 'densidad')]),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Capacidad'),
            Expanded(
              child: Slider(
                value: logic.capacity,
                min: 60,
                max: 160,
                divisions: 20,
                label: fmtFixed(logic.capacity, 0),
                onChanged: (v) {
                  logic.capacity = v;
                  onChanged();
                },
              ),
            ),
            SizedBox(width: 36, child: Text(fmtFixed(logic.capacity, 0), textAlign: TextAlign.right)),
          ],
        ),
        StatGrid(children: [
          StatTile(label: 'Días simulados', value: fmtInt(d.length)),
          StatTile(label: 'Plan (demanda media)', value: fmtFixed(logic.planSales, 1)),
          StatTile(label: 'Ventas medias simuladas', value: d.isEmpty ? '—' : fmtFixed(logic.meanSales, 1), color: AppColors.estimate),
          StatTile(label: 'Teórico', value: fmtFixed(logic.theorySales, 1), color: AppColors.model),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [100, 1000, 5000], label: ' días'),
      ],
    );
  }
}

// ------------------------------------------------------ E10 · correlación
class CorrView extends StatelessWidget {
  const CorrView({super.key, required this.logic, required this.onChanged});
  final CorrLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final n = logic.z1.length;
    final dots = <Dot>[
      for (var i = 0; i < n && i < 2500; i++) Dot(logic.x1(i), logic.x2(i), true),
    ];
    final totals = logic.totals;
    final p95 = totals.isEmpty ? double.nan : quantileSorted(sortedCopy(totals), 0.95);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('ρ'),
            Expanded(
              child: Slider(
                value: logic.rho,
                min: -0.9,
                max: 0.9,
                divisions: 18,
                label: fmtFixed(logic.rho, 1),
                onChanged: (v) {
                  logic.rho = (v * 10).roundToDouble() / 10;
                  onChanged();
                },
              ),
            ),
            SizedBox(width: 40, child: Text(fmtFixed(logic.rho, 1), textAlign: TextAlign.right)),
          ],
        ),
        LayoutBuilder(builder: (context, c) {
          final side = math.min(c.maxWidth, 260.0);
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: CustomPaint(
                painter: ScatterPainter(dots: dots, x0: 20, x1: 180, y0: 20, y1: 180, dotRadius: 1.4, version: n),
                size: Size.infinite,
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        const Center(child: Text('Mano de obra (x) vs. materiales (y)', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        const SizedBox(height: 8),
        ChartBox(
          height: 170,
          semanticLabel: 'Histograma del costo total con el percentil 95',
          painter: HistogramPainter(
            values: totals,
            lo: 60,
            hi: 340,
            bins: 28,
            markers: [if (p95.isFinite) ChartMarker(p95, 'P95', AppColors.risk, dashed: false)],
          ),
        ),
        const SizedBox(height: 8),
        StatGrid(children: [
          StatTile(label: 'Pares', value: fmtInt(n)),
          StatTile(label: 'Desv. del total', value: totals.isEmpty ? '—' : fmtFixed(stdDev(totals), 1), color: AppColors.sample),
          StatTile(label: 'Teórica', value: fmtFixed(logic.theorySd, 1), color: AppColors.model),
          StatTile(label: 'P95 del total', value: p95.isNaN ? '—' : fmtFixed(p95, 1), color: AppColors.risk),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [100, 1000, 5000]),
      ],
    );
  }
}

// ------------------------------------------------------------ E11 · forma
class ShapeView extends StatelessWidget {
  const ShapeView({super.key, required this.logic, required this.onChanged});
  final ShapeLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final nv = logic.normalValues;
    final lv = logic.lognormalValues;
    final shown = logic.showLognormal ? lv : nv;
    final other = logic.showLognormal ? nv : lv;
    final dist = logic.showLognormal ? logic.lognormal.pdf : logic.normal.pdf;
    double frac(List<double> xs, bool Function(double) t) => xs.isEmpty ? double.nan : xs.where(t).length / xs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceRow<bool>(
          options: const [(false, 'Normal(100; 50)'), (true, 'Lognormal(100; 50)')],
          selected: logic.showLognormal,
          onSelected: (v) {
            logic.showLognormal = v;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        ChartBox(
          height: 220,
          semanticLabel: 'Histograma del costo con la cola sobre 200',
          painter: HistogramPainter(
            values: shown,
            values2: other,
            color2: AppColors.textMuted,
            lo: -60,
            hi: 360,
            bins: 42,
            threshold: 200,
            riskBelow: false,
            density: dist,
            markers: const [ChartMarker(0, '0', AppColors.confusion)],
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.sample, 'distribución elegida'), (AppColors.textMuted, 'la otra (contorno)'), (AppColors.risk, 'X > 200')]),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Valores', value: fmtInt(logic.us.length)),
          StatTile(label: 'P(X > 200) normal', value: nv.isEmpty ? '—' : fmtPct(frac(nv, (x) => x > 200), decimals: 2), color: AppColors.risk),
          StatTile(label: 'P(X > 200) lognormal', value: lv.isEmpty ? '—' : fmtPct(frac(lv, (x) => x > 200), decimals: 2), color: AppColors.risk),
          StatTile(label: 'Negativos (normal)', value: nv.isEmpty ? '—' : fmtPct(frac(nv, (x) => x < 0), decimals: 2), color: AppColors.confusion),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [100, 1000, 10000]),
      ],
    );
  }
}
