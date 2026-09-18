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
  verify/        執行後驗證，不異動正式業務資料
  templates/     依環境填值後人工執行的範本
  rollback/      經核准後才可執行的破壞性回復腳本
```

## 本機建立及驗證

下列範例使用 SQL Server LocalDB；正式環境請替換 `-S` 與資料庫名稱。

```powershell
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "CREATE DATABASE [GreenCare_Development]"
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/scripts/001_initial_schema.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/scripts/002_application_permissions.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/001_verify_schema.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/002_verify_permissions.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -d GreenCare_Development -b -i database/verify/003_verify_constraints.sql
```

`-b` 會讓 SQL 錯誤轉成非零結束碼，部署腳本不得省略。

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
