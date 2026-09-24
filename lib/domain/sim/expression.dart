import 'dart:math' as math;

/// Lenguaje de fórmulas del simulador libre.
///
/// El estudiante escribe la salida del modelo como una expresión sobre sus
/// variables de entrada, por ejemplo `anualidad(0.10; 5) * (P - c) * Q - I`.
///
/// Admite: números con punto decimal, variables, `+ - * / ^`, paréntesis,
/// comparaciones `< <= > >=` (valen 1 o 0), constantes `pi` y `e`, y las
/// funciones de [functionHelp]. Los argumentos se separan con `;` o `,`.
///
/// La expresión se compila una sola vez a una función sobre un vector de
/// valores, así cada iteración de la simulación es una llamada directa.

typedef Evaluator = double Function(List<double> vars);

class ExpressionError implements Exception {
  ExpressionError(this.message, this.position);
  final String message;
  final int position;
  @override
  String toString() => 'Posición ${position + 1}: $message';
}

/// Ayuda de funciones que se muestra en el editor.
const Map<String, String> functionHelp = {
  'min(a; b; …)': 'el menor de los valores',
  'max(a; b; …)': 'el mayor de los valores',
  'pos(x)': 'la parte positiva, max(x; 0)',
  'abs(x)': 'valor absoluto',
  'sqrt(x)': 'raíz cuadrada',
  'exp(x)': 'e elevado a x',
  'ln(x)': 'logaritmo natural',
  'round(x)': 'redondeo al entero',
  'si(c; a; b)': 'a si c es verdadero (≠ 0); si no, b',
  'anualidad(r; n)': 'factor de valor actual de n pagos a la tasa r',
};

enum _T { num, id, op, lp, rp, sep, end }

class _Tok {
  _Tok(this.type, this.text, this.pos, [this.value = 0]);
  final _T type;
  final String text;
  final int pos;
  final double value;
}

List<_Tok> _tokenize(String src) {
  final out = <_Tok>[];
  var i = 0;
  bool isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool isAlpha(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || c == '_';
  }

  while (i < src.length) {
    final c = src[i];
    if (c == ' ' || c == '\t' || c == '\n') {
      i++;
      continue;
    }
    if (isDigit(c) || (c == '.' && i + 1 < src.length && isDigit(src[i + 1]))) {
      final start = i;
      while (i < src.length && (isDigit(src[i]) || src[i] == '.')) {
        i++;
      }
      if (i < src.length && (src[i] == 'e' || src[i] == 'E')) {
        final save = i;
        i++;
        if (i < src.length && (src[i] == '+' || src[i] == '-')) i++;
        if (i < src.length && isDigit(src[i])) {
          while (i < src.length && isDigit(src[i])) {
            i++;
          }
        } else {
          i = save;
        }
      }
      final text = src.substring(start, i);
      final v = double.tryParse(text);
      if (v == null) throw ExpressionError('número mal escrito «$text»', start);
      out.add(_Tok(_T.num, text, start, v));
      continue;
    }
    if (isAlpha(c)) {
      final start = i;
      while (i < src.length && (isAlpha(src[i]) || isDigit(src[i]))) {
        i++;
      }
      out.add(_Tok(_T.id, src.substring(start, i), start));
      continue;
    }
    if (c == '(') {
      out.add(_Tok(_T.lp, c, i++));
      continue;
    }
    if (c == ')') {
      out.add(_Tok(_T.rp, c, i++));
      continue;
    }
    if (c == ';' || c == ',') {
      out.add(_Tok(_T.sep, c, i++));
      continue;
    }
    if (c == '<' || c == '>') {
      if (i + 1 < src.length && src[i + 1] == '=') {
        out.add(_Tok(_T.op, '$c=', i));
        i += 2;
      } else {
        out.add(_Tok(_T.op, c, i++));
      }
      continue;
    }
    if ('+-*/^'.contains(c)) {
      out.add(_Tok(_T.op, c, i++));
      continue;
    }
    if (c == '−') {
      out.add(_Tok(_T.op, '-', i++));
      continue;
    }
    if (c == '×') {
      out.add(_Tok(_T.op, '*', i++));
      continue;
    }
    throw ExpressionError('símbolo no reconocido «$c»', i);
  }
  out.add(_Tok(_T.end, '', src.length));
  return out;
}

/// Resultado de compilar una expresión.
class CompiledExpression {
  CompiledExpression(this.source, this.evaluate, this.usedVariables);
  final String source;
  final Evaluator evaluate;

  /// Variables que realmente aparecen en la fórmula.
  final Set<String> usedVariables;
}

class _Parser {
  _Parser(this.tokens, this.varIndex);
  final List<_Tok> tokens;
  final Map<String, int> varIndex;
  final Set<String> used = {};
  int p = 0;

  _Tok get t => tokens[p];

  Evaluator parse() {
    final e = _comparison();
    if (t.type != _T.end) {
      throw ExpressionError('sobra «${t.text}»', t.pos);
    }
    return e;
  }

  Evaluator _comparison() {
    var left = _additive();
    while (t.type == _T.op &&
        (t.text == '<' || t.text == '>' || t.text == '<=' || t.text == '>=')) {
      final op = t.text;
      p++;
      final l = left;
      final r = _additive();
      switch (op) {
        case '<':
          left = (v) => l(v) < r(v) ? 1.0 : 0.0;
        case '>':
          left = (v) => l(v) > r(v) ? 1.0 : 0.0;
        case '<=':
          left = (v) => l(v) <= r(v) ? 1.0 : 0.0;
        default:
          left = (v) => l(v) >= r(v) ? 1.0 : 0.0;
      }
    }
    return left;
  }

