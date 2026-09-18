## Context

背景は [proposal.md](proposal.md) の Why を参照。
2次元および3次元のダッシュボードテンプレート（`dashboard.Rmd`）において、NEJM / Nature Medical 調の CSS スタイルや DataTables インライン辞書が重複定義されている。本設計は、これらのプレゼンテーション資産を `.agents/shared/` に一元化し、単一スタンドアロン HTML 契約を維持したまま DRY を達成するアーキテクチャを定める。

## Goals / Non-Goals

**Goals:**

- **プレゼンテーション資産の一元化**: `.agents/shared/dashboard_theme.css` および `.agents/shared/dashboard_dt_ja.R` を配備し、複数スキル間で完全に共通利用する。
- **完全インライン注入の維持**: ビルド時に R スクリプトから CSS を読み込み、`<style>` タグ内に直接インライン展開することで、単一自己完結型 HTML（Zero-External-Asset 原則）を死守する。
- **px 絶対指定タイポグラフィの保護**: Bootstrap 3 の `html { font-size: 10px; }` による `rem` 縮小破壊を恒久的に防ぐため、共通 CSS 内で `px` 単位を厳格に維持する。

**Non-Goals:**

- Poisson GLM、局所診断、候補判定の計算は変更しない。利用者指定による3次元Dirichlet主事前α=0.5への移行、α=1.0感度分析、必要な結果メタデータの追加は対象に含める。
- ユーザー選択によるダークモードの動的切り替え UI は導入しない。

## Decisions

### 1. 共通 CSS の完全インライン注入方式

- **決定**: `<link rel="stylesheet" href="...">` を使わず、Rmd の setup chunk で `readLines()` を用いて `<style>` タグ内に全 CSS 文字列をインライン展開する。
- **理由**: 生成された HTML が単体で電子メール添付やファイルサーバ共有された際にも、外部 CSS ファイルへのリンク切れを起こさず、完全オフラインで同一表示を保証するため。
- **代替案検討**: Pandoc の `css:` オプション。これは HTML 生成時に外部ファイルとして別置されるリスクがあるため不採用。

### 2. DataTables 日本語辞書の一元ソース化

- **決定**: `.agents/shared/dashboard_dt_ja.R` に `get_dt_ja_lang()` ヘルパーを定義し、各テンプレートから呼び出す。
- **理由**: 外部 CDN（`cdn.datatables.net/.../ja.json`）への通信を 0 件に保ちつつ、ページネーション・検索欄の文言を一貫させるため。

### 3. リポジトリルート探索の標準化

- **決定**: 両 `dashboard.Rmd` の冒頭で、既存の `find_agent_repo()`（`.agents/shared/run_scope.R` を探索する遡及ロジック）を用いて `.agents/shared/` の絶対パスを安全に解決する。
- **理由**: 作業ディレクトリがサブディレクトリや一時ディレクトリ（テスト実行時等）であっても、確実に共有アセットを発見できるようにするため。

### 4. 用語の共通定義と利用側コンテキストを分離する

- `.agents/shared/dashboard_glossary.R` に共通定義を置き、2次元固有（全体独立性、Cramér's V）と3次元固有（M1〜M9、BIC）を選択する。HTMLはraw HTMLブロックとして出力し、Markdownの字下げによるコード化を防ぐ。
- 表示用コンテキストは次元、基準モデルID、事前分布名とα、応答・比較・層別変数、分子／分母水準、区間水準、ゼロセル規約、候補判定規約、セクションIDを含む。JSONの値を優先し、旧JSONに情報がない場合は生成経路の確認済み契約を明示的に渡す。推測したαや変数名を埋め込まず、不明なら未確認と表示する。
- 表示共通化時点では2次元α=0.5・3次元α=1.0という実際の生成条件を正しく表示する。その後の独立した工程で3次元 `compute_conditional_rate_view()` の主事前をα=0.5に変更し、α=1.0を感度分析に用いる。旧成果物はα=1.0のまま識別する。移行計画は `docs/Artifacts/implementation_plan_008_0919.md` に定める。

共通化時に以下の数学的記載を採用する。

