# reCAPTCHA 彈窗相容性修正與 AI 開發避坑指南

> 更新日期：2026-10-14
>
> 適用專案：GreenCare 影片投票網站
>
> 用途：交接給後續開發者或 AI agent，避免再次引入相同問題。

## 1. 結論先行

本次問題不是 reCAPTCHA 第一層方塊載入失敗，而是作品觀看視窗使用 `<dialog>.showModal()` 後，Google 動態加到 `document.body` 的第二層 challenge iframe 被瀏覽器 top layer 擋住或變成不可互動。

必要原則：

1. 作品觀看視窗必須使用 `HTMLDialogElement.show()`，不可改回 `showModal()`。
2. 作品視窗的遮罩、固定定位、背景捲動鎖定、Esc 與焦點管理由前端自行實作。
3. 投票確認視窗可以繼續使用 `showModal()`，因為它不包含 reCAPTCHA。
4. Google 第二層 challenge 必須能顯示在作品視窗上方。
5. 第一層 reCAPTCHA 與刷新按鈕的 RWD 應依內容欄實際寬度處理，不可只看 viewport。

## 2. 使用者症狀

- 「我不是機器人」正常出現。
- 點擊後短暫轉圈，隨後回到未勾選。
- 點擊後完全沒有可見反應。
- 重新整理後依然無法完成驗證。
- 桌機可能正常，iPhone Safari、LINE 內建瀏覽器等環境較容易發生。

看到第一層方塊不代表整個驗證流程正常。Google 若判斷需要加驗，還會建立第二層圖片或訊息 challenge。

## 3. 根本原因

原本作品視窗使用：

```ts
watchDialog.value?.showModal()
```

`showModal()` 會讓 dialog 進入瀏覽器 top layer，並使 dialog 外的內容成為 inert。第一層核取方塊位於作品 dialog 內，所以看得到也點得到；第二層 challenge iframe 則由 Google 加到 `document.body`，位於 dialog 外。

一般 `z-index` 無法超越 top layer，因此即使 challenge iframe 已建立，也可能：

- 被作品視窗蓋住。
- 看不到但實際存在。
- 位於 inert 區域，無法點擊。
- 造成第一層方塊轉圈後恢復未勾選。

iPhone Safari 的 ITP、第三方 Cookie 限制、私密瀏覽或 iCloud 私密轉送可能讓 Google 更常要求第二層挑戰，因此較容易暴露此問題。

## 4. 已完成的根因驗證

本機建立 reCAPTCHA Enterprise Checkbox 測試金鑰，設定：

- 網域：`localhost`。
- 測試用途。
- 分數：`0.0`。
- 挑戰類型：`Unsolvable challenge`。

結果：

1. 使用 `showModal()` 時，點擊方塊後看不到第二層挑戰。
2. 改成 `show()` 後，Google「請稍後再試」測試 challenge 正常顯示在作品視窗上方。

`Unsolvable challenge` 本來就不能通過。測試目的是確認第二層視窗能否顯示與操作，不是完成投票。

## 5. 最終修正架構

### 5.1 Dialog 行為

作品視窗：

```ts
watchDialog.value?.show()
```

投票確認視窗：

```ts
confirmDialog.value?.showModal()
```

請勿混用。作品視窗內含 reCAPTCHA，不可進入 top layer；確認框需要蓋在作品視窗上方，保留 `showModal()` 是正確的。

### 5.2 自行補回 modal 體驗

目前已實作：

- `.watch-backdrop` 全畫面半透明模糊遮罩。
- `.watch-dialog[open]` 使用 `position: fixed` 固定置中。
- 手機版維持滿版作品視窗。
- 點擊遮罩可關閉。
- Esc 可關閉；確認框開啟時 Esc 優先交給確認框。
- 開啟時保存原焦點並聚焦關閉按鈕。
- 基本 Tab focus trap。
- 關閉後恢復原焦點。
- 開啟時鎖定背景捲動。
- 關閉後恢復原捲動位置及 body inline style。
- 元件卸載時清除監聽器與捲動鎖定。
- 切換上一部／下一部時避免重複呼叫 `show()`。

主要檔案：

- `src/greencare-web/src/VotingDialogs.vue`
- `src/greencare-web/public/styles.css`
- `src/greencare-web/src/VotingDialogs.spec.ts`

### 5.3 疊放順序

```css
.watch-backdrop { z-index: 900; }
.watch-dialog[open] { z-index: 901; }
```

Google challenge 可位於其上。不要把作品視窗設成極端大的 z-index，也不要重新放回 top layer。

## 6. 手機與平板 RWD

### 6.1 為什麼只寫手機斷點不夠

標準 Checkbox 約寬 `304px`，旁邊另有 `40–44px` 刷新按鈕和間距。iPhone SE 容易寬度不足；iPad 雖然 viewport 很寬，但雙欄作品視窗的右側資訊欄仍可能很窄。

因此不能只依：

```css
@media (max-width: 420px)
```

判斷，還必須依 `.captcha-support` 實際容器寬度調整。

### 6.2 目前容器斷點

| 驗證區塊寬度 | 顯示方式 |
|---|---|
| 大於 370px | 原尺寸 |
| 370px 以下 | 約 92% |
| 330px 以下 | 約 86% |
| 295px 以下 | 約 76% |
| 270px 以下 | 約 68%，刷新按鈕可換到下一列右側 |

設計原則：

- 刷新按鈕不可覆蓋核取方塊。
- 不可超出內容欄。
- 按鈕維持約 `40–44px` 點擊範圍。
- 第二層 Google challenge 不套用第一層的縮放規則。

