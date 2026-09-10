# Angigravityへの3次元数理スキル統合計画

created: 2026-09-11 06:20 (JST)
update: 2026-09-11 06:27 (JST)
author: Codex (GPT-6)

## 目的

Phase 1で正本化した3次元分析の数理・状態・用語契約を、既存の`Angigravity`ブランチへ統合する。Angigravity側に既に存在するPass 0必須化、run可搬化、sealedライフサイクル、独自の検証証跡を保持し、同じ責務を二重実装しない。

## 対象範囲

- `vcd-bayesian-evidence-analysis` の3次元入口、4軸セル診断、M1〜M9、固定総度数BIC、旧指標の境界を統合する。
- `vcd-pass0-consultation` と共有品質契約を、3次元設定の由来・入力ハッシュ・Pass 0からPass 1への引継ぎに接続する。
- `analysis_config.schema.json`、`run_scope.R`、`run_handover.json`、実行metadataの相互整合を確認し、既存のAngigravity契約を壊さない範囲で不足を補う。
- 既存のOpenSpec、数理リファレンス、README、Skill文書、回帰テストを統合後の正本へ同期する。
- 変更対象とテスト結果を日本語Artifactへ記録し、Phase 3のDashboard UX変更は含めない。

## 非対象

- 統計計算式、Phase 1で確定した閾値、乱数、sealed済みrunの改変
- 英語化・多言語化、セル順位bootstrap、EBIC全面監査
- Angigravity以外のworktree、`main`、リモート履歴の変更
- force push、merge、rebase、既存利用者データの削除

## 実装方針

1. 作業開始時のAngigravityの差分、参照先、OpenSpec状態を固定する。
2. Phase 1コミットのうち、3次元数理契約と共有入口に必要な差分だけを比較し、Angigravity固有の実装を優先して手動統合する。
3. まずスキーマ・Pass 0 provenance・run scope・handoverの契約を確認し、次にBayesian Skillと参照文書・テストを同期する。
4. 失敗時に正式runやsealed成果物を生成・変更しない契約をテストする。
5. 数値不変性、Pass 0ゲート、run可搬性、スキル所有権、文書整合を検証する。

## 完了条件

- Angigravityの3次元スキル入口が、Phase 1の数理契約とPass 0必須順序を同時に示す。
- Pass 0由来の設定なし、由来ハッシュ不一致、入力改変、対象Skill不一致が計算前に拒否される。
- 3次元のM1〜M9、4軸診断、固定N BIC、状態語彙がAngigravityの出力契約と一致する。
- 既存のAngigravity固有テストとPhase 1由来の数理回帰テストが通過する。
- 既存差分、sealed run、外部worktreeを変更せず、差分・検証証跡・コミット対象を明示できる。

## 実装・検証結果

- `templates/three_way/` を配置し、`vcd-bayesian-evidence-analysis/SKILL.md` から3次元正本経路として接続した。
- `input.R` の検分JSONキーを `file_sha256` に対応させ、共有 `run_scope.R` の原子的run予約、portable config snapshot、v2.0 metadata、manifest、handoverを接続した。
- Titanic集計表で `VALID` → `COMPUTED` を確認し、run衝突時のsuffix分離、絶対パスを保存しない結果参照、manifest SHA-256を確認した。
- `test_math_hardening.R`、`test_section3_models.R`、`test_section4_ic_score.R`、`test_validate_config.R`、`test_pass0_contract.R`、`test_run_scope_guards.R` が合格した。
- Dashboard UX、多言語化、順位bootstrap、EBIC全面監査は未着手であり、Phase 3以降または別計画とする。

## コミット境界

実装と検証が完了した後、ユーザーから受けた明示許可の範囲で、Angigravityブランチに対象ファイルだけをコミットする。`origin/Angigravity`へのpushは、別の明示指示がない限り実施しない。
