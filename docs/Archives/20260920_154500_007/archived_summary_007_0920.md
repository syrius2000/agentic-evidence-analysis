# アーカイブ済みArtifactの要約 (Batch 007)

- **created**: 2026-09-20 15:45 (JST)
- **author**: Antigravity
- **対象期間**: 2026-09-18 22:54 (JST) 〜 2026-09-19 19:52 (JST)
- **archive_batch_id**: 20260920_154500_007
- **source_count**: 8

---

## 1. 対象と結論

本ドキュメントは、`docs/Artifacts/` に蓄積されていた臨床・学術標準テーマ導入、Section 12 刷新、2次元・3次元ダッシュボード共通プレゼンテーション資産基盤の新設、および 3次元多項 Dirichlet 主事前の Jeffreys（$\alpha=0.5$）移行と希少確率精度確保（F1〜F3是正）に関する計画書・変更記録・検証報告書計 8 件を精査・統合し、監査可能な原本として `docs/Archives/20260920_154500_007/sources/` に集約したアーカイブです。

この期間において、本リポジトリは以下の重要マイルストーンを完遂しました：

1. **臨床・学術標準テーマと共通プレゼンテーション基盤の確立**:
   NEJM / Nature Medical 調の洗練された視覚言語（1px細枠線、学術ネイビー `#1F4D7A` アクセント、行群色の固定）を定義する `.agents/shared/dashboard_theme.css`、外部 CDN 参照ゼロの完全インライン DataTables 日本語辞書 `.agents/shared/dashboard_dt_ja.R`、および次元・モデル固有コンテキストを受け取る共通用語集 `.agents/shared/dashboard_glossary.R` を新設。2次元（`vcd-categorical-analysis`）および 3次元（`vcd-bayesian-evidence-analysis`）ダッシュボード双方に適用し、外部アセット通信およびOSローカル絶対パス 0 件の完全オフライン性を担保。
2. **Section 12 レンダリング障害の根絶**:
   Pandoc Markdown パーサにおいて、HTML ブロック内部のインデントが原因で発生していたコードブロック化（`pre > code` エスケープ崩れ）を行頭インデントの完全排除（Zero-Leading-Space 契約）により恒久解消。
3. **3次元条件付き割合の多項 Dirichlet Jeffreys 主事前移行**:
   ユーザー方針に基づき、3次元ダッシュボードの多項 Dirichlet 事後推論における主事前を各セル $\alpha=1.0$（一様事前）から $\alpha=0.5$（Jeffreys事前）へ移行。$\alpha=1.0$ は感度分析として並行出力・比較する体制を確立。
4. **独立レビュー F1〜F3 の是正（希少事象の倍精度保持）**:
   独立レビュー（`verification_shared_dashboard_003_0919.md`）により指摘された F1（大 $N$・希少事象における固定小数 4 桁丸めによる事後分布ゼロ潰れ）、F2（設定水準にかかわらず 95%CI と表記される列名固定）、F3（用語集冒頭での Evidence $N$ 比例の無条件一般化）を即座に是正。倍精度の完全保持、ETI 表記・有効桁整形、条件付き $c$ 倍説明の厳密化を完了（commit `7c780b9`）。全 99 アサーションを含む全回帰テストを 100% PASS させ、正式に封印。

---

## 2. 確定した決定と理由

