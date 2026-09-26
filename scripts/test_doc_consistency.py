#!/usr/bin/env python3
"""現行運用文書だけを対象にしたOpenSpec整合性検査。"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        ERRORS.append(message)


def section(markdown: str, heading: str) -> str:
    start = markdown.find(heading)
    if start < 0:
        return ""
    next_heading = markdown.find("\n## ", start + len(heading))
    return markdown[start:] if next_heading < 0 else markdown[start:next_heading]


def first_bash_block(markdown: str) -> str:
    match = re.search(r"```bash\n(.*?)\n```", markdown, re.DOTALL)
    return "" if match is None else match.group(1)


def parse_r_registry(text: str) -> list[str]:
    match = re.search(r"official_tests\s*<-\s*c\((.*?)\n\)", text, re.DOTALL)
    if match is None:
        ERRORS.append("tests/run_regression_suite.R に official_tests がありません")
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def main() -> int:
    categorical_skill = read(".agents/skills/vcd-categorical-analysis/SKILL.md")
    canonical = section(categorical_skill, "## 3. R エンジンの実行方法")
    require(bool(canonical), "2次元SKILLのcanonical実行節がありません")
    canonical_example = first_bash_block(canonical)
    require(bool(canonical_example), "canonical実行節にbash実行例がありません")
    for forbidden in ("--data", "--vars", "--freq", "--render", "--profile"):
        require(forbidden not in canonical_example, f"canonical実行例に旧CLI引数が残っています: {forbidden}")
    require("--config" in canonical_example, "canonical実行例に --config がありません")

    pass0_skill = read(".agents/skills/vcd-pass0-consultation/SKILL.md")
    require("dirichlet_prior" in pass0_skill, "Pass 0設定例に dirichlet_prior がありません")
    require("primary_alpha" in pass0_skill and "sensitivity_alpha" in pass0_skill, "Pass 0設定例の主・感度αが不完全です")
    require("\"dirichlet_a\"" not in pass0_skill, "Pass 0設定例に旧 dirichlet_a が残っています")

    dependency_spec = read("openspec/specs/deterministic-r-dependencies/spec.md")
    require("run_regression_suite.R" in dependency_spec, "現行依存関係SpecがR registryを参照していません")

    registry = parse_r_registry(read("tests/run_regression_suite.R"))
    require(bool(registry), "R registryが空です")
    for relative in registry:
        require((ROOT / relative).is_file(), f"R registryのテストが存在しません: {relative}")

    responsibilities = read("docs/reference/skill_responsibilities.md")
    require("2次元では$N \\ge 2,000$" in responsibilities, "責務解説に2次元N閾値がありません")
    require("3次元の現行候補条件" in responsibilities and "Nカットオフを含めない" in responsibilities,
            "責務解説に3次元Nカットオフなしの境界がありません")

    if ERRORS:
        print("文書一貫性検査: FAIL", file=sys.stderr)
        for error in ERRORS:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"文書一貫性検査: PASS（R registry {len(registry)}件）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
