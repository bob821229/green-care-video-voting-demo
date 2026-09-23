# GreenCare Windows Server 2016／IIS 10 部署文件

測試站與正式站的 AppSecret、Data Protection、IIS ACL 及 CAPTCHA 切換操作，另見 [測試與正式環境部署切換.md](./測試與正式環境部署切換.md)。

## 1. 部署架構

- Windows Server 2016 x64 + IIS 10
- ASP.NET Core .NET 8 framework-dependent deployment
- IIS 透過 ASP.NET Core Module 啟動 Kestrel
- 同一站台提供 Vue 靜態檔案與 `/api`
- SQL Server 使用獨立資料庫及最小權限帳號
- 正式主機不需安裝 Node.js 或 npm

> .NET 8 官方支援至 2026-11-10。伺服器必須保持最新 8.0 servicing patch，並排定升級 .NET 10 LTS。

## 2. 部署前取得資料

- 發布版本／Git commit：`________________`
- Artifact SHA-256：`________________`
- SQL 腳本版本：`________________`
- 部署日期與維護時段：`________________`
- 部署人員：`________________`
- DB 執行人員：`________________`
- 回復負責人：`________________`
- 站台 URL：`________________`
- 實體部署路徑：`________________`
- Data Protection 路徑：`________________`
- Log 路徑：`________________`

## 3. 伺服器前置需求

### 3.1 IIS

安裝並確認：

- Web Server (IIS)
- Static Content
- Default Document
- HTTP Errors
- Request Filtering
- HTTP Logging
- IIS Management Console
- WebSocket Protocol（若未使用可不安裝）

### 3.2 .NET Hosting Bundle

1. 先安裝 IIS，再安裝最新 .NET 8 Hosting Bundle x64。
2. 若 Hosting Bundle 早於 IIS 安裝，重新執行 Hosting Bundle Repair。
3. 安裝後重新啟動 IIS 或伺服器。
4. 確認 `%windir%\System32\inetsrv\aspnetcore.dll` 存在。
5. 確認伺服器已安裝最新且仍受支援的 .NET 8 patch。

### 3.3 帳號與目錄

建議建立：

```text
D:\Sites\GreenCare\current
D:\Sites\GreenCare\releases
D:\Sites\GreenCare\shared\keys
D:\Sites\GreenCare\shared\logs
```

- App Pool identity 對 `current` 僅需讀取與執行。
- App Pool identity 對 `shared\keys` 及需要寫入的 log 目錄授予 Modify。
- 不要讓站台帳號擁有部署根目錄、SQL scripts 或備份檔的修改權。
- Data Protection key 目錄不得放在可由網站下載的 `wwwroot`。

## 4. SQL Server 準備

### 4.1 原則

- 不使用 EF Core migrations。
- 不由應用程式自動建立或升級 Schema。
- SQL 腳本須經 code review／DBA 審核後人工執行。
- 應用程式帳號只授予必要的 SELECT、INSERT、UPDATE、DELETE、EXECUTE 權限。

### 4.2 首次建立

1. 建立正式資料庫及適當 collation。
2. 建立部署／DBA 帳號與獨立應用程式帳號。
3. 備份目前資料庫狀態；首次建立也要保留可追溯紀錄。
4. 依檔名順序人工執行 `database/scripts/*.sql`。
5. 每份腳本成功後核對輸出及 `SchemaVersions`。
6. 查核 table、foreign key、check constraint、index 與權限。
7. 使用應用程式帳號測試連線，並確認其無法執行 `ALTER TABLE`、`CREATE TABLE` 或 `DROP TABLE`。

### 4.3 後續異動

1. 進入維護模式或停止 App Pool。
2. 建立 full backup，記錄備份檔、時間與驗證結果。
3. DBA 人工執行尚未套用的 SQL 腳本。
4. 驗證 `SchemaVersions`、資料筆數、constraint 及必要查詢。
5. 若失敗，停止部署並依核准的 rollback／restore 程序處理。
6. Schema 驗證成功後才部署相依的應用程式版本。

## 5. 建立 IIS 站台

1. 建立專用 Application Pool。
2. 設定 `.NET CLR version` 為 `No Managed Code`。
3. 設定 64-bit application。
4. 建立站台或應用程式，實體路徑指向目前 release。
5. 設定 HTTPS binding 及正式憑證。
6. 僅在必要時保留 HTTP，並導向 HTTPS。
7. 確認發布產物根目錄含 `web.config`、應用程式 DLL 及 Vue assets。
8. 設定 request filtering 與上傳／request body 限制。

## 6. 正式設定

以下名稱應以專案最終 options class 為準；敏感值不得寫入 Git 或發布包：

