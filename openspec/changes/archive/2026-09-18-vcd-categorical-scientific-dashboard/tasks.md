## 1. 先行契約と既存Dashboardの固定

- [x] 1.1 先行する Change 1（`vcd-categorical-provenance-boundary-hardening` の Canonical provenance / run-state 受入完了）および Change 2（`vcd-categorical-conditional-posterior-contract` の Schema・serializer・fixture 完了）の両方が受入完了していることを確認し、条件付き事後や局所乖離をDashboard側で再計算しないことをレビューで検証する
- [x] 1.2 既存Dashboardの生成手順、読込JSON、既存セクション、回帰fixtureを棚卸しし、変更前の対象テスト結果とHTML基準を記録する

## 2. 視座別Dashboardの実装

- [x] 2.1 Section 11（Quality & Provenance）を更新し、先行Change 1/2から引き継いだ実行モード（`execution_mode: "canonical"`）、Pass 0三者SHA再検証状態、解析署名、決定論的乱数シード、Monte Carloドロー数、隔離セル数を漏れなく表示する。検証状態は同じrunの `run_state.json.provenance_status` から読み、`verified` とファイル・フィールド欠落時の「未確認」を読込テストで確認する。Schema・serializerの拡張やDashboardでのSHA再検証は行わない
- [x] 2.2 Section 4（Adjusted Residual Structure）を追加し、0中心の正負表現、隔離セルの区別、数値確認手段、および「効果量ではない」説明をテストする
- [x] 2.3 Section 7（Conditional Posterior）を追加し、`P(B|A)` と `P(A|B)` を別表示で、中央値・95% ETI・平均補助表示・総和誤解防止の説明とともに検証する
- [x] 2.4 Uncertainty Ranking、Posterior Departure、Prior Sensitivityを追加し、それぞれの主指標・参照線・非自動判定説明が存在することを静的テストと生成HTMLで検証する

## 3. 表サイズとオフライン受入

- [x] 3.1 [design.md](design.md) の表示規則（小規模30セル以下・中規模31〜100セル・大規模101セル以上、Top-25、視座別指標、同順位・非有限値の扱い）を実装する。30/31・100/101セルの境界、同順位でも25セルに固定されること、非表示セル数、全件表への導線をfixtureで確認し、大規模表でも隔離セルを含む全件へアクセスできることを検証する
- [x] 3.2 生成HTMLを構文的・属性限定で静的走査し、`script src`, `link href`, `<img> src`, iframe, CSS `url(...)`, `fetch()`, `XMLHttpRequest` における外部プロトコル（`http:`, `https:`, ネットワークスキーム `//`）、およびOSローカル絶対パス（`/Users/`, `/home/`, `/private/var/`, `^[A-Za-z]:`）が存在しないことを検証する
- [x] 3.3 ネットワーク遮断相当のブラウザ環境（Playwright/Headlessまたは隔離プロファイル）で主要図表、全件表、日本語表示、数式代替説明、大規模表表示を確認し、証跡ログを記録する

## 4. 統合検証と独立QA

- [x] 4.1 `tests/test_vcd_categorical_dashboard_v4.R` と関連するDashboard・Interface・run isolationテストを個別プロセスで実行し、既存セクションの回帰がないことを確認する
- [x] 4.2 生成物、OpenSpecの要求、実差分、テスト証跡、HTML受入証跡を独立に突合し、構文検証・静的テスト・実行証跡・独立QAを分けて報告する
- [x] 4.3 `git diff --check` と対象外変更の不在を確認し、commit、push、archiveを行わずに実装結果を引き渡す
