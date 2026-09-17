## 背景

現行の二元分割表分析はDirichlet事後から条件付き確率を計算するが、`P(B|A)` と `P(A|B)` は平均と標準偏差までしか成果物へ出力しない。中央値、95%等裾信用区間（ETI）、区間幅、および要約統計量の数理的に正しい不変量をInterface契約として固定しない限り、下流のDashboardは推定の不確実性を一貫して表示できない。また、先行のChange 1（`vcd-categorical-provenance-boundary-hardening`）で確立された `execution_mode` 契約を成果物JSONのprovenanceへ正式に同期・永続化する必要がある。

## 変更内容

- 条件付き事後確率の両方向について、平均、標準偏差、中央値、q025、q975、ETI幅を、丸め前のMonte Carlo drawから算出する。
- draw単位の総和、条件付き事後平均の総和、確率範囲、分位点順序、ETI幅を検証する。
- 中央値および分位点の総和を1へ強制しない。これらは非線形な要約であり、一般に総和保存しない。
- Interface 3.0 / `two-way-results-v2` の加法的拡張として、serializer、JSON Schema、必要な表形式出力を整合させる。
- 先行Change 1から引き継いだ `execution_mode`（`"canonical"`）を `serializer_v3.R` の `provenance` ブロックへ追加・整合させる。
- 結合確率、対数乖離、alpha=0.5感度分析の既存統計量について回帰保護を追加する。

## 能力

### 新規能力

なし。

### 変更する能力

- `two-way-evidence-analysis`: Dirichlet事後推論、結果JSON、および成果物間不変量に条件付き事後の完全な要約・数理契約を追加し、provenanceブロックへの実行モード記録を同期する。

## 影響範囲

- `.agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R`
- `.agents/skills/vcd-categorical-analysis/R/serializer_v3.R`
- `.agents/skills/vcd-categorical-analysis/schemas/categorical_results_v3.json`
- 必要なCSV出力、Interface reference、root tests、対象限定fixture
- 新規Rパッケージ、実データ、CLI Provenance境界（Change 1で確定済み）、Dashboardレイアウト（Change 3で実施）、commit、pushは対象外

