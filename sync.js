// Cloud sync layer: Supabase Auth (email/password, OAuth, passkeys) + Postgres.
// Each user's budget lives in the budgets table, readable/writable only by them (row level security).
// Password hashing, session cookies, and Auth rate limits are handled by Supabase Auth — not this file.
import { syncConfig } from "./sync-config.js";
import {
  assertOwnUserId,
  clearAuthFailures,
  getAuthLockout,
  recordAuthFailure,
  safeLog,
  sanitizeAuthError,
  sanitizeBudgetState,
  sanitizeCloudPayload,
  validateEmail,
  validatePassword,
} from "./security.js";

let supabase = null;
let lastUid = null;

/** Live GitHub Pages app (project site — not the user Pages root). */
const PROD_APP_URL = "https://elcomparob111.github.io/budget-studio/";

/** OAuth providers enabled in the UI (must also be enabled in Supabase Dashboard). */
export const OAUTH_PROVIDERS = ["apple", "google"];

/**
 * Where Auth confirmation / recovery emails should send the user.
 * Must include `/budget-studio/` on GitHub Pages; bare `*.github.io` is a 404.
 * Localhost uses the current origin; otherwise prefer the production app URL.
 */
function authEmailRedirectTo({ preferProduction = false } = {}) {
  if (preferProduction) return PROD_APP_URL;
  try {
    const { origin, pathname } = window.location;
    if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) {
      return `${origin}/`;
    }
    if (pathname.startsWith("/budget-studio")) {
      return `${origin}/budget-studio/`;
    }
  } catch (_) {
    /* non-browser */
  }
  return PROD_APP_URL;
}

function toAppUser(user) {
  if (!user) return null;
  return { uid: user.id, displayName: user.user_metadata?.name || "" };
}

function requireClient() {
  if (!supabase) throw new Error("Cloud sync is not available.");
  return supabase;
}

export async function initSync(onUserChanged) {
  if (!syncConfig?.url || !syncConfig?.anonKey) {
    onUserChanged(null, { unavailable: true });
    return false;
  }
  // Guard: never ship a service_role key in the browser.
  if (/service_role/i.test(syncConfig.anonKey)) {
    safeLog("error", "Refusing to init sync: service_role key must never be in the frontend.");
    onUserChanged(null, { unavailable: true });
    return false;
  }

  // Pin to a release that includes passkeys (experimental API).
  const { createClient } = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.105.1/+esm");
  supabase = createClient(syncConfig.url, syncConfig.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      experimental: { passkey: true },
    },
  });

  const { data } = await supabase.auth.getSession();
  lastUid = data.session?.user?.id || null;
  onUserChanged(toAppUser(data.session?.user), {});

  supabase.auth.onAuthStateChange((_event, session) => {
    const uid = session?.user?.id || null;
    if (uid === lastUid) return; // ignore token refreshes
    lastUid = uid;
    onUserChanged(toAppUser(session?.user), {});
  });
  return true;
}

function assertNotLocked() {
  const lock = getAuthLockout();
  if (lock.locked) {
    const seconds = Math.ceil(lock.retryAfterMs / 1000);
    const err = new Error(`Too many attempts. Wait ${seconds}s and try again.`);
    err.code = "client_lockout";
    throw err;
  }
}

function captchaOptions(captchaToken) {
  const token = String(captchaToken || "").trim();
  return token ? { captchaToken: token } : {};
}

export function getCaptchaSiteKey() {
  return String(syncConfig?.captchaSiteKey || "").trim();
}

export async function signUp(name, email, password, captchaToken = "") {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);
  const passwordCheck = validatePassword(password);
  if (!passwordCheck.ok) throw new Error(passwordCheck.message);

  const client = requireClient();
  const { data, error } = await client.auth.signUp({
    email: emailCheck.value,
    password: passwordCheck.value,
    options: {
      data: { name: String(name || "").trim().slice(0, 40) },
      // Without this, Supabase falls back to dashboard Site URL (must include /budget-studio/).
      emailRedirectTo: authEmailRedirectTo(),
      ...captchaOptions(captchaToken),
    },
  });
  if (error) {
    recordAuthFailure();
    safeLog("warn", "Sign-up failed", { code: error.code || "auth_error" });
    throw error;
  }
  clearAuthFailures();
  return {
    user: toAppUser(data.user),
    // Supabase obfuscates duplicate signups: user comes back with no identities.
    existingAccount: Array.isArray(data.user?.identities) && data.user.identities.length === 0,
    // Confirm-email is on: no session until the link is clicked.
    confirmationRequired: !data.session,
  };
}

