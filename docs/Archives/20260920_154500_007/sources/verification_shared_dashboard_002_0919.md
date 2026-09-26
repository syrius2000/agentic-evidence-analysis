# 共有ダッシュボード実装検証（theme-assets / Jeffreys移行）

created: 2026-09-19 01:02 (JST)
update: 2026-09-19 01:02 (JST)
author: Codex (Cursor Grok 4.6)

## 結論

OpenSpec change `shared-dashboard-theme-assets` の16タスクを実装した。表示共通化は同一事前の計算値を変えず、3次元条件付き割合の新規主事前だけを各セルα=0.5へ移した。旧UCB fixture（α記録なし／計算はα=1.0相当）は保存した。Poisson BIC・局所診断件数は新旧で一致した。commit / push / archive は未実施。

## 検証実測

| 検証 | 件数 | 失敗 | 区分 |
| --- | --- | --- | --- |
| `tests/test_vcd_categorical_dashboard_v4.R` | 15 Passed | 0 Failed | 構文・契約・生成HTML |
| `tests/test_three_way_dashboard_html.R` | 10 test_that / 74 assertions | 0 | 新規生成 band/card、終了コード確認 |
| `tests/test_shared_dashboard_math.R` | 7 test_that / 33 assertions | 0 | 数学・欠落資産・同一事前差 |
| `tests/test_three_way_computation_engine.R` | 全件 | 0 | 計算エンジン |
| 新規run HTML 静的スキャン | CDN / `https?` script-link / `/Users/` 0件 | 0 | 静的検査 |
| ブラウザ（localhost 配信の preview HTML） | アコーディオン開閉、主事前α=0.5表示、`performance` 外部resource 0件 | — | 独立QA（DOM操作） |

旧fixture HTML を成功根拠にしていない。3次元契約テストは fixture JSON をコピーした一時runから band/card を再生成し、欠落メタデータは「未確認」であり「主事前: 多項Jeffreys」を出さない。

## 新規run

- 入力: `examples/ucb_admissions.csv`（旧fixtureと同一）
- 出力: `scratch/ucb_jeffreys_crv_0919_out/run_ucb_jeffreys_091/`（旧fixture非上書き）
- 主事前: `family=symmetric_dirichlet`, α=0.5, `role=primary`, `name=jeffreys`
- 感度: α=1.0, `role=sensitivity`, `name=uniform`
- 支持集合: `observed_table_rows`, K=24, `structural_zeros_excluded=true`
- プレビューHTML SHA-256: `d4b3668220e857edf80391918632953cd52fb465cabf5fed0b37595c5bbcf286`

## 主事前変更による差（UCB Admissions）

生割合は不変。事後平均の最大差は Dept B Female（17/25）で旧α=1.0相当 0.6659 → 新α=0.5 0.6724（+0.0065）。主／感度の事後平均最大差は 0.005。A Male（512/825）は 0.6204 → 0.6206。希少層で差が大きく、大N層では小さい。Poisson BIC は M5=332.3119 / M8=339.1982 / M1=2324.0717 で一致。M5診断は regular 13 / quarantined 11 / candidate 1 で一致。

## 未実施

- Pass 2 考察と本番 `dashboard.html`（claims gate）は未作成。preview のみ。
- 2次元HTMLのブラウザ開閉は契約テストで代替。3次元previewのみブラウザ操作した。
- commit、push、OpenSpec archive は指示どおり未実施。
