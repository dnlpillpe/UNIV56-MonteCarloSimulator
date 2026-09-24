/// Generadores pseudoaleatorios del simulador.
///
/// Todo el azar de la app pasa por aquí: nunca se usa `dart:math.Random`,
/// porque el estudiante debe poder **ver y repetir la semilla**. Con la misma
/// semilla, la misma simulación produce exactamente los mismos números.
library;

const int _mask32 = 0xFFFFFFFF;

/// Fuente de números uniformes en (0, 1).
abstract class RandomSource {
  /// Siguiente entero sin signo de 32 bits.
  int nextUint32();

  /// Siguiente uniforme en el intervalo abierto (0, 1).
  ///
  /// Se suma 0,5 para no devolver nunca 0 ni 1: así `ln(u)` y la inversa de
  /// la normal siempre están definidas.
  double nextDouble() => (nextUint32() + 0.5) / 4294967296.0;

  /// Nombre corto para mostrar en pantalla.
  String get name;
}

/// Rotación a la izquierda de 32 bits.
int _rotl(int x, int k) => ((x << k) | (x >> (32 - k))) & _mask32;

/// SplitMix32: expande una semilla en estado inicial de buena calidad.
class SplitMix32 {
  SplitMix32(int seed) : _state = seed & _mask32;
  int _state;

  int next() {
    _state = (_state + 0x9E3779B9) & _mask32;
    var z = _state;
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & _mask32;
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & _mask32;
    return (z ^ (z >> 16)) & _mask32;
  }
}

/// xoshiro128** (Blackman y Vigna, 2018): periodo 2^128 − 1, pasa las
/// baterías estadísticas habituales. Es el generador por defecto.
class Xoshiro128 extends RandomSource {
  Xoshiro128(int seed) {
    final sm = SplitMix32(seed);
    _s0 = sm.next();
    _s1 = sm.next();
    _s2 = sm.next();
    _s3 = sm.next();
    if ((_s0 | _s1 | _s2 | _s3) == 0) _s0 = 1;
  }

  late int _s0, _s1, _s2, _s3;

  @override
  String get name => 'xoshiro128**';

  @override
  int nextUint32() {
    final result = (_rotl((_s1 * 5) & _mask32, 7) * 9) & _mask32;
    final t = (_s1 << 9) & _mask32;
    _s2 ^= _s0;
    _s3 ^= _s1;
    _s1 ^= _s2;
    _s0 ^= _s3;
    _s2 ^= t;
    _s3 = _rotl(_s3, 11);
    return result;
  }
}

/// Generador congruencial lineal: x ← (a·x + c) mod m.
///
/// Se incluye **a propósito** con parámetros pequeños para el laboratorio
/// «Fábrica de azar»: su histograma parece perfecto, pero los pares
/// consecutivos caen sobre pocas rectas y la secuencia se repite cada m pasos.
class Lcg extends RandomSource {
  Lcg({required this.a, required this.c, required this.m, required int seed})
      : _x = seed % m;

  final int a;
  final int c;
  final int m;
  int _x;

  @override
  String get name => 'LCG (a=$a, c=$c, m=$m)';

  int get state => _x;

  @override
  int nextUint32() {
    _x = (a * _x + c) % m;
    // Escala a 32 bits para compartir nextDouble.
    return ((_x / m) * 4294967296.0).floor() & _mask32;
  }

  @override
  double nextDouble() {
    _x = (a * _x + c) % m;
    return (_x + 0.5) / m;
  }
}

/// Parámetros del LCG «defectuoso» del laboratorio.
const int badLcgA = 37;
const int badLcgC = 1;
const int badLcgM = 256;

/// Hash FNV-1a de 32 bits: convierte el identificador de un experimento en
/// una semilla estable (igual en todos los dispositivos).
int fnv1a32(String text) {
  var h = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    h ^= unit & 0xFF;
    h = (h * 0x01000193) & _mask32;
    if (unit > 0xFF) {
      h ^= (unit >> 8) & 0xFF;
      h = (h * 0x01000193) & _mask32;
    }
  }
  return h;
}

/// Semilla derivada de un experimento y un número de intento.
int seedFor(String experimentId, int attempt) =>
    fnv1a32('$experimentId#$attempt');
