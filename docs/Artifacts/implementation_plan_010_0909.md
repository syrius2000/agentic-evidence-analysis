# 分析プロジェクト出力導線の統一とREADME更新の実装計画

created: 2026-09-09 17:47 (JST)
update: 2026-09-09 17:47 (JST)
author: Codex (GPT-5)

## 1. 計画の要旨

本リポジトリでは、Pass 0 の検分、Pass 1 以降の正式 run、Skill ごとの既定出力、OpenSpec Artifact がそれぞれ別の場所に保存される。これはデータ保護、再実行、ハッシュ検証、sealed run の維持には有効である一方、初学者には「どこを開けばよいか」が分かりにくく、大学院生には研究記録としての対応関係を確認しにくい。

本計画では、内部の run ライフサイクルと安全契約を変更せず、利用者向けの入口を `output/<project>/` に統一する。README と5つの分析 Skill の説明・コマンド例・パス表現を同じモデルへそろえ、初学者には一本道を、大学院生には相談から確定までの証跡を提供する。

## 2. 設計判断

- 利用者が最初に開く場所を `output/<project>/` とする。
- Pass 0 の相談成果物は、原則として `output/<project>/00_consultation/` に保存する。
- Pass 1 以降の正式 run は、Skill ごとの親ディレクトリを分けて保存する。
- Bayesian と Categorical は `<skill_root>/run_<first16>[_N]/`、Questionnaire は `<skill_root>/runs/<id>[_N]/` という既存の安全契約を維持する。
- `run_handover.json` を正式な次工程への案内情報として扱い、利用者に run パスの手作業推測を求めない。
- `skill_out/` は既存 run と後方互換のために残す。新規の利用例とREADMEでは、プロジェクト配下の親ディレクトリを優先して示す。
- `docs/Artifacts/` は計画・設計・検証文書の保存先であり、統計計算成果物の保存先とは説明上も分離する。
- 既存の sealed run、legacy run、既存の利用者成果物は移動・改名・再計算しない。

## 3. 利用者向けの標準構造

新規プロジェクトでは、次の構造を標準例として提示する。

```text
output/<project>/
├── README.md
├── 00_consultation/
│   ├── inspection_results.json
│   ├── data_analysis_scope.md
│   └── analysis_config.json
├── 10_bayesian/
│   └── run_<id>/
├── 10_categorical/
│   └── run_<id>/
└── 10_questionnaire/
    └── runs/<id>/
```

この構造は利用者向けの配置方針であり、`run_scope.R` の予約・衝突回避・symlink防御・sealed 契約を置き換えるものではない。各 Skill の `analysis_config.json` に対応する親ディレクトリを指定し、正式 run の作成は従来どおり実装に委ねる。

## 4. 対象範囲

### 4.1 README.md の更新

`README.md` を利用者の最初の入口として、次の内容へ更新する。

1. 「まず `output/<project>/` を開く」という導線をクイックスタートの冒頭に置く。
2. Pass 0 → Pass 1 → Pass 2 → Pass 3 を、初学者向けの日本語で一つの実行例として示す。
3. `00_consultation`、正式 run、`run_handover.json`、`sealed` の役割を短く説明する。
4. Bayesian、Categorical、Questionnaire の出力親ディレクトリと正式 run の形を表にする。
5. 初学者向けに「次に開くファイル」を示し、run ディレクトリを手作業で探さない手順にする。
6. 大学院生・研究者向けに、入力ハッシュ、設定、results manifest、run_meta、supersede の証跡を説明する。
7. 現在の `output/<project>/run_<id>/` という古い Pass 0 例を、`output/<project>/00_consultation/` へ修正する。
8. `skill_out/` を既存 run・既定値・後方互換の場所として説明し、新規推奨入口と混同しない注記を置く。
9. Questionnaire の `runs/<id>` と、Bayesian/Categorical の `run_<id>` の違いを一表で説明する。
10. `vcd-categorical-reporting` は非推奨の参照用であり、新規分析では `vcd-categorical-analysis` を使用することを明記する。

### 4.2 Skill 文書の同期

次の5つの Skill の説明と実行例を、README の標準構造と同期する。

- `vcd-pass0-consultation`
- `vcd-bayesian-evidence-analysis`
- `vcd-categorical-analysis`
- `questionnaire-batch-analysis`
- `vcd-categorical-reporting`

各文書では、次の順序を統一する。

1. 利用者向け標準入口
2. Pass 0 の作業領域
3. Pass 1 の出力親ディレクトリ
4. 実際の run パス規則
5. Pass 2・Pass 3 の同一 run 内成果物
6. `run_handover.json` から次のパスを取得する方法

文書と実装に差がある Questionnaire の `--run-id` 既定値、および Categorical の `--profile` 出力先については、実装を先に正本として確認し、誤解を招く例を修正する。統計計算の実装や run 予約規則そのものは、この計画の範囲では変更しない。

### 4.3 例と参照資料の整理

