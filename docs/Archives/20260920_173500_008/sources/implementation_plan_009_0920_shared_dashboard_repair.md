# shared-dashboard-theme-assets 修正実装文書

created: 2026-09-20 15:50 (JST)
update: 2026-09-20 15:50 (JST)
author: Codex (GPT-5) sol

- Status: Proposed Repair / Archive HOLD
- Target change: `openspec/changes/shared-dashboard-theme-assets/`
- QA profile: strict / blind-first
- Scope: 既存Changeの修正のみ。新しい統計手法・新テーマ・KaTeX移行は追加しない。
- Sample evidence: user-provided `dashboard.html`
- Sample SHA-256: `9460d7c914a5127b5cd1c968054fe4c74d912b13f236ef2f16aa6c01a5965101`

## 1. 結論

`shared-dashboard-theme-assets` は実装の大部分が完了しているが、現時点では archive しない。

前回独立レビュー F1〜F3 のうち、

- F1: 希少確率の固定小数丸めによるゼロ化 → 修正済み
- F2: 90%/95% ETI の固定ラベル → 修正済み
- F3: 用語集冒頭の無条件な N 比例表現 → 主修正済み。ただし `analysis.R` help 文言に残存あり

今回の再レビューでは、以下を archive 前の残修正とする。

| ID | Severity | 修正要否 | 内容 |
|---|---|---:|---|
| F4 | HIGH / Blocker | MUST | `analysis_config.schema.json` の JSON 構文不正 |
| F5 | MEDIUM-HIGH | MUST | OpenSpec の prior 固定契約に対し任意正値 alpha を許している |
| F6 | HIGH / Governance | MUST | Jeffreys移行の正本仕様が presentation capability 側に偏在 |
| F7 | MEDIUM | MUST | 2-way正本11-sectionに対し Glossary が Section 12。Glossary内の一部導線も旧番号 |
| F8 | MEDIUM | MUST | Change固有テストが official regression suite に未登録 |
| F9 | LOW | SHOULD | Change外ファイル削除等を修正コミットから分離し履歴境界を明瞭化 |

## 2. 実行サンプルから確認した事実

ユーザー提供の `dashboard.html` は、現行2-way dashboard の実出力として次を示す。

### 2.1 11セクション本体 + Section 12 Glossary

分析本体は以下の11セクションを持つ。

1. Executive Summary
2. Global Association & Effect Size
3. Effect × Evidence & Dual-Filter
4. Adjusted Residual Structure
5. Cell Explorer
6. Joint Posterior Credible Intervals
7. Conditional Posterior Distributions
8. Uncertainty Ranking
9. Posterior Departure from Independence
10. Prior Sensitivity Analysis
11. Quality & Provenance

その後に、

`12. 統計用語集・方法論解説・学術リファレンス`

が追加されている。

正本 `openspec/specs/two-way-evidence-analysis/spec.md` の「11セクション」契約を分析本体の構成として維持し、Glossary は分析セクション番号から分離する。

### 2.2 数式レンダリング

サンプルHTMLには MathML `<math>` 要素が 87 個あり、KaTeX DOM要素は 0 個であった。

したがって本修正では、

- MathML を現状維持する
- KaTeX を導入しない
- KaTeX/MathML方式変更をこのChangeの受入条件へ追加しない

とする。

KaTeXへの移行は、必要ならレンダリング互換性の専用Changeとして別途扱う。

### 2.3 Zero-External-Asset

サンプルHTMLの `src` / `href` 静的確認では、

- `http://` / `https://` / `//` の外部アセット参照: 0
- `/Users/`, `/home/`, `file://` のローカル絶対参照: 0

であり、現行の単一HTML・オフライン方向は維持する。

## 3. 修正方針

### 3.1 F4 — JSON Schema 構文修復

対象:

`.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`

現状は `dirichlet_prior` の直後に、キー名を失った断片が残っている。

```json
"dirichlet_prior": {
  ...
},
  "type": "number"
},
"factor_levels_order": {
```

元来の `arm_min_confidence` property を復元する。

```json
"arm_min_confidence": {
  "type": "number"
},
"dirichlet_prior": {
  "type": "object",
  ...
},
"factor_levels_order": {
```

#### 必須条件

