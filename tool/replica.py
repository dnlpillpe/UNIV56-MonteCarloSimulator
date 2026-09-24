#!/usr/bin/env python3
"""Réplica independiente de las cifras del contenido.

Recalcula cada cifra de lib/domain/content/figures.dart con métodos
distintos a los de Dart (SciPy: distribuciones exactas, integración
adaptativa, binomial exacta) y escribe test/fixtures/figures.json.
`test/figures_test.dart` exige que el motor Dart coincida con estos valores.

Uso:  pip install scipy numpy && python3 tool/replica.py
"""
import json
import math
from pathlib import Path

from scipy import integrate, stats

ROOT = Path(__file__).resolve().parent.parent

tri = lambda a, m, b: stats.triang(c=(m - a) / (b - a), loc=a, scale=b - a)
N = stats.norm


def lognorm_mean_sd(mean, sd):
    s2 = math.log(1 + sd * sd / (mean * mean))
    return stats.lognorm(s=math.sqrt(s2), scale=math.exp(math.log(mean) - s2 / 2))


def annuity(r, n):
    return sum(1 / (1 + r) ** t for t in range(1, n + 1))


z95, z90, z975 = N.ppf(0.95), N.ppf(0.90), N.ppf(0.975)
pq = math.pi / 4
pi_coef = 4 * math.sqrt(pq * (1 - pq))

area = integrate.quad(lambda x: math.exp(-x * x), 0, 1, epsabs=1e-14)[0]
ef2 = integrate.quad(lambda x: math.exp(-2 * x * x), 0, 1, epsabs=1e-14)[0]
sd_hit = math.sqrt(area * (1 - area))
sd_mean = math.sqrt(ef2 - area * area)

P, C, Q = tri(8, 10, 11), tri(5.5, 6, 7), tri(30, 50, 55)
AF = annuity(0.10, 5)
I0 = 550.0
ED = P.mean() - C.mean()
VD = P.var() + C.var()
EQ, VQ = Q.mean(), Q.var()
VDQ = (VD + ED ** 2) * (VQ + EQ ** 2) - ED ** 2 * EQ ** 2


def npv_ploss():
    k = I0 / AF

    def inner(p):
        # P((p − c)·Q < k) integrando sobre c
        def g(c):
            d = p - c
            return C.pdf(c) * (1.0 if d <= 0 else Q.cdf(k / d))
        return integrate.quad(g, 5.5, 7, points=[6], limit=200, epsabs=1e-12)[0]

    return integrate.quad(lambda p: P.pdf(p) * inner(p), 8, 11, points=[10], limit=200, epsabs=1e-11)[0]


def cap_sales(c, mu=100, sigma=25):
    # E[min(D, c)] por integración directa
    return integrate.quad(lambda d: min(d, c) * N.pdf(d, mu, sigma), mu - 12 * sigma, mu + 12 * sigma, points=[c], limit=200)[0]


M = tri(5, 8, 14)
e_max = integrate.quad(lambda x: x * 2 * M.cdf(x) * M.pdf(x), 5, 14, points=[8], limit=200)[0]
corr_sd = lambda r: 20 * math.sqrt(2 + 2 * r)
LN = lognorm_mean_sd(100, 50)
SC = stats.lognorm(s=0.6, scale=100)
MING = lognorm_mean_sd(0.8, 0.4)
AMB = stats.lognorm(s=0.5, scale=30)


def sla(means, t=200):
    # P(max ≤ t) integrando la densidad del máximo
    F = lambda x: math.prod(1 - math.exp(-x / m) for m in means)
    return F(t)


def newsvendor(q, a=40, b=100):
    D = stats.uniform(loc=a, scale=b - a)
    emin = integrate.quad(lambda d: min(d, q) * D.pdf(d), a, b, points=[q])[0]
    return 5 * emin + 0.5 * (q - emin) - 2 * q


def birthday(n):
    q = 1.0
    for k in range(n):
        q *= (365 - k) / 365
    return 1 - q


