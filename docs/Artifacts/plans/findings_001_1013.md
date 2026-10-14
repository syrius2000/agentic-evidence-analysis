# Phase 1 検証所見 (findings_001_1013.md)

- 作成日時: 2026-10-13 JST
- 対象: Phase 1 (T1.1 〜 T1.5) の調査・検証結果

---

## 1. T1.1 run_state 不整合の実確認

- **検証内容**:
  1. `run_state` が `completed` / `failed` の `run_meta.json` (interface_version 2.0) を `read_run_control()` (`.agents/shared/run_scope.R:510`) に渡した際の挙動。
  2. 書込側の実態調査 (`run_freq.R:1291`, `run_means.R:677`, `batch_runner.R:596`, `analysis.R:508`)。
- **実測結果**:
  - `run_scope.R:510` は `if (!meta$run_state %in% c("active", "sealed")) stop("[ERROR] 不正なrun_state")` と実装されている。
  - 書込側の各スキルテンプレートは、正常完了時に `run_state = "completed"`、失敗時に `run_state = "failed"` を記録している。
  - このため、`run_state = "completed"` または `"failed"` を持つ正常成果物に対して `read_run_control()` を実行すると、即座に `[ERROR] 不正なrun_state` で例外停止することが実機で再現・確認された。
- **結論**:
  - **バグ確定**。`read_run_control()` の許可語彙（`active`, `sealed`）と、書込側が使用する語彙（`completed`, `failed`）に重大な不整合がある。Phase 2 の **T2.4 (run_state 語彙の統一: active / completed / failed / sealed)** を有効化して修正する必要がある。

---

## 2. T1.2 ヘッドレス Chrome で MathML 描画確認

- **検証内容**:
  - `katex::katex_mathml("x^2 + y^2 = z^2")` を埋め込んだ最小 HTML (`/tmp/mathml_probe.html`) を生成し、ヘッドレス Chrome (`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --screenshot`) で描画検証。
- **実測結果**:
  - スクリーンショット `/tmp/mathml_probe.png` (5,382 bytes) が正常に出力された。
  - 外部 CSS/JS/フォントの読み込みを行わずに native MathML (`<math xmlns="http://www.w3.org/1998/Math/MathML">`) による数式レンダリングが実行可能であることを確認。

---

## 3. T1.3 pass2_stub の呼び出し元確認

- **検証内容**:
  - `grep -rn "pass2_stub" .agents tests docs` による利用箇所の全調査。
- **調査結果**:
  - 主な参照箇所:
    1. `.agents/shared/run_scope.R:1125, 1167` (`pass2_stub_preview` 内でのパス解決)
    2. `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R` (本体)
    3. `tests/test_vcd_bayesian_pass2_stub.R` (回帰テスト)
  - 現行の `vcd-bayesian-evidence-analysis` の Pass 2 骨子生成スタブとして機能しており、テストでも検証されている現役コードである。
  - `pass2_stub.R:75, 91` に「Evidence Score」を用いた古い偏り記述が残存しているため、T2.3 による現行のセル診断用語（Residual, 局所セル診断）への置換が必要。

---

## 4. T1.4 出力先の確認

- **検証内容**:
  - `vcd-categorical-analysis/templates/analysis.R:54, 388` (`target_dir`, `lock_dir`)
  - `questionnaire-batch-analysis/templates/batch_runner.R:309, 420` (`q_out`)
- **調査結果**:
  - `analysis.R`:
    - `run_output_dir <- reserve_run_output_dir(out_root, "vcd-categorical-analysis", prefix16)` により予約された `run_output_dir` 配下に `lock_dir` (`.run_lock`) および解析成果物が作成されている。
    - 早期失敗時 (`record_run_failure(..., is_root = TRUE)`) のみ `out_root` 直下に `run_state.json` が書かれる仕様（計画書 §2 決定済）。
  - `batch_runner.R`:
    - `q_out <- file.path(out_dir, output_slug)` であり、`out_dir` は `reserve_run_output_dir` で確保されたバッチ用 run ディレクトリ配下となっている。設問ごとのサブディレクトリ `q_out`、画像 `figures/`、JSON 等はすべてその内部に閉じて出力されている。

---

## 5. T1.5 spec 一致監査

- **検証内容**:
  - `openspec/specs/` 全 19 件に対し、`run_state`, `run_meta`, `results_manifest`, `manifest.json`, `run_state.json`, `.run_lock`, `MathML`, `KaTeX`, `self_contained` 等を grep 照合。
- **調査結果**:
  - `implementation_plan_001_1013.md` §2.6 の表に記載されている 7 項目以外の未知の仕様衝突は検出されず、計画書の訂正方針（§2.6）で全件網羅されていることを確認。
