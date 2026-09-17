## MODIFIED Requirements

### Requirement: 完全オフライン Scientific Dashboard の生成と機械的受入検査

システムは、外部CDN、リモートウェブフォント、外部スクリプトへの依存を一切排除した完全自己完結型HTMLとしてScientific Dashboardを生成しなければならない（MUST）。Dashboardは、Effect、頻度論的局所逸脱、条件付き事後、不確実性、独立性からの事後乖離、事前感度が異なる問いであることを明示しなければならない。生成HTMLに対しては、外部URL/CDNおよび絶対ローカルパスの混入を機械的に検出・拒否する静的検査を実施しなければならない。

#### Scenario: 11セクションの統計的責務分離

- **WHEN** 2次元名義分割表のDashboardを生成する
- **THEN** Executive Summary、Global Association & Effect Size、Effect × Evidence、Adjusted Residual Structure、Cell Explorer、Joint Posterior、Conditional Posterior、Uncertainty Ranking、Posterior Departure from Independence、Prior Sensitivity、Quality & Provenanceを表示し、各新規視座の先頭に日本語で「この図が答える統計的・科学的問い」と解釈上の限界を表示する。Section 11（Quality & Provenance）には先行Change 1/2で確定した `execution_mode: "canonical"`、三者SHA再検証状態、決定論的乱数シード、解析署名を表示する

#### Scenario: 条件付き事後を予測確率として表示する

- **WHEN** 条件付き事後要約を含む結果をDashboardへ読み込む
- **THEN** `P(B|A)` と `P(A|B)` を区別して表示し、中央値と95% ETIを主表示、平均を補助表示として、条件付き中央値・分位点の総和を1と解釈してはならない旨を明示する

#### Scenario: 局所診断・不確実性・乖離・感度の解釈を分離する

- **WHEN** Adjusted Residual、Uncertainty Ranking、Posterior Departure、Prior Sensitivityを表示する
- **THEN** adjusted residualを効果量そのものとして表示せず、ETI幅を重要性または有意性として表示せず、対数乖離の区間が0をまたぐかだけで自動二値判定をせず、alpha=1.0と0.5の差をモデル誤りの自動判定として表示しない

#### Scenario: 表サイズに応じた全件アクセス可能なフォールバック

- **WHEN** カテゴリ数またはセル数が表示閾値を超える表をDashboardに表示する
- **THEN** システムは決定論的な選定規則によるTop-N表示を用いても、選定規則・非表示セル数を表示し、フィルタ可能な全件表または全件CSVへの導線を提供する

#### Scenario: 生成 HTML に対する外部リソース混入の静的スキャン

- **WHEN** Dashboard HTMLがレンダリングされる
- **THEN** HTMLソース内の `script src`, `link href`, `<img> src`, iframe, CSS `url(...)`, `fetch()`, `XMLHttpRequest` において、外部通信プロトコル（`http:`, `https:`, ネットワークスキーム `//`）、およびOSローカル絶対パス（`/Users/`, `/home/`, `/private/var/`, Windowsドライブ形式 `^[A-Za-z]:`）が存在しないことを静的検査し、検出時は受入テストを失敗させる


#### Scenario: ダッシュボードのオフライン閲覧とコンポーネント構造

- **WHEN** インターネット非接続環境で生成されたDashboard HTMLを開く
- **THEN** CSS、JS、数式表示、日本語のデータテーブルが外部通信なしに描画され、主要図表・全件表・大規模表フォールバックが閲覧でき、数式または拡張機能が使えない場合は日本語で読める代替説明を表示する
