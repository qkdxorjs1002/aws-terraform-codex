#!/usr/bin/env python3
"""
Summarize Terraform Graphviz DOT into resource initialization order.

Input:
- Graphviz DOT content from `terraform graph`

Output:
- Ordered CLI-friendly steps such as:
  1. vpc['main']
  2-1. subnet['private-a']
  2-2. subnet['private-b']
"""

from __future__ import annotations

import argparse
import heapq
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from graphviz_to_d2 import parse_dot

ROOT_PREFIX = "[root] "
RESOURCE_RE = re.compile(
    r"^(?P<modules>(?:module\.[^.]+\.)*)(?P<rtype>[a-zA-Z0-9_]+)\.(?P<name>[a-zA-Z0-9_]+)(?P<index>\[[^\]]+\])?$"
)
NON_RESOURCE_PREFIXES = (
    "provider[",
    "var.",
    "local.",
    "output.",
    "path.",
    "terraform.",
    "meta.",
    "count.",
    "each.",
)


def clean_node(raw: str) -> str:
    text = raw.strip()
    if text.startswith(ROOT_PREFIX):
        return text[len(ROOT_PREFIX) :].strip()
    return text


def parse_index(index_text: str | None, fallback_name: str) -> str:
    if not index_text:
        return fallback_name
    value = index_text[1:-1].strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    return value.replace("\\\"", '"').replace("\\\\", "\\")


def is_managed_resource(address: str) -> bool:
    if any(address.startswith(prefix) for prefix in NON_RESOURCE_PREFIXES):
        return False

    matched = RESOURCE_RE.match(address)
    if not matched:
        return False

    rtype = matched.group("rtype")
    # Most Terraform managed resource types include provider prefix, e.g. aws_vpc.
    return "_" in rtype


def display_name(address: str) -> str:
    matched = RESOURCE_RE.match(address)
    if not matched:
        return address

    rtype = matched.group("rtype")
    resource_kind = rtype.split("_", 1)[1] if "_" in rtype else rtype
    key = parse_index(matched.group("index"), matched.group("name"))
    return f"{resource_kind}['{key}']"


def compute_levels(all_nodes: list[str], edges: list[tuple[str, str]]) -> dict[str, int]:
    # terraform graph edge means: source depends on target
    # We reverse it to model init order: target -> source
    outgoing: dict[str, set[str]] = defaultdict(set)
    indegree: dict[str, int] = {node: 0 for node in all_nodes}
    level: dict[str, int] = {node: 0 for node in all_nodes}

    for source, target in edges:
        dependency = target
        dependent = source
        if dependent not in indegree:
            indegree[dependent] = 0
            level[dependent] = 0
        if dependency not in indegree:
            indegree[dependency] = 0
            level[dependency] = 0

        if dependent in outgoing[dependency]:
            continue

        outgoing[dependency].add(dependent)
        indegree[dependent] += 1

    heap: list[str] = [node for node, degree in indegree.items() if degree == 0]
    heapq.heapify(heap)

    visited: set[str] = set()

    while heap:
        node = heapq.heappop(heap)
        visited.add(node)

        for child in sorted(outgoing.get(node, [])):
            level[child] = max(level[child], level[node] + 1)
            indegree[child] -= 1
            if indegree[child] == 0:
                heapq.heappush(heap, child)

    if len(visited) != len(indegree):
        max_level = max(level.values(), default=0)
        for node in sorted(indegree.keys()):
            if node in visited:
                continue
            max_level += 1
            level[node] = max_level

    return level


def render_order(dot_text: str, include_address: bool) -> str:
    nodes, parsed_edges = parse_dot(dot_text)

    all_nodes = [clean_node(node) for node in nodes.keys()]
    all_edges = [(clean_node(edge.source), clean_node(edge.target)) for edge in parsed_edges]
    levels = compute_levels(all_nodes, all_edges)

    resources = [node for node in all_nodes if is_managed_resource(node)]
    if not resources:
        return "No managed resources found in graph.\n"

    base_names = {node: display_name(node) for node in resources}
    collisions = Counter(base_names.values())

    grouped_by_level: dict[int, list[str]] = defaultdict(list)
    for node in resources:
        shown = base_names[node]
        if collisions[shown] > 1:
            shown = f"{shown} [{node}]"
        elif include_address:
            shown = f"{shown} [{node}]"
        grouped_by_level[levels.get(node, 0)].append(shown)

    resource_levels = sorted(level for level, items in grouped_by_level.items() if items)

    lines: list[str] = []
    for stage_index, level in enumerate(resource_levels, start=1):
        stage_items = sorted(grouped_by_level[level])
        if len(stage_items) == 1:
            lines.append(f"{stage_index}. {stage_items[0]}")
            continue
        for item_index, item in enumerate(stage_items, start=1):
            lines.append(f"{stage_index}-{item_index}. {item}")

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
        description="Summarize Terraform Graphviz DOT as resource initialization order.",
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
        help="Output text file path. Use '-' for stdout (default).",
    )
    parser.add_argument(
        "--include-address",
        action="store_true",
        help="Append original Terraform address to each line.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    dot_text = load_text(args.input)
    result = render_order(dot_text, include_address=args.include_address)
    save_text(args.output, result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
