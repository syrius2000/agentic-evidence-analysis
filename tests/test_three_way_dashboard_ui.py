from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / ".agents/skills/vcd-bayesian-evidence-analysis/templates/three_way"


def test_dashboard_has_offline_accessible_components():
    renderer = (TEMPLATE / "render_report.R").read_text()
    css = (TEMPLATE / "dashboard.css").read_text()
    assert 'class="hero"' in renderer
    assert 'class="metrics"' in renderer
    assert 'class="factors"' in renderer
    assert 'class="model-detail"' in renderer
    assert 'class="model-link"' in renderer
    assert 'tabindex="-1"' in renderer
    assert 'e.key==="Enter"' in renderer
    assert "scrollIntoView" in renderer
    assert "MathJax" not in renderer
    assert "@media(max-width:700px)" in css
    assert ".scroll{overflow:auto" in css
    assert "outline:3px" in css


def test_statistical_language_does_not_restore_legacy_semantics():
    renderer = (TEMPLATE / "render_report.R").read_text()
    assert "真のモデルや自動的な勝者を意味しません" in renderer
    assert "近似log BFを厳密BFやモデル事後確率と同一視しません" in renderer
    assert "PARTIAL_HOLD" in renderer
    assert "legacy_score" not in renderer


def test_validation_is_separate_and_mandatory():
    renderer = (TEMPLATE / "render_report.R").read_text()
    validation = (TEMPLATE / "report_validation.R").read_text()
    assert "validate_report_artifacts(dir)" in renderer
    assert '"three-way-results-v1"' in validation
    assert '"executive_summary.md", "quality_check.md", "narrative_claims.json"' in validation
    assert 'claims$status, "REVIEWED"' in validation
    assert "考察の数値不一致" in validation
    assert "既存HTMLは上書きしない" in renderer
