## Context

対数線形モデル比較において、モデル識別子（`cond_indep_BC_given_A` 等）だけでなく、因子記号（$A, B, C$）と実変数の対応、生成クラス（`generators` を正本とするブラケット表記 $[AB][AC]$）、構造化された独立性情報、および数理モデル式を一貫して提供する。

モチベーションと要求仕様の詳細は以下を参照：
- [proposal.md](proposal.md)
- [three-way-model-assessment spec](specs/three-way-model-assessment/spec.md)
- [cell-evidence-interpretation spec](specs/cell-evidence-interpretation/spec.md)

現行の `pass1_compute.R` ではモデル式文字列（`formula_str`）とモデル識別子が個別に定義されており、生成クラスとの数学的一貫性がシステム的に保証されていない。また、現行の `dashboard.Rmd` では DT テーブル内に長いモデル名が出力され、数式組版と表の視認性が両立しにくい構造となっている。本設計では、数学的正本としての生成クラスの確立、JSON 出力契約の分離・構造化、ダッシュボードの3段構成、および堅牢なフォールバックと検証基準を具体化する。

## Goals / Non-Goals

**Goals:**
- `generators`（因子記号の文字ベクトル配列）を唯一の正本（SSOT）とするモデル仕様辞書を R エンジンに構築し、実適合式と数学的メタデータを演繹的に導出する。
- 展開項の一致検証（`terms()` 展開後の集合一致）を導入し、R の formula と数学的定義の完全一致を保証する。
- `evidence_results.json` において「変数対応（`models.factor_map`）」「数理辞書（`models.definitions`）」「数値比較表（`models.summary`）」を分離・構造化する。
- ダッシュボード（`dashboard.Rmd`）を「変数凡例」「6列DT比較表」「表直下の静的数理詳細（`<details>`）」の3段構成にし、表内リンクからのアコーディオン展開とフォーカス移動を保証する。
- 旧JSON（数理定義未収録）、適合結果未収録、内部不整合（式と定義の不一致等）、および記録済み適合失敗に対する明瞭なフォールバック表示を実装する。
- 既存成果物（`output/ucb_admissions/run_admit_bias/`）を保護しつつ、4つの比較元（既存JSON、固定参照実行、モデル対応表、実適合式展開項）に基づく数値不変性と数学的整合性を検証する。

**Non-Goals:**
- 統計エンジン（`pass1_compute.R`）内部における適合失敗時（`tryCatch` で `NULL` を返す経路等）のエラー捕捉や、候補除外・順位付けロジック自体の改修（表示側の記録済み失敗ハンドリングに限定する）。
- 4元表以上の多次元分割表への拡張（2元表および3元表を対象とする）。
- スムーススクロール等の装飾的アニメーションの実装（標準的なHTMLアンカー展開とフォーカス移動に留める）。

## Decisions

### 1. `models.definitions` のデータ構造（オブジェクト形式）

- **決定**: `models.definitions` はモデルID（`M1`〜`M9`、2元表は `M1`〜`M2`）をキーとする **JSON オブジェクト（Named List）** とする。
- **スキーマ構成**:
  ```json
  {
    "notation_version": "1.0.0",
    "dimension": 3,
    "factor_map": {
      "A": { "variable": "Dept", "label": "学科" },
      "B": { "variable": "Gender", "label": "性別" },
      "C": { "variable": "Admit", "label": "合否" }
    },
    "definitions": {
      "M5": {
        "model_id": "M5",
        "model_key": "3way_M5",
        "generators": [["A", "B"], ["A", "C"]],
        "bracket_notation": "[AB][AC]",
        "bracket_expanded": "[Dept, Gender][Dept, Admit]",
        "independence": {
          "kind": "conditional_independence",
          "statements": [
            { "left": ["B"], "right": ["C"], "given": ["A"] }
          ],
          "description_ja": "A（学科）で層別したとき、B（性別）とC（合否）は条件付き独立である"
        },
        "fitted_formula": "Freq ~ Dept * Gender + Dept * Admit",
        "formula_latex": "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB} + \\lambda_{ik}^{AC}",
        "formula_description_ja": "主効果A, B, Cおよび2因子交互作用AB, ACを含むポアソン対数線形モデル（BC交互作用および3因子交互作用を含まない）"
      }
    },
    "summary": [
      {
        "model_id": "M5",
        "model_name": "cond_indep_BC_given_A",
        "df_residual": 6,
        "deviance": 21.735,
        "bic": 72.827,
        "delta_bic": 0.0
      }
    ]
  }
  ```
