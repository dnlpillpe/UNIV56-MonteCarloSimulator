import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/cases.dart';
import '../../domain/progress/grading.dart';
import '../practice/exercise_card.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Caso profesional: contexto, tres pasos evaluados y cierre.
class CaseScreen extends ConsumerWidget {
  const CaseScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = caseById(caseId)!;
    final p = ref.watch(progressProvider);
    final allDone = c.steps.every((s) => p.exerciseScores.containsKey(s.id));
    return Scaffold(
      appBar: AppBar(title: Text(c.career)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionCard(
            title: c.title,
            icon: Icons.work_outline,
            accent: AppColors.sample,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FigText(c.context, style: const TextStyle(height: 1.5)),
                if (c.model != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('open_case_model'),
                    icon: const Icon(Icons.scatter_plot),
                    label: const Text('Abrir el modelo en el simulador'),
                    onPressed: () {
                      ref.read(simulatorProvider.notifier).loadModel(c.model!);
                      ref.read(tabProvider.notifier).go(2);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < c.steps.length; i++) ...[
            Text('Paso ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.estimate)),
            const SizedBox(height: 6),
            ExerciseCard(
              key: ValueKey(c.steps[i].id),
              exercise: c.steps[i],
              onGraded: (GradeResult r) => ref.read(progressProvider.notifier).recordAnswer(
                    exerciseId: c.steps[i].id,
                    score: r.score,
                    committed: r.committed,
                    targets: c.steps[i].targets.toSet(),
                  ),
            ),
            const SizedBox(height: 12),
          ],
          if (allDone)
            SectionCard(
              title: 'Cierre del caso',
              icon: Icons.flag,
              accent: AppColors.model,
              child: FigText(c.closing, style: const TextStyle(height: 1.5)),
            ),
        ],
      ),
    );
  }
}
