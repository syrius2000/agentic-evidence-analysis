# OpenSpec 正本仕様・運用契約 再整合（Reconciliation）計画書

created: 2026-09-20 21:00 (JST)
update: 2026-09-21 00:05 (JST)
author: Codex (GPT-6)

- **初稿作成者**: Antigravity
- **対象リポジトリ**: `syrius2000/agentic-evidence-analysis`
- **対象ブランチ**: `main` (基準コミット: `e399368`)
- **計画ID**: `implementation_plan_021_0920`
- **OpenSpec Change名**: `reconcile-canonical-specs-with-current-implementation`

### 追補（2026-09-21 01:00 JST）

独立レビューで正規回帰suiteのDashboardテンプレート検査3件が失敗したため、現行テンプレート構造に合わせたテスト契約の修正を本計画へ追加する。旧テンプレートのchunk名や`mosaic(shade=TRUE)`を現行Dashboardへ再導入することはしない。修正対象はテストと検証記録に限定し、統計エンジン・生成データ・既存archiveは変更しない。

---

## 1. 目的と背景

外部監査（`01_OpenSpec_Current_State_Audit_20260920.md`）および実装計画案（`02_OpenSpec_Reconciliation_Implementation_Plan_20260920.md`）と、本リポジトリの最新一次情報（コミット `e399368`）を照合した結果、直近の多数の OpenSpec Change 完了・アーカイブに伴い、以下の多重正本乖離（Multi-Source-of-Truth Drift）が実証された：

1. **F-01 (Blocker)**: `vcd-categorical-analysis/SKILL.md` が、正本 Spec および実装が明示禁止（`CANONICAL_CONFIG_OVERRIDE_FORBIDDEN`）している旧 CLI（`--data`, `--vars`, `--freq`, `--render`）を標準実行例として提示している。
2. **F-02 (Blocker)**: `vcd-pass0-consultation/SKILL.md` の設定例に旧 `dirichlet_a: 1.0` が残存し、現行 schema および正本 Spec の `primary_alpha=0.5, sensitivity_alpha=1.0` と衝突している。
3. **F-03 (High)**: Pass 0 適用範囲が `AGENTS.md`（必須/推奨/対象外の明示境界）、`docs/reference/skill_responsibilities.md`（「いかなる分析もPass 0必須」）、`vcd-pass0-consultation/SKILL.md`（「Step 1は常にPass 0」）で矛盾している。
4. **F-04 (High)**: 3次元セル診断において、`shared-dashboard-presentation` Spec は「3次元候補式に $N$ 閾値は入っていない」と明記している一方、`skill_responsibilities.md` や `vcd-pass0-consultation` には 3次元を包含する形で「$N > 2,000$ Dual-Filter」と記載されている。
5. **F-05 (Med-High)**: `analysis_quality_contract.md` の可視化 QA に、旧 Evidence Score が現行の通常レビュー項目として並列されている。
6. **F-06 (Med-High)**: `deterministic-r-dependencies` Spec が正規回帰テストを「23本」と固定しているが、現行 `tests/run_regression_suite.R` の登録数は **29本** であり、固定本数の乖離が発生している。
7. **F-07〜F-09 (Med)**: `vcd-categorical-analysis` のバージョン表記不一致（4.0 vs 4.1）、Pass 0 成果物契約（`data_analysis_scope.md` vs `consultation.rationale`）、`cell-evidence-interpretation` の旧 Score 未確定状態の残存。

本計画は、これらの不整合を恒久的に解消し、**「正本（Normative Spec）が単一であり、運用手引き（SKILL.md）が正本に従い、テスト/Schema が正本を自動検証し、過去アーカイブは不変履歴として保護される」** 状態を確立することを目的とする。

---

## 2. 統治原則（Architectural Invariants）

1. **歴史の不変性（Immutable History）**:
   `openspec/changes/archive/*` および `docs/Archives/*` の過去成果物は、当時の意思決定と監査証拠であるため直接改ざんしない。最新仕様への追跡は Supersession Map（追跡対応表）により明示する。
2. **正本の単一性（Single Source of Truth）**:
   規範的挙動（WHAT）の最上位正本は `openspec/specs/*/spec.md` とする。`SKILL.md`、`docs/reference`、`analysis_quality_contract.md` は Spec から派生（Align）した運用・解説文書であり、独自に仕様を追加・変更してはならない。
