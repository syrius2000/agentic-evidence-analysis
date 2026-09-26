## Why

v4.0 で導入された 5 軸分離（Effect, Evidence, Influence, Stability, Posterior Uncertainty）および Interface 3.0 の設計方針を維持しつつ、実コード・テスト・成果物契約・Pass 0 プロベナンスの間に残存する不整合を修復・厳格化（Hardening）します。特に、共有層ですでに整備されている `pass0_contract.R` を 2-way スキルの実行入口へ接続し、Pass 0 から 2-way 分析への監査証跡を完全に確立します。

## What Changes

- **2-way 専任化と legacy コードの隔離**: `analysis.R` から残存していた 3-way 実行分岐、HairEyeColor 依存、および旧フォーマット結果 fallback を完全除去し、Arity=2 専任の実行系に純化します。
- **入力検証の先行実行（Fail-Fast 是正）**: データ集約やモデル適合より前に `validate_input_table()` を配置し、度数欠損や不正入力を解析開始前に確実に遮断します。
- **入力モードの厳格な安全契約**: `input_mode`（`"aggregated"` では freq 列必須、`"individual"` では freq 列指定禁止）を確立し、タイポや設定ミスを即時停止します。
- **Pass 0 Provenance 検証の必須化**: 共有モジュール `.agents/shared/pass0_contract.R` の `validate_pass0_provenance()` を接続し、入力 SHA-256、設定 SHA-256、対象スキル一致を解析前に検証します。
- **ゼロマージン表のフェイルファスト拒否**: 行和または列和が 0 の分割表を即時拒否し、推定不能な計算を防止します。
- **統計的契約の厳格化**:
  - 大標本 Dual-Filter ロジックの是正（$N < 2000$ では候補付与抑止）。
  - 期待度数診断（Cochran 条件）の追加。
  - practical delta の既定無効化（`null` 出力）。
  - 事前感度分析（$\alpha = 0.5$）の事後中央値および 95% ETI 比較要約。
- **解析署名（Canonical Analysis Signature）の一元化**: 実行ディレクトリ、RNG シード導出、結果 JSON、メタ情報、ダッシュボードで共通の一意な SHA-256 署名を使用します。
- **Dirichlet 事後推論ドロー数の統一**: 既定値を OpenSpec 仕様通りの 10,000 回に一元化します。
- **成果物 Schema 不変量検証と Run State ライフサイクル**: 確率総和・信用区間順序等の Cross-Field Invariant 検証および `run_state.json` 確定記録を配備します。
- **検証テストの整備**: スキルローカル `tests/` に v4.1 の実態（7 パターンの異常系を含む）を検証するテストスイートを配備し、実コード・テスト・仕様の完全な一致を保証します。

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities

- `two-way-evidence-analysis`: 入力受入境界（input_mode, ゼロマージン, Pass 0 プロベナンス）の厳格化、期待度数診断の導入、大標本 Dual-Filter 判定の是正、Dirichlet 事後感度分析の要約保持、解析署名の一元化、および成果物 Schema 不変量・Run State ライフサイクル要件を更新。

## Impact

- 影響範囲: `.agents/skills/vcd-categorical-analysis/`（`templates/analysis.R`, `R/*.R`, `tests/`）
- 共有依存: `.agents/shared/pass0_contract.R`, `.agents/shared/categorical/cramers_v_ci.R`
- 外部インタフェース: `categorical_results.json`（Interface 3.0 の構造を維持しつつ signature と candidate 判定精度を向上）
