import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/figures.dart';

/// Tarjeta de sección con título y contenido.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, this.accent, required this.child, this.padding = const EdgeInsets.all(14)});

  final String? title;
  final IconData? icon;
  final Color? accent;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: accent ?? AppColors.felt),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: accent ?? AppColors.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Texto del contenido con cifras `{{id}}` ya sustituidas.
class FigText extends StatelessWidget {
  const FigText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        renderFigures(text),
        style: style ?? Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
      );
}

/// Recuadro de fórmula.
class FormulaBox extends StatelessWidget {
  const FormulaBox(this.formula, {super.key});
  final String formula;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.night,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.model.withValues(alpha: 0.5)),
        ),
        child: Text(
          renderFigures(formula),
          style: const TextStyle(fontFamily: 'monospace', color: AppColors.model, fontSize: 13.5, height: 1.4),
        ),
      );
}

/// Idea clave destacada.
class KeyIdea extends StatelessWidget {
  const KeyIdea(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.estimate.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: AppColors.estimate, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.estimate),
            const SizedBox(width: 8),
            Expanded(child: FigText(text, style: const TextStyle(color: AppColors.text, height: 1.4))),
          ],
        ),
      );
}

/// Indicador numérico compacto.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color = AppColors.text, this.hint});
  final String label;
  final String value;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
    return hint == null ? tile : Tooltip(message: hint!, child: tile);
  }
}

/// Rejilla de indicadores que se adapta al ancho.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth > 520 ? 4 : (c.maxWidth > 300 ? 3 : 2);
          final w = (c.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final ch in children) SizedBox(width: w, child: ch)],
          );
        },
      );
}

/// Aviso con icono.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.color = AppColors.felt, this.icon = Icons.info_outline});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: FigText(text, style: const TextStyle(color: AppColors.text, height: 1.4))),
          ],
        ),
      );
}

/// Barra de progreso con etiqueta.
class LabeledProgress extends StatelessWidget {
  const LabeledProgress({super.key, required this.label, required this.value, this.color = AppColors.felt});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
              Text('${(value * 100).round()} %', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.isNaN ? 0 : value,
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
        ],
      );
}

/// Leyenda de colores-concepto.
class ColorLegend extends StatelessWidget {
  const ColorLegend({super.key, required this.items});
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final it in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: it.$1, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(it.$2, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
        ],
      );
}

/// Alternativa seleccionable con estado de corrección.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.text,
    required this.selected,
    this.state,
    this.onTap,
    this.letter,
  });

  final String text;
  final bool selected;

  /// null: sin corregir; true: correcta; false: incorrecta.
  final bool? state;
  final VoidCallback? onTap;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    Color border = selected ? AppColors.felt : AppColors.outline;
    Color? fill = selected ? AppColors.felt.withValues(alpha: 0.12) : null;
    IconData? icon;
    if (state == true) {
      border = AppColors.model;
      fill = AppColors.model.withValues(alpha: 0.14);
      icon = Icons.check_circle;
    } else if (state == false) {
      border = AppColors.confusion;
      fill = AppColors.confusion.withValues(alpha: 0.12);
      icon = Icons.cancel;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fill ?? AppColors.surfaceHigh.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border, width: selected || state != null ? 1.6 : 0.8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                if (letter != null) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: selected ? AppColors.felt : AppColors.surfaceHigh,
                    child: Text(letter!, style: TextStyle(fontSize: 12, color: selected ? AppColors.onFelt : AppColors.text, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: FigText(text, style: const TextStyle(color: AppColors.text, height: 1.35))),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: border, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String letterFor(int i) => String.fromCharCode(65 + i);

/// Selector de opciones con fichas que se acomodan al ancho (en lugar de
/// SegmentedButton, que no hace salto de línea en pantallas angostas).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.selected, required this.onSelected});
  final List<(T, String)> options;
  final T selected;
  final void Function(T value) onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in options)
            ChoiceChip(
              key: ValueKey('choice_${o.$1}'),
              label: Text(o.$2),
              selected: o.$1 == selected,
              onSelected: (_) => onSelected(o.$1),
            ),
        ],
      );
}
