# SAS PROC FREQ / PROC MEANS 対象限定互換スキル開発計画書

created: 2026-09-13 20:05 (JST)
update: 2026-09-14 01:15 (JST)
author: Codex (GPT-6) / Antigravity
status: FREQ Stage 1 OpenSpec計画確定／実装承認直前
target_spec: FREQ、MEANS、パイプライン統合の各変更へ段階的に展開予定

## 1. 目的・今回の承認範囲

本計画は、SAS PROC FREQ / PROC MEANS のうち明示した機能・入力領域について、統計的定義、欠損処理、集計結果、数値出力を再現する独立スキルを開発するための設計・検証計画である。[リポジトリ概要](../../README.md)および[数理リファレンス](../reference/README.md)を正本の入口とする。

> [!IMPORTANT]
> **本Changeにおける承認対象のスコープ境界**:
> 現在進行中のChange `add-sas-proc-freq-skill`（[Change定義](../../openspec/changes/add-sas-proc-freq-skill/proposal.md) / [設計](../../openspec/changes/add-sas-proc-freq-skill/design.md) / [仕様](../../openspec/changes/add-sas-proc-freq-skill/specs/sas-proc-freq/spec.md)）において先行して承認・実装対象とするのは、**PROC FREQ の Stage 1 基礎受入（数式定義・手計算参照値・境界値テスト）のみ**である。
> PROC MEANS（別Change `add-sas-proc-means-skill` で実施予定）、多変量パイプライン統合、および Stage 2（SAS実機fixture提供時のParity受入）は本Changeの承認範囲外（将来の段階的ゲート）として厳格に分離する。

2026-09-13のユーザー指示により、Webでの再調査、本計画の訂正、追加考察の記載が承認された。本改訂はその範囲を実行したものである。OpenSpec作成、コード・依存関係・データ変更、統計解析の実行、commit、pushは今回の作業に含めない。後続の実装は確定した対象範囲に対する段階的承認に従う。

原著者はAntigravity（旧記載: Advanced Agentic Coding）。本改訂の著者・モデルは上記メタデータに記載する。旧版の「Option A」は具体的な選択内容が本文で定義されていなかったため、承認済み実装の根拠として使用しない。

### 1.1 互換性の定義

目標は「対象限定・参照環境明示・許容誤差付き数値互換」である。異なるSAS/R環境間のビット単位一致や、全SAS構文・全ODS出力の互換を保証しない。数値互換の成立から、規制上の適格性や提出資料としての受入を推論しない。

互換性を次の項目に分けて判定する。

| 区分 | 契約 |
| --- | --- |
| 意味・構造 | 対象集団、変数、水準順、除外規則、分母、統計量、区間方式が一致 |
| 離散結果 | 度数、群、欠損理由、対象水準は完全一致 |
| 決定論的数値 | 丸め前の参照値に対する絶対・相対誤差の併用 |
| 表示 | 明示した桁数・丸め・欠損表記で照合。SAS画面全体の再現は対象外 |
| 確率的結果 | 同じ推定対象・標本化分布を確認し、Monte Carlo誤差を評価。SAS/Rの同一Seedによる同一値は要求しない |
| 証拠状態 | 公式仕様確認、独立式検証、SAS実機照合を別々に記録 |

SAS互換は、固定するSAS製品・リリース・保守レベル・OS・オプション・入力の範囲に限る。SAS実機の利用可能性、バージョン、参照出力は現時点で未確認である。文献から再現した値をSAS実測値と呼ばない。

## 2. 設計境界と対象機能

### 2.1 独立スキルと共通契約

- 正本は `.agents/skills/sas-proc-freq` と `.agents/skills/sas-proc-means`。統計エンジンは本リポジトリに置く。
- PROC FREQは度数・割合・分割表解析、PROC MEANSは数値変数の要約を担当する。MEANSを「重み付き分散分析」のプロシジャとは定義しない。
- Pass 0で入力構造、除外、集計単位、反復観測の有無、手法、許容する近似を確認し、`analysis_config.json` を単一の設定正本とする。個別の設定ファイルを二重管理しない。
- 共通設定に `schema_version`、`analysis_kind`、入力SHA-256、変数型・欠損表現、水準順、分析オプション、実行資源上限を持たせる。スキル別スキーマがその構造を検証する。
- 出力はJSON、CSV、日本語Markdown/HTMLとし、ODSはSAS参照出力の取得元・対応表名として扱う。RからSASのODS機構そのものを生成する意味ではない。
- run単位の予約・分離、設定の写し、入力・結果ハッシュ、manifest、handoverは既存共有実装を調査して再利用する。設定不適合・失敗したrunを正常な完了として公開しない。

