import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monte_carlo_simulator/app.dart';
import 'package:monte_carlo_simulator/core/theme/app_theme.dart';
import 'package:monte_carlo_simulator/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vista alta y angosta (360 px lógicos): todo cabe sin desplazar y se
/// detectan desbordes en pantallas de teléfono.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 18000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> pumpApp(WidgetTester tester, {Widget? home}) async {
  useTallPhone(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: home == null ? const MonteCarloApp() : MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(home == null ? MonteCarloApp : MaterialApp).first);
  return ProviderScope.containerOf(element);
}
