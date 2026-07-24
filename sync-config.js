// Supabase project used for accounts and cloud sync.
//
// IMPORTANT:
// - Only the **anon / publishable** key belongs here. It is public by design.
// - NEVER put the service_role (secret) key in this file, git, or any frontend bundle.
// - Data protection depends on Row Level Security — see supabase/rls.sql and SECURITY.md.
export const syncConfig = {
  url: "https://dhlaqqghjfmgdlkfxlxg.supabase.co",
  anonKey: "sb_publishable_poVoneGFjZxQ2ecE7fQSiA_7YJinWt6",
  // Optional Cloudflare Turnstile site key. Leave empty until CAPTCHA is enabled
  // in Supabase Dashboard → Authentication → Attack Protection (Free plan).
  // When set, the auth form shows a Turnstile widget and passes captchaToken.
  captchaSiteKey: "",
};