既存Pass 0はカテゴリカル分析を中心としているため、連続変数の診断、MEANSの変数別欠損、重み除外まで既に対応済みとは扱わない。統合は単体仕様の後に別Changeで設計する。既存のM1〜M9、BIC、セル診断、CRRをこの計画で改変しない。

### 2.2 段階別の機能集合

| 段階 | FREQ | MEANS |
| --- | --- | --- |
| 基礎 | 1元表、2元表、層ごとの2元表、欠損3モード、度数・割合・累積値 | N、NMISS、SUM、SUMWGT、MEAN、MIN、MAX、RANGE、CSS、USS、VAR、STD、CV、CLASS群 |
| 推測・分位数 | Pearson、尤度比、2×2連続性補正、Fisher、2×2 OR/RR、二項CI | STDERR、LCLM/UCLM、QNTLDEF 1〜5、FREQ、WEIGHT、両者同時指定、非重み付き歪度・尖度 |
| 拡張 | 順序スコアMH、層別2×2 CMH、一般R×CのCMH各統計量 | 必要なCLASS部分集計、SAS出力データセットとの対応拡張 |
| 別途検討 | MEASURES全一式、exact OR/RR区間、mid-p、複雑標本設計 | QMETHOD=P2、任意FORMAT、特殊欠損全種類、BYの全構文、IDGROUP、重み付きMODE |

既存案の `measures: true` は多数の未定義統計量を要求するため廃止し、実装済み統計量IDの配列にする。未対応オプションは黙って無視せず、計算前に明示エラーとする。将来対象と初回受入対象を混同しない。

## 3. PROC FREQの入力・集計契約

### 3.1 入力の限定とSASへの対応

正規入力はカテゴリ列と非負整数の `count_variable` を持つ集計表とする。SAS側では `WEIGHT count;` に対応させる。PROC MEANSのFREQ文とは名称・意味を区別する。

SAS PROC FREQのWEIGHTは非整数も受け付け、ゼロは既定で無視、`ZEROS` 指定で保持、負値があれば割合・統計量を計算しない。本スキルの初回領域は整数度数に限定し、負値・小数・欠損度数・非有限値を拒否する。この限定を「SAS全入力互換」と称さない。[S1]

個票入力は承認された前処理でカテゴリ組合せごとに合算する。count列の存在だけでは個票・重複の検出にならないため、入力粒度と集約キーを検査する。度数の暗黙丸めは禁止する。数値型の整数精度上限とR内部検定の整数上限を別々に確認する。

### 3.2 欠損・水準・分母

| モード | 表示 | 分母・検定 |
| --- | --- | --- |
| `exclude`（SAS既定） | 欠損を表から除外し、欠損度数を別記 | 欠損を除外 |
| `missprint` | 欠損水準を表に表示 | 欠損を除外 |
| `include`（MISSING） | 欠損を有効水準として表示 | 欠損を算入 |

既定の表示表とOUT=データセットの欠損行は同一とは限らない。JSONの集計事実と表示方針を分ける。除外はtable requestの変数集合ごとに適用し、全要求を一括complete-case化しない。[S1]

各表に元の総度数、有効度数、除外欠損度数、行・列分母を保存する。層別表の全体割合は当該層の有効総度数を分母とし、全層合計を使う割合は別名にする。

水準順と型を設定に固定する。SASのORDER、FORMATによる群化、ロケールをRの文字列既定順へ暗黙置換しない。初回はFORMATなし・明示水準順とし、イベント水準、OR/RRの比較方向、二項割合の対象水準を必須とする。SASの二項割合は未指定時に表の先頭水準を対象とするため、照合SASプログラムでもLEVELを明示する。[S2]

観測ゼロ、未観測の水準組合せ、欠損、構造的ゼロを区別する。既知の構造的ゼロを通常の独立性検定へ投入しない。ゼロ周辺の行・列は表示用に保存し、推測用に除去した場合は対応関係を記録する。推測表が2行・2列未満、総度数0、期待度数0等なら未計算理由を返す。割合の0/0を0に置換しない。