- JSON parser で parse 可能
- JSON Schema として validator がロード可能
- 既存 deprecated-key policy と矛盾しない
- `arm_min_confidence` を復元するだけで旧機能を再活性化しない

### 3.2 F5 — 3-way prior contract を OpenSpec に合わせて閉じる

このChangeで合意済みの新規3-way条件付き割合は、

- primary: symmetric Dirichlet alpha = 0.5
- sensitivity: symmetric Dirichlet alpha = 1.0

である。

現在の schema / validation が任意の正値 alpha を許す状態は、本Changeの仕様幅より広い。

#### 修正

Schema:

```json
"primary_alpha": {
  "type": "number",
  "const": 0.5,
  "default": 0.5
},
"sensitivity_alpha": {
  "type": "number",
  "const": 1.0,
  "default": 1.0
}
```

R側 validation でも防御的に、

```r
primary_alpha == 0.5
sensitivity_alpha == 1.0
```

を検証する。

#### 注意

任意 alpha を将来許可する場合は、別Changeで configurable prior contract として定義する。
今回の修正で機能拡張しない。

### 3.3 F6 — OpenSpec capability ownership を修正

現 active change は、

`specs/shared-dashboard-presentation/spec.md`

の中に表示契約と統計計算契約を同居させている。

archive後の正本では責務を分ける。

#### A. `shared-dashboard-presentation`

ここに残すもの:

- shared CSS
- DataTables Japanese dictionary
- glossary
- zero-external-asset
- dimension/context-aware presentation
- mathematical wording / interpretation boundary
- generated HTML structural verification

#### B. `conditional-rate-view`

active change 配下に delta spec を新設する。

推奨パス:

`openspec/changes/shared-dashboard-theme-assets/specs/conditional-rate-view/spec.md`

ここへ移す/重複なく定義するもの:

- 3-way primary alpha = 0.5
- sensitivity alpha = 1.0
- support definition
- structural zero handling
- prior metadata / provenance
- rare probability precision preservation
- interval-level consistency
- primary/sensitivity comparison
- old-run non-relabel rule

archive時に `openspec/specs/conditional-rate-view/spec.md` へ統合される構造とする。

### 3.4 F7 — Glossary を Appendix 化し、導線を現行Sectionへ同期

2-way本体11-sectionは変更しない。

現行:

```html
<h2><span>12.</span> 統計用語集...
```

修正案:

```html
<h2>統計用語集・方法論解説・学術リファレンス
    (Glossary & Scientific References)</h2>
```

または、

```html
<h2>Appendix — 統計用語集・方法論解説・学術リファレンス</h2>
```

番号 `12.` を付けない。

#### Glossary内の導線

ハードコードされた旧Section番号を除去し、既に利用側から渡している context を使う。

特に次を修正する。

- Pearson X²: 現行 Section 2
- Cramér's V: 現行 Section 2
- corrected Cramér's V: 現行 Section 2
- Adjusted Residual: 現行 Section 4
- Effect/Evidence: Section 3
- Cell Explorer / Influence: Section 5
- Joint posterior: Section 6
- Conditional: Section 7.1 / 7.2
- Uncertainty: Section 8
- Posterior departure: Section 9
- Prior sensitivity: Section 10
- Quality/provenance: Section 11

可能な限り `dashboard_glossary.R` 側に数字を直書きせず、`dashboard.Rmd` の context を正本とする。

### 3.5 F3 residual — `analysis.R` help の無条件N比例文言

対象:

`.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`

現残存:

```r
cat(" 2. Evidence（証拠強度: 標本数Nに正比例）\n")
```

修正:

```r
cat(" 2. Evidence（統計的証拠強度）\n")
```

必要なら続く説明で、

「同じ度数構成を c 倍し、同一モデルを再適合する場合に T_score は c 倍」

と条件付きで記述する。

一般の標本追加に対する無条件N比例を主張しない。

### 3.6 F8 — official regression suite へ登録

`tests/run_regression_suite.R` に以下を追加する。

- `tests/test_shared_dashboard_math.R`
- `tests/test_three_way_dashboard_html.R`
- `tests/test_vcd_categorical_dashboard_v4.R`
- 新規 `tests/test_three_way_analysis_config_schema.R`

レンダリング依存で通常suiteへ入れられないものがある場合は、
`core` と `integration/render` を明示的に分離し、どちらも最終QAでは必須とする。

### 3.7 F9 — commit/change boundary

