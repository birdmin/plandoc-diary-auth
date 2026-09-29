-- ============================================================
-- 과제 7 · 카드 3 — 로그아웃한 세션의 "예전 토큰"도 DB에서 거절
--
-- 왜 필요한가
--   Supabase Auth의 로그아웃은 갱신용 토큰(refresh token)과 세션은 없애지만,
--   이미 발급된 액세스 토큰(JWT)은 만료 시각(약 1시간)까지 그대로 통과된다
--   (Supabase 문서에 적힌 동작). 그래서 로그아웃 뒤 예전 토큰으로 요청해도
--   받아들여질 수 있다.
--
-- 어떻게 막나
--   액세스 토큰 안에는 어느 세션에서 발급됐는지 알려주는 session_id가 들어 있다.
--   요청이 올 때마다 "그 세션이 아직 살아 있는가"를 auth.sessions에서 확인하고,
--   없으면 거절한다. 기존 정책(auth.uid() = user_id)은 그대로 두고,
--   "AND 이 조건도 통과해야 한다"는 제한(restrictive) 정책을 표마다 하나씩 덧붙인다.
-- ============================================================

-- 1) 세션이 살아 있는지 확인하는 함수
--    auth 스키마는 일반 사용자가 직접 읽을 수 없으므로 security definer로 만든다.
create or replace function public.is_session_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.sessions s
    where s.id = (auth.jwt() ->> 'session_id')::uuid
      and s.user_id = auth.uid()
  );
$$;

revoke all on function public.is_session_active() from public, anon;
grant execute on function public.is_session_active() to authenticated;

-- 2) 6개 표에 제한 정책 덧붙이기
drop policy if exists "require_active_session" on public.plans;
create policy "require_active_session" on public.plans
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

drop policy if exists "require_active_session" on public.plan_history;
create policy "require_active_session" on public.plan_history
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

drop policy if exists "require_active_session" on public.todos;
create policy "require_active_session" on public.todos
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

drop policy if exists "require_active_session" on public.execution_logs;
create policy "require_active_session" on public.execution_logs
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

drop policy if exists "require_active_session" on public.plan_reviews;
create policy "require_active_session" on public.plan_reviews
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

drop policy if exists "require_active_session" on public.reviews;
create policy "require_active_session" on public.reviews
  as restrictive for all to authenticated
  using ((select public.is_session_active()))
  with check ((select public.is_session_active()));

-- ============================================================
-- (참고) 문제가 생겨서 원래대로 되돌리고 싶을 때만 아래를 실행하세요.
--
-- drop policy if exists "require_active_session" on public.plans;
-- drop policy if exists "require_active_session" on public.plan_history;
-- drop policy if exists "require_active_session" on public.todos;
-- drop policy if exists "require_active_session" on public.execution_logs;
-- drop policy if exists "require_active_session" on public.plan_reviews;
-- drop policy if exists "require_active_session" on public.reviews;
-- drop function if exists public.is_session_active();
--
-- (참고) 로그아웃하면 세션 행이 실제로 사라지는지 보는 확인용 쿼리:
-- select id, user_id, created_at from auth.sessions order by created_at desc;
-- ============================================================