## 4. PROC FREQの統計仕様

### 4.1 基本検定と効果量

独立性検定では E_ij = n_i+ n_+j / N とし、自由度は有効な推測表の (r−1)(c−1) とする。

- Pearson: Q_P = Σ(O−E)²/E。Rでは連続性補正を明示的に無効化する。
- 尤度比: G² = 2Σ O log(O/E)。O=0の寄与は0。これはポアソンモデルの適切なdevianceに対応し、「残差平方和」とは呼ばない。
- 2×2の連続性補正: Q_C = Σ[max(0, |O−E|−0.5)]²/E。SASのCHISQ要求で提供する統計量として定義し、N≤20やE<5を出力切替条件にしない。[S3]
- 順序スコアMH: (N−1)r²。rは度数重み付きの行列スコア相関。SCORESの各方式、水準順、同順位規則は拡張段階で公式式とfixtureを固定する。
- CMH: 相関、行平均スコア、一般関連、共通ORを個別IDにする。`mantelhaen.test()` だけでSASのCMH全出力を実現できるとはしない。補正・層除外・分散・自由度を個別照合する。

2×2表を [[a,b],[c,d]]、列1をイベント、行1対行2を比較とすると、

- OR = ad/(bc)、SE(log OR) = sqrt(1/a+1/b+1/c+1/d)。
- RR列1 = {a/(a+b)}/{c/(c+d)}、SE(log RR列1) = sqrt(1/a−1/(a+b)+1/c−1/(c+d))。
- RR列2も別のイベント定義で計算する。ORの標準誤差式をRRへ流用しない。
- 正のセルでのWald区間は exp(log推定値 ± z_(1−α/2) SE)。ゼロセル、0・無限大、区間未定義は理由付きで保存し、無断の0.5加算はしない。
- RのFisher関数が返す条件付き最尤ORと、標本OR=ad/bcを混同しない。[R1]

二項CIはWald、Clopper–Pearson、Wilsonを初回対象、Agresti–Coull・Jeffreysを追加対象とする。区間端点、0成功・全成功、片側・両側、αをfixture化する。SASの既定Wald/Clopper–Pearsonと追加指定を区別する。[S2]

### 4.2 Fisherと実行資源

周辺度数を固定した帰無分布と、観測表以下の確率を合計する両側定義を明示する。片側、mid-p、両側2倍方式は同一ではない。

Rの2×2は超幾何分布による計算、一般R×Cはネットワーク法、シミュレーションはPatefield法を使用する。2×2を「FEXACTで瞬時完了」とは記載しない。大表・大Nでも常に破綻するわけではなく、周辺度数と実装資源に依存する。[R1][R2]

計算方法は `exact` または `monte_carlo` をPass 0で明示する。exact時のfallback既定は `stop` とし、事前設定 `allow_mc` がある場合に限り資源制約時にMCへ切り替える。実行ごとの追加確認は不要とする。漸近検定への自動置換は初回実装に含めない。

旧版の表サイズ・N閾値は図と本文で一致せず、安全性の実測根拠もないため撤回する。次を実装する。

1. 非負整数、正の有効周辺、整数上限、2×2の支持集合幅、一般表の次元・周辺を検査する。
2. 設定した時間・メモリ・workspace上限で子プロセスを監視する。300秒等はSAS仕様ではなく設定可能な運用上限とする。
3. タイムアウト、メモリ不足、数値失敗を区別する。失敗したP値を0としない。
4. 経験的な事前バイパス規則を追加する場合は、検証データ、環境、ルール版、根拠を保存し、計画に追記する。

### 4.3 Monte Carloの数値契約とSAS/R差異

同じ周辺固定分布と裾の定義なら、MCは同じ正確P値の近似である。前回レビューの「MCへの変更だけで推定対象が変わる」という表現を訂正する。Pearson等への変更は別統計量の検定であり、区別が必要である。

参照したSAS 9.4資料のMC仕様は、反復B、極端表の数Mに対して次である。[S4]

