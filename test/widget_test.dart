import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/presentation/providers.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('la app arranca en Inicio con la marca y los tres módulos', (tester) async {
    await pumpApp(tester);
    expect(find.text('Monte Carlo Simulator'), findsOneWidget);
    expect(find.text('Concepto Monte Carlo'), findsOneWidget);
    expect(find.text('Simulación'), findsOneWidget);
    expect(find.text('Análisis'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('navega por las cinco pestañas', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Aprender'), findsWidgets);
    await tester.tap(find.byIcon(Icons.scatter_plot_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Entradas inciertas'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Práctica generativa'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Ir al simulador'), findsOneWidget);
  });

  testWidgets('simula, analiza y conversa con el analista', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.scatter_plot_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choice_1000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run_simulation')));
    await tester.pumpAndSettle();
    expect(find.text('Resultados'), findsOneWidget);
    expect(container.read(simulatorProvider).summary!.n, 1000);
    expect(container.read(progressProvider).simulationsRun, 1);

    await tester.tap(find.byKey(const ValueKey('go_analyst')));
    await tester.pumpAndSettle();
    expect(find.text('Hallazgos'), findsOneWidget);
    await tester.tap(find.text('¿Cuál es el riesgo?'));
    await tester.pumpAndSettle();
    expect(container.read(chatProvider).messages.length, 2);
    expect(find.text('Motor'), findsOneWidget);
  });

  testWidgets('el simulador muestra el error de una fórmula inválida', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.scatter_plot_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expression')), 'P - Z');
    await tester.pumpAndSettle();
    expect(find.textContaining('no está definida'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run_simulation')));
    await tester.pumpAndSettle();
    expect(container.read(simulatorProvider).error, isNotNull);
  });

  testWidgets('agrega una entrada con el editor', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.scatter_plot_outlined));
    await tester.pumpAndSettle();
    final before = container.read(simulatorProvider).spec.inputs.length;
    await tester.tap(find.byKey(const ValueKey('add_input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('input_save')));
    await tester.pumpAndSettle();
    expect(container.read(simulatorProvider).spec.inputs.length, before + 1);
  });

  testWidgets('carga una plantilla desde la hoja de modelos', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.scatter_plot_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open_templates')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tpl_estimar_pi')));
    await tester.pumpAndSettle();
    expect(container.read(simulatorProvider).spec.id, 'estimar_pi');
    expect(find.text('Estimar π con dardos'), findsOneWidget);
  });
}
