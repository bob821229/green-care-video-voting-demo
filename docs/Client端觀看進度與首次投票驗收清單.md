# Client 端觀看進度與首次投票驗收清單

請依本文件順序逐步測試。每完成一個操作並確認結果後，在對應的 `- [ ]` 中打勾。

## 0. 測試準備

### 0.1 確認測試環境

- [ ] 確認目前測試的是測試站，而不是正式活動站。
- [ ] 確認測試站的活動狀態為進行中。
- [ ] 準備一支尚未投票的個人組作品，記錄作品編號：`__________`。
- [ ] 準備一支尚未投票的團體組作品，記錄作品編號：`__________`。
- [ ] 開啟瀏覽器開發者工具的 Network、Application／Storage 與 Console 面板。
- [ ] Network 面板開啟 Preserve log，方便保留切換頁面前後的 request。
- [ ] 確認瀏覽器沒有封鎖 YouTube、CAPTCHA 或測試站 Cookie。

### 0.2 確認版本與發布內容

- [ ] 確認部署版本來自分支 `codex/client-progress-resilient-voting`。
- [ ] 執行 `dotnet test tests/GreenCare.Api.Tests/GreenCare.Api.Tests.csproj` 並記錄結果：`__________`。
- [ ] 在 `src/greencare-web` 執行 `npm test` 並確認全部通過。
- [ ] 在 `src/greencare-web` 執行 `npm run build` 並確認建置成功。
- [ ] 確認發布產物根目錄存在 `favicon.ico`。
- [ ] 確認本次部署沒有新增或執行資料庫 migration。

## 1. 全新使用者第一次觀看

### 1.1 清除測試瀏覽器狀態

- [o ] 清除測試站的 Cookie、Local Storage 與 Session Storage。
- [ o] 重新整理首頁。
- [o ] 在 Application／Cookies 確認 Server 已建立 `vote_device`。
- [ o] 在 Local Storage 確認尚未產生 `greencare-client-watch-v1`，或內容為空物件。

### 1.2 開始播放

- [o ] 開啟準備好的未投票作品。
- [ o] 確認進度顯示為 `0%`。
- [ o] 按下播放並連續觀看至少 10 秒。
- [ o] 確認進度條約每秒增加，而不是每 5 秒等待 Server 回應才跳動。
- [ o] 在 Network 確認播放期間沒有持續每秒呼叫 Server progress API。
- [ o] 在 Local Storage 找到 `greencare-client-watch-v1`。
- [ o] 確認該作品資料包含 `videoId`、`youtubeId`、`duration`、`watchedSeconds`、`lastPosition`、`updatedAt`。
- [ o] 確認 `watchedSeconds` 大於 0。

## 2. 暫停、背景、倍速、快轉與倒轉

### 2.1 暫停不累積

- [ o] 記錄暫停前進度：`___24_______%`。
- [o ] 暫停影片並等待 5 秒。
- [ o] 確認進度百分比沒有增加。
- [ o] 恢復播放並等待 3 秒。
- [ x] 確認進度重新增加。

### 2.2 背景播放不累積

- [ o] 記錄切換背景前進度：`______39____%`。
- [ o] 切換到其他分頁並等待至少 5 秒。
- [ o] 回到測試站。
- [o ] 確認背景期間沒有增加有效觀看進度。
- [ o] 確認回到前景並播放後，進度可繼續增加。

### 2.3 超過 1.25 倍速不累積

- [o ] 將 YouTube 播放速度調整為高於 `1.25x`。
- [ o] 連續播放至少 5 秒。
- [ o] 確認有效觀看進度沒有增加。
- [ o] 將速度恢復為 `1x`。
- [ o] 確認進度恢復增加。

### 2.4 快轉區間不累積

- [o ] 記錄快轉前進度：`_____0_____%`。
- [ o] 將影片播放位置向前拖曳至少 20 秒。
- [ o] 確認被跳過的 20 秒沒有直接加入有效觀看進度。
- [ o] 從新位置正常播放至少 5 秒。
- [ o] 確認只增加正常播放的秒數。

### 2.5 倒轉後繼續累積有效播放秒數

- [ o] 記錄倒轉前進度：`_______17___%`。
- [ o] 將影片向後拖曳到已觀看過的位置。
- [ ] 確認拖曳動作及跳過的距離本身沒有直接增加進度。
- [ ] 從倒轉後的位置正常播放至少 5 秒。
- [ ] 確認正常播放的有效秒數會繼續累積，不必先播放到倒轉前的位置。

## 3. Local Storage 恢復

- [ o] 正常播放到至少 10%，記錄進度：`_____17_____%`。
- [ o] 重新整理頁面。
- [ o] 重新開啟同一作品。
- [ o] 確認進度沒有回到 0%。
- [ o] 確認顯示進度與重新整理前大致相同。
- [ ] 從影片開頭或任一位置正常播放，確認進度可立即從原值繼續增加。

