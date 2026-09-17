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

セル数に応じて、全セル図、スクロール・フィルタ可能表、Top-N図を切り替える。Top-Nの順序、同順位、閾値、非表示件数を明記し、常に全件表またはCSVへの導線を残す。

Top-Nのみを表示する案は、選ばれなかったセルの監査可能性を失うため採用しない。

### オフライン性は二層で受入する

レンダリング後HTMLの文字列走査で外部URLと絶対パスを検出し、別途ネットワーク遮断相当のブラウザで主要操作を確認する。`self_contained: true` は設定であって受入証跡ではない。

### 先行Change（1 & 2）を不変前提とし、Dashboardでの再計算を排除する

Dashboardの実装開始前に、Change 1（`vcd-categorical-provenance-boundary-hardening`）の実行モード・署名契約、およびChange 2（`vcd-categorical-conditional-posterior-contract`）の条件付き事後要約Schema・serializer・fixtureが完了していることを確認する。
Section 11（Quality & Provenance）は、これらの先行成果物から `execution_mode: "canonical"`、三者SHA再検証状態、決定論的乱数シード、解析署名を描画する。Dashboard側で統計量の独自計算や再推論は一切行わず、JSON契約の純粋な可視化に専念する。


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
