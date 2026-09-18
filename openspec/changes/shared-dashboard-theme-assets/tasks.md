## 1. 共有プレゼンテーション基盤の作成

- [x] 1.1 `.agents/shared/dashboard_theme.css` を新設し、NEJM / Nature Medical 調の共通スタイル（px絶対指定、フラット枠線、発散色、アコーディオン）を集約する
- [x] 1.2 `.agents/shared/dashboard_dt_ja.R` を新設し、外部 CDN 参照ゼロの完全インライン DataTables 日本語辞書リスト（`get_dt_ja_lang()`）を定義する
- [x] 1.3 `.agents/shared/dashboard_glossary.R` に共通定義・次元別項目・利用側コンテキストを実装し、design.md決定4の数学的訂正を反映する

## 2. テンプレートへの共有アセット適用

- [x] 2.1 `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd` の CSS および DataTables 辞書を `.agents/shared/` から読み込む構造へリファクタリングする
- [x] 2.2 `.agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd` の CSS および DataTables 辞書を `.agents/shared/` から読み込む構造へリファクタリングする
- [x] 2.3 両テンプレートから共通用語集を利用し、実際の主事前と感度事前、基準モデル、ゼロセル規約、条件付き割合の分母、変数名・区間水準を正しく渡す。共通化工程では計算値を維持し、旧3次元α=1.0の結果をJeffreysと表示しない

## 3. 回帰テストと完全オフライン検証

- [x] 3.1 2次元契約テスト（`tests/test_vcd_categorical_dashboard_v4.R`）の誤文言固定を訂正し、現行全件を実行して実測件数と失敗数を記録する
- [x] 3.2 3次元契約テスト（`tests/test_three_way_dashboard_html.R`）で再生成の終了コードを検証し、新規生成band/card両HTMLを対象に全件を実行して実測件数と失敗数を記録する
- [x] 3.3 生成された HTML に対して静的正規表現スキャンを実施し、Zero-External-Asset（外部通信・ローカル絶対パス 0 件）を確認する
- [x] 3.4 仕様の用語シナリオを検証する。レバレッジ閉形式とGLM、BIC定数差、2カテゴリ中央値の補数性、実際のα・ゼロ補正・候補条件・表示項目を確認し、同一事前での表示共通化前後のJSONおよび計算値の不変性を記録する
- [x] 3.5 用語集の実DOM構造、アコーディオン操作、オフライン表示、リポジトリ外作業ディレクトリでの共有資産解決と欠落時停止を検証する

## 4. 3次元主事前の移行（利用者追加指定、工程1〜3と区別する）

- [x] 4.1 `implementation_plan_008_0919.md` に従い、支持集合、主事前α=0.5、感度α=1.0、結果フィールドと設定・由来情報の変更箇所を確定する。構造的ゼロを疑似度数で生成しない
- [x] 4.2 3次元条件付き割合をDirichlet(y+0.5)で計算し、同じ入力・支持集合でα=1.0の感度結果を生成する。確率要約・群間差など全依存出力を同じ主事前にそろえる
- [x] 4.3 family、α、主／感度のrole、支持集合・Kを結果へ記録し、設定・run由来情報・結果ハッシュ・handoverに反映する。旧結果のラベルのみ変更せず新しいrunで生成する
- [x] 4.4 ゼロ・希少・大Nで希少・全ゼロ層・複数水準集約を検証し、Beta解析式とMC要約を照合する。主／感度の差と旧結果からの変化を記録し、Poissonモデル・局所診断の不変性を確認する
- [x] 4.5 結果契約・関連fixture・説明とテストを同期し、改定後の全要件を再検証する。規制当局がJeffreysを一律推奨するとの記載を含めない
