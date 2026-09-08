# 統計基盤検証・本番スキル統合およびカテゴリカル分析実験アーカイブ

created: 2026-09-08 18:34 (JST)
update: 2026-09-08 18:34 (JST)
author: Codex (GPT-5)

対象期間: 2026-09-06 〜 2026-09-06

## アーカイブ概要

本書は、`docs/Artifacts/` に保存されていた統計基盤の計画、レビュー、検証報告、実験報告を1本へ集約した履歴文書である。対象文書はすべて2026年9月6日に作成または更新された過去成果であり、現在の実装計画として維持する必要がないため、本アーカイブへ統合した。

既存の過年度アーカイブは [archived_summary_001_0906.md](./archived_summary_001_0906.md) に保持する。現行のOpenSpec変更 `harden-run-path-handover` は、実装前の計画Artifactとしてリポジトリ内に残っている。

## アーカイブ元文書

1. `haireyecolor_scaling_experiment_report_001_0906.md`
2. `implementation_plan_005_0906.md`
3. `review_feedback_001_0906.md`
4. `statistical_foundation_refinement_plan_001_0906.md`
5. `statistical_foundation_skill_migration_plan_001_0906.md`
6. `statistical_foundation_skill_migration_report_001_0906.md`
7. `statistical_validation_001_0906.md`

## 統計基盤の検証・採否

3次元カテゴリカル分析について、Poisson GLM、反復比例適合、閉形式計算を用いた独立参照照合が行われた。9候補対数線形モデル、総度数Nを用いる明示式BIC、Leverage補正局所Score統計量、効果量・証拠量・影響度・安定性の4軸診断が採用方針として整理された。

一方、旧セルScore `r_i^2 - k log(N)` は大標本で証拠を過大に見せるため非推奨とされ、局所尤度比、Leverage補正Score、効果量を区別して扱う方針へ移行した。EBICおよび根拠未確認の局所BFは採用せず、検証済みの統計量と近似量を明示的に区別する。

レビューでは、MCSE基準の厳守、検証失敗時の非ゼロ終了コード、閉形式照合の総合合否への組み込み、厳密BFと条件付き事後量の独立検証、上側対数P値計算の安定化が修正事項として記録された。

## 本番スキルへの統合方針と検証結果

検証テストベッドと本番スキルの仕様乖離が、旧エビデンススコアの再出力を招いた原因として特定された。移行計画では、4軸セル診断、総度数N基準の明示式BIC、Dirichlet推論、設定・出力契約、ダッシュボード用JSONを本番スキルへ統合し、旧スコアをコード・説明・可視化から除去する方針が示された。

完了報告では、本番スキル、品質契約、規範文書、ダッシュボードへの統合と、Titanicの通常表および100倍拡大表による受入検証が報告された。大標本化によるP値・証拠量の増大と、`log(O/E)` やCramér's Vなど効果量の解釈を分離することが確認された。

## HairEyeColor スケール実験

`HairEyeColor` の32セル表について、総度数592と59,200の比較実験を行った。局所対数効果比は標本拡大前後で不変であり、安定セル率は大標本化で改善した。一方、BICモデル選択や証拠量は標本サイズの影響を受けるため、実質的効果量と統計的証拠を別軸で判断する必要がある。

実験結果は、人工的な度数拡大を独立観測の増加と解釈せず、標本サイズ感度の確認として説明するという運用原則を補強した。

## 次の現行作業との境界

本アーカイブは過去の統計基盤検証・統合履歴を保持するためのもので、次の現行作業を完了扱いにはしない。

- `harden-run-path-handover` のOpenSpec計画Artifactは、実装前の現行変更として `openspec/changes/` に残す。
- Run出力ライフサイクル、results manifest、staging promotion、sealed、supersede、Questionnaireの部分失敗、finalizer排他は、現行OpenSpecの承認・Apply・実装・検証の対象である。
- 既存の統計仕様と品質契約は [AGENTS.md](../../AGENTS.md) および [.agents/shared/analysis_quality_contract.md](../../.agents/shared/analysis_quality_contract.md) を参照する。

## アーカイブ時点の注意

本書は元文書の要点を統合した履歴であり、元文書に記載されたすべての数値表・長大な実行ログ・個別タスク一覧の代替ではない。現在の採否や実装完了状態を判断する場合は、現行OpenSpec Artifact、Git差分、テスト実行結果をあわせて確認する。
