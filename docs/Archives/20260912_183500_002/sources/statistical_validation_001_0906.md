# 3次元探索支援の実装・検証結果

created: 2026-09-06 23:31 (JST)
update: 2026-09-06 23:31 (JST)
author: Codex (GPT-6)

## 到達点

[承認対象の計画](implementation_plan_006_0906.md)に基づき、本リポジトリの既存スキルへ新しい3次元経路を追加した。整数度数の集約、9モデル、基準モデル別セル診断、条件付き割合・差のベイズ推定、事前感度、Pass 0、数値根拠付きの日本語AI考察、HTMLまで接続した。旧エンジンの計算は変更していない。新旧の結果schema・rendererは分離した。

初期版の機能検証は完了した。講座での最終利用者受入、実RWD1件での受入、旧全スキルの一括検証は未実施であり、完成済みとは扱わない。

## まず確認する成果物

| 実例 | 日本語考察・HTML |
| --- | --- |
| Titanic原表・目的変数あり | [レポート](../../output/statistical_foundations/verified_0906/runs/run_tit_1_dir/dashboard.html) |
| Titanic人工100倍・目的変数あり | [レポート](../../output/statistical_foundations/verified_0906/runs/run_tit_100_dir/dashboard.html) |
| Titanic原表・対称探索 | [レポート](../../output/statistical_foundations/verified_0906/runs/run_tit_1_exp/dashboard.html) |
| Titanic人工100倍・対称探索 | [レポート](../../output/statistical_foundations/verified_0906/runs/run_tit_100_exp/dashboard.html) |
| HairEyeColor原表 | [レポート](../../output/statistical_foundations/verified_0906/runs/run_hair_1_dir/dashboard.html) |
| HairEyeColor人工100倍 | [レポート](../../output/statistical_foundations/verified_0906/runs/run_hair_100_dir/dashboard.html) |

各runには設定、検分、正規化集計表、結果JSON、考察、品質確認、数値主張一覧を保存した。結果はGit管理外なので、別環境では下の手順で再生成する。[利用スキル](../../.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md)と[統計契約](../../.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md)が入口となる。

## 継承した情報と変更点

他AIの試作、改定計画、HairEyeColorコメントを利用した。閉形式とIPFの独立参照コードを継承し、入力・計算の正本と検証を分けた。[取り込み元とSHA-256](../../tests/statistical_foundations/upstream_provenance.json)に記録した。別worktreeは変更していない。

修正した主な問題は、閉形式不一致の総合判定漏れ、校正失敗の正常終了、固定0.01のMC許容幅、無視された事前設定、未実装の条件付き割合、任意式の抽出経路、重複セルと欠測の扱いである。新経路は5MCSEとCDF基準を使用し、不一致を終了コード1へ伝える。独立性未解決・構造ゼロは終了2で保留する。

数値的な問題も実検証で修正した。Titanic人工100倍の飽和GLMでは、逸脱度が丸め誤差近くに達した後の厳しすぎる収束判定で非収束になった。GLM反復基準を1e-9に変更し、独立参照の許容差は緩めずに全モデルを再照合した。leverageは途中反復の重みに依存するhatvaluesから、最終適合値による重み付きQRへ変更し、倍率不変性を確認した。ゼロセルの局所ダミーは明示的に境界扱いにした。

## 検証結果

- 9ケース × 9モデル = 81モデルでGLM対IPF、閉形式のあるモデルでは閉形式とも照合した。全9ケースがCOMPUTED、参照照合・主事前MC校正・条件付き校正を通過した。特定のモデル勝者は合格条件にしていない。
- [入力・数理・異常系44項目](../../output/statistical_foundations/verified_0906/contract_test_results.json)、[統合・倍率・終了コード・再現性45項目](../../output/statistical_foundations/verified_0906/acceptance_test_results.json)、[レポート9項目](../../output/statistical_foundations/verified_0906/report_test_results.json)、計98項目が通過した。
- 独立性未解決、構造ゼロ、負・非整数・無限度数、欠測、未知列・演算子、ハッシュ変更、重複集約、未記載セル、境界・従属ダミー、極端な対数P値を確認した。
- 故意に閉形式参照だけを壊した実行はCHECK_FAILED・終了1。偏った事後標本はMC校正で不合格。数値主張・ハッシュ不一致、考察欠如ではHTMLを生成しない。
- 同じseed・設定で別runへ再実行し、models・comparisons・cells・posterior・checksの保存JSONが一致した。既存runの上書きを拒否し、元TitanicのSHA-256を保持した。
- 設定例と生成設定12件をJSON Schemaで検証した。OpenSpec strict、git diff --checkを確認した。旧全スキルのテストを実行したという意味ではない。
- HairEyeColorとTitanic人工100倍を実ブラウザーで確認した。日本語、条件付き割合、倍率の注意、各基準の2層・合計6ヒートマップ、横幅を確認した。[全体画像](../../output/statistical_foundations/verified_0906/hair_overview.png)、[セル画像](../../output/statistical_foundations/verified_0906/hair_cells.png)。コンソールはfaviconの404のみで、内容の描画エラーはなかった。