- 点推定: p_hat = M/B。
- 標準誤差: sqrt(p_hat(1−p_hat)/(B−1))。
- 0<M<Bの区間: 正規近似 p_hat ± z_(1−α_MC/2) SE。
- M=0: (0, 1−α_MC^(1/B))、M=B: (α_MC^(1/B), 1)。
- 資料の既定B=10,000、区間99%。計画のB=100,000は本スキルの明示的選択でありSAS既定ではない。
- SAS資料の標本化法はAgresti–Wackerly–Boyett。Mehta–PatelをMC標本化法として記載しない。

Rの `fisher.test()` は補正付き (M+1)/(B+1) を返す。[R2] 初回の `sas_mc_summary` は固定周辺標本からMを保持して上記SAS方式の要約を計算する。必要ならR方式の補正値も別列 `p_mc_plus_one` に保存し、主値と混ぜない。SASの乱数列再現は対象外。MCをMCMCと呼ばない。

結果には要求方法、実行方法、fallback許可、理由、M、B、点推定式、区間方式・水準、RNG種別、Seed、R・依存版、標本化法を保存する。Bは2以上の整数、Seedは必須、α_MCは(0,1)。境界計算には数値安定な式を用いる。0<M<Bでの区間の[0,1]への制限・表示規則は対象SAS実機fixtureで確定する。

MC区間は計算誤差を表し、効果量の信頼区間ではない。M=0も真のP値0の証拠ではない。レポートには実際の方法・B・Seed・区間を記載し、特定当局の照会を必然視する警告文は削除する。

## 5. PROC MEANSの数理・入力契約

### 5.1 対象データと除外

個々の数値、または同じ数値・CLASS・重みの組合せをFREQで圧縮した表を入力とする。階級化データや平均・SDだけの集約から、厳密な分位数・歪度・尖度を復元しない。

FREQは小数部分を切り捨て、1未満・欠損を除外する。FREQ未指定は各行1とする。[S5] 前回レビューにあった `FREQ / NOTRUNCATE` は別プロシジャの仕様の混入であり、本MEANS契約へ移植しない。

WEIGHTは小数を許容する。既定では負値を0として扱い、0重みの行を観測数に含め、欠損重みを除外する。`EXCLNPWGT` 指定時は非正重みを除外する。[S6] 正重み行数を常にNとする旧記述を訂正する。

CLASS欠損は既定で除外、MISSING指定で群として保持する。分析変数の欠損は変数別にN/NMISSへ反映する。入力行数、FREQ換算数、除外理由、群の度数、各変数N/NMISSを別々に保存する。InfやNaNの曖昧な文字列表現、特殊欠損 `.A` 等は初回対応表にない場合に拒否する。

### 5.2 重み・分散・平均の区間

各群・各分析変数について採用対象集合Iを上記規則で定め、f_iを有効頻度、w_iを処理後重み（未指定時1）とする。

n = Σ_I f_i、W = Σ_I f_i w_i、
x_bar = Σ_I f_i w_i x_i / W、
CSS = Σ_I f_i w_i (x_i−x_bar)²。

| VARDEF | 分散の分母d |
| --- | --- |
| DF（既定） | n−1 |
| N | n |
| WDF | W−1 |
| WEIGHT（WGT） | W |

VAR=CSS/d、STD=sqrt(VAR)。旧版の W−Σw²/W はSAS MEANSのWDFではない。[S7] すべてのVARDEFを一括して「不偏分散」と呼ばない。W≤0、d≤0、空群等は適用条件に応じて未定義理由を保存する。

VARDEF=DFの平均標準誤差は STD/sqrt(W)、t区間は x_bar ± t_(1−α/2,n−1) STDERR とする。重み未指定ではW=n。DF以外のSTDERR・平均区間はSAS仕様に従い未定義とする。[S7][S8] 精度重みモデルの推論を、IPW・複雑標本・施設クラスタに対する頑健推論として使用しない。

SUM=Σf_iw_ix_i、SUMWGT=W、USS=Σf_iw_ix_i²、CV=100 STD/x_barとする。MIN/MAXや分位数へのゼロ重み行の扱いは個別fixtureで確認し、全統計量を同じ「正重みのみ」のフィルタで実装しない。

### 5.3 歪度・尖度の適用制約

WEIGHT文があるとPROC MEANSは歪度・尖度を提供しない。重みが全て1でも文の指定有無を保持する。[S6] 重み付き式を独自に出してSAS互換値としない。

WEIGHTなし、VARDEF=DFでは、s²=CSS/(n−1) として、