3. **可変資産の非固定化（No Hardcoded Inventory Counts）**:
   テスト本数やファイル数等の将来変動する数値を Spec に固定記述しない。機械可読なテストレジストリ（`tests/run_regression_suite.R`）を正本参照とする。
4. **Fail-Fast な機械的ゲート（Automated Consistency Gates）**:
   Spec と運用ドキュメントの再乖離を防ぐため、静的ドキュメント一貫性テスト（Python / shell）を配備する。

---

## 3. オーナー決定事項（Owner Decisions）の確定

2026-09-20、Ownerは前回レビューを理解・承認し、以下の方針と計画改定を明示的に了承した。BICがセル探索の標本サイズ問題を吸収するという説明は撤回する。本ラウンドの作業は計画書の改定であり、以下の実装タスクの実施記録ではない。

| 決定項目 | 確定方針 | 根拠・理由 |
| :--- | :--- | :--- |
| **Pass 0 適用範囲** | 必須: `vcd-categorical-analysis`, `vcd-bayesian-evidence-analysis`。文脈推奨: `questionnaire-batch-analysis`。対象外: SAS互換2スキル、単体・回帰テスト、コード・文書保守。 | `AGENTS.md` 鉄則2の境界を維持する。 |
| **2次元 Canonical CLI** | リポジトリルートから `Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R --config analysis_config.json`。許可引数は `--config`, `--out`, `--label`, `--help`。 | 解析条件のCLI上書きは禁止。禁止引数の説明・異常系テストと、正常実行例を区別する。 |
| **3次元 事前分布** | 主事前: 多項Jeffreys α=0.5。感度分析: α=1.0。3次元設定キーは `dirichlet_prior`。 | 旧runを再ラベルしない。旧 `dirichlet_a` の読み取り対応の有無は実装を確認し、文書改定だけで互換readerを新設しない。2次元schemaへこのキーを流用しない。 |
| **Dual-Filter 基準** | 2次元: REGULAR、N≥2000、abs(log(O/E))≥0.50、T_score≥3.84。3次元: REGULAR、abs(log(O/E))≥0.50、T_score≥3.84、Nカットオフなし。 | 現行の探索的候補契約を維持する。BICはモデル比較の指標であり、局所検定の多重性や大標本での過剰検出を吸収しない。これらの閾値は普遍的な重要性基準・FWER/FDR保証ではない。 |
| **旧 Evidence Score** | 3次元で保持する場合は監査専用。2次元Interfaceは旧Score出力禁止を維持する。 | 旧残差ペナルティ式と、再適合による局所尤度比・局所BIC差・Rao scoreを区別する。正当な局所モデル比較まで否定しない。 |
| **回帰テストレジストリ** | `official_tests` をR正規回帰テストの台帳とする。Python契約テストは明示した別ゲートで実行する。 | 固定本数を規範にしない。R台帳が全言語の全テストを網羅するとは主張しない。 |

### 3.1 セル追加モデルの数学的意味と扱い

基準モデルを $M_0: \log\mu_j=x_j^T\beta$、セル $i$ の追加モデルを $M_{1,i}: \log\mu_j=x_j^T\beta+\gamma_i 1(j=i)$ とする。これは「基準モデルで説明した後、セルiに固有の項を許すと適合がどれだけ改善するか」という、意味のある局所モデル比較である。セルiを追加したときは nuisance parameter であるβも再推定するため、他セルの期待値も変わり得る。

