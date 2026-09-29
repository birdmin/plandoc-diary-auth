-- ============================================================
-- 플랜두씨 다이어리 · 과제 7 (인증) 마이그레이션
-- Supabase SQL Editor에서 아래 STEP 순서대로 실행하세요.
-- STEP 1과 STEP 3 사이에 "반드시" 순서가 있습니다 (아래 안내 참고).
-- ============================================================


-- ============================================================
-- STEP 1. 모든 데이터 테이블에 user_id 컬럼 추가
--   - default auth.uid() 를 걸어두면, 로그인한 사용자가 insert할 때
--     클라이언트 코드(app.js, todo.js, log.js, review.js 등)를
--     하나도 고치지 않아도 자동으로 소유자가 기록됩니다.
--   - 지금은 아직 not null이 아닙니다 (기존 데이터가 있기 때문).
--     STEP 2에서 기존 데이터를 채운 뒤 STEP 3에서 not null로 잠급니다.
-- ============================================================

alter table plans          add column if not exists user_id uuid default auth.uid() references auth.users(id);
alter table plan_history   add column if not exists user_id uuid default auth.uid() references auth.users(id);
alter table todos          add column if not exists user_id uuid default auth.uid() references auth.users(id);
alter table execution_logs add column if not exists user_id uuid default auth.uid() references auth.users(id);
alter table plan_reviews   add column if not exists user_id uuid default auth.uid() references auth.users(id);
alter table reviews        add column if not exists user_id uuid default auth.uid() references auth.users(id);


-- ============================================================
-- STEP 2. (여기서 잠깐 멈추세요 — SQL이 아니라 화면에서 할 일입니다)
--
--   1) 배포한 앱(또는 로컬)에서 "가입"으로 본인 계정을 하나 만듭니다.
--   2) Supabase 대시보드 → Authentication → Users 에서 방금 만든
--      계정의 UUID를 복사합니다. (예: 3fa4c1a2-....)
--   3) 아래 UPDATE 문의 '여기에-내-UUID-붙여넣기' 부분을 그 값으로
--      바꿔서 실행합니다. (6번에서 만든 기존 데이터를 전부 그
--      계정 소유로 옮기는 단계 — 과제 T07-C100)
--
--   ⚠ 이 UPDATE는 한 번만 실행하세요. 두 번째 계정을 또 만들어
--      테스트할 때는 그 계정 것까지 덮어쓰지 않도록 주의하세요.
-- ============================================================

update plans          set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;
update plan_history   set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;
update todos          set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;
update execution_logs set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;
update plan_reviews   set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;
update reviews        set user_id = '여기에-내-UUID-붙여넣기' where user_id is null;

-- 확인: 아래 결과가 전부 0이어야 STEP 3으로 넘어갈 수 있습니다.
select
  (select count(*) from plans          where user_id is null) as plans_null,
  (select count(*) from plan_history   where user_id is null) as plan_history_null,
  (select count(*) from todos          where user_id is null) as todos_null,
  (select count(*) from execution_logs where user_id is null) as execution_logs_null,
  (select count(*) from plan_reviews   where user_id is null) as plan_reviews_null,
  (select count(*) from reviews        where user_id is null) as reviews_null;


-- ============================================================
-- STEP 3. user_id를 필수로 잠그고, RLS를 auth.uid() 기준으로 좁힘
--   - STEP 2의 확인 쿼리가 전부 0일 때만 이 블록을 실행하세요.
--   - anon 역할의 권한/정책을 전부 걷어내고 authenticated만 남깁니다.
-- ============================================================

alter table plans          alter column user_id set not null;
alter table plan_history   alter column user_id set not null;
alter table todos          alter column user_id set not null;
alter table execution_logs alter column user_id set not null;
alter table plan_reviews   alter column user_id set not null;
alter table reviews        alter column user_id set not null;

-- ---- anon 권한 전부 회수 ----
revoke all on public.plans          from anon;
revoke all on public.plan_history   from anon;
revoke all on public.todos          from anon;
revoke all on public.execution_logs from anon;
revoke all on public.plan_reviews   from anon;
revoke all on public.reviews        from anon;

-- ---- authenticated 권한 재부여 (기존과 동일한 동작 범위, 대상만 authenticated로) ----
grant select, insert, update         on public.plans          to authenticated;
grant select, insert                 on public.plan_history   to authenticated;
grant select, insert, update, delete on public.todos          to authenticated;
grant select, insert                 on public.execution_logs to authenticated;
grant select, insert, update         on public.plan_reviews   to authenticated;
grant select, insert                 on public.reviews        to authenticated;

-- ---- 기존 anon 정책 전부 제거 ----
drop policy if exists "anon_select_plans" on plans;
drop policy if exists "anon_insert_plans" on plans;
drop policy if exists "anon_update_plans" on plans;
drop policy if exists "anon_select_plan_history" on plan_history;
drop policy if exists "anon_insert_plan_history" on plan_history;
drop policy if exists "anon_select_todos" on todos;
drop policy if exists "anon_insert_todos" on todos;
drop policy if exists "anon_update_todos" on todos;
drop policy if exists "anon_delete_todos" on todos;
drop policy if exists "anon_select_execution_logs" on execution_logs;
drop policy if exists "anon_insert_execution_logs" on execution_logs;
drop policy if exists "anon_select_plan_reviews" on plan_reviews;
drop policy if exists "anon_insert_plan_reviews" on plan_reviews;
drop policy if exists "anon_update_plan_reviews" on plan_reviews;
drop policy if exists "anon_select_reviews" on reviews;
drop policy if exists "anon_insert_reviews" on reviews;

-- ---- 새 authenticated 전용 정책: 반드시 "내 user_id" 행만 ----

-- plans
create policy "own_select_plans" on plans
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_plans" on plans
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own_update_plans" on plans
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- plan_history
create policy "own_select_plan_history" on plan_history
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_plan_history" on plan_history
  for insert to authenticated with check (auth.uid() = user_id);

-- todos
create policy "own_select_todos" on todos
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_todos" on todos
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own_update_todos" on todos
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_delete_todos" on todos
  for delete to authenticated using (auth.uid() = user_id);

-- execution_logs
create policy "own_select_execution_logs" on execution_logs
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_execution_logs" on execution_logs
  for insert to authenticated with check (auth.uid() = user_id);

-- plan_reviews
create policy "own_select_plan_reviews" on plan_reviews
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_plan_reviews" on plan_reviews
  for insert to authenticated with check (auth.uid() = user_id);
create policy "own_update_plan_reviews" on plan_reviews
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- reviews
create policy "own_select_reviews" on reviews
  for select to authenticated using (auth.uid() = user_id);
create policy "own_insert_reviews" on reviews
  for insert to authenticated with check (auth.uid() = user_id);

-- ============================================================
-- 참고: usage 권한(anon, authenticated 모두에게 부여됐던 것)은
-- 스키마 자체에 대한 것이라 굳이 anon에서 회수할 필요는 없습니다.
-- 실제 데이터 접근은 위 테이블 GRANT + RLS가 이미 막고 있습니다.
-- ============================================================
