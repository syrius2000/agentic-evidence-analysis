---
name: blind-qa-cycle
description: >
  Explicit-only independent blind QA invite and review for local peer agents or
  GitHub/cloud agents. Supports checkpoint, cloud (Reviewed+invite+topic push+path),
  cloud re-qa, local, invite, review (cloud may commit+push QA artifacts only),
  and ingest (requester writes back review artifacts). Artifacts under
  docs/Artifacts/qa_cycles/<topic>/c<N>/. Use ONLY when explicitly invoked.
  Never auto-run after commits or OpenSpec apply. Does not Owner-decide, fix
  product code, or merge to main. Topic-only push only for cloud/cloud re-qa/
  cloud review artifacts/ingest.
disable-model-invocation: true
---

# blind-qa-cycle — Independent Blind QA Cycle

## Modes

| User intent | Mode |
| :--- | :--- |
| `/blind-qa-cycle checkpoint` | Pre-change **Baseline** local WIP commit (`Blind-QA-Checkpoint`) — name stays `checkpoint` (not renamed to setup) |
| `/blind-qa-cycle cloud` | Post-change one-shot: Reviewed Yip → `00_invite.md` → invite commit → **topic-only push** → **path handoff** |
| `/blind-qa-cycle cloud re-qa` | Re-QA: Baseline = previous cycle Reviewed; skip new checkpoint requirement |
| `/blind-qa-cycle local` | `invite` with Audience=`local` (no push; full invite body; do not paste to Cloud) |
| `/blind-qa-cycle invite`, 「QAメタデータ」 | `invite` (ask Audience if omitted) |
| `/blind-qa-cycle review`, 依頼ブロック／`00_invite.md`／相対パス | `review`（cloud は **QA 成果物のみ** commit+topic push 可） |
| `/blind-qa-cycle ingest` | 依頼側: Cloud から受け取った4ファイルを Output dir へ書き、artifact commit+topic push |
| Ambiguous | Ask once; default **`invite`** |

Never run `review` in the same chat that implemented the code under review.

## Audience (local vs cloud)

Same skill, same Output dir contract. Channel differs only in **remote visibility** and handoff form.

| Audience | Who runs `review` | SHA requirement | Default handoff |
| :--- | :--- | :--- | :--- |
| `local` | Other local agent / other chat on same clone | SHAs must exist **locally**. Unpushed OK. | Full invite body. **Do not paste to GitHub Cloud.** |
| `cloud` | GitHub / remote Cloud Agent | Baseline **and** Reviewed (and invite commit when path handoff) must be ancestors of `origin/<branch>` after fetch when possible. | **Relative path** to `00_invite.md` (preferred). Full body only if push failed. |

- If audience omitted (plain `invite`): ask once. Do not guess.
- `/blind-qa-cycle cloud` / `local` / `cloud re-qa` fix Audience without asking.
- Record in invite: `Audience` and `Remote visibility: local-only | pushed`.
- **Never paste a `local-only` invite to GitHub Cloud.**

Details: [`references/audience_channels.md`](references/audience_channels.md)

## Existing-branch WIP flow

Read [`references/git_wip_flow.md`](references/git_wip_flow.md) for the full commit and recovery rules.

```text
existing topic branch
  → /blind-qa-cycle checkpoint   # clean Baseline local commit (staged pre-change WIP)
  → implement per plan (skill idle); stage only the review set
  → /blind-qa-cycle cloud        # Reviewed Yip → invite → invite commit → topic push → path
```

An explicit `checkpoint` or `cloud` invocation authorizes the skill to create only the described commits from the staged index (plus, for `cloud`, the invite-only follow-up commit and topic-only push). The skill must inspect and report the exact staged paths before committing product/WIP changes. If unstaged or untracked files exist, or the staged set is empty when a product WIP commit is required, stop before committing. Never use `git add -A` or stage product files on the user's behalf. After writing `00_invite.md`, the skill may stage **only** that invite path (and empty parents if required) for the invite follow-up commit.

