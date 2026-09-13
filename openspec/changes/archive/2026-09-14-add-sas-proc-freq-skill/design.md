## Context

モチベーションと目的の詳細は [proposal.md](proposal.md) を参照。
本設計は、SAS PROC FREQ の集計および推測統計量について、R環境（base R / stats）を用いて対象限定・参照環境明示・許容誤差付きの数値互換を提供する独立スキル `.agents/skills/sas-proc-freq` のアーキテクチャおよび技術的決定を規定する。
本Changeは純粋に PROC FREQ 単体を対象とし、PROC MEANS や多変量パイプライン等の他機能は本設計および受入条件に混入させない。

## Goals / Non-Goals

**Goals:**
- `.agents/skills/sas-proc-freq` の独立スキルディレクトリ構造（`SKILL.md`, `schemas/`, `templates/`）の確立。
- 非負整数度数列を持つ集計表を入力とする厳密な入力バリデーションおよび水準順序・表の向きの固定。
- 1元表、2元表、層別2元表における度数・割合集計および3つの欠損モード（`exclude`, `missprint`, `include`）の制御（table request ごとの独立適用）。
- 独立性検定（Pearsonカイ二乗、尤度比カイ二乗、2×2連続性補正カイ二乗）。
- Fisher正確検定（2×2 超幾何分布和 vs 一般 $R \times C$ ネットワーク法）の分離と、子プロセス監視による資源保護（時間・メモリ・ワークスペース制限と状態コード）。
- SAS仕様に準拠した Monte Carlo 推定・要約（点推定 $\hat{p}=M/B$、SE、正規近似区間、境界 $M=0, B$ 端点式）と、事前承認時のMCフォールバック。
- 2×2表の効果量（OR、RR列1/列2）と各Wald信頼区間、二項割合の信頼区間（Wald、Clopper-Pearson、Wilson）。
- **3点セットの出力成果物の生成**:
  1. 構造化JSON（`freq_results.json`）: 機械可読・正本・全統計量・表の向き・未定義理由コード
  2. CSV（`summary.csv`）: SAS ODS OneWayFreqs / CrossTabFreqs に対応し、安定複合キー `strata_key` を持つ表形式データ
  3. 日本語Markdownレポート（`summary_report.md`）: 分割表、検定結果、適用制約・解釈をまとめた監査用レポート
- Run隔離ディレクトリ（`<output_dir>/run_<first16_run_id>/`）への `analysis_config.json`（設定写し）および `manifest.json`（入力/出力SHA-256、JSTタイムスタンプ、R環境）の同梱。
- **2段階受入ゲートの確立**:
  - Stage 1: 数理定義・手計算・独立実装に基づく基礎受入（`sas_parity: "unverified"` を保持した完了判定）。
  - Stage 2: SAS実機fixture提供時のParity受入（許容誤差基準による検証）。

**Non-Goals:**
- PROC MEANS 統計量、分位数、VARDEF計算（別Change `add-sas-proc-means-skill` で実施）。
- SASの全構文、全ODS出力、任意FORMAT、特殊欠損（.A〜.Z）の全再現。
- SAS `WEIGHT` 文における `ZEROS` オプション（度数0の未観測セルを自動生成する機能。初回は度数0行は集計セルから除外するSAS既定挙動に準拠）。
- 一般 $R \times C$ の CMH統計量や順序スコアMH（拡張段階で個別起案）。
- 既存の 3-way 分析パイプライン（M1〜M9, BIC, セル診断等）の改変や統合。
- Windows 環境での子プロセス資源監視（v1 は Unix / macOS / Linux 専用を正式前提とし、Windows は Non-Goal）。
- OS レベルの OOM Killer による瞬時 SIGKILL に対するミリ秒未満の物理メモリ追従（プロセス監視ポーリング外での即死は exit status 137 / 9 による推定対応とし、厳密な確定保証外）。

## Decisions

### 1. 設定管理とインターフェース
- 単一の `analysis_config.json` を設定正本とし、`schema_version: "sas-summary-config-v1"` および `analysis_kind: "sas_proc_freq"` を定義する。
- 表定義オブジェクト（`tables`）に水準順序、イベント水準、比較方向、資源上限、フォールバック設定を完全規定する：
  ```json
  {
    "schema_version": "sas-summary-config-v1",
    "analysis_kind": "sas_proc_freq",
    "tables": [
      {
        "table_id": "t1",
        "row_var": "ARM",
        "col_var": "RESP",
        "strata_vars": ["REGION"],
        "levels_order": {
          "ARM": ["Trt", "Pbo"],
          "RESP": ["Responder", "NonResponder"]
        },
        "event_level": "Responder",
        "comparison_direction": "Trt_vs_Pbo",
        "missing_mode": "exclude",
        "fisher": {
          "method": "exact",
          "limits": {
            "timeout_sec": 300,
            "max_memory_mb": 1024,
            "workspace_bytes": 1073741824
          },
          "fallback_to_mc": false,
          "mc_sampling_algorithm": "patefield",
          "mc_replications": 10000,
          "mc_seed": 20260913,
          "mc_alpha": 0.01
        }
      }
    ]
  }
  ```

