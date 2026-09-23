-- ============================================================
-- 同學錄 — Supabase 資料庫設定
-- 到 Supabase 專案 → 左側選單「SQL Editor」→ New query，
-- 把這整份貼進去，按 Run 執行一次即可。
-- ============================================================

-- 1. 資料表：存放每位同學的資料
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  edit_pin text not null,
  tags text[] not null default '{}',
  bio text default '',
  linkedin text default '',
  portfolio text default '',
  photo_url text default '',
  created_at timestamptz not null default now()
);

-- 2. 打開 Row Level Security(列層級安全性)
alter table students enable row level security;

-- 3. 任何人都可以「新增」一筆自己的資料(交表單用)
create policy "anyone can insert their own row"
  on students for insert
  to anon
  with check (true);

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

-- 5. 公開檢視用的「View」— 只包含要顯示在網頁上的欄位，
--    刻意不包含 email 和 edit_pin，這兩欄不會透過這個 View 被讀到。
create or replace view students_public as
  select id, name, tags, bio, linkedin, portfolio, photo_url, created_at
  from students
  order by created_at asc;

grant select on students_public to anon;

-- 6. 登入驗證函式：網頁呼叫這個函式來檢查 Email + 編輯密碼是否吻合，
--    吻合才回傳資料(不含 edit_pin 本身)，讓同學可以進入編輯畫面。
create or replace function verify_student_login(p_email text, p_pin text)
returns table (
  id uuid, name text, tags text[], bio text,
  linkedin text, portfolio text, photo_url text
)
language sql
security definer
set search_path = public
as $$
  select id, name, tags, bio, linkedin, portfolio, photo_url
  from students
  where email = lower(trim(p_email)) and edit_pin = p_pin;
$$;

grant execute on function verify_student_login(text, text) to anon;

-- 7. Storage：建立一個叫 photos 的公開儲存桶，用來放同學上傳的照片
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

create policy "anyone can upload photos"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'photos');

create policy "anyone can view photos"
  on storage.objects for select
  to anon
  using (bucket_id = 'photos');
