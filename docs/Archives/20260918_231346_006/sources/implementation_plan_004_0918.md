# vcd-categorical-analysis v4.2 の Provenance 境界と科学的Dashboardを段階実装する計画

created: 2026-09-18 07:07 (JST)
update: 2026-09-18 18:10 (JST)
author: Codex (GPT-5)

## 1. 目的と承認境界

`vcd-categorical-analysis` において、Pass 0 で確定した解析条件を迂回できるCLI上書きを封鎖し、二元分割表の局所診断・条件付き事後分布・不確実性・事前感度を、相互に意味を混同しないDashboardとして完成させる。
あわせて、多項分布のパラメータ変換不変性（Invariance under reparameterization）を備えた多項 Jeffreys 事前分布（$\alpha = 0.5$）を主解析事前として採用し、従来の Bayes-Laplace 一様事前分布（$\alpha = 1.0$）を対照感度分析として再構成する。この主事前変更はスキーマ上は加法的互換であるが、事後推定値の数値的意味を変える「統計的意味論における非後方互換な変更」である。

本計画は、既存の[v4.2 計画](Implementation-plan-vcd-categorical-analysis-v4.2.md)を、現行コードとテストの実態に合わせて実装順序・契約・検証ゲートへ具体化するものである。

この文書の作成は実装承認ではない。コード、依存関係、データ、生成物、OpenSpec change、commit、push、削除およびアーカイブは変更しない。Phase 1以降は、本計画の明示的な承認後にのみ着手する。

## 2. 現状の確認結果

確認時点の対象は `.agents/skills/vcd-categorical-analysis/` である。

- `templates/analysis.R` はPass 0 provenance検証後に `--data`、`--vars`、`--freq`、`--input-mode` を解析条件へ上書きできる。その後で入力SHAと解析署名を作るため、Pass 0の承認条件と実解析条件が乖離し得る。
- `R/dirichlet_posterior.R` は現在、一様事前分布（$\alpha = 1.0$）を主解析、$\alpha = 0.5$ を感度分析としているが、これを主解析 $\alpha = 0.5$（Jeffreys）、感度分析 $\alpha = 1.0$（一様事前）へ入れ替える必要がある。また、結合確率の事後要約、独立性からの対数乖離を算出しているが、`P(B|A)` と `P(A|B)` は平均・標準偏差のみであり、中央値、95% ETI、ETI幅を出力していない。
- `R/serializer_v3.R` は結合確率の事後平均の総和、結合確率ETIの順序、成果物間の署名・run ID・セル集合を検証する。条件付き確率および感度比較の不変量は未検証である。また、`config_sha256` について 64 桁 SHA 検証とフォールバック自動生成の禁止を徹底し、Canonical Core からの伝播を保証する。
- `templates/dashboard.Rmd` は自己完結HTMLを指定し、既存の残差・セル表・周辺事後表示を持つが、v4.2で定義した5視座を分離した完成形には至っていない。
- root tests にはPass 0境界、入力境界、Dirichlet、Interface、Dashboardを対象とするテストが存在する。既存の検証を置換せず、契約を追加する。また主事前の $\alpha=0.5$ 移行に伴う期待値更新が必要となる。
- OpenSpec change `vcd-categorical-conditional-posterior-contract` が planning artifacts 完了（4/4）の状態で準備されている。

## 3. 実装方針と固定する判断

### 3.1 実装順序

以下の依存順序を守る。

```text
契約固定
  -> Provenance境界
  -> 条件付き事後エンジン（Jeffreys 主解析 alpha=0.5）
  -> Serializerとスキーマ（Canonical Core からの config_sha256 伝播保証）
  -> Dashboard
  -> 統合検証と独立QA
```

Dashboardを先に実装しない。可視化は確定した入力provenanceと機械可読な統計契約にのみ依存させる。

### 3.2 Canonical実行とテスト実行

通常のCLIはCanonical専任とする。Canonicalで許可する引数は出力先や表示ラベルなど、解析内容を変えないものに限る。

- 許可候補: `--config`、`--out`、`--label`
- 禁止候補: `--data`、`--vars`、`--freq`、`--input-mode`、`--practical-delta`、`--prior-alpha`
- 禁止引数をCanonical実行で検出したときは、解析・出力ディレクトリ作成・集約処理の前に `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` で停止する。
- 実解析直前に入力ファイルSHAを再計算し、Pass 0 provenance、設定ファイル、実ファイルの三者一致を `PROVENANCE_SHA_MISMATCH` として検証する。

