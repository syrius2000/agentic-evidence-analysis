## 背景

4スキルが生成する Dashboard / HTML のページ背景・見出し・アクセント色が分かれており、既存の共有学術テーマが reporting と questionnaire に適用されていない。計画書 `docs/Artifacts/plans/implementation_plan_001_0928.md` の範囲で、表示の色味を共通正本へ統一する。

## 変更内容

- `.agents/shared/dashboard_theme.css` と共有 R トークンを表示色の正本とし、対象4スキルの Dashboard / HTML で使用する。
- categorical テンプレート内の `THEME_TOKENS` と行パレット関数を共有 R に抽出し、既存のベイズ・カテゴリカル表示から利用する。
- reporting のページクロムと実務領域セルの色を学術パレットに写像する。12列の順序、列限定・セル限定着色、統計上の意味は維持する。
- questionnaire の `flatly` と独自グラデーションを取り除き、共有 CSS を HTML 内に埋め込む。
- 静的契約と代表 fixture の再生成で、色の統一、意味付き着色、自己完結性を確認する。
- HTML 未実装の2スキルについて、将来 Dashboard を追加する際の共有テーマ適用方針を文書化する。

## 対象機能

### 新規機能

なし。

### 変更する既存機能

- `shared-dashboard-presentation`: 共有 CSS の適用対象を、既存の2次元・3次元 Dashboard から reporting と questionnaire の HTML へ広げ、共有 R トークンと色写像の表示契約を加える。

## 影響範囲

- `.agents/shared/dashboard_theme.css`、新規 `.agents/shared/dashboard_theme_tokens.R`
- 4スキルの Dashboard / report テンプレートまたはレンダラー
- 共有テーマ契約のテスト、代表 fixture HTML、`docs/reference/skill_responsibilities.md`
- 統計指標、列の意味、数理 OpenSpec、解析データのスキーマは変更しない。