| 計画・記録文書 | 確定した決定事項 | 理由・背景 | 集約先の節 |
| :--- | :--- | :--- | :--- |
| `implementation_plan_007_0918.md` | Nature Research Figure Guide に基づく視覚言語の策定。色相は常に行カテゴリに固定し、Section 4 の正負残差は発散色（青緑／黄褐）、隔離セルは琥珀太枠で表現。 | 統計的責務分離を維持しつつ、色覚多様性に配慮した学術水準の可読性を確保するため。 | §3.1 |
| `section12_refresh_proposal_001_0918.md` | Section 12 の Zero-Leading-Space 契約。HTML 要素を行頭 0 カラムから記述し、Pandoc インデントコードブロック判定を無効化。 | ダッシュボード末尾の用語・数理解説がコードブロックとしてエスケープされレイアウト崩れを起こす問題を根絶するため。 | §3.1 |
| `implementation_plan_008_0919.md` | 共有資産化と 3 次元主事前移行の工程分離。主事前を $\alpha=0.5$（Jeffreys）、感度事前を $\alpha=1.0$（Uniform）と定義。旧結果のラベル改ざんは行わず保存。 | 表示共通化での計算不変性と、主事前移行による意図した数値差を明確に区別し、再現性を保護するため。 | §3.2 |
| `implementation_plan_008_0919.md` | Poisson BIC、対数線形モデル選択（M1〜M9）、局所セル診断（$T_i^{\rm score}$、Leverage $h_{ii}$、Quarantine 3条件）の計算式・判定論理は一切変更しない。 | セルカウントの対数線形尤度構造と、条件付き割合の事後推論の責務を厳密に分離するため。 | §3.2 |
| `change_record_shared_dashboard_001_0919.md` | 共有 CSS・辞書・用語集の配置先を `.agents/shared/` に集約。旧 fixture は上書きせず、新規 run（`scratch/ucb_jeffreys_crv_0919_out/`）で検証・封印。 | 複数スキル間での資産重複を解消し、過去の監査証拠を破壊しないため。 | §3.1, §3.2 |
| `verification_shared_dashboard_004_0919.md` | （F1是正）計算エンジンおよび中間保存での固定小数丸め（`safe_round`）を撤廃し、倍精度で保持。JSON 書き出しは `digits=NA` とし、表示側で `DT::formatSignif`（有効桁 4 桁）を用いる。 | 大標本下での極めて小さい正の希少確率が 0 へ縮退し、不確実性幅が消失する重大な情報損失を防ぐため。 | §3.3 |
| `verification_shared_dashboard_004_0919.md` | （F2是正）信頼区間表記を排し、設定された `interval_level` に連動した `XX% ETI下限` / `上限` 表記へ統一。 | ベイズ等裾信用区間（Equal-Tailed Interval）としての統計的定義を正確に反映し、指定水準との不整合を解消するため。 | §3.3 |
| `verification_shared_dashboard_004_0919.md` | （F3是正）共通用語集冒頭の要約を「標本数が増えると、小さな差にも強い証拠が得られる場合があります」へ修正。 | 標本数比例は「構成比を保ったまま度数を $c$ 倍した条件付き性質」であり、一般の追加データで無条件に比例すると誤解されるのを防ぐため。 | §3.3 |

---

## 3. 主要成果と検証の限界

### 3.1 プレゼンテーション共通基盤と学術テーマ（Engineering）

- **成果**:
  - `.agents/shared/dashboard_theme.css`: 1px境界線、フラットカード、学術フォントスタック、`details.glossary-accordion` ネイティブアコーディオン。
  - `.agents/shared/dashboard_dt_ja.R`: 外部 CDN 通信を完全排除したインライン JSON 辞書（DataTables 1.10+ / 2.0+ 両対応）。
  - `.agents/shared/dashboard_glossary.R`: 2次元（Cramér's V、局所残差）および 3次元（M1〜M9階層対数線形、周辺・条件付き独立）の数理モデル解説を raw HTML で動的生成。
  - 静的スキャンにより、生成 HTML 内に `http:`, `https:`, `//`, `/Users/` が 0 件であることを実証。
- **検証の限界**:
  - レンダリング確認は Chrome / Chromium 系ヘッドレス環境およびローカル配信プレビューにて実施。一部の特殊なモバイルブラウザ等での微小な差異は保証外（デスクトップ専用契約）。

### 3.2 3次元多項 Dirichlet Jeffreys 主事前移行（Mathematics）

- **成果**:
  - 観測セル数 $K$ に対し、事前パラメータ各セル $\alpha=0.5$（総事前濃度 $0.5K$）を適用。
  - UCB Admissions データ（$N=4526$）において、大 $N$ 層（Dept A Male: 512/825）では事後平均差が $+0.0002$、小標本層（Dept B Female: 17/25）では $+0.0065$ と、層内度数に応じた平滑化緩和の理論的挙動を確認。
  - Poisson BIC（M5=332.3119, M8=339.1982）および局所セル診断（Regular 13, Quarantined 11, Candidate 1）の完全不変性を実証。
- **検証の限界**:
  - 構造的ゼロ（Structural Zeros）は解析対象外（サンプリングゼロのみ $\alpha$ 平滑化の対象）。
  - 分子・分母の任意集約カテゴリに対する事後分布は多項モデルからの誘導 Beta 分布であり、独立な二項 Beta モデルとは総事前濃度が異なる。

### 3.3 希少確率精度確保と独立レビュー指摘是正（Quality & Precision）

- **成果**:
  - $N=120,001$、希少観測度数 $c(0, 1, 30000, 40000, 50000)$ の極限ケース（誘導事後 $\text{Beta}(2, 120001.5)$）において、解析値 $\approx 0.00001667$ に対し、MC 要約が $0.00001673$（下限 $0.00000302$、上限 $0.00003947$）として非ゼロ・有限幅で正確に保持・出力されることを検証。
  - `tests/test_shared_dashboard_math.R`（8ブロック、99アサーション）
  - `tests/test_three_way_computation_engine.R`（6ブロック、49アサーション）
  - `tests/test_three_way_dashboard_html.R`（11ブロック、104アサーション）
  - `tests/test_vcd_categorical_dashboard_v4.R`（15 PASS / 0 FAIL）
  - 上記全テスト 100% 成功。
