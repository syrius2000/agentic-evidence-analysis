# sas-proc-means Specification

## Purpose

SAS PROC MEANS の明示された集計規則、CLASS群化、欠損処理、FREQ/WEIGHT文処理、分散定義（VARDEF）、分位数（QNTLDEF 1〜5）、および3点セット成果物（JSON/CSV/Markdownレポート）について、対象限定・参照環境明示・許容誤差付きの数値互換を提供する。

## Requirements

### Requirement: 入力データとFREQ/WEIGHT規則の遵守
システムは、数値分析変数、CLASS変数、FREQ変数、および WEIGHT 変数を含むデータを入力として受理しなければならない（MUST）。FREQ変数は小数部を切り捨て、1未満および欠損値を除外しなければならない（MUST）。WEIGHT変数は小数を許容し、既定では負値を0扱い・欠損を除外・0重み行を度数 $N$ に算入しなければならない（MUST）。また、`exclnpwgt: true` 指定時は非正重み（0以下）を除外しなければならない（MUST）。

#### Scenario: FREQ変数の小数切り捨てと除外
- **WHEN** FREQ列に正の小数（例: 2.7）や1未満（例: 0.5）、欠損が含まれる
- **THEN** 2.7は2として整数化し、1未満および欠損行は除外して集計を行う

#### Scenario: WEIGHT変数の既定処理とEXCLNPWGT
- **WHEN** WEIGHT列に負値またはゼロが含まれ、`exclnpwgt` が false（既定）である
- **THEN** 負値を0として扱い、観測度数 $N$ には算入し、重み合計 $W$ は非負重みのみで計算する

### Requirement: 分散定義（VARDEF）と基本要約統計量
システムは、N、NMISS、SUM、SUMWGT（$W$）、MEAN（$\bar{x}$）、MIN、MAX、RANGE、CSS、USS、VAR、STD、CV を計算しなければならない（MUST）。分散の分母 $d$ を決定する4つの VARDEF（DF: $n-1$、N: $n$、WDF: $W-1$、WEIGHT: $W$）を厳密に区別して計算しなければならない（MUST）。平均標準誤差 STDERR（$STD/\sqrt{W}$）および平均 $t$ 信頼区間（LCLM/UCLM）は VARDEF=DF の場合のみ算出し、他の VARDEF では未定義（null）としなければならない（MUST）。

#### Scenario: VARDEFの4分岐計算
- **WHEN** 同一のデータセットに対して VARDEF に DF, N, WDF, WEIGHT をそれぞれ指定する
- **THEN** それぞれの分母 $d$（$n-1, n, W-1, W$）に従って VAR および STD を正しく算出する

#### Scenario: VARDEF=DF 以外のSTDERR要求
- **WHEN** VARDEF に N または WDF が指定され STDERR または LCLM/UCLM が要求される
- **THEN** SAS仕様に従い値を null とし、`status_reason` に `undefined_for_vardef` を記録する

### Requirement: 形状統計量（歪度・尖度）の適用制約
システムは、WEIGHT変数（重み）が指定されている場合は、歪度（SKEWNESS）および尖度（KURTOSIS）を未定義（null）としなければならない（MUST）。WEIGHT未指定時は、VARDEF=DF および N において SAS定義に準拠した歪度および超過尖度を算出しなければならない（MUST）。

#### Scenario: WEIGHT指定時の歪度・尖度
- **WHEN** `weight_variable` が指定されているデータセットで歪度または尖度を要求する
- **THEN** 独自拡張の重み付き式を適用せず、値を null として `status_reason` に `not_available_with_weight` を記録する

#### Scenario: WEIGHT未指定時の歪度・尖度算出
- **WHEN** `weight_variable` が未指定で有効観測数が十分（$n \ge 4$）である
- **THEN** 指定された VARDEF（DFまたはN）に従って SAS定義通りの歪度および超過尖度を出力する

### Requirement: 分位数（QNTLDEF 1〜5）の計算
システムは、QMETHOD=OS において QNTLDEF 1〜5 をサポートしなければならない（MUST）。重み未指定時は SAS定義とR定義の照合関係（QNTLDEF 1=R4, 2=R3, 3=R1, 4=R6, 5[既定]=R2）に従って分位数を計算しなければならない（MUST）。また、WEIGHT指定時は累積重みに基づく別経路で分位数を算出しなければならない（MUST）。

