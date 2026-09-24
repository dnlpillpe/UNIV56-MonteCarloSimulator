#!/usr/bin/env python3
"""Verifica la integridad del contenido educativo (sin Flutter).

Comprueba:
  - toda marca {{id}} y toda cifra citada existe en el registro de cifras;
  - toda confusión citada existe, y toda confusión del catálogo la produce
    al menos un distractor, patrón numérico o predicción (sin contenido muerto);
  - referencias a lecciones, laboratorios y experimentos;
  - identificadores únicos;
  - opción múltiple y decisiones con exactamente una alternativa correcta;
  - cada error numérico típico se distingue de la respuesta correcta;
  - cada marca [[clave]] de un hallazgo la produce la lógica del experimento;
  - las cifras de test/fixtures/figures.json cubren todo el registro.

Uso: pip install tree-sitter tree-sitter-language-pack && python3 tool/verify_content.py
"""
import json
import re
import sys
from pathlib import Path

from tree_sitter_language_pack import get_parser

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
CONTENT = LIB / "domain" / "content"
parser = get_parser("dart")
problems = []


def t(src, n):
    return src[n.start_byte:n.end_byte].decode("utf-8")


def walk(n):
    yield n
    for c in n.children:
        yield from walk(c)


def calls(path: Path, name: str):
    """Llamadas `Name(...)` o `const Name(...)` con sus argumentos con nombre."""
    src = path.read_bytes()
    tree = parser.parse(src)
    out = []
    for n in walk(tree.root_node):
        args = None
        if n.type == "const_object_expression":
            tid = next((c for c in n.children if c.type == "type_identifier"), None)
            if tid is not None and t(src, tid) == name:
                args = next((c for c in n.children if c.type == "arguments"), None)
        elif n.type == "identifier" and t(src, n) == name:
            nx = n.next_sibling
            if nx is not None and nx.type == "selector" and nx.children and nx.children[0].type == "argument_part":
                args = next((c for c in nx.children[0].children if c.type == "arguments"), None)
        if args is None:
            continue
        named, pos = {}, []
        for a in args.children:
            if a.type == "named_argument":
                lab = next(c for c in a.children if c.type == "label")
                key = t(src, lab).rstrip(":").strip()
                val = a.children[-1]
                named[key] = (t(src, val), val)
            elif a.type == "argument":
                pos.append(t(src, a))
        out.append((named, pos, n.start_point[0] + 1, src))
    return out


def strlit(s: str):
    m = re.match(r"^'(.*)'$", s.strip(), re.S)
    return m.group(1) if m else None


def list_items(src, node):
    return [c for c in node.children if c.type not in ("[", "]", ",", "const_builtin")]


# ------------------------------------------------------------- registros
fig_src = (CONTENT / "figures.dart").read_text(encoding="utf-8")
figure_ids = re.findall(r"Figure\('([a-z0-9_]+)'", fig_src)
fig_set = set(figure_ids)
if len(fig_set) != len(figure_ids):
    problems.append("figures.dart: hay cifras duplicadas")
fixtures = json.loads((ROOT / "test" / "fixtures" / "figures.json").read_text(encoding="utf-8"))
for f in figure_ids:
    if f not in fixtures:
        problems.append(f"figures.json no contiene la cifra {f} (ejecuta tool/replica.py)")

conf_ids = re.findall(r"id: '([a-z_0-9]+)'", (CONTENT / "confusions.dart").read_text(encoding="utf-8"))
conf_set = set(conf_ids)
lesson_ids = set(re.findall(r"id: '(l\d_\d)'", (CONTENT / "lessons.dart").read_text(encoding="utf-8")))
labs_src = (CONTENT / "labs.dart").read_text(encoding="utf-8")
lab_ids = set(re.findall(r"id: '(lab_[a-z]+)'", labs_src))
exp_ids = re.findall(r"id: '(e\d+_[a-z0-9_]+)'", labs_src)
exp_set = set(exp_ids)

# ------------------------------------------------------------- 1 · cifras
all_text = ""
for p in LIB.rglob("*.dart"):
    s = p.read_text(encoding="utf-8")
    all_text += s
    for m in re.finditer(r"\{\{([a-z0-9_]+)\}\}", s):
        if m.group(1) not in fig_set and m.group(1) != "id":
            problems.append(f"{p.relative_to(ROOT)}: cifra desconocida {{{{{m.group(1)}}}}}")
    for m in re.finditer(r"(?:answerFigure|figure): '([a-z0-9_]+)'", s):
        if m.group(1) not in fig_set:
            problems.append(f"{p.relative_to(ROOT)}: cifra desconocida {m.group(1)}")
    for m in re.finditer(r"figureValue\('([a-z0-9_]+)'\)|figures\['([a-z0-9_]+)'\]", s):
        k = m.group(1) or m.group(2)
        if k not in fig_set:
            problems.append(f"{p.relative_to(ROOT)}: cifra desconocida {k}")

# ------------------------------------------------------------- 2 · confusiones
content_text = "".join(p.read_text(encoding="utf-8") for p in CONTENT.glob("*.dart"))
produced = set(re.findall(r"confusion: '([a-z_0-9]+)'", content_text))
produced.add("acertar_sin_entender")  # también la produce gradeDecision
for c in set(re.findall(r"confusion: '([a-z_0-9]+)'", content_text)) | set(
    x for grp in re.findall(r"(?:targets|remedyFor): \[([^\]]*)\]", content_text) for x in re.findall(r"'([a-z_0-9]+)'", grp)
):
    if c not in conf_set:
        problems.append(f"confusión desconocida: {c}")