export async function resendConfirmation(email) {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);
  const client = requireClient();
  const { error } = await client.auth.resend({
    type: "signup",
    email: emailCheck.value,
    options: { emailRedirectTo: authEmailRedirectTo() },
  });
  if (error) {
    safeLog("warn", "Resend confirmation failed", { code: error.code || "auth_error" });
    throw error;
  }
}

export async function signIn(email, password, captchaToken = "") {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);
  // Sign-in: do not enforce complexity (existing users may have shorter passwords).
  if (!password || String(password).length < 1) throw new Error("Enter your password.");

  const client = requireClient();
  const { data, error } = await client.auth.signInWithPassword({
    email: emailCheck.value,
    password: String(password),
    options: captchaOptions(captchaToken),
  });
  if (error) {
    // Unconfirmed email is not a credential guess — don't count it toward lockout,
    // so the confirm screen can retry sign-in while waiting for the link click.
    if (error.code !== "email_not_confirmed") recordAuthFailure();
    safeLog("warn", "Sign-in failed", { code: error.code || "auth_error" });
    throw error;
  }
  clearAuthFailures();
  return toAppUser(data.user);
}

/** Redirects to Apple or Google OAuth, then back to the app URL. */
export async function signInWithOAuthProvider(provider) {
  assertNotLocked();
  const name = String(provider || "").toLowerCase();
  if (!OAUTH_PROVIDERS.includes(name)) throw new Error("Unsupported sign-in provider.");
  const client = requireClient();
  const { error } = await client.auth.signInWithOAuth({
    provider: name,
    options: {
      redirectTo: authEmailRedirectTo(),
      skipBrowserRedirect: false,
    },
  });
  if (error) {
    recordAuthFailure();
    safeLog("warn", "OAuth sign-in failed", { code: error.code || "oauth", provider: name });
    throw error;
  }
}

/** Discoverable passkey sign-in (no email required). Requires dashboard Passkeys enabled. */
export async function signInWithPasskey() {
  assertNotLocked();
  if (!window.PublicKeyCredential) {
    throw new Error("Passkeys are not supported in this browser.");
  }
  const client = requireClient();
  const { data, error } = await client.auth.signInWithPasskey();
  if (error) {
    if (!/cancel|abort|not allowed/i.test(String(error.message || ""))) {
      recordAuthFailure();
    }
    safeLog("warn", "Passkey sign-in failed", { code: error.code || "passkey" });
    throw error;
  }
  clearAuthFailures();
  return toAppUser(data.user);
}

/** Register a passkey for the currently signed-in, confirmed user. */
export async function registerPasskey() {
  if (!window.PublicKeyCredential) {
    throw new Error("Passkeys are not supported in this browser.");
  }
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  if (!sessionData.session?.user) {
    throw new Error("Sign in first, then add a passkey.");
  }
  const { data, error } = await client.auth.registerPasskey();
  if (error) {
    safeLog("warn", "Passkey registration failed", { code: error.code || "passkey" });
    throw error;
  }
  return data;
}

export async function listPasskeys() {
  const client = requireClient();
  const { data, error } = await client.auth.passkey.list();
  if (error) throw error;
  return Array.isArray(data) ? data : [];
}

export async function deletePasskey(passkeyId) {
  const client = requireClient();
  const { error } = await client.auth.passkey.delete({ passkeyId });
  if (error) throw error;
}

/** Clears Supabase session and returns so the UI can wipe local caches. */
export async function signOutUser() {
  const client = requireClient();
  const { error } = await client.auth.signOut();
  if (error) {
    safeLog("warn", "Sign-out reported an error", { code: error.code || "signout" });
  }
  lastUid = null;
  clearAuthFailures();
}

export async function resetPassword(email, captchaToken = "") {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);

  // Prefer production: reset emails are often opened later when localhost is not running.
  const redirectTo = authEmailRedirectTo({ preferProduction: true });
  const client = requireClient();
  const { error } = await client.auth.resetPasswordForEmail(emailCheck.value, {
    redirectTo,
    ...captchaOptions(captchaToken),
  });
  if (error) {
    recordAuthFailure();
    safeLog("warn", "Password reset request failed", { code: error.code || "reset" });
    throw error;
  }
  // Always show a generic success message in the UI (do not reveal account existence).
}

export async function updatePassword(password) {
  assertNotLocked();
  const passwordCheck = validatePassword(password);
  if (!passwordCheck.ok) throw new Error(passwordCheck.message);

  const client = requireClient();
  const { error } = await client.auth.updateUser({ password: passwordCheck.value });
  if (error) {
    recordAuthFailure();
    throw error;
  }
  clearAuthFailures();
}