## Mode: checkpoint

Create a **clean Baseline** local commit on the existing topic branch before the next implementation increment. Do **not** rename this mode to `setup`.

1. Require a topic other than `main` / `master`, resolve the topic slug, and verify the current branch and repository root.
2. Require at least one staged change and zero unstaged or untracked changes. Otherwise stop with exact status and stage/clean-up guidance; do not stage or discard anything.
3. Show the staged path list and staged diff summary. On this explicit mode invocation, commit only the existing index with subject `Yip: WIP QA checkpoint <topic>` and trailer `Blind-QA-Checkpoint: <topic>`.
4. Record the resulting full SHA in the confirmation. The commit trailer is the branch-local lookup key used by `/blind-qa-cycle cloud`.
5. Do not write QA cycle artifacts, fetch, push, or start a review in checkpoint mode.

## Mode: cloud (shortcut)

Purpose: one command after implementation for **topic-branch cloud QA handoff** — Reviewed commit, invite artifact, invite commit, topic push, path handoff. No main merge.

1. Set Mode=`invite`, Audience=`cloud` (do not ask).
2. `branch=$(git branch --show-current)`.
   - If `branch` is `main` or `master`: **fail-fast STOP**. Do not create Reviewed/invite commits and do not push. Tell the user to switch to a non-`main`/`master` topic branch first. Confirmation does **not** override this guard.
3. Resolve topic. **Baseline** = newest matching `Blind-QA-Checkpoint: <topic>` in current branch first-parent history. If none exists, stop and direct the user to `/blind-qa-cycle checkpoint` (unless Mode `cloud re-qa` — see Re-QA). Never infer Baseline from `main`, merge-base, or an unrelated QA cycle.
4. **Reviewed WIP commit:** If the index has staged changes and the worktree has no unstaged or untracked changes, report the staged paths and create one post-change commit with subject `Yip: WIP QA review <topic>` and trailer `Blind-QA-Reviewed: <topic>`. If a matching reviewed commit is already at `HEAD` (rerun after partial success), reuse it. If neither condition holds, stop without committing.
5. Set Reviewed to that commit and verify Baseline and Reviewed SHAs locally. Collect subjects, `git diff --name-status`, and `git diff --stat` for the invite (orientation only; review inspects the real diff).
6. Choose next cycle folder `docs/Artifacts/qa_cycles/<topic>/c<N>/` (max N+1). Write `00_invite.md` there (**after** Reviewed is fixed so invite files are **not** in Baseline..Reviewed).
7. **Invite follow-up commit:** Stage only the new `00_invite.md` (and directory placeholders if needed). Commit with subject `Yip: QA invite <topic> c<N>` and trailer `Blind-QA-Invite: <topic>`. Do not amend Reviewed. Record Invite commit SHA separately from Reviewed.
8. Prefer `git fetch origin` (warn if fetch fails; use existing `origin/<branch>` refs).
9. **Topic-only push (authorized by this explicit `/blind-qa-cycle cloud` invocation):**
   - Run `git push -u origin HEAD` for the **current topic branch only**.
   - **Never** merge to `main` / `master`. **Never** force-push unless the user gave a separate explicit force-push order in the same turn.
10. **Preflight after push (or against existing origin):**
    - `git merge-base --is-ancestor <baseline> origin/<branch>`
    - `git merge-base --is-ancestor <reviewed> origin/<branch>`
    - Prefer also: invite commit is ancestor of `origin/<branch>` when path handoff is used.
11. **On push or preflight FAIL:** Keep local Reviewed and invite commits. Do **not** claim path handoff works. Show topic-only push help and emit **full invite body** as fallback paste. Stop. Do not merge to main.
12. **On SUCCESS:** Set `Remote visibility: pushed`, optional `Tracking: origin/<branch>@<tip-sha>`. Emit Cloud handoff as **one relative path line** (preferred):

    ```text
    docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md
    ```

    Optionally show Reviewed / Invite / Baseline SHAs in ≤5 bullets. Do not dump the full invite body unless fallback. Do not `gh pr comment` unless explicitly asked.