- **検証の限界**:
  - モンテカルロサンプリング（100,000 draws）に基づく ETI 推定値には、乱数種およびサンプリング誤差（MCSE）が伴う（解析的 Beta 分位点との許容範囲は $6\sigma_{\rm MCSE}$ 以内として検証）。

---

## 4. 未解決事項と引継ぎ

- **3次元セル候補判定式の $N$ 閾値**:
  現行の 3 次元候補判定式には 2 次元の $N \ge 2000$ に相当する標本サイズ閾値が含まれておらず、純粋に統計的証拠強度と効果量で判定される。これは設計意図として保持されており、今回の主事前移行では変更していない。
- **恒久手引きの維持**:
  `docs/Artifacts/quality_loop_manual_001_0912.md` は今後も継続参照される運用マニュアルであるため、`docs/Artifacts/` にそのまま維持されている。
- **Git 反映**:
  実装・テスト・修正は commit `7c780b9` にてローカルおよびリモート `origin/main` に反映済み。今回のアーカイブ作業による移動・まとめ文書作成は未コミット状態であるため、必要に応じて別途コミットを行う。

---

## 5. 元文書と復元情報

退避された 8 文書の移動元、保存先、およびハッシュ対応表は以下のとおりです。
詳細な移動証跡は [`journal/move_journal.md`](journal/move_journal.md)、機械可読メタデータは [`archive_manifest.json`](archive_manifest.json) を参照してください。

| 元パス | 保存先 | 役割 | 移動前 SHA-256 |
| :--- | :--- | :--- | :--- |
| `docs/Artifacts/implementation_plan_007_0918.md` | [`sources/implementation_plan_007_0918.md`](sources/implementation_plan_007_0918.md) | 実装計画 | `54b453d91fc00bf4a1e11bdd73515b7506e15561fd0cccc29d30cbb2a2d2d8f7` |
| `docs/Artifacts/section12_refresh_proposal_001_0918.md` | [`sources/section12_refresh_proposal_001_0918.md`](sources/section12_refresh_proposal_001_0918.md) | 刷新提案 | `b115029882fcf2c52a2ea64806e38f12cd1cb24d1570550c36a530250a852241` |
| `docs/Artifacts/implementation_plan_008_0919.md` | [`sources/implementation_plan_008_0919.md`](sources/implementation_plan_008_0919.md) | 実装計画 | `e2b24dc73b98e7955f8221234356abd3291265baea4d83ef75f07dd6da0f8b38` |
| `docs/Artifacts/change_record_shared_dashboard_001_0919.md` | [`sources/change_record_shared_dashboard_001_0919.md`](sources/change_record_shared_dashboard_001_0919.md) | 変更記録 | `51015922743832b2d1fc409ea15556563e157b071e171ed1b5647a43262912e8` |
| `docs/Artifacts/verification_shared_dashboard_001_0919.md` | [`sources/verification_shared_dashboard_001_0919.md`](sources/verification_shared_dashboard_001_0919.md) | 検証記録 | `eca5827496feac4caa5e973a3fabe260e7ae982d7b953a2b22b741010dd284da` |
| `docs/Artifacts/verification_shared_dashboard_002_0919.md` | [`sources/verification_shared_dashboard_002_0919.md`](sources/verification_shared_dashboard_002_0919.md) | 検証記録 | `e10e34de215a7868c7b091815c979254d17c8733772e2f630de9fe27587da014` |
| `docs/Artifacts/verification_shared_dashboard_003_0919.md` | [`sources/verification_shared_dashboard_003_0919.md`](sources/verification_shared_dashboard_003_0919.md) | 独立レビュー | `19aa3d745a97a06689760c1141009721114ad780bb67aeca770e45f807250946` |
| `docs/Artifacts/verification_shared_dashboard_004_0919.md` | [`sources/verification_shared_dashboard_004_0919.md`](sources/verification_shared_dashboard_004_0919.md) | 修正検証 | `570d83ba0ab6069b9ecac6cf9c28205eef9acd386414687afe0d7180430439c1` |

---

## 6. 保留・除外

- `docs/Artifacts/quality_loop_manual_001_0912.md`: 継続利用する運用手引きとして `docs/Artifacts/` に保持。
- `docs/Artifacts/.gitkeep`: ディレクトリ保持用として `docs/Artifacts/` に保持。
