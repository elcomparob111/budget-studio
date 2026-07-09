// Cloud sync layer: Supabase Auth (email/password) + Postgres.
// Each user's budget lives in the budgets table, readable/writable only by them (row level security).
import { syncConfig } from "./sync-config.js";

let supabase = null;
let lastUid = null;

function toAppUser(user) {
  if (!user) return null;
  return { uid: user.id, displayName: user.user_metadata?.name || "" };
}

export async function initSync(onUserChanged) {
  if (!syncConfig) {
    onUserChanged(null, { unavailable: true });
    return false;
  }
  const { createClient } = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm");
  supabase = createClient(syncConfig.url, syncConfig.anonKey);

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

export async function signUp(name, email, password) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { name } },
  });
  if (error) throw error;
  return toAppUser(data.user);
}

export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return toAppUser(data.user);
}

export async function signOutUser() {
  await supabase.auth.signOut();
}

export async function resetPassword(email) {
  // Always send people to the live site — localhost only works if a local server is running.
  const redirectTo = "https://elcomparob111.github.io/budget-studio/";
  const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo });
  if (error) throw error;
}

export async function updatePassword(password) {
  const { error } = await supabase.auth.updateUser({ password });
  if (error) throw error;
}

export function isPasswordRecoveryLink() {
  const hash = window.location.hash || "";
  return hash.includes("type=recovery");
}

export async function fetchCloudBudget(uid) {
  const { data, error } = await supabase
    .from("budgets")
    .select("state, updated_at, name")
    .eq("user_id", uid)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return { state: data.state, updatedAt: data.updated_at, name: data.name };
}

export async function pushCloudBudget(uid, payload) {
  const { error } = await supabase.from("budgets").upsert({
    user_id: uid,
    state: payload.state,
    updated_at: payload.updatedAt ?? Date.now(),
    name: payload.name || "",
  });
  if (error) throw error;
}

export function friendlyAuthError(error) {
  const message = String(error?.message || "").toLowerCase();
  if (message.includes("invalid login credentials")) return "Email or password is incorrect.";
  if (message.includes("already registered")) return "That email already has an account. Try signing in.";
  if (message.includes("valid email") || message.includes("invalid format")) return "That doesn't look like a valid email.";
  if (message.includes("at least 6")) return "Password needs at least 6 characters.";
  if (message.includes("rate limit") || message.includes("too many")) return "Too many attempts. Wait a minute and try again.";
  if (message.includes("fetch") || message.includes("network")) return "No connection. Check your internet and try again.";
  if (message.includes("user not found") || message.includes("unable to validate")) return "No account found for that email.";
  return "Something went wrong. Please try again.";
}
