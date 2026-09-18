# 一頁式影片投票網站

## Vue／.NET 遷移骨架

目前遷移分支已建立 Vue 3 + Vite、ASP.NET Core 8 與 EF Core 8 SQL Server 資料存取層，舊 Node.js 版本仍保留作為功能與畫面基準。

資料庫 Schema 不由 EF Core 建立或升級。請先依序人工執行 `database/scripts`，再啟動 API；禁止使用 EF migrations、`Database.Migrate()` 或 `EnsureCreated()`。

本機開發需開啟兩個終端機：

```powershell
dotnet run --project src/GreenCare.Api/GreenCare.Api.csproj --launch-profile http
```

```powershell
cd src/greencare-web
npm ci
npm run dev
```

Vue 開發網址為 `http://localhost:5173`，`/api` 會代理至 `http://localhost:5080`。

Development／Testing 預設連線至本機 `(localdb)\MSSQLLocalDB` 的 `GreenCare_Development`。若要指定其他測試 SQL Server，執行整合測試前設定：

```powershell
$env:GREENCARE_TEST_SQLSERVER = "Server=<server>;Database=GreenCare_Development;User ID=<user>;Password=<password>;Encrypt=true;TrustServerCertificate=true"
dotnet test GreenCare.sln
```

正式 API 連線字串不寫入版控，必須由 IIS／主機環境提供 `ConnectionStrings__GreenCare`。

Production 另外必須提供：

- `Security__AppSecret`：至少 32 字元的獨立隨機密鑰，用於不可逆 HMAC 與簽章。
- `Security__DataProtectionKeysPath`：IIS App Pool 可持久讀寫的站外目錄；Windows Production 會以本機 DPAPI 保護金鑰。
- 若 IIS／反向代理不在 loopback，使用 `ForwardedHeaders__KnownProxies__0` 等設定明確列出代理 IP。
- `Captcha__SiteKey`、`Captcha__SecretKey`、`Captcha__ExpectedHostname`：Production 的 reCAPTCHA 設定；任一缺漏時拒絕啟動。

裝置 Cookie 維持 `vote_device`、一年、HttpOnly、SameSite=Lax，Production 會加入 Secure。密鑰或 Data Protection 路徑缺漏時，正式站台會拒絕啟動。

產生 IIS 用單一發布目錄：

```powershell
dotnet publish src/GreenCare.Api/GreenCare.Api.csproj -c Release -o artifacts/publish/GreenCare.Api
```

發布流程會以 `npm ci` 建置 Vue，並將產物放入發布目錄的 `wwwroot`。Development／Testing 活動期間為全年；Production 使用 2026-10-12 10:00 至 2026-10-23 17:00（Asia/Taipei）。

## GitHub Pages 操作展示版

GitHub Pages 採手動部署，不會因推送 `main` 或遷移分支而自動覆蓋既有展示站。展示版會使用瀏覽器端 Mock API：影片清單來自 `src/greencare-web/public/mock-videos.json`，觀看進度與展示投票保存在 `localStorage`，結果票數為固定 Mock 資料；不會連線 .NET API、SQL Server 或舊 SQLite 資料庫。

```powershell
Set-Location D:\greencare\src\greencare-web
npm ci
npm test -- --run
npm run build:pages
```

產物位於 `src/greencare-web/dist/`，不應手動提交。要更新線上 Demo 時，在 GitHub 的 **Actions → Deploy GitHub Pages demo → Run workflow** 選擇要展示的分支後執行；目前遷移版分支為 `codex/migrate-vue-dotnet-sqlserver`。

預期網址為 `https://bob821229.github.io/green-care-video-voting-demo/`。同一個 Repository 只有一個 Pages 網址，因此手動部署新分支後，該網址會改為顯示該次部署內容；`main` 分支與原始碼仍保留，不會被修改，需要時可再手動部署 `main` 還原展示內容。

免登入、每台裝置一票的 30 支 YouTube 影片票選網站。使用者需有效觀看所選影片達 80%，通過 Cloudflare Turnstile 後才能投票；系統會記錄 IP 與裝置訊號的雜湊，用於風險評分及後台稽核。

## 本機啟動

1. 安裝 Node.js 22 以上版本。
2. 執行 `npm install`。
3. 將 `.env.example` 複製為 `.env`，設定密鑰與活動期間。
4. Node.js 不會自動讀取 `.env`；開發時可用 PowerShell 設定環境變數，或用部署平台的環境變數功能。
5. 執行 `npm run dev`，開啟 `http://localhost:3000`。

正式環境必須設定 `RECAPTCHA_SITE_KEY`、`RECAPTCHA_SECRET_KEY` 與 `RECAPTCHA_EXPECTED_HOSTNAME`。前端只取得一次性 token，投票與改投均由後端向 Google 驗證；取消投票不要求再次驗證。

### 重設本機測試投票

執行 `npm run reset:dev` 可清除本機資料庫內的測試票、觀看進度及裝置鎖定，重新整理網頁後即可再次測試。這會清除所有本機測試資料；正式環境會拒絕執行此指令。

執行 `npm run seed:results` 可為 30 支作品重新產生隨機 mock 有效票，方便預覽結果頁的排名與比例條。此指令只替換前一次產生的 mock 票，會保留手動測試資料；正式環境會拒絕執行。

## 設定影片

編輯 `videos.json`：

- `id`：1–30 的內部編號，不要重複。
- `number`：前台顯示編號。
- `title`、`team`：真實片名與團隊名稱。
- `youtubeId`：YouTube 網址中 `v=` 後方的影片 ID。
- `poster`：保留欄位，目前播放器縮圖由 YouTube 提供。

## 管理後台

開啟 `/admin.html`，輸入環境變數 `ADMIN_KEY`。後台只顯示彙總票數與異常紀錄，不會顯示原始 IP 或可逆的裝置資料。

## 票選結果頁

開啟 `/results.html` 查看個人組及團體組即時排名。結果頁從活動開始常駐開放並每 30 秒更新，只計算狀態為 `valid` 的票；`flagged`、已取消及作廢票不列入。首頁同步顯示每組前 3 名摘要。

## 正式部署檢查

- 使用 HTTPS，設定至少 32 字元的 `APP_SECRET` 與獨立的 `ADMIN_KEY`。
- 反向代理後設定 `TRUST_PROXY=1`，否則無法取得正確來源 IP。
- 設定正式活動起訖時間及 Turnstile 金鑰。
- 備份 `data/votes.db`，並限制檔案只能由應用程式帳號讀取。
- 在隱私政策補上主辦單位名稱、聯絡方式、確切保存期限及刪除程序。
- 若多台伺服器水平擴充，應將 SQLite 換成 PostgreSQL，並使用集中式限流儲存。

## 已知界線

免登入方案能可靠限制同一瀏覽器裝置，但不能保證一個真人只有一票。清除 Cookie、換裝置仍可能再次投票，因此必須搭配 Turnstile、流量限制與人工異常稽核。