for c in conf_set - produced:
    problems.append(f"confusión «{c}» no la produce ningún distractor (contenido muerto)")
if len(conf_ids) != len(conf_set):
    problems.append("confusions.dart: ids duplicados")

# ------------------------------------------------------------- 3 · referencias
for m in re.finditer(r"(?:remedyLessonId|lessonId): '([a-z0-9_]+)'", all_text):
    if m.group(1) not in lesson_ids:
        problems.append(f"lección desconocida: {m.group(1)}")
for m in re.finditer(r"remedyExperimentId: '([a-z0-9_]+)'", all_text):
    if m.group(1) not in exp_set:
        problems.append(f"experimento desconocido: {m.group(1)}")
for m in re.finditer(r"labId: '([a-z_]+)'", all_text):
    if m.group(1) not in lab_ids:
        problems.append(f"laboratorio desconocido: {m.group(1)}")
for grp in re.findall(r"experimentIds: \[([^\]]*)\]", labs_src):
    for e in re.findall(r"'([a-z0-9_]+)'", grp):
        if e not in exp_set:
            problems.append(f"laboratorio cita experimento inexistente {e}")
in_labs = set(x for grp in re.findall(r"experimentIds: \[([^\]]*)\]", labs_src) for x in re.findall(r"'([a-z0-9_]+)'", grp))
for e in exp_set - in_labs:
    problems.append(f"experimento {e} no pertenece a ningún laboratorio")
if len(exp_ids) != len(exp_set):
    problems.append("experimentos con id duplicado")
logic_src = (LIB / "domain" / "labs" / "experiment_logic.dart").read_text(encoding="utf-8")
for e in exp_set:
    if f"'{e}' =>" not in logic_src:
        problems.append(f"experimento {e} sin lógica en ExperimentLogic.create")

# ------------------------------------------------------------- 4 · ítems
ex_ids = []
n_items = 0
for path in (CONTENT / "exercises.dart", CONTENT / "cases.dart"):
    for named, _, line, src in calls(path, "Exercise"):
        n_items += 1
        eid = strlit(named.get("id", ("", None))[0])
        ex_ids.append(eid)
        typ = named.get("type", ("", None))[0]
        where = f"{path.name}:{line} ({eid})"

        def count_correct(key):
            if key not in named:
                return None
            return len(re.findall(r"correct: true", named[key][0]))

        if typ.endswith("choice"):
            if count_correct("options") != 1:
                problems.append(f"{where}: opción múltiple con {count_correct('options')} correctas")
        elif typ.endswith("decision"):
            if count_correct("options") != 1 or count_correct("justifications") != 1:
                problems.append(f"{where}: decisión sin exactamente una decisión y una justificación correctas")
        elif typ.endswith("numeric"):
            af = strlit(named.get("answerFigure", ("''", None))[0])
            if not af:
                problems.append(f"{where}: numérico sin answerFigure")
                continue
            tol_txt = named.get("relTolerance", ("0.02", None))[0]
            tol = float(tol_txt)
            ans = fixtures.get(af)
            for w in re.findall(r"figure: '([a-z0-9_]+)'", named.get("wrongPatterns", ("", None))[0]):
                v = fixtures.get(w)
                if ans is None or v is None:
                    continue
                if abs(v - ans) <= max(tol, 0.01) * max(abs(ans), 1e-12) or (ans == 0 and v == 0):
                    problems.append(f"{where}: el error típico {w} ({v}) no se distingue de la respuesta ({ans})")
        elif typ.endswith("ordering"):
            steps = re.findall(r"'([^']+)'", named.get("steps", ("", None))[0])
            if len(steps) < 3 or len(set(steps)) != len(steps):
                problems.append(f"{where}: pasos de ordenamiento insuficientes o repetidos")
dups = {x for x in ex_ids if ex_ids.count(x) > 1}
if dups:
    problems.append(f"ejercicios con id duplicado: {sorted(dups)}")

# ------------------------------------------------------------- 5 · hallazgos
exp_blocks = re.split(r"\n  ExperimentDef\(", labs_src)[1:]
class_for = dict(re.findall(r"'(e\d+_[a-z0-9_]+)' => (\w+)\(\)", logic_src))
for blk in exp_blocks:
    eid = re.search(r"id: '([a-z0-9_]+)'", blk).group(1)
    fm = re.search(r"finding:((?:\s*'(?:[^'\\]|\\.)*')+)", blk)
    keys = set(re.findall(r"\[\[([a-z0-9_]+)\]\]", fm.group(1) if fm else ""))
    cls = class_for.get(eid)
    m = re.search(rf"class {cls} extends[\s\S]*?(?=\nclass |\n// -----|\Z)", logic_src)
    body = m.group(0) if m else ""
    obs = set(re.findall(r"'([a-z0-9_]+)': ", body))
    if "'sd_$l'" in body:
        obs |= {f"sd_{l}" for l in (100, 400, 1600, 6400)}
    for k in keys - obs:
        problems.append(f"hallazgo de {eid}: [[{k}]] no lo produce {cls}.observations")

print(f"Cifras: {len(figure_ids)} · confusiones: {len(conf_set)} · lecciones: {len(lesson_ids)} · "
      f"laboratorios: {len(lab_ids)} · experimentos: {len(exp_set)} · ítems evaluados: {n_items}")
if problems:
    print(f"\n{len(problems)} problema(s):")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("Contenido íntegro.")