## 4. 切換作品與關閉觀看視窗

### 4.1 切換作品同步

- [ o] 播放作品 A 至至少 10%。
- [ o] 在 Network 清除舊紀錄。
- [ o] 使用上一部／下一部切換至作品 B。
- [ o] 確認 Network 出現 `POST /api/watch/client-sync`。
- [ o] 確認 request payload 的 `videoId` 是作品 A。
- [ o] 確認 response 為 HTTP 200。
- [ o] 回到作品 A，確認進度仍存在。

### 4.1.1 切回作品後持續累積

- [ o] 播放作品 A 至約 20%～30%，記錄目前百分比：`______21____`。
- [ o] 切換至作品 B 並播放數秒。
- [ o] 再切回作品 A，讓影片從開頭或低於原紀錄的位置播放。
- [ o] 確認作品 A 從原百分比立即繼續增加，不必先播放到原本的位置。
- [ o] 讓作品 A 持續播放至少 15 秒，確認進度沒有停在原百分比。

### 4.2 關閉 Dialog 同步

- [o ] 播放作品 A 至進度再次增加。
- [ o] 在 Network 清除舊紀錄。
- [ o] 按下觀看 Dialog 的關閉按鈕。
- [ o] 確認 Network 出現 `POST /api/watch/client-sync`。
- [ o] 確認 response 為 HTTP 200。

### 4.3 關閉頁面最佳努力同步

- [o ] 再次開啟作品並播放數秒。
- [ o] 關閉分頁或導向其他頁面。
- [ o] 確認 Network 可觀察到 pagehide 發出的 `/api/watch/client-sync` beacon；若瀏覽器不顯示，記錄為：`__________`。
- [o ] 重新開啟網站及作品，確認 Local Storage 進度仍可恢復。

## 5. 正常首次投票

### 5.1 達到門檻

- [ o] 使用尚未投票的作品正常觀看至 80%。
- [ o] 確認畫面進度達到或超過 `80%`。
- [ o] 確認投票按鈕不再顯示「尚未達投票門檻」。
- [ o] 完成 CAPTCHA。

### 5.2 第一次送出投票

- [o ] 在 Network 清除舊紀錄。
- [o ] 按下投票按鈕並確認投票。
- [o ] 確認只需確認一次，不需要因觀看資格再次按投票。
- [ o] 確認 `POST /api/votes` request 包含 `watchProgress`。
- [ o] 確認 `watchProgress.videoId` 與目前作品相同。
- [ o] 確認 `watchProgress.watchedSeconds / watchProgress.duration >= 0.8`。
- [ o] 確認投票 response 為 HTTP 201。
- [ o] 確認畫面顯示 `投票成功，謝謝你的參與。`。
- [ o] 重新整理頁面後確認該作品顯示已投票。

### 5.3 資料庫確認

- [ o] 在 `Votes` 找到剛建立的投票資料。
- [ o] 在 `WatchSessions` 找到 `Votes.WatchSessionId` 對應的觀看資料。
- [ o] 確認 WatchSession 與 Vote 的 `DeviceId` 相同。
- [ o] 確認 WatchSession 的 `VideoId` 與投票作品相同。
- [ o] 確認 `QualifiedAtUtc` 不為 NULL。
- [ o] 確認沒有只建立 Vote、卻找不到 WatchSession 的孤兒資料。

## 6. 觀看途中 Cookie 遺失

此案例使用另一支尚未投票的作品，避免與第 5 節資料混淆。

- [o ] 清除測試站資料後重新整理，取得新的 `vote_device`。
- [o ] 開啟尚未投票作品並開始播放。
- [ o] 播放到至少 20% 後，記錄進度：`____25______%`。
- [ o] 在 Application／Cookies 刪除 `vote_device`，不要刪除 Local Storage。
- [ o] 繼續播放至 80%。
- [ o] 完成 CAPTCHA 並送出投票。
- [ o] 確認第一次送出即成功，不需要重新整理或重新觀看。
- [ o] 確認 response 重新發放新的 `vote_device`。
- [ o] 確認資料庫建立新的 DeviceId。
- [o ] 確認新 DeviceId 下建立合格 WatchSession。
- [ o] 確認 Vote 指向新 DeviceId 的 WatchSession。
- [ o] 確認 Cookie 單純不存在時，不產生 `device_cookie_invalid` RiskEvent。

## 7. Cookie 格式或簽章無效

此案例再使用另一支尚未投票作品。