- **再適合による局所尤度比**: 同じデータ・支持集合・尤度で両モデルを最尤適合し、$\Delta G_i^2=2\{\ell(\widehat M_{1,i})-\ell(\widehat M_0)\}$ を算出する。追加列が独立で正則条件を満たす場合の自由度差は1。飽和モデルやランク不足では1と決めつけない。
- **局所BIC改善量**: 総度数Nを標本サイズとする本リポジトリの比較規約では、$\mathrm{BIC}(M_0)-\mathrm{BIC}(M_{1,i})=\Delta G_i^2-\Delta p\log N$。正値はこの2モデル間で拡張モデルを支持する。この代数的なBIC差と、正則条件下の $2\log BF_{1,0}$ の漸近近似は区別する。正確なBFには両モデルの適切な事前分布と周辺尤度が必要。
- **Rao score**: Poisson GLMの基準適合における効率的スコア検定は $T_i^{\rm score}=r_{P,i}^2/(1-h_{ii})$。追加モデルの全面再適合なしに同じ追加方向を検定できる。尤度比との漸近的対応は帰無仮説・局所対立および正則条件の下であり、有限標本の等式ではない。未補正Pearson残差二乗から罰則を引いた旧式を、局所BIC差と同一視しない。
- **標本サイズと実務的重要性**: 固定した非ゼロの乖離の下では、適合改善は通常Nのオーダー、BIC罰則はlog Nのオーダーになる。大標本で拡張モデルを支持すること自体は数学的破綻ではない。「全セルが必ず正になる」も一般には成立しない。小さな差への統計的証拠と、薬学・実務上の重要性を分ける。
- **1観測あたりの改善**: 同じ総度数を持つ多項適合、または総期待度数がNに一致するPoisson適合では、$\Delta G_i^2/N=2\{D_{KL}(\hat p\Vert\hat p_0)-D_{KL}(\hat p\Vert\hat p_{1,i})\}$。これは標本内のモデル改善であり、符号付き局所効果・外部予測改善・実務的重要性を自動的に表さない。
- **適用条件と探索**: ゼロ観測では追加係数が−∞へ向かう境界推定、疎セルでは近似不良、h=1では追加方向の識別不能が生じ得る。同じデータによる基準モデル選択・多数セル探索後の検定は、その選択を無視した確証的推論としない。BIC差が正という条件だけでは多重性を制御しない。

本Changeでは上記の意味・限界を既存Specと解説へ反映し、現行Rao scoreおよび探索候補の計算を維持する。新しい局所再適合エンジン、局所BF、p値補正、数値出力列の追加は対象外とする。将来採用する場合は、基準モデル、標本モデル、ランク差、境界処理、選択・多重性、効果指標、独立参照テストを先に定義する。