- `examples/` を使うクイックスタートは、相談成果物と正式 run の保存先をプロジェクト単位で示す。
- `examples/OTC_Q02a.csv` の例では、検分結果が `00_consultation` に残り、入力構造に問題がある場合は `analysis_config.json` を確定しないことを明示する。
- 既存の `tests/skill_out*` はテスト用出力として扱い、利用者向け標準構造の例に混ぜない。
- 必要に応じて `output/<project>/README.md` の雛形を追加し、生成された run への相対リンクを記録できるようにする。ただし、手作業で最新 run を推測する仕組みは作らない。

## 5. 初学者向けと大学院生向けの見せ方

### 初学者向け

- 最初に覚える場所を `output/<project>/` の一つに限定する。
- コマンドは Pass 0 から順にコピー・ペーストできる形にする。
- 成果物の説明を「相談」「計算」「考察」「確定」の4語に置き換える。
- `run_handover.json` を開けば次の対象が分かることを明記する。
- `sealed` は「確定後は上書きしない」と短く説明し、内部ハッシュの詳細は折りたたみ可能な補足へ置く。

### 大学院生・研究者向け

- `data_analysis_scope.md` と `analysis_config.json` を分析計画の記録として位置付ける。
- `run_meta.json`、`results_manifest.json`、入力SHA-256を再現性・監査証跡として説明する。
- `executive_summary.md` と `dashboard.html` は計算結果から派生する解釈・報告成果物であることを区別する。
- sealed run の直接編集を禁止し、改定は `supersedes-run` による新 run とする。
- `run_handover.json` のパスを、人間・AI・後続 Skill が共有するインターフェースとして説明する。

## 6. 実装段階

### 段階1: 現状と文書の差分確認

- README、5 Skill、共有 `run_scope.R`、Pass 0 CLI、既存テストの出力例を再確認する。
- 現在の `skill_out` と `output` の使われ方を一覧化する。
- 既存の未コミット変更（特に `implementation_plan_008_0909.md` と `implementation_plan_009_0909.md`）を変更対象から除外する。

### 段階2: README.md の更新

- 標準プロジェクト構造、4-Pass の一本道、Skill 別パス表、初学者向け導線、研究者向け証跡説明を追加する。
- 既存の古いパス例と実装に一致しない `run-id` 説明を修正する。
- 既存リンク、Mermaid、README の日本語方針を維持する。

### 段階3: Skill 文書と例の同期

- 5 Skill の出力先説明とコマンド例を標準構造へ合わせる。
- Pass 0 は正式 run を作らないことを共通表現にする。
- Pass 1 は `analysis_config.json` の `output_dir` を使うことを明記する。
- 既定値として残る `skill_out` は、後方互換の説明として明示する。

### 段階4: 軽量なナビゲーション補助

- 必要性を確認したうえで、`output/<project>/README.md` の雛形または run 一覧の補助出力を追加する。
- 補助機能を追加する場合も、正式 run の予約・ハッシュ・状態遷移を複製しない。
- `run_handover.json` の情報を再利用し、最新時刻の推測やディレクトリ走査だけに依存しない。

### 段階5: 検証

- README と各 Skill のパス記述を機械的に検索し、矛盾する例がないことを確認する。
- `examples/OTC_Q02a.csv` の Pass 0 で、検分成果物が指定した相談ディレクトリに残ることを確認する。
- 既存の Pass 0 契約、run ライフサイクル、数値不変性、各 Skill のスモークテストを再実行する。
- `git diff --check` と、公開文書への個人絶対パス混入検査を実施する。

## 7. 非対象

- Bayesian、Categorical、Questionnaire の統計計算式、モデル、閾値、乱数、結果JSONの数値変更
- `run_scope.R` の sealed、supersede、symlink、防御、原子的予約の契約変更
- 既存 `skill_out` run、legacy run、sealed run の移動・改名・再計算
- `tests/` の一括削除、大規模なテスト再編、不要な迂回フラグの追加
- 英語化、多言語化、指標定義の外出し（別計画 `implementation_plan_009_0909.md` の対象）
- commit、push、外部システムへの書き込み

## 8. 受入条件

- README のクイックスタートが `output/<project>/` を唯一の利用者向け入口として示している。
- README と5 Skill の出力先説明が同じプロジェクト構造、Pass 0 非正式run、run handover の扱いを共有している。
- 初学者が Skill 名ごとの内部パスを手作業で推測せず、Pass 0 から Pass 3 まで進める手順がある。
- 大学院生が相談記録、設定、入力ハッシュ、結果マニフェスト、確定状態を追跡できる。
- `skill_out` の既存成果物を壊さず、後方互換の位置付けが文書化されている。
- Questionnaire の `runs/<id>`、Bayesian/Categorical の `run_<id>` の差が表で説明されている。
- OTC_Q02a の Pass 0 検分例が `inspection_results.json` の保存先と、入力準備が必要な場合の停止条件を正しく示している。
- 既存の代表テストが通過し、文書更新だけで統計数値や正式 run ライフサイクルに差分がない。
- `git diff --check` が成功し、公開対象文書にホスト固有の絶対パスが追加されていない。

## 9. 承認境界

本 Artifact は、出力導線と README・Skill 文書を統一するための計画案である。ユーザーから「承認します」「実装してください」などの明示的な承認を受けるまでは、README、Skill、スクリプト、テスト、設定ファイルの変更を開始しない。承認後に対象範囲や実装方式を変更する必要が生じた場合は、本計画を更新して再承認を得る。