- 歪度: n/((n−1)(n−2)) Σ f_i ((x_i−x_bar)/s)³。
- 超過尖度: n(n+1)/((n−1)(n−2)(n−3)) Σ f_i ((x_i−x_bar)/s)⁴ − 3(n−1)²/((n−2)(n−3))。

VARDEF=Nは中心モーメントm_k=Σf_i(x_i−x_bar)^k/nから、歪度=m_3/m_2^(3/2)、超過尖度=m_4/m_2²−3とする。WDF/WEIGHTでは未定義とする。[S9] 歪度を任意分布に対して一般的に不偏とは呼ばない。n不足、定数列、ゼロ分散、オーバーフローをテストする。DF用の最小n条件をN方式へ無条件に流用しない。

### 5.4 分位数

MEANSの正規名はQNTLDEF、PCTLDEFは別名として扱い、内部キーは `qntldef` に統一する。QMETHOD=OSを対象とし、P2近似は対象外とする。

| QNTLDEF / PCTLDEF | R type相当（重みなし） | 定義 |
| --- | --- | --- |
| 1 | 4 | npに基づく線形補間 |
| 2 | 3 | 最近傍順位、ちょうど中間は偶数順位 |
| 3 | 1 | 逆経験分布 |
| 4 | 6 | (n+1)pに基づく線形補間 |
| 5（SAS既定） | 2 | npが整数なら隣接順位の平均、それ以外は次の順位 |

SAS定義とR定義の照合による対応である。[S9][R3] 旧版の5→5、1→1または2を訂正する。R既定type=7とは「異なる場合がある」が正しく、中央値や定数列等では一致し得る。

FREQのみでは概念上の頻度展開と同値に計算するが、実装では巨大な展開配列を作らず累積頻度を利用する。WEIGHT指定の分位数は累積重みに基づく別経路とし、QNTLDEF 1〜5の補間を適用しない。[S9] 正の累積重みがpWに一致する場合の隣接値平均、同値値、ゼロ重み、p=0/1を独立テストする。境界の浮動小数点処理はR版・fuzz設定とともに固定し、タイプ番号の一致だけで完全一致としない。

## 6. 設定と結果の具体化

`analysis_config.json` のFREQ部分例は次とする。パス・変数名は説明用であり、Pass 0で実データを確認して置き換える。

~~~json
{
  "schema_version": "sas-summary-config-v1",
  "analysis_kind": "sas_proc_freq",
  "dataset_path": "input/aggregated_counts.csv",
  "count_variable": "count",
  "table_requests": [{
    "request_id": "response_by_group",
    "row_variable": "group",
    "col_variable": "response",
    "stratify_by": [],
    "levels": {"group": ["A", "B"], "response": ["yes", "no"]},
    "missing_mode": "exclude",
    "statistics": ["pearson", "likelihood_ratio", "fisher"],
    "fisher": {
      "method": "exact",
      "fallback": "stop",
      "mc_summary": "sas_mc_summary",
      "replications": 100000,
      "seed": 12345,
      "confidence_level": 0.99
    }
  }],
  "resource_policy": {"timeout_seconds": 300}
}
~~~

MEANSは `analysis_kind=sas_proc_means`、`analysis_variables`、`class_variables`、`freq_variable`、`weight_variable`、`vardef`、`qmethod=OS`、`qntldef`、`class_missing`、`exclnpwgt`、`alpha`、`statistics`、明示した `class_subsets` を持たせる。省略既定はSASの既定と本スキル独自既定を対応表で区別する。両方の分位数キーを受理する場合は、値が不一致ならエラーとする。

各結果は `request_id`、統計量ID、群・層・水準ID、推定対象、分母、方法、値、区間、計算状態、理由を持つ。JSONにNaN/Infinityを出さず、nullと `undefined` / `positive_infinity` / `not_supported` / `resource_limit` 等で区別する。表の方向や区間名を表示層だけで付け替えない。

統計的解釈は日本語とし、P値単独の重要性判定をしない。既存Dual-Filter、QUARANTINED、BIC等をSAS出力に自動転用しない。SASの注意表示と本スキルの品質注意を別属性にする。

## 7. ベンチマークと受入条件

### 7.1 SAS参照証拠

