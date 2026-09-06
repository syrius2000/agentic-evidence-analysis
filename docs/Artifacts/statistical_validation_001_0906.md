# 3次元カテゴリカル統計基盤の検証・採否報告書（改定版）

- 作成日時: 2026-09-06 17:55 (JST)
- 改定日時: 2026-09-06 21:55 (JST)（レビュー指摘対応・局所セル診断4軸体系統合版）
- 実行環境: Mac mini M2 Pro, macOS, R 4.6.1 (aarch64-apple-darwin23)
- 対象ブランチ: `Angigravity` (Worktree: `agentic-evidence-analysis-antigravity`)
- 関連ドキュメント:
  - 改善計画書: [statistical_foundation_refinement_plan_001_0906.md](statistical_foundation_refinement_plan_001_0906.md)
  - レビュー指摘記録: [review_feedback_001_0906.md](review_feedback_001_0906.md)
  - 初期計画書: [implementation_plan_005_0906.md](implementation_plan_005_0906.md)
  - 設計書: [design.md](../../openspec/changes/validate-three-way-statistical-foundations/design.md)
  - タスク一覧: [tasks.md](../../openspec/changes/validate-three-way-statistical-foundations/tasks.md)
  - 外部参照知見: `HairEyeColor_local_cell_diagnostics_redesign.md`（局所セル診断と大域モデル選択の再設計知見）

---

## 1. エグゼクティブ・サマリー

本検証は、3次元カテゴリカルデータ探索支援における統計的基盤（9候補対数線形モデル、情報量規準BIC/EBIC、セルScore、ベイズ事後校正、厳密周辺尤度）の数理的・数値的妥当性を、本番スキルから完全に隔離された独立テストベッド上で厳密に評価・監査したものである。

本改定版では、初期報告書（001_0906 初版）に対する専門家レビュー指摘事項（合意誤差基準への厳格化、検証失敗時の終了コード反映、閉形式照合の総合合否組み込み、上側対数P値計算の適正化、および大域BFと局所LRTの概念区別）を完全に反映した。さらに、分割表における局所残差診断の最新知見（`HairEyeColor_local_cell_diagnostics_redesign.md`）に基づき、**Leverage補正局所Score統計量**の導入と**4軸（Effect × Evidence × Influence × Stability）セル診断体系**を構築・実証した。

全7検証ケース（Titanic 1倍表・100倍拡大表 × 探索的/目的変数指定、および独立・AB連関・3次交互作用の3人工表）において、主計算（Poisson GLM）と独立参照計算（反復比例適合 `stats::loglin` および閉形式解析解）の適合値相対誤差が事前許容基準（$10^{-5}$）および逸脱度誤差（$10^{-4}$）を完全に満たし、自由度の一致を確認した。また、全6本の単体・結合テスト（陰性対照・例外終了確認を含む）がすべて合格した。

---

## 2. 統計手法の採否判定サマリー

