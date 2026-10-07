# Path sanitization — allowed explanatory literals

This fixture is intentionally tracked. It documents forbidden patterns without
creating real navigation or environment-dependent absolute paths.

- Document the scheme as `` `file:///` `` (backtick literal only).
- Document placeholders such as `/Users/<user>/` or `/home/<user>/`.
- Do not create Markdown links whose destination starts with the `file:///` scheme.
- Relative links are preferred: `[evidence_gower.R](../../../.agents/shared/evidence_gower.R)`.
