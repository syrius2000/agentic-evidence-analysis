## 1. Canonical境界の回帰テスト

- [ ] 1.1 有効なPass 0 fixtureを用い、`--data`、`--vars`、`--freq`、`--input-mode` などの解析変更型引数および未知の `--*` 引数が完全ホワイトリスト拒否により `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` で非ゼロ終了するE2Eテストを追加する
- [ ] 1.2 禁止上書き・未知引数時に解析署名、`run_<signature>` ディレクトリ、集約データ、結果JSON、Dashboardが一切生成されず、出力rootの失敗記録（`run_state.json`）だけが残ることを検証する
- [ ] 1.3 Pass 0 fixtureの実入力を検証後に改ざんし、署名・run予約前に `PROVENANCE_SHA_MISMATCH` で停止するE2Eテストを追加する
- [ ] 1.4 署名前早期停止への移行に伴い、`tests/test_vcd_categorical_input_boundary.R`（Test 14/15等）のディレクトリ存在前提アサーションを、ディレクトリ未作成かつ出力root直下の失敗状態検証へ同期・更新する

## 2. Canonical CLI と署名の実装

- [ ] 2.1 Canonical CLIの許可引数（`--config`, `--out`, `--label`, `--help`）を単一ホワイトリストとして定義し、それ以外の `--*` 引数を入力処理・署名算出前に即時拒否するゲートウェイを実装する
- [ ] 2.2 `analysis.R` を「CLI検証ラッパー」と再検証済み設定を受け取る内部コア関数（`run_categorical_analysis_core`）の2層に分離し、Core 内部での独立した三者 SHA 再検証を実装する
- [ ] 2.3 偽造 attestation フラグを付与した未検証 config を Canonical Core に渡した場合でも即座に遮断されるテスト、および `execution_mode: "development"` で成果物ファイルが生成されないテストを追加する
- [ ] 2.4 Pass 0 inspection、設定、実入力ファイルの三者SHAを署名・run ID・runディレクトリ作成前に再照合し、不一致時のエラーコードと失敗記録を検証する（`config_file_sha256` と `canonical_config_sha256` を厳密に区別する）
- [ ] 2.5 解析署名を再検証済みの `canonical_config_sha256` から算出し、署名算出後に解析条件を変更しないことを正常系・失敗系テストで確認する



## 3. 実行記録とテスト経路の分離

- [ ] 3.1 `run_state.json` へ実行モード（`execution_mode: "canonical"`）およびPass 0検証結果を記録し、既存のrun isolationテストでrun識別子と成果物整合を確認する（成果物JSONのSerializer拡張はChange 2へのハンドオフとする）
- [ ] 3.2 既存テストのCLI呼出しを棚卸しし、解析変更型上書きに依存する呼出しをPass 0 fixtureまたは明示的な内部関数テストへ移し、常設の無検証CLI bypassを追加しないことを確認する

## 4. 統合検証と引継ぎ

- [ ] 4.1 `tests/test_vcd_categorical_pass0_boundary.R`、`tests/test_vcd_categorical_input_boundary.R`、`tests/test_vcd_categorical_run_isolation.R` を個別Rプロセスで実行し、依存関係不足時に自動インストールしないことを確認する
- [ ] 4.2 正常Pass 0実行、禁止上書き、未知引数、入力改ざん、欠損設定の実行証跡を分けて記録し、`git diff --check` と対象外変更の不在を確認する
- [ ] 4.3 `vcd-categorical-conditional-posterior-contract` の着手前提として、Canonical CLIホワイトリスト・run state・署名契約が確定したことを引き渡す

