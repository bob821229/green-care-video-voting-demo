# iPhone Safari：reCAPTCHA 無法勾選的原因分析與修正

> 撰寫日期：2026-10-14
> 撰寫者：Claude Code（Opus 5.5）
> 用途：交給 Codex 再驗證一次
> 分支：`codex/client-progress-resilient-voting`（修改**尚未 commit**）

---

## 1. 問題描述

- 使用環境：**iPhone 17 + Safari**
- 狀況：
  - 「我不是機器人」驗證方塊正常顯示，也點得到。
  - 點了之後方塊**轉一下圈，或完全沒反應**，就是勾不起來。
  - 重新整理後一樣：點得到，但勾不起來。

---

## 2. 原因分析

這個推論是讀程式碼得出的，**還沒在 iPhone 實機上確認**。

### 2.1 相關程式碼

- `src/greencare-web/src/VotingDialogs.vue`
  - `open()` 用 `watchDialog.value?.showModal()` 開啟觀看視窗（`<dialog class="watch-dialog">`）。
  - reCAPTCHA Enterprise 是 checkbox 型，用 `grecaptcha.enterprise.render(captchaBox, {...})` 顯示在觀看視窗**裡面**的 `.recaptcha-box`。

### 2.2 為什麼勾不起來

1. 用 `showModal()` 開的 `<dialog>` 會被瀏覽器放進 **top layer**（最上層）。dialog 以外的頁面都會被設為 **inert**：看不到、也點不到。
2. 勾選方塊時，如果 Google 判斷風險偏高，會要求加驗「選圖片」。圖片挑戰框（`bframe` iframe）會被 reCAPTCHA 加在 **`document.body` 底下**，位置在 dialog 外面。它的 `z-index` 是 2000000000，但 top layer 一定蓋在 z-index 上面。
3. 結果圖片挑戰框被觀看視窗蓋住，而且點不到。使用者看到的就是：**轉一下圈 → 沒反應 → 一直沒打勾**。
4. 重新整理後 Google 一樣要求加驗，所以問題會重複出現。

### 2.3 為什麼特別是 iPhone Safari

| 使用者 | Google 的判斷 | 結果 |
|---|---|---|
| 一般桌機或 Chrome（有 Google cookie） | 風險低，直接通過，不需要選圖片 | 正常勾選 |
| iPhone Safari（會擋追蹤 ITP、擋第三方 cookie、可能開 iCloud 私密轉送） | 認不出使用者，常要求選圖片 | 圖片挑戰框被蓋住，**勾不起來** |

這也說明為什麼只有部分使用者遇到，在開發環境不容易重現。

---

## 3. 修正方式

**核心做法：觀看視窗改用 `show()`（non-modal）開啟，不再用 `showModal()`**，讓它離開 top layer。這樣 reCAPTCHA 放在 `<body>` 的挑戰框（z-index 2000000000）就能蓋在觀看視窗（z-index 1000）上面。

改成 non-modal 後，`showModal()` 原本提供的功能要自己補：

| `showModal()` 原本的行為 | 改用 `show()` 後的替代做法 |
|---|---|
| `::backdrop` 半透明模糊背景 | 新增 `<div class="watch-backdrop">` |
| 背景不能點 | 遮罩蓋住全畫面 |
| 按 Esc 觸發 `cancel` 事件 | 在 `document` 監聽 `keydown`，按 Esc 就呼叫 `close()` |
| 自動置中、固定在畫面上 | CSS：`position:fixed; inset:0; margin:auto` |
| 輔助技術把它當成 modal | 加上 `aria-modal="true"` |
| （額外）背景不捲動 | 開啟時在 `<html>` 加上 `watch-dialog-open` class，設定 `overflow:hidden` |

**投票確認框（`confirmDialog`）不改，還是用 `showModal()`**。它出現時不涉及 reCAPTCHA，而且它在 top layer 蓋住觀看視窗也是正確的。

---

## 4. 修改內容

