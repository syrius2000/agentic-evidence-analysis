# アーキテクチャとモジュール構成

本ディレクトリ構成は、vcd-categorical-analysis v4.0 における単体責任原則と再利用性を担保する。

---

## ディレクトリ構造

```text
.agents/skills/vcd-categorical-analysis/
├── SKILL.md                          # スキル定義
├── references/                       # 仕様・数理・AIガイドライン
│   ├── interface.md                  # Interface 3.0 データ契約
│   ├── workflow.md                   # 実行ワークフロー
│   ├── architecture.md               # 本ドキュメント
│   └── ai-narrative-workflow.md      # AI Narrative 7ステップガイド
├── schemas/
│   └── categorical_results_v3.json   # Interface 3.0 JSON Schema
├── R/                                # 分割Rモジュール
│   ├── validate_input.R              # 境界検証・構造的ゼロ・arity検証
│   ├── residual_diagnostics.R        # Poisson GLM, Pearson/Deviance/Haberman残差, Leverage
│   ├── effect_evidence_metrics.R     # log(O/E), Raoスコア, Cramér's V CI (Smithson/Steiger/Bergsma)
│   ├── dirichlet_posterior.R         # 多項Dirichlet事後推論・サンプリング・条件付き確率
│   └── serializer_v3.R               # Interface 3.0 JSON / CSV エクスポート
├── templates/
│   ├── analysis.R                    # 2パス実行エントリーポイント
│   └── dashboard.Rmd                 # 完全オフラインScientific Dashboard
└── tests/                            # スキル個別ユニットテスト

.agents/shared/categorical/           # カテゴリカル共通基盤
└── cramers_v_ci.R                    # 非心カイ二乗反転求根共通ルーチン
```

## 依存関係ルール

1. `validate_input.R` は外部依存を持たず、基本R関数だけでフェイルファスト検証を行う。
2. `effect_evidence_metrics.R` の Cramér's V CI 求根は `stats::uniroot` を用いて決定論的かつ解析的に計算する（RNG非依存）。
3. `dirichlet_posterior.R` のサンプリングは `analysis_signature` からの決定論的シードを用い、生ドローをメモリ・JSONに永続化しない。
4. すべてのスクリプトは事前導入済みライブラリのみを用い、実行時インストール（Fail-Fast原則）を絶対に行わない。