| 手法・指標 | 判定 | 根拠・検証結果 | 適用範囲・注意事項 |
| :--- | :---: | :--- | :--- |
| **9候補対数線形モデル (M1〜M9)** | **採用** | GLM と IPF (`stats::loglin`) / 閉形式が全ケースで誤差 $< 10^{-5}$ で完全一致。閉形式解の照合結果を総合合否に組み込み確認。 | 3変数カテゴリカル分割表。境界適合・特異モデルは通常順位から隔離プールへ除外。 |
| **総度数 $N$ 基準の明示式 BIC** | **採用** | 多項対数尤度とPoisson対数尤度のモデル間差が厳密に一致することを数理・数値で実証。 | 標本サイズは総度数 $N$ を使用。`stats::BIC` はセル数 $K$ を使う定義相違のため不採用。 |
| **拡張BIC (EBIC)** | **見送り / 保留** | 9候補の固定階層モデル空間ではパラメータ組合せ爆発 $\binom{P}{k}$ の仮定が成立せず、追加罰則の根拠が希薄。 | 根拠未確認の値を「検証済みBF」と呼称することを禁止。 |
| **旧セルScore ($r_i^2 - k \ln N$)** | **格下げ (非推奨)** | 局所ダミー再適合モデルの尤度比統計量 $\Delta G_i^2$ と Pearson 残差二乗 $r_i^2$ の著しい乖離（例: 627.22 vs 384.99）を実証。 | 「局所BF」としての呼称を完全廃止。残差スクリーニング指標に留める。 |
| **Leverage補正局所Score統計量 ($T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}}$)** | **推奨採用** | 各セル指示変数追加に対する efficient score statistic であり、再適合なしに局所LRT $\Delta G_i^2$ を高精度に近似（Titanic セル3で $42.8 \approx 43.0$）。 | 自由度1のカイ二乗分布に従う検定統計量。過大レバレッジセル（$h_{ii} \to 1$）は隔離。 |
| **局所モデル再適合 ($\Delta G_i^2$)** | **推奨採用** | セルダミーを追加した再適合により、厳密な逸脱度減少と対数P値を算出。 | 自由度0（列従属）や境界推定のセルは保留プールに隔離。 |
| **4軸セル診断体系 (Effect, Evidence, Influence, Stability)** | **採用** | 単一指標への統合を廃止し、大標本で不変な Effect（$\log(O/E)$, $\Delta G^2/N$）と標本数依存の Evidence（$T_i^{\rm score}, \Delta G^2$）を分離提示。 | 基準モデル（相互独立 M1 または均一連関 M8）を必ず明示。 |
| **Dirichlet事後推定 (a=1.0, 0.1, 10)** | **採用** | 解析的 Beta 等裾区間と 20,000回 MC 標本が MCSE 3-sigma基準内で完全一致（最大誤差 $0.00005 < 3 \times \text{MCSE}$）。 | 点ごとの等裾区間であり、全セル同時の信用領域ではないことを明記。 |
| **同時事後標本による条件付き割合差** | **採用** | Dirichlet同時事後分布から各層の条件付き生存率および層間差（例: 女性 1st vs 3rd: 差平均 +0.513, $P(\text{Diff}>0)=1.0$）を正しく算出。 | 同一ドロー内の相関構造を完全に維持した不確実性評価。 |
| **厳密周辺尤度・厳密BF (独立 vs 飽和)** | **採用 (参照用)** | 多項係数の相殺と Dirichlet 共役性に基づく厳密解析解を導出。人工独立表で $\ln BF_{\text{sat}, \text{ind}} = -15.85 < 0$（独立支持）を確認。 | 独立 vs 飽和の2モデル間限定。他7モデルは厳密BF未計算（大域BIC近似）。 |
| **階層ベイズ縮約モデル** | **見送り (後続Change)** | Stan 等のサンプリング基盤や説明負担が大きく、今回の軽量基盤には含めない。 | 必要性と効果を後続課題として整理。 |

---

## 3. レビュー指摘事項の解消実績

| 指摘番号 | 指摘内容 | 修正前の状態 | 修正後の実装・検証実績 |
| :---: | :--- | :--- | :--- |
| **1** | **合格基準が設計と異なる** | 事後平均の固定絶対誤差 0.01 で判定していた。 | モンテカルロ標準誤差に基づく **MCSE 3-sigma 基準**（$3 \times \text{MCSE}$）および二項標本誤差 3-sigma 基準（$3 \times \sqrt{0.95 \times 0.05 / D} \approx 0.0046$）に改定。最大誤差 $0.000050 < 0.000209$ で完全合格。 |
| **2** | **検証失敗でも実行成功になる経路** | 結果に `CHECK_FAILED` を設定してもパイプライン終了コードが 0（SUCCESS）だった。 | `evaluation_status == "CHECK_FAILED"` を検知した場合、終了コード 1（非ゼロ）で異常終了するよう修正。陰性テスト `test_intentional_mismatch.R` で exit 1 を実証。 |
| **3** | **閉形式照合が総合合否から除外** | `cf_match` が参考情報に留まり、総合合否 `is_ok` / `all_passed` に連動していなかった。 | 閉形式解を持つモデル（M1〜M7, M9）の合否判定を `is_ok` の必須論理積に組み込み。意図的不一致テストで総合不合格となることを実証。 |
| **4** | **上側P値計算の丸め落ち** | `1 - pchisq(...)` により大標本極大検定統計量で 0 に縮退していた。 | `pchisq(..., lower.tail = FALSE)` を採用し、アンダーフローを防止。同時に対数P値 `pchisq(..., lower.tail = FALSE, log.p = TRUE)` を保持。 |
| **5** | **数理的根拠と用語の不整合** | 局所尤度比 $\Delta G_i^2$ を「局所BF」と呼称、`stats::BIC` を「不具合」と表現していた。 | 局所LRT統計量と大域ベイズファクターの相違を明確化。`stats::BIC` の相違を「多項標本総度数 $N$ と GLM 観測セル数 $K$ の定義相違」と適正化。 |

