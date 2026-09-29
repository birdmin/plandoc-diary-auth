// ============================================================
// 플랜두씨 다이어리 · 과제 7 (인증)
// - 선택한 방법: Supabase Auth (이메일/비밀번호)
// - 이 파일이 supabaseClient를 "한 곳에서만" 만들고, 다른 스크립트
//   (app.js, todo.js, log.js, review.js, calendar.js)는 전부
//   window.supabaseClient를 그대로 가져다 씁니다.
// - index.html의 <script> 순서: config.js → supabase-js(CDN) →
//   auth.js → app.js → todo.js → ... (auth.js가 먼저 와야 함)
// ============================================================

window.supabaseClient = window.supabase.createClient(
  window.SUPABASE_URL,
  window.SUPABASE_ANON_KEY
);

// [버그 수정] app.js가 이미 전역에 `el`이라는 이름을 선언하고 있다.
// auth.js와 app.js는 둘 다 일반 <script>라서 같은 전역 스코프를 쓰는데,
// 같은 이름을 const로 두 번 선언하면 "Identifier has already been
// declared" 문법 오류가 나서 app.js 전체가 실행조차 안 된다.
// → auth.js 쪽 헬퍼 이름을 authEl로 바꿔 이름 충돌을 없앤다.
const authEl = (id) => document.getElementById(id);

// index.html에 아래 id를 가진 요소가 있어야 합니다. (아직 없다면 추가 필요)
//   #login-screen   : 로그인/가입 폼을 담는 화면 전체
//   #app-screen     : 기존 다이어리 화면 전체 (계획/세부계획/실행기록/돌아보기/캘린더 다 포함)
//   #signup-form, #su-email, #su-password
//   #login-form,  #li-email, #li-password
//   #auth-status    : 가입/로그인 성공·실패 메시지 표시용
//   #logout-btn     : 로그아웃 버튼 (app-screen 안 어딘가, 보통 헤더)
const loginScreen = authEl("login-screen");
const appScreen = authEl("app-screen");
const signupForm = authEl("signup-form");
const loginForm = authEl("login-form");
const authStatus = authEl("auth-status");
const logoutBtn = authEl("logout-btn");

function setAuthStatus(msg, isError = false) {
  if (!authStatus) return;
  authStatus.textContent = msg;
  authStatus.classList.toggle("error", isError);
}

function showLogin() {
  if (loginScreen) loginScreen.style.display = "";
  if (appScreen) appScreen.style.display = "none";
}

function showApp() {
  if (loginScreen) loginScreen.style.display = "none";
  if (appScreen) appScreen.style.display = "";
}

// ---------- 가입 ----------
if (signupForm) {
  signupForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = authEl("su-email").value.trim();
    const password = authEl("su-password").value;

    if (!email || !password) {
      setAuthStatus("이메일과 비밀번호를 모두 입력해주세요.", true);
      return;
    }
    setAuthStatus("가입 처리 중…");

    const { data, error } = await window.supabaseClient.auth.signUp({ email, password });

    if (error) {
      // 이미 가입된 이메일이면 Supabase가 에러(또는 "이미 등록된 사용자" 안내)를 반환합니다.
      // → T07-C98(같은 아이디로 두 번 가입 안 됨)이 여기서 그대로 증거가 됩니다.
      setAuthStatus(`가입 실패: ${error.message}`, true);
      return;
    }

    // 프로젝트의 Authentication 설정에서 "Confirm email"이 켜져 있으면
    // 여기서 세션이 바로 생기지 않고 메일 인증이 필요합니다.
    // 개인 데모 프로젝트이므로 Supabase 대시보드 → Authentication →
    // Providers → Email에서 "Confirm email"을 꺼두는 것을 권장합니다.
    if (data.session) {
      setAuthStatus("가입되었습니다. 바로 로그인되었습니다.");
    } else {
      setAuthStatus("가입되었습니다. 이메일 인증 후 로그인해주세요.");
    }
  });
}

// ---------- 로그인 ----------
if (loginForm) {
  loginForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = authEl("li-email").value.trim();
    const password = authEl("li-password").value;

    if (!email || !password) {
      setAuthStatus("이메일과 비밀번호를 모두 입력해주세요.", true);
      return;
    }
    setAuthStatus("로그인 중…");

    const { error } = await window.supabaseClient.auth.signInWithPassword({ email, password });

    if (error) {
      // 아이디는 맞고 비밀번호만 틀린 경우 / 아이디 자체가 없는 경우
      // 둘 다 Supabase가 "Invalid login credentials"로 동일하게 응답합니다.
      // → T07-C99를 만족시키는 지점이므로, 이 메시지를 절대 종류별로
      //   구분해서 다시 쓰지 마세요 (계정 존재 여부가 새어나갑니다).
      setAuthStatus(`로그인 실패: ${error.message}`, true);
      return;
    }
    // 성공하면 onAuthStateChange가 showApp()을 호출합니다.
  });
}

// ---------- 로그아웃 ----------
if (logoutBtn) {
  logoutBtn.addEventListener("click", async () => {
    await window.supabaseClient.auth.signOut();
    // 화면에 남아있는 이전 사용자의 캐시(planCache 등)를 확실히 지우기 위해
    // 상태를 이어가지 않고 완전히 새로고침한다.
    location.reload();
  });
}

// ---------- 세션 상태에 따라 화면 전환 ----------
window.supabaseClient.auth.onAuthStateChange((event, session) => {
  if (session) {
    showApp();
    setAuthStatus("");
    // app.js 등에게 "이제 로그인 됐으니 데이터 불러와도 된다"고 알림
    window.dispatchEvent(new CustomEvent("auth-ready", { detail: { user: session.user } }));
  } else {
    showLogin();
  }
});

// 페이지를 처음 열었을 때도 한 번 확인 (onAuthStateChange가 초기 세션도
// 보통 쏴주지만, 명시적으로 한 번 더 확인해 로그인 화면이 늦게 뜨는 걸 방지)
(async () => {
  const { data: { session } } = await window.supabaseClient.auth.getSession();
  if (session) {
    showApp();
    window.dispatchEvent(new CustomEvent("auth-ready", { detail: { user: session.user } }));
  } else {
    showLogin();
  }
})();
