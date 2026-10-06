# 修復タスク

created: 2026-10-06 18:09 (JST)
update: 2026-10-06 18:09 (JST)
author: Codex (GPT-6.1-sol)

- [ ] T-01 (closes: QA-TEST-H01) severity=High; path=`tests/test_skill_run_isolation.R`; action=stable slug rootとcustom rootの期待値を、resolverと同じmacOSシステム別名の実体パス規則で比較するよう修正する。`run_scope.R`のsymlink拒否・namespace制約は変更しない。; done_when=`Rscript tests/test_skill_run_isolation.R`がstable slug root 8件とcustom root 1件を含めて失敗0・終了コード0となる。; verify=macOS上で当該テストを実行し、77件以上の検査が全件PASSであることを確認する。
