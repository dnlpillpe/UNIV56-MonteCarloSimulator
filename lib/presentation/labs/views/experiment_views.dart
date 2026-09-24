import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/format.dart';
import '../../../domain/labs/experiment_logic.dart';
import 'generator_views.dart';
import 'precision_views.dart';
import 'project_views.dart';
import 'rain_views.dart';
import 'reading_views.dart';
import 'traps_views.dart';

/// Despacha cada experimento a su vista.
class ExperimentView extends StatelessWidget {
  const ExperimentView({super.key, required this.logic, required this.onChanged, required this.onAnimate});

  final ExperimentLogic logic;
  final VoidCallback onChanged;
  final void Function(int total) onAnimate;

  @override
  Widget build(BuildContext context) {
    return switch (logic) {
      PiLogic x => PiView(logic: x, onChanged: onChanged, onAnimate: onAnimate),
      AreaLogic x => AreaView(logic: x, onChanged: onChanged, onAnimate: onAnimate),
      SeedsLogic x => SeedsView(logic: x, onChanged: onChanged, onAnimate: onAnimate),
      GeneratorLogic x => GeneratorView(logic: x, onChanged: onChanged),
      InverseExpLogic x => InverseView(logic: x, onChanged: onChanged, onAnimate: onAnimate),
      DiscreteLogic x => DiscreteView(logic: x, onChanged: onChanged),
      NpvLogic x => NpvView(logic: x, onChanged: onChanged),
      TornadoLogic x => TornadoView(logic: x, onChanged: onChanged),
      MergeLogic x => MergeView(logic: x, onChanged: onChanged),
      CapacityLogic x => CapacityView(logic: x, onChanged: onChanged),
      CorrLogic x => CorrView(logic: x, onChanged: onChanged),
      ShapeLogic x => ShapeView(logic: x, onChanged: onChanged),
      SqrtNLogic x => SqrtNView(logic: x, onChanged: onChanged),
      RareLogic x => RareView(logic: x, onChanged: onChanged),
      SCurveLogic x => SCurveView(logic: x, onChanged: onChanged),
      CompareLogic x => CompareView(logic: x, onChanged: onChanged),
      _ => const Text('Experimento no disponible'),
    };
  }
}

/// Botonera de repeticiones: +10, +100, +1 000 y animación.
class RunBar extends StatelessWidget {
  const RunBar({
    super.key,
    required this.onAdd,
    this.steps = const [10, 100, 1000],
    this.onAnimate,
    this.animateTotal = 1000,
    this.label = '',
  });

  final void Function(int k) onAdd;
  final List<int> steps;
  final void Function(int total)? onAnimate;
  final int animateTotal;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final k in steps)
          FilledButton.tonal(
            key: ValueKey('add_$k'),
            onPressed: () => onAdd(k),
            child: Text('+${_fmt(k)}$label'),
          ),
        if (onAnimate != null)
          OutlinedButton.icon(
            key: const ValueKey('animate'),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text('Animar ${_fmt(animateTotal)}'),
            onPressed: () => onAnimate!(animateTotal),
          ),
      ],
    );
  }

  static String _fmt(int k) => fmtInt(k);
}

/// Gráfico con altura fija y fondo de lienzo.
class ChartBox extends StatelessWidget {
  const ChartBox({super.key, required this.painter, this.height = 220, this.semanticLabel});
  final CustomPainter painter;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.night,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(painter: painter, size: Size.infinite),
          ),
        ),
      );
}

/// Gráfico cuadrado centrado (nubes de puntos).
class SquareChart extends StatelessWidget {
  const SquareChart({super.key, required this.painter, this.maxSide = 320, this.semanticLabel});
  final CustomPainter painter;
  final double maxSide;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSide),
          child: AspectRatio(
            aspectRatio: 1,
            child: Semantics(
              label: semanticLabel,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(painter: painter, size: Size.infinite),
              ),
            ),
          ),
        ),
      );
}