- **Rationale**:
  - 配列形式ではモデルIDによる検索時に全探索（$O(N)$）が必要になり、特定モデルの参照が煩雑になる。オブジェクト（マップ）形式にすることで、ダッシュボードのJSやAIがキーで即座に引き当てられる。
  - `summary` は既存の列構成（`model_id`, `model_name`, `df_residual`, `deviance`, `bic`）をそのまま維持し、既存パイプラインとの完全な後方互換性を保つ。

### 2. 独立性仮定の構造化表現（`kind` と `statements`）

- **決定**: 自然言語の日本語説明文の前に、独立性構造を機械判読可能な形式で構造化する。
  - `kind`:
    - `"mutual_independence"`: 相互独立（3因子が互いに独立）
    - `"joint_independence"`: 結合独立（$(A, B) \perp C$ 等）
    - `"conditional_independence"`: 条件付き独立（$B \perp C \mid A$ 等）
    - `"no_independence_constraint"`: 一般には独立性制約なし（M8の均一連関、M9の飽和）
  - `statements`: `[ { "left": [...], "right": [...], "given": [...] } ]`
- **M8・M9の表現**:
  - M8（均一連関）: `kind: "no_independence_constraint"`, `description_ja: "全2因子交互作用を含み、3因子交互作用を含まない（オッズ比の一様性）"`
  - M9（飽和）: `kind: "no_independence_constraint"`, `description_ja: "飽和モデル（3因子交互作用まで含む）"`
- **Rationale**:
  - 相互独立をペアごとの独立と混同しない。
  - M8やM9に存在しない条件付き独立記号を無理に割り当てず、交互作用項の制約として正確に記録する。

### 3. 項集合の一致検証と式生成アルゴリズム

- **決定**: `generators` から R formula を生成し、生成された式を展開した項集合と `generators` から期待される全項集合（主効果＋指定交互作用およびその部分集合）が完全一致することを R 内部で検証する。
- **処理手順**:
  1. `generators`（例: `list(c("A","B"), c("A","C"))`）を実際の変数名（例: `Dept`, `Gender`, `Admit`）に置換。
  2. 各生成子を積の形式（`Dept * Gender + Dept * Admit`）で結合し、`Freq ~ ...` の formula を構築。
  3. `terms.formula()` を用いて展開された全項ラベル（`attr(terms(f), "term.labels")`）を取得。
  4. 生成クラスから階層原理（hierarchical principle）に従い展開した期待項ラベル集合とソート比較し、完全一致（`setequal`）を確認。不一致の場合は例外を投げる。
- **Rationale**:
  - 文字列の貼り合わせによる式の誤り（項の脱落や意図しない交互作用の混入）をコンパイル/適合時に確実に検知する。

### 4. 欠損・未収録・内部不整合の判別規約