---

## 4. 詳細検証と監査結果

### 4.1 9モデルの適合と参照計算の完全一致

`tests/fixtures/statistical_foundations/case_manifest.json` に定義された 9 候補モデルについて、Poisson GLM (`fit_models.R`) と独立参照計算 (`reference_values.R`) の比較を行った。

- **M1 (相互独立)**: $\hat{\mu}_{ijk} = n_{i++} n_{+j+} n_{++k} / N^2$（閉形式とIPFが一致、GLM誤差 $< 10^{-12}$）
- **M2〜M4 (1組関連)**: 閉形式とIPFが一致、GLM誤差 $< 10^{-12}$
- **M5〜M7 (条件付き独立)**: 閉形式とIPFが一致、GLM誤差 $< 10^{-12}$
- **M8 (均一連関)**: IPF 反復比例適合と GLM の適合値相対誤差 $< 10^{-7}$, 逸脱度誤差 $< 10^{-6}$
- **M9 (飽和)**: 観測度数と完全一致

閉形式解の照合判定 `cf_match` は、全モデルで総合合格判定 `is_ok` に組み込まれ、全7ケースにおいて `all_reference_checks_passed = TRUE` を達成した。

### 4.2 情報量規準の監査：大標本ペナルティと定義相違の数理

- **Poisson対数尤度と多項対数尤度の厳密な一致**:
  任意の切片を含む対数線形モデルにおいて $\sum \hat{\mu}_i = N$ が成立するため、Poisson対数尤度と多項対数尤度の差は定数 $N \ln N - N - \ln(N!)$ に過ぎない。したがってモデル間の対数尤度差 $\Delta \ln L$ は多項尤度と厳密に一致する。
- **`stats::BIC` と明示式 BIC の定義相違**:
  R の標準関数 `stats::BIC(fit)` は `nobs = length(residuals)`（分割表のセル数 $K$）を使用する。これは独立同分布（i.i.d.）の標本単位をセルとみなすGLMの仕様に依存している。しかし分割表の真の標本サイズは被験者総数 $N = \sum y_i$ である。
  Titanic データ（$N = 2,201$, $K = 16$）における監査結果：
  - 総度数 $N$ 基準の明示式 BIC (M1): $1,160.18$（ペナルティ $6 \times \ln(2201) = 46.18$）
  - R既定 `stats::BIC` (M1): $1,130.64$（ペナルティ $6 \times \ln(16) = 16.64$）
  - **ペナルティ乖離: $29.54$**
  大標本分析（100倍表: $N = 220,100$）ではこのペナルティ差は $6 \times (\ln 220100 - \ln 16) = 57.19$ に達し、モデル選択の順位に致命的な歪みを与える。したがって、総度数 $N$ を用いた明示式 BIC を唯一の正本とする。

### 4.3 局所セル診断の監査と HairEyeColor 知見の統合

#### 4.3.1 Pearson残差二乗と局所尤度比の乖離
現行コードで用いられていた旧セルScore $r_i^2 - k \ln N$ に対し、各セルに指示変数を追加した局所ダミー再適合モデル $M_{0 + \{i\}}$ の尤度比統計量 $\Delta G_i^2$ を計算したところ、大標本および残差が大きいセルで乖離が著しいことが実証された。

