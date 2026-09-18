## Context

提案の背景は[proposal.md](proposal.md)を参照する。現行のCLIはPass 0検証結果から設定を読んだ後、解析条件を変更できるCLI値を代入し、その変更後の値で入力SHAと署名を作る。これは署名の内部一貫性を保っていても、Pass 0で検分した入力との連続性を保証しない。

## Goals / Non-Goals

**Goals:**

- Canonical CLIの入力・設定をPass 0確定値だけへ固定する。
- 解析署名前に実ファイルSHAを再検証し、失敗を監査可能に記録する。
- テスト可能な内部経路を持ちながら、通常CLIに無検証bypassを残さない。

**Non-Goals:**

- Pass 0の入力検分UI・設定ファイル形式の全面改訂。
- 条件付き事後、Serializer/Schema、Dashboard、依存関係の変更。
- 実行済みrunの上書き、既存成果物の再生成、データ変更。

## Decisions

### Canonical CLIは完全ホワイトリスト方式で引数を検証する

`--config`、`--out`、`--label`、`--help` だけを通常CLIで許容し、解析変更型引数（`--data`, `--vars`, `--freq`, `--input-mode`, `--prior-alpha`, `--practical-delta` 等）および未知の `--*` オプションが1つでも渡された場合は、即座に `CANONICAL_CONFIG_OVERRIDE_FORBIDDEN` としてフェイルファストさせる。ブラックリスト方式ではなく完全ホワイトリスト方式を採用することで、タイポや未知引数によるサイレント・フォールバックを排除する。

### SHA再検証・入力検証は署名・run予約の前に行う

設定、Pass 0 inspection、実入力の三者SHA一致、および `input_mode` 等の基本設定整合性を、解析署名、run ID、`run_<signature>` ディレクトリ作成、集約処理の前に確認する。

SHAの概念および検証責務を以下のように明確に分離する：

- `config_file_sha256`: ディスク上の `analysis_config.json` ファイル自体の生ハッシュ（監査ログ用）。
- `canonical_config_sha256`: 解析パラメータ（engine, input_sha, vars, freq, input_mode, prior_alpha, practical_delta 等）を正規化したオブジェクトのダイジェスト（決定論的 `analysis_signature` 算出用）。Pass 0 確定成果物である `inspection_results.json` を運用上の信頼済み正本とみなし、その `approved_config$canonical_config_sha256` に承認ダイジェストを記録する。同時に `analysis_config.json` の `pass0_provenance$canonical_config_sha256` にも記録する。Canonical Core 内部で「実パラメータの再計算ハッシュ」「設定ファイル内の記録値」「運用上の正本である Pass 0 検分成果物内の承認値」の三者一致を検証することで、設定ファイル単体の書き換えや設定不一致を遮断する（不一致時は `PROVENANCE_CONFIG_MISMATCH`）。
- `input_sha256`: 実入力CSVファイルの生ハッシュ。

失敗時は `run_<signature>` ディレクトリを一切作成せず、指定出力root直下の `run_state.json` に「直近のゲートウェイ試行ステータス（latest attempt）」として atomic に書き出し（`run_id: null`, `analysis_signature: null`, `phase: "gateway"`, `status: "failed"` を明示的 null シリアライズ）、標準エラー出力にも明確なエラーコードを出力して非ゼロ終了する。

### `--label` の署名算入による物理分離

`--label` は成果物ファイル名（`mosaic_<label>.png`, `gt_residuals_<label>.html` 等）に影響を与えるため、解析署名 `analysis_signature` の算出ペイロードに `data_label` を必須要素として含める。これにより、同一データ・同一解析設定であっても label が異なる場合は決定論的に異なる署名・別ディレクトリ（`run_<signature>`）に分離され、成果物の混在や上書き競合を回避する。

### 同一署名・同一出力 root の原子的排他ロックと stale lock 復旧

同一データ・同一設定・同一 label が同一出力 root に対して同時に実行された場合の競合・成果物破損を防ぐため、`run_<signature>` ディレクトリ内に原子的排他ロック機構（`.run_lock`）を導入する（`dir.create` によるアトミック生成）。
先行プロセスが実行中の場合、後続プロセスは `CONCURRENT_RUN_IN_PROGRESS` として早期遮断され、出力 root 直下に競合失敗状態を記録して非ゼロ終了する。先行プロセスの完了または異常終了時には `base::on.exit()` によりロックが解除される。

