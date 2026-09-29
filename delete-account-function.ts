// ============================================================
// Edge Function: delete-account
// 과제 7 · 카드 5 — 회원 탈퇴 (C134)
//
// 이 함수는 Supabase 서버에서만 실행된다(브라우저에서 실행되는
// auth.js 같은 코드와 다르다). service_role 키를 여기서만 쓰고,
// 브라우저에는 절대 넘기지 않는다.
//
// 핵심 안전장치:
//   요청한 사람이 "나 A 계정을 지워줘"라고 말해도 그 말을 믿지 않는다.
//   요청에 실려온 토큰(JWT) 자체를 다시 검증해서, 그 토큰의 진짜
//   주인이 누구인지 서버가 직접 확인한 뒤, 그 사람만 지운다.
//   그래서 "다른 사람 id를 대신 적어 보내는" 방식으로는 절대
//   남을 지울 수 없다 (카드 4에서 확인한 것과 같은 원칙).
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // 브라우저의 사전 확인 요청(preflight) 대응
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: '로그인 토큰이 없습니다.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 1) 요청을 보낸 사람이 "정말 누구인지" 그 사람 권한으로 확인한다.
    //    (관리자 권한이 아니라, 요청에 실린 본인 토큰으로만 조회한다)
    const supabaseAsCaller = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: userErr } = await supabaseAsCaller.auth.getUser()

    if (userErr || !user) {
      return new Response(JSON.stringify({ error: '로그인이 확인되지 않았습니다.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2) 위에서 "확인된 본인의 id"만 지운다. service_role 키는 이 한 줄을
    //    위해서만 서버 안에서 쓰이고, 밖으로 나가지 않는다.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(user.id)

    if (delErr) {
      return new Response(JSON.stringify({ error: delErr.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 계정이 지워지는 순간, account-delete-cascade.sql에서 걸어둔
    // ON DELETE CASCADE 덕분에 그 계정의 plans/todos/... 행도
    // 데이터베이스가 알아서 함께 지운다. 여기서 따로 지울 필요 없음.

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
