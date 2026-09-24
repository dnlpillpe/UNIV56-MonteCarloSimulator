import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/content/glossary.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final items = glossary
        .where((g) => q.isEmpty || g.term.toLowerCase().contains(q) || g.definition.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Glosario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar término'),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final g = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.term, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.model)),
                        const SizedBox(height: 4),
                        Text(g.definition, style: const TextStyle(height: 1.4)),
                        if (g.example != null) ...[
                          const SizedBox(height: 4),
                          Text('Ejemplo: ${g.example}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
