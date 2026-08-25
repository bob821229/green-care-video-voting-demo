# 一頁式影片投票網站

## GitHub Pages 操作展示版

推送至 `main` 後，GitHub Actions 會執行測試、建立純前端版本並部署至 GitHub Pages。展示版會自動使用瀏覽器端 Mock API：影片清單來自 `videos.json`，觀看進度與展示投票保存在 `localStorage`，結果票數為固定 Mock 資料。展示操作不會連線或寫入正式 SQLite 資料庫。

```bash
npm run build:pages
```

產物位於 `dist/`，不應手動提交。正式 Node／Express 執行方式與 API 維持不變。

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