n50 = next(n for n in range(1, 100) if birthday(n) >= 0.5)
irwin = stats.rv_histogram  # (no se usa: la suma de 3 uniformes se integra abajo)


def irwin_hall_out(width=1.0):
    # P(|U1+U2+U3 − 1,5| > 1) por integración de la densidad de Irwin-Hall
    def f(s):
        if s < 0 or s > 3:
            return 0
        if s < 1:
            return s * s / 2
        if s < 2:
            return (-2 * s * s + 6 * s - 3) / 2
        return (3 - s) ** 2 / 2
    inside = integrate.quad(f, 0.5, 2.5, points=[1, 2])[0]
    return 1 - inside


fig = {
    "pi_se_coef": pi_coef,
    "pi_se_100": pi_coef / 10,
    "pi_se_400": pi_coef / 20,
    "pi_se_1000": pi_coef / math.sqrt(1000),
    "pi_se_1600": pi_coef / 40,
    "pi_se_6400": pi_coef / 80,
    "pi_half_100": z975 * pi_coef / 10,
    "pi_half_500": z975 * pi_coef / math.sqrt(500),
    "pi_n_001": math.ceil((z975 * pi_coef / 0.01) ** 2),
    "area_true": area,
    "area_sd_hit": sd_hit,
    "area_sd_mean": sd_mean,
    "area_var_ratio": (sd_hit / sd_mean) ** 2,
    "exp_below_mean": stats.expon(scale=2).cdf(2),
    "exp_median": stats.expon(scale=2).median(),
    "npv_annuity": AF,
    "npv_mode": AF * (10 - 6) * 50 - I0,
    "npv_mean": AF * ED * EQ - I0,
    "npv_sd": AF * math.sqrt(VDQ),
    "npv_ploss": npv_ploss(),
    "npv_price_mean": P.mean(),
    "npv_volume_mean": Q.mean(),
    "tornado_share_price": EQ ** 2 * P.var() / VDQ,
    "tornado_share_cost": EQ ** 2 * C.var() / VDQ,
    "tornado_share_volume": ED ** 2 * VQ / VDQ,
    "cap_expected_sales": cap_sales(100),
    "cap_gap": (100 - cap_sales(100)) / 100,
    "cap_profit_plan": 30 * 100 - 1500,
    "cap_profit_expected": 30 * cap_sales(100) - 1500,
    "merge_task_mean": M.mean(),
    "merge_p_one": M.cdf(9),
    "merge_p_two": M.cdf(9) ** 2,
    "merge_mean_max": e_max,
    "merge_mean_total": e_max + 5,
    "corr_sd_0": corr_sd(0),
    "corr_sd_08": corr_sd(0.8),
    "corr_p95_0": N.ppf(0.95, 200, corr_sd(0)),
    "corr_p95_08": N.ppf(0.95, 200, corr_sd(0.8)),
    "corr_p95_m05": N.ppf(0.95, 200, corr_sd(-0.5)),
    "corr_p250_0": N.sf(250, 200, corr_sd(0)),
    "corr_p250_06": N.sf(250, 200, corr_sd(0.6)),
    "shape_normal_tail": N.sf(200, 100, 50),
    "shape_normal_neg": N.cdf(0, 100, 50),
    "shape_lognormal_tail": LN.sf(200),
    "pi_se_wrong_n": pi_coef / 1000,
    "exp_mean": 2,
    "exp_wrong_scale": 1.0,
    "area_sd_ratio": sd_hit / sd_mean,
    "cap_plan_sales": 100,
    "corr_sd_wrong": 40,
    "zero": 0,
    "half": 0.5,
    "n_req_ex": math.ceil((z975 * 140 / 5) ** 2),
    "n_req_ex_wrong": z975 * 140 / 5,
    "se_ex": 2.0,
    "se_ex_wrong_n": 0.02,
    "se_ex_sd": 200,
    "rare_abs_se_10000": stats.binom(10000, 0.002).std() / 10000,
    "rare_p0_100": stats.binom(100, 0.002).pmf(0),
    "rare_p0_1000": stats.binom(1000, 0.002).pmf(0),
    "rare_relse_1000": stats.binom(1000, 0.002).std() / 1000 / 0.002,
    "rare_relse_10000": stats.binom(10000, 0.002).std() / 10000 / 0.002,
    "rare_rule3_1000": 0.003,
    "rare_n_rel10": math.ceil(0.998 / (0.002 * 0.01)),
    "sc_mean": SC.mean(),
    "sc_median": SC.median(),
    "sc_p10": SC.ppf(0.10),
    "sc_p90": SC.ppf(0.90),
    "sc_p_over_mean": SC.sf(SC.mean()),
    "cmp_a_ploss": N.cdf(0, 120, 80),
    "cmp_a_p5": N.ppf(0.05, 120, 80),
    "cmp_b_p5": N.ppf(0.05, 100, 15),
    "cmp_b_ploss": N.cdf(0, 100, 15),
    "min_p_below": MING.cdf(0.5),
    "min_median": MING.median(),
    "min_normal_neg": N.cdf(0, 0.8, 0.4),
    "sis_p_sla": sla([40, 60, 100]),
    "sis_p_sla_fast": sla([40, 60, 70]),
    "sis_p_sla_other": sla([40, 40, 100]),
    "ele_p_out": irwin_hall_out(),
    "ele_sd_one": stats.uniform(9.5, 1).std(),
    "ele_sd_sum": math.sqrt(3) * stats.uniform(9.5, 1).std(),
    "ele_sd_wrong": 3 * stats.uniform(9.5, 1).std(),
    "ele_normal_approx": 2 * N.sf(2),
    "amb_p_exceed": AMB.sf(50),
    "amb_mean": AMB.mean(),
    "amb_days": 365 * AMB.sf(50),
    "amb_model_sd": AMB.std(),
    "adm_mean_demand": 70,
    "adm_cr": 3 / 4.5,
    "adm_qstar": stats.uniform(40, 60).ppf(3 / 4.5),
    "adm_profit_q70": newsvendor(70),
    "adm_profit_q80": newsvendor(80),
    "eco_sd_wrong": 1.5,
    "eco_p_loss": N.cdf(0, 0.6, 0.15 * math.sqrt(10)),
    "eco_median": stats.lognorm(s=0.15 * math.sqrt(10), scale=math.exp(0.6)).median(),
    "eco_mean": stats.lognorm(s=0.15 * math.sqrt(10), scale=math.exp(0.6)).mean(),
    "eco_sd_log": 0.15 * math.sqrt(10),
    "con_rule3": 3 / 150,
    "con_p0_3pct": stats.binom(150, 0.03).pmf(0),
    "psi_p10": stats.binom(20, 0.25).sf(9),
    "psi_pass_500": 500 * stats.binom(20, 0.25).sf(9),
    "bio_p_half": N.cdf(math.log(0.5), 0.4, 0.2 * math.sqrt(20)),
    "bio_sd_log": 0.2 * math.sqrt(20),
    "bio_median_ratio": math.exp(0.4),
    "hum_p30": birthday(30),
    "hum_n50": n50,
    "hum_p23": birthday(23),
    "dev_sd_total": 100 * math.sqrt(12),
    "dev_sd_wrong": 1200,
    "dev_p_goal": N.sf(3500, 3600, 100 * math.sqrt(12)),
    "dev_p_goal_wrong": N.sf(3500, 3600, 1200),
    "dev_p10": N.ppf(0.10, 3600, 100 * math.sqrt(12)),
    "dev_p90": N.ppf(0.90, 3600, 100 * math.sqrt(12)),
}


def main():
    out = ROOT / "test" / "fixtures" / "figures.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    data = {k: float(v) for k, v in sorted(fig.items())}
    out.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(data)} cifras escritas en {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
