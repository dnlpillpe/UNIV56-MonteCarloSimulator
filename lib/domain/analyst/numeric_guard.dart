/// Guardia numérica: toda cifra que escriba la IA debe coincidir con una
/// cifra conocida por el motor. Si inventa o calcula un número, su respuesta
/// se descarta y se muestra la del motor.
///
/// Regla del proyecto: **la IA redacta, el motor calcula**.
library;

class GuardResult {
  const GuardResult(this.ok, this.unknownNumbers);
  final bool ok;
  final List<String> unknownNumbers;
}

class NumericGuard {
  const NumericGuard({this.relTol = 0.015, this.absTol = 0.006});

  final double relTol;
  final double absTol;

  /// Números que siempre se permiten: niveles de confianza y percentiles
  /// habituales, y enteros pequeños («dos entradas», «P5»).
  static const List<double> _alwaysAllowed = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 20, 25, 50, 75, 80, 90, 95, 99, 100, 1000,
    1.96, 0.5, 0.05, 0.95, 0.9, 0.1,
  ];

  static final RegExp _grouped = RegExp(r'(?<![\w.,])-?\d{1,3}(?:[    ]\d{3})+(?:,\d+)?');
  static final RegExp _plain = RegExp(r'(?<![A-Za-zÀ-ÿ_\d])-?\d+(?:[.,]\d+)*');

  /// Interpretaciones posibles de un número escrito (coma o punto decimal).
  static List<double> candidates(String raw) {
    final s = raw.replaceAll(RegExp(r'[    ]'), '');
    final out = <double>[];
    void tryAdd(String t) {
      final v = double.tryParse(t);
      if (v != null) out.add(v);
    }

    if (!s.contains(',') && !s.contains('.')) {
      tryAdd(s);
    } else if (s.contains(',') && !s.contains('.')) {
      final parts = s.split(',');
      if (parts.length == 2) tryAdd(s.replaceAll(',', '.')); // 3,16
      if (parts.skip(1).every((p) => p.length == 3)) tryAdd(s.replaceAll(',', '')); // 1,234
    } else if (s.contains('.') && !s.contains(',')) {
      final parts = s.split('.');
      if (parts.length == 2) tryAdd(s); // 3.16
      if (parts.skip(1).every((p) => p.length == 3)) tryAdd(s.replaceAll('.', '')); // 1.234
    } else {
      // Ambos: el último separador es el decimal.
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        tryAdd(s.replaceAll('.', '').replaceAll(',', '.'));
      } else {
        tryAdd(s.replaceAll(',', ''));
      }
    }
    return out;
  }

  /// Extrae los números escritos en [text].
  static List<String> extract(String text) {
    var t = text.replaceAll('−', '-');
    final found = <String>[];
    t = t.replaceAllMapped(_grouped, (m) {
      found.add(m.group(0)!);
      return ' ';
    });
    for (final m in _plain.allMatches(t)) {
      found.add(m.group(0)!);
    }
    return found;
  }

  bool _close(double v, double a) {
    final d = (v - a).abs();
    if (d <= absTol || d <= relTol * a.abs()) return true;
    return (v.abs() - a.abs()).abs() <= relTol * a.abs(); // signo escrito aparte
  }

  bool _matches(double v, List<double> allowed) {
    for (final a in _alwaysAllowed) {
      if (_close(v, a)) return true;
    }
    for (final a in allowed) {
      // Un porcentaje escrito (37,8) equivale a la proporción (0,378).
      if (_close(v, a) || (a.abs() <= 1 && _close(v / 100, a))) return true;
    }
    return false;
  }

  GuardResult check(String text, List<double> allowed) {
    final unknown = <String>[];
    for (final raw in extract(text)) {
      final cands = candidates(raw);
      if (cands.isEmpty) continue;
      if (!cands.any((c) => _matches(c, allowed))) unknown.add(raw);
    }
    return GuardResult(unknown.isEmpty, unknown);
  }
}
