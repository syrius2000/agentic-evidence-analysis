# Focus pack: path-sanitization

Use when the invite lists `path-sanitization`.

## 重点監査観点（Audit Criteria）

1. **環境依存パスおよび個人情報の完全無害化**:
   - リポジトリ全体で特定個人名や OS ローカル絶対パス（`/Users/<user>/...` 等）、および Markdown 内 `file:///` リンクが完全に排除されているか。

## Reviewer notes

- Scope default: **reviewed commit tree content** (not full git history rewrite).
- Distinguish:
  - **Real** absolute paths / `file:///` navigation links → Finding
  - **Literal** forbid-patterns inside rules/tests/docs that explain detection → not a Finding (note as Scope note / PASS caveat)
- Also check Windows drive letters and UNC forms when present in the diff.
- History / author metadata “zero PII” is a separate contract; do not HOLD path sanitization solely for git author names unless the invite explicitly expands scope.
