# 正式環境範本

正式作品名單已固定於 `database/catalog/2026_official_video_catalog.sql`，不再使用舊的 30 筆固定分組置換範本。

正式資料庫尚未建立前，只能審核及演練腳本，不得在 `GreenCare_Development` 套用正式名單。建立新的正式資料庫後依序執行版本 `001` 至 `005`，再以 `@ApplyChanges = 0` 演練正式名單；核對 27 筆輸出後才設定確認詞正式套用。

正式資料庫建置完成後，必須以 `database/verify/006_verify_environment_readiness.sql` 搭配 `RequireEmptyActivity=1` 與 `RequireOfficialCatalog=1` 執行。正式應用程式帳號不得屬於 `db_owner`。