> 這幾個檔案在我修改前就已經有其他未 commit 的變更，所以 `git diff` 會混在一起。以下只列出**這次修正**加入的部分。

### 4.1 `src/greencare-web/src/VotingDialogs.vue`

**(a) 新增狀態（約第 18–20 行，接在 `captchaLoadPromise` 宣告後面）**

```ts
let captchaLoadPromise:Promise<void>|null=null
// The watch dialog is shown non-modally: reCAPTCHA appends its image-challenge iframe to <body>, which a showModal() top-layer dialog would cover and make inert.
const watchOpen=ref(false)
```

**(b) `open()`：不再用 `showModal()`**

```diff
- ...;syncUrl(video.id);watchDialog.value?.showModal();...
+ ...;syncUrl(video.id);showWatchDialog();...
```

**(c) `close()`，以及新增的三個函式（約第 159–162 行）**

```diff
- ...;player.value=null;watchDialog.value?.close();syncUrl()}
+ ...;player.value=null;hideWatchDialog();syncUrl()}
```

```ts
function showWatchDialog(){if(!watchDialog.value?.open)watchDialog.value?.show();watchOpen.value=true;document.documentElement.classList.add('watch-dialog-open');document.addEventListener('keydown',watchKeydown)}
function hideWatchDialog(){watchDialog.value?.close();watchOpen.value=false;document.documentElement.classList.remove('watch-dialog-open');document.removeEventListener('keydown',watchKeydown)}
function watchKeydown(event:KeyboardEvent){if(event.key==='Escape'&&watchOpen.value&&!confirmDialog.value?.open){event.preventDefault();close()}}
```

說明：
- `showWatchDialog()` 會先檢查 `open`。切換上一部、下一部影片時會再呼叫一次 `open()`，這樣不會重複呼叫 `show()`。
- 按 Esc 時，如果確認框正開著，就不關閉觀看視窗，交給確認框自己的 `@cancel` 處理。

**(d) `onBeforeUnmount` 時清除監聽和 class**

```diff
- onBeforeUnmount(()=>{playerGeneration++;...
+ onBeforeUnmount(()=>{playerGeneration++;document.removeEventListener('keydown',watchKeydown);document.documentElement.classList.remove('watch-dialog-open');...
```

**(e) Template：加上遮罩和 `aria-modal`**

```diff
+  <div v-if="watchOpen" class="watch-backdrop" aria-hidden="true"></div>
-  <dialog ref="watchDialog" class="watch-dialog" :data-category="current?.category" @cancel.prevent="close">
+  <dialog ref="watchDialog" class="watch-dialog" aria-modal="true" :data-category="current?.category" @cancel.prevent="close">
```

### 4.2 `src/greencare-web/public/styles.css`（加在檔案最後）

```css
/* The watch dialog opens non-modally so reCAPTCHA's challenge iframe (z-index 2000000000 on <body>) can appear above it. */
.watch-dialog{position:fixed;inset:0;margin:auto;z-index:1000}
.watch-backdrop{position:fixed;inset:0;z-index:999;background:rgba(45,43,32,.82);backdrop-filter:blur(7px);-webkit-backdrop-filter:blur(7px)}
html.watch-dialog-open,html.watch-dialog-open body{overflow:hidden}
```

遮罩的顏色和模糊程度，沿用原本 `dialog::backdrop` 的設定（`rgba(45,43,32,.82)` / `blur(7px)`）。

### 4.3 `src/greencare-web/src/VotingDialogs.spec.ts`

**(a) `beforeAll` 加上 `show()` 的 mock（jsdom 沒有實作）**

```ts
HTMLDialogElement.prototype.show=vi.fn(function(this:HTMLDialogElement){this.setAttribute('open','')})
```

**(b) 新增測試**

