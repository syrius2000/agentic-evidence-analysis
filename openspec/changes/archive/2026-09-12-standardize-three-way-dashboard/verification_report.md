# standardize-three-way-dashboard 実装・監査検証レポート

created: 2026-09-12 (JST)
branch: `codex/dashboard-unification`
target_head: `6d07077c7e45ee9b2c82f6304b82735c1cd9df09`
base_commit: `dfc851beb7030e8fd4cb07a0f8384bc98f275977`
commit_chain:

- `e1d1343`: feat(vcd-3way): 3次元ダッシュボードの標準化と数理・オフライン基盤の実装
- `6d07077`: test(fixtures): UCB 3-Way 正本 fixture の追加と不変性回帰テストの導入
worktree: `/Users/myamaguchi/Programing/00TotalRWD/agentic-evidence-analysis-dashboard`

---

## 1. 実施概要

本変更は `docs/Artifacts/implementation_plan_013_0912.md` に基づき、AG版の凡例・結論表示・モデル比較と、M版の分母付きセル集計・監査表示を統合した、デスクトップ向け3次元ダッシュボードの標準化実装である。

- **Pass 0 検査と設定契約**:
  `examples/ucb_admissions.csv`（24完全セル, $N=4,526$）の合意仕様に基づき、`analysis_config.json` を確定。スキーマ検証および未知モデルIDの即時エラー停止、`conditional_rate_view` の検証、不整合時の部分 HOLD を実装。
- **Pass 1 三次元計算正本経路**:
  全主効果を含む M1〜M9 階層対数線形モデル適合、ポアソン明示式 $\mathrm{BIC} = -2\ln L + p\ln N$（M5=332.3119, M8=339.1982）、多重基準セル診断（M1相互独立基準 / M5選択モデル基準）、大標本 Dual-Filter（$|\log(O/E)| \ge 0.50$ かつ $T^{\mathrm{score}} \ge 3.84$ かつ REGULAR）、旧 Evidence Score の監査専用隔離、汎用 Dirichlet 条件付き率推論を実装。
- **Pass 2 / 2.5 主張ゲート (Claims Gate)**:
  `narrative_claims.json`（12 claims）による結果 SHA-256、JSON Pointer、数値の完全照合ゲートを導入。不一致や未確認サマリーの完成レポート化を完全遮断。
- **Pass 3 デスクトップ UI & 完全オフライン化**:
  `katex` パッケージおよびインライン CSS による LaTeX 静的埋め込み、DataTables 日本語辞書インライン化、外部 CDN / Ajax / Google Fonts のネットワーク要求 0 件を達成。最良モデル表示の 2 案（横長コンパクト帯 `band` vs 抑制した独立カード `card`）の切替対応。
- **Fixture 保全と回帰テスト**:
  旧 AG OTC_Q05 fixture（`antigravity_otc_q05_v1`）および新 UCB 3-Way fixture（`ucb_admissions_three_way_v1`）のハッシュ不変性・数値契約を固定。

---

## 2. 独立監査マトリクス（delta-spec 全シナリオ対応表）

