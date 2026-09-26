# UCB Admissions 分析品質確認・監査証跡 (Quality Check)

- **対象 run**: `run_ucb_admit_standa`
- **検証日時**: 2026-09-12 JST
- **正本計算エンジン**: `vcd-bayesian-evidence-analysis` (canonical 4-axis multi-baseline)

---

## 1. 入力完全性と再現性検証

| 項目 | 検証値 | 状態 |
| :--- | :--- | :--- |
| **入力データ** | `examples/ucb_admissions.csv` | 適合 |
| **入力 SHA-256** | `3c869703114951dfac2b3bb72b41ea4efaface26a5fc84e64b3358efe409cf54` | 一致 |
| **総度数 ($N$)** | 4,526 | 完全一致 |
| **セル数** | 24 完全セル（欠損なし、観測ゼロなし） | 適合 |
| **結果 JSON SHA-256** | `245bc18dfa90655aad215ec267a87ee4d1cbac5dde3271555dd7edaad508c55d` | 検証済み |

---

## 2. 数理仕様および契約検証

1. **ポアソン完全対数尤度による明示式 BIC**:
   - R 既定の `stats::BIC`（行数 24 基準）や Deviance 式への置換は行われておらず、総度数 $N=4,526$ 基準の明示式 $\mathrm{BIC} = -2\ln L + p\ln N$ を厳格に使用。
   - M5: $\mathrm{BIC} = 332.3119$
   - M8: $\mathrm{BIC} = 339.1982$
   - 既存の固定数値参照との完全一致を確認済み。
2. **多重基準セル診断 (M1 / M5)**:
   - M1 基準（相互独立）および M5 基準（条件付き独立）の 2 基準診断が別個の名前空間に出力されている。
   - 旧 Evidence Score は監査専用列（`evidence_score_legacy`）に隔離され、真の信号判定やセル合否の自動判定には一切使用されていない。
3. **主張ゲート (Pass 2.5 Claims Gate)**:
   - `narrative_claims.json` の 12 件の数値主張が `evidence_results.json` と完全一致（許容誤差 $10^{-4}$ 以内）。
   - 改変ハッシュおよび存在しない Pointer の拒否機能を確認済み。
