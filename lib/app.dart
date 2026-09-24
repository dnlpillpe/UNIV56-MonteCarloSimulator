import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/shell/home_shell.dart';

class MonteCarloApp extends StatelessWidget {
  const MonteCarloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monte Carlo Simulator',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
