# 3次元カテゴリカル探索の数理

created: 2026-09-06 23:48 (JST)
update: 2026-09-06 23:48 (JST)
author: Codex (GPT-5)

この文書は、集計済みの3変数カテゴリカル表を探索する現行経路の学習用リファレンスです。実装の入口は [vcd-bayesian-evidence-analysis](../../.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md)、入力と推論の制約は [three_way_contract.md](../../.agents/skills/vcd-bayesian-evidence-analysis/references/three_way_contract.md) です。

## 1. 入力を先に固定する

入力は、3つのカテゴリ変数 `A, B, C` と非負整数の度数 `n_ijk` を持つ集計表です。個票へ展開せず、同じ組合せの複数行は合算します。分析前に、次を `analysis_config.json` とPass 0の検分結果へ保存します。

- 変数、水準順、度数列、総度数 `N = Σ n_ijk`
- 欠測、未記載セル、標本ゼロ、構造ゼロの意味
- 標本単位、重複、独立性の仮定
- 目的変数を指定するか、3変数を対称に探索するか
- 抽出条件、分母、実用上意味のある差の定義

集計表だけから患者・回答者の重複やクラスタ依存性を自動判定することはできません。独立性が未解決なら、数値を計算しても推論結果は保留します。

## 2. 階層対数線形モデル

Poisson表現は、セルの期待度数を

\[
  n_{ijk} \sim \operatorname{Poisson}(\mu_{ijk}),\qquad
  \log \mu_{ijk} = X_{ijk}\beta
\]

と置きます。3変数の主効果を含む階層モデルを次の9個に固定します。`[AB][C]`はABの関連を許し、Cとの関連は主効果だけにする表記です。

| ID | 最大項 | 問う構造 |
| --- | --- | --- |
| M1 | `[A][B][C]` | 相互独立 |
| M2 | `[AB][C]` | ABだけの周辺関連 |
| M3 | `[AC][B]` | ACだけの周辺関連 |
| M4 | `[BC][A]` | BCだけの周辺関連 |
| M5 | `[AB][AC]` | BとCがAの下で条件付き独立 |
| M6 | `[AB][BC]` | AとCがBの下で条件付き独立 |
| M7 | `[AC][BC]` | AとBがCの下で条件付き独立 |
| M8 | `[AB][AC][BC]` | 全ての2因子関連、3次交互作用なし |
| M9 | `[ABC]` | 飽和モデル、3次交互作用を含む |

目的変数を指定しても、比較する9モデルは変えません。目的変数指定は条件付き割合や層間差を読む切り口にだけ使います。モデルを選んだ理由は、P値だけでなく、構造上の問い、尤度差、効果の大きさ、データの疎らさとともに記録します。

Rの `glm(..., family = poisson())` は対数線形モデルを適合できます。`stats::loglin()` は反復比例適合（IPF）による独立参照として使えます。`loglin`の漸近カイ二乗近似は構造ゼロがないことを前提にしているため、構造ゼロは本経路で保留します。[R `glm`公式](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/glm.html)、[R `loglin`公式](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/loglin.html)

## 3. 尤度、逸脱度、BIC

Poisson対数尤度を `ℓ_P` とすると、固定総度数の多項尤度は共通項を除いて比較できます。本実装では

\[
  \ell_M = \ell_P - \{N\log N - N - \log(N!)\}
\]

を保存します。Poissonの設計行列の階数を `r` とすると、固定総度数の多項パラメータ数は `r - 1` です。したがって比較用のBICは

\[
  \operatorname{BIC}_M = -2\ell_M + (r-1)\log N
\]

