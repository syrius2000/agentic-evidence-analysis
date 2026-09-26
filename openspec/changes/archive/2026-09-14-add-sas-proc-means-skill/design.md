## Context

モチベーションと目的の詳細は [proposal.md](proposal.md) を参照。
本設計は、SAS PROC MEANS の記述統計量、CLASS群化、欠損除外、FREQ/WEIGHT文規則、分散定義（VARDEF）、分位数補間（QNTLDEF 1〜5）について、R環境（base R / stats）を用いて対象限定・参照環境明示・許容誤差付きの数値互換を提供する独立スキル `.agents/skills/sas-proc-means` のアーキテクチャおよび技術的決定を規定する。

## Goals / Non-Goals

**Goals:**

- `.agents/skills/sas-proc-means` の独立スキルディレクトリ構造（`SKILL.md`, `schemas/`, `templates/`）の確立。
- 数値分析変数、CLASS変数、FREQ変数、WEIGHT変数を扱う入力前処理および除外ロジックの実装。
- 基本記述統計量（N, NMISS, SUM, SUMWGT, MEAN, MIN, MAX, RANGE, CSS, USS, VAR, STD, CV）の計算。
- 4つの VARDEF（DF: $n-1$、N: $n$、WDF: $W-1$、WEIGHT: $W$）の厳密な分母計算。
- 平均標準誤差 STDERR および平均 $t$ 信頼区間（LCLM/UCLM）の計算（VARDEF=DF のみ有効、他は未定義）。
- 歪度・尖度の SAS 制約（WEIGHT指定時は未定義、VARDEF=DF および N での非重み付き計算）。
- 分位数（QMETHOD=OS）: 重みなし QNTLDEF 1〜5（1=R4, 2=R3, 3=R1, 4=R6, 5=R2）および WEIGHT 指定時の累積重み分位数の実装。
- CLASS変数の層別集計および欠損群制御（既定除外、`class_missing: true` で保持）。
- **3点セットの出力成果物の生成**:
  1. 構造化JSON（`means_results.json`）: 機械可読・正本・全統計量・未定義理由コード
  2. CSV（`summary.csv`）: SAS ODS Summary / OUT=データセットに対応した表形式データ
  3. 日本語Markdownレポート（`summary_report.md`）: 群別要約表、設定パラメータ、適用制約をまとめた監査用レポート
- Run隔離ディレクトリ（`<output_dir>/run_<first16_run_id>/`）への `analysis_config.json`（設定写し）および `manifest.json`（入力/出力SHA-256、JSTタイムスタンプ、R環境）の同梱。
- 数値パリティ検証テストスイートの整備。

**Non-Goals:**

- QMETHOD=P2（近似分位数アルゴリズム）。
- 特殊欠損値（.A〜.Z）や SAS FORMAT 群化の全再現。
- 重み付き分散分析プロシジャとしての拡張や IPW 頑健分散推定。
- 既存の 3-way 分析パイプラインへの統合（別Changeで実施）。
- **ビット単位一致の非保証**: 浮動小数点演算順序やアーキテクチャ差による最下位ビット差を許容し、ビット完全一致は保証しない。
- **全SAS構文・全ODS画面再現の対象外**: 明示された対象機能のみの限定互換とし、全ステートメント・全画面再現は対象外とする。
- **規制提出適格性の非主張**: 規制当局（FDA/PMDA等）への申請・提出資料としてのバリデーション適格性は主張しない。

## Decisions

### 1. 設定管理とインターフェース

- 単一の `analysis_config.json` を設定正本とし、`schema_version: "sas-summary-config-v1"` および `analysis_kind: "sas_proc_means"` を定義する。
- 分析変数群（`analysis_variables`）、CLASS変数群（`class_variables`）、FREQ/WEIGHT変数名、VARDEF、QNTLDEF 等を明確に指定可能とする。

### 2. FREQ と WEIGHT の数理・除外処理

- FREQ は行頻度であり、小数部は切り捨て（floor）、1未満およびNA行は計算から除外する。
- WEIGHT は観測重みであり、小数を許容する。既定では負値を 0 として扱い、欠損重みを除外し、0 重み行は観測度数 $N$ に算入する。`exclnpwgt: true` の場合は非正重み行を観測度数 $N$ からも除外する。
- メモリ保護のため、巨大な個票展開配列は作成せず、重み付き・頻度付きの累積集計アルゴリズムを採用する。

### 3. モーメント・分散・平均区間の数理計算

