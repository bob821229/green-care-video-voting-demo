# 正式作品目錄置換

取得業主核准的 30 筆正式作品與素材後，使用 `replace_video_catalog.template.sql`：

1. 備份並驗證目標資料庫。
2. 另存一份有日期的腳本，只修改標示的 30 筆 `VALUES`。
3. ID 1–15 固定為 `individual`；ID 16–30 固定為 `team`。
4. 保持 `@ApplyChanges = 0` 先執行，應顯示 `DRY RUN passed. All changes were rolled back.`。
5. 與業主逐筆核對標題、團隊、YouTube ID 與海報路徑。
6. 確認 `WatchSessions`、`Votes` 皆為空；腳本會拒絕在已有活動資料時置換。
7. 正式執行時改成 `@ApplyChanges = 1`，並設定 `@Confirmation = N'REPLACE GREENCARE VIDEO CATALOG'`。
8. 隨即執行 `database/verify/005_verify_official_video_catalog.sql`，再驗證 `/api/bootstrap` 與 `/api/results`。
9. 保存實際執行的 SQL、驗證結果、備份識別與 Git commit。

此程序保留作品 ID 與 Schema 版本 `003`，避免破壞應用程式契約及外鍵。

正式資料庫建置完成後，必須以 `database/verify/006_verify_environment_readiness.sql` 搭配 `RequireEmptyActivity=1` 與 `RequireOfficialCatalog=1` 執行。正式應用程式帳號不得屬於 `db_owner`。
