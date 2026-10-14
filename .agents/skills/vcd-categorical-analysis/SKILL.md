---
name: vcd-categorical-analysis
description: "Use when performing nominal two-way categorical analysis through the profile, render, expert narrative, quality-check, and dashboard workflow."
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "4.1"
---

名義カテゴリカル変数の **完全2次元分割表（Arity=2）専用**の独立性検定（Poisson GLM）、局所診断（Haberman 調整残差・Rao スコア）、大標本 Dual-Filter、多項 Dirichlet 事後推論、および完全オフライン Scientific Dashboard の生成を行う。

3次元以上の多次元探索や階層対数線形モデル（M1〜M9）は、正本スキル `vcd-bayesian-evidence-analysis` へ委譲する。

---

## 1. 共通品質契約と入力境界

本スキルは `.agents/shared/analysis_quality_contract.md` を厳格に遵守する。

| 項目 | 契約仕様 | 違反時の挙動 |
| :--- | :--- | :--- |
| **次元数（Arity）** | 厳密に2（$I \ge 2, J \ge 2$） | `INVALID_INPUT_ARITY` でフェイルファスト停止し、3-way正本スキルへ委譲案内 |
| **度数** | 有限非負整数（$N > 0$） | 欠測・負値・非整数重みは即時停止（`NON_INTEGER_COUNTS` 等） |
| **構造的ゼロ** | **入力禁止**（サンプリングゼロのみ許容） | `STRUCTURAL_ZERO_NOT_SUPPORTED` で即時停止し準独立モデル案内 |
| **その他入力検証例外** | 想定外または非構造化検証エラー | `INPUT_VALIDATION_FAILED`（フォールバック）で即時停止し `run_meta.json` に記録 |
| **出力先** | `evidence_runs/vcd_categorical/` またはその配下にある明示root内の `run_<canonical_id>[_N]/` | namespace外・`..`・symlink逸脱は拒否。衝突時は自動サフィックス分離 |

---

## 2. 必須ワークフロー（Pass 0 + エージェント3ステップ）

1. **Pass 0（Consultation）**: `vcd-pass0-consultation`で入力品質、変数、度数列、構造的ゼロ、標本単位、実務上の問いを確認し、承認済みの`analysis_config.json`を確定する。
2. **Step 1（Canonical R）**: 確定設定から`categorical_results.json`（Interface 3.0）、`residuals_table.csv`、`quarantine_cells.csv`、`session_info.txt`、統制メタデータ（`run_meta.json`）、および改ざん検知マニフェスト（`results_manifest.json`）を生成する。出力root直下には `runs_index.jsonl` および `latest.json` が更新される（run ディレクトリ内の `run_state.json` は廃止・`run_meta.json` に一本化）。
3. **Step 2（AI Review）**: JSONを読み、7ステップ考察契約に従って日本語の`executive_summary.md`を作成する。
4. **Step 3（Report）**: 完全オフライン`dashboard.Rmd`をレンダリングし、調整標準化残差、条件付きestimand、効果量、不確実性を中心とした外部リソースゼロの`dashboard.html`を生成・確認する。モザイク図は現行canonicalの主表示・必須成果物ではない。

---

## 3. R エンジンの実行方法

### Canonical実行

```bash
Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R \
  --config path/to/analysis_config.json \
  --out ./evidence_runs/vcd_categorical/ \
  --label datasetA
```

`--config`、`--out`、`--label`、`--help`以外の引数はcanonical経路では使いません。`--data`、`--vars`、`--freq`、`--input-mode`、`--prior-alpha`、`--practical-delta`などで解析条件を上書きすると、`CANONICAL_CONFIG_OVERRIDE_FORBIDDEN`で停止します。

開発・テスト用の非canonical経路は成果物を生成せず、運用上のcanonical実行例として使用しません。

### 実行同一性と再開

canonical実行は `requested_run_id`、`analysis_signature`、`run_state` を記録し、出力先を `<out>/run_<first16>[_N]/` として予約します。予約は atomic reservation で行い、同一署名の並行実行は `.run_locks/<signature16>.lock` により排他されます（先行実行中は `CONCURRENT_RUN_IN_PROGRESS` で停止）。

#### 強制終了（SIGKILL等）後のロック復旧手順

プロセスが `kill -9` や不意のシステム停止によって強制終了された場合、ロックディレクトリが残存して再実行が `CONCURRENT_RUN_IN_PROGRESS` で拒絶されることがあります。この場合は、エラーメッセージに表示されたロックパスを確認し、削除前に `lock_info.json` の pid が生存していないこと（`ps -p <pid>`）を確認した上で、手動で削除することで復旧できます：

```bash
# 1. 保持プロセスの生存確認（出力が空、または該当プロセスが存在しないことを確認）
cat <out_root>/.run_locks/<signature16>.lock/lock_info.json
ps -p <pid>

# 2. ロックディレクトリの手動削除（ロックパス例: evidence_runs/vcd_categorical/.run_locks/<signature16>.lock）
rm -rf <out_root>/.run_locks/<signature16>.lock
```

---

## 4. Step 2 AI Narrative の 7ステップ考察契約

`references/ai-narrative-workflow.md` に従い、以下の順序で記述する：

1. **全体関連構造**: $\chi^2, G^2$、自由度、$p$ 値
2. **効果の大きさ**: 未補正 Cramér's $V$ と bias-corrected $\tilde{V}$（95% CI）
3. **統計的証拠強度**: $\log(O/E)$、Rao スコア $T^{\rm score}$、大標本 Dual-Filter 候補
4. **局所診断と安定性**: Quarantine 判定（ゼロセル、低期待度数、高レバレッジ）
5. **ベイズ事後不確実性**: 多項 Dirichlet 95% ETI 信用区間
6. **条件付き割合と実務解釈**: $P(B|A), P(A|B)$
7. **制約事項と次アクション**: 限界、交絡、3次元以上への移行案内

**禁止事項**:

- P値単独判定
- 観測ゼロセルの対数比0扱い（$-\infty$ 隔離セルとして扱うこと）
- 英語本文（数式・記号除く）
- 残差符号の未確認解釈

### Pass 2.5: 品質確認

Pass 2の後、同じrun出力に`quality_check.md`を作成し、P値偏重、効果量とEvidenceの混同、隔離セルの過大解釈、図表と本文の不整合、未解決の解釈保留を確認します。重大な未解決事項があれば、完成扱いにせず理由を明記します。
