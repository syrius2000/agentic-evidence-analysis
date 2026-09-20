## Context

現行の `vcd-categorical-analysis` は 2 次元分割表の Pearson 残差分析と可視化を中心に構成されているが、標本サイズ増大時の過剰検出や効果量と統計的証拠の混同、推定不確実性の未考慮という課題がある。
本設計では、`docs/Artifacts/Implementation-plan-vcd-categorical-analysis-v4.0.md` で合意された仕様に基づき、2 変数名義分割表に特化した「2-way categorical evidence & uncertainty analysis engine」を構築する。

## Goals / Non-Goals

**Goals:**

- 完全な 2 変数名義分割表（Complete 2-way table）に対する Poisson 独立 GLM に基づく 5 軸セル診断（Effect, Evidence, Influence, Stability, Posterior Uncertainty）の実装
- 対称 Dirichlet 事前分布（既定 $\alpha=1.0$）による共役事後推論と等裾 95% 信用区間（ETI）、各種生成量（結合、条件付き、独立性乖離）の算出
- 非心カイ二乗反転求根による Cramér's V 信頼区間（未補正および Bergsma bias-corrected 補正後）の厳密な算定と端点単調性の保証
- 決定論的乱数シード生成と要約値のみのメモリ保存ポリシー（生ドローの非永続化）
- Interface 3.0 (`two-way-results-v2`) 構造化 JSON 結果契約（非有限値の安全な表現）
- 外部 CDN やリモート通信に一切依存しない完全オフライン・自己完結型の Scientific Dashboard HTML 生成と静的検査
- 多標本・極端値・大標本における厳密なユニットテストおよび再現性テストの整備

**Non-Goals:**

- 構造的ゼロ（発生不能セル）を含む不完全分割表（Incomplete table）や準独立モデルのサポート（本エンジンの対象外・入力禁止）
- 3 次元対数線形モデル体系（M1〜M9 比較等）の複製（3-way は `vcd-bayesian-evidence-analysis` の専任）
- 4 次元以上の一般対数線形モデル対応
- 頻度論 $p$ 値とベイズ事後確率の統合スコア化
- 旧スコア（`Evidence Score = r² - k log(N)`）の存続
- 事後密度プロットやバイオリンプロットを主要表示とすること
- 実務的有意差閾値（`practical_effect_delta`）の恣意的な自動判定

## Decisions

### 1. 入力受入境界と構造的ゼロの禁止（OutOfScope 契約）

- **決定**: 本エンジンは完全な 2 変数名義分割表専用とし、入力次元数は厳密に 2（Arity = 2）、各軸水準数 $I \ge 2, J \ge 2$、総度数 $N > 0$、度数は有限非負整数のみを受理する。3 次元以上の入力は即時フェイルファスト停止し、正本スキル `vcd-bayesian-evidence-analysis` への委譲を案内する。また、構造的ゼロ（理論的に発生不能なセル）は準独立モデルという別 estimand を要するため入力禁止とし、指定時は即時停止（`STRUCTURAL_ZERO_NOT_SUPPORTED`）とする。観測 0 はすべて偶然のサンプリングゼロとして一貫処理する。
- **理由**: 構造的ゼロとサンプリングゼロの混同による独立モデル適合の破綻を防ぎ、2-way 解析エンジンの責務境界を明確にするため。

### 2. Poisson GLM による独立モデルと canonical residual / evidence の定義

- **決定**: Poisson 独立 GLM $\log \mu_{ij} = \lambda + \lambda_i^A + \lambda_j^B$ を適合し、Hat 行列の対角成分から Leverage $h_{ij}$ を算出。調整残差 $r^{\rm adj}_{ij} = r^P_{ij} / \sqrt{1 - h_{ij}}$ を canonical residual、局所 Rao スコア統計量 $T^{\rm score}_{ij} = (r^P_{ij})^2 / (1 - h_{ij})$ を canonical evidence とする。
- **理由**: 2 次元分割表における Haberman 型標準化残差と正確に一致し、セルごとの影響度（Leverage）を反映した公平な評価が可能となるため。

### 3. Cramér's V 信頼区間の厳密算定（非心 $\chi^2$ 反転と Bergsma 変換）

- **決定**: Smithson (2003) / Steiger (2004) に基づき、観測 $X^2$ に対する非心カイ二乗累積分布関数 $F(X^2; df, \lambda)$ を数値求根（`stats::uniroot`）して非心度 $\lambda$ の 95% 信頼区間 $[\lambda_L, \lambda_U]$ を導出（$X^2 \le \chi^2_{0.975}(df)$ のときは $\lambda_L = 0$）。
  - 未補正 Cramér's $V$: $V_* = \sqrt{\frac{\lambda_*/N}{\min(I,J)-1}}$
  - Bergsma (2013) bias-corrected Cramér's $V$: 有効次元 $\tilde{k} = \min\left(I - \frac{(I-1)^2}{N-1}, J - \frac{(J-1)^2}{N-1}\right)$ を用い、$\tilde{V}_* = \min\left(1, \sqrt{\frac{\max(0, \lambda_*/N)}{\tilde{k}-1}}\right)$
  - $\lambda \mapsto \tilde{V}$ は狭義単調非減少であるため、端点順序 $0 \le \tilde{V}_L \le \tilde{V}_U \le 1$ が数学的に保証される。JSON 契約では未補正 `cramers_v_ci` と補正後 `cramers_v_corrected_ci` を分離して保持する。退化表や小標本（$\tilde{k} \le 1$ 等）では `null` とし quality warning を付与する。
