# UCB Admissions 分析品質確認・監査証跡 (Quality Check)

- **対象 run**: `run_ucb_jeffreys_091`（run_id: `ucb_jeffreys_0919`）
- **検証日時**: 2026-09-19 JST
- **正本計算エンジン**: `vcd-bayesian-evidence-analysis`（canonical 4-axis multi-baseline）

---

## 1. 入力完全性と再現性

| 項目 | 検証値 | 状態 |
| :--- | :--- | :--- |
| 入力データ | `examples/ucb_admissions.csv` | 適合 |
| 入力 SHA-256 | `3c869703114951dfac2b3bb72b41ea4efaface26a5fc84e64b3358efe409cf54` | 一致 |
| 総度数 ($N$) | 4,526 | 一致 |
| セル数 | 24（観測ゼロなし） | 適合 |
| 結果 JSON SHA-256 | `19289826998d061ee62e943d8e1fe662e6801cc0b67be0d28300674f1cd4736a` | 検証対象 |
| 主事前 | symmetric Dirichlet α = 0.5（jeffreys） | 結果メタデータと一致 |
| 感度事前 | α = 1.0（uniform） | 結果メタデータと一致 |
| 支持集合 | observed_table_rows, K = 24 | 構造的ゼロ未生成 |

---

## 2. 数理仕様および契約

1. **明示式 BIC（総度数 N 基準）**
   M5 = 332.3119、M8 = 339.1982。Poisson モデル比較は本事前移行で変更していない。
2. **多重基準セル診断**
   M1 候補 12、M5 REGULAR 13 / QUARANTINED 11 / 候補 1。旧 Evidence Score は監査列のみ。
3. **条件付き割合**
   主解析は Dirichlet(y+0.5)。感度は同一支持集合で α = 1.0。旧 fixture（α 記録なし）を Jeffreys と再ラベルしていない。
4. **P 値単独判定の排除**
   考察は BIC・条件付き割合・層別差・候補条件を併用し、全体検定の有意差のみで実務重要性を断定していない。
5. **解釈保留**
   因果・公平性の断定、候補セルの合否自動判定、区間狭さ＝重要性、を禁止。

---

## 3. Pass 2.5 Claims Gate

`narrative_claims.json` の数値主張を `evidence_results.json` と照合する（許容誤差 $10^{-4}$）。照合成功後に本番 `dashboard.html` を生成する。