```ts
it('opens the watch dialog non-modally so the reCAPTCHA challenge can appear above it',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,status:200,json:async()=>({sessionId:'watch-session'})}))
  const wrapper=mount(VotingDialogs,{props:{data:structuredClone(base)},attachTo:document.body})
  const dialog=wrapper.find('dialog.watch-dialog').element as HTMLDialogElement
  vi.mocked(HTMLDialogElement.prototype.showModal).mockClear()
  await (wrapper.vm as unknown as {open:(id:number)=>Promise<void>}).open(2)
  await flushPromises()

  expect(HTMLDialogElement.prototype.showModal).not.toHaveBeenCalled()
  expect(dialog.hasAttribute('open')).toBe(true)
  expect(wrapper.find('.watch-backdrop').exists()).toBe(true)

  document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}))
  await flushPromises()
  expect(dialog.hasAttribute('open')).toBe(false)
  expect(wrapper.find('.watch-backdrop').exists()).toBe(false)
  wrapper.unmount()
})
```

---

## 5. 測試結果

在 `src/greencare-web` 底下執行：

| 指令 | 結果 |
|---|---|
| `npx vitest run` | 5 個測試檔、24 個測試全部通過 |
| `npx vue-tsc -b` | 沒有型別錯誤（exit 0） |

**還沒做**：iPhone 實機測試、桌機瀏覽器的手動畫面檢查。

---

## 6. 請 Codex 驗證的重點

1. **原因是否正確**：確認 reCAPTCHA（Enterprise checkbox）的圖片挑戰框是不是真的加在 `document.body`，以及被 `showModal()` 的 top layer 和 inert 擋住。
2. **定位是否正確**：`VotingDialogs` 的祖先元素有沒有 `transform`、`filter`、`contain` 等屬性，會讓 `position:fixed` 失效、或產生新的 stacking context（我沒有全部檢查）。如果有，可能要改用 `<Teleport to="body">`。
3. **疊放順序**：頁面上其他元素（導覽列、`body:after` 的 z-index:20 等）的 z-index 是否都小於 999。
4. **YouTube iframe**：改成 `show()` 後播放器和全螢幕功能是否正常，播放器初始化有沒有受影響。
5. **確認框疊在觀看視窗上**：投票時 `confirmDialog.showModal()` 蓋住 non-modal 的觀看視窗，焦點和 Esc 的行為是否正確。
6. **焦點管理**：non-modal dialog 不會把焦點限制在視窗內，用 Tab 可能跑到背景頁面。看是否需要另外加 focus trap。
7. **手機版版面**：`max-width:800px` 時原本是全螢幕（`100vw × 100dvh`，`display:block`），加上 `position:fixed; inset:0; margin:auto` 後是否一樣。
8. **iOS 鎖住背景捲動**：`html, body {overflow:hidden}` 在 iOS Safari 是否有效，觀看視窗本身（`overflow-y:auto`）是否還能捲動。
9. **其他頁面**：`App.vue`、`ResultsPage.vue` 也有 dialog，確認它們沒有用到 reCAPTCHA，不需要一起改。

---

## 7. 實機驗證步驟（建議）

1. 用 iPhone Safari 開啟網站。最好開著 iCloud 私密轉送，或用私密瀏覽，比較容易出現圖片挑戰。
2. 打開任一部影片，看到 80% 以上，讓驗證方塊出現。
3. 點驗證方塊，確認**圖片挑戰框出現在觀看視窗上面，而且可以操作**。
4. 完成挑戰後方塊打勾，可以正常投票。
5. 回歸檢查：
   - 桌機和手機的遮罩外觀和原本一樣。
   - 按 Esc 或關閉按鈕可以關閉視窗。
   - 視窗開著時背景不會捲動。
   - 上一部、下一部切換正常。
   - 投票確認框正常。

桌機重現原本問題的方法：用無痕視窗加 VPN，提高 Google 要求選圖片的機率。

---

## 8. 後續建議

- 目前畫面上的提示「勾選沒反應？請點右側刷新圖示重新整理，或改用手機預設瀏覽器開啟。」，重新整理其實解決不了這個問題。修正上線、確認有效後，建議改寫或拿掉。
