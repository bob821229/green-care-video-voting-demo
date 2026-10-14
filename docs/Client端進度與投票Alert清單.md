# Client 端進度與投票 Alert／錯誤訊息清單

本文件列出觀看進度改由 Client 計算後，前端可能顯示的狀態與後端錯誤。除「阻擋」項目外，不應使用瀏覽器原生 `alert()`；統一顯示在觀看 Dialog 的訊息區。

| 階段 | 狀況 | 類型 | 顯示文字 | 後端／除錯識別 |
|---|---|---|---|---|
| 播放器 | YouTube API 載入失敗 | 阻擋 | `YouTube 播放器載入失敗。` | 瀏覽器 script error |
| 播放器 | 10 秒內無法取得片長 | 可恢復 | `影片載入尚未完成，請點擊影片開始播放。` | 無 API request |
| Session | 無法建立初始觀看紀錄 | 可恢復 | API error；無內容時顯示 `無法建立觀看紀錄。` | `/api/watch/start` failure |
| 本機保存 | localStorage 不可用或額度不足 | 非阻擋 | 不顯示；本次頁面仍以記憶體進度繼續 | DevTools storage exception |
| 本機進度 | 暫停、背景、快轉或倍速超過 1.25 | 說明 | `觀看達 80% 後即可投票。快轉及背景播放不列入進度。` | Client 不增加 watchedSeconds |
| 同步 | 切換／關閉時同步失敗 | 可恢復 | API error；無內容時顯示 `觀看進度更新失敗。` | `/api/watch/client-sync` failure |
| 同步 | 作品或 YouTube ID 不符 | 阻擋 | `觀看進度資料與作品不符，請重新開啟影片。` | HTTP 400/409 |
| 同步 | 時間、位置或片長不合法 | 阻擋 | `觀看進度資料不正確，請重新開啟影片。` | HTTP 400/409 |
| 投票 | 尚未達 80% | 阻擋 | `請先有效觀看這支影片達 80%。` | HTTP 409 |
| 投票 | Cookie 不存在 | 非阻擋 | 不顯示；重新發放 DeviceId 後繼續投票 | DeviceCookieStatus.Missing |
| 投票 | Cookie 格式或簽章無效 | 非阻擋 | 投票成功仍顯示 `投票成功，謝謝你的參與。` | `RiskEvents.Kind=device_cookie_invalid` |
| 投票 | 無法辨識 device signal | 阻擋 | `無法辨識裝置環境，請重新整理後再試。` | HTTP 400 |
| 投票 | CAPTCHA 未通過 | 阻擋 | `機器人驗證未通過，請重新勾選。` | HTTP 403 |
| 投票 | 不在活動期間 | 阻擋 | `目前不在投票期間。` | HTTP 403 |
| 投票 | 作品不存在／未開放 | 阻擋 | `找不到這支作品。` | HTTP 409 |
| 投票 | 同一作品已有票 | 阻擋 | `你已經投過這支作品。` 或 `此裝置與網路環境已投過這支作品。` | HTTP 409 |
| 投票 | 同組兩票已滿 | 阻擋 | `個人組已使用兩票，投票送出後無法取消或改投。`（團體組同理） | HTTP 409 |
| 投票 | 操作頻率過高 | 可恢復 | `操作過於頻繁，請稍後再試。` | HTTP 429、Retry-After: 60 |
| 投票 | 交易／唯一索引衝突 | 可恢復 | `投票狀態已變更，請重新整理。` | HTTP 409 |
| 投票 | 未分類錯誤 | 可恢復 | `投票失敗。` | Browser network／Server 500 |
| 成功 | 新增觀看紀錄及投票成功 | 成功 | `投票成功，謝謝你的參與。` | HTTP 201 |

## Debug 必查資料

1. Client：`localStorage.greencare-client-watch-v1` 的 `videoId`、`youtubeId`、`duration`、`watchedSeconds`、`lastPosition`、`updatedAt`。
2. Network：`/api/watch/start`、`/api/watch/client-sync`、`/api/votes` 的狀態碼與 response body。
3. Cookie：`vote_device` 是否存在、是否每次 request 都變更；不得複製 Cookie 原值到工單或日誌。
4. Database：`Devices`、`WatchSessions`、`Votes`、`RiskEvents` 的建立時間與關聯 ID。
5. 無效 Cookie：確認 `RiskEvents.Kind=device_cookie_invalid`，`DetailJson={"reissued":true}`。