  Evaluator _additive() {
    var left = _term();
    while (t.type == _T.op && (t.text == '+' || t.text == '-')) {
      final op = t.text;
      p++;
      final l = left;
      final r = _term();
      left = op == '+' ? ((v) => l(v) + r(v)) : ((v) => l(v) - r(v));
    }
    return left;
  }

  Evaluator _term() {
    var left = _unary();
    while (t.type == _T.op && (t.text == '*' || t.text == '/')) {
      final op = t.text;
      p++;
      final l = left;
      final r = _unary();
      left = op == '*' ? ((v) => l(v) * r(v)) : ((v) => l(v) / r(v));
    }
    return left;
  }

  Evaluator _unary() {
    if (t.type == _T.op && t.text == '-') {
      p++;
      final e = _unary();
      return (v) => -e(v);
    }
    if (t.type == _T.op && t.text == '+') {
      p++;
      return _unary();
    }
    return _power();
  }

  Evaluator _power() {
    final base = _primary();
    if (t.type == _T.op && t.text == '^') {
      p++;
      final exp = _unary(); // asociativa a la derecha: 2^3^2 = 2^9
      return (v) => math.pow(base(v), exp(v)).toDouble();
    }
    return base;
  }

  Evaluator _primary() {
    final tok = t;
    switch (tok.type) {
      case _T.num:
        {
          p++;
          final value = tok.value;
          return (v) => value;
        }
      case _T.lp:
        {
          p++;
          final e = _comparison();
          _expect(_T.rp, 'falta cerrar el paréntesis');
          return e;
        }
      case _T.id:
        {
          p++;
          if (t.type == _T.lp) return _call(tok);
          final name = tok.text;
          if (name == 'pi') return (v) => math.pi;
          if (name == 'e') return (v) => math.e;
          final idx = varIndex[name];
          if (idx == null) {
            throw ExpressionError('la variable «$name» no está definida', tok.pos);
          }
          used.add(name);
          return (v) => v[idx];
        }
      default:
        throw ExpressionError(
          tok.type == _T.end ? 'la fórmula termina antes de tiempo' : 'no se esperaba «${tok.text}»',
          tok.pos,
        );
    }
  }

  void _expect(_T type, String message) {
    if (t.type != type) throw ExpressionError(message, t.pos);
    p++;
  }

  Evaluator _call(_Tok nameTok) {
    p++; // (
    final args = <Evaluator>[];
    if (t.type != _T.rp) {
      args.add(_comparison());
      while (t.type == _T.sep) {
        p++;
        args.add(_comparison());
      }
    }
    _expect(_T.rp, 'falta cerrar el paréntesis de ${nameTok.text}(…)');
    final name = nameTok.text.toLowerCase();
    void arity(int n) {
      if (args.length != n) {
        throw ExpressionError(
            '$name(…) necesita $n argumento${n == 1 ? '' : 's'}', nameTok.pos);
      }
    }

    switch (name) {
      case 'min':
      case 'max':
        {
          if (args.isEmpty) {
            throw ExpressionError('$name(…) necesita al menos un argumento', nameTok.pos);
          }
          final isMin = name == 'min';
          return (v) {
            var r = args[0](v);
            for (var i = 1; i < args.length; i++) {
              final x = args[i](v);
              r = isMin ? (x < r ? x : r) : (x > r ? x : r);
            }
            return r;
          };
        }
      case 'pos':
        {
          arity(1);
          final a = args[0];
          return (v) {
            final x = a(v);
            return x > 0 ? x : 0.0;
          };
        }
      case 'abs':
        {
          arity(1);
          final a = args[0];
          return (v) => a(v).abs();
        }
      case 'sqrt':
        {
          arity(1);
          final a = args[0];
          return (v) => math.sqrt(a(v));
        }
      case 'exp':
        {
          arity(1);
          final a = args[0];
          return (v) => math.exp(a(v));
        }
      case 'ln':
      case 'log':
        {
          arity(1);
          final a = args[0];
          return (v) => math.log(a(v));
        }
      case 'round':
        {
          arity(1);
          final a = args[0];
          return (v) => a(v).roundToDouble();
        }
      case 'si':
      case 'if':
        {
          arity(3);
          final c = args[0], a = args[1], b = args[2];
          return (v) => c(v) != 0 ? a(v) : b(v);
        }
      case 'anualidad':
        {
          arity(2);
          final r = args[0], n = args[1];
          return (v) => annuityFactor(r(v), n(v));
        }
      default:
        throw ExpressionError('función desconocida «${nameTok.text}»', nameTok.pos);
    }
  }
}

/// Factor de valor actual de una anualidad: Σ 1/(1+r)^t, t = 1..n.
double annuityFactor(double r, double n) {
  if (r == 0) return n;
  return (1 - math.pow(1 + r, -n)) / r;
}

/// Compila [source] con las variables [variables] (en ese orden).
CompiledExpression compileExpression(String source, List<String> variables) {
  if (source.trim().isEmpty) {
    throw ExpressionError('escribe la fórmula de la salida', 0);
  }
  final index = <String, int>{
    for (var i = 0; i < variables.length; i++) variables[i]: i,
  };
  final parser = _Parser(_tokenize(source), index);
  final eval = parser.parse();
  return CompiledExpression(source, eval, parser.used);
}

/// Nombre de variable válido: letra inicial, luego letras, dígitos o «_».
bool isValidVariableName(String name) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) return false;
  const reserved = {
    'pi', 'e', 'min', 'max', 'pos', 'abs', 'sqrt', 'exp', 'ln', 'log',
    'round', 'si', 'if', 'anualidad',
  };
  return !reserved.contains(name);
}
