import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/sim/expression.dart';
import '../../domain/sim/model_spec.dart';
import '../painters/distribution_painters.dart';

/// Hoja para crear o editar una variable de entrada.
/// Devuelve la entrada editada, o null si se cancela.
Future<InputSpec?> showInputEditor(BuildContext context, {InputSpec? initial, required Set<String> takenNames}) {
  return showModalBottomSheet<InputSpec>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _InputEditor(initial: initial, takenNames: takenNames),
    ),
  );
}

class _InputEditor extends StatefulWidget {
  const _InputEditor({this.initial, required this.takenNames});
  final InputSpec? initial;
  final Set<String> takenNames;

  @override
  State<_InputEditor> createState() => _InputEditorState();
}

class _InputEditorState extends State<_InputEditor> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late DistKind _kind;
  late List<TextEditingController> _params;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? _suggestName());
    _desc = TextEditingController(text: i?.description ?? '');
    _kind = i?.kind ?? DistKind.triangular;
    _params = _controllersFor(i?.params ?? InputSpec.defaultParams(_kind, 10));
  }

  String _suggestName() {
    for (var k = 1; k < 50; k++) {
      final n = 'X$k';
      if (!widget.takenNames.contains(n)) return n;
    }
    return 'X';
  }

  List<TextEditingController> _controllersFor(List<double> ps) =>
      [for (final p in ps) TextEditingController(text: _plain(p))];

  static String _plain(double p) {
    if (p == p.roundToDouble() && p.abs() < 1e12) return p.toInt().toString();
    return p.toString().replaceAll('.', ',');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    for (final c in _params) {
      c.dispose();
    }
    super.dispose();
  }

  List<double> get _values => [for (final c in _params) parseUserNumber(c.text) ?? double.nan];

  InputSpec get _draft => InputSpec(
        name: _name.text.trim(),
        kind: _kind,
        params: _values,
        description: _desc.text.trim(),
        unit: widget.initial?.unit ?? '',
      );

  void _changeKind(DistKind k) {
    final vals = _values.where((v) => v.isFinite).toList();
    final center = vals.isEmpty ? 10.0 : vals.reduce((a, b) => a + b) / vals.length;
    for (final c in _params) {
      c.dispose();
    }
    setState(() {
      _kind = k;
      _params = _controllersFor(InputSpec.defaultParams(k, center));
      _error = null;
    });
  }

  void _save() {
    final d = _draft;
    String? err;
    if (!isValidVariableName(d.name)) {
      err = 'Nombre no válido: letra inicial y luego letras, dígitos o _ (sin espacios ni tildes).';
    } else if (d.name != widget.initial?.name && widget.takenNames.contains(d.name)) {
      err = 'Ya existe una variable «${d.name}».';
    } else {
      err = d.validate();
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final valid = draft.validate() == null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.initial == null ? 'Nueva entrada incierta' : 'Editar entrada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    key: const ValueKey('input_name'),
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in DistKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => _changeKind(k),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_kind.hint, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < _params.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: ValueKey('param_$i'),
                      controller: _params[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(labelText: _kind.paramNames[i]),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 110,
              decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(10)),
              child: valid
                  ? CustomPaint(painter: DensityPainter(draft.build()), size: Size.infinite)
                  : const Center(child: Text('Completa parámetros válidos para ver la forma', style: TextStyle(color: AppColors.textMuted))),
            ),
            if (valid) ...[
              const SizedBox(height: 6),
              Text(
                'Media ${fmtNum(draft.build().mean)} · desviación ${fmtNum(draft.build().sd)}',
                style: const TextStyle(fontSize: 12, color: AppColors.model),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.confusion)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                const Spacer(),
                FilledButton(key: const ValueKey('input_save'), onPressed: _save, child: const Text('Guardar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
