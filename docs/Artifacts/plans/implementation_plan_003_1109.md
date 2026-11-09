# エグゼクティブサマリー表示改善 Implementation Plan

**Goal:** 比較DashboardのH1・黄色の免責事項の後に、HTMLとして整形された要約を開いた状態の折りたたみ領域で表示する。

**Architecture:** 既存のPass 2/3とrunのハッシュ検証を維持し、`render_dashboard.R` の要約挿入位置とレンダリングを変更する。Markdownは安全なHTML要素へ変換し、既存の `guide-accordion` / `guide-summary` / `guide-content` の見た目を利用する。

**Tech Stack:** R、既存の `commonmark` / `xml2`（使用前に依存確認）、HTML `<details open>` / `<summary>`、既存の共通run基盤。

## Global Constraints

- 表示順序は `h1#dashboard-title` → `#guidance-callout` → H2「エクゼクティブサマリー」の折りたたみ領域 → 従来の内容。
- 要約は初期状態で展開し、キーボードでも開閉可能とする。見出し、段落、強調、箇条書き、表をHTMLとして表示する。
- 要約全文・分析スキルID・結果manifestと要約のハッシュ連携・オフライン性を保持する。HTMLタグや危険なURLを実行可能な形で挿入しない。
- Rパッケージは自動インストールしない。不足時は停止して報告する。
- 一時テストとそのrunは他の成果物と隔離し、検証終了後に今回作成したものだけ破棄する。既存の管理済みテストやrunは削除しない。
- この依頼によるcommit・pushは行わない。

## 対象ファイル

- 変更: `.agents/skills/vcd-categorical-reporting/render_dashboard.R` — 要約の安全なHTML変換、折りたたみ表示、挿入位置。
- 変更: `.agents/skills/vcd-categorical-reporting/SKILL.md`、必要な依存確認とOpenSpec変更文書 — 表示・依存・安全性の実装と説明を一致させる。
- 一時テスト: `/tmp/` 内に今回専用のテストスクリプトを作成。runは出力root制約を満たす `evidence_runs/vcd_categorical_reporting/` 内の今回専用ディレクトリに限定する。

## Task 1: TDDで表示契約を固定

- [x] 一時テストに、H1→免責事項→要約の順序、`details[open]`、H2、Markdownの見出し・段落・強調・箇条書き・表のHTMLタグ化を追加し、現在の実装で失敗することを確認する。
- [x] `<script>`、イベント属性、`javascript:` URL、外部画像、長文・日本語・記号を含む要約を入力し、スクリプト実行や外部リソース読み込みを防ぎつつ本文を保持する受入条件を追加する。
- [x] missing・空・ハッシュ不一致の失敗、同runの要約とDashboardの来歴、`sealed` 状態、および既存の比較表が維持されることを確認する。

## Task 2: rendererと仕様の更新

- [x] `#guidance-callout` の終了直後を一意に特定し、見つからない・複数ある場合はfinalization前に停止する。
- [x] `commonmark` のMarkdown構文木を許可タグ・属性だけのHTMLに変換する。生HTMLや危険なリンクは実行可能にせず、外部画像を読み込まない。新しい依存が未導入なら停止する。
- [x] `<details open class="guide-accordion">` と `<summary class="guide-summary">` にH2「エクゼクティブサマリー」を置き、`guide-content` に整形された本文とskill IDを入れる。TDDテストを再実行する。
- [x] `SKILL.md` と既存OpenSpec changeの設計・タスクを現行仕様に合わせて更新し、`openspec validate --strict` を実行する。

## Task 3: 統合確認と後片付け

- [x] 小規模fixtureでPass 1→summary確定→Dashboard確定を実行し、HTML構造・全本文・安全性・ハッシュ・索引を確認する。
- [x] 既存の安全性データは別の新規runで再生成し、前runと250 contrast・CSVが一致することを確認して、表示改善後のDashboardを提供する。既存sealed runは変更しない。
- [x] 今回の一時テストスクリプトと一時runだけを破棄し、Git状態から検証用ファイルが混入していないことを確認する。
- [x] ブラウザでの視覚確認が環境制約によりできない場合は、静的HTML確認と視覚未検証を区別して報告する。

## 着手ゲート

前計画の `<pre>` 表示・挿入位置から方式が変わるため、AGENTS.mdに従い計画を更新。2026-11-09にユーザーが承認し、既存の黄色い免責事項を維持する意図も確認済み。