| Capability | Requirement | Scenario | 検証コード / テスト | 実行結果・証拠 |
| :--- | :--- | :--- | :--- | :--- |
| **three-way-dashboard-reporting** | 因子とモデル記号の一貫表示 | UCB Admissionsを表示する | `tests/test_three_way_dashboard_html.R` | PASS (因子凡例 A:Dept, B:Gender, C:Admit, 応答変数表示) |
| | ポアソン明示式BIC比較 | UCBの最良モデルを表示する | `tests/test_three_way_computation_engine.R` | PASS (M5=332.3119, M8=339.1982, M5最良) |
| | | 候補モデルが評価不能である | `templates/analysis.R`, `config_validation.R` | PASS (FAILED状態と理由記録、BIC比較除外) |
| | 相対的モデル選択の説明 | M5を要約する | `output/ucb_admissions/run_ucb_admit_standa/executive_summary.md` | PASS (相対採択、真の独立・公平性の証明ではない限界を明記) |
| | エグゼクティブサマリー根拠検証 | 考察の数値が改変されている | `tests/test_narrative_claims_gate.R` | PASS (改変ハッシュ、無効Pointer、HOLD数値の拒否検証) |
| | 単一HTML完全オフライン | ネットワークを遮断して開く | `tests/test_three_way_dashboard_html.R`, `render_dashboard.R` | PASS (外部 script/link 要求 0 件、MathJax/ja.json 排除) |
| | 標準参照版の来歴追跡 | UCB標準版を再生成する | `tests/test_dashboard_fixture_invariance.R` | PASS (manifest.json による SHA-256・依存版追跡) |
| **multi-baseline-cell-diagnostics** | 基準モデル別にセル診断を保存 | UCBでM1とM5を診断する | `tests/test_three_way_computation_engine.R` | PASS (`cells$by_base_model$M1` と `M5` の完全分離) |
| | 4軸と分母付き件数を提示 | 大標本Dual-Filterを表示する | `tests/test_three_way_dashboard_html.R` | PASS (分母付きカード: M1探索候補=12/24, M5探索候補=1/24) |
| | | セルが不安定である | `tests/test_three_way_computation_engine.R` | PASS (QUARANTINED 判定: M1=0件, M5=11件) |
| | 旧Evidence Scoreの監査限定 | 旧指標を表示する | `tests/test_three_way_dashboard_html.R` | PASS (折りたたみ監査領域に隔離、判定ロジック不使用) |
| | 基準モデル設定を厳密に検証 | 未知のモデルIDを指定する | `tests/test_config_validation_rules.R` | PASS (M10等の未知IDで即時エラー停止) |
| | 基準別診断を切り替えて読める | M5詳細へ切り替える | `templates/dashboard.Rmd` (JS tab switching) | PASS (M1タブ / M5タブの独立表示・分母隣接) |
| **conditional-rate-view** | 条件付き割合の意味を設定明示 | UCBの合格割合を設定する | `tests/test_config_validation_rules.R` | PASS (response=Admit, num=Admitted, denom=2水準, comp=Gender, strat=Dept) |
| | | 多水準応答を設定する | `tests/test_config_validation_rules.R` | PASS (分子水準和/分母水準和の正常検証) |
| | 割合と事後不確実性の構造化保存 | UCBの学部内割合を保存する | `tests/test_three_way_computation_engine.R` | PASS (生割合、事後平均、95% ETI、男女差の完全記録) |
| | データ固有語を埋め込まず可視化 | 別の3変数表を表示する | `templates/dashboard.Rmd` | PASS (変数名・水準名から動的に見出し・軸・分母生成) |
| | 不明な意味を推測せず部分HOLD | 応答水準が未指定である | `tests/test_config_validation_rules.R` | PASS (末尾暗黙選択を拒否し HOLD 遷移) |
| | | 分母度数がゼロである | `tests/test_config_validation_rules.R` | PASS (分母ゼロ行を HOLD 遷移) |
| | 適用可能なデータ境界を守る | 割合のみの入力を受ける | `tests/test_config_validation_rules.R` | PASS (度数列なし入力を適用不能として拒否) |

---

## 3. テストスイート実行結果総括

すべてのテストは `codex/dashboard-unification` 分離 Worktree 上で exit code 0 で通過した。

```bash
Rscript tests/test_config_validation_rules.R      # 7 tests (ALL PASS)
Rscript tests/test_three_way_computation_engine.R # 49 assertions (ALL PASS)
Rscript tests/test_narrative_claims_gate.R        # 6 tests (ALL PASS)
Rscript tests/test_three_way_dashboard_html.R     # 49 assertions (ALL PASS)
Rscript tests/test_dashboard_fixture_invariance.R # 41 assertions (ALL PASS)
```

**合計: 152 項目以上の検証すべて合格。**

---

## 4. 最良モデル表示 2 案の比較と確認用ファイル

Chrome headless（1280px デスクトップ幅）により撮影された画像および生成 HTML：

1. **案 A: 横長コンパクト要約帯 (`band`)**
   - HTML: `output/ucb_admissions/run_ucb_admit_standa/dashboard_band.html`
   - スクリーンショット: `output/ucb_admissions/run_ucb_admit_standa/screenshot_band.png`
   - 特徴: 縦スペースを圧迫せず、青色アクセントバッジ（`M5`）とメトリクス（明示式BIC 332.31, ΔBIC +6.89）が1行に整理され、AI サマリーへの視線誘導が極めてスムーズ。
2. **案 B: 抑制した独立カード (`card`)**
   - HTML: `output/ucb_admissions/run_ucb_admit_standa/dashboard_card.html`
   - スクリーンショット: `output/ucb_admissions/run_ucb_admit_standa/screenshot_card.png`
   - 特徴: 白背景の独立カード枠で、左側にモデル解釈、右側にグレーのメトリクスボックスを配置。情報ブロックが明確に境界付けられている。

### 裁定結果（改善提案 IP-001 の確定）

Owner（統括者）のレビューにより、縦スペースを圧迫せず情報集約度と AI サマリーへの視線誘導に優れた **【案 A: 横長コンパクト要約帯 (`band`)】** が正本レイアウトとして正式採用・決定されました。正本 `dashboard.html` および正本 fixture は案 A で固定・確定されています。

---

## 5. コミット・マージ・プッシュの境界遵守

- 本 Worktree（`codex/dashboard-unification`）は比較基準 `dfc851beb7030e8fd4cb07a0f8384bc98f275977` から分岐し、2つのコミット（`e1d1343` 実装＋テスト、`6d07077` fixture 追加）で構成されています。
- 今回の QMS 是正作業（F-001: 生割合と事後平均の推定量明示・テスト強化、F-002: レポート来歴照合）は、Owner 実装許可（`allowed_targets`）の認可範囲内で厳密に修正・更新されています。
- `main` への commit / merge / push は一切行われていません。
- メインリポジトリ（`/Users/myamaguchi/Programing/00TotalRWD/agentic-evidence-analysis`）は `working tree clean` のまま維持されています。
