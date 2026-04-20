#!/usr/bin/env python3
"""
Convert a Graphviz DOT graph into D2 language.

This converter focuses on Terraform `terraform graph` output:
- node declarations
- directed edges
- optional `label` attributes
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    label: str | None = None


def split_outside_quotes(text: str, separator: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    i = 0
    in_quote = False
    escaped = False

    while i < len(text):
        ch = text[i]

        if in_quote:
            current.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_quote = False
            i += 1
            continue

        if ch == '"':
            in_quote = True
            current.append(ch)
            i += 1
            continue

        if text.startswith(separator, i):
            parts.append("".join(current).strip())
            current = []
            i += len(separator)
            continue

        current.append(ch)
        i += 1

    parts.append("".join(current).strip())
    return [p for p in parts if p]


def extract_trailing_attrs(statement: str) -> tuple[str, str | None]:
    text = statement.strip().rstrip(";").strip()
    if "[" not in text or "]" not in text:
        return text, None

    in_quote = False
    escaped = False
    depth = 0
    start = -1
    end = -1

    for i, ch in enumerate(text):
        if in_quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_quote = False
            continue

        if ch == '"':
            in_quote = True
            continue

        if ch == "[":
            if depth == 0 and start == -1:
                start = i
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                end = i

    if start == -1 or end == -1:
        return text, None

    if text[end + 1 :].strip():
        return text, None

    main = text[:start].strip()
    attrs = text[start + 1 : end].strip()
    return main, attrs


def parse_attrs(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}

    items = split_outside_quotes(raw, ",")
    parsed: dict[str, str] = {}

    for item in items:
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        key = key.strip()
        value = value.strip()
        parsed[key] = unquote(value)

    return parsed


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    value = value.replace('\\"', '"').replace("\\\\", "\\")
    value = value.replace("\\n", "\n")
    return value


def normalize_identifier(raw: str) -> str:
    return unquote(raw.strip())


def parse_dot(dot_text: str) -> tuple[OrderedDict[str, dict[str, str]], list[Edge]]:
    nodes: OrderedDict[str, dict[str, str]] = OrderedDict()
    edges: list[Edge] = []

    for original_line in dot_text.splitlines():
        line = original_line.strip()
        if not line:
            continue
        if line.startswith("//") or line.startswith("#"):
            continue
        if line in {"{", "}"}:
            continue
        if line.startswith(("digraph", "graph", "subgraph")):
            continue

        statement = line.rstrip(";").strip()
        if not statement:
            continue

        main, raw_attrs = extract_trailing_attrs(statement)
        attrs = parse_attrs(raw_attrs)

        if "->" in main:
            parts = split_outside_quotes(main, "->")
            if len(parts) < 2:
                continue

            for src, dst in zip(parts, parts[1:]):
                src_id = normalize_identifier(src)
                dst_id = normalize_identifier(dst)
                nodes.setdefault(src_id, {})
                nodes.setdefault(dst_id, {})
                edges.append(Edge(source=src_id, target=dst_id, label=attrs.get("label")))
            continue

        if "=" in main:
            # Graph-level attributes such as `compound = "true"`
            continue

        node_key = normalize_identifier(main)
        if node_key in {"node", "edge"}:
            # Default node/edge style blocks.
            continue

        nodes.setdefault(node_key, {}).update(attrs)

    return nodes, edges


def to_d2(nodes: OrderedDict[str, dict[str, str]], edges: list[Edge]) -> str:
    id_map: OrderedDict[str, str] = OrderedDict()
    for idx, original in enumerate(nodes.keys(), start=1):
        id_map[original] = f"n{idx}"

    lines: list[str] = []
    lines.append("# Generated from Graphviz DOT by scripts/graphviz_to_d2.py")
    lines.append("direction: right")
    lines.append("")

    for original, attrs in nodes.items():
        node_id = id_map[original]
        label = attrs.get("label") or original
        lines.append(f'{node_id}: {json.dumps(label)}')

    if edges:
        lines.append("")

    for edge in edges:
        src = id_map[edge.source]
        dst = id_map[edge.target]
        if edge.label:
            lines.append(f"{src} -> {dst}: {json.dumps(edge.label)}")
        else:
            lines.append(f"{src} -> {dst}")

    lines.append("")
    return "\n".join(lines)


def load_text(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def save_text(path: str, content: str) -> None:
    if path == "-":
        sys.stdout.write(content)
        return
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(content, encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert Graphviz DOT to D2 language format.",
    )
    parser.add_argument(
        "-i",
        "--input",
        default="-",
        help="Input DOT file path. Use '-' for stdin (default).",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="-",
        help="Output D2 file path. Use '-' for stdout (default).",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    dot_text = load_text(args.input)
    nodes, edges = parse_dot(dot_text)
    d2_text = to_d2(nodes, edges)
    save_text(args.output, d2_text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
