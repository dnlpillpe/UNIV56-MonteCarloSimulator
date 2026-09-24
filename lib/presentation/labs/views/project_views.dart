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

// ----------------------------------------------------------------- E7 · VAN
class NpvView extends StatelessWidget {
  const NpvView({super.key, required this.logic, required this.onChanged});
  final NpvLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = logic.summary;
    final values = s?.run.outputs ?? const <double>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 230,
          semanticLabel: 'Histograma del VAN simulado con la zona de pérdida',
          painter: HistogramPainter(
            values: values,
            lo: -450,
            hi: 450,
            bins: 36,
            threshold: 0,
            riskBelow: true,
            markers: [
              ChartMarker(logic.modeNpv, 'más probable', AppColors.text),
              if (s != null) ChartMarker(s.mean, 'media', AppColors.estimate, dashed: false),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const ColorLegend(items: [(AppColors.sample, 'VAN ≥ 0'), (AppColors.risk, 'VAN < 0'), (AppColors.estimate, 'VAN medio')]),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Iteraciones', value: fmtInt(logic.n)),
          StatTile(label: 'VAN más probable', value: fmtFixed(logic.modeNpv, 0)),
          StatTile(label: 'VAN medio', value: s == null ? '—' : fmtFixed(s.mean, 0), color: AppColors.estimate),
          StatTile(label: 'P(VAN < 0)', value: s == null ? '—' : fmtPct(s.thresholdProb!), color: AppColors.risk),
          StatTile(label: 'P5', value: s == null ? '—' : fmtFixed(s.p(5), 0), color: AppColors.risk),
          StatTile(label: 'P95', value: s == null ? '—' : fmtFixed(s.p(95), 0), color: AppColors.sample),
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

// --------------------------------------------------------- E9 · paralelo
class MergeView extends StatelessWidget {
  const MergeView({super.key, required this.logic, required this.onChanged});
  final MergeLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final totals = logic.totals();
    final onTime = logic.onTime();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceRow<bool>(
          options: const [(false, 'Una ruta (A)'), (true, 'Dos rutas en paralelo (A y B)')],
          selected: logic.twoPaths,
          onSelected: (v) {
            logic.twoPaths = v;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        ChartBox(
          height: 210,
          semanticLabel: 'Histograma del plazo total con el plan de 14 días',
          painter: HistogramPainter(
            values: totals,
            lo: 9,
            hi: 20,
            bins: 22,
            threshold: MergeLogic.plan,
            riskBelow: false,
            markers: [if (totals.isNotEmpty) ChartMarker(mean(totals), 'media', AppColors.estimate, dashed: false)],
          ),
        ),
        const SizedBox(height: 10),
        StatGrid(children: [
          StatTile(label: 'Iteraciones', value: fmtInt(logic.a.length)),
          StatTile(label: 'Plan', value: '14 días'),
          StatTile(label: 'P(cumplir)', value: totals.isEmpty ? '—' : fmtPct(onTime), color: AppColors.sample),
          StatTile(label: 'Plazo medio', value: totals.isEmpty ? '—' : fmtFixed(mean(totals), 2), color: AppColors.estimate),
          StatTile(label: 'Teórico 1 ruta', value: figures['merge_p_one']!.text, color: AppColors.model),
          StatTile(label: 'Teórico 2 rutas', value: figures['merge_p_two']!.text, color: AppColors.model),
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

// ------------------------------------------------------------ E16 · tornado
class TornadoView extends StatelessWidget {
  const TornadoView({super.key, required this.logic, required this.onChanged});
  final TornadoLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = logic.summary;
    const names = {'P': 'Precio (8–11)', 'c': 'Costo (5,5–7)', 'Q': 'Volumen (30–55)'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartBox(
          height: 170,
          semanticLabel: 'Gráfico de tornado de las entradas del VAN',
          painter: TornadoPainter(items: s?.sensitivities ?? const []),
        ),
        const SizedBox(height: 6),
        const Text(
          'Barra = correlación de rangos entre la entrada y el VAN. Cian: al subir la entrada sube el VAN; naranja: lo baja.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        StatGrid(children: [
          for (final e in names.entries)
            StatTile(
              label: e.value,
              value: s == null ? '—' : fmtFixed(logic.rhoOf(e.key), 2),
              color: e.key == 'c' ? AppColors.risk : AppColors.sample,
            ),
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
