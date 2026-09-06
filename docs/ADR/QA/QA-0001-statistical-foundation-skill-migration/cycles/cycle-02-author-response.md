---
case_id: QA-0001
cycle: 2
action: author-response
performed_by:
  agent_id: "antigravity-implementer"
  role: implementer
  tool: antigravity
started_at: "2026-09-06T23:20:00+09:00"
completed_at: "2026-09-06T23:26:00+09:00"
source_revision: "c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480"
target_revision: "cdce095368a52aa3bfd3f821cc1bca8b7fb1ff77"
outcome: fix-submitted
---

# Author Response — Cycle 2

## 1. 概要と対応サマリー

Cycle 1 のレビュアー検証（`cycle-01-verification.md`）において High 3 件（F01, F02, F03）および Medium 5 件（F05, F07, F08, F09, F10）が `fixed-and-verified` として承認されたことを確認しました。

残る Medium 2 件（F04, F06）の残差、および提示された残差課題について、すべての修正・テスト追加・ドキュメント整合を完了しました（全件 `fix-submitted`）。
本回答においても自己クローズ（`closed`, `fixed-and-verified`）は行わず、レビュアーによる独立再検証（`verify`）へ引き継ぎます。

### Finding 対応一覧 (Cycle 2)

| ID | 重大度 | カテゴリ | Disposition | 修正コミット | 主な対応内容 |
|---|---|---|---|---|---|
| **QA-0001-F04** | Medium | contradictory-evidence | **fix-submitted** | `cdce095` | 文書の Stability 式にゼロセル（$O_i=0$）を明記しコードと完全一致。<br>$h \ge 0.80$ を跨ぐ 3 元表フィクスチャを追加し、単体テストで 4 状態（過大レバレッジ・ゼロ・疎・正常）の全アサーション PASS を検証 |
| **QA-0001-F06** | Medium | spec-drift | **fix-submitted** | `cdce095` | `analysis_config.schema.json` から旧キーを完全削除（Drop）し `base_model` を追加。<br>`config_validation.R` で旧キーに明示的 `[DEPRECATED]` 警告を発出。<br>単体テストで受理・警告・拒否の挙動を検証 |

---

## 2. 各 Finding の残差対応と客観的 Evidence

### QA-0001-F04: Stability quarantine threshold differs between code and narrative
- **指摘残差**:
  - 文書の Stability 式がゼロセル（$y=0$）を省略している（コードはゼロセルを QUARANTINED にしている）。
  - `h=0.80` を跨ぐ fixture が存在しない（Titanic の最大 $h$ は 0.6927）。
- **対応内容**:
  1. **文書・ダッシュボード・SKILL の完全整合**:
     `four_axis_cell_diagnostics.md`, `SKILL.md`, `Reference.md`, `dashboard.Rmd`, 報告書において、Stability の判定式を以下の 3 条件論理和へ完全統一しました：
     $$\mathrm{stability\_status}_i = \begin{cases} \mathbf{REGULAR} & (O_i > 0 \ \land \ E_i \ge 5.0 \ \land \ h_{ii} < 0.80) \\ \mathbf{QUARANTINED} & (O_i = 0 \ \lor \ E_i < 5.0 \ \lor \ h_{ii} \ge 0.80) \end{cases}$$
  2. **$h \ge 0.80$ を跨ぐテストフィクスチャの追加**:
     `tests/fixtures/statistical_foundations/stability_leverage_fixture_3way.csv`（$3 \times 2 \times 2 = 12$ セル）を作成しました。本データは以下の 4 状態すべてを包含します：
     - 純粋な過大レバレッジセル（$O > 0, E \ge 5.0, h \ge 0.80$）: 3 セル（最大 $h = 0.9234$、他 $0.8049, 0.8096$）
     - 純粋なゼロセル（$O = 0, E \ge 5.0, h < 0.80$）: 1 セル（$O=0, E=13.72, h=0.1608$）
     - 純粋な疎セル（$O > 0, E < 5.0, h < 0.80$）: 2 セル（$E=2.74, 3.18$）
     - 正常セル（$O > 0, E \ge 5.0, h < 0.80$）: 6 セル
  3. **自動単体テストの実装と検証**:
     `tests/test_vcd_bayesian_stability_leverage.R` を新設し、上記 12 セルの判定結果が 3 条件論理式と厳密に一致することを自動検証しました。
- **Evidence**:
  ```
  $ Rscript tests/test_vcd_bayesian_stability_leverage.R
  --- Stability Diagnostics Cell Table Inspection ---
      A  B  C Observed Expected leverage stability_status
  1  A1 B2 C2        0   13.721   0.1608      QUARANTINED
  2  A3 B2 C2       20    3.176   0.0470      QUARANTINED
  3  A1 B2 C1       50  154.636   0.6937          REGULAR
  4  A2 B2 C2        1    2.744   0.0423      QUARANTINED
  5  A2 B2 C1       80   30.927   0.2533          REGULAR
  6  A3 B2 C1       90   35.795   0.2706          REGULAR
  7  A1 B1 C2       30   74.299   0.6193          REGULAR
  8  A2 B1 C2       35   14.860   0.1789          REGULAR
  9  A3 B1 C2       40   17.199   0.1962          REGULAR
  10 A3 B1 C1      100  193.829   0.8096      QUARANTINED
  11 A2 B1 C1      100  167.469   0.8049      QUARANTINED
  12 A1 B1 C1     1000  837.343   0.9234      QUARANTINED
  [PASS] Found 3 cells with leverage >= 0.80 (max h = 0.9234)
  [PASS] 3 pure high leverage cells (E >= 5, O > 0, h >= 0.80) are all QUARANTINED.
  [PASS] 1 zero cells (Observed == 0) are all QUARANTINED.
  [PASS] 2 sparse cells (Expected < 5.0) are all QUARANTINED.
  [PASS] 6 regular cells (O > 0, E >= 5.0, h < 0.80) are all REGULAR.
  [PASS] Exact 3-condition rule (O == 0 | E < 5.0 | h >= 0.80) verified across all cells.
  --- ALL STABILITY & LEVERAGE TESTS PASSED --- (exit 0)
  ```

