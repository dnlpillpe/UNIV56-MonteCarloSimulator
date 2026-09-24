import 'dart:math' as math;

import '../../core/math/distributions.dart';
import '../../core/math/special.dart';
import '../../core/util/format.dart';
import '../sim/expression.dart';

/// Registro de cifras del contenido.
///
/// Regla del proyecto: **ningún número del contenido se escribe a mano**.
/// Los textos citan `{{id}}` y aquí se calcula cada cifra con fórmulas
/// cerradas o cuadratura determinista. Una réplica independiente en Python
/// (`tool/replica.py`, con SciPy) recalcula las mismas cifras y las guarda en
/// `test/fixtures/figures.json`; `test/figures_test.dart` exige que coincidan.

enum FigureFormat { percent, decimal, integer }

class Figure {
  const Figure(this.id, this.compute, this.format, {this.decimals = 2, this.tolerance = 1e-6});
  final String id;
  final double Function() compute;
  final FigureFormat format;
  final int decimals;

  /// Tolerancia absoluta frente a la réplica (mayor en cuadraturas).
  final double tolerance;

  double get value => compute();

  String get text => switch (format) {
        FigureFormat.percent => fmtPct(value, decimals: decimals),
        FigureFormat.decimal => fmtFixed(value, decimals),
        FigureFormat.integer => fmtInt(value.round()),
      };
}

// ---------------------------------------------------------------- constantes
const double _z95 = 1.6448536269514722; // Φ⁻¹(0,95)
const double _z90 = 1.2815515655446004; // Φ⁻¹(0,90)
const double _z975 = 1.959963984540054;

double _erf(double x) => 2 * normalCdf(x * math.sqrt2) - 1;

// π con dardos
final double _pQuarter = math.pi / 4;
double get _piCoef => 4 * math.sqrt(_pQuarter * (1 - _pQuarter));

// Área bajo e^{-x²}
double get _areaTrue => math.sqrt(math.pi) / 2 * _erf(1);
double get _areaSdHit => math.sqrt(_areaTrue * (1 - _areaTrue));
double get _areaSdMean {
  final ef2 = math.sqrt(math.pi / 8) * _erf(math.sqrt2);
  return math.sqrt(ef2 - _areaTrue * _areaTrue);
}

// Proyecto (VAN)
const TriangularDist npvPrice = TriangularDist(8, 10, 11);
const TriangularDist npvCost = TriangularDist(5.5, 6, 7);
const TriangularDist npvVolume = TriangularDist(30, 50, 55);
const double npvInvestment = 550;
double get npvAnnuity => annuityFactor(0.10, 5);

double get _npvMode => npvAnnuity * (10 - 6) * 50 - npvInvestment;
double get _npvMean =>
    npvAnnuity * (npvPrice.mean - npvCost.mean) * npvVolume.mean - npvInvestment;

double get _varDQ {
  final ed = npvPrice.mean - npvCost.mean;
  final vd = npvPrice.variance + npvCost.variance;
  final eq = npvVolume.mean;
  final vq = npvVolume.variance;
  return (vd + ed * ed) * (vq + eq * eq) - ed * ed * eq * eq;
}

double get _npvSd => npvAnnuity * math.sqrt(_varDQ);

/// P(VAN < 0) por cuadratura de punto medio en el espacio de probabilidad
/// de precio y costo, con la acumulada exacta del volumen.
double npvLossProbability({int grid = 800}) {
  final k = npvInvestment / npvAnnuity; // flujo anual mínimo
  final ps = List<double>.generate(grid, (i) => npvPrice.quantile((i + 0.5) / grid));
  final cs = List<double>.generate(grid, (i) => npvCost.quantile((i + 0.5) / grid));
  var acc = 0.0;
  for (final p in ps) {
    for (final c in cs) {
      final d = p - c;
      acc += d <= 0 ? 1.0 : npvVolume.cdf(k / d);
    }
  }
  return acc / (grid * grid);
}

// Capacidad
const double capMu = 100, capSigma = 25, capC = 100, capMargin = 30, capFixed = 1500;
double capExpectedSales(double c) {
  final z = (c - capMu) / capSigma;
  final excess = capSigma * normalPdf(z) + (capMu - c) * (1 - normalCdf(z));
  return capMu - excess;
}

