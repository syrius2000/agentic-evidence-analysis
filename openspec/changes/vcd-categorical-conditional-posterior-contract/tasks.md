## 0. 改定前の基線確認

- [x] 0.1 現行の `alpha = 1.0`、`is_sensitive`、`sensitivity_analysis`、`serialize_interface_v3()` 呼出しを、templates・root tests・Dashboard Consumer・fixture から inventory 化する
- [x] 0.2 個別 R プロセスで既存対象テストを実行し、実行前からの失敗、Change 1 契約同期不足、今回の主事前変更による期待値更新を区別して記録する
- [x] 0.3 基線失敗を未実行のまま「既存赤状態」と断定しない。実測した失敗だけを Change 内の修正対象として確定する

## 1. Change artifact の整合化

- [x] 1.1 proposal、design、delta spec の Non-Goals を整合させ、「prior の任意選択肢拡張は対象外だが、主・感度 prior の固定した入替は対象」と明記する
- [x] 1.2 serializer は canonical 専用、development はインメモリ専用とする実行モード境界を、design、delta spec、tasks に同一文言で記載する
- [x] 1.3 planning artifact（proposal、design、delta spec）において、主事前変更を「スキーマ加法的互換・統計的意味論は非後方互換」と明記し、成果物比較禁止境界の方針を記述する
- [x] 1.4 Jeffreys 事前の理論記述から、唯一最適性、全 estimand への優越性、安全性評価での一般的バイアス改善の断定を除く
- [x] 1.5 `practical_delta` の有効範囲、不正値の fail-fast、未指定時の null を Requirement と Scenario に追加する

## 2. 数理エンジンの契約実装

- [ ] 2.1 canonical と development の両方の主解析呼出しを `alpha = 0.5` へ移行し、感度分析を `alpha = 1.0` に固定する（受入条件: 既存の canonical-signature Requirement に従い、Pass 0 承認ハッシュと canonical config hash を `alpha = 0.5` で再生成・照合すること）
- [ ] 2.2 `prior_specification` に family、alpha、role、name を追加し、主解析を成果物単体で識別可能にする
- [ ] 2.3 条件付き確率の両方向について、丸め前 draw から mean、sd、median、q025、q975、ETI幅を生成する
- [ ] 2.4 各 draw の条件付き確率和、丸め前条件付き平均和、確率範囲、分位点順序、ETI幅を engine で検証する。中央値・分位点の総和は検証しない
- [ ] 2.5 `practical_delta` の入力値を検証し、有効値でのみ絶対結合確率乖離の閾値超過確率を計算する
- [ ] 2.6 感度比較を primary = 0.5、sensitivity = 1.0 で計算し、`eti_width_difference = sensitivity - primary` を符号付きで出力する
- [ ] 2.7 `is_sensitive` と固定 `0.05` 警告判定を削除し、数値的な差分要約のみを残す

## 3. serializer・Schema・Consumer 契約

- [ ] 3.1 `serialize_interface_v3()` を canonical 専用として明示し、development からの呼出しを禁止するとともに、`analysis_signature`、`input_sha256`、`config_sha256` の 64 桁 SHA 検証（欠損およびフォールバック代替生成の禁止）を実装する
- [ ] 3.2 provenance に `execution_mode = "canonical"` を記録し、serializer 不変量で canonical を検証する
- [ ] 3.3 JSON Schema に条件付き完全要約、`prior_specification` の識別情報、局所乖離、`prob_practical_delta` の null 表現、感度比較を定義する
- [ ] 3.4 結合確率と条件付き平均の丸め後総和を、セル数・水準数に応じた `1e-6` 許容差で serializer にて検証する
- [ ] 3.5 6桁／4桁の丸め契約を JSON、CSV、reference、fixture に同一に適用する
- [ ] 3.6 不確実性ランキングの `prob_eti_width` 降順、`observed` 昇順、row_level 昇順、col_level 昇順を実装・検証する
- [ ] 3.7 `.agents/skills/vcd-categorical-analysis/references/interface.md` を更新し、条件付き確率の完全な要約統計量、桁数規則、`prior_specification`、および異なる主事前成果物の直接比較禁止境界を文書化する
- [ ] 3.8 Dashboard Consumer 契約を更新し、prior 種別と alpha を表示して異なる主事前の成果物を直接比較しない契約を反映する（レイアウト変更は Change 3 に分離）

## 4. テストと性能境界

- [ ] 4.1 固定 seed の小規模表で、Jeffreys 主解析の解析的平均、条件付き要約、ETI順序、丸め前総和を検証する
- [ ] 4.2 疎セル表で、`alpha = 0.5` と `alpha = 1.0` の平滑化量の差を検証する。ただし、一般的なバイアス改善の証明とは扱わない
- [ ] 4.3 `practical_delta` の未指定、有効値、0、負値、1以上、非数値、非有限値を入力境界テストに追加する
- [ ] 4.4 serializer の丸め後総和、識別キー、run_id、analysis_signature、input_sha256、config_sha256（64桁SHA形式・非空）、canonical execution_mode の違反が `SCHEMA_INVARIANT_VIOLATION` で停止することを確認し、Pass 0 承認 `canonical_config_sha256` と最終成果物 `provenance.config_sha256` の完全一致を E2E テストで検証する
- [ ] 4.5 `is_sensitive` と固定閾値警告が JSON、CSV、警告配列、Schema、reader に残らないことを検証する
- [ ] 4.6 root tests、module tests、input-boundary tests、Dashboard Consumer tests、fixture を全て `alpha = 0.5` 主解析契約に同期する
- [ ] 4.7 代表的な小規模・中規模表で計算が完了することを確認し、観測した実行時間とメモリ上の注意を検証記録に残す（新規の実行時上限や fail-fast 機構の導入は本 Change 対象外とする）
- [ ] 4.8 旧 `alpha = 1.0` で封緘された config / inspection を渡した場合に canonical 実行が `PROVENANCE_CONFIG_MISMATCH` で確実に停止し、`alpha = 0.5` で再確定した成果物では正常通過することを回帰テストで検証する

## 5. 受入判定と引継ぎ

- [ ] 5.1 Schema validation、固定 seed 再現性、丸め規則、JSON/CSV 一貫性、`git diff --check` を独立に記録する
- [ ] 5.2 既存 `alpha = 1.0` 成果物との数値差を prior 変更由来として整理し、予期しない回帰と区別する
- [ ] 5.3 Dashboard Change に渡すフィールド名、型、null、丸め、主事前識別子、比較禁止境界を引継ぎ記録に残す
- [ ] 5.4 実装、独立 QA、Owner 判断、commit、push、archive を別々の証拠状態として報告する
