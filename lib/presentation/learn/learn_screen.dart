import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/labs.dart';
import '../../domain/content/lessons.dart';
import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'module_screen.dart';

/// Los tres módulos pedidos, cada uno con sus lecciones y laboratorios.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aprender')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const InfoBanner(
            text: 'Cada módulo combina lecciones breves con laboratorios. En los laboratorios primero predices, luego simulas y al final explicas: '
                'los controles se desbloquean al registrar tu predicción.',
            icon: Icons.route_outlined,
          ),
          const SizedBox(height: 12),
          for (final m in modules) ...[
            _ModuleCard(
              number: m.number,
              title: m.title,
              theme: m.theme,
              question: m.question,
              summary: m.summary,
              lessonsDone: lessonsOf(m.id).where((l) => p.lessonsDone.contains(l.id)).length,
              lessonsTotal: lessonsOf(m.id).length,
              expDone: [for (final l in labsOf(m.id)) ...l.experimentIds].where(p.experimentsDone.contains).length,
              expTotal: [for (final l in labsOf(m.id)) ...l.experimentIds].length,
              mastery: masteryOf(m.id, p),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ModuleScreen(moduleId: m.id))),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.number,
    required this.title,
    required this.theme,
    required this.question,
    required this.summary,
    required this.lessonsDone,
    required this.lessonsTotal,
    required this.expDone,
    required this.expTotal,
    required this.mastery,
    required this.onTap,
  });

  final int number;
  final String title;
  final String theme;
  final String question;
  final String summary;
  final int lessonsDone, lessonsTotal, expDone, expTotal;
  final Mastery mastery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.module[number - 1];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              color: color.withValues(alpha: 0.14),
              child: Row(
                children: [
                  Text('Módulo $number', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                    child: Text(theme, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(mastery.level, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(question, style: const TextStyle(color: AppColors.estimate, fontStyle: FontStyle.italic, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(summary, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.menu_book, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$lessonsDone/$lessonsTotal lecciones', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 14),
                      const Icon(Icons.science_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('$expDone/$expTotal experimentos', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LabeledProgress(label: 'Dominio', value: mastery.total, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
