## Why

3次元カテゴリカル分析のダッシュボードは、Antigravity版とmain版で、モデル比較、セル指標、説明文、表示契約が分岐している。統計的に整合した一つの正本経路へ統合し、非専門家が結論を読み取れ、分析者が数値根拠を追跡できる完全オフラインHTMLを再現可能に生成する必要がある。

合意した範囲と承認境界は、[AG版・M版ダッシュボードの統合改善計画](../../../docs/Artifacts/implementation_plan_013_0912.md)を上位の意思決定記録とする。

## What Changes

- Antigravity主系の3次元M1〜M9、因子凡例、ポアソン明示式BIC、最良モデル表示をmain側の正本生成経路へ選択移植する。
- M1相互独立基準とBIC最良モデル基準のセル診断を別々に保存・表示し、Effect・Evidence・Influence・Stabilityと分母付き件数を混同なく提示する。
- 旧Evidence Scoreを監査専用へ隔離し、探索候補、セルBF、実務的重要性の判定に使用しない。
- `conditional_rate_view` に応答、分子、分母、比較、層別、区間、参照水準を明示し、条件付き割合と事後信用区間を汎用的に生成する。設定不足や適用不能は理由付き部分HOLDにする。
- エグゼクティブサマリーを平易な要約、統計的根拠、限界と次の確認の3層にし、`narrative_claims.json`で結果ハッシュと引用数値を照合する。
- M1〜M9比較表をBIC昇順で開始し、モデル名、生成クラス、自由度、逸脱度、BIC、ΔBICで並べ替え可能にする。
- MathJaxとDataTablesロケールのCDN参照を除去し、KaTeXによる生成時数式変換と埋め込み資産で、デスクトップ向け単一HTMLを完全オフライン化する。
- AG旧UI参照版とUCB Admissions新標準版を、ハッシュ・依存版・生成条件付きの受入fixtureとして保存する。
- `templates/three_way/`は削除せず、互換性維持のみの非正本経路として明示する。
- **BREAKING**：新規結果JSONはセル診断を基準モデル別の構造へ変更し、新規設定では無効な基準モデルや曖昧な条件付き割合を暗黙補完せず拒否または部分HOLDにする。旧JSONの読込互換は表示側に限定する。

## Capabilities

### New Capabilities

- `three-way-dashboard-reporting`: 3次元M1〜M9、ポアソン明示式BIC、因子凡例、根拠追跡可能な3層サマリー、列ソート、完全オフラインHTML、再現情報の表示契約。
- `multi-baseline-cell-diagnostics`: M1基準と選択モデル基準の4軸セル診断、分母付き件数、基準別JSON、旧指標監査、HOLDの契約。
- `conditional-rate-view`: Pass 0で明示した分子・分母・比較・層別に基づく条件付き割合、Dirichlet事後区間、汎用可視化、部分HOLDの契約。

### Modified Capabilities

該当なし。現時点で `openspec/specs/` に同期済みの正本仕様がないため、本changeでは上記3機能を新規delta specとして定義する。既存の `validate-three-way-statistical-foundations` changeは参照するが、その未完了タスクを変更または完了扱いにしない。

## Impact

- 対象は `.agents/skills/vcd-bayesian-evidence-analysis/` の主系テンプレート・設定schema・文書、`.agents/skills/vcd-pass0-consultation/`、`.agents/shared/analysis_quality_contract.md`、関連テスト・fixture、ルートREADMEである。
- KaTeX関連Rパッケージを明示依存として追加し、実使用版と第三者ライセンスを記録する。`renv`は導入しない。
- 実装は最新`origin/main`から分離した `codex/dashboard-unification` Worktreeで行い、現在のmainとAntigravityの既存差分・出力を保持する。
- 2変数分析、質問票バッチ、モバイル対応、非カテゴリカル・非集計度数データへの自動適用、旧経路削除、commit、mainへのmerge、pushは対象外とする。