です。Rの `BIC(glm_object)` が行数を `n` として返す値は、同じ基準の絶対値ではありません。Rの `BIC` は `-2 log L + k n_par`（通常 `k = log(n)`）で定義されるため、総度数を標本サイズとする固定多項表では、`N`とセル行数の違いを監査列に残して区別します。[R `AIC/BIC`公式](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/AIC.html)、[Schwarz (1978)](https://doi.org/10.1214/aos/1176344136)

入れ子モデルM0からM1への局所または全体の改善量は

\[
  \Delta G^2 = 2\{\ell_{M1}-\ell_{M0}\}
\]

で、通常は自由度差とともに扱います。これは尤度比統計量であり、ベイズ因子そのものではありません。正則性と大標本近似が確認できる場合にだけカイ二乗近似のP値を補助表示します。Rの `pchisq(..., lower.tail = FALSE, log.p = TRUE)` を使い、極端なP値の下では対数P値を保持します。

## 4. セル診断は4つの問いに分ける

一つのScoreにすべてを押し込めず、同じ基準モデルに対して次を別々に示します。

### 効果の大きさ

基準モデルの期待度数を `E_i`、観測度数を `O_i` とすると、次を保存します。

\[
  \log(O_i/E_i),\qquad d_i/\sqrt N,\qquad \Delta G_i^2/N
\]

`log(O/E)`は乗法的なずれ、`d_i/√N`はdeviance残差の総度数正規化、`ΔG²/N`は局所モデル改善の総度数正規化です。これらに普遍的な「実務上重要」の閾値は置きません。業務上の許容差、分母、費用やリスクと一緒に決めます。

### 証拠量

セルダミーを1列追加して再適合したときの局所改善量 `ΔG²` を、基準モデルから見た局所尤度比として保存します。ダミー追加が正則で、期待度数などの近似条件を満たすときだけ、局所BIC差

\[
  \Delta G^2 - \Delta r\log N
\]

の半分を近似 `log BF` と表示します。これは明示した近似であり、厳密なセルBFではありません。

Null fitだけから計算するscore型の近似は

\[
  T_i = r_{P,i}^2/(1-h_{ii})
\]

です。`r_P`はPearson残差、`h_ii`は最終適合の重み付き設計行列のleverageです。`T_i`は局所再適合の `ΔG²` と近いことがありますが、同じ量とは扱いません。

### モデル診断

`h_ii` はモデル行列上のleverageで、セルを削除した影響度や再標本化による安定性そのものではありません。非収束、境界、階数不足、leverageが1に近い場合は局所推論を保留します。安定性を主張するには、別途bootstrapや感度分析を設計します。

### 多重性

複数セル、複数の基準モデル、複数の軸を探索するため、上位セルの表示は探索的です。初期版はFDR、FWER、選択後推論を保証しません。確証的なセル選択が必要な場合は、候補選択と検証用データまたは再標本化計画を分けます。

## 5. 度数の100倍実験

同じ表の全度数を100倍すると、固定モデルの `log(O/E)`、`d/√N`、`ΔG²/N` は概ね不変ですが、`ΔG²`、P値、BIC近似、BF、信用区間は変化します。これは標本サイズ感度の教材であり、元データを100回複製して独立情報を増やしたことを意味しません。独立な追加観測なのか、コピーによる感度実験なのかを、結果ごとに明記します。

## 6. 参照文献

- Agresti, A. (2013). *Categorical Data Analysis*, 3rd ed., Wiley. [出版社情報](https://www.wiley.com/en-us/General+%26+Introductory+Statistics/Categorical+Data+Analysis-c-ST53)
- McCullagh, P., & Nelder, J. A. (1989). *Generalized Linear Models*, 2nd ed., Chapman & Hall/CRC. R `glm`公式の参考文献にも掲載されています。
- Schwarz, G. (1978). “Estimating the Dimension of a Model.” *The Annals of Statistics*, 6(2), 461–464. [DOI](https://doi.org/10.1214/aos/1176344136)
- R Core Team. `glm`, `loglin`, `residuals.glm`, `AIC/BIC`, `pchisq`の公式マニュアル。[R statsマニュアル](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/00Index.html)
