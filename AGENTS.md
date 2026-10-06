# AGENTS.md — エージェント作業契約

このファイルは、本リポジトリで作業するAIエージェント向けの行動規則です。利用者向けの概要・導入・実行例は [README.md](README.md) を参照してください。

## 文書の責務と正本

- エージェントの作業境界・承認条件は本ファイルに従う。
- 利用方法は [README.md](README.md) と各スキルの `SKILL.md`、スキル間の責務は [docs/reference/skill_responsibilities.md](docs/reference/skill_responsibilities.md) を参照する。
- 統計数理は [docs/reference/README.md](docs/reference/README.md) から該当する数理文書を参照する。
- 規範的な挙動は該当する `openspec/specs/` の現行仕様を確認する。archiveは履歴であり、規範として扱わない。
- 文書間に不整合があれば独自に規則を作らず、該当する正本を照合し、解消できない場合は不整合を報告する。

## 作業時の必須ルール

### 1. R依存関係は実行時に導入しない

- 解析・レポート生成・テスト実行中に `install.packages()`、`pacman::p_load()` などでパッケージを自動導入してはならない。
- 依存関係が不足した場合は `check_r_dependencies()` 等の既存チェックに従って停止し、必要な案内を行う。

### 2. Pass 0の適用範囲を守る

- **必須**: `vcd-bayesian-evidence-analysis` と `vcd-categorical-analysis` の新規分析、および非独立観測デザインを扱う `comparative-design-analysis`。
- **推奨**: 複数テーマ・複数設問を一括処理する `vcd-categorical-reporting` と `questionnaire-batch-analysis`。
- **対象外**: `sas-proc-freq`、`sas-proc-means`、単体集計スクリプトの直接実行、回帰・ユニットテスト、文書・コードの保守。
- Pass 0では入力品質、分析単位、変数・次元、欠測、疎セル、デザイン、目的を確認する。詳細な手順と設定契約は [vcd-pass0-consultation/SKILL.md](.agents/skills/vcd-pass0-consultation/SKILL.md) および各分析スキルに従う。

### 3. 解析成果物をrun単位で分離する

- 解析の永続出力はスキルごとの出力ルート配下に `run_<canonical_id>[_N]/` を作り、run間で物理的に分離する。出力ルート直下へ解析成果物を書かない。
- 既存runやユーザーデータを無言で上書きしない。既定ルート・ID形式・互換条件は各スキルと共有run基盤の契約に従う。
- 新しい解析実行の出力先は原則 `evidence_runs/<skill_slug>/` 配下とする。

### 4. 言語・時刻と成果物の制約

- 生成するレポート、AI要約、解説は原則として日本語で作成する。解析コンテキストとタイムスタンプはJSTを用いる。
- HTMLレポートは外部CDN・外部CSS/JS・外部フォント・OS依存の絶対パスを参照しない自己完結型とする。成果物に外部通信先や環境依存パスを含めない。

### 5. 正本リポジトリの境界

- スキルの管理対象は `.agents/skills` のみとし、`.cursor/skills` を作成・復元しない。
- 共通R基盤は `.agents/shared`、数理リファレンスは `docs/reference`、規範挙動は該当する現行 `openspec/specs/` で管理する。
- 本リポジトリは統計スキル・schema・品質契約・Rテンプレート・統計回帰テストの正本である。一般コード・SQL理解とRWD/DB実行の境界は [README.md](README.md) のエコシステム案内に従う。
- P値単独や一律閾値で重要性を自動判定しない。効果量、方向支持、実務領域、不確実性・精度、影響度、数値安定性、意思決定を混同せず、自動規制判断を行わない。定義と数理は担当リファレンスを参照する。

## 変更前の手続きと保全

- 調査、現状確認、差分確認、計画書作成は読み取り専用で進められる。
- 大規模変更、コード・依存関係・データの変更、外部システムへの書き込みに着手する前に `docs/Artifacts/plans/implementation_plan_NNN_MMDD.md` を作成する。
- 計画承認前に実装・データ変更・外部書き込みへ進まない。対象・方式・影響範囲が変わる場合は計画を更新し、再承認を得る。
- 作業開始時点のユーザー変更、無関係な差分、未追跡ファイルを保持する。復元・削除が必要なら対象を限定し、明示的な承認を得る。
- 計画書には、canonical指標と由来を含むデータ契約、統計概念の分離、コードベースの一次情報照合、Fixture・Checks・Expected Resultsを示す具体的な確認マトリクスを記載する。

## Git・レビュー・外部操作

- 大規模改修やOpenSpec Changeでは、リポジトリのブランチ運用規約に従って専用トピックブランチを使う。
- 作業ブランチ上の中間コミットは規約に沿って作成できる。コミットやレビューの証拠は作業結果と区別して報告する。
- 独立ブラインドQAはユーザーが明示的に起動した場合に限り、[blind-qa-cycleスキル](.agents/skills/blind-qa-cycle/SKILL.md) の手順に従う。自動起動、Owner裁定の代行、QA担当による製品コード修正をしない。
- `git push`、ブランチ削除、その他リモートへの書き込みは、ユーザーの明示指示がない限り行わない。明示起動されたblind-qa-cycleの例外は同スキルと本リポジトリの運用規約に限定する。
- `main`への集約は、実装・レビュー完了後にユーザー承認を得てから行う。

## 完了報告の証拠区分

- 構文確認、静的確認、テスト、解析実行、独立QA、Owner判断、commit、pushを区別して報告する。
- 実施していない確認は「未検証」とする。過去の記録や実装者の報告だけで現行状態を確定しない。
- ユーザーへの報告は結論を先にし、次の行動と未検証事項が分かるようにする。詳細は [docs/reference/output_style_adhd.md](docs/reference/output_style_adhd.md) を参照する。
