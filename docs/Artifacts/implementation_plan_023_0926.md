# 実装計画書 023: エビデンス・シグネチャ・マップ（Gower距離 / PCoA / クラスタリング探索）

- **作成日時**: 2026-09-26 23:58 (JST)
- **ステータス**: DRAFT（仕様策定および独立レビュー用提案）
- **対象新規 Change**: `comparative-evidence-exploration-v1`
- **上位目的**: 多数の比較エビデンス（安全性 PT、処方、RWD テーマ）において、完全一致する重複度数パターンを「エビデンス・シグネチャ」へ縮約し、Gower 距離および主座標分析（PCoA）、階層的クラスタリング（HAC）を用いてエビデンス空間の類似構造を直感的に俯瞰・探索できる完全自己完結型ダッシュボードおよびデータ基盤を提供する。

---

## 1. 背景と課題意識（事実と動機）

### 1.1 `examples/Drug-Safty-example.csv` の実測データ分析

リポジトリ内の実例データ `examples/Drug-Safty-example.csv` を精査した結果、以下の事実が判明した：

- **総行数（PT 数）**: 250 行
- **一意な度数パターン `(Drug, Dsize, Placebo, Psize)`**: わずか **67 種類**
- **重複パターン群の数**: 20 群
- **重複パターンに属する行数**: 203 行 / 250 行（**全体の 81.2%**）

主要な頻出重複パターンの実測値：
1. `(1, 219, 0, 219)`: **77 件** の PT（例: 軽微な有害事象群）
2. `(0, 219, 1, 219)`: **50 件** の PT
3. `(2, 219, 0, 219)`: **14 件** の PT
4. `(3, 219, 0, 219)`: **8 件** の PT
5. `(1, 219, 1, 219)`: **8 件** の PT

### 1.2 なぜ独立した新 Change とすべきか（アーキテクチャ境界）

1. **頻出パターンの幾何支配問題**:
   250 行をそのまま通常の距離空間（ユークリッド距離や K-means）へ投入すると、`77件` や `50件` の同一度数パターンが空間の重心やクラスタ中心を過度に歪めてしまう。
2. **分析単位の拡張**:
   報告層（Section 14）は「1行 = 1有害事象（PT）」を表示するレポートであるのに対し、探索層は「1点 = 1統計的同値クラス（Evidence Signature）」という新たな分析単位と、距離空間から 2 次元直交座標への変換（PCoA）、およびクラスタリング幾何学を導入する。
3. **責務の分離**:
   集計・レポーティングを担う `comparative-evidence-reporting-v3`（アーカイブ済み）と、多変量探索・幾何学的俯瞰を担う本 Change を明確に分離する。

---

## 2. コア設計と概念分離（Statistical Architecture）

### 2.1 エビデンス・シグネチャ（Evidence Signature）の定義

エビデンス・シグネチャとは、**「統計モデルに入力した際に、数学的に完全に同一の推論結果（事後分布／推定値／区間）を生成する統計的同値クラス」** である。

- **シグネチャ決定キー（Exact Key）**:
  - `inferential_semantics`（`"posterior"` / `"bootstrap"`）
  - `target_events` ($x_T$)
  - `target_total` ($n_T$)
  - `reference_events` ($x_R$)
  - `reference_total` ($n_R$)
  - `primary_delta`（$\delta$ 設定値または null）
  - `interval_level`（0.95）
  - `model_version` / `prior_type`（Jeffreys 等）
- **シグネチャから厳格に除外される情報（メタデータ・メンバーシップ）**:
  - PT 名、SOC 名、テーマ名、薬品名
  - ※これらは医学・薬学的な分類ラベルであり、統計モデルの数学的出力には一切影響しないため、シグネチャの同一性判定には含めず、所属メンバー（Membership）として搬送する。
- **デザイン考慮型推論（IPTW, Matched Sets）のスコープ境界**:
  - v1 では独立 2 群二値データ（`independent_count`）を完全縮約の対象とする。
  - IPTW やマッチドペア等の非独立観測は、raw counts が同一でも共変量分布やマッチング構造により推論値が異なるため、v1 では「1行 = 1シグネチャ（縮約なし）」として扱う（Option A）。

### 2.2 重み付け契約（Unweighted Geometry Contract）

- **PCoA 幾何座標およびクラスタリング距離の計算**:
  - **1 Signature = 1 観測点（Weight = 1.0）** を基本鉄則とする。
  - 重複数（`multiplicity`）を距離や重心の計算重みに使用してはならない（`77件` の重複が PCoA 空間の第 1 軸を歪めることを防ぐため）。
