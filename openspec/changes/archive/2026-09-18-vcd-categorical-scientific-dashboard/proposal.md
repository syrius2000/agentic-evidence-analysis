## 背景

現行Dashboardには既存の残差・セル表・周辺事後表示があるが、Effect、頻度論的局所逸脱、条件付き予測確率、不確実性、独立性からの事後乖離、事前感度が別の問いであることを画面構造として十分に分離できていない。統計量の意味を混同せず、完全オフラインで確認可能なScientific Dashboardを完成させる必要がある。本改修は、先行するChange 1（`vcd-categorical-provenance-boundary-hardening`）の実行モード・provenance契約、およびChange 2（`vcd-categorical-conditional-posterior-contract`）の条件付き事後JSON契約が確定・完了していることを前提として着手する。

## 変更内容

- Adjusted Residual、Conditional Posterior、Uncertainty Ranking、Posterior Departure、Prior Sensitivityの5視座を追加し、既存セクションと合わせた11セクション構成を実現する。
- 各視座に、日本語の科学的問い、主指標、解釈上の限界、自動的な有意・重要判定を行わない旨を表示する。
- 小規模・中規模・大規模の表で、全セル表示、フィルタ可能表、決定論的Top-Nと全件アクセスを使い分ける規則を定める。
- Section 11（Quality & Provenance）において、先行Change 1/2で確定した `execution_mode`（`"canonical"`）、Pass 0三者SHA検証ステータス、決定論的乱数シード、解析署名を完全表示する。
- `self_contained` 指定だけに依存せず、生成HTMLの外部URL・絶対パス静的走査と、ネットワーク遮断相当のブラウザ検証を受入条件とする。
- Dashboard側での統計量の独自再計算を禁止し、成果物JSON契約の完全な消費者（Consumer）として振る舞う。

## 能力

### 新規能力

なし。

### 変更する能力

- `two-way-evidence-analysis`: 完全オフラインScientific Dashboardの構成、各統計視座の表示責務、大規模表フォールバック、機械的なHTML受入検査を具体化する。

## 影響範囲

- `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`
- Dashboard生成・読込に直接必要な最小限のR serializerまたはreference
- `tests/test_vcd_categorical_dashboard_v4.R` と対象限定のHTML・fixtureテスト
- ブラウザ確認用の検証資産
- 条件付き事後計算（Change 2で完了）、CLI Provenance境界（Change 1で完了）、Rパッケージ追加、実データ、公開成果物、commit、pushは対象外

