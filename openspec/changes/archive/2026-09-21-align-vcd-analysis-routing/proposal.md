## Why

現行の `vcd-categorical-analysis` は2次元専用であり、3次元以上の解析は `vcd-bayesian-evidence-analysis` が正本である。この責務境界自体は妥当だが、旧 `report.Rmd` に3次元モザイク図の分岐が残り、現行 `dashboard.Rmd` および3次元正本への導線と混同される可能性があるため、利用者が解析スキルと可視化経路を誤選択しない契約へ整理する。

## What Changes

- `vcd-categorical-analysis` を2次元名義カテゴリ解析専用として明文化し、3次元以上は `vcd-bayesian-evidence-analysis` へ委譲する導線を統一する。
- 現行テンプレートを `dashboard.Rmd` とし、`report.Rmd` はレガシー互換資産であることを明示する。
- モザイク図を現行の主表示・必須成果物から外し、残差、estimand、不確実性、層別構造を中心とした可視化へ置き換える。
- 2次元の主残差表示には、行・列周辺の推定影響を調整したHaberman型の調整標準化残差を用い、期待度数、レバレッジ、Quarantine状態と併記する。
- 3次元可視化では、単純な周辺association plotを主表示にせず、Facet残差マトリクス、条件付き割合図、サブグループ効果量図を正本スキル側の契約として整理する。
- 3次元の交互作用はFacet残差だけで断定せず、M1〜M9等のモデル比較、逸脱度、BIC、効果量と対応づける。
- 仕様・設計・テスト項目を、現行canonical入口とレガシー資産の区別に合わせて更新する。

## Capabilities

### New Capabilities

- なし

### Modified Capabilities

- `two-way-evidence-analysis`: 2次元専用の入力境界、現行ダッシュボード入口、調整標準化残差の主表示、3次元スキルへの委譲、およびレガシー `report.Rmd` の非正本扱いを明確化する。
- `three-way-dashboard-reporting`: 3次元のFacet残差マトリクス、条件付き割合図、サブグループ効果量図、モデル比較の役割と、2次元スキルからの導線を明確化する。

## Impact

- 対象: `.agents/skills/vcd-categorical-analysis/`、`.agents/skills/vcd-bayesian-evidence-analysis/`、`docs/reference/`、該当するOpenSpec仕様・テスト。
- 既存の2次元統計計算、3次元モデル計算、結果JSONの数理定義は変更しない。
- 外部依存関係、入力データ形式、実行時インストール方針は変更しない。
- レガシー資産を直ちに削除せず、現行経路との混同を防ぐ注記と検証を優先する。
