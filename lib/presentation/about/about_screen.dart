import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../painters/brand_painter.dart';
import '../providers.dart';
import '../widgets/common.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Center(child: BrandMark(size: 120)),
          const SizedBox(height: 12),
          Center(child: Text('Monte Carlo Simulator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          const Center(child: Text('Versión 1.0.0 · Educational Mobile Apps Factory', style: TextStyle(color: AppColors.textMuted))),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'El icono',
            icon: Icons.palette_outlined,
            child: Text(
              'Lluvia de puntos sobre el cuarto de círculo: el experimento con el que se explica el método desde su origen. '
              'Los puntos cian caen dentro, los naranjas fuera; la curva verde es el modelo y el punto dorado, la estimación.',
              style: TextStyle(height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'Cada color es un concepto',
            icon: Icons.color_lens_outlined,
            child: ColorLegend(items: [
              (AppColors.model, 'modelo / valor teórico'),
              (AppColors.sample, 'muestras observadas'),
              (AppColors.estimate, 'estimación Monte Carlo'),
              (AppColors.risk, 'riesgo: colas, pérdidas, umbral'),
              (AppColors.uncertainty, 'incertidumbre: error estándar, IC'),
              (AppColors.confusion, 'confusión detectada'),
            ]),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'Cómo está hecha',
            icon: Icons.architecture,
            child: Text(
              'Todo el azar sale de xoshiro128** con semilla visible. Ningún número del contenido está escrito a mano: se calcula con fórmulas cerradas y se verifica con una réplica independiente en Python. '
              'El analista es un motor determinista; la IA es opcional y solo redacta sobre las cifras del motor. Funciona sin conexión.',
              style: TextStyle(height: 1.45),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt, color: AppColors.confusion),
            label: const Text('Borrar mi progreso'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Borrar el progreso?'),
                  content: const Text('Se perderán lecciones vistas, hallazgos, puntajes y diagnóstico.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Borrar')),
                  ],
                ),
              );
              if (ok == true) ref.read(progressProvider.notifier).reset();
            },
          ),
        ],
      ),
    );
  }
}
