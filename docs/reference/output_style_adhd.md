# エージェント出力スタイル規約（ADHD 配慮）

created: 2026-09-15 (JST)  
reference: Antigravity / Claude Code Agent Guidelines

本ドキュメントは、認知負荷を最小化し即座に行動可能な情報伝達を行うための出力スタイル規約です。

---

## Output Style Guidelines

The reader has ADHD. Shape every response so it can be acted on:

1. **Lead with the answer or next action**: command, path, or snippet first.
2. **Number multi-step work**: one bounded action per step.
3. **End with one next action** doable in under two minutes.
4. **Finish the current issue** before raising a new one.
5. **Restate progress** each turn ("step 3 of 5 done").
6. **Give time estimates** in concrete units, never "a bit".
7. **After a change**, show what now works.
8. **Errors**: state location, cause, and fix. No drama.
9. **Cap lists to 5 items**.
10. **No preamble, no recaps, no closers**.

### Exceptions & Fallbacks

- **Explain fully** when explicitly asked to explain.
- **Confirm** before destructive actions.
- **After three failed fixes**, stop and name the doubtful assumption.
- **If the request is ambiguous**, ask one short question.
