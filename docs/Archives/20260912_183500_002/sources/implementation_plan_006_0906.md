# 3次元探索支援の検証修正とスキル統合

created: 2026-09-06 19:40 (JST)
update: 2026-09-06 19:40 (JST)
author: Codex (GPT-6)

## 承認と出発点

ユーザーの「実装してください。お願いします。」を、本リポジトリにおける検証修正から既存スキル・日本語考察・HTMLまでの実装指示として受領した。開始時は main、origin/main より1コミット先行、作業ツリーはクリーン。コミット・push・archiveは範囲外。

[前計画](implementation_plan_005_0906.md)と[OpenSpec](../../openspec/changes/validate-three-way-statistical-foundations/design.md)を継承する。参照する他AIの成果は[改定案](/Users/myamaguchi/Programing/00TotalRWD/agentic-evidence-analysis-antigravity/docs/Artifacts/statistical_foundation_refinement_plan_001_0906.md)、[検証試作](/Users/myamaguchi/Programing/00TotalRWD/agentic-evidence-analysis-antigravity/tests/statistical_foundations/)、[セル診断コメント](/Users/myamaguchi/Downloads/HairEyeColor_local_cell_diagnostics_redesign.md)。他worktreeは変更しない。

## 今回の実装と順序

1. 既存試作の独立参照計算を継承し、入力・集約・モデル・ベイズ・照合を修正する。解析用の正本を `.agents/skills/vcd-bayesian-evidence-analysis/templates/three_way/` に置き、テストから同じ正本を呼ぶ。独立参照は `tests/statistical_foundations/` に残す。
2. `3way-foundation-v1` 設定にPass 0の検分ファイルと合意理由を必須化する。入力ハッシュを照合する。度数は展開せず重複行を集約する。欠測は拒否・保留、未記載セルは明示した標本ゼロに限り補完。構造ゼロ・標本独立性未解決は保留。抽出は等値・集合包含のみ。
3. 9モデル、M1/M7/M8基準の局所診断、総度数による多項BIC、Dirichlet事後、目的変数の条件付き割合と層間差、事前感度を接続する。旧Scoreは監査列のみ。EBICは採用しない。厳密BFは明示事前の独立対飽和のみ。
4. Titanic原表・100倍表の2モード、HairEyeColor原表・100倍表、計画の人工3表と異常系をPass 0から検証する。GLM対IPF・閉形式、独立な小表BF参照、5MCSEと分位点CDF、非ゼロ終了、再現性を確認する。
5. 既存スキルに明示した3次元入口を加え、数値に追跡できる日本語AI考察と品質確認を要求する。独立したHTMLレンダラーに構造比較・セル全表・層別ヒートマップ・事後区間・限界を表示する。代表実例の考察を実際に作成して表示を確認する。
6. README、TODO、Pass 0、共有品質契約、AGENTSの誤解を招く統計規則を整合させ、実施証拠と未実施項目を日本語検証報告に残す。

## 数学的な採否と限界

固定したモデル・度数全体の倍率変更に対する構成比、log(O/E)、d/√N、ΔG²/Nの不変を確認する。ベイズでも標本サイズへの感度は残り、コピー100倍は新しい独立観測ではない。leverageを実際の影響度、境界・階数フラグを再標本化による安定性と呼ばない。

許容誤差は既存設計の絶対1e-8＋相対1e-6、平均5MCSE＋数値誤差、分位点CDFは5√(q(1−q)/S)＋1e-4。局所再適合の統計量とカイ二乗による漸近P値を区別する。小期待度数、非正則推定で近似推論を保留する。セル探索は多重性・選択後推論の保証をしない。

階層ベイズ、bootstrap安定性、実用差の自動閾値、FREQ/MEANS、全スキル一括移行、大量行性能保証は後続。旧2次元エンジンの計算互換性は維持し、新経路のJSONを旧rendererに渡さない。questionnaireの既存抽出処理の全面修正も後続とし、新経路の構造化抽出を先に提供する。

## 変更対象と受入

正本エンジン・schema・renderer・ガイドは上記スキル配下。検証コード・manifestは tests/statistical_foundations と tests/fixtures/statistical_foundations。スキル説明、README、TODO、AGENTS、共有品質契約、OpenSpec計画を更新する。元CSVは変更しない。実行出力は output/statistical_foundations 配下に隔離し上書きを拒否する。新規依存は追加しない。

合格は特定の有意化・モデル勝者ではなく、独立参照一致、誤入力の拒否、保留の伝播、倍率感度の正しい説明、セル・モデル・分母に追跡できる実例レポートで判定する。自動検証でAIの解釈の正しさを完全保証したとは扱わず、講座での最終利用者受入は残す。