| 論点 | 訂正・適用条件 |
| --- | --- |
| レバレッジ | 2次元独立モデルでは h_ij = p_i+ + p_+j − p_i+ p_+j。現行用語集の積項係数「−2」は誤り。一般の3次元モデルでは H = W^(1/2) X (X'WX)^− X' W^(1/2) の対角を用い、2次元閉形式を流用しない。高レバレッジは潜在的な影響を示し、実際の削除影響量そのものではない。 |
| EffectとEvidence | log(O/E)は倍率そのものではなく倍率の自然対数。同じ度数構成をc倍し、同一モデルを再適合する場合に不変で、同条件でT_scoreはc倍。一般の追加標本や帰無仮説のもとで常にN比例と断定しない。 |
| 残差とスコア | z=(O−E)/sqrt(E(1−h))、T_score=z²。正規／χ²近似には帰無仮説と適切な漸近条件が必要。h=1等の退化ケースに有限な通常式を主張しない。 |
| ゼロと隔離 | O=0, E>0におけるlog(O/E)の拡張実数値は−∞。2次元JSONは非有限状態を別途表現し、3次元診断は現状log(0.5/E)という補正値を格納する。補正値を厳密なlog(O/E)として説明しない。E<5、h≥0.80等は運用上の隔離条件であり、近似精度を保証する定理ではない。 |
| Dual-Filter | 探索的候補抽出でありFWER/FDRを保証しない。2次元はN≥2000が条件。現行3次元の候補式はlarge_n_thresholdを参照しておらず、N>2000でのみ計算されると表示しない。この計算差を本Changeで黙って修正しない。 |
| BIC | 正本はBIC=−2ℓ_hat+p log N（ポアソン完全尤度）。Kを同じ支持集合のセル数、df=K−pとすると、BIC=(G²−df log N)+(K log N−2ℓ_sat)。後半は同一データ・支持集合・尤度でモデル共通の定数であり、前半と絶対値は等しくない。一般のG²=2Σ[O log(O/E)−(O−E)]で、線形項を落とせるのは総適合度数と総観測度数が一致する場合。 |
| Jeffreys | K−1個の自由座標で事前密度∝sqrt(det I)。多項モデルではDirichlet(1/2,…,1/2)。滑らかな一対一再パラメータ化に対する不変性を述べ、「局所ハール」「過度な平滑化が起きない」とは断定しない。総事前濃度はKαであり、α=0.5でも影響が無視できるとは限らない。 |
| 一様事前 | Dirichlet(1,…,1)は単体上で一様。各成分の周辺分布が一様という意味ではない。移行後は感度事前α=1.0として表示し、旧成果物では旧主事前として表示する。 |
| 条件付き確率 | q=π_ij/π_i+等の事後分布と、その中央値・平均・ETIを区別する。同一条件・支持集合の次の1観測に対する予測確率はE[q\|data]であり、中央値ではない。方向の違いは条件付けの違いであり、因果方向ではない。 |
| 要約の和 | 同一条件の全カテゴリを含む各ドローとその平均の和は1（数値誤差・丸めは別）。中央値／分位点の和は一般には1に制約されないが、必ず1にならないわけではない。2カテゴリの連続分布では中央値は補数となる。 |
| ETI | データ・モデル・事前のもとで定まる事後分位区間。95%なら[Q0.025,Q0.975]であり、「真の範囲」や頻度論的被覆の保証とは呼ばない。3次元では設定された区間水準・分子分母を表示する。 |
| 独立性からの事後乖離 | 2次元では各ドローのlog(π_ij/(π_i+π_+j))。独立モデルそのものを適合した事後分布や観測log(O/E)と同一視しない。3次元の選択モデルからのセル診断とも分ける。 |

用語と数式の正しさ、生成結果との一致をテストする。古い不正確な文言（例「中央値の総和は数学的に1にはなりません」）の正規表現一致を受入条件に残さない。学術文献は支持する定義へ対応付け、著者・題名・出版媒体を確認する。教科書を一律に一次論文とは呼ばない。

## Risks / Trade-offs

### 検証上の留意点

- 既存3次元テストの一部は保存済みfixture HTMLを検査するため、新テンプレートから生成したband/card両方にも共通資産・用語の検査を適用する。子Rプロセスの終了コードを確認し、失敗時にコピー済みの古いHTMLを成功扱いしない。
- 祖先探索だけではリポジトリ外の一時ディレクトリから根を発見できない。レンダラーで確認済みrootを渡す経路と、資産欠落時の明示的停止を検証する。
- テスト成功件数を固定せず、実際のケース数・アサーション数・失敗数を記録する。静的HTML検査と、ブラウザの開閉・オフライン表示確認は別の証拠として報告する。

- **[共有 CSS の変更による複数スキルへの波及]** → 共通 CSS の修正が 2次元・3次元両ダッシュボードの表示に影響を与える。
  - *Mitigation*: 両スキルの HTML 契約テスト（`test_vcd_categorical_dashboard_v4.R` および `test_three_way_dashboard_html.R`）を常時実行し、双方でレイアウト崩れや外部アセット混入がないことを自動検証する。

### 5. 3次元 Dirichlet 事前の結果契約（タスク 4.1）

結果 JSON パスは `evidence_results.json` の `conditional_rate_view` 配下に固定する。信用区間水準 `interval_level` と Dirichlet のセル α を同じフィールドに置かない。

| フィールド | 意味 | 欠損時 |
| --- | --- | --- |
| `conditional_rate_view.prior_specification` | `{family, alpha, role, name}`。新規主解析は `family=symmetric_dirichlet`, `alpha=0.5`, `role=primary`, `name=jeffreys` | 表示は「未確認」。現在の既定値で補填しない |
| `conditional_rate_view.sensitivity_prior` | `{family, alpha, role, name}`。新規は `alpha=1.0`, `role=sensitivity`, `name=uniform` | 表示は「未確認」 |
| `conditional_rate_view.support` | `{definition="observed_table_rows", K, structural_zeros_excluded=true}`。K は入力集計表の行数。欠測組み合わせを疑似度数で埋めない | K 未確認 |
| `conditional_rate_view.config_echo.primary_alpha` / `sensitivity_alpha` | 計算に使った α。`interval_level` は別キー | 旧 JSON に無い場合は補填しない |
| `conditional_rate_view.rates` / `differences` | 主事前の要約 | 既存 HOLD 契約を保存 |
| `conditional_rate_view.sensitivity_analysis` | 同一支持集合・同一入力での α=1.0 要約とセル差 | 旧成果物には作らない |
| `run_meta.json` extra `dirichlet_prior` | family, 主／感度 α と role/name, support | 新規 run のみ |
| `analysis_config.json` optional `dirichlet_prior` | `{primary_alpha, sensitivity_alpha}`。省略時の新規計算は 0.5 / 1.0 | 旧設定を書き換えて過去 run を再ラベルしない |

設定ハッシュは既存の config snapshot に `dirichlet_prior` が含まれる場合のみそれを写す。結果ファイルハッシュは新しい run の `evidence_results.json` を対象とし、旧 run を上書きしない。