- Titanic データ（M1 相互独立基準）における数値例：
  - セル 1 (1st, Female, No): $r^2 = 39.32$, $\Delta G^2 = 77.77$, 差 $|r^2 - \Delta G^2| = 38.45$
  - セル 2 (1st, Female, Yes): $r^2 = 627.22$, $\Delta G^2 = 384.99$, 差 $|r^2 - \Delta G^2| = 242.23$
  - セル 3 (1st, Male, No): $r^2 = 17.50$, $\Delta G^2 = 43.02$, 差 $|r^2 - \Delta G^2| = 25.51$

#### 4.3.2 Leverage補正局所Score統計量 $T_i^{\rm score}$ の数理的優位性
`HairEyeColor_local_cell_diagnostics_redesign.md` の数理展開に基づき、Hat 行列対角成分（Leverage）$h_{ii}$ を用いた局所Score統計量を実装した：
$$T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}} = \frac{(y_i - \hat{\mu}_i)^2}{\hat{\mu}_i (1 - h_{ii})}$$
これはセル $i$ のダミー変数パラメータ $\gamma_i = 0$ に対する **Rao のスコア検定統計量（efficient score statistic）** に厳密に一致する。
Titanic データにおける検証により、$r^2$ 単体では $\Delta G^2$ から大きく乖離するセルにおいても、$T_i^{\rm score}$ は局所LRT $\Delta G^2$ の極めて高精度な二次近似となることが実証された：
- セル 3 (1st, Male, No, $h_{ii} = 0.591$):
  - $r^2 = 17.50$
  - $T_i^{\rm score} = \frac{17.50}{1 - 0.591} = 42.80$
  - $\Delta G^2 = 43.02$
  - **残差二乗の誤差が $25.51$ であったのに対し、Score統計量の誤差はわずか $0.22$（ほぼ完全一致）**。

#### 4.3.3 4軸セル診断体系（Effect × Evidence × Influence × Stability）
単一の「Evidence Score」に複数の概念を混同させることを廃止し、以下の 4 軸構造で出力する設計を確立した：

1. **Effect（効果量・実質的有意性）**:
   標本サイズ $N$ に依存しない不変量。
   - $\log(O_i / E_i)$: 相対リスクの対数。
   - 標準化差 $e_i = d_i / \sqrt{N}$（ただし $d_i = (y_i - \hat{\mu}_i) / \sqrt{\hat{\mu}_i}$）。
   - 標準化逸脱度減少 $\Delta G_i^2 / N$。
   - 割合差 $(y_i - \hat{\mu}_i) / N$。
   - *実証*: 100倍拡大表（$N = 220,100$）においても、これらの値は 1倍表（$N = 2,201$）と完全に同一値を保持する。
2. **Evidence（証拠強度・統計的有意性）**:
   標本サイズ $N$ に比例して増大する検定統計量。
   - Leverage補正Score統計量 $T_i^{\rm score}$（自由度 1 のカイ二乗値）。
   - 局所逸脱度減少 $\Delta G_i^2$ および上側対数P値 $\ln p$（アンダーフロー完全防止）。
   - 局所 $\Delta\text{BIC}_i = \Delta G_i^2 - k \ln N$（ダミー追加によるBIC改善度）。
3. **Influence（構造的影響度）**:
   - Hat 行列対角成分（Leverage: $h_{ii} = \text{hatvalues}(fit)$）。モデル適合に対するセルの梃子力・制約度合を表す。
4. **Stability（数値的安定性）**:
   - ゼロセル、小期待度数（$\hat{\mu}_i < 5$）、過大レバレッジ（$h_{ii} \to 1$）、自由度消費（$\Delta df_i = 0$）を検知し、異常セルを `QUARANTINED` に隔離する。

### 4.4 ベイズDirichlet事後推定・モンテカルロ校正・厳密BF

- **MCSE 3-sigma 基準によるモンテカルロ校正 (20,000 ドロー, seed = 20260906)**:
  - 解析事後平均と MC 事後平均の最大絶対誤差: $0.000050$
  - 許容基準上限（$3 \times \text{MCSE}$）: $0.000209$
  - **判定: PASS（完全適合）**
  - 解析区間の MC カバレッジ率最大誤差: $0.0043$
  - 二項標本誤差許容基準上限（$3 \times \sqrt{0.95 \times 0.05 / 20000}$）: $0.0046$
  - **判定: PASS（完全適合）**