- **重複数（`multiplicity`）の視覚表現**:
  - 重複件数は、マップ上の **「プロット点の大きさ（Point Radius / Size）」** および **「ツールチップ / 詳細リスト」** の表示にのみ使用する。

### 2.3 2系統マップ・モデル（Two-Map Model）

実務領域閾値 $\delta$ の感度を分離して評価できるよう、2 種類の座標マップを提供する：

1. **Core Evidence Map（標準ビュー）**:
   - 閾値 $\delta$ に依存しないコア指標のみで Gower 距離および PCoA 座標を構築。
   - 目的: 実務閾値 $\delta$ をどのような値に変更しても不変な、データ自体の普遍的証拠幾何構造を俯瞰する。
2. **Practical Evidence Map（実務領域適応ビュー）**:
   - コア指標に加え、実務領域確率（`target_excess`, `practical_neutral`, `reference_excess`）および U-Grade を Gower 特徴量に含めて PCoA 座標を構築。
   - 目的: 特定の規制・臨床方針（$\delta$）の下での実務的解決度（U0〜U3）による群集構造を俯瞰する。

### 2.4 Gower 距離と凍結参照範囲（Frozen Reference Ranges）の再利用

- 既存の検証済み共通モジュール [`.agents/shared/evidence_gower.R`](file:///.agents/shared/evidence_gower.R) および [`.agents/shared/evidence_feature_extract.R`](file:///.agents/shared/evidence_feature_extract.R) を 100% 再利用する。
- **特徴量キー（一次情報完全一致）**:
  - `CORE_CLUSTERING_KEYS`:
    `rd_estimate`, `rd_interval_width`, `direction_support`, `resolution_grade`, `rr_mean_is_finite`, `has_zero_reference`, `target_n`, `reference_n`, `quarantine_flag_count`
  - `DELTA_CLUSTERING_KEYS`:
    `primary_delta`, `target_excess`, `practical_neutral`, `reference_excess`
- **決定ラベル排除の原則**:
  - `FORBIDDEN_DECISION_LABEL_KEYS`（`decision`, `regulatory_outcome`, `approval_status` 等）は距離特徴量から物理的に排除する（`assert_no_forbidden_decision_labels`）。

### 2.5 主座標分析（PCoA）と非ユークリッド加法補正（Additive Constant Correction）

Gower 非類似度行列 $D$ は、欠測やカテゴリカル特徴量により非ユークリッド性（負の固有値）を生じ得る。

- **基本数理式**:
  $$J = I - \frac{1}{n} \mathbf{1}\mathbf{1}^T, \quad B = -\frac{1}{2} J D^2 J, \quad B = V \Lambda V^T$$
  主座標: $X_k = V_k \Lambda_k^{1/2}$（第1軸・第2軸を出力）
- **固有値診断（Eigenvalue Diagnostics）の義務化**:
  - 正の固有値合計、負の固有値合計、負の慣性比率（Negative Inertia Fraction: $\sum |\lambda_-| / \sum |\lambda_i|$）を必ず計算・記録する。
- **加法定数補正（Lingoes / Cailliez 補正）**:
  - 負の慣性比率が事前設定閾値（例: 0.05）を超える場合は、`stats::cmdscale(..., add = TRUE)` による補正定数 $c$ を適用し、補正適用フラグと補正定数をメタデータに明記する。

### 2.6 階層的クラスタリング（HAC）オーバーレイの境界

- [`.agents/shared/evidence_cluster.R`](file:///.agents/shared/evidence_cluster.R) の `cluster_evidence_hclust` を再利用。
- 許容リンケージ（`EVIDENCE_HCLUST_ALLOWED_LINKAGE`）: `"average"`, `"complete"`, `"single"`（Ward 法は幾何学的に禁止）。
- **自動決定の禁止**: 自動 $k$ 決定や最適クラスタ数判定は行わず、明示的な $k$ 指定、またはクラスタリングなし（PCoA 単独プロット）を基本とする。
- **視覚表現の競合防止**: マップ上の点の色相（Hue）は「実務領域（`practical_region`）」に予約されているため、クラスタ番号を点の色相に割り当てることは禁止する。クラスタ境界は **外枠コンター（Convex Hull / Ellipse）** または **点外周リング / 形状** で表現する。

---

## 3. データ契約先行（Data & Schema First Specification）

本機能が生成・出力するすべてのデータ構造を先行定義する（表示層での ad-hoc 計算は厳禁）。

### 3.1 `evidence_signature_summary.csv`（シグネチャ要約テーブル）

| 列名 | 型 | NULL許可 | 一次情報・算出根拠 | 説明 |
|:---|:---|:---:|:---|:---|
| `signature_id` | character | NO | `sig_<sha256_8>` | 一意なシグネチャ識別子（決定キーのSHA-256先頭8文字） |
| `inferential_semantics` | character | NO | 入力データ契約 | `"posterior"` または `"bootstrap"` |
| `target_events` | integer | NO | $x_T$ | 対象群イベント数 |
| `target_total` | integer | NO | $n_T$ | 対象群総被験者数 |
| `reference_events` | integer | NO | $x_R$ | 対照群イベント数 |
| `reference_total` | integer | NO | $n_R$ | 対照群総被験者数 |
| `multiplicity` | integer | NO | 所属PT件数 | このシグネチャに該当するPT/項目の総数（例: 77） |
| `soc_count` | integer | NO | 所属SOC数 | 所属PTが跨るユニークなSOC数 |
| `rd_estimate` | numeric | NO | canonical point estimate | リスク差（事後中央値または標本推定量） |
| `rd_interval_lower` | numeric | NO | 95% interval lower | RD 95%信用区間/ブートストラップ下限 |
| `rd_interval_upper` | numeric | NO | 95% interval upper | RD 95%信用区間/ブートストラップ上限 |
| `rd_interval_width` | numeric | NO | upper - lower | 連続精度指標（区間幅） |
| `direction_support` | numeric | NO | $P(RD > 0)$ または $\hat{p}^*$ | 方向支持確率（因果的優越の主張禁止） |
| `resolution_grade` | character | NO | U0–U3 / NONE | 実務領域解像度グレード（U-Grade） |
| `dominant_region` | character | NO | canonical region | 最も確率密度の高い領域名 |
| `pcoa_axis1_core` | numeric | NO | PCoA 第1軸 | Core Evidence Map の X 座標 |
| `pcoa_axis2_core` | numeric | NO | PCoA 第2軸 | Core Evidence Map の Y 座標 |
| `pcoa_axis1_practical` | numeric | YES | PCoA 第1軸 | Practical Evidence Map の X 座標（$\delta$ 有効時） |
| `pcoa_axis2_practical` | numeric | YES | PCoA 第2軸 | Practical Evidence Map の Y 座標（$\delta$ 有効時） |
| `cluster_id` | character | YES | HAC 結果 | クラスタ番号（例: `"C1"`, クラスタ実行時のみ） |
| `diagnostic_badges` | character | YES | セミコロン区切り | 付与された診断コード（`ZERO_REFERENCE` 等） |

### 3.2 `evidence_signature_membership.csv`（個別PT/テーマ所属テーブル）

| 列名 | 型 | NULL許可 | 説明 |
|:---|:---|:---:|:---|
| `signature_id` | character | NO | 所属するシグネチャ ID |
| `row_key` | character | NO | 入力データの元行一意識別子 |
| `theme` | character | NO | 有害事象名（PT名）または項目名 |
| `parent_theme` | character | YES | SOC名または上位カテゴリ名 |
| `domain` | character | NO | `"clinical_safety"`, `"rwd"`, `"prescription"` |

### 3.3 `evidence_map.json`（幾何構造・診断メタデータ）

```json
{
  "schema_version": "evidence-map-v1",
  "created_at": "2026-09-26T23:59:00+09:00",
  "compression_summary": {
    "total_input_rows": 250,
    "unique_signatures": 67,
    "duplicate_groups_count": 20,
    "rows_in_duplicate_groups": 203,
    "compression_ratio": 0.268
  },
  "pcoa_diagnostics": {
    "core_map": {
      "features_used": ["rd_estimate", "rd_interval_width", "direction_support", "resolution_grade", "rr_mean_is_finite", "has_zero_reference", "target_n", "reference_n", "quarantine_flag_count"],
      "frozen_range_version": "1.0.0",
      "total_inertia": 12.45,
      "positive_inertia": 12.10,
      "negative_inertia": 0.35,
      "negative_inertia_fraction": 0.028,
      "correction_applied": false,
      "axis1_explained_variance_ratio": 0.485,
      "axis2_explained_variance_ratio": 0.242
    },
    "practical_map": {
      "enabled": true,
      "primary_delta": 0.01,
      "features_used": ["..."],
      "negative_inertia_fraction": 0.031,
      "correction_applied": false
    }
  },
  "clustering_metadata": {
    "method": "hclust",
    "linkage": "average",
    "k": 4,
    "disclaimer": "Cluster assignments are exploratory grouping aids only; they are never regulatory decisions."
  }
}
```

---

## 4. 可視化・UI 設計（Interactive Evidence Map Dashboard）

完全自己完結型 HTML（`evidence_map.html`）を生成する。Zero-External-Asset 原則を厳格に遵守（CDN・外部通信ゼロ、インライン SVG / Canvas / CSS / JS）。

### 4.1 視覚エンコーディング（Visual Encodings）

| 視覚要素 | 割り当て指標 | 表現ルール | 統計概念分離の根拠 |
|:---|:---|:---|:---|
| **X軸 / Y軸** | PCoA Axis 1 / Axis 2 | 2次元連続座標（分散説明率を軸ラベルに表示） | 全体的な多変量エビデンス類似度 |
| **点の大きさ (Radius)** | `multiplicity` | 1件: 4px 〜 最大件数: 22px（平方根スケール） | 重複の多さを表現しつつ座標空間を歪めない |
| **点の色相 (Fill Hue)** | `practical_region` | target_excess (赤系) / neutral (灰系) / ref_excess (青系) | 実務領域（Practical Difference）限定色 |
| **色の明度/彩度** | `resolution_grade` | U0 (高彩度) $\to$ U2 (低彩度) / U3 は無彩色固定 | 解像度（確信度）に応じた減衰 |
| **点の形状 (Shape)** | `resolution_grade` | U0: 円, U1: 四角, U2: 三角, U3: ダイヤ | 色覚多様性（CUD）への配慮 |
| **点の枠線 (Stroke)** | 診断コード | 赤太枠: `ZERO_REFERENCE`, 橙破線: `SPARSE` | 数値的不安定性・警告の明確化 |
| **クラスタ境界** | `cluster_id` | 凸包（Convex Hull）の点線または外周ラベル | 色相と衝突させずグループを明示 |

### 4.2 インタラクション機能
1. **ホバー・ツールチップ**: シグネチャID、事象件数 ($x_T/n_T, x_R/n_R$)、RD/RR、U-Grade、所属する代表PT名（上位5件＋他N件）。
2. **クリック・詳細ドロワー**: クリックしたシグネチャに属する全 PT / SOC の一覧テーブル表示。
3. **ビュー切り替えタブ**: 「Core Evidence Map」 $\leftrightarrow$ 「Practical Evidence Map」のワンクリック切り替え。
4. **多機能フィルタ**: SOC 絞り込み、U-Grade 絞り込み、特定 PT 検索（マップ上の該当点がハイライト）。
5. **CSV ダウンロード**: `#btn-export-signatures`（シグネチャ要約 CSV）および `#btn-export-members`（所属 PT 一覧 CSV）。

---

## 5. 具体的なテストマトリクス（Concrete QA Test Matrix）

抽象的な「テストする」を排し、入力 Fixtures、検証論理（Checks）、期待結果を表形式で確定する。

| # | テスト分類 | 対象 Fixture | 検証内容 (Checks) | 期待される結果 (Expected Results) |
|:---|:---|:---|:---|:---|
| **T1** | **正常系（重複縮約）** | `examples/Drug-Safty-example.csv` (250行) | `extract_evidence_signatures()` を実行し、生成されたシグネチャ数と多重度を検証 | 一意なシグネチャ数が厳密に **67件**、`multiplicity` の合計が **250** に完全一致すること。 |
| **T2** | **特定パターン検証** | `Drug-Safty-example.csv` | `(1, 219, 0, 219)` および `(0, 219, 1, 219)` のシグネチャを抽出 | `(1, 219, 0, 219)` の multiplicity が **77**、`(0, 219, 1, 219)` が **50** であること。 |
| **T3** | **幾何非支配検証** | T2 の 77 件重複シグネチャ | 重複行（77行）を個別に PCoA した場合と、シグネチャ（1行）として PCoA した場合の座標歪みを検証 | シグネチャ単位 PCoA では 77 重複が 1 観測点として扱われ、第 1 軸の固有値が不当に引きずられないこと。 |
| **T4** | **全件一意境界** | 人工データ（10行すべて異なる度数） | 重複が存在しないデータセットでの挙動確認 | 入力行数 = シグネチャ数（10件）となり、全 `multiplicity` が 1 となること。 |
| **T5** | **単一パターン境界** | 人工データ（10行すべて同一度数） | 極端な全重複データセットでの挙動確認 | シグネチャ数が 1 件、`multiplicity` が 10 となり、エラーなく単一点として処理されること。 |
| **T6** | **不変性契約照合** | Gower 距離行列 | 対称性（$D_{ij} = D_{ji}$）、対角成分ゼロ（$D_{ii} = 0$）、有界性（$0 \le D_{ij} \le 1$）を検証 | `assert_symmetric_distance_matrix` を完全にパスすること。 |
| **T7** | **決定ラベル排除** | 特徴量抽出入力 | `decision`, `regulatory_outcome` 等の禁止キーを意図的に混入した入力 | `[DECISION_LABEL_IN_FEATURE_SOURCE]` エラーで即座に Fail-Fast 停止すること。 |
| **T8** | **PCoA 固有値診断** | Gower 距離行列 | 正の固有値、負の固有値、負の慣性比率の算出を検証 | `negative_inertia_fraction` が数値として算出され、診断ログに記録されること。 |
| **T9** | **負の固有値補正** | 負の慣性比率が 0.05 を超える人工距離行列 | `cmdscale(..., add = TRUE)` による加法補正適用の検証 | 補正後の固有値がすべて非負（実数座標）となり、`correction_applied = TRUE` が記録されること。 |
| **T10** | **HAC ガードレール** | HAC クラスタリング結果 | 禁止リンケージ（Ward 法）の拒絶、免責文言の存在 | Ward 法指定時はエラー停止し、出力結果に `EVIDENCE_CLUSTER_WORDING` が必ず含まれること。 |
| **T11** | **オフライン静的監査** | 生成された `evidence_map.html` | `http:`, `https:`, `//` 等の外部ネットワーク参照、およびローカル絶対パスのスキャン | 外部通信 0 件、OS ローカル絶対パス（`/Users/`, `C:\` 等）0 件で完全合格すること。 |

---

## 6. 実装モジュールとファイル構成

### 6.1 新規作成・変更ファイル一覧

1. **新規共通モジュール**:
   - `.agents/shared/evidence_signature.R`:
     度数データの完全一致縮約、シグネチャ ID 発行、メンバーシップ辞書管理。
   - `.agents/shared/evidence_pcoa.R`:
     Gower 距離からの PCoA 座標計算、固有値診断、加法定数補正（Lingoes / Cailliez）。
2. **新規可視化モジュール**:
   - `.agents/skills/vcd-categorical-reporting/evidence_map_template.html`:
     インライン SVG / Canvas によるインタラクティブ・エビデンスマップ・テンプレート。
   - `.agents/skills/vcd-categorical-reporting/evidence_map_render.R`:
     データ注入および自己完結 HTML レンダリングエンジン。
3. **新規テストスイート**:
   - `tests/test_evidence_signature.R`: T1〜T5 の縮約論理テスト。
   - `tests/test_evidence_pcoa.R`: T6, T8, T9 の PCoA 数理・固有値補正テスト。
   - `tests/test_evidence_map_qa.R`: T10, T11 の可視化・HTML 静的スキャンテスト。
4. **新規スキーマ**:
   - `schemas/evidence-map-v1.json`: マップ幾何およびメタデータの正本 JSON Schema。

---

## 7. 提出前自己レビュー（Pre-Submission Independent Gate）

`plan_quality_analysis_and_prevention_001_0926.md` に基づき、提出前に以下の自律監査を実施：

- [x] **Q1. データの流れ（Provenance）**: 中間データ構造（`evidence_signature_summary.csv`, `evidence_signature_membership.csv`, `evidence_map.json`）の列定義・型・NULL許可を表形式で先行明記したか？ $\to$ **YES (§3 に完全定義)**
- [x] **Q2. 一次情報との完全一致**: 定数名（`CORE_CLUSTERING_KEYS`, `DELTA_CLUSTERING_KEYS`, `EVIDENCE_HCLUST_ALLOWED_LINKAGE`, `FORBIDDEN_DECISION_LABEL_KEYS`）は実コードから完全一致で転記したか？ $\to$ **YES (§2.4, §2.6 に完全一致)**
- [x] **Q3. 論理的無矛盾性**: 重複行が幾何空間を歪めない設計になっているか？ $\to$ **YES (1 signature = 1 point、multiplicity はサイズとメタデータのみに限定)**
- [x] **Q4. ドメイン・統計原則への合致**: 点の色相を行全体に着色せず実務領域に限定し、クラスタ境界と衝突させない設計になっているか？ $\to$ **YES (色相は実務領域限定、クラスタは外枠コンターで表現)**
- [x] **Q5. 具体的テストマトリクス**: 具体的な Fixtures（`Drug-Safty-example.csv` の 250 行 $\to$ 67 signatures）、Checks、Expected Results を表形式で網羅したか？ $\to$ **YES (§5 に T1〜T11 を網羅)**
- [x] **Q6. 環境非依存性**: Windows / Linux / macOS の差分、パス形式、外部ツール非依存性が担保されているか？ $\to$ **YES (Zero-External-Asset 原則の静的監査 T11 を配備)**
