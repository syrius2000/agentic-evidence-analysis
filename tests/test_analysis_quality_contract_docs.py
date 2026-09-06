import inspect
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_analysis_quality_contract_exists_and_sets_boundaries():
    text = read(".agents/shared/analysis_quality_contract.md")

    required_phrases = [
        "Pass 2.5",
        "quality_check.md",
        "cross_question_summary.md",
        "P値のみで結論しない",
        "Evidence Scoreが負のセル",
        "MCP artifact",
        "Reactウィジェット",
        "外部Data Analyticsランタイムを要求しません",
    ]

    for phrase in required_phrases:
        assert phrase in text


def test_target_skills_reference_analysis_quality_contract():
    skill_paths = [
        ".agents/skills/vcd-pass0-consultation/SKILL.md",
        ".agents/skills/vcd-categorical-analysis/SKILL.md",
        ".agents/skills/vcd-bayesian-evidence-analysis/SKILL.md",
        ".agents/skills/questionnaire-batch-analysis/SKILL.md",
    ]

    for path in skill_paths:
        text = read(path)
        assert ".agents/shared/analysis_quality_contract.md" in text
        assert "共通品質契約" in text


def test_vcd_skills_define_quality_check_outputs():
    for path in [
        ".agents/skills/vcd-categorical-analysis/SKILL.md",
        ".agents/skills/vcd-bayesian-evidence-analysis/SKILL.md",
    ]:
        text = read(path)
        assert "Pass 2.5" in text
        assert "quality_check.md" in text
        assert "P値" in text
        assert "解釈保留" in text


def test_questionnaire_skill_defines_cross_question_summary():
    text = read(".agents/skills/questionnaire-batch-analysis/SKILL.md")

    required_phrases = [
        "cross_question_summary.md",
        "横断総括",
        "P値だけで設問を順位付け",
        "nominal_2way",
        "likert_2way",
        "nominal_3way",
        "status=error",
    ]

    for phrase in required_phrases:
        assert phrase in text


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
