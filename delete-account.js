// ============================================================
// 과제 7 · 카드 5 — 회원 탈퇴 버튼 (C134)
// index.html의 #delete-account-btn을 누르면 실행된다.
// auth.js가 만들어 둔 window.supabaseClient를 그대로 쓴다.
// ============================================================

(function () {
  const btn = document.getElementById("delete-account-btn");
  if (!btn) return;

  btn.addEventListener("click", async () => {
    // 1차 확인
    const ok1 = confirm(
      "정말로 회원 탈퇴하시겠습니까?\n계정과 함께 이 계정의 모든 계획·할 일·실행 기록·돌아보기 메모가 삭제됩니다."
    );
    if (!ok1) return;

    // 2차 확인 (되돌릴 수 없음을 한 번 더 알림)
    const typed = prompt(
      '이 작업은 되돌릴 수 없습니다.\n계속하려면 정확히 "삭제"라고 입력해주세요.'
    );
    if (typed !== "삭제") {
      alert("입력이 일치하지 않아 탈퇴가 취소되었습니다.");
      return;
    }

    btn.disabled = true;
    btn.textContent = "탈퇴 처리 중…";

    try {
      const {
        data: { session },
      } = await window.supabaseClient.auth.getSession();
      if (!session) {
        alert("로그인 정보가 없습니다. 다시 로그인 후 시도해주세요.");
        btn.disabled = false;
        btn.textContent = "회원 탈퇴";
        return;
      }

      const res = await fetch(window.SUPABASE_URL + "/functions/v1/delete-account", {
        method: "POST",
        headers: {
          Authorization: "Bearer " + session.access_token,
          apikey: window.SUPABASE_ANON_KEY,
          "Content-Type": "application/json",
        },
      });
      const data = await res.json();

      if (!res.ok || !data.success) {
        alert("탈퇴에 실패했습니다: " + (data.error || res.status));
        btn.disabled = false;
        btn.textContent = "회원 탈퇴";
        return;
      }

      alert("계정과 자료가 모두 삭제되었습니다.");
      await window.supabaseClient.auth.signOut();
      location.reload();
    } catch (e) {
      alert("탈퇴 요청 중 오류가 발생했습니다: " + e.message);
      btn.disabled = false;
      btn.textContent = "회원 탈퇴";
    }
  });
})();
