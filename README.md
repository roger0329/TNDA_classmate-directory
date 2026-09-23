# 同學錄 — 部署到 GitHub Pages 教學

這個資料夾裡的 `index.html` 就是完整的網頁。把它放上 GitHub、開啟 GitHub Pages，
就能得到一個網址讓同學自己加入照片、姓名、LinkedIn、標籤，**之後也能自己回來修改**。

整體架構：**Supabase(免費資料庫) → 網頁直接讀寫**。
同學不需要碰 GitHub，只要打開網址、按右上角「＋ 加入我的資料」填資料就好；
你只需要設定一次。

---

## 第一步：建立 Supabase 專案

1. 到 [supabase.com](https://supabase.com) 用 GitHub 或 Email 註冊、登入。
2. 「New project」→ 隨便取個名字(例如 `classmate-directory`)、
   設一組資料庫密碼(存好，之後用不到但要留著)、選一個離你近的地區 → 「Create new project」。
3. 等 1-2 分鐘讓專案建立完成。

## 第二步：執行資料庫設定

1. 左側選單點「SQL Editor」→「New query」。
2. 打開這個資料夾裡的 `supabase-setup.sql`，把**整份內容**複製貼上到編輯框裡。
3. 按右下角「Run」執行。跑完不會有錯誤訊息就代表成功
   (畫面上會建立一個 `students` 資料表、一個 `photos` 儲存空間、還有幾條安全性規則)。

> 這份 SQL 只需要執行**一次**。之後同學交的每一筆資料都會自動存進這個資料庫。

## 第三步：把金鑰貼進網頁

1. Supabase 專案左側選單「Project Settings」(齒輪圖示) →「API」。
2. 找到「Project URL」和「anon public」這兩個值，分別複製起來。

   > 「anon public」是設計給網頁前端直接使用的公開金鑰，不是機密資料，
   > 可以放心貼到 `index.html` 裡。千萬不要用「service_role」那組(那組才是機密)。

3. 用文字編輯器打開這個資料夾裡的 `index.html`，搜尋 `SUPABASE_URL`，
   你會看到這兩行(大約在檔案中段)：
   ```js
   var SUPABASE_URL = "";
   var SUPABASE_ANON_KEY = "";
   ```
4. 分別貼進兩個引號中間，存檔：
   ```js
   var SUPABASE_URL = "https://xxxxxxxxxxxx.supabase.co";
   var SUPABASE_ANON_KEY = "eyJhbGciOiJI...(一長串)";
   ```

## 第四步：把網頁放上 GitHub Pages

不需要安裝任何工具，全部用網頁操作即可：

1. 到 [github.com](https://github.com)，登入帳號，右上角「+」→「New repository」。
2. Repository name 隨便取(例如 `classmate-directory`)，設成 **Public**，按「Create repository」。
3. 進到新建立的 repo 頁面 → 「Add file」→「Upload files」。
4. 把改好的 `index.html` 拖進去上傳(不用上傳 `.sql` 檔和這份 README，那兩個是給你自己看的)，
   下方寫個 commit message，按「Commit changes」。
5. 到 repo 的「Settings」→ 左側選單「Pages」。
6. 「Build and deployment」的「Source」選「Deploy from a branch」，
   Branch 選 `main` / `/(root)`，按「Save」。
7. 等 1-2 分鐘，重新整理這個 Pages 設定頁，上面會出現網址，長得像：
   ```
   https://你的帳號.github.io/classmate-directory/
   ```
   這就是同學會看到的網址。

## 測試方式

自己先打開這個網址，按右上角「＋ 加入我的資料」，填一筆測試資料
(姓名、Email、編輯密碼都填)，送出後關閉視窗，應該就會看到自己的 CD 出現在頁面上。
再試著用剛剛填的 Email + 密碼點「修改已提交的資料」，確認可以查到、改到剛剛那筆。

---

## 同學要怎麼加入 / 修改資料？

- **加入資料**：打開網址 → 右上角「＋ 加入我的資料」→「新增資料」分頁 →
  填姓名、Email、自訂一組編輯密碼、LinkedIn、作品集、一句話介紹、最多 5 個標籤、上傳照片 → 送出。
- **修改資料**：同一個按鈕 →「修改已提交的資料」分頁 → 輸入當初填的 Email + 編輯密碼 →
  查詢成功後就能改內容(換照片、改標籤等)並重新送出。
- 新增或修改後，網頁會立刻重新整理清單，不需要你重新部署或做任何事。

## Supabase 專案太久沒用會被暫停，怎麼辦？

Supabase 免費方案有個規則：專案連續 **7 天沒有任何 API 請求**(例如放寒暑假、沒人開網頁)，
就會自動被「暫停(pause)」。暫停不會刪除任何資料，只是網頁會暫時讀不到資料庫，
到 Supabase 後台按一下「Restore」就能立刻復原，資料完全還在。

如果不想每次放假回來還要手動復原，這個資料夾裡多附了一個
`.github/workflows/keep-supabase-awake.yml`，是一個免費的 GitHub Actions 排程，
每 3 天會自動幫你的 Supabase 專案打一次 API，讓它一直保持在使用中的狀態，
之後就完全不用管它了。設定方式：

1. 打開 `.github/workflows/keep-supabase-awake.yml`，把裡面 `YOUR_PROJECT_URL` 和
   `YOUR_ANON_KEY` 換成你在 `index.html` 裡 `SUPABASE_URL` / `SUPABASE_ANON_KEY`
   填的同一組值。
2. 把整個 `.github` 資料夾(包含裡面的子資料夾結構)跟 `index.html` 一起上傳到
   同一個 GitHub repo(用「Add file → Upload files」，把資料夾整包拖進去即可，
   GitHub 會自動照原本的資料夾路徑建立)。
3. 上傳後到 repo 上方的「Actions」分頁確認這個排程有出現，之後就會自動照排程跑，
   不需要再做任何事。也可以在那個分頁手動點一次「Run workflow」先測試看看。

## 關於安全性，誠實的提醒

編輯密碼(PIN)是為了**避免同學不小心互相覆蓋資料**設計的輕量防呆機制，
適合教室內部這種互信環境使用，但它**不是真正的帳號驗證**：

- 同學的 Email 和編輯密碼不會透過網頁公開顯示(存在資料庫裡，網頁只讀取姓名、標籤、連結等公開欄位)。
- 但因為這是「後端免伺服器」的靜態網站，使用的是可公開的 anon 金鑰，
  技術上比較熟悉的人仍有可能繞過網頁介面，直接呼叫 Supabase 的 API 修改資料
  (Row Level Security 目前是設定成「任何人都能更新」，密碼檢查只發生在網頁的查詢流程裡)。
- 如果之後想要更嚴謹的保護(例如要求同學用 Email 收驗證信才能編輯)，
  可以進一步串接 Supabase Auth(Magic Link 登入)，這需要額外設定，
  目前這個版本沒有包含，若有需要歡迎再問。

對一個學期性質、內部使用的班級同學錄來說，這個折衷是合理的；
但這不是能承受被惡意破壞、需要強保護的正式系統。

---

## 之後想換照片儲存空間的免費額度用完怎麼辦？

Supabase 免費方案有 1GB 的 Storage 額度，一般班級規模(幾十張大頭照)完全夠用。
如果之後真的接近額度上限，可以到 Supabase 專案的「Storage」→「photos」裡刪除舊照片，
或升級付費方案。

---

## 附錄：如果不想用資料庫，改用 Google 表單(唯讀，不能事後修改)

如果你不想申請 Supabase 帳號，也可以退回最簡單的版本：用 Google 表單收資料、
Google 試算表存資料、網頁讀取顯示。缺點是同學事後想改資料，只能你手動去試算表改，
網頁本身沒有「修改」功能。

作法：把 `index.html` 裡 `SUPABASE_URL` 保持空白，改填 `SHEET_CSV_URL`。
詳細的 Google 表單建立步驟(題目名稱、檔案上傳權限設定等)如果需要，
可以再回來問我，我會補上完整的操作教學。
