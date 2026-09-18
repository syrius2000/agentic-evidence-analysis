## 背景

現行の二元分割表分析はDirichlet事後から条件付き確率を計算するが、`P(B|A)` と `P(A|B)` は平均と標準偏差までしか成果物へ出力しない。中央値、95%等裾信用区間（ETI）、区間幅、および要約統計量の数理的に正しい不変量をInterface契約として固定しない限り、下流のDashboardは推定の不確実性を一貫して表示できない。

また、安全性評価やRWD分析において稀少事象・疎セルを扱う際、現行の主解析である一様事前分布（Bayes-Laplace: $\alpha = 1.0$）は全セルへ仮想度数を均等付与するため、疎セルへの平滑化量が大きくなる。多項分布モデルにおいてフィッシャー情報行列式 $|I(\boldsymbol{\pi})|^{1/2} \propto \prod \pi_k^{-1/2}$ から導出される多項 Jeffreys 事前分布（$\alpha = 0.5$）は、パラメータ変換不変性（Invariance under reparameterization）を備え、疎セルに対する仮想度数が一様事前より小さい。本Changeではこの再パラメータ化不変性を根拠として主解析事前（$\alpha = 0.5$）として採用し、対照感度分析を一様事前（$\alpha = 1.0$）として再構成する。この主事前変更はスキーマ上は加法的互換であるが、事後平均やETI等の数値的意味を変える「統計的意味論における非後方互換な変更」である。

さらに、成果物をディスクへ書き出す serializer は canonical 実行専用とし、development 実行はインメモリ計算パスに限定して成果物ファイルを生成しない境界を確定する。

## 変更内容

- 主解析を対称 Dirichlet の多項 Jeffreys 事前分布（$\alpha = 0.5$）、対照感度分析を一様事前分布（$\alpha = 1.0$）として定義し、成果物に `posterior.prior_specification`（family, alpha, role, name）を記録して自己記述性を担保する。
- 条件付き事後確率の両方向について、平均、標準偏差、中央値、q025、q975、ETI幅を、丸め前のMonte Carlo drawから算出する。
- `practical_delta` の estimand を「絶対結合確率乖離の閾値超過確率 $P(|\pi_{ij} - \pi_{i+}\pi_{+j}| > \delta \mid \text{data})$」として確定し、有効範囲（$0 < \delta < 1$）外の不正値は fail-fast、未指定時は `null` 出力とする。
- draw単位の総和（1.0）、条件付き事後平均の総和（1.0、丸め前許容差 `1e-12`）、確率範囲、分位点順序、ETI幅を数理エンジン内部で検証し、中央値および分位点の総和を1へ強制しない。
- 成果物書き出しを行う `serializer_v3.R` は canonical 実行専用（`execution_mode = "canonical"` のみ受入）とし、丸め済み値に対する許容差（水準数 $\times 10^{-6}$）で最終整合性を検証する。
- 事前感度分析における二値判定フラグ `is_sensitive` および `0.05` 閾値警告を廃止し、客観的シフト量（符号付き `eti_width_difference = sensitivity - primary` 等）のみを出力する。
- 先行Change 1から引き継いだ `execution_mode: "canonical"` を `serializer_v3.R` の `provenance` ブロックへ記録・検証し、canonical 成果物として `analysis_signature`、`input_sha256`、`config_sha256` の必須性を保証する。
- 代表的な小規模・中規模表で計算が完了することを確認し、観測した実行時間とメモリ上の注意を検証記録に残す（新規の実行時上限や fail-fast 機構の導入は本 Change 対象外）。

## 能力

### 新規能力

なし。

### 変更する能力

- `two-way-evidence-analysis`: Dirichlet事後推論、結果JSON、および成果物間不変量に条件付き事後の完全な要約・数理契約を追加し、canonical 専用 serializer 境界および主事前自己記述メタデータを同期する。

## 影響範囲

- `.agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R`
- `.agents/skills/vcd-categorical-analysis/R/serializer_v3.R`
- `.agents/skills/vcd-categorical-analysis/schemas/categorical_results_v3.json`
- `.agents/skills/vcd-categorical-analysis/templates/analysis.R`（canonical 設定ハッシュ・署名照合の主事前 alpha=0.5 呼出し整合）
- 必要なCSV出力、Interface reference、root tests、対象限定fixture
- 新規Rパッケージ、実データ、CLI Provenance境界構造の変更（Change 1で確定済み）、Pass 0 共有契約の改定、Dashboardレイアウト（Change 3で実施）、commit、pushは対象外
