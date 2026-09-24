import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/content/confusions.dart';
import '../../domain/content/labs.dart';
import '../../domain/labs/experiment_logic.dart';
import '../../domain/models/content_models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'views/experiment_views.dart';

/// Marco común de los 16 experimentos: Predice → Simula → Explica.
class ExperimentScreen extends ConsumerStatefulWidget {
  const ExperimentScreen({super.key, required this.experimentId});
  final String experimentId;

  @override
  ConsumerState<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends ConsumerState<ExperimentScreen> {
  late final ExperimentLogic logic = ExperimentLogic.create(widget.experimentId);
  int? _choice;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final def = experimentById(widget.experimentId);
    if (logic.progress >= def.minSamples) {
      ref.read(progressProvider.notifier).completeExperiment(def.id);
    }
  }

  /// Animación: agrega de a pocos hasta [total] para ver la convergencia.
  void _animate(int total) {
    _timer?.cancel();
    var remaining = total;
    final chunk = math.max(1, total ~/ 40);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted || remaining <= 0) {
        t.cancel();
        setState(() {});
        return;
      }
      final k = math.min(chunk, remaining);
      logic.add(k);
      remaining -= k;
      _changed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final def = experimentById(widget.experimentId);
    final predicted = _choice != null;
    final unlocked = logic.progress >= def.minSamples;
    final progressFrac = math.min(1.0, logic.progress / def.minSamples);
    final initial = ref.watch(progressProvider.select((p) => p.predictions[def.id]));
    return Scaffold(
      appBar: AppBar(title: Text(def.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FigText(def.setup, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
          const SizedBox(height: 14),
          // ---------------------------------------------------- 1 · Predice
          _StepHeader(number: 1, title: 'Predice', done: predicted, color: AppColors.estimate),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FigText(def.prediction, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 10),
                for (var i = 0; i < def.options.length; i++)
                  OptionTile(
                    text: def.options[i].text,
                    letter: letterFor(i),
                    selected: _choice == i,
                    onTap: predicted
                        ? null
                        : () {
                            setState(() => _choice = i);
                            ref.read(progressProvider.notifier).recordPrediction(def.id, def.options[i].correct);
                          },
                  ),
                if (predicted)
                  const Text(
                    'Predicción registrada. Ahora simula y compara: la predicción no resta puntos, es tu punto de partida.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------- 2 · Simula
          _StepHeader(number: 2, title: 'Simula', done: unlocked, color: AppColors.sample),
          AbsorbPointer(
            absorbing: !predicted,
            child: Opacity(
              opacity: predicted ? 1 : 0.35,
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!predicted)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                            SizedBox(width: 6),
                            Expanded(child: Text('Registra tu predicción para desbloquear', style: TextStyle(color: AppColors.textMuted))),
                          ],
                        ),
                      ),
                    ExperimentView(logic: logic, onChanged: _changed, onAnimate: _animate),
                    const SizedBox(height: 12),
                    LabeledProgress(
                      label: 'Repeticiones para desbloquear el hallazgo (${fmtInt(math.min(logic.progress, def.minSamples))}/${fmtInt(def.minSamples)})',
                      value: progressFrac,
                      color: AppColors.sample,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Semilla ${logic.seed}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.casino_outlined, size: 18),
                          label: const Text('Otra semilla'),
                          onPressed: () {
                            _timer?.cancel();
                            logic.newSeed();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------- 3 · Explica
          _StepHeader(number: 3, title: 'Explica', done: unlocked, color: AppColors.model),
          if (!unlocked)
            const SectionCard(
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El hallazgo se desbloquea al alcanzar el mínimo de repeticiones: con pocas, el azar todavía domina.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            SectionCard(
              title: 'Hallazgo',
              icon: Icons.lightbulb,
              accent: AppColors.model,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(renderFinding(def.finding, logic.observations), style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 10),
                  KeyIdea(def.explanation),
                  const SizedBox(height: 10),
                  _PredictionReview(def: def, choice: _choice, initialCorrect: initial),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title, required this.done, required this.color});
  final int number;
  final String title;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: done ? color : color.withValues(alpha: 0.2),
              child: done
                  ? const Icon(Icons.check, size: 16, color: AppColors.night)
                  : Text('$number', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      );
}

class _PredictionReview extends StatelessWidget {
  const _PredictionReview({required this.def, required this.choice, required this.initialCorrect});
  final ExperimentDef def;
  final int? choice;
  final bool? initialCorrect;

  @override
  Widget build(BuildContext context) {
    final c = choice;
    if (c == null) return const SizedBox.shrink();
    final opt = def.options[c];
    final correct = opt.correct;
    final confusionId = opt.confusion;
    final conf = confusionId == null ? null : confusionById(confusionId);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (correct ? AppColors.model : AppColors.estimate).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? 'Tu predicción coincidió con lo observado.' : 'Tu predicción no coincidió: eso es justamente lo que el experimento vino a mostrar.',
            style: TextStyle(fontWeight: FontWeight.w700, color: correct ? AppColors.model : AppColors.estimate),
          ),
          if (conf != null) ...[
            const SizedBox(height: 4),
            Text('Intuición habitual: «${conf.name}». ${conf.description}', style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          if (initialCorrect != null) ...[
            const SizedBox(height: 4),
            Text(
              'Intuición inicial registrada: ${initialCorrect! ? 'acertada' : 'distinta de lo observado'} (no resta puntos).',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
