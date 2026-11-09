# Design

## Context

See `proposal.md` for the problem and the delta specs for required behavior. Today `generate_comparative_report()` writes machine results, `comparative_report.md`, `dashboard.html`, a manifest, and `run_state=completed` in one call. It never reads `executive_summary.md`. The shared `run_scope.R` already provides staged Pass 2/3 finalization, validates the narrative against the Pass 1 results-manifest hash, records artifact hashes, and seals a run after Pass 3, but `vcd-categorical-reporting` does not use that lifecycle. The shared quality contract also omits this skill from its applicable-skill list.

## Goals / Non-Goals

**Goals:**

- Make the executive summary and the actual skill ID visible together in every finalized comparative Dashboard.
- Keep the final Dashboard unavailable until the summary has been written and verified against the same canonical results.
- Use the shared run lifecycle and preserve the existing `comparative-evidence.json` and 40-field summary CSV contracts.
- Make the embedded summary safe and self-contained without adding a package dependency.

**Non-Goals:**

- Automatically author an AI summary inside R.
- Change statistical estimates, thresholds, Dashboard table columns, or legacy run contents.
- Add Markdown links as a substitute for displaying the summary in the Dashboard.

## Decisions

### 1. Turn reporting into a staged run

Pass 1 will produce and validate the canonical evidence JSON, summary CSV, and machine-generated comparative Markdown report. It will keep `run_state=active`, record Pass 1 as complete, and write the Pass 1 results manifest without a final `dashboard.html`. The run handover will ask the AI to write `executive_summary.md` from those canonical artifacts and the manifest digest, then invoke a reporting-specific Pass 3 renderer.

Pass 2 will use the shared narrative staging/finalization path. Pass 3 will build `staging/dashboard.html` from the Dashboard template and the verified summary, then use the shared dashboard finalizer. Missing, empty, hash-mismatched, or wrong-run summaries will fail before promotion. Only successful Pass 3 seals the run.

### 2. Keep the results manifest stable and bind later artifacts in run metadata

The results manifest will identify the canonical Pass 1 computational artifacts and remain unchanged while the AI summary and Dashboard are created. `run_meta.json` will record the summary SHA-256 and its `based_on_results_manifest_sha256`, then the Dashboard SHA-256 and its `based_on_results_manifest_sha256` and `based_on_narrative_sha256`, following the existing shared finalization contract. This avoids a circular digest dependency and preserves the manifest as the Pass 1 evidence identity.

### 3. Embed the full summary safely near the Dashboard start

The final Dashboard will place a clearly titled executive-summary section before the filters and comparison table. It will show the human-readable skill name and the exact skill slug from `run_meta.json`. The full Markdown source will be HTML-escaped and displayed with preserved line breaks and wrapping in a preformatted text container. This preserves all summary text without executing raw HTML, script, or link markup; it also avoids introducing a Markdown-rendering dependency or external asset.

### 4. Make the skill workflow explicit

Update `vcd-categorical-reporting/SKILL.md` to require Pass 1 → AI-authored Pass 2 → Pass 3 rendering, make `executive_summary.md` and `dashboard.html` required final artifacts, and state that a Pass 1-only run is incomplete. Add `vcd-categorical-reporting` to the shared quality contract scope and specify that Pass 3 verifies the embedded summary and skill ID.

### 5. Use test-first implementation

For each lifecycle and rendering behavior, add a focused regression test that demonstrates the current failure before changing production code. Implement only enough to make that test pass, then run the targeted test. Finish with an end-to-end run that checks the handover, summary binding, safe Dashboard rendering, final run state, and manifest integrity.

### Alternatives considered

- Keep the current one-call generator and add an optional summary argument: rejected because the summary does not exist until after Pass 1 and optional input permits a finalized Dashboard without it.
- Link to `executive_summary.md` only: rejected because the user must leave the Dashboard and the requested single-surface report remains split.
- Generate a generic summary template in R: rejected because it would replace the evidence-based AI narrative with static boilerplate.
- Render arbitrary Markdown as raw HTML: rejected because it could execute untrusted markup and violate the offline/safe-rendering contract.

## Risks / Trade-offs

- [Pass 1 and Pass 2 runs remain active if the AI workflow stops] → The handover will expose the exact next action and identify the run as incomplete; only Pass 3 seals it.
- [A very long summary increases standalone Dashboard size] → Embed one escaped copy of the summary and avoid duplicating it in the page data model.
- [Preformatted display retains Markdown punctuation] → Preserve exact content and safety without new dependencies; the section heading and wrapping keep the prose readable.
- [Older reporting runs lack staged metadata and embedded summaries] → Keep them read-only and valid under their original contract; require a new run to obtain the integrated Dashboard.

## Migration Plan

New runs use the staged lifecycle after implementation. Existing completed runs are not rewritten. To obtain the new Dashboard for an old analysis, rerun the analysis into a new run directory so its summary, evidence digest, and Dashboard are bound together.