- **決定**: 各データ状態を以下の4つの明確なカテゴリに分類し、推測補完を行わずにその状態を表示する。
  1. **正常（定義・結果の両方あり）**:
     - `definitions[id]` が存在し、実適合式と項集合が一致し、`summary` に適合数値（自由度、逸脱度、BIC）が記録されている。
  2. **定義あり・適合結果未収録**:
     - `definitions[id]` は存在するが、`summary` に該当候補が存在しない、または数値が記録されていない。
     - 表示: 数理定義を展開可能とし、比較表の数値欄は「適合結果未収録」と表示。推測で失敗理由を作らない。
  3. **定義未収録（旧JSON・互換モード）**:
     - `models.definitions` が存在しない、または `null`。
     - 表示: `summary` の数値比較表を表示し、詳細欄には「数学的定義未収録」と明記。
     - 変数凡例: 旧JSONの `input_summary.variables` の順序から $A, B, C$ を導出して凡例を表示してよいが、モデル定義の推測補完とは区別する。主要指標カードの構造仮定表示は保留する。
  4. **内部不整合（不整合検知）**:
     - 条件:
       - `dimension = 2` なのに `factor_map` に因子 $C$ が存在する。
       - `summary` に存在する `best_model_id` が `definitions` に存在しない、または比較表に存在しない。
       - `fitted_formula` の展開項と `generators` の期待項が一致しない。
     - 表示: 該当モデルの数学的説明を保留し、「内部不整合（式と定義の不一致等）」と明示する。
  5. **記録済み適合失敗（検証用フィクスチャ等）**:
     - `summary` 内でステータスが失敗（収束不良等）として理由とともに記録されている場合。
     - 表示: 保存された理由を表示し、通常順位付けから除外して保留候補として提示する。

### 5. バージョン管理と `jsonlite` 型崩れ防止

- **決定**:
  - `notation_version: "1.0.0"` を `models` 配下に記録。
  - R の `jsonlite::toJSON(..., auto_unbox = TRUE)` による単一要素ベクトルのスカラー化（例: `["A"]` が `"A"` になる）を防ぐため、配列であるべきフィールド（`vars`, `generators`, 各 `statements` 内の `left`, `right`, `given`）には明示的に `I()`（AsIsクラス）を付与する。
  - 未知のメジャーバージョン（`2.x.x` 等）を検出した場合、ダッシュボードは「未対応の notation_version」警告を表示し、未定義メタデータへのアクセスを安全にフォールバックする。

### 6. ダッシュボード表示レイアウトとアクセシビリティ

- **決定**:
  - **3段構成**:
    1. **ページ最上部（主要指標カードの前）**:
       - 「変数定義・因子記号凡例」ボックス（背景薄グレー、枠線付き）。
       - 因子記号（$A, B, C$）と実変数名、水準、および注記（「学科水準 A〜F と因子記号 A は異なります」）を明記。
       - 主要指標カード: 有効な数理定義が存在する場合は BIC 最小モデルの構造仮定（例: 「合否と性別は学科で層別したとき条件付き独立である」）を明記。定義未収録・不整合時はその状態を表示。
    2. **モデル比較表（DT）**:
       - 直前にブラケット記法の読み方と BIC 算式・解釈注記を配置。
       - 6列構成:
         - `モデル`: 短い構造説明と「数式・定義を見る」アンカーリンク（例: `#model-detail-M5`）
         - `生成クラス`: 等幅テキストによるブラケット表記（`<code>[AB][AC]</code>`）
         - `残差自由度`: `df_residual`
         - `逸脱度`: `deviance`
         - `BIC`: `bic`
         - `ΔBIC`: `delta_bic`
    3. **モデル詳細アコーディオン（静的 HTML `<details>`）**:
       - DT 表の直下に配置。
       - 有効な `best_model_id` に対応する `<details>` のみ `open` 属性を付与して初期展開。`best_model_id` が欠落・不正な場合は先頭候補などを勝手に初期展開しない。
       - 各アコーディオン内に、等幅ブラケット表記、実変数展開表記、独立性仮定テキスト、ポアソン対数線形モデル式（LaTeX）、および制約条件注記を掲載。
  - **キーボードアクセシビリティとスクロール**:
    - 表内のアンカーリンクをクリックした際、対象の `<details>` の `open` 属性を JavaScript で `true` に設定し、該当詳細の `<h5>` 見出しへ `focus()` を移す。これによりスクリーンリーダーやキーボード操作での継続性を担保する。
  - **MathJax 未読み込み時フォールバック**:
    - ブラケット記法と日本語構造説明は通常の HTML テキスト（および等幅フォント）としてマークアップし、MathJax の読み込み遅延・失敗時でもモデル仮定が完全に伝わるようにする。

### 7. 数値検証と許容誤差の基準（4つの比較元）