### 2. 水準順序・表の向き・ゼロの厳密処理
- **水準解決**: `levels_order` が指定されている場合はその順序を絶対保持する。未指定時はデータの出現順とし、Rの暗黙の文字列昇順ソート（ロケール依存）による変形を禁止する。
- **2×2表の向き**: 行1=暴露群（分子群）、行2=対照群（分母群）、列1=イベント、列2=非イベントとして配置し、結果JSONに明示記録する。
- **ゼロ度数行（count = 0）**: SAS既定動作に従い、度数0の行は集計セル生成時に除外する。未観測組み合わせを自動生成するSASの `ZEROS` オプションは Non-Goal とする。
- **退化表・0/0割合**:
  - 行・列の周辺度数が0の表や、2×2未満に退化した推測表は独立性検定・効果量計算を行わず、統計量は `null`、理由コード（`DEGENERATE_TABLE_ZERO_MARGINAL` 等）を記録する。
  - 分母0の割合計算（0/0）は 0 に置換せず `null`（理由: `INDETERMINATE_FRACTION_ZERO_DENOMINATOR`）とする。
- **ゼロセル**: OR/RR計算時のセル0に対して勝手な 0.5 加算（Haldane補正）を行わず、`null`（理由: `ZERO_CELL_UNDEFINED`）を記録する。
- **構造的ゼロ**: 入力で構造的ゼロが指定された場合は、通常の独立性検定への投入を拒否し `STRUCTURAL_ZERO_PRESENT` を返す。

### 3. 数値計算エンジンと独立性検定
- base R および stats パッケージを主軸とし、不要な外部依存を避ける。
- カイ二乗連続性補正は R の `chisq.test(..., correct=TRUE)` に依存せず、SAS定義の数式 $Q_C = \sum [\max(0, |O-E|-0.5)]^2/E$ を明示的に直接計算する。
- 尤度比 $G^2 = 2\sum O \log(O/E)$ は $O=0$ の寄与を厳密に 0 としてベクトル演算する。

### 4. Fisher正確検定と両側定義の分離
- **2×2表の exact**: 超幾何分布に基づき、観測表の確率以下の全表確率和 $\sum_{P(t) \le P_{obs}} P(t)$ を計算する。片側2倍方式や mid-p は採用しない。
- **一般 $R \times C$ 表の exact**: Mehta & Patel (1983) のネットワーク法（同一周辺度数を持つ全可能表の多変量超幾何確率のうち、観測表の確率以下の確率を持つ表の確率総和）を採用する。
- Rの `fisher.test()` を利用するが、2×2と一般表の計算法・両側定義の差異を内部で区別して扱う。

### 5. 資源保護と子プロセス監視アーキテクチャ
- 大標本・大分割表での `fisher.test(..., simulate.p.value=FALSE)` は計算時間膨大化やCルーチン内の作業領域超過のリスクがある。
- **制限単位と R API 換算規則**:
  - `max_memory_mb`: OSプロセス全体の最大RSS（常駐物理メモリ）上限（MB単位）。Unix `ps` コマンド（`ps -o rss= -p <pid>`）による子プロセスの定期ポーリング監視を行い、超過を検知した場合は子プロセスを停止する。
  - `workspace_bytes`: 正確検定計算用の内部作業バッファ上限（バイト単位、既定: 33,554,432 = 32MB、最大推奨: 1GB等）。
  - **適用範囲（2×2 vs 一般 $R \times C$ 表）**:
    - **2×2表**: R の `fisher.test()` では超幾何分布からの直接確率計算（`dhyper`/`phyper`）を行うため、`workspace` 引数は一切参照・使用されない。
    - **一般 $R \times C$ 表（$R > 2$ または $C > 2$）**: Mehta & Patel (1983) ネットワーク法の Exact 検定（`simulate.p.value = FALSE`）においてのみ、内部作業配列サイズとして `workspace` 引数が渡される。
  - **R API 換算規則（4バイト単位）**:
    - R の公式仕様（`stats::fisher.test` Rd）において、`workspace` 引数は明確に **`In units of 4 bytes`**（4バイト単位の整数値）と定義されている。
    - したがって、設定値 `workspace_bytes` から R API へ渡す整数値 `workspace` の換算式は以下を厳密に適用する：
      $$\mathrm{workspace} = \min\left(\left\lfloor \frac{\mathrm{workspace\_bytes}}{4} \right\rfloor, 2147483647\right)$$
      （C言語の `int` / Rの32-bit符号付き整数上限 `.Machine$integer.max` = $2^{31} - 1 = 2,147,483,647$ を上限としてクリップ）。
      - 例: 既定値 32MB（`33,554,432` バイト）$\rightarrow \mathrm{workspace} = 8,388,608$（約8.38M units）
      - 例: 1GB（`1,073,741,824` バイト）$\rightarrow \mathrm{workspace} = 268,435,456$（約2.68億 units）
      - （参考: base R 既定の `workspace = 200,000` は $200,000 \times 4 = 800,000$ バイト $\approx 800$ KB 相当）。
