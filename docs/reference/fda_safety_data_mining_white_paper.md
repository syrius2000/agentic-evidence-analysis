# FDA White Paper: Data Mining at FDA

created: 2026-10-02 (JST)
source_checked: 2026-10-02 (JST)
source_type: FDA web white paper

## 出典

- 発行機関: U.S. Food and Drug Administration (FDA), FDA Data Mining Council
- 原題: *Data Mining at FDA -- White Paper*
- 公式ページ: <https://www.fda.gov/science-research/data-mining/data-mining-fda-white-paper>
- 参照箇所: “The place of data mining in assessment of safety reports”; “Challenges related to the application of data mining to safety reports”
- 注意: この文書はFDA公式ページの要約・参照記録であり、原文の複製やFDAによる本リポジトリの解析方針の承認を意味しない。ページに記載されたデータ件数・運用状況には当時の情報が含まれるため、現行のFDA運用状況の根拠としては再確認が必要。

## 本リポジトリに関連する要点

1. FDAの安全性データマイニングは、製品と有害事象の報告上の関連を見つけ、潜在的な安全性シグナルの調査を優先するために使われる。自発報告データの不均衡な報告（disproportionality）は実際の発生率を表さず、統計的関連だけで因果関係やリスクを確立できない。
2. 安全性シグナルの評価閾値は、有害事象の重症度と、その製品が治療する疾患の重症度を考慮して調整される。FDAは、がん治療薬とざ瘡治療薬では安全性課題を評価する閾値が異なり得る例を挙げている。
3. データマイニングの出力は単独で因果性を判断するものではない。症例レビュー、他のデータソース、疫学的評価などを組み合わせて臨床的・公衆衛生上の意味を検討する。

## `vcd-categorical-reporting` への適用と境界

この資料は、Safety解析の実務閾値を事象の重症度や治療対象の疾患から切り離した普遍値として扱わないための背景資料として用いる。特に、`rare_ae_exploratory_v1` の `primary_delta = 0.001` をFDA推奨値、規制上の閾値、臨床的重要性の普遍基準として引用してはならない。同値は本リポジトリの探索的報告における運用上の既定値であり、事象別の臨床評価・重篤事象レビューを置き換えない。

また、このWhite Paperの中心は自発報告データのシグナル検出であり、`vcd-categorical-reporting` が扱う分母のある群別イベント頻度に基づくRDの実務領域評価とは、データ設計・推定対象・統計手法が異なる。したがって、本資料は `δ` の数値を直接正当化する数理根拠としては使わない。

## 参照時の解釈メモ

- FDA資料が支えるのは、閾値を文脈依存で扱う必要性と、シグナルを追加調査の契機として解釈すること。
- 本リポジトリで `δ` を定める場合は、対象事象、絶対リスク差の単位、観察期間、臨床的重症度、比較目的を明示し、データを見た後に閾値を選ばない。
- FDAの自発報告データに関するシグナル閾値と、本スキルのRD閾値は同一の量ではない。