- ASP.NET Core environment：`Production`
- SQL Server connection string：環境變數 `ConnectionStrings__GreenCare`
- 應用程式／HMAC 密鑰：`Security__AppSecret`（至少 32 個隨機字元）
- Data Protection key path：`Security__DataProtectionKeysPath`（例如 `D:\sites\GreenCare\shared\keys`）
- CAPTCHA：`Captcha__SiteKey`、`Captcha__SecretKey`、`Captcha__ExpectedHostname`
- 活動開始：`2026-10-12T10:00:00+08:00`
- 活動結束：`2026-10-23T17:00:00+08:00`
- Forwarded headers／known proxy 設定；同機 IIS 使用預設 loopback，其他代理以 `ForwardedHeaders__KnownProxies__0` 起逐項設定
- Log level 與 log path

建議透過 IIS Configuration Editor、`web.config` 環境變數區段的部署轉換，或受控的伺服器環境變數提供。設定檔 ACL 僅允許管理員及必要服務帳號存取。

Production 在 Windows 會以本機 DPAPI 保護持久化 Data Protection keys；仍須將 keys 目錄 ACL 限制為管理員與該 App Pool identity。不得刪除此目錄，否則既有保護資料可能無法解讀。

## 7. 應用程式發布

### 7.1 在 CI 或建置機

1. 執行 Vue 測試與 production build。
2. 將 Vue build 放入 ASP.NET Core 發布流程指定位置。
3. 執行 .NET restore、build、test、publish。
4. 確認 artifact 包含 `web.config` 與所有靜態資產。
5. 產生 artifact SHA-256 並保存測試報告。

### 7.2 在伺服器

1. 將 artifact 解壓至新的 `releases/<version>`，不得直接覆蓋執行中的目錄。
2. 核對 SHA-256。
3. 停止 App Pool 或放置 `app_offline.htm`。
4. 套用正式設定並核對 ACL。
5. 將站台路徑切換至新 release。
6. 啟動 App Pool，確認 process 正常啟動。
7. 完成 smoke test 後移除 `app_offline.htm`。

## 8. 部署後 Smoke Test

- [ ] HTTPS 憑證與重新導向正常。
- [ ] `/` 回傳首頁且靜態資產全部成功。
- [ ] `/results` 與瀏覽器重新整理正常。
- [ ] `/api/bootstrap` 回傳 200、活動時間及 30 支作品。
- [ ] 首次瀏覽會收到安全的裝置 Cookie。
- [ ] App Pool recycle 後 Cookie 仍有效。
- [ ] YouTube 影片可載入並回報觀看進度。
- [ ] CAPTCHA 使用正式 hostname 驗證成功。
- [ ] SQL Server 連線正常，且應用程式帳號權限符合最小權限。
- [ ] 測試投票、票滿後前往原作品取消、重新投票及結果更新正常；確認無直接改投功能。
- [ ] Client IP／forwarded headers 判斷正確。
- [ ] IIS log、應用程式 log 及 Windows Event Viewer 無持續錯誤。
- [ ] 回應與 log 不洩漏連線字串、密鑰、Cookie 或原始 IP。

## 9. 監控與維運

監看：

- HTTP 500、502.5、503 比率
- ASP.NET Core process crash／restart
- SQL timeout、deadlock、connection pool exhaustion
- 429 限流量及異常 `flagged` 票比例
- CAPTCHA 驗證失敗率
- 磁碟空間、log 成長及 Data Protection key 存取錯誤
- App Pool recycle 後的服務狀態

資料庫須依組織政策進行 full／differential／transaction log 備份，並定期實際演練還原；僅有備份成功訊息不視為已驗證可回復。

## 10. 回復程序

### 10.1 僅應用程式失敗

1. 停止 App Pool 或啟用 `app_offline.htm`。
2. 將站台路徑切回上一個已驗證 release。
3. 啟動 App Pool。
4. 執行首頁、API、Cookie、SQL 及投票 smoke test。
5. 保留失敗 release、log 與事件資訊供分析。

### 10.2 含資料庫異動失敗

1. 立即停止 App Pool，避免新版本繼續寫入。
2. 由 DBA 判斷執行核准 rollback SQL 或從部署前備份還原。
3. 切回與舊 Schema 相容的應用程式 release。
4. 驗證資料完整性、`SchemaVersions` 與主要票數查詢。
5. 完成 smoke test 後再恢復流量。

不得在未評估資料遺失範圍前直接執行破壞性 rollback。

## 11. 部署完成紀錄

- 實際發布版本：`________________`
- 實際 SQL 版本：`________________`
- App Pool／站台名稱：`________________`
- 部署開始／完成時間：`________________`
- Smoke test 結果：`通過 / 失敗`
- 是否執行回復：`否 / 是，原因：________________`
- 已知問題：`________________`
- .NET 10 升級工作編號與期限：`________________`