- [o ] 清除測試站資料後重新整理，取得有效 `vote_device`。
- [o ] 開啟作品並播放至至少 20%。
- [ o] 在 Application／Cookies 將 `vote_device` 改成 `not-a-valid-token`。
- [ o] 保留 Local Storage 並繼續播放至 80%。
- [ o] 完成 CAPTCHA 並送出投票。
- [ o] 確認第一次送出即成功。
- [ o] 確認畫面仍顯示 `投票成功，謝謝你的參與。`，不顯示阻擋式 Cookie Alert。
- [ o] 確認 response 覆蓋並重新發放有效 `vote_device`。
- [ x] 在 `RiskEvents` 找到 `Kind = device_cookie_invalid`。
- [o ] 確認事件 `DeviceId` 是重新發放的新 DeviceId。
- [! ] 確認 `DetailJson` 為 `{ "reissued": true }`。
- [ !] 確認事件只保存 IP 雜湊，不保存原始 IP。
- [ o] 確認資料庫及應用程式 log 都沒有保存 Cookie 原值。

## 8. 既有資料相容性

### 8.1 舊觀看資格

- [ o] 找一筆部署前已達 80% 且尚未投票的 WatchSession。
- [ o] 使用對應測試裝置開啟作品。
- [ o] 確認既有進度仍顯示。
- [ o] 完成 CAPTCHA 並投票。
- [ o] 確認未帶新版本機進度時，後端仍可使用既有合格 WatchSession。

### 8.2 舊投票資料

- [ o] 確認部署前已存在的有效票仍出現在首頁狀態中。
- [ o] 確認部署前有效票仍計入結果頁。
- [ o] 確認既有 `Votes.WatchSessionId` 外鍵仍完整。
- [ o] 確認本次部署沒有修改既有票的 `Status`。

## 9. 既有投票限制回歸測試

### 9.1 同作品不可重複投票

- [o ] 對已投票作品再次嘗試投票。
- [o ] 確認不會建立第二張 active 票。
- [o ] 確認顯示 `你已經投過這支作品。` 或環境重複票訊息。

### 9.2 每組最多兩票

- [ o] 使用同一測試裝置完成同組兩支不同作品投票。
- [ o] 嘗試投給同組第三支作品。
- [ o] 確認第三張票被拒絕。
- [ o] 確認錯誤訊息指出該組已使用兩票。

### 9.3 CAPTCHA 與活動期間

- [ o] 未完成 CAPTCHA 時嘗試投票。
- [ o] 確認顯示 `請先完成「我不是機器人」驗證。`。
- [ o] 使用無效或過期 CAPTCHA token，確認後端拒絕投票。
- [ o] 在測試環境模擬非活動期間，確認新增投票被拒絕。

### 9.4 保留已移除規格

- [ o] 確認 `Voting:AllowCancellation` 仍為 `false`。
- [ o] 確認前端沒有出現取消投票功能。
- [ o] 確認沒有直接改投 API 或流程。
- [ o] 確認高風險分數只供稽核，不會自動將成功票改成 `flagged`。

## 10. 同步與投票錯誤測試

測試前請參考 [Client 端進度與投票 Alert 清單](./Client端進度與投票Alert清單.md)。

- [ ] 暫時封鎖 `/api/watch/client-sync` 後播放並關閉 Dialog。
- [ ] 確認本機進度仍保留在 Local Storage。
- [ o] 確認畫面錯誤訊息符合 Alert 清單。
- [ ] 解除封鎖後重新開啟作品，確認可繼續觀看。
- [ ] 提交不符合目前作品的 `youtubeId`，確認顯示 `觀看進度資料與作品不符，請重新開啟影片。`。
- [ ] 提交負數、超過影片長度或非有限數值，確認顯示 `觀看進度資料不正確，請重新開啟影片。`。
- [ ] 觸發投票限流，確認 HTTP 429 與 `Retry-After: 60`。
- [ ] 確認任何失敗案例都不會產生缺少 WatchSession 的 Vote。

## 11. Favicon

- [ ] 開啟 `https://greencare.triwra.org.tw/favicon.ico`。
- [ ] 確認 HTTP status 為 200，不再出現 404。
- [ ] 確認瀏覽器可以顯示圖示，而不是下載錯誤頁面。
- [ ] 重新開啟正式站首頁，確認瀏覽器分頁顯示網站圖示。
- [ ] 在首頁原始碼確認存在 `<link rel="icon" href="/favicon.ico">`。

## 12. 驗收結果

- [ o] 第一次正常觀看與投票成功。
- [ o] Cookie 遺失後第一次投票成功。
- [可以投票 但沒有紀錄riskevent ] Cookie 無效後第一次投票成功，且資料庫留下 RiskEvent。
- [ o] 既有票與既有觀看紀錄相容。
- [ ] 同作品與每組兩票限制仍正常。
- [ o] CAPTCHA、活動期間與限流仍正常。
- [ ] 取消、直接改投、自動 `flagged` 沒有被重新啟用。
- [ ] favicon 不再回傳 404。
- [ ] 所有未通過項目均已記錄於問題追蹤：`__________`。

驗收人：`__________`

驗收日期：`__________`
部署版本／Commit：`__________`