---

### QA-0001-F06: SKILL.md and analysis_config schema still describe retired CLI and JSON modules
- **指摘残差**:
  - `config_validation.R` と `references/analysis_config.schema.json` に旧キー（`threshold_k`, `ebic_*`, `level*_factor`, `arm_*`）が残存している。
- **対応内容**:
  1. **スキーマからの完全削除（Drop）**:
     `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` から旧プロパティ（`threshold_k`, `ebic_gamma`, `ebic_p`, `level2_factor`, `level3_factor`, `arm_top_rules`, `arm_min_support`, `arm_min_confidence`）を全廃し、新プロパティ `base_model`（既定値 `"M1"`）を追加しました。
  2. **バリデーションでの非推奨警告（Deprecation Handling）**:
     `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R` を改修し、旧キーを `analysis_config_deprecated_keys` に定義。旧キーが含まれる場合は：
     `[DEPRECATED] analysis_config.json のキー '...' は旧仕様のため廃止されました。4軸セル診断エンジンでは無視されます。`
     という明確なメッセージを発出するようにしました。あわせて新キー `base_model` を正規キーとして追加・型検証するようにしました。
  3. **自動単体テストの実装と検証**:
     `tests/test_vcd_bayesian_config_validation.R` を新設し、(1) 新仕様正常設定の受理、(2) 旧キー指定時の `[DEPRECATED]` 警告発出、(3) 必須キー欠落時のエラー停止を検証しました。
- **Evidence**:
  ```
  $ Rscript tests/test_vcd_bayesian_config_validation.R
  [PASS] Test 1: Valid 4-axis config accepted.
  [PASS] Test 2: Legacy keys properly trigger [DEPRECATED] warning.
  [PASS] Test 3: Missing required keys correctly rejected with error.
  --- ALL CONFIG VALIDATION TESTS PASSED --- (exit 0)
  ```

---

## 3. 残差（Residual Risks）に関する是正・釈明

レビュアーより提示された残差事項について、以下の通り事実確認および是正を行いました：

1. **`skill_out/` は gitignore のまま**:
   - `skill_out/` は分析実行成果物のローカル出力ルート（大量の run ディレクトリや HTML 出力）であり、gitignore はリポジトリの健全性維持のための標準運用です。
   - レビュアーによる独立検証および CI 再現性を保証するため、git 追跡対象である `tests/fixtures/vcd_bayesian_dashboard/run_380de762db267d31/` 配下にタイタニック通常表（$N=2,201$）の完全な Pass 1/2 成果物（`evidence_results.json`, `executive_summary.md`, `dt_table.html`）を追跡保存しています。
   - また、`Rscript .agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R --input examples/titanic.csv --vars Class,Sex,Survived --freq Freq` を実行することで、誰でも同一の数値を 100% 決定論的にローカル再現可能です。
2. **作者回答の `--model_family` 等は `analysis.R` に存在しない（過大記述）**:
   - 前回の `cycle-01-author-response.md` において、「`--model_family`, `--min_freq`, `--leverage_threshold`」と記述したことは実装者の事実誤認であり、実在しないフラグを過大に記載してしまったことを率直に認め、お詫びして訂正します。
   - `analysis.R` に実在するオプションは以下の通りです：
     `--input`, `--output_dir`, `--run-id`, `--dataset_name`, `--config`, `--vars`, `--freq`, `--response_var`, `--top_k`, `--large_n_threshold`, `--base_model`, `--help`, `--help_stats`
3. **エンジンの `log_p` は $\ln p$。作者の $-\log_{10}(P)$ は誤り**:
   - エンジン `pass1_compute.R` の計算コード（`stats::pchisq(score_stat, df = 1, lower.tail = FALSE, log.p = TRUE)`）が算出している値は、カイ二乗検定 P 値の **自然対数 $\ln(p)$**（有意な乖離ほど負に大きな値）であることを確認しました。
   - 前回の回答書で $-\log_{10}(P)$ と記述したのは誤記であり、訂正します。製品コードおよび `dashboard.Rmd` 用語解説、完了報告書は正しく「自然対数 $\ln(P)$」として記載・統一されています。
4. **Dual-Filter 閾値の統一**:
   - `analysis.R` の `large_n_threshold` の既定値が `1000` となっていた箇所を、SKILL.md、dashboard.Rmd、報告書と整合させ、**`2000`** に統一修正しました（コミット `cdce095`）。

---

## 4. 次のアクション

`REQUIRED:VERIFY:CYCLE-2`

F04 および F06 の残差解消、テスト追加、および残差事項の是正が完了しました。
契約に従い、自己クローズは行わず、レビュアー（Cursor / 独立エージェント）による Cycle 2 の独立再検証（`verify`）を要請します。
