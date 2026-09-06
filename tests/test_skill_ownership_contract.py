import inspect
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / ".agents" / "skills"
EXPECTED_SKILLS = {
    "questionnaire-batch-analysis",
    "vcd-bayesian-evidence-analysis",
    "vcd-categorical-analysis",
    "vcd-categorical-reporting",
    "vcd-pass0-consultation",
}
FORBIDDEN_OWNERSHIP_PHRASES = {
    "サテライト",
    "ここでは統合DB構築・Query作成支援",
}


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def frontmatter_description(skill_file: Path) -> str:
    text = skill_file.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(?P<frontmatter>.*?)\n---\n", text, re.DOTALL)
    assert match is not None, f"frontmatter not found: {skill_file}"

    description = re.search(
        r"^description:\s*[\"']?(?P<value>.*?)[\"']?\s*$",
        match.group("frontmatter"),
        re.MULTILINE,
    )
    assert description is not None, f"description not found: {skill_file}"
    return description.group("value")


def test_repository_guides_define_canonical_ownership_without_legacy_wording():
    for guide_path in ("README.md", "AGENTS.md"):
        text = read(guide_path)

        assert "agentic-evidence-analysis" in text
        assert "同名5スキル" in text
        assert "統計schema" in text
        assert "統計品質契約" in text
        assert "Rテンプレート" in text
        assert "統計回帰テスト" in text
        assert "Productivity-Skill" in text
        assert "一般コード・SQLコード理解" in text
        assert "rwd-mysql-skill-toolkit" in text
        assert "RWD/DB実行・統合ハブ" in text

        for phrase in FORBIDDEN_OWNERSHIP_PHRASES:
            assert phrase not in text


def test_exactly_five_canonical_skills_use_discovery_focused_descriptions():
    canonical_skill_dirs = sorted(
        path for path in SKILL_ROOT.iterdir()
        if path.is_dir() and path.name in EXPECTED_SKILLS
    )
    skill_slugs = {path.name for path in canonical_skill_dirs}
    skill_files = [path / "SKILL.md" for path in canonical_skill_dirs]

    assert skill_slugs == EXPECTED_SKILLS
    assert len(canonical_skill_dirs) == 5

    for skill_file in skill_files:
        assert skill_file.is_file(), f"Missing SKILL.md in {skill_file}"
        assert frontmatter_description(skill_file).startswith("Use when")


def test_installation_uses_agentic_canonical_repository():
    install_command = "npx skills add syrius2000/agentic-evidence-analysis"

    assert install_command in read("README.md")


def test_categorical_run_layout_documentation_matches_canonical_runtime():
    layout_contract = "<out>/run_<first16>[_N]/"

    for path in (
        "README.md",
        "AGENTS.md",
        ".agents/skills/vcd-categorical-analysis/SKILL.md",
        ".agents/skills/vcd-categorical-analysis/references/interface.md",
        ".agents/skills/vcd-categorical-reporting/SKILL.md",
    ):
        assert layout_contract in read(path)


def test_categorical_canonical_docs_forbid_legacy_runs_layout():
    categorical_docs = [
        SKILL_ROOT / "vcd-bayesian-evidence-analysis" / "SKILL.md",
        *sorted((SKILL_ROOT / "vcd-categorical-analysis").rglob("*.md")),
        *sorted((SKILL_ROOT / "vcd-categorical-reporting").rglob("*.md")),
    ]

    for path in categorical_docs:
        assert "runs/<id>" not in path.read_text(encoding="utf-8"), path


def test_pass0_examples_require_run_scoped_output_directory():
    out_dir_contract = "--out-dir output/<project>/run_<id>/"

    for path in (
        "README.md",
        ".agents/skills/vcd-pass0-consultation/SKILL.md",
    ):
        text = read(path)
        assert ".agents/shared/inspect_data.R" in text
        assert out_dir_contract in text
        assert "空のout-dir" in text


def test_questionnaire_output_slug_schema_documents_path_safety():
    for path in (
        ".agents/skills/questionnaire-batch-analysis/SKILL.md",
        ".agents/skills/questionnaire-batch-analysis/references/config-schema.md",
    ):
        text = read(path)

        for contract in (
            "安全な単一slug成分",
            "1〜100文字",
            "ASCII",
            "先頭は英数字",
            "`[A-Za-z0-9._-]`",
            "末尾の `.`",
            "パス区切り",
            "case-insensitive",
            "CON",
            "COM1",
            "COM9",
            "LPT1",
            "LPT9",
            "拡張子付き",
            "CSV文字列をそのまま保持",
            "先頭ゼロを維持",
            "`output_slug` 以外",
            "`NA` は欠損",
            "`output_slug` の `NA` は文字列",
        ):
            assert contract in text


def test_categorical_resume_identity_is_documented():
    for path in (
        ".agents/skills/vcd-categorical-analysis/SKILL.md",
        ".agents/skills/vcd-categorical-analysis/references/interface.md",
    ):
        text = read(path)
        for contract in (
            "requested_run_id",
            "analysis_signature",
            "run_state",
            "`allocated`",
            "`profile_complete`",
            "`render_in_progress`",
            "`render_complete`",
            "atomic reservation",
            "存在しない `--data`",
        ):
            assert contract in text


if __name__ == "__main__":
    current_module = sys.modules[__name__]
    tests = [
        f for name, f in inspect.getmembers(current_module, inspect.isfunction)
        if name.startswith("test_")
    ]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"[PASS] {test.__name__}")
        except Exception as e:
            print(f"[FAIL] {test.__name__}: {e}")
            failed += 1
    if failed > 0:
        sys.exit(1)
    print(f"All {len(tests)} tests passed!")
