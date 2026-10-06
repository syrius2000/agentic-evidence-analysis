# Proposal

## Why

解析Skill間で正規出力ルートの記載・設定・永続化責務が揃っておらず、特に比較デザイン系とSAS系では共通root契約からの解釈差が残っている。出力の場所とrun隔離を単一の規範に揃え、利用者がSkillをまたいでも一貫して成果物を発見・監査できるようにする。

## What Changes

- **BREAKING**: 全解析Skillに安定slugを割り当て、既定出力rootを `evidence_runs/<skill_slug>/`、成果物の格納先をその配下の `run_<canonical_id>[_N]/` に統一する。明示root指定は割当済みskill root配下に制限する。
- `comparative-design-analysis` は永続化するwrapper/callerが `comparative_design` rootとrun隔離を担い、in-memory推論器の責務とは分ける。
- SAS PROC FREQ/MEANSの `output_dir` を各SAS Skillの正規rootに結び、成果物を共通runディレクトリ内に保存する。
- Pass 0検分とquestionnaire legacy読取は既存の明示例外として保持し、解析成果物と区別する。
- OpenSpecの共通仕様、README/AGENTS、全解析Skillの該当文書、schema、runner/shared実装、関連テスト・fixturesを横断照合し、対象不整合を一式改定する。
- 正規slug台帳とslugの追加・名称変更・廃止ライフサイクルを規範化する。Archivesと明示legacy資料は履歴として保全する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `evidence-run-layout`: 安定slug台帳、各Skillの正規root、明示rootの許容境界、run隔離、Pass 0例外を規範化する。
- `sas-proc-freq`: 3点セット成果物をSAS Skill正規root配下の共通runディレクトリへ保存する要件を明確化する。
- `sas-proc-means`: 3点セット成果物をSAS Skill正規root配下の共通runディレクトリへ保存する要件を明確化する。

## Impact

- Affected specifications: `openspec/specs/evidence-run-layout/`, `openspec/specs/sas-proc-freq/`, `openspec/specs/sas-proc-means/`.
- Affected documentation: `README.md`, `AGENTS.md`, `docs/Artifacts/README.md`、全解析Skillの `SKILL.md` と出力root/run記述を持つreferences。
- Affected implementation/configuration: `.agents/skills/` の8解析Skillのschema・templates・runners、`.agents/shared/` のrun scope/finalizationおよびPass 0 inspection、関連するトップレベル `schemas/`。
- Affected verification: 出力先・run isolation・metadataを検証するtests、fixtures、static documentation consistency checks。
- No change to statistical estimands, inference formulas, report interpretation policy, or archived run contents.
