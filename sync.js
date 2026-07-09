// Cloud sync layer: Supabase Auth (email/password) + Postgres.
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
  validateEmail,
  validatePassword,
} from "./security.js";

let supabase = null;
let lastUid = null;

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

  const { createClient } = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm");
  supabase = createClient(syncConfig.url, syncConfig.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
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

export async function signUp(name, email, password) {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);
  const passwordCheck = validatePassword(password);
  if (!passwordCheck.ok) throw new Error(passwordCheck.message);

  const client = requireClient();
  const { data, error } = await client.auth.signUp({
    email: emailCheck.value,
    password: passwordCheck.value,
    options: { data: { name: String(name || "").trim().slice(0, 40) } },
  });
  if (error) {
    recordAuthFailure();
    safeLog("warn", "Sign-up failed", { code: error.code || "auth_error" });
    throw error;
  }
  clearAuthFailures();
  return toAppUser(data.user);
}

export async function signIn(email, password) {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);
  // Sign-in: do not enforce complexity (existing users may have shorter passwords).
  if (!password || String(password).length < 1) throw new Error("Enter your password.");

  const client = requireClient();
  const { data, error } = await client.auth.signInWithPassword({
    email: emailCheck.value,
    password: String(password),
  });
  if (error) {
    recordAuthFailure();
    safeLog("warn", "Sign-in failed", { code: error.code || "auth_error" });
    throw error;
  }
  clearAuthFailures();
  return toAppUser(data.user);
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

export async function resetPassword(email) {
  assertNotLocked();
  const emailCheck = validateEmail(email);
  if (!emailCheck.ok) throw new Error(emailCheck.message);

  // Always send people to the live site — localhost only works if a local server is running.
  const redirectTo = "https://elcomparob111.github.io/budget-studio/";
  const client = requireClient();
  const { error } = await client.auth.resetPasswordForEmail(emailCheck.value, { redirectTo });
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
  assertOwnUserId(sessionUid, uid);

  const { data, error } = await client
    .from("budgets")
    .select("state, updated_at, name")
    .eq("user_id", sessionUid)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return { state: data.state, updatedAt: data.updated_at, name: data.name };
}

export async function pushCloudBudget(uid, payload) {
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  const sessionUid = sessionData.session?.user?.id;
  assertOwnUserId(sessionUid, uid);

  const { error } = await client.from("budgets").upsert({
    user_id: sessionUid,
    state: payload.state,
    updated_at: payload.updatedAt ?? Date.now(),
    name: String(payload.name || "").slice(0, 80),
  });
  if (error) throw error;
}

/**
 * Best-effort account deletion placeholder.
 * Supabase client apps cannot call admin deleteUser without a privileged key.
 * Clears the user's budget row (RLS-scoped) and signs out; full Auth user deletion
 * must be done in the Supabase dashboard or via a server-side Edge Function.
 */
export async function deleteOwnBudgetAndSignOut() {
  const client = requireClient();
  const { data: sessionData } = await client.auth.getSession();
  const sessionUid = sessionData.session?.user?.id;
  if (!sessionUid) throw new Error("You must be signed in to delete your data.");

  const { error } = await client.from("budgets").delete().eq("user_id", sessionUid);
  if (error) throw error;
  await signOutUser();
  return {
    deletedBudget: true,
    authUserDeleted: false,
    note: "Budget data removed. Delete the Auth user in Supabase Dashboard → Authentication → Users if you need the account gone entirely.",
  };
}

export function friendlyAuthError(error) {
  if (error?.code === "client_lockout") {
    return String(error.message || "Too many attempts. Wait a minute and try again.");
  }
  // Prefer client validation messages we threw ourselves.
  const raw = String(error?.message || "");
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
    raw.startsWith("You must be")
  ) {
    return raw;
  }
  return sanitizeAuthError(error);
}
