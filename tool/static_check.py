#!/usr/bin/env python3
"""Verificación estática sin SDK de Flutter.

Usa el parser real de Dart (tree-sitter) para:
  1. detectar errores de sintaxis en lib/ y test/;
  2. comprobar que cada import relativo o del paquete existe;
  3. comprobar que cada símbolo del proyecto usado en un archivo está
     importado en ese archivo (los imports de Dart no son transitivos);
  4. verificar los argumentos con nombre de cada llamada a constructor
     (propios y de Flutter/Riverpod/SDK si se indican sus fuentes), y que
     no falten los `required`;
  5. verificar miembros estáticos: Icons.x, AppColors.x, Curves.x, enums…

Uso:
  pip install tree-sitter tree-sitter-language-pack
  python3 tool/static_check.py [--ref DIR ...]

--ref apunta a carpetas con fuentes Dart de referencia (p. ej. un clon de
flutter/packages/flutter/lib). Sin --ref se verifican solo los símbolos
propios.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

from tree_sitter_language_pack import get_parser

ROOT = Path(__file__).resolve().parent.parent
PKG = "monte_carlo_simulator"
parser = get_parser("dart")


def text(src: bytes, n) -> str:
    return src[n.start_byte:n.end_byte].decode("utf-8", "replace")


def walk(n):
    yield n
    for c in n.children:
        yield from walk(c)


# ------------------------------------------------------------ índice de clases
class ClassInfo:
    def __init__(self, name):
        self.name = name
        self.ctors: dict[str, list[tuple[set, set, bool]]] = defaultdict(list)  # nombre → [(named, required, open)]
        self.statics: set[str] = set()
        self.has_explicit_ctor = False
        self.is_enum = False
        self.sources: set[str] = set()


classes: dict[str, ClassInfo] = {}


def param_sets(src, plist):
    """(named, required, open): parámetros con nombre, obligatorios y si
    hay algo que no se pudo entender (se vuelve permisivo)."""
    named, required = set(), set()
    open_ = False
    for ch in plist.children:
        if ch.type == "optional_formal_parameters":
            is_named = text(src, ch).lstrip().startswith("{")
            if not is_named:
                continue
            req_next = False
            for p in ch.children:
                if p.type == "required":
                    req_next = True
                    continue
                if p.type == "formal_parameter":
                    ids = [c for c in walk(p) if c.type == "identifier"]
                    # nombre = último identificador directo del parámetro
                    name = None
                    for c in p.children:
                        if c.type in ("constructor_param", "super_formal_parameter"):
                            idc = [x for x in c.children if x.type == "identifier"]
                            if idc:
                                name = text(src, idc[-1])
                        elif c.type == "identifier":
                            name = text(src, c)
                        elif c.type == "function_formal_parameter" or c.type == "function_type":
                            idc = [x for x in c.children if x.type == "identifier"]
                            if idc:
                                name = text(src, idc[-1])
                    if name is None and ids:
                        name = text(src, ids[-1])
                    if name:
                        named.add(name)
                        if req_next:
                            required.add(name)
                    req_next = False
    return named, required, open_


def index_file(path: Path, tag: str):
    try:
        src = path.read_bytes()
    except OSError:
        return
    tree = parser.parse(src)
    for n in walk(tree.root_node):
        if n.type in ("class_definition", "enum_declaration", "mixin_declaration", "extension_type_declaration"):
            idn = next((c for c in n.children if c.type == "identifier"), None)
            if idn is None:
                continue
            cname = text(src, idn)
            ci = classes.setdefault(cname, ClassInfo(cname))
            ci.sources.add(tag)
            if n.type == "enum_declaration":
                ci.is_enum = True
                ci.statics.update({"values"})
            body = next((c for c in n.children if c.type in ("class_body", "enum_body", "extension_type_body")), None)
            if body is None:
                continue
            for m in body.children:
                if m.type == "enum_constant":
                    idc = next((c for c in m.children if c.type == "identifier"), None)
                    if idc is not None:
                        ci.statics.add(text(src, idc))
            for m in walk(body):
                if m.type in ("constant_constructor_signature", "constructor_signature", "factory_constructor_signature", "redirecting_factory_constructor_signature"):
                    ids = [c for c in m.children if c.type == "identifier"]
                    if not ids or text(src, ids[0]) != cname:
                        continue
                    cn = text(src, ids[1]) if len(ids) > 1 else ""
                    plist = next((c for c in m.children if c.type == "formal_parameter_list"), None)
                    ci.has_explicit_ctor = True
                    if plist is None:
                        ci.ctors[cn].append((set(), set(), True))
                    else:
                        ci.ctors[cn].append(param_sets(src, plist))
                    if cn:
                        ci.statics.add(cn)
            # miembros estáticos (campos, getters, métodos)
            for d in body.children:
                t = text(src, d)
                if d.type in ("declaration", "method_signature") and re.match(r"\s*(@\w+(\([^)]*\))?\s*)*static\b", t):
                    for c in walk(d):
                        if c.type in ("identifier",):
                            pass
                    m = re.match(r"\s*(?:@\w+(?:\([^)]*\))?\s*)*static\s+(?:const\s+|final\s+|late\s+)*(?:[\w<>?,\s\[\]().]+?\s+)?(?:get\s+)?(\w+)\s*(?:[=;(<]|$)", t)
                    if m:
                        ci.statics.add(m.group(1))
                    # listas: static const a = 1, b = 2;
                    for mm in re.finditer(r",\s*(\w+)\s*=", t):
                        ci.statics.add(mm.group(1))


# ------------------------------------------------------------ proyecto
def project_files():
    out = []
    for base in ("lib", "test"):
        for p in sorted((ROOT / base).rglob("*.dart")):
            out.append(p)
    return out


TOP_DECL = ("class_definition", "enum_declaration", "mixin_declaration", "extension_declaration", "type_alias")


def top_level_names(path: Path):
    src = path.read_bytes()
    tree = parser.parse(src)
    names = set()
    for n in tree.root_node.children:
        if n.type in TOP_DECL:
            idn = next((c for c in n.children if c.type in ("identifier", "type_identifier")), None)
            if idn is not None:
                names.add(text(src, idn))
        elif n.type == "function_signature":
            idn = next((c for c in n.children if c.type == "identifier"), None)
            if idn is not None:
                names.add(text(src, idn))
        elif n.type == "getter_signature":
            idn = next((c for c in n.children if c.type == "identifier"), None)
            if idn is not None:
                names.add(text(src, idn))
        elif n.type in ("static_final_declaration_list", "initialized_identifier_list", "top_level_variable_declaration", "declaration") or n.type.endswith("variable_declaration"):
            for c in walk(n):
                if c.type in ("initialized_identifier", "static_final_declaration"):
                    idn = next((x for x in c.children if x.type == "identifier"), None)
                    if idn is not None:
                        names.add(text(src, idn))
    return names


def imports_of(path: Path):
    src = path.read_text(encoding="utf-8")
    return re.findall(r"^\s*(?:import|export)\s+'([^']+)'", src, re.M)


def resolve_import(path: Path, uri: str):
    if uri.startswith("dart:"):
        return "dart"
    if uri.startswith("package:"):
        if uri.startswith(f"package:{PKG}/"):
            return ROOT / "lib" / uri[len(f"package:{PKG}/"):]
        return "external"
    return (path.parent / uri).resolve()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", action="append", default=[], help="carpeta con fuentes Dart de referencia")
    args = ap.parse_args()

    problems = []
    files = project_files()

    # 1 · sintaxis
    for f in files:
        src = f.read_bytes()
        tree = parser.parse(src)
        for n in walk(tree.root_node):
            if n.type == "ERROR" or n.is_missing:
                ln = n.start_point[0] + 1
                problems.append(f"{f.relative_to(ROOT)}:{ln}: error de sintaxis cerca de «{text(src, n)[:40]}»")
                break

    # 2 · imports
    for f in files:
        for uri in imports_of(f):
            r = resolve_import(f, uri)
            if isinstance(r, Path) and not r.exists():
                problems.append(f"{f.relative_to(ROOT)}: import inexistente {uri}")

    # índice de referencia y del proyecto
    for ref in args.ref:
        for p in Path(ref).rglob("*.dart"):
            index_file(p, "ref")
    for f in files:
        index_file(f, "proj")

    # 3 · símbolos del proyecto importados
    defs: dict[str, set[Path]] = defaultdict(set)
    for f in (ROOT / "lib").rglob("*.dart"):
        for nm in top_level_names(f):
            defs[nm].add(f.resolve())
    exports: dict[Path, set[Path]] = {}

    def visible(f: Path):
        vis = {f.resolve()}
        for uri in imports_of(f):
            r = resolve_import(f, uri)
            if isinstance(r, Path):
                vis.add(r.resolve())
        return vis

    for f in files:
        src = f.read_bytes()
        tree = parser.parse(src)
        vis = visible(f)
        local_names = set()
        for n in walk(tree.root_node):
            # nombres declarados localmente (parámetros, variables, patrones)
            if n.type in ("initialized_identifier", "initialized_variable_definition", "formal_parameter", "for_loop_parts", "pattern_variable_declaration", "variable_pattern", "getter_signature", "setter_signature", "method_signature", "function_signature", "constructor_param"):
                for c in n.children:
                    if c.type == "identifier":
                        local_names.add(text(src, c))
        seen = set()
        for n in walk(tree.root_node):
            if n.type not in ("identifier", "type_identifier"):
                continue
            nm = text(src, n)
            if nm in seen or nm not in defs or nm.startswith("_"):
                continue
            prev = n.prev_sibling
            par = n.parent
            if prev is not None and prev.type == ".":
                continue
            if par is not None and par.type in ("unconditional_assignable_selector", "conditional_assignable_selector", "label", "cascade_selector"):
                continue
            if par is not None and par.type in TOP_DECL + ("function_signature", "getter_signature", "setter_signature", "method_signature", "constructor_signature", "constant_constructor_signature", "factory_constructor_signature", "initialized_identifier", "enum_constant"):
                continue
            if nm in local_names and nm[0].islower():
                continue
            seen.add(nm)
            if not (defs[nm] & vis):
                problems.append(f"{f.relative_to(ROOT)}:{n.start_point[0] + 1}: «{nm}» se usa sin importar {', '.join(sorted(str(p.relative_to(ROOT)) for p in defs[nm]))}")

    # 4 · argumentos con nombre y 5 · miembros estáticos
    for f in files:
        src = f.read_bytes()
        tree = parser.parse(src)
        for n in walk(tree.root_node):
            callee = None
            ctor = ""
            args_node = None
            if n.type == "const_object_expression" or n.type == "new_expression":
                tid = next((c for c in n.children if c.type == "type_identifier"), None)
                if tid is None:
                    continue
                callee = text(src, tid)
                ids = [c for c in n.children if c.type == "identifier"]
                if ids:
                    ctor = text(src, ids[0])
                args_node = next((c for c in n.children if c.type == "arguments"), None)
            elif n.type == "identifier" and text(src, n)[:1].isupper():
                nxt = n.next_sibling
                name = text(src, n)
                if nxt is not None and nxt.type == "selector":
                    sub = nxt.children[0] if nxt.children else None
                    if sub is not None and sub.type == "unconditional_assignable_selector":
                        mem = next((c for c in sub.children if c.type == "identifier"), None)
                        member = text(src, mem) if mem is not None else ""
                        ci = classes.get(name)
                        if ci is not None and member and ci.statics and member not in ci.statics and not member.startswith("_"):
                            if name in ("Icons", "AppColors", "Curves", "Colors", "FontWeight") or ci.is_enum:
                                problems.append(f"{f.relative_to(ROOT)}:{n.start_point[0] + 1}: {name}.{member} no existe")
                        after = nxt.next_sibling
                        if after is not None and after.type == "selector" and after.children and after.children[0].type == "argument_part":
                            callee, ctor = name, member
                            args_node = next((c for c in after.children[0].children if c.type == "arguments"), None)
                    elif sub is not None and sub.type == "argument_part":
                        callee = name
                        args_node = next((c for c in sub.children if c.type == "arguments"), None)
            if callee is None or args_node is None:
                continue
            ci = classes.get(callee)
            if ci is None or not ci.has_explicit_ctor or ctor not in ci.ctors:
                continue
            given = set()
            for a in args_node.children:
                if a.type == "named_argument":
                    lab = next((c for c in a.children if c.type == "label"), None)
                    if lab is not None:
                        idc = next((c for c in lab.children if c.type == "identifier"), None)
                        if idc is not None:
                            given.add(text(src, idc))
            variants = ci.ctors[ctor]
            if any(o for (_, _, o) in variants):
                continue
            ok = any(given <= named for (named, _, _) in variants)
            if not ok:
                allowed = set().union(*[v[0] for v in variants])
                bad = sorted(given - allowed)
                problems.append(f"{f.relative_to(ROOT)}:{n.start_point[0] + 1}: {callee}{'.' + ctor if ctor else ''}() no acepta {', '.join(bad)}")
                continue
            miss_all = [req - given for (named, req, _) in variants if given <= named]
            if miss_all and all(m for m in miss_all):
                problems.append(f"{f.relative_to(ROOT)}:{n.start_point[0] + 1}: {callee}{'.' + ctor if ctor else ''}() sin argumentos requeridos: {', '.join(sorted(min(miss_all, key=len)))}")

    print(f"Archivos Dart analizados: {len(files)}; clases indexadas: {len(classes)}")
    if problems:
        print(f"\n{len(problems)} problema(s):")
        for p in problems:
            print("  -", p)
        sys.exit(1)
    print("Sin problemas.")


if __name__ == "__main__":
    main()
