import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Configuración de la IA opcional del analista.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late AiProvider _provider;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _url;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiSettingsProvider);
    _provider = s.provider;
    _key = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    _url = TextEditingController(text: s.baseUrl);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = AiSettings(provider: _provider, apiKey: _key.text, model: _model.text, baseUrl: _url.text);
    return Scaffold(
      appBar: AppBar(title: const Text('IA opcional del analista')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const InfoBanner(
            text: 'La app funciona completa sin IA: el analista determinista responde con las cifras de tu corrida. '
                'Si activas una IA, solo redacta sobre esas cifras; una guardia descarta su respuesta si escribe un número que el motor no calculó.',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 16),
          for (final p in AiProvider.values)
            OptionTile(
              text: p.label,
              selected: _provider == p,
              onTap: () => setState(() => _provider = p),
            ),
          if (_provider != AiProvider.none) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Clave de API',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              decoration: InputDecoration(labelText: 'Modelo', hintText: draft.effectiveModel),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              decoration: InputDecoration(labelText: 'URL base (opcional, p. ej. un proxy institucional)', hintText: draft.effectiveBaseUrl),
            ),
            const SizedBox(height: 10),
            const Text(
              'La clave se guarda solo en este dispositivo, sin cifrado adicional. Para uso institucional se recomienda un proxy propio que guarde la clave en el servidor.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              ref.read(aiSettingsProvider.notifier).save(draft);
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