- **プラットフォーム前提とサンドボックス要件**:
  - 子プロセス常時監視（PID および RSS）は Unix（macOS / Linux）の `/bin/ps` コマンドに依存するため、実行環境は Unix 前提（`.Platform$OS.type == "unix"`）とする。Windows 環境は正式 Non-Goal。
  - IDE サンドボックスやコンテナ環境においてプロセス間情報参照が制限される場合、監視が正常に機能しないため、適切な実行権限（`BypassSandbox: true` 等）での運用を前提とする。
- **停止ハンドリングと状態コードの厳密判別**:
  - `TIMEOUT`: 実行時間が `timeout_sec`（既定300秒）を超過し、親プロセスの監視ループから SIGTERM（応答なき場合 SIGKILL）を発行して強制停止した場合。
  - `WORKSPACE_EXCEEDED`: R の FEXACT ルーチンからワークスペース枯渇に関する固有エラー（`"FEXACT error 40. Out of workspace."`, `"ldWorkspace is not large enough"`, `"workspace is not large enough to calculate exact p-value"`, `"FEXACT error 7"` 等）が捕捉された場合。
  - `OUT_OF_MEMORY`: プロセス監視による `max_memory_mb` 超過検知、OSのOOM Killer/SIGKILL終了（exit status 137 / 9）、または R の一般的なメモリ割当失敗（`"cannot allocate vector of size"`, `"std::bad_alloc"` 等）が捕捉された場合。
  - `SUBPROCESS_FAILURE`: 上記以外のプロセス異常終了。
  - `NUMERICAL_FAILURE`: その他の数値計算不能・特異行列・アンダーフロー等。
  - *【OOM Killer 即死時の保証限界】*: 子プロセスが急激なメモリ確保により OS OOM Killer に瞬時に落とされた場合、ポーリング周期の合間にプロセスが消滅することがある。この場合、ログ上の割当エラー文字列または exit status 137（128 + 9 = SIGKILL）により `OUT_OF_MEMORY` と推定するが、ミリ秒未満の物理メモリ追従は保証外とする。
- **部分成果物の保護**:
  - 資源停止が発生した場合でも、すでに完了している度数集計、欠損要約、カイ二乗検定結果は一切破棄せず保持する。
  - Fisher検定値のみを `null` とし、該当表の `fisher.status` に上記状態コードを記録した上で3点セット成果物を正常出力する。
- **フォールバック契約**:
  - `fisher.fallback_to_mc: true` が明示設定されている場合のみ、停止後に Monte Carlo 推定へ移行し、`requested_method: "exact"`, `executed_method: "monte_carlo"`, `fallback_reason: "RESOURCE_LIMIT_EXCEEDED"` を結果に記録する（既定は `stop`）。

### 6. SAS仕様Monte Carlo要約とアルゴリズム固定
- **標本化アルゴリズムの固定（`mc_sampling_algorithm`）**:
  - 設定項目 `mc_sampling_algorithm` を必須項目とし、`"patefield"` または `"awb"` を定義する。
  - **v1 実装範囲**: `"patefield"` のみ実装（base R の `r2dtable` / Patefield (1981) アルゴリズムに準拠し、決定論的再現性と実行速度を確保）。
  - **AWB拒否**: `"awb"` はスキーマ予約項目とし、v1 ではサイレントな patefield フォールバックを禁止して設定時に明示的バリデーションエラー（設定拒否）とする。
  - 実行時に適用されたアルゴリズム名（`"patefield"`）、固定Seed（`mc_seed`）、反復回数（`mc_replications`）を結果JSONおよび `manifest.json` に明示記録する。同一アルゴリズム・同一Seedのもとでのみ表列生成と極端表数 $M$ の完全再現性を保証する。