- **同時事後標本による条件付き割合差の推定**:
  多項分布の Dirichlet 事後分布から生成された同一の同時事後標本を用い、条件付き生存率（$P(\text{Survived}=\text{Yes} \mid \text{Class}, \text{Sex})$）および層間差を計算した：
  - 1st Female vs 3rd Female 生存率差: 平均 $+0.513$ (95% 信用区間: $[0.438, 0.586]$), $P(\text{Diff} > 0) = 1.0000$
  - 1st Male vs 3rd Male 生存率差: 平均 $+0.198$ (95% 信用区間: $[0.119, 0.276]$), $P(\text{Diff} > 0) = 1.0000$
  - 1st Female vs 1st Male 生存率差: 平均 $+0.627$ (95% 信用区間: $[0.548, 0.701]$), $P(\text{Diff} > 0) = 1.0000$
  これにより、周辺区間の独立比較では失われる相関構造を完全に維持した推論が可能となった。
- **厳密周辺尤度と厳密ベイズファクター**:
  - 人工独立表（`syn_independent`）:
    - 飽和対数周辺尤度: $-47.64$
    - 相互独立対数周辺尤度: $-31.79$
    - $\ln BF_{\text{sat}, \text{ind}} = -15.85 < 0$（**独立モデルを決定的に支持**）
  - Titanic 表:
    - $\ln BF_{\text{sat}, \text{ind}} = +466.96 > 0$（飽和モデルが独立モデルを圧倒的に支持）

### 4.5 パイプライン堅牢性と陰性対照テストの実証

`test_intentional_mismatch.R` を用いて、パイプラインの防御機能を検証した：
1. **閉形式解不一致の検出**: M1 の参照値を意図的に改ざんした場合、`all_reference_checks_passed = FALSE` となり、総合合否が即座に `CHECK_FAILED` となることを確認。
2. **異常終了コードの保証**: `run_validation.R` は検証失敗（`CHECK_FAILED`）を検知した瞬間に、終了コード 1（非ゼロ）で exit することを確認（旧来の SUCCESS 偽陽性を完全防止）。

---

## 5. 階層ベイズ縮約（Hierarchical Shrinkage）の位置づけ

| 項目 | 評価・所見 |
| :--- | :--- |
| **必要性** | スパースな分割表（ゼロセルや少数セルが頻発する高次元カテゴリカルデータ）において、主効果や交互作用パラメータをゼロ方向へ適応的に縮約するために極めて有効である。 |
| **期待効果** | Horseshoe 事前分布や階層事前分布により、真のシグナルを残しつつノイズ交互作用を自動抑制し、大標本過剰適合や小標本過大推定を防ぐ。 |
| **計算基盤** | RStan, CmdStanR 等の C++ コンパイルおよび HMC/NUTS サンプリング基盤が必要となり、本リポジトリの軽量 R 実行環境への依存追加負担が大きい。 |
| **採否判定** | **初回試作では見送り、後続の高度分析タスク（独立 Change）として位置づける**。今回の Dirichlet-Multinomial 校正基盤とは明確に区別し、完成扱いとしない。 |

---

## 6. 後段（Pass 2 AI Narrative / Pass 3 Dashboard）への引継ぎ契約

### 6.1 結果 JSON 契約 (`validation_results.json`)

後段のレポート生成および LLM による要約プロンプトには、以下の構造化された結果を渡す：
- `provenance`: 実行識別子、入力ファイル SHA-256、実行時刻
- `input_summary`: 変数名、総度数 $N$、セル数 $K$、サンプリング前提
- `models`: 9モデルの対数尤度、自由度、明示式 BIC（総度数 $N$ 基準）、AIC、推定状態
- `comparisons`: 入れ子比較における $\Delta G^2$, $\Delta df$, 方向性
- `cells`: 各セルの 4 軸診断（Effect, Evidence, Influence, Stability）
- `posterior`: Dirichlet 事後平均、周辺 95% 信用区間、条件付き生存率差、厳密周辺尤度
- `decisions`: 隔離された異常モデル、採否状態（`VERIFIED` または `CHECK_FAILED`）

