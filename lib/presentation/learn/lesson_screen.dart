import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/lessons.dart';
import '../../domain/models/content_models.dart';
import '../labs/lab_screen.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Lección en tarjetas deslizables. Al llegar a la última se marca como
/// vista y se ofrece ir al laboratorio.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = lessonById(widget.lessonId)!;
    final cards = lesson.cards;
    final last = _page == cards.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _page ? AppColors.felt : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                if (i == cards.length - 1) {
                  ref.read(progressProvider.notifier).completeLesson(lesson.id);
                }
              },
              itemBuilder: (context, i) => _CardView(card: cards[i], goal: i == 0 ? lesson.goal : null),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: () => _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: const Text('Anterior'),
                    ),
                  const Spacer(),
                  if (!last)
                    FilledButton(
                      onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: const Text('Siguiente'),
                    )
                  else if (lesson.labId != null)
                    FilledButton.icon(
                      icon: const Icon(Icons.science),
                      label: const Text('Ir al laboratorio'),
                      onPressed: () {
                        ref.read(progressProvider.notifier).completeLesson(lesson.id);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => LabScreen(labId: lesson.labId!)),
                        );
                      },
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        ref.read(progressProvider.notifier).completeLesson(lesson.id);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Terminar'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, this.goal});
  final LessonCard card;
  final String? goal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (goal != null) ...[
          InfoBanner(text: 'Objetivo: $goal', icon: Icons.flag_outlined),
          const SizedBox(height: 12),
        ],
        Text(card.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        FigText(card.body, style: const TextStyle(fontSize: 15.5, height: 1.5, color: AppColors.text)),
        if (card.formula != null) ...[
          const SizedBox(height: 14),
          FormulaBox(card.formula!),
        ],
        if (card.keyIdea != null) ...[
          const SizedBox(height: 14),
          KeyIdea(card.keyIdea!),
        ],
        if (card.check != null) ...[
          const SizedBox(height: 14),
          _QuickCheckView(check: card.check!),
        ],
      ],
    );
  }
}

class _QuickCheckView extends StatefulWidget {
  const _QuickCheckView({required this.check});
  final QuickCheck check;

  @override
  State<_QuickCheckView> createState() => _QuickCheckViewState();
}

class _QuickCheckViewState extends State<_QuickCheckView> {
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final c = widget.check;
    return SectionCard(
      title: 'Autocomprobación (no puntúa)',
      icon: Icons.quiz_outlined,
      accent: AppColors.uncertainty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FigText(c.question, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 10),
          for (var i = 0; i < c.options.length; i++)
            OptionTile(
              text: c.options[i],
              letter: letterFor(i),
              selected: _chosen == i,
              state: _chosen == null ? null : (i == c.correct ? true : (i == _chosen ? false : null)),
              onTap: _chosen == null ? () => setState(() => _chosen = i) : null,
            ),
          if (_chosen != null) FigText(c.explanation, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        ],
      ),
    );
  }
}
