import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/stats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/format.dart';
import '../../../domain/labs/experiment_logic.dart';
import '../../painters/point_painters.dart';
import '../../widgets/common.dart';
import 'experiment_views.dart';

// ----------------------------------------------------------------- E12 · √n
class SqrtNView extends StatelessWidget {
  const SqrtNView({super.key, required this.logic, required this.onChanged});
  final SqrtNLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final l in SqrtNLogic.levels) MapEntry('n = ${fmtInt(l)}', logic.results[l] ?? const <double>[]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 240,
          semanticLabel: 'Cuarenta réplicas de la estimación de π para cada n',
          painter: StripPainter(rows: rows, truth: math.pi, lo: 2.6, hi: 3.7),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.estimate, 'una réplica'), (AppColors.uncertainty, '±1 desviación'), (AppColors.model, 'π')]),
        const SizedBox(height: 10),
        StatGrid(children: [
          for (final l in SqrtNLogic.levels)
            StatTile(
              label: 'Desv. con n = ${fmtInt(l)}',
              value: logic.results[l] == null ? '—' : fmtFixed(logic.sdAt(l), 3),
              color: AppColors.uncertainty,
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in SqrtNLogic.levels)
              FilledButton.tonal(
                key: ValueKey('level_$l'),
                onPressed: () {
                  logic.runLevel(l);
                  onChanged();
                },
                child: Text('Correr n = ${fmtInt(l)}'),
              ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------- E13 · raros
class RareView extends StatelessWidget {
  const RareView({super.key, required this.logic, required this.onChanged});
  final RareLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final n = logic.currentN;
    final hits = logic.results[n];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('30 réplicas · cada cuadro es una réplica; el número indica cuántos eventos vio', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        if (hits == null)
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(12)),
            child: const Text('Elige un n y corre las réplicas', style: TextStyle(color: AppColors.textMuted)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in hits)
                Container(
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: h == 0 ? AppColors.surfaceHigh : AppColors.risk.withValues(alpha: math.min(0.9, 0.25 + h * 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: h == 0 ? AppColors.outline : AppColors.risk),
                  ),
                  child: Text('$h', style: TextStyle(fontWeight: FontWeight.w700, color: h == 0 ? AppColors.textMuted : AppColors.text)),
                ),
            ],
          ),
        const SizedBox(height: 10),
        if (hits != null)
          StatGrid(children: [
            StatTile(label: 'Réplicas sin casos', value: '${logic.zerosAt(n)} de 30', color: AppColors.confusion),
            StatTile(label: 'p̂ promedio', value: fmtPct(mean(logic.estimatesAt(n)), decimals: 2), color: AppColors.estimate),
            StatTile(label: 'p real', value: fmtPct(RareLogic.p, decimals: 2), color: AppColors.model),
            StatTile(label: 'Regla del tres (3/n)', value: fmtPct(3 / n, decimals: 2), color: AppColors.uncertainty),
          ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in RareLogic.levels)
              FilledButton.tonal(
                key: ValueKey('rare_$l'),
                onPressed: () {
                  logic.runLevel(l);
                  onChanged();
                },
                child: Text('30 réplicas con n = ${fmtInt(l)}'),
              ),
          ],
        ),
      ],
    );
  }
}
