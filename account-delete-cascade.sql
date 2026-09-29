-- ============================================================
-- 과제 7 · 카드 5 — 계정을 지우면 자료도 함께 지워지게 하기 (C134)
--
-- 지금은 user_id가 auth.users(id)를 참조하지만 삭제 규칙이 없어서,
-- 계정을 지우려 하면 "그 계정을 참조하는 자료가 남아있다"는 오류로
-- 거절됩니다(외래키 기본값은 NO ACTION). 이 SQL은 참조 방식을
-- ON DELETE CASCADE로 바꿔서, 계정이 지워지는 순간 그 계정의
-- plans/todos/... 행도 함께 지워지도록 만듭니다.
--
-- 실행 후: Authentication → Users에서 계정을 삭제하면(관리자가 지우는
-- 경우) 그 계정의 자료가 전부 함께 사라집니다. 이걸 "계정 삭제 =
-- 자료도 삭제"의 증거로 스크린샷 남기면 됩니다.
-- ============================================================

alter table plans          drop constraint if exists plans_user_id_fkey;
alter table plans          add constraint plans_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table plan_history   drop constraint if exists plan_history_user_id_fkey;
alter table plan_history   add constraint plan_history_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table todos          drop constraint if exists todos_user_id_fkey;
alter table todos          add constraint todos_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table execution_logs drop constraint if exists execution_logs_user_id_fkey;
alter table execution_logs add constraint execution_logs_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table plan_reviews   drop constraint if exists plan_reviews_user_id_fkey;
alter table plan_reviews   add constraint plan_reviews_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table reviews        drop constraint if exists reviews_user_id_fkey;
alter table reviews        add constraint reviews_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

-- ============================================================
-- 참고 — 왜 "계정 삭제" 버튼을 화면에 직접 만들지 않았는지
--
-- Supabase Auth는 보안상, 로그인한 사람이 자기 계정을 직접 지우는
-- API를 클라이언트(브라우저)에서 호출하도록 공개해 두지 않았습니다.
-- 계정 삭제는 service_role(관리자) 권한이 있어야만 가능한데, 그 키를
-- 브라우저 코드에 넣으면 지금까지 만든 모든 잠금이 무의미해집니다.
-- 그래서 이 프로젝트는 "화면에 안내 문구를 띄우고, 실제 삭제는 이메일
-- 요청 → 관리자(나)가 대시보드에서 처리"하는 방식을 택했습니다.
-- (이 SQL이 그 처리를 "삭제 = 자료도 삭제"로 만들어 줍니다.)
-- ============================================================
