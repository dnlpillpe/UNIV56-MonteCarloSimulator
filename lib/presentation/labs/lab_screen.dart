import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/labs.dart';
import '../../domain/content/lessons.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'experiment_screen.dart';

class LabScreen extends ConsumerWidget {
  const LabScreen({super.key, required this.labId});
  final String labId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab = labById(labId);
    final m = moduleById(lab.moduleId);
    final color = AppColors.module[m.number - 1];
    final p = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lab.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          InfoBanner(text: lab.subtitle, icon: Icons.science_outlined, color: color),
          const SizedBox(height: 8),
          const ColorLegend(items: [
            (AppColors.model, 'modelo / valor teórico'),
            (AppColors.sample, 'muestras'),
            (AppColors.estimate, 'estimación'),
            (AppColors.risk, 'riesgo'),
            (AppColors.uncertainty, 'incertidumbre'),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < lab.experimentIds.length; i++)
            Builder(builder: (context) {
              final e = experimentById(lab.experimentIds[i]);
              final done = p.experimentsDone.contains(e.id);
              final predicted = p.predictions.containsKey(e.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: done ? AppColors.model.withValues(alpha: 0.2) : color.withValues(alpha: 0.15),
                    child: done
                        ? const Icon(Icons.check, color: AppColors.model)
                        : Text('${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    done ? 'Hallazgo desbloqueado' : (predicted ? 'Predicción registrada · simula para desbloquear' : 'Empieza con tu predicción'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ExperimentScreen(experimentId: e.id)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
