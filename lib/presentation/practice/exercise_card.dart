import 'package:flutter/material.dart';

import '../../core/rng/random_source.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/content/confusions.dart';
import '../../domain/models/content_models.dart';
import '../../domain/progress/grading.dart';
import '../widgets/common.dart';

/// Muestra y corrige cualquier ítem (opción, número, decisión 60/40 u
/// orden). Tras corregir, muestra retroalimentación y explicación, y
/// permite reintentar (el primer intento queda como «acierto ciego»).
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.exercise, required this.onGraded, this.index, this.total});

  final Exercise exercise;
  final void Function(GradeResult result) onGraded;
  final int? index;
  final int? total;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  int? _option;
  int? _justification;
  final _number = TextEditingController();
  late List<String> _order;
  GradeResult? _result;

  Exercise get e => widget.exercise;

  @override
  void initState() {
    super.initState();
    _order = shuffledSteps(e, fnv1a32(e.id));
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != e.id) {
      _option = null;
      _justification = null;
      _number.clear();
      _order = shuffledSteps(e, fnv1a32(e.id));
      _result = null;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _ready => switch (e.type) {
        ExerciseType.choice => _option != null,
        ExerciseType.decision => _option != null && _justification != null,
        ExerciseType.numeric => parseUserNumber(_number.text) != null,
        ExerciseType.ordering => true,
      };

  void _check() {
    final r = switch (e.type) {
      ExerciseType.choice => gradeChoice(e, _option!),
      ExerciseType.decision => gradeDecision(e, _option!, _justification!),
      ExerciseType.numeric => gradeNumeric(e, parseUserNumber(_number.text)!),
      ExerciseType.ordering => gradeOrdering(e, _order),
    };
    setState(() => _result = r);
    widget.onGraded(r);
  }

  void _retry() => setState(() {
        _result = null;
        _option = null;
        _justification = null;
        _number.clear();
      });

  @override
  Widget build(BuildContext context) {
    final graded = _result != null;
    final typeLabel = switch (e.type) {
      ExerciseType.choice => 'Opción múltiple',
      ExerciseType.numeric => 'Respuesta numérica',
      ExerciseType.decision => 'Decisión + justificación (60/40)',
      ExerciseType.ordering => 'Ordena los pasos',
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(typeLabel, style: const TextStyle(fontSize: 12, color: AppColors.uncertainty, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (widget.index != null && widget.total != null)
                Text('${widget.index! + 1}/${widget.total}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          FigText(e.prompt, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.45)),
          const SizedBox(height: 12),
          ..._body(graded),
          const SizedBox(height: 8),
          if (!graded)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const ValueKey('check_answer'),
                onPressed: _ready ? _check : null,
                child: const Text('Comprobar'),
              ),
            )
          else
            _Feedback(result: _result!, exercise: e, onRetry: _retry),
        ],
      ),
    );
  }

  List<Widget> _body(bool graded) {
    switch (e.type) {
      case ExerciseType.choice:
        return [
          for (var i = 0; i < e.options.length; i++)
            OptionTile(
              text: e.options[i].text,
              letter: letterFor(i),
              selected: _option == i,
              state: graded ? (e.options[i].correct ? true : (_option == i ? false : null)) : null,
              onTap: graded ? null : () => setState(() => _option = i),
            ),
        ];
      case ExerciseType.decision:
        return [
          const Text('Decisión', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          for (var i = 0; i < e.options.length; i++)
            OptionTile(
              text: e.options[i].text,
              letter: letterFor(i),
              selected: _option == i,
              state: graded ? (e.options[i].correct ? true : (_option == i ? false : null)) : null,
              onTap: graded ? null : () => setState(() => _option = i),
            ),
          const SizedBox(height: 6),
          const Text('¿Por qué?', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          for (var i = 0; i < e.justifications.length; i++)
            OptionTile(
              text: e.justifications[i].text,
              letter: '${i + 1}',
              selected: _justification == i,
              state: graded ? (e.justifications[i].correct ? true : (_justification == i ? false : null)) : null,
              onTap: graded ? null : () => setState(() => _justification = i),
            ),
        ];
      case ExerciseType.numeric:
        return [
          TextField(
            key: const ValueKey('numeric_answer'),
            controller: _number,
            enabled: !graded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: e.answerIsPercent ? 'Tu respuesta (en %)' : 'Tu respuesta',
              suffixText: e.answerIsPercent ? '%' : (e.unit.isEmpty ? null : e.unit),
              helperText: 'Puedes usar coma o punto decimal',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case ExerciseType.ordering:
        return [
          const Text('Arrastra para ordenar', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: !graded,
            onReorder: (oldI, newI) {
              if (graded) return;
              setState(() {
                if (newI > oldI) newI -= 1;
                final item = _order.removeAt(oldI);
                _order.insert(newI, item);
              });
            },
            children: [
              for (var i = 0; i < _order.length; i++)
                Container(
                  key: ValueKey('step_${_order[i]}'),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: graded
                        ? (_order[i] == e.steps[i] ? AppColors.model : AppColors.confusion).withValues(alpha: 0.14)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.estimate)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_order[i])),
                      if (!graded) const Icon(Icons.drag_handle, color: AppColors.textMuted),
                    ],
                  ),
                ),
            ],
          ),
        ];
    }
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.result, required this.exercise, required this.onRetry});
  final GradeResult result;
  final Exercise exercise;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ok = result.correct;
    final partial = !ok && result.score > 0;
    final color = ok ? AppColors.model : (partial ? AppColors.estimate : AppColors.confusion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ok ? 'Correcto' : (partial ? 'Parcial: ${fmtPct(result.score, decimals: 0)}' : 'Todavía no'),
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 4),
              Text(result.feedback, style: const TextStyle(height: 1.4)),
              for (final c in result.committed)
                if (confusionById(c) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.confusion),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Confusión detectada: ${confusionById(c)!.name}${result.recognized ? ' (reconocida por el número que escribiste)' : ''}.',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.confusion),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        KeyIdea(exercise.explanation),
        if (!ok)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(icon: const Icon(Icons.refresh), label: const Text('Reintentar'), onPressed: onRetry),
          ),
      ],
    );
  }
}
