## MODIFIED Requirements

### Requirement: 共通テーマ CSS をインライン注入できる

Dashboard / HTML レンダラーは、`.agents/shared/dashboard_theme.css` に定義された NEJM / Nature Medical 調の共通スタイル（1px 枠線、`#F6F8FB` 背景、`#1F4D7A` アクセント、px 絶対指定フォント）を、単一 HTML の内部にインライン `<style>` として注入しなければならない（MUST）。対象は `vcd-bayesian-evidence-analysis`、`vcd-categorical-analysis`、`vcd-categorical-reporting`、`questionnaire-batch-analysis` が生成する Dashboard / HTML レポートとする。対象ページの背景・見出し・操作アクセントは共有学術テーマの値と一致しなければならず（MUST）、スキル固有のページクロムで上書きしてはならない（MUST NOT）。

#### Scenario: 2次元ダッシュボードで共通テーマを読み込む

- **WHEN** 2次元カテゴリカル分析のダッシュボードをレンダリングする
- **THEN** `.agents/shared/dashboard_theme.css` のスタイルが `<style>` タグ内に完全にインライン展開され、外部通信なしで同一の学術スタイルが適用される

#### Scenario: 3次元ダッシュボードで共通テーマを読み込む

- **WHEN** 3次元エビデンス分析のダッシュボードをレンダリングする
- **THEN** 同一の `.agents/shared/dashboard_theme.css` がインライン展開され、2次元と同一のデザイントークンで描画される

#### Scenario: 比較レポートで共通テーマを読み込む

- **WHEN** 比較エビデンスの HTML Dashboard を生成する
- **THEN** 共有 CSS が単一 HTML にインライン展開され、ページ背景・見出し・表頭・操作アクセントが学術テーマの値で描画される
- **AND** 既存の比較表の12列と操作機能を利用できる

#### Scenario: アンケートの HTML を共通テーマで生成する

- **WHEN** アンケートの Dashboard または個別 HTML レポートを生成する
- **THEN** 共有 CSS が単一 HTML にインライン展開され、`flatly` のページテーマと旧ネイビーのグラデーションに依存せず、共通の背景・見出し・アクセント色で描画される

## ADDED Requirements

### Requirement: 共通の色意味を保ち、表示面で統計指標を混同しない

対象 Dashboard / HTML は、行群色、残差の正負、隔離状態、実務領域の色を共通の学術パレットへ写像しなければならない（MUST）。色の変更によって効果量、方向支持、実務領域、精度の指標や意味を再計算・再判定してはならない（MUST NOT）。比較表の実務領域背景は当該セルだけに適用し、他列や行全体へ広げてはならない（MUST NOT）。

#### Scenario: 行群色と統計状態色を表示する

- **WHEN** カテゴリカル Dashboard が行群、正負残差、隔離セルを描画する
- **THEN** 同一の共通パレットの定義に従い、行群色と統計状態色を別の意味として表示する

#### Scenario: 比較表の実務領域セルを表示する

- **WHEN** 比較エビデンスの12列表で T、N、R または U3 の実務領域セルを表示する
- **THEN** T は `#9B2945`、N は `#1F4D7A`、R は `#64748B` と同系、U3 は低不透明度のスレート系で表示される
- **AND** 背景色は実務領域セルだけに適用され、RD、方向支持、精度などの列には波及しない
