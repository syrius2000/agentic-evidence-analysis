## 1. Canonical境界の回帰テスト

- [x] 1.1 有効なPass 0 fixtureを用い、`--data`、`--vars`、`--freq`、`--input-mode` などの解析変更型引数および未知の `--*` 引数が完全ホワイトリスト拒否により `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` で非ゼロ終了するE2Eテストを追加する
- [x] 1.2 禁止上書き・未知引数時に解析署名、`run_<signature>` ディレクトリ、集約データ、結果JSON、Dashboardが一切生成されず、出力rootの失敗記録（`run_state.json`）だけが残ることを検証する
- [x] 1.3 Pass 0 fixtureの実入力を検証後に改ざんし、署名・run予約前に `PROVENANCE_SHA_MISMATCH` で停止するE2Eテストを追加する
- [x] 1.4 署名前早期停止への移行に伴い、`tests/test_vcd_categorical_input_boundary.R`（Test 14/15等）のディレクトリ存在前提アサーションを、ディレクトリ未作成かつ出力root直下の失敗状態検証へ同期・更新する
- [x] 1.6 運用上の信頼済み正本である Pass 0 検分成果物（`inspection_results.json`）内の `approved_config$canonical_config_sha256` と設定ファイルの照合により、設定変更を `PROVENANCE_CONFIG_MISMATCH` で即時遮断するE2Eテストを追加する
- [x] 1.7 同一設定・同一label・同一出力rootの完全並行実行時に、原子的排他ロックにより一方のプロセスが `CONCURRENT_RUN_IN_PROGRESS` で安全に早期停止し、成果物破壊・競合が発生しないE2Eテストを追加する

## 2. Canonical CLI と署名の実装

- [x] 2.1 Canonical CLIの許可引数（`--config`, `--out`, `--label`, `--help`）を単一ホワイトリストとして定義し、それ以外の `--*` 引数を入力処理・署名算出前に即時拒否するゲートウェイを実装する
- [x] 2.2 `analysis.R` を「CLI検証ラッパー」と再検証済み設定を受け取る内部コア関数（`run_categorical_analysis_core`）の2層に分離し、Core 内部での独立した三者 SHA 再検証を実装する
- [x] 2.3 偽造 attestation フラグを付与した未検証 config を Canonical Core に渡した場合でも即座に遮断されるテスト、および `execution_mode: "development"` で成果物ファイルが生成されないテストを追加する
- [x] 2.4 Pass 0 inspection、設定、実入力ファイルの三者SHAを署名・run ID・runディレクトリ作成前に再照合し、不一致時のエラーコードと失敗記録を検証する（`config_file_sha256` と `canonical_config_sha256` を厳密に区別する）
- [x] 2.5 解析署名を再検証済みの `canonical_config_sha256` および成果物名に反映される `data_label` から算出し、署名算出後に解析条件を変更しないことを正常系・失敗系テストで確認する
- [x] 2.6 `finalize_pass0_config.R` および `pass0_contract.R` において `canonical_config_sha256` を算出して `pass0_provenance` に封緘し、Core 内部で実設定パラメータと照合して事後改ざんを遮断する
- [x] 2.7 同一設定で異なる `--label` を指定した場合に、異なる `analysis_signature` が導出され、別々の `run_<signature>` ディレクトリに物理分離されるテストを追加する
- [x] 2.8 `finalize_pass0_config.R` において、`inspection_results.json` に `approved_config$canonical_config_sha256` を追記・保存し、Core 内部で運用上の正本として三者照合する
- [x] 2.9 `analysis.R` において、`run_<signature>/.run_lock` による原子的排他ロック取得・解放機構（`CONCURRENT_RUN_IN_PROGRESS`）を実装する

## 3. 実行記録とテスト経路の分離

- [x] 3.1 `run_state.json` へ実行モード（`execution_mode: "canonical"`）およびPass 0検証結果を記録し、既存のrun isolationテストでrun識別子と成果物整合を確認する（成果物JSONのSerializer拡張はChange 2へのハンドオフとする）
- [x] 3.2 既存テストのCLI呼出しを棚卸しし、解析変更型上書きに依存する呼出しをPass 0 fixtureまたは明示的な内部関数テストへ移し、常設の無検証CLI bypassを追加しないことを確認する
- [x] 3.3 署名算出前の早期失敗時（ゲートウェイ・Pass 0 検証・引数不正など）に、出力 root 直下の `run_state.json` に明示的に `"run_id": null` および `"analysis_signature": null` がシリアライズされる契約を実装・検証する

## 4. 統合検証と引継ぎ

- [x] 4.1 `tests/test_vcd_categorical_pass0_boundary.R`、`tests/test_vcd_categorical_input_boundary.R`、`tests/test_vcd_categorical_run_isolation.R` を個別Rプロセスで実行し、依存関係不足時に自動インストールしないことを確認する
- [x] 4.2 正常Pass 0実行、禁止上書き、未知引数、入力改ざん、設定改ざん、欠損設定、同一署名並行競合の実行証跡を分けて記録し、`git diff --check` と対象外変更の不在を確認する
- [x] 4.3 `vcd-categorical-conditional-posterior-contract` の着手前提として、Canonical CLIホワイトリスト・run state・署名契約が確定したことを引き渡す
