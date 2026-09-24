import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/cases.dart';
import '../../domain/content/exercises.dart';
import '../../domain/content/lessons.dart';
import '../../domain/progress/grading.dart';
import '../../domain/progress/progress.dart';
import '../cases/case_screen.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'exercise_card.dart';
import 'generated_practice_screen.dart';

/// Práctica: ejercicios por módulo, casos profesionales y práctica generativa.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Práctica'),
          bottom: const TabBar(tabs: [Tab(text: 'Ejercicios'), Tab(text: 'Casos por carrera')]),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const InfoBanner(
                  text: 'Cada distractor revela una confusión concreta. En las decisiones, la elección vale 60 % y la justificación 40 %: acertar sin entender también se detecta.',
                  icon: Icons.psychology_outlined,
                ),
                const SizedBox(height: 12),
                for (final m in modules) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.module[m.number - 1].withValues(alpha: 0.2),
                        child: Text('${m.number}', style: TextStyle(color: AppColors.module[m.number - 1], fontWeight: FontWeight.w800)),
                      ),
                      title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${exercisesOf(m.id).where((e) => (p.exerciseScores[e.id] ?? 0) >= 0.999).length}/${exercisesOf(m.id).length} dominados · práctica ${(masteryOf(m.id, p).practice * 100).round()} %',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ModulePracticeScreen(moduleId: m.id))),
                    ),
                  ),
                ],
                Card(
                  color: AppColors.feltDeep,
                  child: ListTile(
                    leading: const Icon(Icons.all_inclusive, color: AppColors.estimate),
                    title: const Text('Práctica generativa', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Preguntas ilimitadas con números nuevos: error estándar, iteraciones, √n y regla del tres.', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GeneratedPracticeScreen())),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const InfoBanner(
                  text: 'Once carreras, un problema real cada una. Resuelve los tres pasos y, cuando el modelo es simulable, ábrelo en el simulador.',
                  icon: Icons.work_outline,
                ),
                const SizedBox(height: 12),
                for (final c in cases)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.sample.withValues(alpha: 0.15),
                        child: Icon(_careerIcon(c.career), color: AppColors.sample, size: 20),
                      ),
                      title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${c.career} · ${(caseScore(c.id, p) * 100).round()} %', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      trailing: c.model != null ? const Icon(Icons.scatter_plot, color: AppColors.estimate, size: 18) : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CaseScreen(caseId: c.id))),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _careerIcon(String career) {
    final c = career.toLowerCase();
    if (c.contains('minas')) return Icons.landscape_outlined;
    if (c.contains('sistemas')) return Icons.dns_outlined;
    if (c.contains('electr')) return Icons.memory;
    if (c.contains('ambient')) return Icons.eco_outlined;
    if (c.contains('admin')) return Icons.storefront_outlined;
    if (c.contains('econom')) return Icons.trending_up;
    if (c.contains('contab')) return Icons.receipt_long_outlined;
    if (c.contains('psico')) return Icons.psychology_outlined;
    if (c.contains('biol')) return Icons.pets_outlined;
    if (c.contains('human')) return Icons.history_edu_outlined;
    return Icons.self_improvement;
  }
}

/// Ejercicios de un módulo, uno tras otro.
class ModulePracticeScreen extends ConsumerStatefulWidget {
  const ModulePracticeScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<ModulePracticeScreen> createState() => _ModulePracticeScreenState();
}

class _ModulePracticeScreenState extends ConsumerState<ModulePracticeScreen> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final list = exercisesOf(widget.moduleId);
    final m = moduleById(widget.moduleId);
    final ex = list[_i];
    final p = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Práctica · ${m.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final sc = p.exerciseScores[list[i].id];
                final color = sc == null
                    ? AppColors.surfaceHigh
                    : (sc >= 0.999 ? AppColors.model : (sc > 0 ? AppColors.estimate : AppColors.confusion));
                return ChoiceChip(
                  label: Text('${i + 1}'),
                  selected: i == _i,
                  backgroundColor: color.withValues(alpha: 0.35),
                  onSelected: (_) => setState(() => _i = i),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ExerciseCard(
            key: ValueKey(ex.id),
            exercise: ex,
            index: _i,
            total: list.length,
            onGraded: (GradeResult r) => ref.read(progressProvider.notifier).recordAnswer(
                  exerciseId: ex.id,
                  score: r.score,
                  committed: r.committed,
                  targets: ex.targets.toSet(),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_i > 0)
                OutlinedButton(onPressed: () => setState(() => _i--), child: const Text('Anterior')),
              const Spacer(),
              if (_i < list.length - 1)
                FilledButton(key: const ValueKey('next_exercise'), onPressed: () => setState(() => _i++), child: const Text('Siguiente')),
            ],
          ),
        ],
      ),
    );
  }
}
