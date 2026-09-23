-- ============================================================
-- 同學錄 — Supabase 資料庫設定
-- 到 Supabase 專案 → 左側選單「SQL Editor」→ New query，
-- 把這整份貼進去，按 Run 執行一次即可。
--
-- 如果你的專案「已經」執行過更早的版本，不用整份重跑，
-- 直接跳到檔案最下面「如果你已經執行過舊版」那一段即可。
-- ============================================================

-- 1. 資料表：存放每位同學的資料
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text unique,
  edit_pin text not null,
  tags text[] not null default '{}',
  bio text default '',
  linkedin text default '',
  portfolio text default '',
  photo_url text default '',
  -- CSS background-position 值，例如 "50% 50%"；同學上傳照片後可以拖曳調整
  -- CD 裁成圓形時要保留照片的哪個部位，這欄就存那個位置。
  photo_pos text default '50% 50%',
  created_at timestamptz not null default now()
);

-- 2. 打開 Row Level Security(列層級安全性)
alter table students enable row level security;

-- 2b. anon 角色需要 INSERT / UPDATE / DELETE 的資料表權限(GRANT)，
--     不然即使 RLS policy 都允許，還是會在權限這關就被擋下來，
--     出現 "permission denied for table students"。
--     注意：這裡「不」把 select 整欄開放給 anon — 下面第 2c 點會另外
--     用「只列出欄位」的方式開放 select，刻意不包含 edit_pin(密碼)，
--     避免同學能直接用 API 讀到別人的密碼。
grant insert, update, delete on students to anon;

-- 2c. anon 也需要能「看到」資料列，UPDATE / DELETE 的 WHERE 條件才找得到
--     要更新/刪除的那一列(這點很容易被忽略：即使 UPDATE / DELETE 的
--     policy 都允許，沒有對應的 SELECT 權限，Postgres 還是會找不到
--     任何一列可以動，導致 UPDATE / DELETE 看起來「成功」但其實
--     完全沒有真的改到/刪到任何資料)。
--     只開放不含 edit_pin 的欄位，避免密碼被直接讀到——
--     公開顯示的名單本來就是走下面第 5 點的 students_public 這個 view。
grant select (id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email, created_at)
  on students to anon;

-- 3. 任何人都可以「新增」一筆自己的資料(交表單用)
create policy "anyone can insert their own row"
  on students for insert
  to anon
  with check (true);

-- 3b. 任何人都可以「看到」資料列(上面第 2c 點已經把實際能讀到的
--     欄位限制在不含密碼)，這條 policy 本身要開，UPDATE / DELETE
--     才能正確找到、影響到目標那一列。
create policy "anyone can select rows"
  on students for select
  to anon
  using (true);

-- 4. 任何人都可以「更新」資料
--    注意：這裡沒有在資料庫層面檢查編輯密碼是否正確，
--    密碼檢查是網頁程式呼叫下面第 6 點的函式先驗證過才會執行更新。
--    這是給教室內部使用的輕量防呆機制，不是真正的帳號驗證，
--    詳見 README.md「關於安全性，誠實的提醒」。
create policy "anyone can update a row"
  on students for update
  to anon
  using (true)
  with check (true);

-- 4b. 任何人都可以「刪除」資料(同學刪除自己帳號用)
--     同樣沒有在資料庫層面檢查密碼，密碼檢查發生在網頁呼叫刪除前
--     先用第 6 點的登入函式驗證過，這是同一套輕量防呆機制。
create policy "anyone can delete a row"
  on students for delete
  to anon
  using (true);

-- 5. 公開檢視用的「View」— 只包含要顯示在網頁上的欄位，
--    刻意不包含 edit_pin，這欄不會透過這個 View 被讀到。
--    email 有包含在內：同學可以選擇要不要填，填了才會顯示在個人頁面上。
drop view if exists students_public;

create view students_public as
  select id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email, created_at
  from students
  order by created_at asc;

grant select on students_public to anon;

