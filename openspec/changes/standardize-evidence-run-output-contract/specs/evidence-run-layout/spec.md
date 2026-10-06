# Spec Delta

## MODIFIED Requirements

### Requirement: Canonical Recommended Output Root

システムは、各解析スキルに登録された安定slugを用いて `evidence_runs/<skill_slug>/` を正規出力ルートとして使用しなければならない（MUST）。出力ルートが明示された場合も、割当済みskill root自身またはその配下に限定しなければならない（MUST）。

#### Scenario: Default output root resolution

- **WHEN** 解析ランナー実行時に明示的な出力先が指定されない
- **THEN** システムは登録済みslugに対応する `evidence_runs/<skill_slug>/` をout_rootとして採用する

#### Scenario: Explicit custom output root

- **WHEN** 利用者がスキル規定の出力インターフェースでrootを明示する
- **THEN** システムは、解決後のrootが当該スキルの `evidence_runs/<skill_slug>/` 自身またはその配下にある場合に限り指定を受理し、それ以外は書込み前に拒否する

#### Scenario: Interface boundaries preserved by skill kind

- **WHEN** 各スキルが実行される
- **THEN** システムは各スキルの規定インターフェースを厳格に適用し（`sas-proc-*` は設定JSONのみ、`vcd-categorical-analysis` は許可引数 `--out`、`inspect_data.R` は `--out-dir`）、未定義なCLI上書きや不整合な引数投入を許容しない

#### Scenario: Pre-inspection backward-compatible default output

- **WHEN** 事前検分スクリプト（`inspect_data.R`）実行時に明示的な `--out-dir` または第2引数が指定されない
- **THEN** システムは既存の呼び出し元および対話的ワークフローの後方互換性を維持するためカレントディレクトリ（`.`）への出力を許容し、明示的に `--out-dir` が渡された場合は指定ディレクトリ配下（推奨: `evidence_runs/inspections/<project>/run_<id>/`）へ成果物を隔離出力する

### Requirement: Run Isolation and No Root Leakage

すべての新規解析実行は、登録済みskill rootまたは許可されたその配下の出力rootの直下ではなく、一意なRun物理ディレクトリ `run_<canonical_id>[_N]/` 配下に完全に隔離して成果物を出力しなければならない（MUST）。出力root直下への成果物書き込みは厳格に禁止する（MUST NOT）。

#### Scenario: Artifact isolation in run directory

- **WHEN** 解析実行が正常に開始される
- **THEN** システムは解析結果ファイル（JSON, CSV, MD, HTML等）を出力root直下に書き込まず、必ず `run_<canonical_id>[_N]/` を作成してその配下に格納する

## ADDED Requirements

### Requirement: Stable Skill Output Slug Registry

システムは、各解析スキル名と一意な安定出力slugとの対応を規範台帳として保持し、すべての新規出力を登録済みslugのrootへ割り当てなければならない（MUST）。

#### Scenario: Registered analysis skill resolves its canonical root

- **WHEN** 登録済み解析スキルが出力rootを解決する
- **THEN** 次の対応を適用する: `vcd-bayesian-evidence-analysis` → `vcd_bayesian`; `vcd-categorical-analysis` → `vcd_categorical`; `vcd-categorical-reporting` → `vcd_categorical_reporting`; `comparative-design-analysis` → `comparative_design`; `evidence-decision-review` → `evidence_decision_review`; `questionnaire-batch-analysis` → `questionnaire`; `sas-proc-freq` → `sas_proc_freq`; `sas-proc-means` → `sas_proc_means`

#### Scenario: Unregistered analysis skill cannot write output

- **WHEN** 新規または既存の解析スキルがroot台帳に登録されていない状態で出力しようとする
- **THEN** システムは出力先を推測・共有せず、書込み前に未登録slugを示して停止する

### Requirement: Skill Slug Lifecycle

出力slugはSkillの表示名から独立した安定IDでなければならず（MUST）、追加・名称変更・廃止時には台帳を更新し、過去に割り当てたslugを別Skillへ再利用してはならない（MUST NOT）。

#### Scenario: Skill is renamed without changing its output contract

- **WHEN** Skillの表示名が変更されるが出力契約は互換である
- **THEN** システムは既存slugを維持し、同一の正規rootと既存runの可読性を保つ

#### Scenario: Skill is retired or its output contract becomes incompatible

- **WHEN** Skillが廃止される、または出力契約が互換性のない形に変わる
- **THEN** 廃止slugを他Skillへ再割当せず、互換性を評価した移行規則を定めたうえで必要な場合のみ新slugを登録する

### Requirement: Pass 0 Inspection Output Exception

Pass 0の入力検分は統計解析結果を生成するSkillとは別のinspection成果物として扱い、既存呼び出しとの互換例外と推奨隔離rootを維持しなければならない（MUST）。

#### Scenario: Inspection output keeps its legacy default and supports isolated output

- **WHEN** `inspect_data.R` が実行される
- **THEN** 未指定時は互換性のため `.` を使い、明示出力先が指定された場合は `evidence_runs/inspections/<project>/run_<id>/` を推奨するinspection領域に隔離して保存する
