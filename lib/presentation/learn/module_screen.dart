import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/labs.dart';
import '../../domain/content/lessons.dart';
import '../../domain/progress/progress.dart';
import '../labs/lab_screen.dart';
import '../practice/practice_screen.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'lesson_screen.dart';

class ModuleScreen extends ConsumerWidget {
  const ModuleScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = moduleById(moduleId);
    final p = ref.watch(progressProvider);
    final color = AppColors.module[m.number - 1];
    final mastery = masteryOf(moduleId, p);
    return Scaffold(
      appBar: AppBar(title: Text('Módulo ${m.number} · ${m.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SectionCard(
            title: m.question,
            icon: Icons.help_outline,
            accent: color,
            child: Column(
              children: [
                LabeledProgress(label: 'Lecciones', value: mastery.lessons, color: color),
                const SizedBox(height: 8),
                LabeledProgress(label: 'Laboratorios', value: mastery.labs, color: color),
                const SizedBox(height: 8),
                LabeledProgress(label: 'Práctica', value: mastery.practice, color: color),
                const SizedBox(height: 8),
                Text(
                  mastery.competent
                      ? 'Competente: superaste 0,70 en el total y en la práctica.'
                      : 'Para «Competente» necesitas 0,70 en el total y también en la práctica.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Header(icon: Icons.menu_book, text: 'Lecciones'),
          for (final l in lessonsOf(moduleId))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  p.lessonsDone.contains(l.id) ? Icons.check_circle : Icons.circle_outlined,
                  color: p.lessonsDone.contains(l.id) ? AppColors.model : AppColors.textMuted,
                ),
                title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l.goal, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonScreen(lessonId: l.id))),
              ),
            ),
          const SizedBox(height: 12),
          const _Header(icon: Icons.science_outlined, text: 'Laboratorios'),
          for (final lab in labsOf(moduleId))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(Icons.science, color: color),
                ),
                title: Text(lab.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${lab.subtitle}\n${lab.experimentIds.where(p.experimentsDone.contains).length}/${lab.experimentIds.length} hallazgos',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LabScreen(labId: lab.id))),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.fitness_center),
            label: const Text('Practicar este módulo'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ModulePracticeScreen(moduleId: moduleId)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