export function isPasswordRecoveryLink() {
  const hash = window.location.hash || "";
  return hash.includes("type=recovery");
}

export async function fetchCloudBudget(uid) {
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  const sessionUid = sessionData.session?.user?.id;
  // Refuse missing session and mismatched uid (defense-in-depth; RLS is still required).
  assertOwnUserId(sessionUid, uid);

  const { data, error } = await client
    .from("budgets")
    .select("state, updated_at, name")
    .eq("user_id", sessionUid)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  // Sanitize before applying in the UI — never trust cloud JSON shape blindly.
  return {
    state: sanitizeBudgetState(data.state),
    updatedAt: Number(data.updated_at) || 0,
    name: String(data.name || "").slice(0, 80),
  };
}

export async function pushCloudBudget(uid, payload) {
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  const sessionUid = sessionData.session?.user?.id;
  assertOwnUserId(sessionUid, uid);

  const safe = sanitizeCloudPayload(payload);
  // Do not trust client updated_at — DB trigger sets server time (see security-hardening.sql).
  const { data, error } = await client
    .from("budgets")
    .upsert({
      user_id: sessionUid,
      state: safe.state,
      name: safe.name,
    })
    .select("updated_at")
    .single();
  if (error) throw error;
  return { updatedAt: Number(data?.updated_at) || Date.now() };
}

// ---------------------------------------------------------------------------
// Shared/couples budgets (see docs/SHARED_BUDGETS.md). One shared budget per
// user in v1. All rows are RLS-guarded server-side; membership and invite
// redemption go through security-definer RPCs.
// ---------------------------------------------------------------------------

async function requireSessionUid() {
  const client = requireClient();
  const { data } = await client.auth.getSession();
  const uid = data.session?.user?.id;
  if (!uid) throw new Error("You must be signed in to do that.");
  return uid;
}

/** The caller's shared-budget membership, or null when solo. */
export async function fetchMySharedMembership() {
  const client = requireClient();
  const uid = await requireSessionUid();
  const { data, error } = await client
    .from("budget_members")
    .select("budget_id, role")
    .eq("user_id", uid)
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data ? { id: data.budget_id, role: data.role } : null;
}

export async function fetchSharedBudget(budgetId) {
  const client = requireClient();
  await requireSessionUid();
  const { data, error } = await client
    .from("shared_budgets")
    .select("state, updated_at, name")
    .eq("id", budgetId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return {
    state: sanitizeBudgetState(data.state),
    updatedAt: Number(data.updated_at) || 0,
    name: String(data.name || "").slice(0, 80),
  };
}

export async function pushSharedBudget(budgetId, payload) {
  const client = requireClient();
  await requireSessionUid();
  const safe = sanitizeCloudPayload(payload);
  // Deliberately not updating `name`: the payload carries the saver's display
  // name, which would rename the shared budget on every partner save.
  // updated_at is set by a DB trigger — client timestamps are ignored.
  const { data, error } = await client
    .from("shared_budgets")
    .update({ state: safe.state })
    .eq("id", budgetId)
    .select("updated_at")
    .single();
  if (error) throw error;
  return { updatedAt: Number(data?.updated_at) || Date.now() };
}

/** Create a shared budget seeded from `state`; caller becomes owner. Returns budget id. */
export async function createSharedBudget(state, name) {
  const client = requireClient();
  await requireSessionUid();
  const { data, error } = await client.rpc("create_shared_budget", {
    initial_state: sanitizeBudgetState(state),
    budget_name: String(name || "").slice(0, 80),
  });
  if (error) throw error;
  return data;
}

/** Mint a single-use invite link token (owner only, enforced by RLS). */
export async function createBudgetInvite(budgetId) {
  const client = requireClient();
  const uid = await requireSessionUid();
  const { data, error } = await client
    .from("budget_invites")
    .insert({ budget_id: budgetId, created_by: uid })
    .select("token")
    .single();
  if (error) throw error;
  return data.token;
}

/** Redeem an invite token; returns the shared budget id to switch to. */
export async function acceptBudgetInvite(token) {
  const client = requireClient();
  await requireSessionUid();
  const clean = String(token || "").trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clean)) {
    throw new Error("That invite link looks invalid.");
  }
  const { data, error } = await client.rpc("accept_budget_invite", { invite_token: clean });
  if (error) throw error;
  return data;
}

export async function listBudgetMembers(budgetId) {
  const client = requireClient();
  await requireSessionUid();
  const { data, error } = await client
    .from("budget_members")
    .select("user_id, role, joined_at")
    .eq("budget_id", budgetId)
    .order("joined_at", { ascending: true });
  if (error) throw error;
  return data || [];
}