### 6.2 大標本（100倍拡大データ）に関する解釈上の必須ルール

- タイタニック 100倍拡大表（$N = 220,100$）において、生のセル構成比は 1倍表（$N = 2,201$）と完全に同一である。
- しかし、検定統計量（カイ二乗値、逸脱度、Score統計量）や対数尤度差は 100倍に肥大化し、P値はすべて極限的な過剰有意（$\ln p \ll -100$）となる。
- **Pass 2 の AI Narrative は、P値のみに依存した判定を固く禁じる**。
- **Effect 軸（$\log(O/E)$, $\Delta G^2/N$, 割合差）が 1倍表と完全に一致することを明示し、実質的な効果量と大標本による証拠強度の肥大化（Evidence 軸）を分離して解説しなければならない**。

### 6.3 未実施事項の明示

- **実 LLM によるプロンプト評価および最終ユーザー受入検証は、本変更のスコープ外（後段未実施）**である。
- 本変更の完了条件は、統計基盤・計算エンジン・監査・校正・出力隔離の数理的・実装的検証完了までとする。

---

## 7. 再現手順と全検証実行エビデンス

### 7.1 再現実行コマンド

```bash
# 1. テストケースおよび設定ファイルの生成（MCSE 3-sigma 基準を含む）
Rscript tests/statistical_foundations/prepare_cases.R

# 2. 全 7 検証ケースの実行
for cfg in tests/fixtures/statistical_foundations/configs/*.json; do
  Rscript tests/statistical_foundations/run_validation.R --config "$cfg"
done

# 3. 単体・結合・陰性対照テストの実行
Rscript tests/statistical_foundations/test_validate_config.R
Rscript tests/statistical_foundations/test_section3_models.R
Rscript tests/statistical_foundations/test_section4_ic_score.R
Rscript tests/statistical_foundations/test_section5_bayesian.R
Rscript tests/statistical_foundations/test_intentional_mismatch.R
Rscript tests/statistical_foundations/test_reproducibility.R
```

### 7.2 全テストの合格エビデンス記録（2026-09-06 21:51 実行）

- `test_validate_config.R`: 正常設定、未知キー拒否、変数数不正、response_var所属、独立性未解決HOLD、構造ゼロHOLD、不正フィルタ演算子拒否、未知列拒否、フィルタ0件拒否の全 9 テスト成功。
- `test_section3_models.R`: `syn_independent`, `syn_ab_associated`, `syn_interaction_shifted`, `titanic_aggregated_3way` の全 4 ケースで IPF/閉形式照合が完全一致し、全件合格。
- `test_section4_ic_score.R`: 明示式BICとstats::BICの乖離（29.54）、Hat対角成分（Leverage $h_{ii}$）、Score統計量 $T_i^{\rm score}$ と $\Delta G^2$ の近似（セル3で $42.8 \approx 43.0$）、$N$ 不変効果量（$\log(O/E)$, $d/\sqrt{N}$, $\Delta G^2/N$）を検証し、全件合格。
- `test_section5_bayesian.R`: MCSE 3-sigma 基準合格（最大誤差 $0.000050 < 0.000209$）、二項誤差 3-sigma 基準合格（カバレッジ誤差 $0.0043 < 0.0046$）、条件付き生存率差（女性 1st vs 3rd: 差平均 $+0.513$, 95% CI $[0.438, 0.586]$, $P>0=1.0$）、人工独立表における厳密BFの独立支持（$\ln BF = -15.85 < 0$）を検証し、全件合格。
- `test_intentional_mismatch.R`: IPF参照値改ざんの検出、閉形式解改ざんの総合不合格検出、`run_validation.R` の `CHECK_FAILED` 時の非ゼロ終了（exit 1）を実証し、全件合格。
- `test_reproducibility.R`: 乱数固定による完全再現性、出力ディレクトリ衝突検知、独立ディレクトリ隔離性を検証し、全件合格。