// Tareas en paralelo
const TriangularDist mergeTask = TriangularDist(5, 8, 14);
double get _mergeEMax {
  // E[max] = b − ∫_a^b F(x)² dx  (Simpson con 4000 subintervalos)
  const a = 5.0, b = 14.0;
  const n = 4000;
  const h = (b - a) / n;
  var s = 0.0;
  for (var i = 0; i <= n; i++) {
    final x = a + i * h;
    final f = mergeTask.cdf(x);
    final w = (i == 0 || i == n) ? 1 : (i.isOdd ? 4 : 2);
    s += w * f * f;
  }
  return b - s * h / 3;
}

// Costos correlacionados
double _corrSd(double rho) => 20 * math.sqrt(2 + 2 * rho);

// Forma de la entrada: normal vs lognormal con media 100 y desviación 50
final LogNormalDist _shapeLn = LogNormalDist.fromMeanSd(100, 50);

// Curva S: costo lognormal con mediana 100 y σ_ln 0,6
const LogNormalDist scCost = LogNormalDist(4.605170185988092, 0.6);

// Casos
final LogNormalDist minGrade = LogNormalDist.fromMeanSd(0.8, 0.4);
double _slaProb(List<double> means, double t) =>
    means.fold(1.0, (acc, m) => acc * (1 - math.exp(-t / m)));
const LogNormalDist ambConc = LogNormalDist(3.4011973816621555, 0.5); // mediana 30

double _irwinHallUpper3(double s) {
  // P(U1+U2+U3 − 1,5 > s) para uniformes en [0,1], 0 ≤ s ≤ 1,5
  final t = 1.5 - s;
  if (t <= 0) return 0;
  if (t <= 1) return t * t * t / 6;
  return 1; // no se usa fuera de [0,5; 1,5]
}

double get _birthday30 {
  var q = 1.0;
  for (var k = 0; k < 30; k++) {
    q *= (365 - k) / 365;
  }
  return 1 - q;
}

double _birthday(int n) {
  var q = 1.0;
  for (var k = 0; k < n; k++) {
    q *= (365 - k) / 365;
  }
  return 1 - q;
}

int get _birthdayN50 {
  var n = 1;
  while (_birthday(n) < 0.5) {
    n++;
  }
  return n;
}

