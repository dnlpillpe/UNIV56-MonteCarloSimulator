/// Formato numérico en español: coma decimal y espacio fino de miles
/// (1 234,5). Se usa en toda la interfaz y en las cifras del contenido.
library;

const String _nbsp = ' ';

String _group(String intPart) {
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  if (digits.length <= 4) return intPart; // 1234 se deja sin separar
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_nbsp);
    buf.write(digits[i]);
  }
  return (neg ? '-' : '') + buf.toString();
}

/// Número con [decimals] decimales fijos.
String fmtFixed(double x, int decimals) {
  if (x.isNaN) return '—';
  if (x.isInfinite) return x > 0 ? '∞' : '−∞';
  var s = x.toStringAsFixed(decimals);
  if (s == '-0' || RegExp(r'^-0\.0*$').hasMatch(s)) s = s.substring(1);
  final parts = s.split('.');
  final ip = _group(parts[0]);
  final out = parts.length > 1 ? '$ip,${parts[1]}' : ip;
  return out.replaceFirst('-', '−');
}

/// Número con decimales automáticos según su magnitud.
String fmtNum(double x, {int? decimals}) {
  if (decimals != null) return fmtFixed(x, decimals);
  final a = x.abs();
  if (a >= 1000) return fmtFixed(x, 0);
  if (a >= 100) return fmtFixed(x, 1);
  if (a >= 10) return fmtFixed(x, 2);
  if (a >= 1) return fmtFixed(x, 3);
  if (a >= 0.01) return fmtFixed(x, 4);
  if (a == 0) return '0';
  return fmtFixed(x, 5);
}

/// Proporción como porcentaje: 0.3781 → «37,8 %».
String fmtPct(double p, {int decimals = 1}) {
  if (p.isNaN) return '—';
  return '${fmtFixed(p * 100, decimals)}$_nbsp%';
}

/// Entero con separador de miles: 10000 → «10 000».
String fmtInt(int n) => _group(n.toString()).replaceFirst('-', '−');

/// Lee un número escrito por el estudiante: acepta coma o punto decimal,
/// espacios de miles y el signo «−».
double? parseUserNumber(String raw) {
  var s = raw.trim().replaceAll(' ', '').replaceAll(' ', '');
  s = s.replaceAll('−', '-').replaceAll('%', '');
  if (s.isEmpty) return null;
  // «1.234,5» → «1234.5»; «1,5» → «1.5».
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}