テストの簡便さを理由に、通常CLIへ永続的な無検証上書きフラグは追加しない。テストはPass 0 fixtureを使用するか、解析済みの設定値を受け取る内部関数を直接呼ぶ。内部関数を設ける場合も、Canonical CLI経路とは別責務とし、実行メタデータをCanonical成果物として偽装しない。

### 3.3 条件付き事後分布の不変量

各Monte Carlo draw `s` に対し、分母が正であることを確認して次を計算する。

\[
P(B=j\mid A=i)^{(s)}=\frac{\pi_{ij}^{(s)}}{\pi_{i+}^{(s)}},\qquad
P(A=i\mid B=j)^{(s)}=\frac{\pi_{ij}^{(s)}}{\pi_{+j}^{(s)}}
\]

検証対象は次に限定する。

- 各drawの行条件付き確率・列条件付き確率の総和は、浮動小数点誤差の範囲で1である。
- 各条件付き事後平均の総和は、丸め前の値で1である（許容差 $10^{-12}$）。
- `0 <= probability <= 1`、`q025 <= median <= q975`、`eti_width = q975 - q025 >= 0` を満たす。
- 条件付き事後中央値と分位点の横和・縦和を1へ強制しない。非線形な要約であり、一般に総和保存しないためである。

### 3.4 Interfaceと表示責務

Interface 3.0を原則維持し、追加フィールドで表現できる場合は破壊的変更を行わない。JSON Schema、R serializer、CSV出力、Dashboard読込側を同じ変更単位で更新する。

Dashboardでは、同じセルが強調されても次の問いを混同させない。

| 視座 | 答える問い | 主指標 |
| --- | --- | --- |
| Effect × Evidence | 実務上の差と統計的証拠はどこにあるか | log(O/E)、Rao score、Dual-Filter |
| Adjusted Residual | 独立モデルから局所的にどこが逸脱するか | adjusted residual |
| Conditional Posterior | 一方のカテゴリを所与にした他方の予測確率は何か | 条件付き平均・中央値・95% ETI |
| Uncertainty Ranking | どの推定が最も広い不確実性を持つか | ETI幅 |
| Posterior Departure | 独立性からのベイズ的乖離はどの方向・程度か | log departure と95% ETI |
| Prior Sensitivity | 結論は主解析（alpha=0.5）と感度分析（alpha=1.0）でどの程度変わるか | 中央値差・ETI幅差（符号付き: 感度側幅 - 主側幅） |

各新規セクションの先頭に、その図が答える統計的・科学的な問い、解釈上の非同一性、閾値による自動意思決定をしない旨を日本語で表示する。

### 3.5 主解析事前分布の変更（alpha=0.5）と境界管理

本改修では、多項分布におけるパラメータ変換不変性を根拠として、主解析事前分布を多項 Jeffreys（$\alpha = 0.5$）、対照感度分析を一様事前（$\alpha = 1.0$）とする。本変更に伴い、以下の境界管理を厳格に適用する：

1. **主解析 prior の変更判断**:
   - 疎セルに対する仮想度数の影響を一様事前より抑え、再パラメータ化不変性を備えた多項 Jeffreys 事前（$\alpha = 0.5$）を主解析に採用する。
   - 感度分析は、対照として一様事前（$\alpha = 1.0$）との比較を行い、数値的シフト量（中央値差、符号付き ETI 幅差）を出力する。
2. **既存成果物との直接比較禁止境界**:
   - 事前分布が異なる過去の成果物（$\alpha = 1.0$ 主解析）と本改修後の成果物（$\alpha = 0.5$ 主解析）は、推定量としての意味論が異なる。
   - したがって、これら異なる主事前の成果物同士を同一推定量として直接比較・突合することを禁止し、Interface reference および Dashboard Consumer 契約に明記する。
3. **変更前成果物を再現・識別する方法（自己記述的メタデータ）**:
   - 成果物 JSON の `posterior.prior_specification` に `{ "family": "symmetric_dirichlet", "alpha": 0.5, "role": "primary", "name": "jeffreys" }` を記録し、成果物単体で主事前の定義を明示可能とする。
   - 旧成果物との混同を防ぎ、再現性を自己記述的に担保する。
