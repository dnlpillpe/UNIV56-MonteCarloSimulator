import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/format.dart';
import '../../../domain/content/figures.dart';
import '../../../domain/labs/experiment_logic.dart';
import '../../painters/point_painters.dart';
import '../../widgets/common.dart';
import 'experiment_views.dart';

// ----------------------------------------------------------------- E1 · π
class PiView extends StatelessWidget {
  const PiView({super.key, required this.logic, required this.onChanged, required this.onAnimate});
  final PiLogic logic;
  final VoidCallback onChanged;
  final void Function(int) onAnimate;

  @override
  Widget build(BuildContext context) {
    final est = logic.estimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SquareChart(
          maxSide: 300,
          semanticLabel: 'Nube de ${logic.n} dardos sobre el cuarto de círculo',
          painter: ScatterPainter(dots: logic.dots, quarterCircle: true, version: logic.n),
        ),
        const SizedBox(height: 8),
        const ColorLegend(items: [
          (AppColors.sample, 'dentro'),
          (AppColors.risk, 'fuera'),
          (AppColors.model, 'cuarto de círculo'),
        ]),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Dardos', value: fmtInt(logic.n)),
          StatTile(label: 'Estimación de π', value: est.isNaN ? '—' : fmtFixed(est, 4), color: AppColors.estimate),
          StatTile(label: 'Error real', value: est.isNaN ? '—' : fmtFixed((est - math.pi).abs(), 4), color: AppColors.risk),
          StatTile(label: 'Error estándar', value: logic.n == 0 ? '—' : fmtFixed(logic.theoreticalSe, 4), color: AppColors.uncertainty),
        ]),
        const SizedBox(height: 10),
        ChartBox(
          height: 200,
          semanticLabel: 'Convergencia de la estimación de π',
          painter: ConvergencePainter(
            traces: [logic.trace],
            truth: math.pi,
            seCoef: figureValue('pi_se_coef'),
            yLo: 2.4,
            yHi: 3.9,
            version: logic.n,
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [
          (AppColors.estimate, 'estimación'),
          (AppColors.model, 'π'),
          (AppColors.uncertainty, '±2 EE'),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, onAnimate: onAnimate, animateTotal: 2000),
      ],
    );
  }
}

// --------------------------------------------------------------- E2 · área
class AreaView extends StatelessWidget {
  const AreaView({super.key, required this.logic, required this.onChanged, required this.onAnimate});
  final AreaLogic logic;
  final VoidCallback onChanged;
  final void Function(int) onAnimate;

  @override
  Widget build(BuildContext context) {
    final truth = figureValue('area_true');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SquareChart(
          maxSide: 300,
          semanticLabel: 'Puntos bajo la curva e elevado a menos x cuadrado',
          painter: ScatterPainter(dots: logic.dots, curve: AreaLogic.f, version: logic.n),
        ),
        const SizedBox(height: 8),
        StatGrid(children: [
          StatTile(label: 'Iteraciones', value: fmtInt(logic.n)),
          StatTile(label: 'Acierto-fallo', value: logic.n == 0 ? '—' : fmtFixed(logic.estHit, 4), color: AppColors.estimate),
          StatTile(label: 'Valor medio', value: logic.n == 0 ? '—' : fmtFixed(logic.estMean, 4), color: AppColors.sample),
          StatTile(label: 'Valor exacto', value: fmtFixed(truth, 4), color: AppColors.model),
        ]),
        const SizedBox(height: 10),
        ChartBox(
          height: 200,
          semanticLabel: 'Convergencia de los dos estimadores',
          painter: ConvergencePainter(
            traces: [logic.traceHit, logic.traceMean],
            colors: const [AppColors.estimate, AppColors.sample],
            truth: truth,
            yLo: 0.45,
            yHi: 1.05,
            version: logic.n,
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [
          (AppColors.estimate, 'acierto-fallo'),
          (AppColors.sample, 'valor medio'),
          (AppColors.model, 'área exacta'),
        ]),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, onAnimate: onAnimate, animateTotal: 2000),
      ],
    );
  }
}

// ------------------------------------------------------------ E3 · semillas
class SeedsView extends StatelessWidget {
  const SeedsView({super.key, required this.logic, required this.onChanged, required this.onAnimate});
  final SeedsLogic logic;
  final VoidCallback onChanged;
  final void Function(int) onAnimate;

  @override
  Widget build(BuildContext context) {
    final est = logic.estimates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 230,
          semanticLabel: 'Cinco trayectorias de estimación de π con semillas distintas',
          painter: ConvergencePainter(
            traces: logic.traces,
            colors: AppColors.seeds,
            truth: math.pi,
            seCoef: figureValue('pi_se_coef'),
            yLo: 2.4,
            yHi: 3.9,
            nMax: 1000,
            version: logic.n,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var i = 0; i < est.length; i++)
              Chip(
                avatar: CircleAvatar(backgroundColor: AppColors.seeds[i], radius: 6),
                label: Text('Semilla ${logic.seeds[i] % 1000}: ${est[i].isNaN ? '—' : fmtFixed(est[i], 3)}'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        RunBar(onAdd: (k) {
          logic.add(k);
          onChanged();
        }, steps: const [10, 100, 500], onAnimate: onAnimate, animateTotal: 500),
      ],
    );
  }
}
