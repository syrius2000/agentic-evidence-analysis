## Context

提案の背景は[proposal.md](proposal.md)を参照する。このchangeは、`vcd-categorical-conditional-posterior-contract` が条件付き事後のJSON契約を確定済みであることを前提とする。現行Dashboardは自己完結HTMLを指向するが、5視座を統計的な問いごとに分離した構成、大規模表の一貫した表示規則、静的HTMLとブラウザの二重受入証跡を持たない。

## Goals / Non-Goals

**Goals:**

- 11セクションを、分析の問いと統計量の意味が混ざらない順序で構成する。
- 条件付き事後、局所残差、不確実性、対数乖離、事前感度を同一セルに対しても別視座として表示する。
- 小規模から大規模まで、全件アクセスと認知負荷制御を両立する。
- 自己完結HTMLの主張を、静的走査とネットワーク遮断相当のブラウザ確認で検証可能にする。

**Non-Goals:**

- 条件付き事後の計算式、JSON Schema、CLI、Pass 0 provenanceの変更。
- Shiny化、SPA化、新規R・JavaScript依存関係の導入。
- 統計的な自動判定・推奨・因果解釈の追加。

## Decisions

### 問いを先に示し、図を後に示す

各新規セクションの冒頭に、対象の統計的問い、主指標、非解釈事項を日本語で置く。利用者は色や順位だけで同じ意味の強調と誤認しにくくなる。

単一の「重要セル」ランキングに統合する案は、Effect、Evidence、Uncertainty、Prior sensitivityの次元分離を損なうため採用しない。

### 条件付き確率は方向別かつ区間中心で示す

`P(B|A)` と `P(A|B)` は同じ結合分布から作られても問いが異なるため別表示とする。主表示を中央値と95% ETI、補助を平均とし、中央値の総和が1であるという印象を与えない。

両方向を一つのヒートマップへ混在させる案は、条件付けの向きが不明瞭になるため採用しない。

### 大規模表は決定論的Top-Nと全件アクセスを併用する

表示規模は、ゼロ度数・隔離セルを含むJSONの全セル数 `K` で区分する。既存Dashboardの30セル境界と上位25セルを踏まえ、次の表示方針に固定する。100セル境界は本Changeの表示設計値であり、性能保証や統計的な標本サイズ・重要性の閾値ではない。

| 表示規模 | セル数 | セル別表示 |
| --- | --- | --- |
| 小規模 | `K <= 30` | 全セル図と全件表 |
| 中規模 | `31 <= K <= 100` | スクロール・フィルタ可能な全件表を主表示とし、過密な全セル図を置き換える |
| 大規模 | `K >= 101` | 視座別のTop-25図とスクロール・フィルタ可能な全件表 |

Top-Nは `N = 25` とし、次の既存JSON値だけで選定する。全体効果量などセル単位でない表示には適用しない。

| 視座 | 選定順序 |
| --- | --- |
| Effect × Evidence | `abs(cells.log_oe)` の降順。証拠強度は別軸のまま表示する |
| Adjusted Residual Structure | `abs(cells.adj_res)` の降順 |
| Joint Posterior | `posterior.cell_posteriors.prob_mean` の降順（既存方針を維持） |
| Conditional Posterior | `cond_row_prob_median`、`cond_col_prob_median` の降順で、方向ごとに別選定 |
| Uncertainty Ranking | `posterior.uncertainty_ranking.rank` の昇順をそのまま使用し、順位を再計算しない |
| Posterior Departure from Independence | `abs(log_divergence_median)` の降順 |
| Prior Sensitivity | `posterior.sensitivity_analysis.cell_comparisons` の `median_shift` の降順 |

既存rank以外の同順位は `row_level`、`col_level` の順にUTF-8バイト順で昇順とし、境界の同順位を追加せず25セルに固定する。選定指標が欠落・非有限のセルは有限値の後ろに同じセルキー順で置き、値を補完せず算出不能等の状態を示す。隔離セルは選定対象から一律除外せず、隔離状態を区別する。表示用の絶対値・並べ替え以外に統計量を再計算しない。

各縮約図には選定指標・順序、表示セル数、非表示セル数 `K - N` を明記する。順位は当該指標による表示順であり、重要性・有意性の判定ではない。Cell Explorerは常に全件を保持し、各視座から全件表へ移動できるようにする。条件付き確率のTop-Nは条件付き分布全体ではないことも明示する。

Top-Nのみを表示する案は、選ばれなかったセルの監査可能性を失うため採用しない。

### オフライン性は二層で受入する

レンダリング後HTMLの文字列走査で外部URLと絶対パスを検出し、別途ネットワーク遮断相当のブラウザで主要操作を確認する。`self_contained: true` は設定であって受入証跡ではない。

### 先行Change（1 & 2）を不変前提とし、Dashboardでの再計算を排除する

Dashboardの実装開始前に、Change 1（`vcd-categorical-provenance-boundary-hardening`）の実行モード・署名契約、およびChange 2（`vcd-categorical-conditional-posterior-contract`）の条件付き事後要約Schema・serializer・fixtureが完了していることを確認する。
Section 11（Quality & Provenance）は、これらの先行成果物から `execution_mode: "canonical"`、三者SHA再検証状態、決定論的乱数シード、解析署名を描画する。Dashboard側で統計量の独自計算や再推論は一切行わず、JSON契約の純粋な可視化に専念する。

実行モード・シード・解析署名は `categorical_results.json` の既存 `provenance` ブロックから取得する。三者SHA再検証状態は、そのJSONと同じrunディレクトリの `run_state.json` にある `provenance_status` から取得し、`"verified"` を「検証済み」と表示する。`categorical_results.json` に検証状態のフィールドを追加せず、JSON Schemaやserializerの拡張は行わない。`run_state.json` または当該フィールドが欠落する場合は「未確認」と表示し、実行モードや署名の存在だけから「検証済み」と推測しない。Dashboard自身によるSHA再検証は行わない。


## Risks / Trade-offs

- [11セクションによる認知負荷] → 問いの明示、折り畳み可能な詳細、全件表との役割分離を行う。
- [大規模表で描画性能が低下] → しきい値に基づく図の抑制とTop-N、全件表への遅延的アクセスを組み合わせる。
- [外部依存が自己完結HTMLへ混入] → 静的走査とブラウザ確認を両方必須にする。
- [条件付き事後のSchemaが未確定] → 先行changeの完了前はDashboardコードを変更しない。

## Migration Plan

1. 条件付き事後changeの完了・検証後に、既存Dashboardの回帰fixtureを基準化する。
2. Quality & Provenance、Adjusted Residual、Conditional Posterior、Uncertainty、Departure、Sensitivityの順に追加する。
3. 各追加段階で、HTML静的走査、対象Rテスト、既存セクションの回帰を確認する。
4. 最終段階で大規模表fixtureとネットワーク遮断相当のブラウザ受入を行う。
5. 問題発生時は、最後に追加した視座とそのreader/testに限定して戻し、既存Dashboardの表示を維持する。