4. **Pass 0 設定と `canonical_config_sha256` の再封緘方針**:
   - 正本仕様（canonical signature / `canonical_config_sha256` に事前分布パラメータを含める）に従い、canonical 実行時およびテストにおいて $\alpha = 0.5$ を一貫して渡してダイジェストを算出・照合する。
   - 旧 $\alpha = 1.0$ で封緘された設定ファイルは `PROVENANCE_CONFIG_MISMATCH` で確実に拒否され、$\alpha = 0.5$ で再確定された Pass 0 成果物のみが canonical 実行を通過する境界を維持する。
5. **既存 fixture・テスト期待値の移行方針**:
   - 既存テストの期待値は $\alpha = 1.0$ 前提となっているため、改定前の基線確認（Task 0）で実測確認を行った上で、$\alpha = 0.5$ 基準の期待値へ計画的に移行する。

### 3.6 `config_sha256` と `canonical_config_sha256` の伝播・検証責務

- **Canonical Core**: Pass 0 provenance、設定ファイル、実ファイルの三者照合を行い、再検証済み `canonical_config_sha256` を算出・確定する。
- **Serializer**: Canonical Core から渡された `canonical_config_sha256` について、64桁の有効なSHA-256文字列であること、非空であること（フォールバック自動生成の禁止）を検証し、出力JSONの `provenance.config_sha256` にそのまま記録する。Serializer 内部での自己比較引数は増設しない。
- **E2E / 回帰テスト**: Pass 0 で承認された `canonical_config_sha256` と、最終生成 JSON の `provenance.config_sha256` が完全一致することをエンドツーエンドで検証する。

## 4. 変更範囲

### 変更対象候補

- `.agents/skills/vcd-categorical-analysis/templates/analysis.R`
- `.agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R`
- `.agents/skills/vcd-categorical-analysis/R/serializer_v3.R`
- `.agents/skills/vcd-categorical-analysis/schemas/categorical_results_v3.json`
- `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`
- `.agents/skills/vcd-categorical-analysis/SKILL.md` および必要最小限の同Skill内reference
- `tests/test_vcd_categorical_pass0_boundary.R`
- `tests/test_vcd_categorical_input_boundary.R`
- `tests/test_vcd_categorical_dirichlet_v4.R`
- `tests/test_vcd_categorical_interface_v3.R`
- `tests/test_vcd_categorical_dashboard_v4.R`
- 新規の対象限定root testまたはfixture
- 承認後に作成するOpenSpec changeのproposal、design、spec、tasks

### 対象外

- 3次元以上の分析機能
- 新規の効果量・仮説検定・機械的な重要性閾値
- Shiny化、JavaScript frontend化、Dashboard frameworkの全面変更
- Rパッケージの実行時インストールまたは新規依存関係の追加
- `.cursor/skills` の作成・復元
- 実データ、公開成果物、既存履歴資料の変更
- commit、push、ブランチ操作、削除、アーカイブ

## 5. 実装フェーズ

### Phase 0: OpenSpecと受入契約の確定

承認後、`vcd-categorical-analysis-v4-2-dashboard-contract-hardening` を候補名としてOpenSpec changeを作成する。名称は既存changeとの衝突を確認して最終決定する。

作成物には、以下を明文化する。

1. Canonicalとテスト経路の責務分離、許可・禁止引数、エラーコード、SHA再検証時点。
2. 条件付き事後統計量、丸め時点、数値許容差、中央値を総和検証から除外する理由。
3. JSON Schemaの追加フィールド、null許容、後方互換性、CSV列の扱い。
4. 11セクションのDashboard構成、各セクションの問い、カテゴリ多数時の表示方針。
5. オフラインHTML、外部URL、絶対パス、既存fixtureの扱い。

完了条件は、OpenSpecの各artifactと本計画の間に矛盾がなく、対象ファイル・非目標・受入条件がレビュー可能であることとする。

### Phase 1: Provenance境界の実装

`analysis.R` を変更し、Pass 0設定を唯一の解析条件として解決する。

1. argument parserで解析変更型引数を検出し、Canonical経路では即時に拒否する。
2. Pass 0 provenance検証の結果、設定値、実ファイルSHAの一致を解析署名作成前に確認する。
3. 解析署名へ実際に使うcanonicalized値だけを入れる。署名算出後の解析条件変更を禁止する。
4. `run_state.json` へ実行モードと検証済みprovenanceを記録する。非Canonicalのテスト経路を実装する場合は、Canonical run_id・成果物との混同を防ぐ。
5. 既存の正常なPass 0 fixture実行、禁止上書き、SHA不一致、欠損設定をテストする。