- **極端表判定**: $P(t) \le P(t_{obs})$。
- **専用要約関数 `sas_mc_summary(M, B, alpha)`**:
  - $\hat{p} = M / B$
  - $\mathrm{SE} = \sqrt{\hat{p}(1 - \hat{p}) / (B - 1)}$
  - $0 < M < B$: $\hat{p} \pm z_{1 - \alpha/2} \mathrm{SE}$
  - $M = 0$: $(0, 1 - \alpha^{1/B})$
  - $M = B$: $(\alpha^{1/B}, 1)$
- R既定の $(M+1)/(B+1)$ は主値とせず、監査列 `p_mc_plus_one` にのみ記録する。

### 7. 出力層アーキテクチャ、可逆複合キー、および個別列併記
- 出力は完全隔離された `<output_dir>/run_<first16_run_id>/` 配下に配置する。
- **① 構造化JSON (`freq_results.json`)**:
  - 表ごとの観測度数、有効度数、除外欠損数、行・列水準順、表の向き、全統計量、状態理由コード。
  - `sas_parity`（`"unverified"` または `"verified"`）および `parity_basis`。
- **② CSV (`summary.csv`)**:
  - **真に可逆・衝突なしの複合キー `strata_key`**:
    - 各層別変数名および水準値を UTF-8 文字列として RFC 3986 percent-encoding（`=` → `%3D`, `|` → `%7C`, `%` → `%25`, 改行・空白等もエンコード）を適用する。
    - 変数名（ASCII昇順）でソートした上で `encoded_var=encoded_val` を `|` で結合する（例: `REGION=East|STAGE=II` は `REGION=East|STAGE=II`、値に記号が含まれる場合 `GRP=A%7CB` のように安全に表現）。層別なし時は予約値 `"ALL"` とする。
    - 逆関数 `decode_strata_key(key)` により、任意の文字が含まれる場合でも元の変数名と水準値が一意に復元可能であることを保証する。
  - **個別層別変数列の併記**:
    - `summary.csv` には複合キー `strata_key` 列に加えて、各層別変数を個別列（生の値、CSV標準エスケープ）として併記する（例: `REGION`, `STAGE` 列）。
    - これにより、外部ツール（Pandas, dplyr 等）でキー分解処理を行わずに直接グループ化・フィルタリングが可能となる。
    - 列構成: `table_id, strata_key, <strata_var1>, ..., row_level, col_level, frequency, percent, row_percent, col_percent`
- **③ 日本語Markdownレポート (`summary_report.md`)**:
  - 人間可読要約。度数分布、検定結果一覧、効果量区間、資源停止の有無、注意点テーブルを記載。
- **④ 実行メタデータ**:
  - `analysis_config.json`（設定写し）
  - `manifest.json`（入出力SHA-256、JSTタイムスタンプ、R環境情報、使用した `mc_sampling_algorithm`）

### 8. 2段階受入ゲート（Acceptance Gates）
- **Stage 1: 基礎受入（Foundation Acceptance）[本Changeのスコア]**
  - SAS公式仕様書（SAS 9.4 PROC FREQ Documentation等）に基づく数式単体テスト、手計算値照合、境界値テスト（ゼロセル、退化表、欠損3モード、資源タイムアウト停止）の全件合格を必須条件とする。
  - SAS実機アクセスが未提供の場合でも、成果物メタデータに `sas_parity: "unverified"`, `parity_basis: "formula_and_hand_calculation"` を記録することで本Changeの実装完了条件を満たす。
- **Stage 2: SAS Parity受入（Parity Verification Acceptance）[将来ゲート]**
  - SAS実機（バージョン、保守レベル、OS、ロケール、実行ログ、丸め前出力）のfixtureが提供された時点で実行。
  - 許容誤差: 決定論的統計量は $|R - SAS| \le 10^{-12} + 10^{-10}|SAS|$、極小P値は $\log P$ 比較、MC要約関数は固定 $M, B$ での完全一致。
  - 全fixture合格時に `sas_parity: "verified"` へ昇格。

## Risks / Trade-offs

- **[大標本・大表での計算ハング]** → 子プロセス監視により時間・メモリ上限で確実にプロセス停止し、部分成果物を安全に保持して出力する。
- **[SAS実機未確認による過大主張]** → Stage 1（基礎受入）と Stage 2（Parity受入）を明確に分離し、fixture未提供時は `unverified` を維持することで、品質契約の偽装を防止する。
- **[PROC MEANSや他分析との混同]** → 本ChangeからMEANS関連記述を完全排除し、PROC FREQ 単体の完結性を担保する。
