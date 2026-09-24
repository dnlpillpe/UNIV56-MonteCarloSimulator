import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/format.dart';
import '../../domain/content/cases.dart';
import '../../domain/content/figures.dart';
import '../../domain/sim/expression.dart';
import '../../domain/sim/model_spec.dart';
import '../../domain/sim/templates.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'input_editor.dart';
import 'results_panel.dart';

/// Simulador libre: entradas inciertas + fórmula + umbral → distribución.
class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  final _expr = TextEditingController();
  final _outName = TextEditingController();
  final _threshold = TextEditingController();
  final _seed = TextEditingController();
  int _syncedRevision = -1;
  String? _exprError;

  @override
  void initState() {
    super.initState();
    _sync(ref.read(simulatorProvider));
  }

  @override
  void dispose() {
    _expr.dispose();
    _outName.dispose();
    _threshold.dispose();
    _seed.dispose();
    super.dispose();
  }

  void _sync(SimulatorState st) {
    if (_syncedRevision == st.revision) return;
    _syncedRevision = st.revision;
    _expr.text = st.spec.expression;
    _outName.text = st.spec.outputName;
    _threshold.text = st.spec.threshold == null ? '' : fmtNum(st.spec.threshold!).replaceAll(' ', '');
    _seed.text = '${st.seed}';
    _exprError = _checkExpr(st.spec);
  }

  String? _checkExpr(ModelSpec spec) {
    try {
      compileExpression(spec.expression, spec.variableNames);
      return null;
    } on ExpressionError catch (e) {
      return e.toString();
    }
  }

  SimulatorNotifier get _n => ref.read(simulatorProvider.notifier);

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(simulatorProvider.select((s) => s.revision), (_, __) {
      setState(() => _sync(ref.read(simulatorProvider)));
    });
    final st = ref.watch(simulatorProvider);
    final spec = st.spec;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador'),
        actions: [
          TextButton.icon(
            key: const ValueKey('open_templates'),
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('Modelos'),
            onPressed: () => _openTemplates(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionCard(
            title: spec.title,
            icon: Icons.account_tree_outlined,
            child: FigText(spec.description, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ),
          const SizedBox(height: 12),
          // ---------------------------------------------------------- entradas
          SectionCard(
            title: 'Entradas inciertas',
            icon: Icons.input,
            accent: AppColors.sample,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < spec.inputs.length; i++) _inputRow(context, spec, i),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  key: const ValueKey('add_input'),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar entrada'),
                  onPressed: () async {
                    final res = await showInputEditor(context, takenNames: spec.variableNames.toSet());
                    if (res != null) {
                      final next = spec.copyWith(inputs: [...spec.inputs, res]);
                      _n.updateSpec(next);
                      setState(() => _exprError = _checkExpr(next));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ----------------------------------------------------------- fórmula
          SectionCard(
            title: 'Fórmula de la salida',
            icon: Icons.functions,
            accent: AppColors.model,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('output_name'),
                  controller: _outName,
                  decoration: const InputDecoration(labelText: 'Nombre de la salida'),
                  onChanged: (v) => _n.updateSpec(spec.copyWith(outputName: v.trim().isEmpty ? 'Salida' : v.trim())),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('expression'),
                  controller: _expr,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Fórmula (usa los nombres de las entradas)',
                    errorText: _exprError,
                    errorMaxLines: 3,
                  ),
                  onChanged: (v) {
                    final next = spec.copyWith(expression: v);
                    _n.updateSpec(next);
                    setState(() => _exprError = _checkExpr(next));
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final name in spec.variableNames)
                      ActionChip(
                        label: Text(name),
                        onPressed: () => _insert(name, spec),
                      ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Funciones disponibles', style: TextStyle(fontSize: 13)),
                  children: [
                    for (final e in functionHelp.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key, style: const TextStyle(fontFamily: 'monospace', color: AppColors.model)),
                        subtitle: Text(e.value),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Operadores + − * / ^ y comparaciones < <= > >= (valen 1 o 0). Decimales con punto: 0.10. Separa argumentos con ; o ,',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ------------------------------------------------ umbral y correlación
          SectionCard(
            title: 'Umbral de riesgo',
            icon: Icons.flag_outlined,
            accent: AppColors.risk,
            child: _thresholdEditor(spec),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Dependencia entre entradas',
            icon: Icons.link,
            accent: AppColors.uncertainty,
            child: _correlationEditor(spec),
          ),
          const SizedBox(height: 12),
          // ------------------------------------------------------------ correr
          SectionCard(
            title: 'Corrida',
            icon: Icons.casino_outlined,
            accent: AppColors.estimate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceRow<int>(
                  options: const [(1000, '1 000'), (10000, '10 000'), (50000, '50 000'), (100000, '100 000')],
                  selected: st.iterations,
                  onSelected: _n.setIterations,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('seed'),
                        controller: _seed,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Semilla', helperText: 'Misma semilla = mismo resultado'),
                        onChanged: (v) {
                          final s = int.tryParse(v.trim());
                          if (s != null && s >= 0) _n.setSeed(s);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Semilla al azar',
                      icon: const Icon(Icons.casino),
                      onPressed: () {
                        final s = DateTime.now().microsecondsSinceEpoch % 100000;
                        _seed.text = '$s';
                        _n.setSeed(s);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('run_simulation'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Simular ${fmtInt(st.iterations)} iteraciones'),
                  onPressed: () => _n.run(),
                ),
                if (st.error != null) ...[
                  const SizedBox(height: 8),
                  InfoBanner(text: st.error!, color: AppColors.confusion, icon: Icons.error_outline),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (st.summary != null) ...[
            if (st.dirty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: InfoBanner(
                  text: 'Cambiaste el modelo o la corrida: estos resultados corresponden a la versión anterior. Vuelve a simular.',
                  color: AppColors.estimate,
                  icon: Icons.update,
                ),
              ),
            SectionCard(
              title: 'Resultados',
              icon: Icons.insights,
              accent: AppColors.estimate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (st.report != null)
                    Text(st.report!.headline, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                  const SizedBox(height: 10),
                  ResultsPanel(summary: st.summary!),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: const ValueKey('go_analyst'),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Analizar con el Analista'),
                    onPressed: () => ref.read(tabProvider.notifier).go(4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _insert(String text, ModelSpec spec) {
    final sel = _expr.selection;
    final base = _expr.text;
    final start = sel.isValid ? sel.start : base.length;
    final end = sel.isValid ? sel.end : base.length;
    final next = base.replaceRange(start, end, text);
    _expr.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + text.length));
    final ns = spec.copyWith(expression: next);
    _n.updateSpec(ns);
    setState(() => _exprError = _checkExpr(ns));
  }

  Widget _inputRow(BuildContext context, ModelSpec spec, int i) {
    final inp = spec.inputs[i];
    return Card(
      color: AppColors.surfaceHigh,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.sample.withValues(alpha: 0.18),
          child: Text(inp.name, style: const TextStyle(fontSize: 11, color: AppColors.sample, fontWeight: FontWeight.w800)),
        ),
        title: Text(inp.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: inp.description.isEmpty && inp.unit.isEmpty
            ? null
            : Text([inp.description, inp.unit].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: AppColors.textMuted)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () async {
                final res = await showInputEditor(context, initial: inp, takenNames: spec.variableNames.toSet());
                if (res == null) return;
                final list = [...spec.inputs]..[i] = res;
                var next = spec.copyWith(inputs: list);
                if (res.name != inp.name) {
                  next = next.copyWith(expression: _renameVar(spec.expression, inp.name, res.name));
                  _expr.text = next.expression;
                }
                _n.updateSpec(next);
                setState(() => _exprError = _checkExpr(next));
              },
            ),
            IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: spec.inputs.length <= 1
                  ? null
                  : () {
                      final list = [...spec.inputs]..removeAt(i);
                      final corr = spec.correlation;
                      final dropCorr = corr != null && (corr.a == inp.name || corr.b == inp.name);
                      final next = spec.copyWith(inputs: list, clearCorrelation: dropCorr);
                      _n.updateSpec(next);
                      setState(() => _exprError = _checkExpr(next));
                    },
            ),
          ],
        ),
      ),
    );
  }

  static String _renameVar(String expr, String from, String to) =>
      expr.replaceAllMapped(RegExp('(?<![A-Za-z0-9_])${RegExp.escape(from)}(?![A-Za-z0-9_])'), (_) => to);

  Widget _thresholdEditor(ModelSpec spec) {
    final enabled = spec.threshold != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Medir la probabilidad de cruzar un umbral'),
          value: enabled,
          onChanged: (v) {
            if (v) {
              _threshold.text = '0';
              _n.updateSpec(spec.copyWith(threshold: 0));
            } else {
              _n.updateSpec(spec.copyWith(clearThreshold: true));
            }
          },
        ),
        if (enabled) ...[
          Row(
            children: [
              SegmentedButton<ThresholdSide>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThresholdSide.below, label: Text('<')),
                  ButtonSegment(value: ThresholdSide.above, label: Text('>')),
                ],
                selected: {spec.side},
                onSelectionChanged: (v) => _n.updateSpec(spec.copyWith(side: v.first)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('threshold'),
                  controller: _threshold,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Umbral'),
                  onChanged: (v) {
                    final x = parseUserNumber(v);
                    if (x != null) _n.updateSpec(spec.copyWith(threshold: x));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Riesgo = «${spec.outputName} ${spec.side.symbol} ${fmtNum(spec.threshold!)}»${spec.thresholdMeaning.isEmpty ? '' : ': ${spec.thresholdMeaning}'}.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _correlationEditor(ModelSpec spec) {
    final names = [for (final i in spec.inputs) if (i.kind != DistKind.constant) i.name];
    if (names.length < 2) {
      return const Text('Necesitas al menos dos entradas inciertas para modelar dependencia.', style: TextStyle(color: AppColors.textMuted));
    }
    final c = spec.correlation;
    final a = c != null && names.contains(c.a) ? c.a : names[0];
    final b = c != null && names.contains(c.b) && c.b != a ? c.b : names.firstWhere((x) => x != a);
    final rho = c?.rho ?? 0.0;
    void set(String na, String nb, double r) {
      if (na == nb) return;
      _n.updateSpec(r == 0 ? spec.copyWith(clearCorrelation: true) : spec.copyWith(correlation: CorrelationSpec(na, nb, r)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value: a,
              items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
              onChanged: (v) {
                if (v != null) set(v, v == b ? names.firstWhere((x) => x != v) : b, rho);
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('↔')),
            DropdownButton<String>(
              value: b,
              items: [for (final n in names) if (n != a) DropdownMenuItem(value: n, child: Text(n))],
              onChanged: (v) {
                if (v != null) set(a, v, rho);
              },
            ),
            const Spacer(),
            Text('ρ = ${fmtFixed(rho, 2)}', style: const TextStyle(color: AppColors.uncertainty, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: rho,
          min: -0.95,
          max: 0.95,
          divisions: 38,
          label: fmtFixed(rho, 2),
          onChanged: (v) => set(a, b, (v * 20).roundToDouble() / 20),
        ),
        const Text(
          'ρ = 0 supone independencia. Con ρ > 0 las dos entradas tienden a ser altas (o bajas) a la vez.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  void _openTemplates(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Plantillas', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final m in modelTemplates)
              ListTile(
                key: ValueKey('tpl_${m.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_graph, color: AppColors.estimate),
                title: Text(m.title),
                subtitle: Text(renderFigures(m.description), maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  _n.loadModel(m);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 12),
            Text('Modelos de los casos profesionales', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final c in cases)
              if (c.model != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline, color: AppColors.sample),
                  title: Text(c.model!.title),
                  subtitle: Text(c.career),
                  onTap: () {
                    _n.loadModel(c.model!);
                    Navigator.of(ctx).pop();
                  },
                ),
          ],
        ),
      ),
    );
  }
}