#### Scenario: 重みなしデータでのQNTLDEF 5（SAS既定）計算
- **WHEN** `weight_variable` が未指定で `qntldef` が 5（または未指定）である
- **THEN** SAS定義の第5定義（Rのtype=2相当）に従って分位数を算出する

#### Scenario: WEIGHT指定時の分位数計算
- **WHEN** `weight_variable` が指定され、`qntldef` が 1〜5 のいずれかに指定される
- **THEN** 累積重みパーセンタイルに基づく重み付き分位数ロジックが適用され、各分位数（MEDIAN, Q1, Q3, P1〜P99）が有限値として算出される

### Requirement: CLASS変数と欠損群の制御
システムは、CLASS変数による層別・群別集計をサポートしなければならない（MUST）。CLASS変数の欠損値は既定で除外（exclude）し、`class_missing: true`（MISSING指定）の場合は欠損値を有効な群として保持しなければならない（MUST）。分析変数の欠損は変数別に独立して N および NMISS に反映しなければならない（MUST）。

#### Scenario: CLASS欠損の既定除外
- **WHEN** CLASS変数にNAを含む行が存在し、`class_missing` が false（既定）である
- **THEN** 当該欠損行を群集計から除外して各群の統計量を算出する

#### Scenario: CLASS欠損のMISSING指定保持
- **WHEN** `class_missing` が true に指定される
- **THEN** 欠損水準を1つの群として集計し、その群の記述統計量を出力する

### Requirement: 3点セット成果物とRun隔離出力
システムは、解析完了時に Run 固有の隔離ディレクトリへ、①構造化JSON（`means_results.json`）、②CSV（`summary.csv`）、③日本語Markdownレポート（`summary_report.md`）の3点セットを必ず出力しなければならない（MUST）。また実行設定の写し（`analysis_config.json`）および整合性メタデータ（`manifest.json`）を同梱しなければならない（MUST）。

#### Scenario: 3点セット成果物の正常生成
- **WHEN** PROC MEANS 解析が正常に完了する
- **THEN** `<output_dir>/run_<first16_run_id>/` 配下に `means_results.json`、`summary.csv`、`summary_report.md`、`analysis_config.json`、`manifest.json` が漏れなく生成される

#### Scenario: 未定義統計量の出力表現
- **WHEN** 重み指定により歪度・尖度が未計算、または DF 以外で STDERR が未定義となる
- **THEN** JSONでは値を null とし `status_reason` を記録し、CSVでは空文字またはNAとし、Markdownレポートには未定義理由を注記する

### Requirement: 数値パリティ検証と許容誤差契約
システムは、照合先参照環境として SAS 9.4 on Linux/Windows を基準とし、統計量クラス別の許容誤差契約を満たさなければならない（MUST）。度数（N, NMISS）および分位数（QNTLDEF 1〜5）、中央値は完全一致（差分 0）とし、決定論的連続統計量（SUM, SUMWGT, MEAN, MIN, MAX, RANGE, CSS, USS, VAR, STD, CV, STDERR, LCLM, UCLM, SKEWNESS, KURTOSIS）は絶対誤差 $\text{atol} \le 10^{-12}$ または相対誤差 $\text{rtol} \le 10^{-10}$ の許容範囲内に収まらなければならない（MUST）。また、実機SAS出力を優先 fixture とし、実機未取得時は数理定義値による参照値に `sas_parity: "unverified"` を付与して区別しなければならない（MUST）。

#### Scenario: 決定論的統計量の許容誤差検証
- **WHEN** SAS 9.4 出力 fixture と計算結果を照合する
- **THEN** 度数および分位数は完全一致し、連続統計量は $\text{atol} \le 10^{-12}$ または $\text{rtol} \le 10^{-10}$ を満たす

#### Scenario: 実機未取得 fixture の区別
- **WHEN** 実機SAS出力が得られていない条件・統計量についてテストを実施する
- **THEN** 数理定義値による検証を行い、結果メタデータに `sas_parity: "unverified"` を明示して実機照合と区別する

### Requirement: 対象限定互換と非保証・非主張境界
システムは、明示された対象機能のみの限定互換であることを明示し、ビット単位一致の非保証、全SAS構文・全ODS画面再現の対象外、規制提出適格性の非主張を前提として動作しなければならない（MUST）。

#### Scenario: 境界の明示
- **WHEN** ユーザーまたは仕様参照者がスキルの保証範囲を確認する
- **THEN** ビット単位完全一致は保証せず、全SAS構文/ODS再現は対象外であり、規制提出適格性を主張しないことが明示されている
