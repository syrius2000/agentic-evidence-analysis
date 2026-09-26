# 分析スキルの責務境界とアーキテクチャ

created: 2026-09-07 00:08 (JST)
update: 2026-09-21 00:35 (JST)
author: Codex (GPT-5)

この文書は、本リポジトリで提供される各種分析スキルの役割分担と適用範囲を説明する派生リファレンスです。規範的挙動は`openspec/specs/`を正本とし、archiveは履歴として扱います。

---

## 1. スキル選定ガイドライン

入力データの構造、分析目的、および変数の次元数に応じて、以下の通り適切なスキルを選択します：

| 分析のフェーズ・目的 | 主担当スキル | 扱う範囲・提供機能 | 扱わない範囲（境界外） |
| :--- | :--- | :--- | :--- |
| **Pass 0: 分析設計・事前相談・ルーティング** | `vcd-pass0-consultation` | データ検分（度数・水準・欠測）、次元削減・層別の提案、観察デザインの検証・ルーティング（`analysis_config.json` / `routing_decision.json` 生成） | 統計計算実行そのもの、非集約クラスターデータの強制投入 |
| **3次元集計表の探索・関連構造** | `vcd-bayesian-evidence-analysis` | 3次元正本（`three-way-results-v1`）、9階層対数線形モデル、新4軸セル診断、明示式BIC、多項Dirichlet事後推論、Dual-Filterスクリーニング、条件付きセル順位再現性（CRR）、HTMLダッシュボード | 2変数のみの単純解析、旧スコアによる自動判定、因果構造の断定 |
| **2次元名義カテゴリの関連・残差** | `vcd-categorical-analysis` | 2次元分割表の全体効果量（Cramér's V、Bergsma 補正）、Haberman型調整標準化残差ヒートマップ、estimand・不確実性、executive_summary、11セクションHTML生成 | 3次元以上の交互作用モデル比較、セルベイズ因子 |
| **比較群間エビデンス・多テーマスクリーニング** | `vcd-categorical-reporting` | 独立2群・対照群対比のエビデンス（RD/RR/方向支持/実務領域/U-Grade）、ゼロ参照群確定挙動（`mean=null, mean_is_finite=false`）、安全性（SOC/PT重複排除）、完全オフラインHTML | マッチドペア・IPTW等の依存デザイン、FWER厳格制御の主張、自動規制判定 |
| **デザイン考慮型比較推論** | `comparative-design-analysis` | 1:1マッチドペア（Dirichlet 厳密期待値）、1:kマッチドセット（固定条件付きクラスタブートストラップ）、IPTW（PS再適合患者ブートストラップ）、人年発症率（共役Gamma-Poisson推論） | 独立群用推論器への依存データ投入、GLMM/GEEモデリング、非整数度数のDirichlet投入 |
| **統計エビデンス決定監査・先例検索** | `evidence-decision-review` | 決定ラベル非含有特徴量プロファイル抽出（`evidence-feature-v1`）、Gower距離、階層クラスタリング（HAC）、歴史的先例検索、決定台帳（Ledger）、QA Review Candidate助言 | 自動規制決定（承認/棄却）、決定ラベルの直接クラスタリング投入、処方的判断 |
| **アンケート設問の量産・バッチ** | `questionnaire-batch-analysis` | 設定ファイルに基づく複数設問の自動バッチ実行、サマリー集約 | 設問ごとの統計的前提や因果構造の自動的正当化 |
| **SAS PROC FREQ 互換集計** | `sas-proc-freq` | PROC FREQ 互換度数集計、独立性検定、2×2効果量、Fisher正確検定、Monte Carlo推定 | Pass 0 対話相談、ベイジアン事後推論 |
| **SAS PROC MEANS 互換記述統計** | `sas-proc-means` | PROC MEANS 互換記述統計、CLASS層別、FREQ/WEIGHT、VARDEF、QNTLDEF 1〜5 | Pass 0 対話相談、因果推論 |

---

## 2. 現行 3 次元経路の基本原則

1. **Pass 0 の適用境界**:
   `vcd-categorical-analysis`と`vcd-bayesian-evidence-analysis`の新規分析、および `comparative-design-analysis`（非独立観測デザイン）ではPass 0を必須とする。`questionnaire-batch-analysis`や`vcd-categorical-reporting`では文脈に応じて推奨し、SAS互換スキル、単体・回帰テスト、コード・文書保守では要求しない。