完了条件は、未承認の入力・変数・集約方式へCLIで差し替えられず、失敗時に解析成果物を正常状態として残さないこととする。

### Phase 2: 条件付き事後エンジンの拡張

`dirichlet_posterior.R` に、丸め前drawに基づく条件付き事後要約を追加し、主解析 prior を更新する。

1. 主解析事前分布を多項 Jeffreys（$\alpha = 0.5$）へ移行し、対照感度分析を一様事前（$\alpha = 1.0$）として再構成する。
2. `P(B|A)` と `P(A|B)` のそれぞれへ平均、標準偏差、中央値、q025、q975、ETI幅を追加する。
3. 行・列周辺が数値的に0となる場合の扱いを明示し、有限値でない結果を黙ってJSONへ流さない。
4. draw単位の総和、平均の総和、確率範囲、分位点順序、ETI幅の不変量を検証する。
5. 結合確率、局所対数乖離、事前感度比較（符号付き `eti_width_difference = sensitivity - primary`）を算出し、`is_sensitive` 二値判定および固定0.05警告を廃止する。

完了条件は、固定seedの小規模・疎な表で再現可能に計算され、中央値の総和を誤って1と要求しないテストが存在することとする。

### Phase 3: Serializer・Schema・表形式出力の整合

Phase 2の結果を機械可読な契約として固定する。

1. 既存の`posterior`構造へ条件付き要約を加える位置を決め、row/column水準との対応を一意にする。
2. `posterior.prior_specification`（family, alpha=0.5, role="primary", name="jeffreys"）を記録し、自己記述性を担保する。
3. JSON Schema、serializer、必要なCSVエクスポートを同時に更新する。
4. serializer は canonical 実行専用とし、結合確率、条件付き平均、分位点、ETI幅、セルキー、感度比較のcross-field不変量を検証する。また Core から渡された `canonical_config_sha256` の64桁SHA形式・非空を検証して `provenance.config_sha256` に格納し、Pass 0承認ハッシュとの一致はE2Eテストで検証する。
5. 丸めは検証後の出力境界でのみ行い、許容差は仕様とテストで同一にする（丸め後許容差: 水準数 $\times 10^{-6}$）。
6. additive extensionで対応不能な場合だけ、破壊的変更理由と移行方針を計画更新・再承認対象として扱う。

完了条件は、Rオブジェクト、JSON、CSV、Schema検証、既存Interface 3.0利用者の期待が一貫することとする。

### Phase 4: Dashboardの段階実装

Dashboardをデータ契約確定後に以下の順で追加する。各段階で既存セクションの回帰を確認する。

1. Quality & Provenanceを補強し、実行モード、入力SHA、設定SHA、署名、seed、draw数、隔離セル数を明示する。
2. Adjusted Residual Heatmapを追加する。色の中心を0とし、正負、隔離セル、数値確認手段を明示する。
3. Conditional Posteriorを追加する。`P(B|A)` と `P(A|B)` を別表示とし、中央値と95% ETIを主表示、平均を補助表示とする。
4. Uncertainty Rankingを追加する。ETI幅を「重要性」や「有意性」と読ませない説明を付す。
5. Posterior Departureを追加する。0を独立性の参照線とし、ETIのみで自動二値判定しない。
6. Prior Sensitivityを追加する。主解析（$\alpha=0.5$）と感度分析（$\alpha=1.0$）の中央値差・ETI幅差（符号付き）を提示し、疎セルでの事前依存を客観的数値で説明する。異なる主事前の過去成果物との直接比較禁止を明記する。
7. 表の大きさに応じた表示を実装する。小規模表は全セル、中規模表はフィルタ可能な全件表、大規模表は決定論的Top-Nと全件表・CSVへの導線を併用する。切替閾値とTop-N選定規則を仕様化する。

Dashboardは自己完結HTMLを維持する。外部CDN、外部日本語辞書、外部数式リソース、絶対ローカルパスを残さず、必要なフォールバックを日本語で表示する。

完了条件は、11セクションそれぞれが固有の問い・指標・解釈限界を持ち、統計量の意味がセクション間で混同されないこととする。

### Phase 5: 統合検証と独立QA

実装者による成功報告と独立QAを分ける。

