# GreenCare SQL Server 資料庫腳本

## 原則

- 不使用 EF Core migrations。
- 不允許應用程式呼叫 `Database.Migrate()`、`EnsureCreated()` 或執行 DDL。
- 所有 Schema 與權限異動均以版本化 SQL 交付，經人工審核、備份後由 DBA／部署人員執行。
- 應用程式帳號只加入 `GreenCareAppRole`，不得加入 `db_owner`、`db_ddladmin`、`db_securityadmin` 等高權限角色。
- `SchemaVersions` 是已執行腳本的唯一版本紀錄；腳本成功提交後才寫入版本。
- 資料模型與主要約束請參考 [SCHEMA.md](./SCHEMA.md)。

## 目錄

```text
database/
  scripts/       依編號順序執行的正式異動腳本
  catalog/       經業主核准、預設只演練的正式作品資料
  verify/        執行後驗證，不異動正式業務資料
  reports/       唯讀的作品、票選結果及受控稽核匯出
  templates/     依環境填值後人工執行的範本
  rollback/      經核准後才可執行的破壞性回復腳本
```

## 本機建立及驗證

下列範例使用 SQL Server LocalDB；正式環境請替換 `-S` 與資料庫名稱。

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "CREATE DATABASE [GreenCare_Development]"
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/scripts/001_initial_schema.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/scripts/002_application_permissions.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -f 65001 -i database/scripts/003_video_catalog.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -f 65001 -i database/scripts/004_cross_browser_vote_guard.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -f 65001 -i database/scripts/005_dynamic_video_catalog.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/001_verify_schema.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/002_verify_permissions.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/003_verify_constraints.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/004_verify_video_catalog.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/007_verify_cross_browser_vote_guard.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/008_verify_dynamic_video_catalog.sql
```

`-b` 會讓 SQL 錯誤轉成非零結束碼，部署腳本不得省略。

`003_video_catalog.sql` 含繁體中文 Demo 作品資料；使用 `sqlcmd` 時必須加上 `-f 65001`，明確以 UTF-8 讀取。使用 SSMS 開啟時也須確認檔案編碼為 UTF-8，避免作品名稱亂碼。

## 正式環境執行順序

1. 確認應用程式已停止或進入維護模式。
2. 記錄目前應用程式版本及 `SchemaVersions`。
3. 完成 SQL Server full backup，並確認備份可以讀取。
4. DBA 審核尚未套用的 `database/scripts/*.sql`。
5. 使用具 DDL 權限的部署帳號依檔名順序執行，並啟用 `sqlcmd -b`。
6. 執行 `database/verify/*.sql`。
7. 使用 `database/templates/add_application_user.sql` 將既有 database user 加入最小權限角色。
8. 以應用程式帳號驗證連線及 DML，不授予 Schema 異動權限。
9. 部署相容的應用程式版本並完成 smoke test。

將 DBA 已建立的 database user 加入應用程式角色時，必須明確傳入名稱：

```powershell
sqlcmd -S "<server>" -d "<database>" -E -b `
  -v AppUserName="GreenCareApp" `
  -i database/templates/add_application_user.sql
```

## 版本規則

- 檔名格式：`NNN_description.sql`。
- 已執行腳本不得修改；後續變更必須新增下一個版本。
- 每份正式腳本必須在同一 transaction 內完成，使用 `SET XACT_ABORT ON`。
- 若版本已存在，腳本須驗證必要物件仍存在後安全結束。
- 若發現同名但非預期的物件，必須失敗，不得覆蓋。

`003_video_catalog.sql` 會建立 `Videos`、匯入與目前 `videos.json` 相同的 30 筆 Demo 作品，並建立 `WatchSessions`／`Votes` 的作品外鍵。正式作品尚未確認前不得將 Demo 資料視為正式名單；正式名單須以後續版本化 SQL 人工置換並留下紀錄。

`004_cross_browser_vote_guard.sql` 不新增資料表或修改既有票。它只建立 `IpHash + DeviceSignalHash + Category + Status` 查詢索引，支援應用程式在同一 transaction 內鎖定相同裝置與網路環境的有效票，阻止換瀏覽器或清除 Cookie 後重新取得票數額度。部署新版 API 前須先執行此腳本及 `007_verify_cross_browser_vote_guard.sql`。

`005_dynamic_video_catalog.sql` 移除以作品 ID 推導總數與組別的舊限制。應用程式改讀取 `Videos.Category`、`SortOrder` 與 `IsActive`；外鍵仍確保觀看及投票只能參照存在的作品。

## 活動結果匯出

活動結束後依 [reports/README.md](./reports/README.md) 的凍結、備份、匯出與雜湊程序執行。一般業主結果使用 `003_vote_summary.sql`；`004`、`005` 含假名化識別與安全訊號，只能作受控內部稽核，不得作公開結果檔。

## 正式作品置換

2026 正式名單使用 `catalog/2026_official_video_catalog.sql`。第一次執行保持 `@ApplyChanges = 0` 進行演練；確認輸出後才設定確認詞正式套用。正式套用前必須確認觀看與投票資料皆為空。

## 回復

初始 Schema 回復腳本會刪除所有 GreenCare 資料表及資料，只能在已備份、確認不再需要資料且核准停機後執行。執行時必須明確提供 SQLCMD 變數：

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b `
  -v ConfirmDestructiveRollback="YES" `
  -i database/rollback/001_initial_schema.rollback.sql
```

若未提供 `ConfirmDestructiveRollback`，`sqlcmd` 會直接失敗；值不是 `YES` 時腳本也會拒絕執行。

正式環境若需保留資料，優先使用 SQL Server full backup 還原，而不是執行破壞性 rollback：

1. 停止 IIS App Pool，記錄目前應用程式版本與資料庫版本。
2. 由 DBA 驗證目標 `.bak`、還原目的資料庫名稱與檔案路徑。
3. 將備份還原至隔離的驗證資料庫，執行 `database/verify` 與筆數核對。
4. 經核准後才對正式資料庫執行 restore／切換。
5. 重新套用低權限 application user 對應，啟動 App Pool 並完成 smoke test。