### 6.3 DevTools 雙重縮放陷阱

目前窄容器使用 CSS `transform: scale()` 縮放第一層 reCAPTCHA。Chrome DevTools 若又選擇 `Fit to window`，會同時存在：

1. 頁面 CSS 縮放。
2. DevTools 對整台模擬裝置縮放。

跨網域 iframe 可能因此在 DevTools 出現點擊座標偏移：看得到方塊，但點擊沒反應。排查方式：

1. 將 Device Toolbar 從 `Fit to window` 改成 `100%`。
2. 強制重新整理。
3. 改用 `Responsive`，手動輸入相同尺寸做對照。
4. 最終以真實 iPad／iPhone 實機為準。

如果真實裝置仍有點擊錯位，再考慮移除 iframe transform，讓刷新按鈕換行，或改用 Google compact 尺寸。

## 7. 不建議採用的替代方案

### 改用 `vue3-recaptcha2`

不建議。套件主要包裝一般 reCAPTCHA v2，無法解決 top layer 根因，並可能讓目前 Enterprise 整合倒退。

### 只提高 z-index

無效。一般 z-index 無法超越瀏覽器 top layer。

### 只要求使用者重新整理

只能處理偶發 script 載入問題，不能修復 `showModal()` 遮住 challenge。刷新按鈕是容錯，不是根因修正。

### 到 80% 才開始載入 Google JavaScript

會增加達標後才下載與初始化造成的等待或失敗。目前策略為：

1. 開啟作品時預載 reCAPTCHA JavaScript。
2. 進度達 80% 才 render 並顯示方塊。
3. 投票資格仍維持 80%，不提前開放。

## 8. 測試方式

### 8.1 自動測試

```powershell
cd D:\greencare\src\greencare-web
npm test -- --run
npm run build
```

本次完成時：

- 5 個測試檔通過。
- 23 項測試通過。
- TypeScript 檢查通過。
- Vite production build 通過。

`jsdom` 沒有完整實作 `HTMLDialogElement.show()`，測試設定必須保留：

```ts
HTMLDialogElement.prototype.show = vi.fn(function () {
  this.setAttribute('open', '')
})
```

後續應補一項專屬回歸測試，明確確認作品視窗呼叫 `show()`、不呼叫 `showModal()`，且遮罩與 Esc 關閉正常。

### 8.2 建議裝置尺寸

- `320 × 568`：極小手機。
- `375 × 667`：iPhone SE。
- `390 × 844`：iPhone 14。
- `844 × 390`：手機橫向。
- `768 × 1024`：一般平板。
- `820 × 1180`：iPad Air 類型。
- `1032 × 1376`：iPad Pro 13。
- 平板橫向與分割畫面。

除模擬器外，至少完成一次真實 iPhone Safari 驗收。

## 9. 正式部署注意事項

本次 dialog 修正全部位於前端，不涉及後端 API、資料庫、投票資格或後端 reCAPTCHA 驗證，可只部署 `wwwroot`。

專案已排除 Development／Testing 設定：

```xml
<Content Update="appsettings.Development.json" CopyToPublishDirectory="Never" />
<Content Update="appsettings.Testing.json" CopyToPublishDirectory="Never" />
```

本機強制挑戰 Site Key 只能留在 `appsettings.Development.json`，不得放入 Production。

前端 ZIP 應確認：

- 根目錄直接包含 `index.html` 和 `assets/`。
- 不含 `appsettings*.json`。
- 不含 `web.config`。
- 不含 DLL 或 PDB。
- 部署前先備份原本 `wwwroot`。
- 部署後用無痕視窗或清除快取驗收。

## 10. 後續 AI agent 修改前必查清單

- [ ] 沒有把作品 dialog 改回 `showModal()`。
- [ ] 投票確認 dialog 仍可使用 `showModal()`。
- [ ] Google challenge 能位於作品視窗上方。
- [ ] 沒有用極端 z-index 蓋住 Google challenge。
- [ ] 新增祖先 `transform`、`filter`、`contain` 前，已檢查 fixed containing block。
- [ ] 若祖先開始影響定位，評估將作品 dialog／遮罩 Teleport 到 `body`。
- [ ] 切換作品不會重複呼叫 `show()` 或重複鎖定 body。
- [ ] close 與 unmount 都會恢復 body style。
- [ ] 確認框開啟時，Esc 不會誤關作品視窗。
- [ ] 焦點不會跑到背景，關閉後會回到原控制項。
- [ ] 第一層 reCAPTCHA 與刷新按鈕不重疊、不溢出。
- [ ] RWD 同時考慮容器寬度和 viewport。
- [ ] DevTools 使用 `100%` 排除 `Fit to window` 點擊偏移。
- [ ] 已在真實 iPhone Safari 測試第二層 challenge。
- [ ] Development 測試金鑰沒有進入 Production。
- [ ] `npm test -- --run` 與 `npm run build` 都通過。

## 11. 仍需持續觀察

1. DevTools iPad `Fit to window` 可能造成 iframe 點擊偏移，先以 100% 或實機確認。
2. 若真實 iOS 因 CSS transform 點擊錯位，優先取消 transform，改用換行或 compact 模式。
3. Safari 動態網址列會改變可視高度，第二層 challenge 仍需實機驗收。
4. 現有提示文字為：「勾選沒反應？請點右側刷新圖示重新整理，或改用手機預設瀏覽器開啟。」穩定上線後可再評估是否縮短。
5. 建議新增禁止作品視窗使用 `showModal()` 的專屬自動回歸測試。