`tests/benchmarks/sas_fixtures/` に将来保存する各fixtureは、入力CSVとSHA-256、SASソース、実行ログ、SASバージョン・保守レベル・OS・ロケール・FORMAT・オプション、丸め前出力、取得日時、結果ハッシュを一式にする。公開教材は出典・利用条件を確認して採用し、名称だけでSAS標準データと認定しない。CDISC公開データは必須依存にせず、まず小さな合成データで境界を網羅する。

SAS参照がない項目は `sas_parity=unverified` とする。公式ドキュメント値、手計算、独立実装の検証は継続できるが、実機互換合格の代用にしない。fixtures未提供は証拠不足として一覧化する。

### 7.2 数値・構造の合格基準

- 度数・キー・除外数・NA理由・区間方式は完全一致。行位置ではなく安定キーで照合する。
- 通常の決定論的値は |R−SAS| ≤ atol + rtol|SAS|。初期候補は atol=10^-12、rtol=10^-10とし、統計量・尺度別に参照値取得前に確定する。
- 極小P値はlog Pまたは別の絶対誤差・アンダーフロー状態で評価する。通常のatolで小さいP値を全て同じと認定しない。
- 表示の丸め後一致と丸め前一致を別試験にする。百分率を強制調整して合計100にするとSAS表示と異なる場合があるため実施しない。
- MCは既知exact Pに対する推定誤差と区間被覆を、事前固定したSeed群・B・判定規則で評価する。一回の99%区間包含だけを必須試験にしない。
- M=0、M=B、内部値ではMとBを直接与える要約関数試験を別途用意する。SAS/Rが違う乱数標本を引いた結果に10^-10の一致を要求しない。

### 7.3 必須ケース

| 領域 | 必須ケース |
| --- | --- |
| FREQ集計 | 欠損3モード、要求ごとの分母、層別、順序、重複キー、全欠損、ゼロ度数、水準欠落、構造的ゼロ拒否 |
| FREQ推測 | 独立表、疎な2×2、補正差が0.5未満、左右反転、OR/RRゼロセル、Fisherの確率同値、一般表の資源停止 |
| MEANS | fのみ、wのみ、fとw、非整数f、ゼロ・負・欠損w、EXCLNPWGT、変数別欠損、CLASS欠損 |
| 分散・形状 | VARDEF4分岐、DF以外の区間未定義、重み指定時の形状未定義、n=0/1/2/3、定数列、極端重み |
| 分位数 | 1〜5、p=0/1、np整数・半整数の偶奇、同値値、頻度圧縮、重み付き境界、全等重み |
| 再現性 | 固定R環境・Seed、入力順変更の影響、設定不一致、結果ハッシュ、失敗run、既存テスト非回帰 |

独立検証者がSASソースとR設定の対象集団・向き・既定値を照合する。R関数を呼ぶだけのテストで、その同じ関数を期待値生成にも使用しない。

## 8. 開発段階と変更対象

1. 仕様段階: `add-sas-proc-freq-skill` と `add-sas-proc-means-skill` を独立起案し、対応機能、非対応機能、既定値、fixture一覧、未確認点を仕様化する。
2. 基礎段階: 第2.2節の基礎機能を先行し、schema、R計算、JSON/CSV、境界試験を構築する。
3. 推測段階: 第2.2節の推測・分位数を追加し、SAS照合と独立検証を完了する。MCは別受入項目とする。
4. 拡張段階: MH/CMH等を個別仕様・fixture付きで追加する。未定義の一般CMHを初回完了条件に紛れ込ませない。
5. 統合段階: 別ChangeでPass 0、4-Pass、run管理、レポート導線を変更し、既存分析の非回帰を確認する。

予定対象は各新スキルの `SKILL.md`、`schemas/analysis_config.schema.json`、`templates/run_freq.R` / `run_means.R`、検証コード、`tests/test_sas_proc_freq_numerical_parity.R`、`tests/test_sas_proc_means_numerical_parity.R`、SAS fixtures、数理リファレンスである。統合対象の共有ファイルは調査後に実パスを計画へ追記する。

依存パッケージ追加は必要性・代替・版・利用条件を実装前に記載する。数理核は可能な範囲でbase R / statsを利用するが、採用自体をこの改訂で確定しない。

完了条件は、対象機能の契約確定、SAS参照証拠、数値・境界・既存回帰合格、日本語レポート、独立検証が揃うことである。OpenSpecの構文検証合格だけでは実装完了としない。