- **理由**: RNG 非依存の決定論的な信頼区間を保証し、推定量と CI の対応関係を数学的に厳密化するため。

### 4. セル安定性 Quarantine と非有限値の安全な表現

- **決定**: 以下のいずれかに該当するセルを `QUARANTINED` とし、理由コード配列を付与する。
  1. 観測度数ゼロ ($O_{ij} = 0$)
  2. 期待度数僅小 ($E_{ij} < 5$)
  3. 高レバレッジ ($h_{ij} \ge 0.80$)
  $O=0$ の場合、対数効果比 $\log(O/E)$ の理論値 $-\infty$ は標準 JSON の数値型に適合しないため、`log_oe: null`, `log_oe_state: "NEGATIVE_INFINITY"`, `is_finite: false` として出力する。Dashboard 散布図の通常軸からは除外し、隔離テーブル上に明示表示する。
- **理由**: スキーマ検証エラーやパーサークラッシュを防止し、極端値セルを教育的に明示するため。

### 5. 大標本 Dual-Filter 原則

- **決定**: $N \ge 2000$ の場合、探索的候補（Exploratory dual-filter candidate）の判定に「Effect: $|\log(O/E)| \ge 0.50$」かつ「Evidence: $T^{\rm score} \ge 3.84$」を要求する。ゼロセルおよび Quarantine セルは候補から自動除外する。
- **理由**: 大標本下では微小な偏りでも統計的有意となりやすいため、実質的な効果量と統計的証拠の双方を必須条件として過剰検出を抑制する。

### 6. 多項 Dirichlet 事後推論とメモリポリシー

- **決定**: 多項尤度に対する共役事前分布 $\text{Dirichlet}(\alpha, \dots, \alpha)$（既定 $\alpha=1.0$）を採用。10,000 回のモンテカルロドローから生成量（$\pi_{ij}$, $P(B|A)$, $P(A|B)$, 独立性乖離 $D_{ij}$）の事後要約（平均, SD, Q2.5, Q25, Q50, Q75, Q97.5, 区間幅, $P(D>0)$）のみを算出して保持し、生ドロー配列は JSON に保存しない。乱数シードは `analysis_signature` より決定論的に導出する。
- **理由**: 共役性により高速かつ正確にサンプリング可能であり、生ドローを破棄して要約値のみを保持することで JSON ファイルの肥大化とダッシュボード読み込み遅延を防止するため。

### 7. 完全オフライン Scientific Dashboard と静的受入検査

- **決定**: 外部リソース（Google Fonts, CDN, 外部 MathJax, DataTables 外部辞書 URL）を一切排除。システムフォントスタック、ローカル KaTeX、インライン日本語辞書付き DataTables を用い、HTML 1 ファイルで完全自己完結させる。生成された HTML に対し、正規表現による静的外部 URL スキャン検査を実施し、外部通信依存を機械的に遮断する。
- **理由**: 製薬企業・機密 RWD 環境における閉域網（エアギャップ）での動作を保証し、回帰を自動検出するため。

### 8. 結果契約 Interface 3.0

- **決定**: `interface_version = "3.0"`, `schema = "two-way-results-v2"` とし、旧形式の `Evidence Score` やフラットなセル配列を排し、`global`, `cells`, `posterior`, `quality`, `provenance` に構造化する。

## Risks / Trade-offs

- **[Risk 1: 既存コンシューマとの後方互換性破壊]** $\to$ **Mitigation**: `interface_version` を 3.0 に明示的にメジャーバンプし、旧バージョン（2.x）を期待するパーサーに対しては明確なスキーマバージョンエラーまたは警告を出力する。
- **[Risk 2: 外部 CDN 混入の見落とし]** $\to$ **Mitigation**: 生成 HTML に対する静的正規表現スキャンをユニットテストに必須化し、CI/CD で自動検出する。
- **[Risk 3: 小標本・退化表での Bergsma 補正不能]** $\to$ **Mitigation**: $\tilde{k} \le 1$ 等で分母非正となる場合は `cramers_v_corrected_ci` を安全に `null` とし、`quality_warnings` に明確な理由を記録する。

## Migration Plan

1. **Phase 0**: 契約・スキーマ・定数の確定（Interface 3.0 freeze, 入力受入境界、構造的ゼロ禁止）
2. **Phase 1**: Poisson 独立 GLM・残差・レバレッジ・Quarantine・非有限値 JSON 実装
3. **Phase 2**: 効果量・スコア統計量・Dual Filter・非心 $\chi^2$ Cramér's V CI 実装
4. **Phase 3**: 多項 Dirichlet 事後推論・決定論的 RNG・要約統計量生成
5. **Phase 4**: 条件付き確率・独立性乖離・区間幅・事前感度実装
6. **Phase 5**: Interface 3.0 JSON シリアライザ・バリデータ・テスト群
7. **Phase 6**: 完全オフライン Scientific Dashboard Rmd 刷新・静的受入検査
8. **Phase 7**: AI Narrative / SKILL.md ガイドライン改定・実データ検証
