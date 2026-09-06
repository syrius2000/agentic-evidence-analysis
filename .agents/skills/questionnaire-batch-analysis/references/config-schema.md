# question config CSV 仕様

`templates/batch_runner.R` が期待する設定CSVの仕様。

## 必須列

以下の列が **すべて必須**。

- `survey_id`
- `question_id`
- `analysis_type`
- `var1`
- `var2`
- `var3`
- `output_slug`
- `question_label`
- `subset_expr`
- `na_policy`
- `ordered_levels`
- `reference_note`

## 列の使い方（主要）

- `analysis_type`: `nominal_2way` / `likert_2way` / `nominal_3way`
- `var1`,`var2`,`var3`: 入力データ列名（`var3` は2-wayでは空で可）
- `output_slug`: 各設問の出力フォルダ名
- `subset_expr`: R式のフィルタ（空なら全件）
- `na_policy`: `drop` なら欠損行を除外

### `output_slug` の安全性契約

`output_slug` は、出力root直下のフォルダ名として使える**安全な単一slug成分**に限る。

- 長さは1〜100文字、ASCIIのみとし、先頭は英数字とする。
- 使用可能文字はASCII英数字・`.`・`_`・`-`、すなわち `[A-Za-z0-9._-]` のみとする。
- 末尾は英数字・`_`・`-` とし、末尾の `.` は禁止する。空白、非ASCII文字、`/` と `\` のパス区切り、Windows禁止記号は使用できない。
- `.`、`..`、Unix形式・Windows形式の絶対パスは、上記の構文規則を満たさないため使用禁止。
- 重複判定はcase-insensitive（大文字小文字を区別しない）で行う。たとえば `Question1` と `question1` は同一slugとして拒否する。
- Windows予約名 `CON`、`PRN`、`AUX`、`NUL`、`COM1`〜`COM9`、`LPT1`〜`LPT9` は、`CON.txt` など拡張子付きの場合も禁止する。
- 設定CSVは全列を文字列として読み、`output_slug` のCSV文字列をそのまま保持して先頭ゼロを維持する。`output_slug` 以外の設定列ではliteral `NA` は欠損として扱い、空欄も従来どおり欠損として扱う。一方、`output_slug` の `NA` は文字列として保持する。`001` と `1`、`01` と `1` は別slugであり、文字列 `NA` も上記構文を満たす合法slugとなる。
- 契約違反と重複は、設問別ディレクトリや成果物を生成する前に拒否する。

## 最小例

```csv
survey_id,question_id,analysis_type,var1,var2,var3,output_slug,question_label,subset_expr,na_policy,ordered_levels,reference_note
S1,Q01,nominal_2way,sex,event,,q01,性別×事象,,drop,,
S1,Q02,nominal_3way,sex,event,age_group,q02,性別×事象×年齢層,,drop,,
```

## よくある失敗

- `var1/var2/var3` が入力CSVに存在しない
- `analysis_type` の綴りミス
- `output_slug` が安全性契約に違反する、またはcase-insensitiveで重複する
- `subset_expr` の式エラー（実装上は全件扱いにフォールバックする場合があるため要注意）
