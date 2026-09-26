# Fully inlined DataTables Japanese dictionary (Zero-External-Asset; no CDN ja.json)

get_dt_ja_lang <- function() {
  list(
    emptyTable = "データが登録されていません",
    info = "_TOTAL_ 件中 _START_ 〜 _END_ 件を表示",
    infoEmpty = "0 件中 0 〜 0 件を表示",
    infoFiltered = "（全 _MAX_ 件から抽出）",
    lengthMenu = "表示件数: _MENU_",
    loadingRecords = "読み込み中...",
    processing = "処理中...",
    search = "検索:",
    zeroRecords = "一致するデータが見つかりません",
    paginate = list(
      first = "先頭",
      previous = "前へ",
      `next` = "次へ",
      last = "最終"
    )
  )
}