## Mode: cloud re-qa

Required when closing findings from a frozen cycle (`HOLD` / `FAIL`).

1. Audience=`cloud`. Inputs: topic, previous cycle path (default: latest `cN` under topic), Finding IDs to close (from previous `02_tasks.md` / review), Reviewed tip (usually current HEAD after repair Yip commit).
2. `branch=$(git branch --show-current)`. If `branch` is `main` or `master`: **fail-fast STOP** (same guard as `cloud` step 2). No Reviewed/invite commit and no push.
3. **Baseline default** = previous cycle's **Reviewed** SHA (not a new checkpoint). Do **not** require `Blind-QA-Checkpoint` for this mode.
4. If repair is not yet committed: same staged-clean rules as `cloud` step 4 to create Reviewed; else reuse HEAD if it is the repair tip.
5. Create **`c{N+1}`**; never mutate frozen `cN`.
6. Continue with invite file → invite commit → topic-only push → path handoff (same as `cloud` steps 6–12).

## Mode: local (shortcut)

1. Set Audience=`local`, `Remote visibility: local-only`.
2. Run standard invite (skip origin ancestor check and push; optional warn if unpushed).
3. Emit **full invite body** with explicit **Do not paste to GitHub Cloud.**

## Output directory (canonical)

```text
docs/Artifacts/qa_cycles/<topic>/c<N>/
  00_invite.md
  01_review.md
  02_tasks.md
  03_machine.json
  STATUS.md
```

- `<topic>`: OpenSpec change name, else short kebab-case slug
- Re-QA always creates **`c{N+1}`**; freeze prior cycle
- Placement rules: [`docs/Artifacts/README.md`](../../../docs/Artifacts/README.md)
- JSON keys: [`references/machine_schema.md`](references/machine_schema.md)

## Focus packs

Load only packs named in the invite:

- [`references/focus_math_definitions.md`](references/focus_math_definitions.md)
- [`references/focus_path_sanitization.md`](references/focus_path_sanitization.md)
- [`references/focus_openspec_coherence.md`](references/focus_openspec_coherence.md)
- [`references/focus_provenance_plans.md`](references/focus_provenance_plans.md)

## Mode: invite

Used by `cloud` / `local` / plain invite. Plain invite does **not** create WIP commits or push unless entered via `cloud`.

1. Resolve **full** SHAs: `git rev-parse <baseline>` / `git rev-parse <reviewed>`. Fail if unresolved locally.
2. Resolve **Audience** (`local` | `cloud`). Ask once if missing (unless entered via shortcut).
3. For bare `invite` with Audience=`cloud` **without** going through Mode cloud's commit/push pipeline: run remote visibility gate only; on FAIL print push help and do not claim path handoff; on SUCCESS may emit path if `00_invite.md` is already on `origin/<branch>`, else full body.
4. For `audience=local`: set `Remote visibility: local-only`. Skip origin ancestor check (optional warn if unpushed).
5. Choose `topic` and next cycle: list `docs/Artifacts/qa_cycles/<topic>/c*`, use max N+1 (start at `c1`).
6. Collect **Requester notes** (or `(none)`). Do not rewrite focus pack bodies.
7. Select focus pack id(s).
8. Read [`references/cloud_output_contract.md`](references/cloud_output_contract.md). For cloud path handoff, the reviewer loads `00_invite.md` from git; still keep the invite file self-contained (inline focus criteria and output templates inside `00_invite.md`).
9. Write `00_invite.md` with required fields below. **Handoff:**
   - cloud + pushed + invite on origin → emit **relative path only**
   - otherwise → emit one fenced full markdown block

