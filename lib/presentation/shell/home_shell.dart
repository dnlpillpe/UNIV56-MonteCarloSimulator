import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analyst/analyst_screen.dart';
import '../home/home_screen.dart';
import '../learn/learn_screen.dart';
import '../practice/practice_screen.dart';
import '../providers.dart';
import '../simulator/simulator_screen.dart';

/// Armazón con cinco destinos: Inicio, Aprender (módulos y laboratorios),
/// Simulador, Práctica (ejercicios y casos) y Analista.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    LearnScreen(),
    SimulatorScreen(),
    PracticeScreen(),
    AnalystScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return Scaffold(
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).go(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Aprender'),
          NavigationDestination(icon: Icon(Icons.scatter_plot_outlined), selectedIcon: Icon(Icons.scatter_plot), label: 'Simulador'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Práctica'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Analista'),
        ],
      ),
    );
  }
}
