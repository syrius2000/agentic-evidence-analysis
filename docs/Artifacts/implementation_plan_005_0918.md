# 実装計画書: vcd-categorical-scientific-dashboard (完全オフライン Scientific Dashboard)

- **案件名**: `vcd-categorical-scientific-dashboard`
- **作成日**: 2026-09-18
- **作成者**: Antigravity
- **先行依存**: Change 1 (`vcd-categorical-provenance-boundary-hardening`), Change 2 (`vcd-categorical-conditional-posterior-contract`) 完了・受入済み

---

## 1. 背景と目的

現行の `dashboard.Rmd` は 6 セクション構成であり、自己完結 HTML を指向しているものの、

1. Adjusted Residual（頻度論的局所逸脱）、Conditional Posterior（条件付き予測確率）、Uncertainty Ranking（事後不確実性）、Posterior Departure from Independence（局所独立性からの事後対数乖離）、Prior Sensitivity（主事前 Jeffreys $\alpha=0.5$ と対照一様事前 $\alpha=1.0$ の感度分析）という「異なる 5 つの統計的・科学的問い」が画面構造として十分に分離されていない。
2. 小規模・中規模・大規模表における一貫した決定論的 Top-N 選定と全件アクセス性の保証ルールが未整備。
3. Section 11（Quality & Provenance）において、先行 Change 1/2 で確定した `execution_mode: "canonical"`、Pass 0 三者 SHA 再検証状態、解析署名、決定論的乱数シード、Monte Carlo ドロー数が漏れなく表示されていない。
4. 自己完結 HTML の主張に対して、外部 URL / CDN 混入の静的走査と、ネットワーク遮断相当のブラウザ確認による二重受入体制を確立する。

本改修では、先行 Change 1/2 で確定した JSON 契約（`categorical_results.json` および `run_state.json`）の**完全な消費者（Consumer）**として Dashboard を再構成し、統計量の独自計算や再推論を一切行わずに、11 セクション構成の完全オフライン Scientific Dashboard を実現する。

---

## 2. 契約境界と非機能要件（鉄則）

1. **Dashboard 側での再計算・再推論の絶対禁止**:
   - 条件付き事後、局所対数乖離、不確実性順位、感度分析、残差、効果量等の統計量はすべて `categorical_results.json` の既存フィールドをそのまま描画する。
   - 表示用の絶対値（`abs()`）やソート・フォーマット以外の統計的再計算を行ってはならない。
2. **Provenance / 状態の取得元契約**:
   - `execution_mode`、`analysis_signature`、`input_sha256`、`config_sha256`、`deterministic_seed` は `categorical_results.json` の `provenance` ブロックから取得する。
   - 三者 SHA 再検証状態は、同ディレクトリ内の `run_state.json` の `provenance_status` から取得し、`"verified"` の場合のみ「検証済み」と表示する（ファイルまたはフィールド欠落時は「未確認」と表示）。Dashboard 自身による再検証は行わない。
3. **完全オフライン性**:
   - 外部 CDN、Google Fonts、リモート MathJax、外部 JavaScript/CSS の一切を排除。
   - Pandoc `--mathml`、システムフォントスタック、DT の完全インライン日本語辞書を維持。
   - 生成 HTML に対して、外部 URL（`http:`, `https:`, `//`）および OS ローカル絶対パス（`/Users/`, `/home/`, `/private/var/`, `^[A-Za-z]:`）の混入を機械的に検出・拒否する静的走査を実施。
4. **自動判定の完全排除**:
   - 各セクション冒頭に「この図が答える統計的・科学的問い」と「解釈上の限界・非自動判定の注意」を日本語で明示する。
   - 残差を有意性・効果量と混同させない、ETI 幅を重要性と混同させない、対数乖離の区間が 0 を跨ぐかだけで二値判定しない、感度差をモデル誤りと判定しない。

---

## 3. 11 セクションの構成設計