## 9. 再考察による訂正と残る確認事項

| 旧版・前回レビュー | 本改訂 |
| --- | --- |
| ビット単位完全一致・規制受入を目的化 | 対象環境と誤差を明示した数値互換へ変更 |
| QNTLDEF=5をR type=5と対応 | type=2へ訂正、1はtype=4、2の偶奇処理も追加 |
| VARDEFのDF/N/WDFが誤り | n−1、n、W−1へ訂正 |
| 非正重みを一律除外 | SAS既定とEXCLNPWGTを分離 |
| 重み付き歪度・尖度、全VARDEFの平均区間 | SASが提供しない組合せを未定義化 |
| MEANSへNOTRUNCATEを類推 | 前回レビューの他プロシジャ混入を撤回 |
| Fisherの大表は必ず破綻、2×2は瞬時 | 実装・周辺・資源依存へ変更 |
| MCMC、Mehta–PatelによるMC | Monte Carlo、SAS/Rの標本化法を訂正 |
| SASのMC値も(M+1)/(B+1) | SASのM/B・区間式とR補正値を分離 |
| MCへの変更で推定対象が変わる | 同一exact Pの近似と別検定への変更を区別 |
| Yatesの切り詰めなし、標本数で切替 | max(0,…)と出力要求で定義 |
| OR/RRのSEを共通化 | 個別式とイベント方向を明記 |
| separate configと一括4-Pass統合 | analysis_config.jsonへ統一、統合Changeを後段化 |
| 計画のConfirmedを実装承認と推定 | 今回は計画改訂の承認として記録 |

残る確認事項は、対象SASリリース、参照fixture取得方法、ゼロ周辺・非正重みと統計量別の詳細動作、MC区間の表示境界、CLASS部分集計・FORMAT範囲、MH/CMHの各式と自由度、実行上限の実測である。これらは実装前の仕様・証拠ゲートとして扱う。取得できない証拠は未確認のまま明記し、推測で「完全互換」にしない。

今回の変更は本計画書のみ。開始時に存在したTODO変更、旧計画削除、アーカイブ追加、output.zipは本改訂の差分に含めない。

## 10. Web一次資料と確認範囲

確認日: 2026-09-13（JST）。SASの資料版は混在しているため、以下は定義を確認した根拠であり、全リリース共通性の証明ではない。正式fixtureでは対象製品版を固定する。SAS公式MEANSの一部HTMLは全文取得がタイムアウトしたため、検索で取得できた該当仕様と専用ページを照合した。画像数式など実機照合が必要な細部は第9節に保留を残す。

- [S1: SAS PROC FREQ公式資料（欠損・WEIGHT・出力）](https://documentation.sas.com/api/docsets/statug/v_039/content/freq.pdf?locale=en)
- [S2: SAS 9.4 TABLES文（二項割合、対象水準、区間）](https://support.sas.com/documentation/cdl/en/procstat/67528/HTML/default/procstat_freq_syntax08.htm)
- [S3: SAS 9.4 カイ二乗統計量（連続性補正を含む）](https://support.sas.com/documentation/cdl/en/procstat/65544/HTML/default/procstat_freq_details08.htm)
- [S4: SAS 9.4 正確検定とMonte Carlo推定式](https://support.sas.com/documentation/cdl/en/procstat/67528/HTML/default/procstat_freq_details98.htm)
- [S5: SAS PROC MEANS FREQ文](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a000146732.htm)
- [S6: SAS PROC MEANS WEIGHT文](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a000146736.htm)
- [S7: SAS PROC MEANS文（VARDEF、QNTLDEF、適用制約）](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a000146729.htm)
- [S8: SAS PROC MEANS統計計算](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a000608466.htm)
- [S9: SAS基礎統計のキーワード・数式・分位数](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a002473330.htm)
- [R1: R公式Fisher検定資料](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/fisher.test.html)
- [R2: R Core Fisher実装（開発版ミラー、確認時点）](https://raw.githubusercontent.com/wch/r-source/trunk/src/library/stats/R/fisher.test.R)
- [R3: R公式分位数資料](https://search.r-project.org/R/refmans/stats/html/quantile.html)

R開発版資料・ソースは実装候補の確認に使用した。実装時には採用する安定版Rとそのソース・依存版を固定し、開発版にだけ存在するオプションを前提にしない。
