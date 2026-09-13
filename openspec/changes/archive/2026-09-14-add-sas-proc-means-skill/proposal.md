## Why

製薬・RWD解析の実務において、SAS PROC MEANS で算出される要約帳票・記述統計量と厳密に同一基準での数値照合が不可欠となる。連続変数の記述統計量、CLASS群化、欠損処理、FREQ/WEIGHT規則、分散定義（VARDEF）、分位数補間（QNTLDEF 1〜5）について、SAS仕様に準拠した対象限定・許容誤差付きの数値互換を提供する独立スキル `.agents/skills/sas-proc-means` を導入する。

## What Changes

- **独立スキルの創設**: `.agents/skills/sas-proc-means` を新設し、専用の `SKILL.md`、設定スキーマ、Rエンジンテンプレートを配置。
- **入力および除外契約**:
  - 数値分析変数、CLASS変数、および FREQ/WEIGHT 変数を含むデータフレームを入力とする。
  - FREQ文規則（小数部切り捨て、1未満・欠損の除外、未指定時は1）。
  - WEIGHT文規則（既定では負値を0扱い・0重み行をNに算入・欠損除外、`EXCLNPWGT` 指定時は非正重みを除外）。
  - CLASS欠損の制御（既定除外、MISSING指定で群として保持）。
- **基本統計量と分散定義（VARDEF）**:
  - N、NMISS、SUM、SUMWGT（$W$）、MEAN（$\bar{x}$）、MIN、MAX、RANGE、CSS、USS、VAR、STD、CV の計算。
  - 4つの分散分母 VARDEF（DF: $n-1$、N: $n$、WDF: $W-1$、WEIGHT: $W$）の実装。
  - 平均標準誤差 STDERR（$STD/\sqrt{W}$）および平均 $t$ 信頼区間（LCLM/UCLM）の計算（VARDEF=DF のみ有効、他は未定義）。
- **形状統計量の適用制約**:
  - WEIGHT文指定時は歪度・尖度を未定義とするSAS制約の遵守。
  - VARDEF=DF および N における非重み付き歪度・超過尖度の厳密な計算。
- **分位数（QNTLDEF 1〜5）**:
  - 定義 1〜5（SAS既定5はR type=2、1はtype=4、2はtype=3、3はtype=1、4はtype=6）の対応。
  - メモリ効率的な累積度数展開による分位数計算、および WEIGHT 指定時の累積重み分位数計算。
- **3点セットの出力成果物とRun隔離**:
  - Run単位の隔離ディレクトリ配下に、①構造化JSON（`means_results.json`: 全統計量・未定義理由コードを含む正本）、②CSV（`summary.csv`: SAS ODS Summary / OUT=データセット相当の表形式データ）、③日本語Markdownレポート（`summary_report.md`: 群別要約表・設定パラメータ・適用制約を記載した監査用文書）を出力。
  - 実行設定の写し（`analysis_config.json`）および整合性メタデータ（`manifest.json`）を同梱。
- **検証とテスト**:
  - SAS参照値または数理定義値との照合テストスイート `tests/test_sas_proc_means_numerical_parity.R` を整備。

## Capabilities

### New Capabilities
- `sas-proc-means`: SAS PROC MEANS 対象限定互換スキルの入力契約、欠損処理、基本要約統計量、VARDEF 4分岐、FREQ/WEIGHT処理、歪度・尖度制約、分位数（QNTLDEF 1〜5）、および3点セット（JSON/CSV/Markdownレポート）の出力仕様を規定する。

### Modified Capabilities
<!-- なし。既存パイプラインの仕様変更はない。 -->

## Impact

- **新規ファイル**:
  - `openspec/specs/sas-proc-means/spec.md`
  - `.agents/skills/sas-proc-means/SKILL.md`
  - `.agents/skills/sas-proc-means/schemas/analysis_config.schema.json`
  - `.agents/skills/sas-proc-means/templates/run_means.R`
  - `tests/test_sas_proc_means_numerical_parity.R`
- **既存システムへの影響**:
  - 既存の 3-way 分析パイプラインや既存 specs への影響はなく、完全な独立拡張として動作する。

## Boundaries & Limitations (Non-Claims)

- **ビット単位一致の非保証**: 浮動小数点演算順序や実行環境（CPU/OS/Rバージョン）の差異に起因する最下位ビットの不一致は許容され、ビット単位の完全一致は保証しない。
- **全SAS構文・全ODS画面再現の対象外**: SAS PROC MEANS の全ステートメント・全オプション（例: QMETHOD=P2、SAS FORMAT による群化、特殊欠損値等）や全ODS出力の再現は行わず、明示された機能のみを対象とする限定互換である。
- **規制提出適格性の非主張**: 本スキルおよびその出力は研究・探索的データ解析を目的とするものであり、規制当局（FDA/PMDA等）への申請・提出資料としての適合性・バリデーション適格性を主張するものではない。
