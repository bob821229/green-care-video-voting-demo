# GreenCare 本機測試 Checklist

## 1. 測試環境

- [x] Windows 開發機日期、時間及時區正確。（2026-09-18 Asia/Taipei）
- [x] 已安裝專案指定的 .NET 8 SDK、Node.js、npm 及 SQL Server。
- [x] SQL Server 測試資料庫與正式資料庫完全分離。（本機 `GreenCare_Development`）
- [x] 已人工執行所有 `database/scripts` SQL，`SchemaVersions` 版本正確。（001、002）
- [ ] API 使用低權限測試帳號連線成功。
- [x] 已設定測試用活動起訖時間、應用程式密鑰及 CAPTCHA 測試設定。
- [ ] Data Protection keys 使用站外持久化目錄，API 重啟後仍能解讀既有保護資料。
- [ ] 只信任實際 IIS／反向代理 IP，偽造的 forwarded headers 不會改寫來源 IP。
- [x] 啟動前端、API 後，瀏覽器 Console 與 API log 無未處理錯誤。（發布成品 smoke test）

## 2. Build 與自動化測試

- [x] `npm ci` 成功。（隔離乾淨目錄，0 vulnerabilities）
- [x] Vue lint／test 成功。（13/13）
- [x] Vue production build 成功。（2026-09-18：`src/greencare-web` 執行通過）
- [x] `dotnet restore` 成功。
- [x] `dotnet build` 成功且無 warning-as-error。（0 warning、0 error）
- [x] `dotnet test` 全部成功。（37/37）
- [x] EF Core 整合測試使用真實 SQL Server，未以 InMemory provider 取代 constraint、index 或 transaction 驗證。
- [x] 程式碼未呼叫 `Database.Migrate()`、`EnsureCreated()` 或在啟動時執行 DDL。
- [x] `dotnet publish` 可產生含 Vue assets 與 `web.config` 的完整目錄，且發布目錄可獨立啟動。
- [x] GitHub Pages Demo build 成功。（2026-09-18：13/13 測試通過，子路徑首頁／結果頁／重整通過）

## 3. 基本頁面與視覺

- [x] `/` 可正常開啟且不出現未載入資源。（發布成品 HTTP 200）
- [x] `/results` 可正常開啟，重新整理不會由 IIS/API 回傳 404。（發布成品 HTTP 200）
- [x] 舊 `/results.html` 依設計正確導向或相容顯示。（GET 302 → `/results`）
- [ ] Logo、主辦／執行單位、作品海報及活動背景正確。
- [ ] 個人組與團體組切換正常。
- [ ] 桌面、平板、手機寬度與現有版本視覺一致。
- [ ] 鍵盤可操作頁籤、作品卡、Dialog 及確認按鈕。
- [ ] Dialog 開啟、關閉、ESC 與焦點行為正常。
- [ ] 頁面文案、錯誤訊息及票數文字與目前版本一致。

## 4. 裝置 Cookie

- [ ] 首次開啟站台會建立裝置 Cookie。
- [ ] Cookie 為 HttpOnly、SameSite=Lax；HTTPS 模式含 Secure。
- [ ] 重新整理與重開瀏覽器後仍識別同一裝置。
- [ ] API／站台重啟後既有 Cookie 仍可解讀。
- [ ] 竄改 Cookie 後不會冒用原裝置，系統安全地建立新識別或拒絕。
- [ ] 日誌不記錄 Cookie 原值或可逆裝置資訊。
- [ ] 錯誤回應與日誌不包含 AppSecret、SQL 密碼、原始 IP 或例外內部訊息。

## 5. YouTube 與觀看資格

- [ ] 點擊作品可載入正確 YouTube 影片。
- [ ] 首次播放會建立觀看 Session。
- [ ] 短時間重新開啟相同影片可依規則重用 Session。
- [ ] 正常前景播放會累積有效觀看進度。
- [ ] 暫停時不累積。
- [ ] 切換分頁或視窗進入背景時不累積。
- [ ] 快轉跳過區間不累積。
- [ ] 影片大幅倒轉時正確標記 restarted，既有有效秒數不被重複累積。
- [ ] 大於允許值的播放倍速不累積。
- [ ] 不合理的位置跳動或回報頻率不累積。
- [ ] 網路短暫中斷後，伺服器已確認的進度仍保留。
- [ ] 未達 80% 不可投票，達 80% 後可投票。