2. **モデル比較の厳格性**:
   全主効果を含む 9 階層モデル（M1〜M9）を適合し、総度数 $N$ 基準のポアソン明示式 $\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$ により全体構造を評価する。
3. **新 4 軸セル診断の徹底**:
   セル単位の偏りは、単一のスコアに押し込めず、**Effect（効果量: $\log(O/E)$, $e_i^{(\mathrm{global})}$, $d_i$）**、**Evidence（証拠強度: $T_i^{\rm score}$, $\ln P$）**、**Influence（影響度: Leverage $h_{ii}$）**、**Stability（数値安定性: QUARANTINED 判定）** の 4 軸を明確に分離して報告する。
4. **探索的Dual-Filterの次元別境界**:
   2次元では$N \ge 2,000$、REGULAR、Effect（$|\log(O/E)| \ge 0.50$）、Evidence（$T_i^{\rm score} \ge 3.84$）を候補条件とする。3次元の現行候補条件はREGULAR、Effect、Evidenceであり、Nカットオフを含めない。いずれもFWER/FDR、実務的重要性、因果性、外部妥当性、再現性を保証しない探索的条件である。
5. **不確実性の誠実な報告**:
   多項 Dirichlet 共役事後推論により、条件付き割合や層間リスク差の点ごとの 95% 等裾信用区間（ETI）および Freeman-Tukey 事後予測チェック（PPP-value）を算出し、過分散や推定保留を明記する。
6. **条件付きセル順位再現性（CRR）の条件付け開示**:
   多項再標本化によるセル順位選択頻度を評価する場合、各反復で基準モデル（M1/M5）を再適合した局所効果比を用い、元データ `REGULAR` 適格セル集合への条件付けおよび運用品質ゲート（有効反復率 $\ge 0.95$）を明記する。因果効果、真の母集団重要性、患者・施設・時系列クラスタリングへの外挿を行ってはならない。

---

## 3. 比較エビデンスおよびデザイン推論の基本原則

1. **概念次元の厳格な分離**:
   \[
   \text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Region Resolution} \ne \text{Numerical Precision} \ne \text{Decision}
   \]
   - 方向支持指標（$P(RD > 0)$）はゼロより上の確率質量であり、実務的重要性や因果的優越性を証明しない。
   - 実務領域・U-Grade（U0〜U3）は不確実性分布の領域収まり具合（確信度）であり、標本サイズ・サンプリング精度（ESS/区間幅）や臨床的重症度とは完全に直交する。
2. **ゼロイベント・参照群ゼロ時の数理確定性**:
   - 参照群のイベント発生数がゼロ（$x_R = 0$）の場合、相対リスクの理論的期待値は $E(RR) = \infty$ となる。点推定値（中央値）および信用区間を報告しつつ、`mean = null`、`mean_is_finite = false` を確定し、有限な標本平均を代入してはならない。
3. **デザインと推論セマンティクスの整合**:
   - ベイズ事前分布モデル（Beta-Binomial、Dirichlet、Gamma-Poisson）は `inferential_semantics = "posterior"`、`interval.method = "posterior_eti"` とする。
   - リサンプリングモデル（IPTW、マッチドセット）は `inferential_semantics = "bootstrap"`、`interval.method = "bootstrap_percentile"` とし、`bootstrap_support_fraction` として表現する。
4. **自動規制決定の絶対排除**:
   - `evidence-decision-review` は決定ラベルを用いない客観的特徴量から歴史的先例との類似度を計算し、乖離を "QA Review Candidate" として提示する探索的ツールであり、規制判断（承認/不承認/警告）を自動化してはならない。

---

## 4. 旧指標の位置づけ（監査専用列）

旧Evidence Score（$r^2-k\ln N$）は監査専用列であり、新規分析の信号判定、セル合否、セルBayes factorとして使わない。これは、明示したセル追加モデルの局所尤度比、局所BIC改善量、Rao scoreを否定するものではない。これらは基準モデル、比較方向、尤度、パラメータ差、漸近近似、探索後解釈を識別して扱う。
