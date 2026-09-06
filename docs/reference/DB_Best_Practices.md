# 技術リファレンス: DB設計とデータ整合性

created: 2026-09-06 23:55 (JST)
update: 2026-09-07 00:35 (JST)
author: Codex (GPT-5) / Antigravity

このドキュメントは、MySQL / MariaDB または各種 RDBMS を用いた分析データ基盤の構築において、カテゴリカルデータ分析パイプライン（Pass 0〜Pass 3）とシームレスかつ高信頼に連携するために遵守すべき技術的原則をまとめたものです。

---

## 1. データ型選択と統計契約

統計分析の効率と正確性を担保するため、以下の基準でデータ型を厳格に選択します：

- **カテゴリカル変数**:
  原則として `VARCHAR` または `ENUM` を使用し、可能な限り正規化（マスターコード化）を検討します。空白文字、前後のトリミング（trimming）、および大文字・小文字の不整合を ETL 段階で排除します。
- **度数・カウント（Counts）**:
  `INT UNSIGNED` または `BIGINT UNSIGNED` を使用します。度数は非負整数（$n_{ijk} \ge 0$）であり、負の値はスキーマ制約で拒否します。
- **日付・時刻**:
  `DATETIME` または `TIMESTAMP` を使用し、タイムゾーンは日本標準時（JST / Asia/Tokyo）で一貫させます。

---

## 2. 文字コードとエンコーディング (UTF-8 / utf8mb4)

日本語を含むデータの文字化けや不整合を防止するため、以下の設定を必須とします：

- **Charset**: `utf8mb4` (4 バイト UTF-8、絵文字・JIS第3/第4水準文字に対応)
- **Collation**: `utf8mb4_ja_0900_as_cs` (MySQL 8.0+、日本語照合順序、アクセント・大文字小文字区別) または `utf8mb4_bin`
- **R / Python 接続時**:
  接続文字列において明示的に `charset=utf8mb4` を指定し、クライアント・サーバー間の暗黙の文字コード変換を防止します。

---

## 3. ETL（抽出・変換・ロード）と件数整合性検証

外部ファイル（CSV 等）から DB へロードする際、または DB から集計表を抽出する際の手順：

- **中間ファイルの検証**:
  生データを直接投入せず、前処理スクリプトでクレンジング（型変換、欠測値補正、重複排除）を実施します。
- **総度数 $N$ の完全一致検証**:
  元データ（生レコード）の件数と、集計クエリ（`GROUP BY`）で得られたセル度数の総和 $\sum n_{ijk} = N$ が 1 件の狂いもなく完全一致することを必ずアサーション（検証）します。
- **疎セルと未観測セルの明示化**:
  観測度数が 0 のセル（サンプリングゼロ）について、DB の `GROUP BY` で行ごと消滅しないよう、水準マスターとの外部結合（`LEFT JOIN`）等により `count = 0` として明示的に保持します。

---

## 4. 参考文献（Primary Literature）

1. **Celko, J. (2014)**. *Joe Celko's SQL for Smarties: Advanced SQL Programming* (5th ed.). Morgan Kaufmann, Waltham, Massachusetts. [ISBN:978-0-12-800761-7](https://www.elsevier.com/books/joe-celkos-sql-for-smarties/celko/978-0-12-800761-7)
2. **Oracle Corporation (2024)**. *MySQL 8.4 Reference Manual: Character Sets, Collations, and Unicode Support*. Oracle Online Documentation. [MySQL Documentation](https://dev.mysql.com/doc/refman/8.4/en/charset.html)