根拠: [既存の3次元数理解説](../reference/three_way_models.md)、[旧指標の解説](../reference/stats_categorical.md)、[Schwarz (1978) 原論文](https://www.andrew.cmu.edu/user/kk3n/simplicity/schwarzbic.pdf)、[R公式 anova のモデル比較](https://search.r-project.org/R/refmans/stats/html/anova.html)。旧版で実際に全セルの追加モデルを再適合したかは、履歴調査で確認するまで未確認とする。

---

## 4. 実施フェーズと変更対象ファイル

### Phase 0: 基準状態と承認範囲の記録

- [ ] HEADの完全SHA、作業ツリー差分、active Change、対象文書・schema・テスト台帳のハッシュを記録する。e399368と異なる場合は差分を照合する。
- [ ] 外部監査F-01〜F-09を現行checkoutで再確認し、事実・既修正・未確認を区別する。
- [ ] 旧Score、セルダミー再適合、Rao scoreの実装・テスト・履歴を照合し、同名指標の計算式を識別する。未実装の手法を実装済みと記載しない。
- [ ] 既存変更を保持し、今回の変更対象と分離する。基準変動時は再照合し、自動rebaseや復元を前提にしない。

### Phase 1: OpenSpec Change の起票

- `openspec new change "reconcile-canonical-specs-with-current-implementation"` により、正規メタデータを持つチェンジセットを起草。
- `proposal.md`、`design.md`、`tasks.md` とcapability別のdelta specを作成し、Owner決定と3.1の数理境界を反映する。

### Phase 2: Change配下のdelta specの作成

以下は同期先の正本パスを示す。編集はまず `openspec/changes/reconcile-canonical-specs-with-current-implementation/specs/` の対応capabilityへ記述する。現行正本への同期はPhase 6の検証・受入後に行う。

1. **[NEW] `openspec/specs/analysis-workflow-governance/spec.md`**:
   - リポジトリ横断の統治規約（正本階層、Pass 0 applicability matrix、成果物契約、R/Pythonテストの責務）を新設。CLI詳細・数理式は担当capabilityを参照し、二重定義しない。正本階層は製品挙動の範囲とし、Owner承認・Git操作等のAGENTS運用権限を上書きしない。
   - CC-SDDの通常参照面は `openspec/specs/**/spec.md` とする。active Changeのdelta specは、対象Changeが明示された実装・レビュー時だけに参照する。`openspec/changes/archive/**` は履歴・根拠確認に限り、現行挙動の入力として採用しない。
   - CC-SDDが全リポジトリ検索を行う場合、archive由来の記述には historical / superseded の文脈ラベルを付け、現行Specと競合したときは現行Specを採用する。判定できない場合はSupersession Mapを確認し、それでも不明なら実装を停止してOwnerへ照会する。
2. **[MODIFY] `openspec/specs/two-way-evidence-analysis/spec.md`**:
   - Canonical 実行の具体例シナリオを追加、バージョン表記の責務分離。
3. **[MODIFY] `openspec/specs/conditional-rate-view/spec.md`**:
   - `dirichlet_prior` 設定キーの標準化。
4. **[MODIFY] `openspec/specs/multi-baseline-cell-diagnostics/spec.md`**:
   - 3次元 Dual-Filter の現行条件を「REGULAR、Effect条件、Rao score条件、Nカットオフなし」と明文化。N閾値が数学的に不要と証明されたとは記載しない。
5. **[MODIFY] `openspec/specs/cell-evidence-interpretation/spec.md`**:
   - 旧 Evidence Score の扱いを確定し、3.1の局所尤度比・BIC改善・Rao scoreとの区別を保持する。capabilityは存続させ、新しい指標の実装を要求しない。
6. **[MODIFY] `openspec/specs/deterministic-r-dependencies/spec.md`**:
   - 「23本」の固定記述を「正規回帰テストレジストリ（`tests/run_regression_suite.R`）に登録された全件」へ置換。
7. **[MODIFY] `openspec/specs/shared-dashboard-presentation/spec.md`**:
   - 旧3次元α=1.0の表示と現行α=0.5の表示を成果物メタデータに結び付ける。局所BICをセルBFや重要性と同一視しない説明を同期する。

### Phase 3: 運用ドキュメント・スキル手引き（Derived Docs）の同期

1. **[MODIFY] `.agents/skills/vcd-categorical-analysis/SKILL.md`**:
   - `--data`, `--vars`, `--freq`, `--render` の旧 CLI 例を全廃。
   - Pass 0 $\to$ `analysis_config.json` $\to$ `--config` の正規 Canonical 実行フローへ全面刷新。バージョン表記を v4.1 へ統一。
2. **[MODIFY] `.agents/skills/vcd-pass0-consultation/SKILL.md`**:
   - `dirichlet_a: 1.0` を削除し、`dirichlet_prior: { primary_alpha: 0.5, sensitivity_alpha: 1.0 }` へ修正。
   - 「Step 1は常にPass 0」を Applicability Matrix へ修正。
   - 3次元の成果物契約として `data_analysis_scope.md` の代わりに `consultation.rationale` が正本である旨を明記。
3. **[MODIFY] `docs/reference/skill_responsibilities.md`**:
   - 「探索・因果構造」を「探索・関連構造」へ是正。
   - Pass 0 適用範囲を Applicability Matrix に合致。
   - 3次元 Dual-Filter の $N > 2,000$ 表記を実態に合致。
4. **[MODIFY] `.agents/shared/analysis_quality_contract.md`**:
   - 可視化 QA（Line 56）等に残る Evidence Score を「audit-only（監査専用）」と明記。
   - 2次元・3次元・アンケートの必要成果物境界を分離。
5. **[MODIFY] `docs/reference/stats_categorical.md`, `advanced_analysis.md`, `three_way_models.md`, `stats_bayesian.md`, `README.md`（いずれも `docs/reference/` 配下）**:
   - 「大標本で正になるから数学的破綻」「全セルが必ず正値化」という一般化を改める。旧式の未正当化と、正当な局所モデル比較の標本サイズ依存を区別する。
   - 3.1の定義・適用条件を `three_way_models.md` に集約し、他文書はそこを参照する。再適合・局所BFの実装状況はPhase 0の証拠に合わせる。
6. **[MODIFY・必要差分のみ] ルート `README.md`, `AGENTS.md`**:
   - Pass 0適用境界と正本への導線を同期する。既存の承認・履歴保護ルールは維持する。

### Phase 4: 再発防止の一貫性検査スクリプト配備

1. **[NEW] `scripts/test_doc_consistency.py`**:
   - 旧 CLI 引数（`--data`, `--vars`, `--freq`, `--render`）が現在の `SKILL.md` や運用マニュアルの canonical 節に出現しないことを静的スキャン。
   - `dirichlet_a` が現行設定例に出現しないことを検証。
   - Spec 内に「23本」等のテスト固定本数が残っていないことを検査。
   - `run_regression_suite.R` 内の全テストファイルがディスク上に存在することを検証。
   - 対象スキル・節・コードブロックを限定する。禁止引数の説明、拒否テスト、legacy説明、archive、別スキルの正常CLIを誤検出しない。
   - Pass 0設定例を対象schemaで実際に検証する。文字列の存在だけで設定整合を合格にしない。
   - 意図的に誤ったcanonical実行例・prior設定・存在しないテストパスを与える負例と、正当なlegacy説明の許容例でゲート自体を検証する。
   - CC-SDD向けに、現行Spec、active Change、archiveの参照優先順位を検査する。archiveにだけ存在する旧 `dirichlet_a` や旧CLI例を、現行契約違反として誤検出しない。

### Phase 5: 追跡対応表（Supersession Map）の作成

1. **[NEW] `docs/reference/spec_supersession_map.md`**:
   - 過去アーカイブ Change と現行正本 Spec の関係性（どの Change がどの Spec に包含・昇格されたか）を明文化。

### Phase 6: 検証・正本同期・引継ぎ

- [ ] 第5章の検証結果をChange内 `verification_report.md` に記録する。
- [ ] 受入後にdelta specを現行正本へ同期し、全Specの構造検証・リンク・一貫性検査を再実行する。
- [ ] archive、commit、pushは別操作としてOwnerの指示時に実施する。新規archiveの追加と既存archiveの不変性を区別する。

---

## 5. 検証計画（Verification Plan）

### 1. 自動テスト

1. **OpenSpec 構文・構造検証（数理的正しさは別途レビュー）**:

   ```bash
   openspec validate reconcile-canonical-specs-with-current-implementation --strict
   openspec validate --all --strict --json
   ```

2. **新設ドキュメント一貫性ゲート**:

   ```bash
   python3 scripts/test_doc_consistency.py
   ```

3. **正規統計回帰テスト全件実行（実行時の台帳件数を記録）**:

   ```bash
   Rscript tests/run_regression_suite.R
   ```

4. **既存 Python 契約テスト実行**:

   ```bash
   python3 tests/test_analysis_quality_contract_docs.py
   python3 tests/test_skill_ownership_contract.py
   ```

5. **Markdown Linter 検査**:

   ```bash
   scripts/markdownlint/check.sh
   ```

   変更した `docs/` と `.agents/` のMarkdownも、`.markdownlint.json` を指定して対象ファイルを明示検査する。既存archiveのlint修正は行わない。

### 2. 手動・受入判定

- requirementと変更箇所・schema・検証証拠の対応を記録し、未確認事項を全件解消またはOwner判断として明示する。
- Phase 0のハッシュ一覧と比較して、既存archiveの変更・削除・移動がないことを確認する。`git status`だけで履歴不変を証明しない。
- canonical正常例、禁止CLI拒否、3次元主α=0.5／感度α=1.0、Pass 0設定例のschema適合を確認する。既存fixtureを上書きせず検証専用出力先を使う。
- `test_vcd_categorical_pass0_boundary.R`、`test_vcd_categorical_input_boundary.R`、`test_three_way_analysis_config_schema.R`、`test_vcd_bayesian_analysis_config_schema.R` がR台帳に含まれるか照合し、未登録分は別途実行する。
- 2次元・3次元HTMLのオフライン検査を検証用生成物で実施する。既存テストで必要な証拠が得られた場合は重複実行不要。
- 旧Scoreの監査専用化が正当な局所モデル比較の否定に拡大していないこと、BICが多重性・実務的重要性を保証すると書かれていないことを数理レビューする。
- エンジン、数値schema、候補判定式に変更がないことを差分で確認する。必要な実装不具合が見つかった場合は文書を追従させず、計画の対象範囲を再評価する。

### 3. 実装者向け完了チェック

- [ ] T01 基準状態とF-01〜F-09の再確認、旧局所指標の定義・実装状態の棚卸し。
- [ ] T02 Owner決定・対象外事項をproposal/design/tasks/delta specへ反映。
- [ ] T03 正本の担当capabilityと派生文書の対応確定。
- [ ] T04 canonical CLI、prior、Pass 0成果物・適用境界の同期。
- [ ] T05 旧Scoreと局所モデル比較の区別、および大標本・BIC説明の訂正。
- [ ] T06 R台帳とPythonゲートの明記、範囲を限定した一貫性検査の追加。
- [ ] T07 Supersession Map作成、既存archiveハッシュ照合。
- [ ] T08 静的・契約・回帰・生成物の検証結果と未確認事項を報告。
- [ ] T09 受入後の正本同期と再検証、残課題の引継ぎ。

---

## 6. 次のアクション

Ownerが了承した方針を反映した改定版として引き渡す。実装者はPhase 0から着手し、上記チェックをChangeのtasksへ展開する。今回の計画改定で局所再適合や局所BFの新規機能を実装する承認が追加されたとは解釈しない。