```markdown
# 独立 QA レビュー依頼: <title>

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `<branch>`
- **Baseline commit:** `<full-sha>`
- **Reviewed commit:** `<full-sha>`
- **Reviewed subject:** `<git log -1 --format=%s reviewed>`
- **Diff:** `git diff <baseline> <reviewed>`
- **Focus pack:** `<pack-ids>`
- **Output dir:** `docs/Artifacts/qa_cycles/<topic>/c<N>/`
- **Cycle:** `<N>`
- **Audience:** `local` | `cloud`
- **Remote visibility:** `local-only` | `pushed`
- **Baseline subject:** `<git log -1 --format=%s baseline>`
- **Changed paths:** `<git diff --name-status baseline reviewed>`
- **Diff summary:** `<git diff --stat baseline reviewed>`
- **Requester notes:**
  - <bullets or "(none)">

## 重点監査観点

<from selected focus pack references>

## Reviewer contract

- Write ONLY under Output dir: `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md`. Do **not** modify `00_invite.md` or any product/code paths outside that Output dir.
- Create all four files in the specified Output dir in the QA checkout. Follow the exact templates and completeness checks in [`references/cloud_output_contract.md`](references/cloud_output_contract.md).
- Create the Output dir if it is absent; never overwrite a frozen prior cycle.
- Findings only in `01_review.md` (no long Aligned formula dumps); write the report in Japanese, preserving code identifiers in English.
- Every actionable finding must have a task; every High finding must have one. Each task identifies the finding ID, path, concrete completion condition, and verification/expected result.
- Chat final reply ≤5 bullets (Gate / Output dir / Blocking count / Task count / Next action / Artifacts git SHA or ingest-needed).
- **Do not** edit product code, change Baseline/Reviewed SHAs, merge to main, force-push, or Owner-decide (no ACCEPT/ARCHIVE).
- **Git 帰着（Audience=`cloud`）:** After the four files are complete, stage **only** those four paths under Output dir, commit `Yip: QA review <topic> c<N>` with trailer `Blind-QA-Review-Artifacts: <topic>`, then **topic-only** `git push -u origin HEAD`. This artifact push is authorized by explicit `/blind-qa-cycle review` with Audience=`cloud`.
- If the cloud environment **cannot** push or cannot write to a clone of the topic branch: do **not** claim repo persistence; return the four file bodies for requester `/blind-qa-cycle ingest`.
- If Baseline or Reviewed SHA is missing in this clone: do NOT review another tip; Gate HOLD with High provenance finding; still write the four artifacts (and attempt artifact commit/push or return bodies per above).
```

Required fields (fail invite if any missing): Repository, Branch, both full SHAs, both commit subjects, Diff, Focus pack, **Output dir**, Cycle, **Audience**, **Remote visibility**, changed paths, diff summary, Requester notes, Reviewer contract, complete inline output requirements and templates.

1. Do not auto-run `gh pr comment` unless the user explicitly asks; then confirm before posting. Refuse posting when `Remote visibility: local-only`.
2. **Push policy:**
   - `/blind-qa-cycle cloud` / `cloud re-qa`: topic-only push of Reviewed+invite commits.
   - `/blind-qa-cycle review` with Audience=`cloud`: topic-only push of **QA artifact commit only** (four files under Output dir).
   - `/blind-qa-cycle ingest`: topic-only push of the same artifact commit after writing files locally.
   - `checkpoint` / `local` / plain `invite`: must not push.
   - Never merge to `main`. Force-push requires a separate explicit user order.

## Mode: review

1. Require invite metadata (message, `00_invite.md`, or a repo-relative path to `00_invite.md`). Missing SHA, Output dir, or Audience → stop.
2. Confirm you are not the implementer of the reviewed commit in this chat; if you are, refuse `review`.
3. **SHA availability (before any math review):**
   - `git rev-parse <baseline>` and `git rev-parse <reviewed>` must succeed in **this** clone.
   - If either fails (typical cloud + unpushed Reviewed):
     - Do **not** substitute `HEAD` / another commit for the missing SHA.
     - Write the four artifacts under Output dir with Gate **`HOLD`**.
     - One High finding e.g. `QA-PROV-H01` (repair_surface: `plan`): specified SHA not present; independent review of requested tip impossible.
     - Task with `closes:` requiring push (cloud) or corrected invite.
     - Still attempt artifact git 帰着 (step 10) or return bodies for ingest.
     - Chat ≤5 bullets. Stop after 帰着 attempt.
