# GreenCare SQL Server Schema

本文件描述 `001_initial_schema.sql` 建立的初始模型。所有時間欄位均以 UTC `datetime2(3)` 儲存，主流程識別碼使用 `uniqueidentifier`，流水紀錄使用 `bigint IDENTITY`。

## 資料表

| 資料表 | 用途 | 主鍵與主要關聯 |
|---|---|---|
| `SchemaVersions` | 紀錄人工套用的 SQL 版本、時間與執行者 | `VersionNumber` |
| `Videos` | 固定參賽作品目錄、組別、影片及顯示資訊 | `Id`；由 `WatchSessions`、`Votes` 參照 |
| `Devices` | 匿名裝置識別與最後活動時間 | `Id` |
| `WatchSessions` | 每個裝置對作品的觀看進度與資格 | `Id`；FK 至 `Devices` |
| `Votes` | 投票、取消、改投與風險狀態 | `Id`；FK 至 `Devices`、`WatchSessions` 與被取代票 |
| `RiskEvents` | 防濫用風險事件 | `Id`；可選 FK 至 `Devices` |
| `AuditLogs` | 後端重要操作稽核 | `Id` |

## 重要資料規則

- `Videos` 固定包含作品 ID `1` 至 `30`；`1` 至 `15` 為 `individual`，`16` 至 `30` 為 `team`，每組顯示順序不得重複。
- `WatchSessions.VideoId` 與 `Votes.VideoId` 均以可信任外鍵參照 `Videos.Id`。
- 觀看秒數與播放位置不可為負，也不可超過影片長度。
- 投票狀態限定 `valid`、`flagged`、`cancelled`、`void`。
- 同一裝置對同一作品最多只能存在一張有效票；取消或作廢後才可再投。
- `cancelled` 必須有取消時間；`void` 必須有作廢時間與原因。
- IP 與裝置訊號只儲存 32-byte hash，不儲存原始值。
- JSON 明細由 `ISJSON` constraint 驗證。

## 索引

- `WatchSessions(DeviceId, VideoId)` 支援觀看 Session 查找。
- `Votes(DeviceId, VideoId)` filtered unique index 阻止重複有效票。
- 票數依裝置／分類／狀態及作品／狀態建立查詢索引。
- IP hash、風險事件與稽核紀錄依時間建立追查索引。

## 權限模型

`002_application_permissions.sql` 建立 `GreenCareAppRole`。角色可對五個可寫業務資料表執行 `SELECT`、`INSERT`、`UPDATE`、`DELETE`，可讀取 `SchemaVersions`；`003_video_catalog.sql` 另授予 `Videos` 唯讀權限。角色被拒絕變更 `dbo` schema。正式 application user 由部署人員依 `templates/add_application_user.sql` 手動加入角色，不授予 `db_owner`、`db_ddladmin` 或 `CREATE TABLE`。
