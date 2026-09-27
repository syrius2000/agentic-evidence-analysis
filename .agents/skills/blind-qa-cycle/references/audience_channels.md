# Audience channels — local vs cloud

One skill (`blind-qa-cycle`), one Output dir contract. Choose **Audience** at invite time (or via shortcuts).

## Shortcuts

| Invoke | Audience | Notes |
| :--- | :--- | :--- |
| `/blind-qa-cycle checkpoint` | (n/a) | Baseline local commit only. No invite, no push. |
| `/blind-qa-cycle cloud` | `cloud` | Reviewed Yip → invite file → invite commit → **topic-only push** → **path handoff**. |
| `/blind-qa-cycle cloud re-qa` | `cloud` | Baseline = previous cycle Reviewed; then same as cloud one-shot. |
| `/blind-qa-cycle local` | `local` | Skip origin check and push. Full body; do not paste to GitHub Cloud. |
| `/blind-qa-cycle invite` | ask if omitted | Full invite flow; no push unless via `cloud`. |
| `/blind-qa-cycle review` | from invite | Cloud: write 4 artifacts then **artifact-only** commit+topic push (or return bodies for ingest). |
| `/blind-qa-cycle ingest` | (n/a) | Requester writes returned 4 files → artifact commit+topic push. |

## local

- Reviewer: another local agent or another chat on the **same** git clone / worktree.
- SHAs need only resolve with `git rev-parse` locally.
- Unpushed commits are allowed.
- Invite must set `Remote visibility: local-only`.
- Handoff: **full invite body**. Do **not** paste to GitHub Cloud Agents.

## cloud

- Reviewer: GitHub-hosted / remote agent whose clone tracks `origin`.
- Preferred handoff after successful topic push:

  ```text
  docs/Artifacts/qa_cycles/<topic>/c<N>/00_invite.md
  ```

  Cloud reads that path from git. Full-body paste is **fallback** when push/preflight fails or invite is not on origin.
- After optional `git fetch origin`, Baseline and Reviewed must satisfy:
  `git merge-base --is-ancestor <sha> origin/<branch>`
  where `<branch>` is the **topic branch** named in the invite (not necessarily `main`). Prefer the invite commit also on origin for path handoff.
- **Push authorization:** Explicit `/blind-qa-cycle cloud` or `/blind-qa-cycle cloud re-qa` authorizes **one** topic-only:

  ```text
  git push -u origin HEAD
  ```

  Precondition: current branch must **not** be `main` / `master` (fail-fast; confirmation does not override). Applies to `/blind-qa-cycle cloud`, `cloud re-qa`, cloud `review` artifact push, and `ingest`. Explicit `/blind-qa-cycle review` (Audience=`cloud`) or `/blind-qa-cycle ingest` authorizes the same topic-only push **after** an artifacts-only commit (`Blind-QA-Review-Artifacts`) **only** on a non-main topic branch. This does **not** merge to main and does **not** force-push. Other modes must not push.
- If cloud **review** cannot push: return four file bodies; requester runs `/blind-qa-cycle ingest`. Do not claim origin persistence.
- If cloud **invite** push/preflight fails: keep local commits; show topic-only push help; emit full invite body as fallback; do not claim path handoff.
- Invite must set `Remote visibility: pushed` when invite preflight succeeds.
- Typical flow: `checkpoint` → implement → stage → `/blind-qa-cycle cloud` → Cloud opens the path → **review** writes+pushes QA artifacts (or ingest) → later merge to `main` (out of scope).

## review when SHA missing

If the reviewer clone cannot resolve the invite SHAs:

1. Do not silently review `HEAD` or “nearest” remote tip as if it were Reviewed.
2. Gate `HOLD` with High provenance finding (`repair_surface: plan`).
3. Still write `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md` under the Output dir.
