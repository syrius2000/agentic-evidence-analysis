# Design

## Context

See `proposal.md` for motivation and `specs/` for observable requirements. 現行 `evidence-run-layout` は全解析Skillへの推奨rootを定める一方、明示rootをnamespace外でも受理する。共有 `.agents/shared/run_scope.R` はrun ID正規化・衝突回避・metadataを提供するが、Skillから渡されるout_rootが当該Skillのroot配下かは統一して検証していない。各runnerには個別root指定があり、SASは設定JSONの `output_dir` を必須としている。Pass 0検分は互換のため未指定時 `.` を許容する。

## Goals / Non-Goals

**Goals:**

- 全解析Skillの正規slug、root、runディレクトリ、および永続化ownerを同じ規範へ合わせる。
- 正規root外への新規永続出力を防ぎ、root直下への成果物漏出をなくす。
- README/AGENTS/Skill文書/schema/runner/shared実装/testsを同じ契約に合わせる。
- Pass 0既定互換とquestionnaire legacy読取を明示例外として保つ。

**Non-Goals:**

- 推論式、統計的estimand、レポート解釈規則の変更。
- 既存run、Archive、legacy成果物の移動・改名・削除。
- `.agents/skills/blind-qa-cycle/` のQA成果物レイアウト変更。
- OpenSpec文書作成だけで実改定を完了したとみなすこと。

## Decisions

### 1. `evidence-run-layout`を正規台帳とし、runtimeでも同じslug対応を強制する

以下の固定対応を仕様、共有run解決、Skill資料で一致させる:

| Skill | slug | canonical root |
|---|---|---|
| `vcd-bayesian-evidence-analysis` | `vcd_bayesian` | `evidence_runs/vcd_bayesian/` |
| `vcd-categorical-analysis` | `vcd_categorical` | `evidence_runs/vcd_categorical/` |
| `vcd-categorical-reporting` | `vcd_categorical_reporting` | `evidence_runs/vcd_categorical_reporting/` |
| `comparative-design-analysis` | `comparative_design` | `evidence_runs/comparative_design/` |
| `evidence-decision-review` | `evidence_decision_review` | `evidence_runs/evidence_decision_review/` |
| `questionnaire-batch-analysis` | `questionnaire` | `evidence_runs/questionnaire/` |
| `sas-proc-freq` | `sas_proc_freq` | `evidence_runs/sas_proc_freq/` |
| `sas-proc-means` | `sas_proc_means` | `evidence_runs/sas_proc_means/` |

Runtimeは未登録skillへrootを推測せずfail-fastする。Skill名変更時は契約互換性がある限りslugを保ち、廃止slugは再利用しない。台帳外に同じ対応表を別々に複製する設計は避け、共有resolverが参照する登録情報と仕様上の正本を同期検証する。

### 2. すべてのrun出力にskill namespaceを適用する

各runnerは正規rootを既定値とする。既存interfaceがroot値を受け取れる場合は、パスを正規化して当該Skillの `evidence_runs/<skill_slug>/` 自身またはその配下であることを確認してからrunを予約する。namespace外root、`..`、symlinkを経由した逸脱はファイル作成前に拒否する。許可済みrootの配下に `run_<canonical_id>[_N]/` を作成し、現在の原子的衝突回避を維持する。

SASの `output_dir` は設定schema上引き続き必須の入力項目として扱えるが、指定先は `evidence_runs/sas_proc_freq/` または `evidence_runs/sas_proc_means/` の対応namespace内に限定する。設定例は正規rootを示し、runnerは設定値を安全検証後に共有run予約へ渡す。

この挙動は既存の「安全な任意rootを許す」契約より狭い。namespace外への明示指定を利用していた利用者にはBREAKING CHANGEとして案内する。自動移動や外部rootへのfallbackはせず、旧成果物は現位置に保持する。

### 3. 永続化ownerは各skill固有のwriterに置く

共有の統計計算器がin-memory結果を返すだけの場合、rootを受け取らずrun directoryも作成しない。永続化するwrapper/callerがskill IDとcanonical rootを指定し、成果物・manifest・run metadataをrun directoryへ保存する。`comparative-design-analysis` は実際の呼出経路を調査してwriterを確定し、呼出側が存在しないならSkillに永続出力契約を捏造せず、その事実をtasksと確認結果に記録する。

### 4. 共通検証をrun scope境界に置き、Skill固有interfaceを保つ

共通run基盤でskill IDからrootを解決し、明示rootのnamespace検証とrun隔離を一貫して行う。既存CLI/config入口（VCDの `--out`、questionnaireの `--out`、SASのJSON `output_dir`）は維持するが、未定義overrideを新設しない。resolved `out_root`、`run_output_dir`、logical ID等の既存metadata契約は実ディスク構造と一致させる。Pass 0検分は別のinspection rootを用い、未指定時 `.` の後方互換を維持する。

### 5. 文書・schema・実装・検証を一括改定する

OpenSpecの3つの関連specを更新した後、file inventoryに従ってREADME/AGENTS/Artifacts案内、8解析Skillの入口/reference/config例/schema/runner、inspection・共有run基盤、関連testsとstatic checksを同一契約へ更新する。ファイルに契約の記載・実装がない場合は変更せず、確認根拠をinventoryへ記録する。Reportingのlegacy templateとworkflowは現行手順との境界を表示し、履歴内容は消さない。

## Risks / Trade-offs

- **[Risk]** 既存利用者がnamespace外rootを指定できなくなる → **Mitigation:** proposalと移行案内に破壊的変更を明記し、旧ファイルは保持して新規書込みのみを制限する。
- **[Risk]** 相対パス・symlinkを含む経路検証が環境差で異なる → **Mitigation:** 正規化後の実体パスと既存symlink guardを併用し、パストラバーサル・symlink逸脱の境界ケースをテストする。
- **[Risk]** writerが複数のSkillでは台帳と実際の保存ownerがずれる → **Mitigation:** file inventoryにproducer/callerを記録し、各Skillのend-to-end出力テストでroot・run metadataを照合する。
- **[Trade-off]** 任意の外部rootを許す柔軟性を減らす代わりに、repo内で予測可能な成果物配置と共通監査を優先する。

## Migration Plan

1. 変更前の既存run、Archive、legacy `runs/<id>/` は移動・上書き・削除しない。
2. runtime/schema/docs/testsを一括更新し、全Skillの既定rootと許可rootを切り替える。
3. namespace外rootを使う利用者には対応Skill namespace配下のrootへ設定変更を案内する。新旧rootを自動探索・自動移行しない。
4. 検証失敗時は当該変更をrollbackし、旧成果物は保持する。データ移行は別途承認なしに実施しない。

## Open Questions

なし。`comparative-design-analysis` の実際のwriter/caller有無など実装事実は、specの判断を先送りする質問ではなく、tasks内の必須read-only調査として解決してから実装する。