4. Inspect only `git diff <baseline> <reviewed>` (blind: treat implementer narrative / prior flat QA PASS as **claim**, not proof). Use changed-path and stat summaries only to navigate; verify findings against the actual diff and source files.
5. Write `01_review.md` (Japanese body; code ids in English):
   - Header: repo, branch, baseline, reviewed, cycle, audience, remote visibility, focus, **Gate**
   - §結論: Blocking items only, one line each
   - §Findings: mismatches only. ID `QA-<AREA>-<H|M|L|P><nn>`, Severity, Status, Evidence `path:line`, Expected, `repair_surface` (`docs`|`code`|`spec`|`plan`)
   - §Re-QA: next baseline default = this reviewed SHA
   - **Forbidden:** long Aligned formula catalogs; broken TeX; Owner ACCEPT/ARCHIVE
6. Write `02_tasks.md`:
   - Follow [`references/cloud_output_contract.md`](references/cloud_output_contract.md).
   - All actionable findings map to a task; High → task required; PASS notes → no task.
7. Write `03_machine.json` per [`references/machine_schema.md`](references/machine_schema.md) (include `audience`, `remote_visibility`).
8. Write `STATUS.md` with single token Gate: `PASS` | `HOLD` | `FAIL` | `INCONCLUSIVE`.
9. **Do not** edit product code or `00_invite.md`.
10. **Artifact git 帰着:**
    - Before any artifact commit or push: `branch=$(git branch --show-current)`. If `branch` is `main` or `master`: **fail-fast STOP** (same guard as `cloud`). Do not commit artifacts and do not push. Confirmation does **not** override.
    - **Audience=`cloud`:** Stage only `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md` under Output dir (worktree otherwise clean aside from those). Commit `Yip: QA review <topic> c<N>` with trailer `Blind-QA-Review-Artifacts: <topic>`. Run topic-only `git push -u origin HEAD`. Report Artifacts commit SHA. On push failure: keep local commit if created; return four file bodies; tell requester to run `/blind-qa-cycle ingest`.
    - **Audience=`local`:** Writing into the shared clone is enough; do not push unless the user separately asks.
11. Chat final reply ≤5 bullets including Gate, Output dir, Blocking/Task counts, and Artifacts SHA **or** `ingest-needed`.

## Mode: ingest

Use when Cloud review returned four file bodies (or a patch) but could not push to origin.

1. Require Output dir path and the four file contents (or paths the user staged). Audience effectively `cloud` handoff cleanup.
2. `branch=$(git branch --show-current)`. If `branch` is `main` or `master`: **fail-fast STOP** (same guard as `cloud` / cloud `review`). Do not write-commit-push on main.
3. Write/overwrite only `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md` under that Output dir. Never modify `00_invite.md` or product code.
4. Require worktree clean except those four paths. Commit `Yip: QA review <topic> c<N>` with `Blind-QA-Review-Artifacts: <topic>` if not already committed.
5. Topic-only `git push -u origin HEAD`. Never merge to main / force-push.
6. Confirm with Artifacts commit SHA and relative Output dir. Stop.

## Re-QA (`c{N+1}`)

Prefer `/blind-qa-cycle cloud re-qa`. Required inputs: new Reviewed SHA (or staged repair), previous cycle path, Finding IDs to close, Audience=`cloud` for cloud path. Baseline default = previous cycle's Reviewed. Create new folder; do not mutate frozen `cN`. Checkpoint is **not** required for Re-QA when Baseline is taken from the previous cycle Reviewed SHA.

## Out of scope

Implementation/repair of product code, merge to main, Owner sign-off, Artifacts flat-file migration, always-on `gh` posting, renaming `checkpoint` to `setup`, silent push outside explicit `cloud` / `cloud re-qa` / cloud `review` artifact push / `ingest`.
