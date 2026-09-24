import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/content/confusions.dart';
import '../../domain/content/labs.dart';
import '../../domain/content/lessons.dart';
import '../../domain/progress/progress.dart';
import '../about/about_screen.dart';
import '../glossary/glossary_screen.dart';
import '../labs/experiment_screen.dart';
import '../learn/lesson_screen.dart';
import '../learn/module_screen.dart';
import '../painters/brand_painter.dart';
import '../providers.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final next = nextStepLabel(p);
    final active = activeConfusions(p).take(3).toList();
    final blind = blindAccuracy(p);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Hero(onGlossary: () => _push(context, const GlossaryScreen()), onAbout: () => _push(context, const AboutScreen())),
          const SizedBox(height: 14),
          if (next != null)
            Card(
              color: AppColors.feltDeep,
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, color: AppColors.estimate, size: 32),
                title: const Text('Continúa donde te quedaste', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(next, style: const TextStyle(color: AppColors.text)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openNext(context, ref, p),
              ),
            ),
          const SizedBox(height: 14),
          Text('Tus tres módulos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final m in modules) ...[
            _ModuleProgressCard(moduleId: m.id),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          SectionCard(
            title: 'Diagnóstico de confusiones',
            icon: Icons.psychology_alt_outlined,
            accent: active.isEmpty ? AppColors.model : AppColors.confusion,
            child: active.isEmpty
                ? const Text(
                    'Todavía no hay confusiones con evidencia suficiente. Cada distractor que elijas suma evidencia (+1); '
                    'evitarla después resta (−0,5) y todo se desvanece un 3 % por ítem.',
                    style: TextStyle(color: AppColors.textMuted, height: 1.4),
                  )
                : Column(
                    children: [
                      for (final e in active) _ConfusionTile(id: e.key, evidence: e.value),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Tu actividad',
            icon: Icons.bar_chart,
            child: StatGrid(children: [
              StatTile(label: 'Simulaciones', value: fmtInt(p.simulationsRun), color: AppColors.estimate),
              StatTile(label: 'Experimentos', value: '${p.experimentsDone.length}/${experiments.length}', color: AppColors.sample),
              StatTile(
                label: 'Acierto ciego',
                value: blind.isNaN ? '—' : fmtPct(blind, decimals: 0),
                color: AppColors.uncertainty,
                hint: 'Primeros intentos correctos antes de ver la explicación',
              ),
              StatTile(label: 'Práctica generada', value: '${p.generatedCorrect}/${p.generatedAnswered}', color: AppColors.model),
            ]),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _openNext(BuildContext context, WidgetRef ref, ProgressState p) {
    for (final l in lessons) {
      if (!p.lessonsDone.contains(l.id)) {
        _push(context, LessonScreen(lessonId: l.id));
        return;
      }
    }
    for (final e in experiments) {
      if (!p.experimentsDone.contains(e.id)) {
        _push(context, ExperimentScreen(experimentId: e.id));
        return;
      }
    }
    ref.read(tabProvider.notifier).go(3);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onGlossary, required this.onAbout});
  final VoidCallback onGlossary;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF155C4C), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const BrandMark(size: 84),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monte Carlo Simulator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Azar controlado para estimar, medir el riesgo y decidir mejor.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(avatar: const Icon(Icons.menu_book, size: 16), label: const Text('Glosario'), onPressed: onGlossary),
                    ActionChip(avatar: const Icon(Icons.info_outline, size: 16), label: const Text('Acerca de'), onPressed: onAbout),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleProgressCard extends ConsumerWidget {
  const _ModuleProgressCard({required this.moduleId});
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    final m = moduleById(moduleId);
    final mastery = masteryOf(moduleId, p);
    final color = AppColors.module[m.number - 1];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ModuleScreen(moduleId: moduleId))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Text('${m.number}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Tema: ${m.theme} · ${mastery.level}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  if (mastery.competent) const Icon(Icons.verified, color: AppColors.model),
                ],
              ),
              const SizedBox(height: 10),
              LabeledProgress(label: 'Dominio (15 % lecciones · 15 % labs · 70 % práctica)', value: mastery.total, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfusionTile extends StatelessWidget {
  const _ConfusionTile({required this.id, required this.evidence});
  final String id;
  final double evidence;

  @override
  Widget build(BuildContext context) {
    final c = confusionById(id);
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.confusion),
              const SizedBox(width: 6),
              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.confusion))),
              Text('evidencia ${fmtFixed(evidence, 1)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.remedy, style: const TextStyle(color: AppColors.text, height: 1.35)),
          Wrap(
            spacing: 6,
            children: [
              if (c.remedyLessonId != null)
                TextButton.icon(
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: const Text('Lección'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonScreen(lessonId: c.remedyLessonId!))),
                ),
              if (c.remedyExperimentId != null)
                TextButton.icon(
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: const Text('Experimento'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExperimentScreen(experimentId: c.remedyExperimentId!))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
