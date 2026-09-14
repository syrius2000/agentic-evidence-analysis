# TODO: 分析パイプラインの強化と保守

4-Pass パイプラインと 3 次元探索正本経路（新 4 軸セル診断、総度数 $N$ 基準の明示式 BIC、大標本 Dual-Filter 原則、多項 Dirichlet 事後推論、完全オフラインHTMLダッシュボード）は実装・検証完了済みです。以下は受入後の保守運用項目および次期計画です。

## 受入後の運用・確認項目
- [x] **スモークテストの実行**: `tests/test_questionnaire_batch_smoke.R` 等を実行し、実行環境の健全性を確認。
- [x] **Titanic・HairEyeColor の全パス検証**: `output/statistical_foundations/verified_0906/` に検証記録を保存、QA-0001 にて Cycle 2 承認完了。
- [x] **3次元ダッシュボードの標準化と完全オフライン化**: KaTeX生成時数式レンダリング、DataTables日本語インライン化、M1/M5二基準診断、UCB標準版の確立（OpenSpec `standardize-three-way-dashboard` 完了）。
- [x] **講座利用者・実務ユーザーによる確認**: レポートの説明量、新 4 軸の用語（Effect, Evidence, Influence, Stability）、HTML 図表が受講者に直感的に理解できるか確認。

## 優先度の高い改善項目 (High Priority)
- [x] **JSON スキーマの導入と検証**:
  - `analysis_config.json` のバリデーション（`test_vcd_bayesian_config_validation.R`）を実装・検証済み。

## 中長期的な改善課題 (Backlog)
- [x] **堅牢なオフライン・フォントスタックの拡充**: `dashboard.Rmd` において外部通信を発生させず、あらゆるOS環境（Win/Mac/Linux）で文字化けしないシステムフォント・フォールバックを強化。
- [x] **実RWDの受入検証**: 実際の医療・購買データ 1 件を、標本単位・重複・分母・除外条件を確認してから Pass 0 で分析。
- [x] **セル順位の再標本化安定性評価（集計度数CRR）**: 3次元集計表に対し、基準モデル（M1/M5）・指標（`abs_log_oe`）・上位 K を固定し、多項再標本化と各反復での閉形式モデル再推定を実施。元データの `REGULAR` 適格セル集合に条件付けた上位 K 包含率、順位分布、MCSE、適合成功率（`valid_rate`）を `evidence_results.json` に保存（[条件付きセル順位再現性の実装](.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R)、[意味論とセル順位安定性の整備計画](docs/Archives/20260912_183500_002/sources/semantic_governance_and_ranking_stability_plan_001_0907.md) 準拠）。個票ブートストラップ、順位相関、Poisson再標本化、複数設定の一括評価は未実装。

## 次期開発予定（合意事項）
- [x] **SAS PROC FREQ 互換スキルの開発計画**: 集計済み度数データを必須入力とし、度数・割合・クロス集計・欠損処理の数値互換を担保（[計画書](docs/Archives/20260915_182000_004/sources/implementation_plan_017_0913.md) 確定済）。
- [x] **SAS PROC MEANS 互換スキルの開発計画**: FREQ 互換とは別スキルとして計画。要約統計量、欠損・重みの扱いを確定（[計画書](docs/Archives/20260915_182000_004/sources/implementation_plan_017_0913.md) 確定済）。
- [x] **OpenSpec への展開と実装**: 
  - [x] `add-sas-proc-means-skill`: 要件定義、実装、数値パリティテスト検証、OpenSpec delta spec 同期、アーカイブ完了。
  - [x] `add-sas-proc-freq-skill`: Change 起案・要件定義・実装・Stage 1 基礎受入テスト検証完了（全16タスク完了、アーカイブ可能）。
- [x] **統計仕様の検証**: 9 モデル、新 4 軸セル診断、Dirichlet 事後、Titanic・HairEyeColor・人工表の検証完了。旧 Evidence Score（$r^2 - k\ln N$）は監査専用列に隔離。
- [x] **統計文書の正本化と数理厳密化**: `docs/reference/` 配下を新 4 軸セル診断、明示式 BIC、大標本 Dual-Filter、多項 Dirichlet 推論（ETI）、バイアス低減 Bergsma 補正、一次情報（DOI付き）で全面刷新。

## 残課題・未実施問題：SAS 実機 Fixture による Stage 2 数値パリティ検証
`sas-proc-means` および `sas-proc-freq` の 2 スキルは、「Stage 1: 数式・手計算参照値・境界値・独立実装に基づく基礎受入」を完了し、各単体テストスイートで全件合格を達成しています。しかし、**SAS 実機環境（SAS 9.4 / SAS Viya 等）から抽出した公式参照出力（golden fixture）が未提供であるため、Stage 2 の実機完全パリティ検証は未実施（保留）** となっています（成果物メタデータは規約に基づき `sas_parity: "unverified"` を保持）。

- [ ] **SAS 実機 fixture の調達・生成**:
  - **環境記録**: SAS バージョン、リリース、メンテナンスレベル、実行 OS、ロケール、エンコーディング。
  - **採取対象 (PROC MEANS)**: 基本統計量（N, NMISS, MEAN, STD, VAR, USS, CSS, CV, STDERR, LCLM, UCLM, SKEWNESS, KURTOSIS）、CLASS 層別、VARDEF（DF, N, WDF, WEIGHT）、QNTLDEF（1〜5）、FREQ/WEIGHT 指定、EXCLNPWGT、MISSING オプション。ODS OUTPUT で `BEST32.` または 16 桁浮動小数で出力。
  - **採取対象 (PROC FREQ)**: 1元表、2元表、層別2元表、欠損モード（exclude, missprint, include）、独立性検定（Pearson, LR, 連続性補正）、効果量（OR, RR1, RR2 と各 Wald CI）、二項割合（Wald, Clopper-Pearson, Wilson）、Fisher 正確検定（2×2 および 一般表ネットワーク法）、Monte Carlo 推定（Seed・反復数・SE・端点区間）。ODS OUTPUT で丸め前数値を採取。
- [ ] **SAS PROC MEANS の Stage 2 実機パリティ検証 (`--stage=parity`)**:
  - `tests/fixtures/sas_proc_means_parity.json` を配置し、`Rscript tests/test_sas_proc_means_numerical_parity.R --stage=parity` を実行。
  - 決定論的統計量の許容誤差基準（$|R - \mathrm{SAS}| \le 10^{-12} + 10^{-10}|\mathrm{SAS}|$）を満たすことを確認し、成果物メタデータの `sas_parity` を `"verified"` へ昇格。
- [ ] **SAS PROC FREQ の Stage 2 実機パリティ検証 (`--stage=parity`)**:
  - `tests/fixtures/sas_proc_freq_parity.json` を配置し、`Rscript tests/test_sas_proc_freq_numerical_parity.R --stage=parity` を実行。
  - 独立性検定・効果量・信頼区間・Fisher P 値の一致、および Monte Carlo 要約（Patefield アルゴリズム）の挙動一致を確認し、`sas_parity` を `"verified"` へ昇格。