- **決定**: 数値不変性および整合性の検証元を以下の4つに明確に分離する。
  
  | 確認対象 | 比較元 | 許容誤差・判定基準 |
  |---|---|---|
  | 残差自由度 | 既存 JSON（`run_admit_bias`） | 完全一致（整数一致） |
  | BIC・逸脱度 | 既存 JSON（`run_admit_bias`） | 絶対誤差 $< 10^{-6}$ |
  | 保存済みセル診断値 | 既存 JSON（`run_admit_bias`） | 完全一致または相対誤差 $< 10^{-6}$ |
  | 対数尤度・未保存適合値 | 変更前エンジン固定参照実行 | 絶対誤差 $< 10^{-6}$ |
  | 生成クラス・独立性の対応 | 独立したモデル定義仕様（正解辞書） | 完全一致（文字列・構造一致） |
  | 実適合式と生成クラス | 適合 formula の展開項（`terms()`） | 集合完全一致（`setequal`） |

- **同点 BIC 候補の扱い**:
  - 最小 BIC に複数モデルが並ぶ場合（同点時）、既存ロジックと整合させ、辞書順・候補定義順（先頭のインデックス）を採用するルールを維持し、挙動の揺れを防ぐ。

## Risks / Trade-offs

- **[Risk 1: `jsonlite` の単一要素ベクトル配列化の喪失]**
  - 単一要素の文字ベクトル（例: `c("A")`）が `auto_unbox = TRUE` で単一文字列 `"A"` として出力され、フロントエンドやバリデータで型エラーとなる。
  - **Mitigation**: R の出力構築時に `I(list(...))` または `I(c(...))` を使用して AsIs 属性を付与し、単一要素でも JSON 配列 `["A"]` として出力されることをテストで検証する。

- **[Risk 2: 旧JSONでの変数順序の曖昧さ]**
  - 旧JSONに `models.factor_map` がない場合、変数順序が不定になるリスク。
  - **Mitigation**: 旧JSONでは `input_summary.variables`（または設定ファイルの `vars`）の記録順を厳格に採用し、先頭から $A, B, C$ を割り当てる。記録順すら存在しない場合は無理に対応を推測せず「因子対応未収録」と表示する。

- **[Risk 3: MathJax の組版遅延による画面のガタつき]**
  - DT 表の内部に複雑な数式を配置すると、ページングやソートのたびに MathJax が再実行され、表示のちらつきや遅延が発生する。
  - **Mitigation**: DT テーブル内には等幅テキストのブラケット記法（`<code>[AB][AC]</code>`）のみを配置し、MathJax 数式は表直下の静的 `<details>` 領域に集約する。

- **[Risk 4: 適合失敗処理の実装範囲の拡大（ゴール・ドリフト）]**
  - 仕様を満たそうとして、後続タスクで `glm()` のエラー捕捉処理や候補除外ロジックまで手をつけてしまう。
  - **Mitigation**: 本提案の実装範囲を「保存済み状態の正しい表示」に限定し、記録済み失敗のテストにはあらかじめ失敗情報（理由付き）を格納したフィクスチャ JSON を用いる。

## Migration Plan

1. **フェーズ 1: R エンジン仕様辞書・式導出・出力拡張**
   - `pass1_compute.R` に `MODEL_SPECS_3WAY` / `MODEL_SPECS_2WAY`（`generators` を正本とする辞書）を実装。
   - 項集合展開検証関数（`validate_formula_terms()`）を実装。
   - `models.factor_map`, `models.definitions` の出力ロジックを実装。
2. **フェーズ 2: ダッシュボード表示の更新**
   - `dashboard.Rmd` に変数凡例ボックス、6列DT表、表直下のモデル詳細アコーディオン、アンカーリンクスクロール JS を実装。
   - 旧JSON・未収録・不整合・記録済み失敗のフォールバック条件分岐を実装。
3. **フェーズ 3: 検証と回帰テスト**
   - 辞書と式の一致性テスト。
   - 既存 run（`output/ucb_admissions/run_admit_bias/`）との4軸数値比較テスト（既存成果物は保持し、別runへ出力して比較）。
   - 旧JSON読み込みテスト、および異常系フィクスチャ（不整合JSON、記録済み失敗JSON）のレンダリングテスト。