1. 対象Rテストを、キャッシュやネットワーク依存を避けた個別プロセスで実行する。
2. 既存fixtureと新規fixtureで、Canonical正常系、禁止上書き、SHA不一致、条件付き事後、schema、Dashboardを検証する。
3. 生成HTMLを静的走査し、`http://`、`https://`、必要に応じて`//`、`/Users/`、`/home/`、`/private/var/`、Windowsドライブ形式を検出しないことを確認する。
4. ネットワーク遮断相当のブラウザ確認を行い、主要表・図・数式フォールバック・日本語表示・大規模表フォールバックを確認する。
5. 独立QAでは、OpenSpecのallowed targets、実差分、テスト証跡、生成物、統計的不変量を突合する。

完了条件は、構文検証、静的テスト、実行証跡、独立QA、Owner判断を別々に報告できることとする。`openspec validate --strict` の成功だけでは実装完了としない。

## 6. 検証マトリクス

| 層 | 主な確認 | 最低限の対象 |
| --- | --- | --- |
| CLI境界 | Canonical拒否、SHA一致、不正設定停止 | `tests/test_vcd_categorical_pass0_boundary.R`、`tests/test_vcd_categorical_input_boundary.R` |
| 数理 | draw総和、平均総和、分位点順序、ETI幅、seed再現性 | `tests/test_vcd_categorical_dirichlet_v4.R`、追加テスト |
| Interface | JSON Schema、セルキー、cross-field不変量、後方互換 | `tests/test_vcd_categorical_interface_v3.R` |
| Dashboard | セクション、問い、読込、表示、既存回帰 | `tests/test_vcd_categorical_dashboard_v4.R`、既存Dashboard関連テスト |
| 実行隔離 | Run ID、出力分離、失敗時状態 | `tests/test_vcd_categorical_run_isolation.R` |
| HTML受入 | オフライン性、外部参照・絶対パス不在、ブラウザ表示 | 新規または既存の対象限定検証 |
| 差分衛生 | 空白エラー、対象外変更、既存差分保持 | `git diff --check`、`git diff --name-status` |

Rテストは、依存関係不足時に自動インストールせずfail-fastする。全テストを無差別に実行する前に対象テストから開始し、失敗が環境要因・既存失敗・本変更の回帰のいずれかを切り分ける。

## 7. リスクと対策

| リスク | 影響 | 対策 |
| --- | --- | --- |
| CLI上書き封鎖で既存テストや利用手順が停止する | 高 | 既存呼出しを棚卸しし、Pass 0 fixtureまたは内部関数へ明示的に移行する。暗黙fallbackを作らない。 |
| 条件付き中央値に総和1を要求する | 高 | drawと平均だけを総和不変量とし、中央値・分位点のテストは順序と範囲に限定する。 |
| 丸めで不変量が偽陽性となる | 中 | 丸め前で検証し、出力後の表示値は表示専用とする。 |
| JSON追加で既存readerが壊れる | 高 | Schema、serializer、Dashboard、fixtureを同時変更し、additive extensionを優先する。 |
| Dashboardが情報過多となる | 中 | 各視座の問いを明示し、Top-Nと全件アクセスを併用する。 |
| 自己完結HTMLに外部参照が残る | 中 | 静的走査とネットワーク遮断相当のブラウザ検証を両方行う。 |
| 既存の利用者差分を巻き込む | 高 | 各編集ラウンドの開始・終了でGit差分を確認し、対象ファイルのみを変更する。 |

## 8. ロールバックと変更管理

- 実装開始前の既存差分を記録し、Codexが追加した差分と区別する。
- 各Phaseの終了時に、対象ファイル、テスト結果、未解決事項、次Phaseへ持ち越す境界を固定する。
- 不具合時の復元対象は当該PhaseでCodexが追加した行に限定する。ユーザー既存差分、未追跡ファイル、無関係な変更は復元しない。
- Schemaの破壊的変更、依存関係追加、対象外への拡張、実データ・外部システムへの書込みが必要になった場合は、計画を更新して再承認を得る。
- 実装完了後もcommit、push、OpenSpec archive、ブランチ削除は別途の明示指示を要する。

## 9. 実行開始の判断点

本計画の次の操作はPhase 0またはPhase 1の開始であり、コード・OpenSpec artifactを変更する。実装に着手するには、ユーザーが本計画を明示的に承認する必要がある。

承認後の最初の作業は、Git状態を再確認し、OpenSpec changeの有無と命名衝突を確認したうえで、Phase 0の受入契約を作成することである。Phase 1以降は、各Phaseの検証結果と差分境界を報告してから次へ進む。
