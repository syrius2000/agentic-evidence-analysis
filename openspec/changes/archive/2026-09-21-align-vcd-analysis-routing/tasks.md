## 1. 責務境界と現行導線の整備

- [x] 1.1 `vcd-categorical-analysis` のSKILL・Reference・workflow・READMEの現行入口を `templates/dashboard.Rmd` として統一し、2次元専用・3次元委譲・Pass 0境界を明記した文書検査を追加する
- [x] 1.2 `templates/report.Rmd` と関連リファレンスに、v1.xレガシー資産・非canonical入口・3次元正本ではないことを明記し、現行利用者向け導線から誤って選択されないことを確認する
- [x] 1.3 既存の `INVALID_INPUT_ARITY` メッセージ、エラー説明、スキル責務リファレンスを同一の `vcd-bayesian-evidence-analysis` 委譲表現へそろえ、関連文書検索で旧導線が残っていないことを確認する

## 2. 残差・estimand・3次元可視化契約の明確化

- [x] 2.1 2次元Dashboardの主診断をHaberman型調整標準化残差へ整理し、期待度数、レバレッジ、ゼロ観測、小期待度数、Quarantine状態を併記する表示とその解釈注記を検査する
- [x] 2.2 `vcd-bayesian-evidence-analysis` のDashboard仕様・用語集・実行導線に、Facet残差マトリクス、条件付き割合ドット・区間図、サブグループ効果量Forest plot（明示的な効果量結果契約がある場合のみ）の役割と分母・因子対応を追加し、既存3次元仕様との重複・矛盾を検査する
- [x] 2.3 3次元のFacet残差を交互作用候補の探索に限定し、M1〜M9等のモデル比較、逸脱度、BIC、効果量による別評価を要求する仕様検査を追加する
- [x] 2.4 現行結果契約の条件付き割合についてestimand、比較対象、分母、CrIを表示し、RD/RR/ORは明示的な結果契約がない限り代用表示しないこと、頻度論的CIとベイズCrIを混同しないことを検査する
- [x] 2.5 モザイク図を現行canonicalの必須成果物・主表示から外し、残差・estimand・不確実性・層別構造を主表示とする導線を検査する

## 3. 検証と受入

- [x] 3.1 2次元入力のcanonical smoke・入力境界・Dashboard静的検査を実行し、既存の2次元結果契約とオフライン契約に回帰がないことを確認する
- [x] 3.2 UCB等の3次元fixtureでFacet残差、条件付きestimand、因子対応、完全オフラインHTMLを検査し、既存のM1〜M9・BIC・結果JSONを変更していないことを確認する
- [x] 3.3 `openspec validate align-vcd-analysis-routing --type change --strict`、対象テスト、`git diff --check` を実行し、仕様・実装・テストの導線が一致することを確認する
