#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")
PROJECT_ROOT=$(cd "$SKILL_DIR/../../.." && pwd)

echo "============================================================"
echo "[VERIFY] vcd-categorical-analysis v4.1 Comprehensive Verification"
echo "============================================================"
echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Skill dir: $SKILL_DIR"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Error: Rscript not found in PATH"
  exit 1
fi

echo ""
echo "--- Step 1: Unit & Modular Logic Tests ---"
Rscript "$SKILL_DIR/tests/test_logic.R"

echo ""
echo "--- Step 2: Input Boundary & Failure Mode Tests (7 Failure Modes) ---"
Rscript "$SKILL_DIR/tests/test_vcd_categorical_input_boundary.R"

echo ""
echo "--- Step 3: Pass 0 Provenance Integration Tests ---"
Rscript "$SKILL_DIR/tests/test_vcd_categorical_pass0_boundary.R"

echo ""
echo "============================================================"
echo "[SUCCESS] All vcd-categorical-analysis v4.1 tests passed!"
echo "============================================================"