| No | セクション名 | 答える問い / 主指標 | 表示形式と規則 |
|:---|:---|:---|:---|
| 1 | **エグゼクティブ要約** (Pass 2 AI Narrative) | 分析全体の統合的定性的解釈 | `executive_summary.md` のレンダリング（MathML正規化） |
| 2 | **全体連関構造** (Global Association & Effect Size) | 表全体の連関の有無と効果の大きさ | 指標カード: $N, \chi^2, p$, Cramér's $V$, 偏り補正 $\tilde{V}$ (95% CI) |
| 3 | **局所効果 × 証拠散布図** (Effect × Evidence & Dual-Filter) | どのセルが大きく乖離し、十分な証拠があるか | 散布図: 横軸 $\log(O/E)$, 縦軸 $T^{\rm score}$。大標本 Dual-Filter 候補明示 |
| 4 | **調整残差構造** (Adjusted Residual Structure) | 【新規】帰無仮説（独立）からの頻度論的局所標準化残差 | 0 中心バー/ヒートマップ。調整残差 $z_{ij}$。隔離セル区別。「効果量ではない」明記 |
| 5 | **セル診断エクスプローラー** (Cell Explorer) | 全セルの網羅的・定量的数値一覧 | 完全インライン日本語 DataTables。全セル（観測、期待、残差、効果比、Rao、状態、候補） |
| 6 | **結合事後推論** (Joint Posterior Credible Intervals) | セル結合生起確率 $\pi_{ij}$ の事後推定値と不確実性 | 点・区間プロット（事後平均、95% ETI）。行グループ色分け |
| 7 | **条件付き事後推論** (Conditional Posterior Distributions) | 【新規】行または列を与えたときの条件付き生起確率 | $P(B\mid A)$ と $P(A\mid B)$ を別表示。主表示: 中央値 & 95% ETI、補助: 平均。中央値の総和$\neq 1$の注意明記 |
| 8 | **事後不確実性ランキング** (Uncertainty Ranking) | 【新規】推定精度の高いセル・低いセルの特定 | 主指標: `prob_eti_width`。JSON の `rank` 順序を直接使用。重要性判定ではない旨を明記 |
| 9 | **局所独立性事後乖離** (Posterior Departure from Independence) | 【新規】独立モデルからの対数乖離度の事後推論 | 主指標: `log_divergence_median` & 95% ETI。参照線 0。0 を跨ぐかの二値判定排除 |
| 10 | **事前分布感度分析** (Prior Sensitivity Analysis) | 【新規】主事前 Jeffreys ($\alpha=0.5$) と対照一様 ($\alpha=1.0$) の頑健性 | 主指標: `median_shift`, `eti_width_difference`。モデル誤り自動判定ではない旨を明記 |
| 11 | **品質・プロビナンス情報** (Quality & Provenance) | 実行の完全な監査証跡と再現性情報 | `execution_mode: "canonical"`, Pass 0 三者 SHA 検証状態, 署名, シード, ドロー数, 隔離セル数 |

---

## 4. 表サイズ別表示規則と決定論的 Top-25 選定

全セル数 $K$ に応じた 3 区分：

1. **小規模 ($K \le 30$)**:
   - 全セル図と全件表を通常表示。
2. **中規模 ($31 \le K \le 100$)**:
   - 過密な全セル図を置き換え、スクロール・フィルタ可能な全件表を主表示とする。
3. **大規模 ($K \ge 101$)**:
   - 視座別の決定論的 Top-25 縮約図と、スクロール・フィルタ可能な全件表。
   - 縮約図には選定指標、選定順序、表示セル数（25）、非表示セル数（$K - 25$）、Cell Explorer への導線を明記。

**Top-25 選定順序（JSON 既存値のみ使用）**:

- Effect × Evidence: `abs(cells.log_oe)` 降順
- Adjusted Residual: `abs(cells.adj_res)` 降順
- Joint Posterior: `posterior.cell_posteriors.prob_mean` 降順
- Conditional Posterior: `cond_row_prob_median`, `cond_col_prob_median` 降順（方向別）
- Uncertainty Ranking: `posterior.uncertainty_ranking.rank` 昇順（再計算禁止）
- Posterior Departure: `abs(log_divergence_median)` 降順
- Prior Sensitivity: `posterior.sensitivity_analysis.cell_comparisons.median_shift` 降順
- **同順位規則**: `row_level`, `col_level` の UTF-8 バイト順昇順。境界で同順位があっても 25 セルに固定。
- **欠落・非有限値**: 有限値の後ろに配置。

---

## 5. 変更対象ファイル

### 1. テンプレート

- [MODIFY] [`.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`](.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd)
  - 11 セクションの HTML / R チャンク実装
  - 表サイズ別フォールバック（小・中・大）および Top-25 決定論的ロジック
  - 日本語問い・解釈限界の説明ブロック
  - Section 11 の provenance_status 読込と表示

### 2. テストスイート

- [MODIFY] [`tests/test_vcd_categorical_dashboard_v4.R`](tests/test_vcd_categorical_dashboard_v4.R)
  - Test 1: 小規模表（2x2）での 11 セクション正常レンダリング
  - Test 2: 中規模表（31〜100 セル）でのフォールバック動作
  - Test 3: 大規模表（101 セル以上）での Top-25 選定・同順位固定・非表示セル数表示
  - Test 4: 外部 URL / CDN / スクリプト / 画像の静的正規表現走査（完全排除）
  - Test 5: OS ローカル絶対パス（`/Users/`, `/home/`, `/private/`, Windows ドライブ）の静的走査（完全排除）
  - Test 6: `run_state.json` の `provenance_status` 連携（`"verified"` および欠落時「未確認」の表示検証）
  - Test 7: Dashboard 側での統計量再計算が存在しないことのコード静的検証

### 3. OpenSpec タスク追跡

- [MODIFY] [`openspec/changes/vcd-categorical-scientific-dashboard/tasks.md`](openspec/changes/vcd-categorical-scientific-dashboard/tasks.md)
  - タスク進捗（1.1 〜 4.3）の更新

---

## 6. 検証手順

1. **R スクリプト個別テスト**:
   - `Rscript tests/test_vcd_categorical_dashboard_v4.R`（`BypassSandbox: true`）
2. **全体回帰テスト**:
   - `test_vcd_categorical_*.R` 全スイートの実行
3. **HTML 静的走査**:
   - 外部プロトコルおよびローカル絶対パスのゼロ検出確認
4. **ブラウザ受入確認**:
   - ヘッドレスブラウザ / Playwright による完全オフライン描画・コンポーネント・日本語・MathML 動作確認
