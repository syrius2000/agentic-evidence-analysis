# 独立QAレビュー

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `codex/standardize-evidence-run-output-contract`
- Baseline: `17670c0516c4885c64c86731a413108a28f8cb8a`
- Reviewed: `936fa41ae57e4bde4b84a230427951ade70903cc`
- Cycle: `1`
- Audience: `cloud`
- Remote visibility: `pushed`
- Focus packs: `openspec-coherence`, `provenance-plans`, `path-sanitization`
- Gate: `HOLD`

## 結論

- `QA-SPEC-H01`: SAS PROC FREQ/MEANS のMODIFIED requirementが、namespace配下のcustom `output_dir` を許可する一方、無条件の正常終了scenarioではcanonical root直下への保存を要求しており、custom sub-root実行で同時充足できない。

## Findings

### QA-SPEC-H01: SAS custom output_dir と正常出力scenarioの保存先が矛盾
- Severity: High
- Status: OPEN
- Evidence: `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-freq/spec.md:7`, `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-freq/spec.md:11-17`, `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-means/spec.md:7`, `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-means/spec.md:11-22`
- Expected: SAS Skill はcanonical namespace自身または許可されたその配下のresolved `output_dir`をrootとして受理し、成果物をそのroot配下の `run_<canonical_id>[_N]/` に隔離する契約で一意に記述されるべきである。一般の「解析完了」scenarioはresolved rootを参照するか、canonical rootを使う条件をWHENで限定する必要がある。
- Finding: FREQはRequirement本文でcanonical rootまたはその配下の `output_dir` を許可し、configured-output scenarioでもnamespace内sub-rootを受理する一方、無条件の正常出力scenarioは `evidence_runs/sas_proc_freq/run_<canonical_id>[_N]/` 固定を要求する。MEANSも同様に `evidence_runs/sas_proc_means/run_<canonical_id>[_N]/` 固定である。例えば `output_dir=evidence_runs/sas_proc_freq/project_a` を正当に受理した場合、同じ実行に対して `.../project_a/run_*` とcanonical root直下 `.../run_*` の双方が要求され、観察可能な期待結果が矛盾する。
- repair_surface: spec

### QA-PROV-M01: tasksのOpenSpec検証コマンドがCLI契約と不一致
- Severity: Medium
- Status: OPEN
- Evidence: `openspec/changes/standardize-evidence-run-output-contract/tasks.md:16`
- Expected: Changeの検証手順は、OpenSpec CLIの有効な形式 `openspec validate standardize-evidence-run-output-contract --type change --strict`（または同等の現行サポート構文）を使い、strict validationの成否を観察可能にするべきである。
- Finding: task 2.4 は `openspec validate --change standardize-evidence-run-output-contract` を指定しているが、現行OpenSpec CLIの `validate` はitem名を位置引数で受け、`--type change` と `--strict` を使用する。`--change` は当該validate構文のオプションではなく、依頼書で要求されたstrict validationも欠けるため、計画どおり実行すると検証手順自体が失敗または要求不足になる。
- repair_surface: plan

## 検証注記

- `openspec validate standardize-evidence-run-output-contract --type change --strict`: **未実行**。独立レビュー環境に `openspec` CLI が存在せず、GitHub上のReviewed SHAに関連するworkflow run/statusも確認できなかったため、validator PASSは主張しない。
- Plan provenance: Baseline上で `implementation_plan_003_1006.md` と `implementation_plan_004_1006.md` は存在し、`implementation_plan_005_1006.md` は未存在、少なくとも006/007も未存在であることを確認した。tasks/planで明示された主要source/test pathはReviewed tree上に存在することを確認した。
- Path sanitization: Reviewed差分8ファイルについて `/Users/<user>/`, `/home/<user>/`, `file:///`, Windows drive path, UNC pathに該当する実環境依存パスは検出しなかった。

## Re-QA
- 推奨Baseline: `936fa41ae57e4bde4b84a230427951ade70903cc`
- 再確認対象: `QA-SPEC-H01`, `QA-PROV-M01`