-- 6. 登入驗證函式：網頁呼叫這個函式來檢查「姓名 + 編輯密碼」是否吻合，
--    吻合才回傳資料(不含 edit_pin 本身)，讓同學可以進入編輯畫面。
--    (不用 Email 登入，因為 Email 現在是選填欄位。)
create or replace function verify_student_login(p_name text, p_pin text)
returns table (
  id uuid, name text, tags text[], bio text,
  linkedin text, portfolio text, photo_url text, photo_pos text, email text
)
language sql
security definer
set search_path = public
as $$
  select id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email
  from students
  where trim(name) = trim(p_name) and edit_pin = p_pin
  limit 1;
$$;

grant execute on function verify_student_login(text, text) to anon;

-- 7. Storage：建立一個叫 photos 的公開儲存桶，用來放同學上傳的照片
--    file_size_limit / allowed_mime_types 是在資料庫層面真正擋住檔案
--    大小跟檔案類型 — 網頁上「5MB、只能傳圖片」的檢查只發生在瀏覽器端，
--    技術上熟悉的人可以繞過瀏覽器直接呼叫 API 上傳，所以這裡另外用
--    資料庫本身的限制再擋一層。
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "anyone can upload photos"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'photos');

create policy "anyone can view photos"
  on storage.objects for select
  to anon
  using (bucket_id = 'photos');

-- 允許刪除：換照片時，網頁會自動把換掉的舊照片從這裡刪除，
-- 避免同學一直換照片導致 Storage 空間被舊檔案佔滿。
create policy "anyone can delete photos"
  on storage.objects for delete
  to anon
  using (bucket_id = 'photos');

-- ============================================================
-- 如果你已經執行過舊版(不論是最早那版「Email 必填」的，還是
-- 中間那版「改用姓名+密碼登入」但還沒有 photo_pos 的)，
-- 不需要整份重跑，只要在 SQL Editor 開一個新 query，
-- 把下面這一段貼上、按 Run 就會更新成最新版本。
-- 這段可以重複執行，不會出錯。
-- ============================================================

alter table students alter column email drop not null;
alter table students add column if not exists photo_pos text default '50% 50%';

-- 補開資料表本身的操作權限(GRANT)給 anon 角色 — 沒有這行，
-- 即使 RLS policy 都允許，還是會出現 "permission denied for table students"。
-- 如果之前執行過整表 select 的版本(grant select on students to anon)，
-- 這裡先收回，改成下面「只列出欄位、不含 edit_pin」的版本，避免密碼外洩。
revoke select on students from anon;
grant insert, update, delete on students to anon;
grant select (id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email, created_at)
  on students to anon;

do $$ begin
  create policy "anyone can select rows"
    on students for select
    to anon
    using (true);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "anyone can delete a row"
    on students for delete
    to anon
    using (true);
exception when duplicate_object then null;
end $$;

-- create or replace view can only append columns at the end, not insert one
-- in the middle of the existing column order — drop and recreate instead
drop view if exists students_public;

create view students_public as
  select id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email, created_at
  from students
  order by created_at asc;

grant select on students_public to anon;

drop function if exists verify_student_login(text, text);

create function verify_student_login(p_name text, p_pin text)
returns table (
  id uuid, name text, tags text[], bio text,
  linkedin text, portfolio text, photo_url text, photo_pos text, email text
)
language sql
security definer
set search_path = public
as $$
  select id, name, tags, bio, linkedin, portfolio, photo_url, photo_pos, email
  from students
  where trim(name) = trim(p_name) and edit_pin = p_pin
  limit 1;
$$;

grant execute on function verify_student_login(text, text) to anon;

do $$ begin
  create policy "anyone can delete photos"
    on storage.objects for delete
    to anon
    using (bucket_id = 'photos');
exception when duplicate_object then null;
end $$;

-- 補上檔案大小/類型限制的資料庫層面防護(之前的版本只有靠網頁端檢查)
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif']
where id = 'photos';