// --------------------------------------------------------------- el registro
final Map<String, Figure> figures = {
  for (final f in <Figure>[
    // ---- Módulo 1: π, error y estimadores
    Figure('pi_se_coef', () => _piCoef, FigureFormat.decimal, decimals: 3),
    Figure('pi_se_100', () => _piCoef / 10, FigureFormat.decimal, decimals: 3),
    Figure('pi_se_400', () => _piCoef / 20, FigureFormat.decimal, decimals: 3),
    Figure('pi_se_1000', () => _piCoef / math.sqrt(1000), FigureFormat.decimal, decimals: 3),
    Figure('pi_se_1600', () => _piCoef / 40, FigureFormat.decimal, decimals: 3),
    Figure('pi_se_6400', () => _piCoef / 80, FigureFormat.decimal, decimals: 3),
    Figure('pi_half_100', () => _z975 * _piCoef / 10, FigureFormat.decimal, decimals: 2),
    Figure('pi_half_500', () => _z975 * _piCoef / math.sqrt(500), FigureFormat.decimal, decimals: 2),
    Figure('pi_n_001', () => math.pow(_z975 * _piCoef / 0.01, 2).toDouble().ceilToDouble(), FigureFormat.integer),
    Figure('area_true', () => _areaTrue, FigureFormat.decimal, decimals: 4),
    Figure('area_sd_hit', () => _areaSdHit, FigureFormat.decimal, decimals: 3),
    Figure('area_sd_mean', () => _areaSdMean, FigureFormat.decimal, decimals: 3),
    Figure('area_var_ratio', () => math.pow(_areaSdHit / _areaSdMean, 2).toDouble(), FigureFormat.decimal, decimals: 1),
    Figure('exp_below_mean', () => 1 - math.exp(-1), FigureFormat.percent),
    Figure('exp_median', () => 2 * math.ln2, FigureFormat.decimal, decimals: 2),

    // ---- Módulo 2: proyecto, capacidad, paralelo, correlación, forma
    Figure('npv_annuity', () => npvAnnuity, FigureFormat.decimal, decimals: 4),
    Figure('npv_mode', () => _npvMode, FigureFormat.decimal, decimals: 0),
    Figure('npv_mean', () => _npvMean, FigureFormat.decimal, decimals: 0),
    Figure('npv_sd', () => _npvSd, FigureFormat.decimal, decimals: 0),
    Figure('npv_ploss', () => npvLossProbability(), FigureFormat.percent, tolerance: 1e-4),
    Figure('npv_price_mean', () => npvPrice.mean, FigureFormat.decimal, decimals: 2),
    Figure('npv_volume_mean', () => npvVolume.mean, FigureFormat.decimal, decimals: 0),
    Figure('tornado_share_price', () => math.pow(npvVolume.mean, 2) * npvPrice.variance / _varDQ, FigureFormat.percent, decimals: 0),
    Figure('tornado_share_cost', () => math.pow(npvVolume.mean, 2) * npvCost.variance / _varDQ, FigureFormat.percent, decimals: 0),
    Figure('tornado_share_volume', () => math.pow(npvPrice.mean - npvCost.mean, 2) * npvVolume.variance / _varDQ, FigureFormat.percent, decimals: 0),
    Figure('cap_expected_sales', () => capExpectedSales(capC), FigureFormat.decimal, decimals: 1),
    Figure('cap_gap', () => (capMu - capExpectedSales(capC)) / capMu, FigureFormat.percent),
    Figure('cap_profit_plan', () => capMargin * capMu - capFixed, FigureFormat.decimal, decimals: 0),
    Figure('cap_profit_expected', () => capMargin * capExpectedSales(capC) - capFixed, FigureFormat.decimal, decimals: 0),
    Figure('merge_task_mean', () => mergeTask.mean, FigureFormat.decimal, decimals: 0),
    Figure('merge_p_one', () => mergeTask.cdf(9), FigureFormat.percent),
    Figure('merge_p_two', () => math.pow(mergeTask.cdf(9), 2).toDouble(), FigureFormat.percent),
    Figure('merge_mean_max', () => _mergeEMax, FigureFormat.decimal, decimals: 2),
    Figure('merge_mean_total', () => _mergeEMax + 5, FigureFormat.decimal, decimals: 2),
    Figure('corr_sd_0', () => _corrSd(0), FigureFormat.decimal, decimals: 1),
    Figure('corr_sd_08', () => _corrSd(0.8), FigureFormat.decimal, decimals: 1),
    Figure('corr_p95_0', () => 200 + _z95 * _corrSd(0), FigureFormat.decimal, decimals: 1),
    Figure('corr_p95_08', () => 200 + _z95 * _corrSd(0.8), FigureFormat.decimal, decimals: 1),
    Figure('corr_p95_m05', () => 200 + _z95 * _corrSd(-0.5), FigureFormat.decimal, decimals: 1),
    Figure('corr_p250_0', () => 1 - normalCdf(50 / _corrSd(0)), FigureFormat.percent),
    Figure('corr_p250_06', () => 1 - normalCdf(50 / _corrSd(0.6)), FigureFormat.percent),
    Figure('shape_normal_tail', () => 1 - normalCdf(2), FigureFormat.percent, decimals: 2),
    Figure('shape_normal_neg', () => normalCdf(-2), FigureFormat.percent, decimals: 2),
    Figure('shape_lognormal_tail', () => 1 - _shapeLn.cdf(200), FigureFormat.percent, decimals: 2),

    // ---- Módulo 3: precisión, eventos raros, curva S, decisión
    Figure('rare_p0_100', () => math.pow(0.998, 100).toDouble(), FigureFormat.percent),
    Figure('rare_p0_1000', () => math.pow(0.998, 1000).toDouble(), FigureFormat.percent),
    Figure('rare_relse_1000', () => math.sqrt(0.998 / (1000 * 0.002)), FigureFormat.percent, decimals: 0),
    Figure('rare_relse_10000', () => math.sqrt(0.998 / (10000 * 0.002)), FigureFormat.percent, decimals: 0),
    Figure('rare_rule3_1000', () => 3 / 1000, FigureFormat.percent),
    Figure('rare_n_rel10', () => (0.998 / (0.002 * 0.01)).ceilToDouble(), FigureFormat.integer),
    Figure('sc_mean', () => scCost.mean, FigureFormat.decimal, decimals: 1),
    Figure('sc_median', () => scCost.median, FigureFormat.decimal, decimals: 0),
    Figure('sc_p10', () => scCost.quantile(0.10), FigureFormat.decimal, decimals: 1),
    Figure('sc_p90', () => scCost.quantile(0.90), FigureFormat.decimal, decimals: 1),
    Figure('sc_p_over_mean', () => 1 - scCost.cdf(scCost.mean), FigureFormat.percent),
    Figure('cmp_a_ploss', () => normalCdf(-120 / 80), FigureFormat.percent),
    Figure('cmp_a_p5', () => 120 - _z95 * 80, FigureFormat.decimal, decimals: 1),
    Figure('cmp_b_p5', () => 100 - _z95 * 15, FigureFormat.decimal, decimals: 1),
    Figure('cmp_b_ploss', () => normalCdf(-100 / 15), FigureFormat.percent, decimals: 4),

    // ---- Cifras auxiliares de ejercicios (respuestas y errores típicos)
    Figure('pi_se_wrong_n', () => _piCoef / 1000, FigureFormat.decimal, decimals: 5),
    Figure('exp_mean', () => 2, FigureFormat.decimal, decimals: 0),
    Figure('exp_wrong_scale', () => 0.5 * 2, FigureFormat.decimal, decimals: 1),
    Figure('area_sd_ratio', () => _areaSdHit / _areaSdMean, FigureFormat.decimal, decimals: 2),
    Figure('cap_plan_sales', () => math.min(capMu, capC), FigureFormat.decimal, decimals: 0),
    Figure('corr_sd_wrong', () => 40, FigureFormat.decimal, decimals: 0),
    Figure('zero', () => 0, FigureFormat.decimal, decimals: 0),
    Figure('half', () => 0.5, FigureFormat.percent, decimals: 0),
    Figure('n_req_ex', () => math.pow(_z975 * 140 / 5, 2).toDouble().ceilToDouble(), FigureFormat.integer),
    Figure('n_req_ex_wrong', () => _z975 * 140 / 5, FigureFormat.decimal, decimals: 1),
    Figure('se_ex', () => 200 / math.sqrt(10000), FigureFormat.decimal, decimals: 1),
    Figure('se_ex_wrong_n', () => 200 / 10000, FigureFormat.decimal, decimals: 2),
    Figure('se_ex_sd', () => 200, FigureFormat.decimal, decimals: 0),
    Figure('rare_abs_se_10000', () => math.sqrt(0.002 * 0.998 / 10000), FigureFormat.percent, decimals: 3),

    // ---- Casos profesionales
    Figure('min_p_below', () => minGrade.cdf(0.5), FigureFormat.percent),
    Figure('min_median', () => minGrade.median, FigureFormat.decimal, decimals: 2),
    Figure('min_normal_neg', () => normalCdf(-2), FigureFormat.percent, decimals: 2),
    Figure('sis_p_sla', () => _slaProb(const [40, 60, 100], 200), FigureFormat.percent),
    Figure('sis_p_sla_fast', () => _slaProb(const [40, 60, 70], 200), FigureFormat.percent),
    Figure('sis_p_sla_other', () => _slaProb(const [40, 40, 100], 200), FigureFormat.percent),
    Figure('ele_p_out', () => 2 * _irwinHallUpper3(1), FigureFormat.percent, decimals: 2),
    Figure('ele_sd_one', () => 1 / math.sqrt(12), FigureFormat.decimal, decimals: 3),
    Figure('ele_sd_sum', () => math.sqrt(3 / 12), FigureFormat.decimal, decimals: 2),
    Figure('ele_sd_wrong', () => 3 / math.sqrt(12), FigureFormat.decimal, decimals: 3),
    Figure('ele_normal_approx', () => 2 * (1 - normalCdf(2)), FigureFormat.percent, decimals: 2),
    Figure('amb_p_exceed', () => 1 - ambConc.cdf(50), FigureFormat.percent),
    Figure('amb_mean', () => ambConc.mean, FigureFormat.decimal, decimals: 1),
    Figure('amb_days', () => 365 * (1 - ambConc.cdf(50)), FigureFormat.integer),
    Figure('amb_model_sd', () => ambConc.sd, FigureFormat.decimal, decimals: 2),
    Figure('adm_mean_demand', () => (40 + 100) / 2, FigureFormat.decimal, decimals: 0),
    Figure('adm_cr', () => 3 / 4.5, FigureFormat.decimal, decimals: 3),
    Figure('adm_qstar', () => 40 + 60 * (3 / 4.5), FigureFormat.integer),
    Figure('adm_profit_q70', () => _newsvendorProfit(70), FigureFormat.decimal, decimals: 2),
    Figure('adm_profit_q80', () => _newsvendorProfit(80), FigureFormat.decimal, decimals: 2),
    Figure('eco_p_loss', () => normalCdf(-0.6 / (0.15 * math.sqrt(10))), FigureFormat.percent),
    Figure('eco_median', () => math.exp(0.6), FigureFormat.decimal, decimals: 2),
    Figure('eco_mean', () => math.exp(0.6 + 0.15 * 0.15 * 10 / 2), FigureFormat.decimal, decimals: 2),
    Figure('eco_sd_wrong', () => 0.15 * 10, FigureFormat.decimal, decimals: 2),
    Figure('eco_sd_log', () => 0.15 * math.sqrt(10), FigureFormat.decimal, decimals: 3),
    Figure('con_rule3', () => 3 / 150, FigureFormat.percent),
    Figure('con_p0_3pct', () => math.pow(0.97, 150).toDouble(), FigureFormat.percent, decimals: 2),
    Figure('psi_p10', () => binomialUpperTail(20, 0.25, 10), FigureFormat.percent, decimals: 2),
    Figure('psi_pass_500', () => 500 * binomialUpperTail(20, 0.25, 10), FigureFormat.decimal, decimals: 1),
    Figure('bio_p_half', () => normalCdf((math.log(0.5) - 0.4) / (0.2 * math.sqrt(20))), FigureFormat.percent),
    Figure('bio_sd_log', () => 0.2 * math.sqrt(20), FigureFormat.decimal, decimals: 3),
    Figure('bio_median_ratio', () => math.exp(0.4), FigureFormat.decimal, decimals: 2),
    Figure('hum_p30', () => _birthday30, FigureFormat.percent),
    Figure('hum_n50', () => _birthdayN50.toDouble(), FigureFormat.integer),
    Figure('hum_p23', () => _birthday(23), FigureFormat.percent),
    Figure('dev_sd_total', () => 100 * math.sqrt(12), FigureFormat.decimal, decimals: 0),
    Figure('dev_sd_wrong', () => 1200, FigureFormat.integer),
    Figure('dev_p_goal', () => normalCdf(100 / (100 * math.sqrt(12))), FigureFormat.percent),
    Figure('dev_p_goal_wrong', () => normalCdf(100 / 1200), FigureFormat.percent),
    Figure('dev_p10', () => 3600 - _z90 * 100 * math.sqrt(12), FigureFormat.decimal, decimals: 0),
    Figure('dev_p90', () => 3600 + _z90 * 100 * math.sqrt(12), FigureFormat.decimal, decimals: 0),
  ])
    f.id: f,
};

/// Utilidad esperada del inventario con demanda Uniforme(40; 100),
/// precio 5, costo 2 y remate 0,5.
double _newsvendorProfit(double q) {
  const a = 40.0, b = 100.0;
  final eMin = q - (q - a) * (q - a) / (2 * (b - a));
  return 5 * eMin + 0.5 * (q - eMin) - 2 * q;
}

final RegExp _figRef = RegExp(r'\{\{([a-z0-9_]+)\}\}');

/// Sustituye las marcas `{{id}}` por las cifras formateadas.
String renderFigures(String text) => text.replaceAllMapped(_figRef, (m) {
      final f = figures[m.group(1)];
      return f == null ? '⟨${m.group(1)}?⟩' : f.text;
    });

/// Identificadores citados en un texto.
Iterable<String> figureRefs(String text) =>
    _figRef.allMatches(text).map((m) => m.group(1)!);

/// Valor numérico de una cifra (para respuestas numéricas).
double figureValue(String id) {
  final f = figures[id];
  if (f == null) throw ArgumentError('Cifra desconocida: $id');
  return f.value;
}