/** Remove the caller's own membership (their personal budget is untouched). */
export async function leaveSharedBudget(budgetId) {
  const client = requireClient();
  const uid = await requireSessionUid();
  const { error } = await client
    .from("budget_members")
    .delete()
    .eq("budget_id", budgetId)
    .eq("user_id", uid);
  if (error) throw error;
}

/** Dissolve the shared budget; the owner-only RLS policy protects this call. */
export async function deleteSharedBudget(budgetId) {
  const client = requireClient();
  await requireSessionUid();
  const { error } = await client
    .from("shared_budgets")
    .delete()
    .eq("id", budgetId);
  if (error) throw error;
}

/**
 * Realtime: notify on any change to the shared budget row. The callback gets
 * no payload — callers refetch, so event size limits and trust don't matter.
 * Returns an unsubscribe function.
 */
export function subscribeSharedBudget(budgetId, onRemoteChange) {
  const client = requireClient();
  const channel = client
    .channel(`shared-budget-${budgetId}`)
    .on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "shared_budgets", filter: `id=eq.${budgetId}` },
      () => onRemoteChange(),
    )
    .on(
      "postgres_changes",
      { event: "DELETE", schema: "public", table: "shared_budgets", filter: `id=eq.${budgetId}` },
      () => onRemoteChange(),
    )
    .subscribe();
  return () => {
    client.removeChannel(channel);
  };
}

/**
 * Best-effort account data deletion.
 * Supabase client apps cannot call admin deleteUser without a privileged key.
 * Clears personal budget, leaves or dissolves shared membership, then signs out.
 * Full Auth user deletion still needs the Supabase dashboard or an Edge Function.
 */
export async function deleteOwnBudgetAndSignOut() {
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  const sessionUid = sessionData.session?.user?.id;
  if (!sessionUid) throw new Error("You must be signed in to delete your data.");

  // Shared first so we don't leave membership/state behind after personal wipe.
  let sharedHandled = false;
  try {
    const membership = await fetchMySharedMembership();
    if (membership) {
      if (membership.role === "owner") {
        const { error: sharedErr } = await client.from("shared_budgets").delete().eq("id", membership.id);
        if (sharedErr) throw sharedErr;
      } else {
        await leaveSharedBudget(membership.id);
      }
      sharedHandled = true;
    }
  } catch (error) {
    const msg = String(error?.message || error || "");
    // Shared schema not applied yet — still allow personal delete.
    if (!/relation|does not exist|schema cache|could not find the table/i.test(msg)) {
      throw error;
    }
  }

  const { error } = await client.from("budgets").delete().eq("user_id", sessionUid);
  if (error) throw error;
  await signOutUser();
  return {
    deletedBudget: true,
    sharedHandled,
    authUserDeleted: false,
    note: "Personal budget removed and shared membership cleared when present. Delete the Auth user in Supabase Dashboard → Authentication → Users if you need the account gone entirely.",
  };
}

export function friendlyAuthError(error) {
  if (error?.code === "client_lockout") {
    return String(error.message || "Too many attempts. Wait a minute and try again.");
  }
  if (error?.code === "email_not_confirmed" || /email not confirmed/i.test(String(error?.message || ""))) {
    return "Your email isn't confirmed yet. Check your inbox for the link, or resend it.";
  }
  if (error?.code === "over_email_send_rate_limit" || /rate limit/i.test(String(error?.message || ""))) {
    return "Too many emails sent recently. Wait a few minutes and try again.";
  }
  if (error?.code === "passkey_disabled") {
    return "Passkeys aren't enabled yet for this project.";
  }
  if (error?.code === "captcha_failed" || /captcha/i.test(String(error?.message || ""))) {
    return "Complete the CAPTCHA check and try again.";
  }
  const raw = String(error?.message || "");
  if (/cancel|abort|not allowed/i.test(raw) && /passkey|webauthn|credential/i.test(raw)) {
    return "Passkey sign-in was cancelled.";
  }
  // Prefer client validation messages we threw ourselves.
  if (
    raw.startsWith("Enter ") ||
    raw.startsWith("Password ") ||
    raw.startsWith("Too many") ||
    raw.startsWith("Choose ") ||
    raw.startsWith("Unable to") ||
    raw.startsWith("No connection") ||
    raw.startsWith("Something went") ||
    raw.startsWith("Cloud sync") ||
    raw.startsWith("You can only") ||
    raw.startsWith("You must be") ||
    raw.startsWith("Passkeys ") ||
    raw.startsWith("Sign in first") ||
    raw.startsWith("Unsupported ")
  ) {
    return raw;
  }
  return sanitizeAuthError(error);
}
