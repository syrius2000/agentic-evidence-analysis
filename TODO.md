# TODO: 分析パイプラインの強化と保守

4-Pass パイプラインと 3 次元探索正本経路（新 4 軸セル診断、総度数 $N$ 基準の明示式 BIC、大標本 Dual-Filter 原則、多項 Dirichlet 事後推論）は実装・検証完了済みです。以下は受入後の保守運用項目および次期計画です。

## 受入後の運用・確認項目
- [x] **スモークテストの実行**: `tests/test_questionnaire_batch_smoke.R` 等を実行し、実行環境の健全性を確認。
- [x] **Titanic・HairEyeColor の全パス検証**: `output/statistical_foundations/verified_0906/` に検証記録を保存、QA-0001 にて Cycle 2 承認完了。
- [ ] **講座利用者・実務ユーザーによる確認**: レポートの説明量、新 4 軸の用語（Effect, Evidence, Influence, Stability）、HTML 図表が受講者に直感的に理解できるか確認。

## 優先度の高い改善項目 (High Priority)
- [ ] **対話ログの保存 (Traceability)**:
  - Pass 0 での AI との議論内容（変数選択理由、水準定義）を `discussion.log` として `run_dir` に保存する仕組みを `vcd-pass0-consultation` に追加。
- [x] **JSON スキーマの導入と検証**:
  - `analysis_config.json` のバリデーション（`test_vcd_bayesian_config_validation.R`）を実装・検証済み。
- [ ] **ポータブルなライブラリ環境**:
  - `.Renviron` またはプロジェクト内設定で `libPaths()` を固定し、書き込み権限エラーを恒久的に回避。

## 中長期的な改善課題 (Backlog)
- [ ] **Google Fonts 連携**: `dashboard.Rmd` に Google Fonts を組み込み、日本語フォントがない環境でもフォールバックで文字化けを防止。
- [ ] **実RWDの受入検証**: 実際の医療・購買データ 1 件を、標本単位・重複・分母・除外条件を確認してから Pass 0 で分析。
- [ ] **セル順位の再標本化安定性評価**: 基準モデル・指標・上位 K を固定し、個票ブートストラップまたは集計度数再標本化で上位 K 包含率、順位分布、適合成功率を評価（[意味論とセル順位安定性の整備計画](docs/Artifacts/semantic_governance_and_ranking_stability_plan_001_0907.md) 準拠）。

## 次期開発予定（合意事項）
- [ ] **SAS PROC FREQ 互換スキルの開発計画**: 集計済み度数データを必須入力とし、度数・割合・クロス集計・欠損処理の数値互換を担保。
- [ ] **SAS PROC MEANS 互換スキルの開発計画**: FREQ 互換とは別スキルとして計画。要約統計量、欠損・重みの扱いを確定。
- [x] **統計仕様の検証**: 9 モデル、新 4 軸セル診断、Dirichlet 事後、Titanic・HairEyeColor・人工表の検証完了。旧 Evidence Score（$r^2 - k\ln N$）は監査専用列に隔離。
- [x] **統計文書の正本化**: `docs/reference/` 配下を新 4 軸セル診断、明示式 BIC、大標本 Dual-Filter、多項 Dirichlet 推論、一次情報（DOI付き）で全面刷新。
