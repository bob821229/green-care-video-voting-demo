# 正式資料庫建立與正式作品匯入

目前 `GreenCare_Development` 僅供測試，不得視為正式資料庫，也不得匯入正式活動資料後直接轉正。

## 建立時機

完成程式碼測試、SQL 審核及正式封面確認後，才由具權限的部署人員在正式 SQL Server 建立新的 `GreenCare_Production`。建立前須確認正式伺服器、備份位置、復原模式、容量與 application login；不要從 Development 複製活動資料。

## 執行順序

1. 在正式 SQL Server 的 SSMS 依序執行：
   - `database/production/001_create_production_database.sql`：先填入確認詞，只建立空白 `GreenCare_Production`，不會覆蓋既有同名資料庫。
   - `database/production/002_backup_empty_production_database.sql`：填入 SQL Server 服務帳號可寫入的絕對備份路徑與確認詞，建立 `COPY_ONLY` full backup，並以 `RESTORE VERIFYONLY` 驗證。
   - 保存兩支腳本的結果頁；確認資料庫狀態為 `ONLINE`、復原模式為 `FULL`，且備份完成時間與檔案路徑正確。
2. 依序執行：
   - `database/scripts/001_initial_schema.sql`
   - `database/scripts/002_application_permissions.sql`
   - `database/scripts/003_video_catalog.sql`
   - `database/scripts/004_cross_browser_vote_guard.sql`
   - `database/scripts/005_dynamic_video_catalog.sql`
3. 執行 `database/verify/001_verify_schema.sql` 至 `004_verify_video_catalog.sql`、`007_verify_cross_browser_vote_guard.sql` 與 `008_verify_dynamic_video_catalog.sql`。
4. 開啟 `database/catalog/2026_official_video_catalog.sql`，保持 `@ApplyChanges = 0` 執行演練。
5. 核對輸出必須是 27 筆啟用作品，其中個人組 13 筆、團體組 14 筆。
6. 將 `@ApplyChanges` 設為 `1`，並將 `@Confirmation` 設為 `N'APPLY 2026 GREENCARE OFFICIAL CATALOG'` 後正式執行。
7. 執行 `database/verify/005_verify_official_video_catalog.sql`。
8. 以 `database/templates/add_application_user.sql` 將 IIS 使用的 database user 加入 `GreenCareAppRole`。
9. 執行 `database/verify/006_verify_environment_readiness.sql`，設定：
   - `ExpectedDatabase=GreenCare_Production`
   - `RequireEmptyActivity=1`
   - `RequireOfficialCatalog=1`
10. 保存執行紀錄、驗證結果、backup 識別與部署 commit。

## 上線前要求

- `Devices`、`WatchSessions`、`Votes`、`RiskEvents`、`AuditLogs` 必須是空的。
- 正式名單不得含 Demo YouTube ID 或 Demo 封面路徑。
- API 連線字串只能指向 `GreenCare_Production`，不得沿用 `GreenCare_Development`。
- 正式 application user 不得加入 `db_owner`。
- 上線前再次執行 full backup，完成首頁、觀看、投票及排名 smoke test 後才開放活動。
