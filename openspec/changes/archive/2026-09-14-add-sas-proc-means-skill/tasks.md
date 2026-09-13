## 1. ディレクトリとスキーマ整備

- [x] 1.1 `.agents/skills/sas-proc-means` ディレクトリ構造（`SKILL.md`、`schemas/`、`templates/`）を作成し、初期ファイルが存在することを確認する
- [x] 1.2 `schemas/analysis_config.schema.json` を定義し、`schema_version: "sas-summary-config-v1"` および `analysis_kind: "sas_proc_means"` のバリデーションが機能することを確認する

## 2. 入力前処理とFREQ/WEIGHT処理エンジン

- [x] 2.1 FREQ変数の切り捨て・除外ロジック、および WEIGHT変数の既定処理（負値0扱い・N算入）と `exclnpwgt` 除外ロジックを実装し、単体テストで動作を検証する
- [x] 2.2 CLASS変数の群化および欠損値処理（既定除外、`class_missing: true` で保持）を実装し、群度数と分析変数N/NMISSの集計をテストで検証する

## 3. 基本記述統計量とVARDEF計算

- [x] 3.1 N、NMISS、SUM、SUMWGT（$W$）、MEAN（$\bar{x}$）、MIN、MAX、RANGE、CSS、USS の計算モジュールを実装し、テストケースで計算値の一致を確認する
- [x] 3.2 4つの分散分母 VARDEF（DF, N, WDF, WEIGHT）による VAR、STD、CV の分岐計算、および VARDEF=DF の STDERR と $t$ 信頼区間（LCLM/UCLM）を実装し、テストで検証する

## 4. 形状統計量と分位数計算

- [x] 4.1 WEIGHT指定時の歪度・尖度未定義化、および WEIGHT未指定時の VARDEF=DF/N に基づく歪度・尖度計算ロジックを実装し、制約動作をテストで確認する
- [x] 4.2 重みなし QNTLDEF 1〜5（1=R4, 2=R3, 3=R1, 4=R6, 5=R2）および WEIGHT指定時の累積重み分位数ロジックを実装し、テストで計算精度を検証する

## 5. 3点セット成果物出力と総合テスト

- [x] 5.1 構造化JSON（`means_results.json`）出力生成モジュールを実装し、全統計量および未定義理由コード（`status_reason`）の付与を確認する
- [x] 5.2 表形式CSV（`summary.csv`）出力生成モジュールを実装し、SAS ODS Summary 相当の列が出力されることを確認する
- [x] 5.3 日本語Markdownレポート（`summary_report.md`）生成モジュールを実装し、群別要約表・設定パラメータ・適用制約テーブルの描画を確認する
- [x] 5.4 Run隔離ディレクトリ配下への成果物（3点セット + `analysis_config.json` + `manifest.json`）の配置と整合性をテストで検証する
- [x] 5.5 数値検証テストスイート `tests/test_sas_proc_means_numerical_parity.R` を作成し、design.md / spec.md に規定された参照SAS環境（SAS 9.4）、統計量クラス別許容誤差契約（度数/分位数: 完全一致、連続統計量: $\text{atol} \le 10^{-12}$ または $\text{rtol} \le 10^{-10}$）、および fixture優先規則（実機SAS実測値優先、未取得項目は `sas_parity='unverified'` 表記）に基づき全テストケースが合格することを確認する
