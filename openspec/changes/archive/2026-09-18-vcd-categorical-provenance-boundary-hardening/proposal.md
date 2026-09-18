## 背景

Canonical実行はPass 0 provenanceを検証した後にCLI引数でデータ、変数、頻度列、入力モードを上書きできる構造になっており、署名や成果物が示す入力条件とPass 0で承認・検分された条件が乖離し得る。下流の条件付き事後契約（Change 2）およびScientific Dashboard（Change 3）に先行して、解析の正本入力境界を厳格に封鎖（Hardening）する必要がある。

## 変更内容

- Canonical CLIにおいて完全ホワイトリスト方式を採用し、許可引数（`--config`, `--out`, `--label`, `--help`）以外の解析変更型引数および未知引数をすべて拒否し、`CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` でフェイルファストする。
- Pass 0 provenance、設定、実ファイルの三者入力SHAを解析署名算出・run予約前に再照合し、不一致時は `PROVENANCE_SHA_MISMATCH` で停止する。
- 解析署名は再検証済みのcanonicalized設定値のみから算出し、署名算出後に解析条件を変更しない。
- `analysis.R` を「CLI検証ラッパー」と「再検証済み設定を受け取る内部コア関数」の2層に構造化し、テスト用常設CLI bypassを一切作らずに安全なテスト経路を確立する。
- 署名前の早期停止時は `run_<signature>` ディレクトリを作成せず、指定出力root直下の `run_state.json` へ失敗状態（`run_id: null`, `analysis_signature: null` 等）を記録する。
- 署名前停止の順序変更に伴う既存テスト（`test_vcd_categorical_input_boundary.R` 等）のアサーションを、ディレクトリ未作成検証へ同期する。

## 能力

### 新規能力

なし。

### 変更する能力

- `two-way-evidence-analysis`: Canonical実行のPass 0 input/config境界、解析署名、run stateの要件を、完全ホワイトリスト型CLI拒否、三者実入力SHA再検証、および署名前フェイルファストを含む契約へ強化する。

## 影響範囲

- `.agents/skills/vcd-categorical-analysis/templates/analysis.R`
- `tests/test_vcd_categorical_pass0_boundary.R`
- `tests/test_vcd_categorical_input_boundary.R`（署名前フェイルファストに伴うディレクトリ検証の更新）
- `tests/test_vcd_categorical_run_isolation.R`
- 新規Rパッケージ、事後統計量、Serializer/Schema（Change 2で実施）、Dashboard（Change 3で実施）、実データ、commit、pushは対象外

