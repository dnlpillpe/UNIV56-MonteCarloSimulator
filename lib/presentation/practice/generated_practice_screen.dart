import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/content/confusions.dart';
import '../../domain/progress/grading.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Práctica ilimitada con números nuevos. Alimenta el diagnóstico, no el
/// dominio: repetir no infla la nota.
class GeneratedPracticeScreen extends ConsumerStatefulWidget {
  const GeneratedPracticeScreen({super.key});

  @override
  ConsumerState<GeneratedPracticeScreen> createState() => _GeneratedPracticeScreenState();
}

class _GeneratedPracticeScreenState extends ConsumerState<GeneratedPracticeScreen> {
  String _topic = generatorTopics.first;
  int _seed = DateTime.now().millisecondsSinceEpoch % 100000;
  late GeneratedQuestion _q = generateQuestion(_topic, _seed);
  final _answer = TextEditingController();
  GradeResult? _result;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _next() => setState(() {
        _seed++;
        _q = generateQuestion(_topic, _seed);
        _answer.clear();
        _result = null;
      });

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Práctica generativa')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in generatorTopics)
                ChoiceChip(
                  label: Text(t),
                  selected: t == _topic,
                  onSelected: (_) {
                    _topic = t;
                    _next();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: _q.topic,
            icon: Icons.all_inclusive,
            accent: AppColors.estimate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_q.prompt, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.45)),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('gen_answer'),
                  controller: _answer,
                  enabled: _result == null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Tu respuesta', suffixText: _q.unit.isEmpty ? null : _q.unit),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                if (_result == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: parseUserNumber(_answer.text) == null
                          ? null
                          : () {
                              final r = _q.grade(parseUserNumber(_answer.text)!);
                              ref.read(progressProvider.notifier).recordGenerated(correct: r.correct, committed: r.committed);
                              setState(() => _result = r);
                            },
                      child: const Text('Comprobar'),
                    ),
                  )
                else ...[
                  InfoBanner(
                    text: _result!.feedback,
                    color: _result!.correct ? AppColors.model : AppColors.confusion,
                    icon: _result!.correct ? Icons.check_circle_outline : Icons.error_outline,
                  ),
                  for (final c in _result!.committed)
                    if (confusionById(c) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Confusión: ${confusionById(c)!.name}', style: const TextStyle(color: AppColors.confusion, fontSize: 12.5)),
                      ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(icon: const Icon(Icons.skip_next), label: const Text('Otra'), onPressed: _next),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Respondidas: ${p.generatedAnswered} · correctas: ${p.generatedCorrect}'
            '${p.generatedAnswered == 0 ? '' : ' (${fmtPct(p.generatedCorrect / p.generatedAnswered, decimals: 0)})'}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
