# TODO: 分析パイプラインの強化と保守

本日の作業により、4-Pass パイプラインが標準化されました。明日以降、以下の項目を順次実施することで、さらに堅牢なシステムへと進化させます。

## 明日の仕事始めの「最初の一手」
- [ ] **スモークテストの実行**: `tests/test_questionnaire_batch_smoke.R` を実行し、環境が正常であることを確認する。
- [ ] **Pass 0 のフル試行**: `examples/titanic.csv` を用いて、`vcd-pass0-consultation` からダッシュボード生成までの一連の「導き」がスムーズか再確認する。

## 優先度の高い改善項目 (High Priority)
- [ ] **対話ログの保存 (Traceability)**:
  - Pass 0 での AI との議論内容（なぜその変数を選んだか）を `discussion.log` として `run_dir` に保存する仕組みを `vcd-pass0-consultation` に追加。
- [ ] **JSON スキーマの導入**:
  - `analysis_config.json` のバリデーション用スキーマを作成し、Pass 0 の出力時にチェックをかける。
- [ ] **ポータブルなライブラリ環境**:
  - `.Renviron` またはプロジェクト内設定で `libPaths()` を固定し、書き込み権限エラーを恒久的に回避する。

## 中長期的な改善 (Backlog)
- [ ] **Google Fonts 連携**: `dashboard.Rmd` に Google Fonts を組み込み、日本語フォントがない環境でも文字化けしないようにする。
- [ ] **大規模データモードの自動閾値提案**: N数に応じて `threshold_k` の推奨値を Pass 0 が自動計算して提示する。

---
*Created on: 2026-04-19 by Gemini CLI*
