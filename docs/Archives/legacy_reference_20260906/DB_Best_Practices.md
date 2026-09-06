# 技術リファレンス: DB設計とデータ整合性

このドキュメントは、MySQL/MariaDB を用いた分析基盤の構築において共通して守るべき技術的原則とベストプラクティスをまとめたものです。

## 1. データ型選択の原則

統計分析の効率と正確性を担保するため、以下の基準でデータ型を選択します。
- **カテゴリカル変数**: 原則として `VARCHAR` または `ENUM` を使用し、可能な限り正規化（マスターテーブル化）を検討します。
- **度数・カウント**: `INT UNSIGNED` または `BIGINT UNSIGNED` を使用します。負の値は許容しません。
- **日付・時刻**: `DATETIME` または `TIMESTAMP` を使用し、タイムゾーン（JST）を一貫させます。

---

## 2. 文字コードとエンコーディング (UTF-8)

日本語を含むデータの不整合（文字化け）を防ぐため、以下の設定を必須とします。
- **Charset**: `utf8mb4` (4バイトUTF-8)
- **Collation**: `utf8mb4_ja_0900_as_cs` (MySQL 8.0+) または `utf8mb4_general_ci`
- **R/Python接続時**: 接続文字列にて明示的に `charset=utf8mb4` を指定。

---

## 3. ETL (Extract, Transform, Load) ロジック

外部ファイル（CSV等）からDBへロードする際の整合性確保ルール。
- **中間ファイルの使用**: 生データを直接投入せず、一度 Python 等でクレンジング（型変換、トリミング）を行った中間ファイルを経由します。
- **件数検証**: ロード前後でレコード数の一致を必ず確認します。

---

## 参考文献
- MySQL 8.4 Reference Manual.
- Celko, J. (2014). *SQL for Smarties: Advanced SQL Programming*. Morgan Kaufmann.