最終計算後の変更はvalidate-onlyで検分サマリーを表示するCLI部分と文書・検証運用の仕上げであり、統計計算の式は変更していない。結果には実行時の計算ソースハッシュを保存し、現在のCLIファイルのハッシュと区別する。

通常の本番入口でも元Titanicの32行を16セルへ集約して実行し、検証入口とmodels・cells・posteriorが一致した。独立参照未実行の本番出力はchecks=NOT_RUNと明示した。

## 数学的な採否

| 対象 | 採否と適用範囲 |
| --- | --- |
| 9階層モデル | 採用。主効果・2因子関連・3次交互作用を分け、目的変数の有無で集合を変えない |
| 固定Nの多項BIC | 採用。Poissonとの共通尤度項と階数差を導出し、直接多項尤度・モデル間BIC差を照合。stats::BICの行数版をRの誤りとは呼ばない |
| EBIC | 新経路では不採用。限定9候補に追加組合せ罰則を課すモデル空間・事前を正当化していない。原典と旧実装の全面監査は残課題 |
| 旧Pearson²−logN | 監査列だけ。局所BF、実質的重要性、真の信号判定には使わない |
| 局所ΔG²とscore統計量 | 採用。M1/M7/M8基準の再適合とleverage補正を区別する。カイ二乗P値は漸近値で、正確な有限標本検定ではない |
| log(O/E)、d/√N、ΔG²/N | 採用。固定モデルの倍率不変性を検証。普遍的な重要性閾値は与えない |
| Dirichlet事後 | 採用。セル確率と条件付き割合をBeta周辺で照合。差は同一同時標本。点ごとの区間で、多重性未調整 |
| 厳密BF | 明示事前の独立対飽和のみ採用。小さな2×2×2表を階乗有限積で独立照合。ほか7モデルの厳密BF・モデル事後確率は未算出 |
| PPC | 主事前a=1の飽和モデルに固定N・Freeman–Tukeyを適用。事前感度は割合・差・BFで比較。PPCを全事前で繰り返す拡張は未実施 |
| 影響度・安定性 | leverageと推定状態を表示するが、削除診断・bootstrapによる影響度や安定性とは呼ばない |

初期版では比較する両モデルの期待度数が全て5以上のときだけ近似推論を表示する。これは保守的な運用基準で、厳密な誤差保証ではない。したがってHairEyeColor原表の漸近P値には保留が多い。計算済みの効果や明示ベイズ推定と区別して読める。

## 実例で分かったこと

Titanicは元表から強い関連を含む。M8の逸脱度は原表65.17983、100倍6517.98310。log(O/E)など固定モデルの正規化量は変わらず、P値・BF・信用区間は変わる。「100倍で初めて有意」が必要とはしなかった。

HairEyeColorではM7の逸脱度156.67789からM8の6.76125へ改善する。一方、独立対飽和の厳密log BFはa=1で−14.54486、a=0.1で−69.14132、a=10で31.78381となり、事前によって支持方向が変わる。これを「関連がない」と短絡せず、比較モデルの選び方・事前と、Hair–Eyeの構造・セル効果を分けて説明した。ベイズなら問題が消えるとする設計から離れるための重要な教材になる。

数値根拠付き考察は実際にCodexが作成して全文を確認した。ただし別LLMによる独立の盲検評価は未実施。rendererは登録された数値の一致を検証するだけで、未登録の数値や全文の正しい解釈を自動保証しない。

## 再現手順と環境

R 4.6.1、jsonlite 2.0.0。参照計算はstats::loglinと既存dplyr、検分はreadr、HTMLは既存htmltools・commonmarkを使用した。依存関係を追加インストールしていない。乱数seed=20260906、独立事後標本20,000。数値許容差は絶対1e-8＋相対1e-6。MCは5MCSEと分位点CDF基準。

リポジトリルートで、新しい保存先を指定する。

```bash
Rscript tests/statistical_foundations/prepare_cases.R output/statistical_foundations/new_acceptance
Rscript tests/statistical_foundations/run_cases.R output/statistical_foundations/new_acceptance
Rscript tests/statistical_foundations/test_contract.R output/statistical_foundations/new_acceptance
python3 tests/statistical_foundations/test_acceptance.py output/statistical_foundations/new_acceptance
```

考察は計算後にスキルのPass 2/2.5に従って作成する。自動の空欄テンプレートを完成考察として出力しない。設定例では元TitanicのAge合算を重複セル集約で処理する。

## 次の順序

1. まず上のHairEyeColor原表と100倍、Titanic原表を読み、講座の説明量と図表の使いやすさを利用者が確認する。
2. 実際のアンケートまたはRWD集計1件に適用し、Pass 0で標本単位・重複・分母・除外条件を確認する。
3. 必要性が見えた後に、旧2次元・questionnaire抽出の移行、構造ゼロ、bootstrap、多重性、階層的縮約を別計画にする。階層モデルは疎なセルの部分プーリングに期待できるが、事前設計・識別性・MCMC診断と計算負担が増すため今回は導入しない。
4. FREQ相当、次にMEANS相当を別スキルとして計画する。全機能・SAS構文互換は先取りしない。

commit・push・archiveは行っていない。