#### Stale Lock（残存ロック）の手動復旧手順
プロセスの急激な強制終了（SIGKILL や電源遮断など）により `on.exit()` が走行せず、`.run_lock` ディレクトリがディスク上に残存して後続実行が `CONCURRENT_RUN_IN_PROGRESS` で恒常的にブロックされる場合がある。その際の手動復旧手順は以下の通り：

1. 実行中の R プロセスが存在しないことを確認する（例: `pgrep -fl "analysis.R"`）。
2. 対象出力ディレクトリ内の残存ロックディレクトリを確認・削除する：
   ```bash
   # 残存ロックの確認
   ls -ld <out_dir>/run_<signature>/.run_lock
   # 手動削除によるロック解除
   rm -rf <out_dir>/run_<signature>/.run_lock
   ```
3. ロック解除後、再度 Canonical 解析コマンドを実行する。


### 内部アーキテクチャ seam（2層分離）と Core の独立検証境界

`templates/analysis.R` を以下の2層に構造化する：

1. `run_analysis(args_vec)`: CLI 引数のホワイトリスト検査、Pass 0 由来検証、設定 canonicalize を担当する CLI ゲートウェイ層。
2. `run_categorical_analysis_core(config_data, out_root, data_label, execution_mode = "canonical")`: コア関数。
   - `execution_mode == "canonical"` の場合：Core は呼び出し元から渡されたフラグのみに依存せず、Core 内部でも必ず三者 SHA（Pass 0 inspection、設定、実入力ファイル）および `canonical_config_sha256` の再検証を実施する。未検証設定、改ざん設定、またはフラグを偽装した設定が渡された場合は `PROVENANCE_SHA_MISMATCH`、`PROVENANCE_CONFIG_MISMATCH`、または `CANONICAL_CONFIG_VERIFICATION_REQUIRED` で即時停止する。
   - `execution_mode == "development"` の場合：内部モジュール試験・アルゴリズム検証専用とし、ディスク上に本番成果物（`categorical_results.json`、`evidence_profile.json`、Dashboard HTML）および `run_<signature>` ディレクトリを一切生成しない。インメモリの計算結果リストのみを返し、本番 Canonical 成果物との混同や誤認を防止する。

### 既存テスト（test_vcd_categorical_input_boundary.R 等）のアサーション同期

署名算出前の早期停止に伴い、不正入力時に `run_<signature>` ディレクトリが作成されなくなるため、既存テスト（Test 14/15）で `run_*` ディレクトリの存在を前提としていたアサーションを、出力root直下の `run_state.json` のみを検証する形へ同期・更新する。また、早期失敗時の `run_state.json` において `run_id: null` および `analysis_signature: null` が正しく記録されていることをアサートする。

## Risks / Trade-offs

- [既存CLIテストが上書き引数に依存] → 呼出しを棚卸しし、Pass 0 fixtureまたは内部関数へ移す。
- [既存テストのディレクトリ存在前提] → 署名前フェイルファスト仕様に合わせてテストアサーションを明示的に更新する。
- [失敗記録が残らず原因を追跡できない] → 出力root直下に限定した失敗状態を残し、標準エラー出力にも機械可読エラーを出力する。
- [SHA再計算のI/Oコスト] → 一度のファイルハッシュ計算に限定し、解析前の安全境界として受容する。
- [将来の正規CLI引数追加] → ホワイトリスト定数を1箇所で管理し、仕様・テストと同期して拡張する。

## Migration Plan

1. 禁止上書き、未知引数、改ざん入力、欠損設定のE2E失敗テストを追加する。
2. 既存テスト `test_vcd_categorical_input_boundary.R` のディレクトリ存在アサーションを更新する。
3. `analysis.R` を2層構造化し、ホワイトリスト検査と三者SHA再検証を署名・ディレクトリ作成前に実装する。
4. `run_state.json` へ実行モード・検証結果を追加し、失敗時に `run_*` が作成されないことを確認する。
5. 対象root tests（pass0_boundary, input_boundary, run_isolation）を実行し、回帰がないことを確認する。
