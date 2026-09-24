import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/analyst/analyst_engine.dart';
import '../../domain/analyst/hybrid_analyst.dart';
import '../../domain/analyst/question_router.dart';
import '../../domain/content/lessons.dart';
import '../learn/lesson_screen.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'ai_settings_screen.dart';

/// Analista de resultados: hallazgos del motor + conversación.
class AnalystScreen extends ConsumerStatefulWidget {
  const AnalystScreen({super.key});

  @override
  ConsumerState<AnalystScreen> createState() => _AnalystScreenState();
}

class _AnalystScreenState extends ConsumerState<AnalystScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _ask(String text) {
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).ask(text);
    _q.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(simulatorProvider);
    final report = sim.report;
    final chat = ref.watch(chatProvider);
    final ai = ref.watch(textGeneratorProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analista de resultados'),
        actions: [
          IconButton(
            tooltip: 'Configurar IA opcional',
            icon: Icon(ai == null ? Icons.smart_toy_outlined : Icons.smart_toy, color: ai == null ? AppColors.textMuted : AppColors.uncertainty),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen())),
          ),
        ],
      ),
      body: report == null
          ? _Empty(onGo: () => ref.read(tabProvider.notifier).go(2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                InfoBanner(
                  text: ai == null
                      ? 'Responde el motor determinista: cada cifra sale de tu corrida. Puedes activar una IA opcional que solo redacta.'
                      : 'IA activa (${ai.label}): redacta sobre las cifras del motor. Si escribe un número que el motor no calculó, se descarta.',
                  icon: Icons.verified_user_outlined,
                  color: ai == null ? AppColors.felt : AppColors.uncertainty,
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: report.summary.spec.title,
                  icon: Icons.insights,
                  accent: AppColors.estimate,
                  child: Text(report.headline, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                ),
                const SizedBox(height: 12),
                Text('Hallazgos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final f in report.findings) _FindingCard(finding: f),
                const SizedBox(height: 12),
                Text('Pregúntale al analista', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in suggestedQuestions)
                      ActionChip(label: Text(q), onPressed: chat.busy ? null : () => _ask(q)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final m in chat.messages) _Bubble(message: m),
                if (chat.busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Analizando…', style: TextStyle(color: AppColors.textMuted)),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('analyst_input'),
                        controller: _q,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(hintText: 'Escribe tu pregunta sobre la corrida'),
                        onSubmitted: _ask,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const ValueKey('analyst_send'),
                      icon: const Icon(Icons.send),
                      onPressed: chat.busy ? null : () => _ask(_q.text),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onGo});
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights, size: 56, color: AppColors.estimate),
              const SizedBox(height: 12),
              const Text(
                'El analista lee la corrida que hagas en el Simulador: precisión, riesgo, colas, falacia de los promedios, sensibilidad y supuestos.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(icon: const Icon(Icons.scatter_plot), label: const Text('Ir al simulador'), onPressed: onGo),
            ],
          ),
        ),
      );
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});
  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (finding.level) {
      FindingLevel.ok => (AppColors.model, Icons.check_circle_outline),
      FindingLevel.info => (AppColors.sample, Icons.info_outline),
      FindingLevel.warning => (AppColors.estimate, Icons.warning_amber_outlined),
      FindingLevel.risk => (AppColors.risk, Icons.local_fire_department_outlined),
    };
    final lesson = finding.lessonId == null ? null : lessonById(finding.lessonId!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(finding.title, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
              ],
            ),
            const SizedBox(height: 6),
            Text(finding.body, style: const TextStyle(height: 1.45)),
            if (lesson != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonScreen(lessonId: lesson.id))),
                  child: Text('Repasar: ${lesson.title}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    final sourceLabel = switch (message.source) {
      AnswerSource.ai => 'IA verificada',
      AnswerSource.engineFallback => 'Motor (respaldo)',
      AnswerSource.engine => 'Motor',
      null => '',
    };
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: user ? AppColors.feltDeep : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user)
              Text(sourceLabel, style: const TextStyle(fontSize: 11, color: AppColors.uncertainty, fontWeight: FontWeight.w700)),
            Text(message.text, style: const TextStyle(height: 1.45)),
            if (message.note != null) ...[
              const SizedBox(height: 6),
              Text(message.note!, style: const TextStyle(fontSize: 11, color: AppColors.estimate)),
            ],
          ],
        ),
      ),
    );
  }
}