修正コミットでは、次を避ける。

- unrelated memo deletion
- unrelated root file cleanup
- scratch artifact deletion
- archive整理

必要なら別commitへ分離する。

推奨commit境界:

1. `fix(schema): repair 3-way analysis config schema`
2. `spec: align conditional-rate prior ownership`
3. `fix(glossary): align appendix and section navigation`
4. `fix(stats-doc): remove unconditional N-proportional wording`
5. `test: add shared-dashboard regression gates`
6. `docs: record independent re-review evidence`

## 4. OpenSpec修正タスク

### Phase A — Spec ownership

- [ ] A1 `shared-dashboard-presentation` から統計計算の正本責務を切り分ける
- [ ] A2 `conditional-rate-view` delta spec を追加
- [ ] A3 primary=0.5 / sensitivity=1.0 を MUST として固定
- [ ] A4 rare probability precision / ETI level / old-run non-relabel を conditional-rate-view 側へ配置
- [ ] A5 presentation側は「結果を再計算しない」を保持
- [ ] A6 `openspec validate shared-dashboard-theme-assets --strict` PASS

### Phase B — Schema / validation

- [ ] B1 invalid JSON fragment を修復
- [ ] B2 schema parser test を追加
- [ ] B3 primary/sensitivity alpha の const contract を追加
- [ ] B4 R validation と schema を一致させる
- [ ] B5 config example を再検証

### Phase C — Dashboard presentation

- [ ] C1 2-way Glossary の `12.` を削除し Appendix 扱い
- [ ] C2 Glossary内のSection導線を現行構成へ同期
- [ ] C3 context-driven routing を優先し重複ハードコードを減らす
- [ ] C4 MathML は維持。KaTeX導入なし
- [ ] C5 Zero-External-Asset を維持

### Phase D — wording

- [ ] D1 3-way `analysis.R` help の「Nに正比例」を除去
- [ ] D2 glossary / help / dashboardに旧無条件表現が残っていない

### Phase E — regression

- [ ] E1 schema test
- [ ] E2 shared dashboard math test
- [ ] E3 2D dashboard generation test
- [ ] E4 3D dashboard generation test
- [ ] E5 90% / 95% ETI test
- [ ] E6 rare probability JSON round-trip
- [ ] E7 MathML present / KaTeX absent を「現行方式保持」の回帰確認として実施
- [ ] E8 external/local absolute reference = 0
- [ ] E9 official suite registration
- [ ] E10 strict blind-first re-review

## 5. 非目標

本修正では以下を実施しない。

- KaTeX導入
- MathJax導入
- MathML方式の全面変更
- 新しい統計指標
- 3-way Dual-Filter式変更
- Poissonモデル選択変更
- 4-way拡張
- dark mode
- mobile redesign
- 任意Dirichlet alpha機能
- regulation submission validation

## 6. Acceptance Criteria

すべて満たした場合のみ archive 候補とする。

1. `analysis_config.schema.json` がJSONとしてparse可能
2. schema validationが実行可能
3. 3-way new run は primary alpha=0.5 / sensitivity alpha=1.0
4. その他alphaは明示的にreject
5. Jeffreys移行の正本deltaが `conditional-rate-view` capability に存在
6. shared presentation spec は presentation責務に限定
7. 2-way分析本体は11-sectionのまま
8. GlossaryはSection 12ではなくAppendix/unnumbered
9. Glossaryの「どこを見るか」が現行Section構造と一致
10. `analysis.R` help に無条件「Nに正比例」がない
11. rare positive posterior / ETI がJSON round-trip後も > 0
12. 90%/95% ETIの見出し・表・図・glossaryが一致
13. MathMLレンダリングは維持される
14. KaTeXを新規依存として追加しない
15. external URL / local absolute path = 0
16. Change固有テストが正式QA経路に登録
17. OpenSpec strict validation PASS
18. core regression PASS
19. render/integration tests PASS
20. 別担当blind-first reviewerが material finding 0 を確認
21. Owner adjudication 後に archive

## 7. 完了判定

次の論理積で完了とする。

`Spec ownership`
AND `Schema validity`
AND `Implementation`
AND `Regression`
AND `Generated HTML evidence`
AND `Independent QA`
AND `Owner acceptance`

`tasks.md` の `[x]` のみでは完了根拠としない。