- 有効観測集合において $n = \sum f_i$、$W = \sum f_i w_i$、加重平均 $\bar{x} = \sum f_i w_i x_i / W$、修正平方和 $CSS = \sum f_i w_i (x_i - \bar{x})^2$ を算出する。
- 分散分母 $d$ を VARDEF に応じて分岐（DF: $n-1$、N: $n$、WDF: $W-1$、WEIGHT: $W$）し、$VAR = CSS/d$, $STD = \sqrt{VAR}$ とする。
- VARDEF=DF の場合のみ $STDERR = STD/\sqrt{W}$ および $t$ 信頼区間 $\bar{x} \pm t_{1-\alpha/2, n-1} STDERR$ を算出し、それ以外の VARDEF では null（`status_reason: "undefined_for_vardef"`）とする。

### 4. 形状統計量の制約

- WEIGHT変数が指定された場合は、重み付き歪度・尖度を算出せず null（`status_reason: "not_available_with_weight"`）とする。
- WEIGHT未指定時は、VARDEF=DF（標本不偏推定量）および VARDEF=N（母集団モーメント）の定義に従い、$n \ge 3$（歪度）、$n \ge 4$（尖度）をチェックして計算する。

### 5. 分位数（QNTLDEF 1〜5）の実装

- 重みなしデータでは、R の `stats::quantile()` の type パラメータとの照合関係（QNTLDEF 1=type 4, 2=type 3, 3=type 1, 4=type 6, 5=type 2）を利用する。
- WEIGHT指定データでは、累積重み $W_j = \sum_{i=1}^j w_{(i)}$ に基づく専用の累積重みステップ関数分位数ロジックを実装し、QNTLDEF 1〜5 いずれの指定時にも累積重み経路を適用する（定義5相当の境界平均化、他定義でも安全に有限値を算出）。

### 6. 出力層アーキテクチャ（3点セット成果物とRun隔離）

- 出力は完全隔離された `<output_dir>/run_<first16_run_id>/` 配下に配置する。
- **① 構造化JSON (`means_results.json`)**:
  - メタデータ（`analysis_kind`, `timestamp_jst`, `input_hash`, `vardef`, `qntldef`）
  - 群別・変数ごとの統計量オブジェクト（N, NMISS, MEAN, STD, STDERR, LCLM, UCLM, 分位数等）
  - 未定義理由コード（`status_reason`: `undefined_for_vardef`, `not_available_with_weight`, `zero_variance`）
  - `NaN`, `Inf` は JSON 仕様に基づき `null` に置換
- **② CSV (`summary.csv`)**:
  - SAS の `PROC MEANS ... OUT=summary;` や ODS Summary に対応するフラットな表形式。
  - 列構成: `class_group, variable, _TYPE_, _FREQ_, N, NMISS, SUMWGT, MEAN, STD, MIN, MAX, MEDIAN, LCLM, UCLM`（※Rでの読み込み時は `check.names = FALSE` で `_TYPE_`, `_FREQ_` 列名が維持される）。
- **③ 日本語Markdownレポート (`summary_report.md`)**:
  - 人間可読の要約文書。入力データ概要、設定一覧、群別要約統計量テーブル、適用制約・注記を記載。
- **④ 実行メタデータ**:
  - `analysis_config.json`（入力設定の完全な写し）
  - `manifest.json`（入出力ハッシュ、タイムスタンプJST、Rバージョン情報）

### 7. 数値パリティ検証と許容誤差契約

- **参照SAS環境**: 照合先SAS環境として SAS 9.4 on Linux/Windows を明示的基準とする。
- **統計量クラス別の許容誤差方針**:
  - **度数・完全一致クラス**: 観測度数 $N$、欠損数 NMISS、分位数（QNTLDEF 1〜5）、中央値 MEDIAN は、整数一致または離散順序統計量として完全一致（差分 0）を要求する。
  - **決定論的連続統計量クラス**: SUM, SUMWGT, MEAN, MIN, MAX, RANGE, CSS, USS, VAR, STD, CV, STDERR, LCLM, UCLM, SKEWNESS, KURTOSIS については、絶対誤差 $\text{atol} \le 10^{-12}$ または 相対誤差 $\text{rtol} \le 10^{-10}$ を合否判定の閾値とする。
- **fixture優先規則**:
  - 実機SAS出力から取得した実測データセットを最優先のテスト fixture とする。
  - 実機未取得の項目・組み合わせについては数理定義値による参照値を使用し、テストスイートおよびメタデータ上で `sas_parity: "unverified"` と表記して区別する。tasks 5.5 は本契約に基づいてテストを構築・実行する。

## Risks / Trade-offs

- **[浮動小数点演算による累積重み境界の判定誤差]** → 浮動小数点の丸め誤差に対処するため、判定時に微小許容誤差（イプシロン）を適用する。
- **[極端な小標本（n < 4）でのモーメント破綻]** → 標本数境界ガードを設け、ゼロ除算や負の自由度を防ぎ安全に null を返す。