## 6. 投票、取消與重新投票

- [ ] 活動開始前不可投票。
- [ ] 活動期間可對已取得資格的作品投票。
- [ ] 活動結束後不可新增或取消。
- [ ] 個人組最多同時持有 2 張有效票。
- [ ] 團體組最多同時持有 2 張有效票。
- [ ] 同一裝置不可對相同作品重複持有有效票。
- [ ] 投票成功後 UI、剩餘票數與結果資料同步更新。
- [ ] 取消投票後票數立即扣除，資料庫保留 cancelled 紀錄。
- [ ] 取消後可以重新投給同一作品。
- [ ] 每組投滿 2 票後，新作品只顯示已投作品與「前往查看」，不可直接替換選票。
- [ ] 使用者必須前往原作品再次確認標題／影片並取消原票。
- [ ] 取消成功後，新作品仍須具備 80% 觀看資格並重新完成 CAPTCHA 才能投票。
- [ ] 直接呼叫舊版 `/api/votes/{id}/replace` 不可改變選票。
- [ ] CAPTCHA 失敗、過期及缺少 token 時不可投票。
- [ ] 同時送出重複請求時，資料庫 constraint 可防止重複有效票。

## 7. 限流與風險判定

- [ ] 投票裝置限流正常並回傳 429。
- [ ] 投票 IP 限流正常並回傳 429。
- [ ] 觀看開始、進度與 Session 限流正常。
- [ ] 429 response 含正確 `Retry-After`。
- [ ] 同 IP 短時間集中投票會提高風險分數。
- [ ] 相同裝置訊號跨裝置使用會提高風險分數。
- [ ] 高風險票標記為 `flagged`，不列入有效結果。
- [ ] 資料庫及日誌未保存原始 IP 或原始裝置訊號。

## 8. 結果頁

- [ ] 個人組顯示 13 支、團體組顯示 14 支作品。
- [ ] 只統計 `valid`；`flagged`、`cancelled`、`void` 不計入。
- [ ] 同票時依作品 ID 穩定排序。
- [ ] 名次、票數、得票率及更新時間正確。
- [ ] 前端每 30 秒更新。
- [ ] 後端 5 秒快取正常，投票或取消後會使快取失效。
- [ ] 活動狀態與結果頁聲明正確。

## 9. Demo mode

- [x] Demo 使用 mock 作品與固定結果。
- [x] 觀看及展示投票只寫入 `localStorage`。
- [x] Demo 不傳送請求至正式 `/api`。
- [x] Demo 重整頁面後狀態符合目前展示版行為。
- [x] 清除 `localStorage` 可重設 Demo。

## 10. SQL Server 與安全

- [x] EF mapping 與人工建立的 Schema 完全一致。（真實 SQL Server 整合測試）
- [x] foreign key、check constraint、unique/filter index 均生效。（真實 SQL Server 整合測試）
- [x] 正式應用程式啟動時不執行 migration、`EnsureCreated()` 或其他 DDL。
- [ ] 應用程式 SQL 帳號無 `ALTER`、`CREATE`、`DROP` 權限。
- [ ] 連線失敗時回傳一般錯誤，不洩漏連線字串或 SQL 細節。
- [x] 所有日期以 UTC 儲存，台北活動起訖時間判斷正確。（Production：2026-10-12 10:00～2026-10-23 17:00）
- [x] SQL transaction isolation 足以防止併發超額投票。（整合測試通過）

## 11. 完成判定

- [ ] 所有必要項目通過。
- [ ] 無 blocker 或 critical issue。
- [ ] 功能差異已有書面核准，而非未預期回歸。
- [ ] 測試使用的票數、Cookie、資料庫及密鑰未混入正式環境。
- [ ] 測試結果、失敗證據與修正 commit 可追溯。
