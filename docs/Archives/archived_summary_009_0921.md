# アーカイブ済みArtifactの要約 (Batch 009)

- **created**: 2026-09-21 19:55 (JST)
- **author**: Antigravity
- **対象期間**: 2026-09-20 20:25 (JST) 〜 2026-09-21 19:50 (JST)
- **archive_batch_id**: 20260921_195500_009
- **source_count**: 1

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` に配備されていた実装計画書 `implementation_plan_021_0920.md`（OpenSpec 現行仕様との整合性確保および多重正本乖離解消計画）を精査・完了確認し、原本を `docs/Archives/20260921_195500_009/sources/` へ退避・集約したアーカイブです。

この期間において、本リポジトリは以下の重要課題を完遂しました：

1. **正本単一性の確立（OpenSpec 最上位規約の執行）**:
   「`openspec/specs/` が規範的挙動（WHAT）の唯一の正本（Single Source of Truth: TRUE）であり、`README.md`、`docs/reference`、`SKILL.md` は Spec から派生・整合させる」原則を厳格に執行。過去の経緯や周辺記述を理由に Spec 側を改ざんする誤りを排除。
2. **多重正本乖離（F-01〜F-09）の完全解消**:
   - **F-01（2次元 CLI）**: `vcd-categorical-analysis/SKILL.md` の実行例を canonical な `--config` 経路へ統一し、旧引数（`--data` 等）を排除。
   - **F-02（Pass 0 事前分布）**: `vcd-pass0-consultation/SKILL.md` の 3-way 設定例を現行 schema / Spec 通りの `dirichlet_prior`（主事前 $\alpha=0.5$、感度分析 $\alpha=1.0$）に改定。
   - **F-03（Pass 0 適用範囲）**: 必須（2-way/3-way）、文脈推奨（アンケートバッチ）、対象外（SAS互換・テスト・保守）の適用境界を `AGENTS.md` 鉄則2に基づき統一。
   - **F-04（Dual-Filter 規約）**: 2次元（$N \ge 2,000$ 必須）と 3次元（現行候補式に $N$ 閾値を含めない）を分離し、FWER/FDR・実務的重要性の非保証を明記。
   - **F-05（旧エビデンススコア）**: $r^2 - k\ln N$ を監査専用列（audit-only）として位置づけ、再適合による局所BIC差やRaoスコア検定との数理的差異を明文化。
   - **F-06（回帰テスト台帳）**: `tests/run_regression_suite.R` を R 正規回帰テストの動的台帳として確立。
3. **Change `align-vcd-analysis-routing` の完遂とアーカイブ**:
   2次元調整標準化残差ヒートマップ、3次元 Facet 残差マトリクス、estimand 峻別、2-way/3-way 委譲契約を実装し、`/opsx-archive` により正本 Spec へ同期完了。
4. **全自動検証の完全合格**:
   R 正規回帰テスト全 31 本が 100% PASS、OpenSpec strict validate 全 12 specs 合格、Python 契約テスト 12 件合格。

---

## 2. 確定した決定と理由

| 計画・記録文書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| `implementation_plan_021_0920.md` | OpenSpec（`openspec/specs/`）を絶対正本とし、周辺ドキュメント・スキル・テストをそれに完全追従させる。 | 実装・ドキュメント・Spec 間に生じていた二重正本（F-01〜F-09）を恒久解消し、保守性と再現性を担保するため。 | §3.1 |
| 同上 | 2次元・3次元の Dual-Filter 契約を厳密に分離（2次元: $N \ge 2,000$, 3次元: $N$ カットオフなし）。 | 標本サイズ $N$ の影響とモデル自由度消費の違いを正しく扱い、探索的着目セル選定の数理的性質を保つため。 | §3.2 |
| 同上 | 旧エビデンススコアを監査専用列（audit-only）として保持し、合否判定や候補抽出に使わない。 | 度数 100 倍実験等で示された線形対数ペナルティの限界を踏まえ、局所モデル比較（再適合逸脱度改善）と区別するため。 | §3.2 |
| 同上 | `tests/run_regression_suite.R`（`official_tests`）を機械可読台帳とし、固定本数アサーションを廃止。 | テスト追加に伴う Spec の陳腐化を防ぎ、決定論的な回帰検証基盤を維持するため。 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 仕様・運用の整合化成果

- **正本 Spec の更新**:
  - `openspec/specs/two-way-evidence-analysis/spec.md`: 2次元専用入口および調整標準化残差ヒートマップ要件を反映。
  - `openspec/specs/three-way-dashboard-reporting/spec.md`: 3次元 Facet 残差マトリクスおよび条件付き estimand 要件を反映。
- **ドキュメント・スキルの整列**:
  - `README.md`、`AGENTS.md`、`docs/reference/`、`.agents/skills/` の全記述が正本 Spec と完全一致。

### 3.2 統計解析の実証（UCB Admissions）

- `examples/ucb_admissions.csv`（$N = 4,526$）に対する完全パイプライン実行により、最良モデル M5（$[DA][DG]$, $\Delta\mathrm{BIC} = 0.0$）が同定され、Simpson's Paradox（出願学科の交絡による見かけの性差）が対数線形モデルの条件付き独立性によって定量的・数理的に証明されることを確認。

### 3.3 検証の限界と成立条件

- **多重性の未調整**:
  残差診断や Dual-Filter スクリーニングの閾値（$T_i^{\rm score} \ge 3.84, |\log(O/E)| \ge 0.50$）は探索的足切りであり、Family-Wise Error Rate（FWER）や False Discovery Rate（FDR）を保証するものではありません。
- **因果推論の非保証**:
  対数線形モデルや多項事後推論による関連構造の同定は、観測データに基づく統計的記述であり、未観測交絡（サブグループ等の交絡因子）が存在しないことを無条件に保証するものではありません。

---

## 4. 未解決事項と引継ぎ

- **後続タスク**:
  - 本アーカイブ完了後、Git 上の作業ツリーを整理し、最新の安定マイルストーンとしてコミット・PUSH を行う。
  - 今後新しい機能改定を行う場合は、必ず OpenSpec Change（`openspec/changes/<change-name>/`）を作成して進める。

---

## 5. 元文書と復元情報

| 元ファイルパス | 退避先（アーカイブ原本） | 復元方法（Gitコミット） | 状態 |
| :--- | :--- | :--- | :---: |
| `docs/Artifacts/implementation_plan_021_0920.md` | `docs/Archives/20260921_195500_009/sources/implementation_plan_021_0920.md` | `git checkout 3c018e5 -- docs/Artifacts/implementation_plan_021_0920.md` | **完了・退避** |
