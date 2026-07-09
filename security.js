/**
 * Client-side security helpers for Budget Studio.
 * Auth hashing, HttpOnly cookies, and server rate limits remain Supabase Auth responsibilities.
 * These helpers add defense-in-depth for XSS, input validation, and UX lockout only.
 */

const SENSITIVE_KEY_RE =
  /password|passwd|token|secret|authorization|apikey|api_key|anonkey|refresh_token|access_token|budget|transaction|amount|balance/i;

const AUTH_RATE_KEY = "budget-studio-auth-rate";
const AUTH_MAX_FAILURES = 5;
const AUTH_LOCKOUT_MS = 60_000;

/** Escape user-controlled text before inserting into HTML. */
export function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

/** Basic email shape check (server still validates). */
export function validateEmail(email) {
  const value = String(email || "").trim();
  if (!value || value.length > 254) return { ok: false, message: "Enter a valid email address." };
  // Practical client check — not a full RFC parser.
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    return { ok: false, message: "Enter a valid email address." };
  }
  return { ok: true, value: value.toLowerCase() };
}

/**
 * Password strength for signup / password update.
 * Align Supabase Auth password policy with these rules in the dashboard.
 */
export function validatePassword(password, { minLength = 8 } = {}) {
  const value = String(password || "");
  if (value.length < minLength) {
    return { ok: false, message: `Password needs at least ${minLength} characters.` };
  }
  if (value.length > 128) {
    return { ok: false, message: "Password is too long." };
  }
  if (!/[A-Za-z]/.test(value) || !/[0-9]/.test(value)) {
    return { ok: false, message: "Password needs at least one letter and one number." };
  }
  return { ok: true, value };
}

export function validateAmount(raw) {
  const amount = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(amount) || amount <= 0) {
    return { ok: false, message: "Enter an amount greater than zero." };
  }
  if (amount > 1_000_000_000) {
    return { ok: false, message: "Amount is too large." };
  }
  // Cap to cents precision for money fields.
  const rounded = Math.round(amount * 100) / 100;
  return { ok: true, value: rounded };
}

export function validateDate(raw) {
  const value = String(raw || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return { ok: false, message: "Enter a valid date." };
  }
  const parsed = new Date(`${value}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) {
    return { ok: false, message: "Enter a valid date." };
  }
  const year = parsed.getFullYear();
  if (year < 2000 || year > 2100) {
    return { ok: false, message: "Date is out of range." };
  }
  return { ok: true, value };
}

export function validateCategoryName(raw) {
  const value = String(raw || "").trim().replace(/\s+/g, " ").slice(0, 40);
  if (!value) return { ok: false, message: "Enter a category name." };
  if (/[<>]/.test(value)) return { ok: false, message: "Category name has invalid characters." };
  return { ok: true, value };
}

export function validateDescription(raw) {
  const value = String(raw || "").trim().replace(/\s+/g, " ").slice(0, 120);
  if (/[<>]/.test(value)) return { ok: false, message: "Description has invalid characters." };
  return { ok: true, value };
}

export function validateAccountName(raw) {
  const value = String(raw || "").trim().slice(0, 40);
  if (!value) return { ok: false, message: "Choose an account." };
  return { ok: true, value };
}

export function validateTransactionType(raw) {
  const value = String(raw || "");
  if (value !== "Income" && value !== "Expense") {
    return { ok: false, message: "Choose Income or Expense." };
  }
  return { ok: true, value };
}

/**
 * Ensure cloud reads/writes only target the signed-in user.
 * Prevents accidental IDOR if a uid ever came from URL/query state.
 */
export function assertOwnUserId(sessionUid, requestedUid) {
  const session = String(sessionUid || "");
  const requested = String(requestedUid || "");
  if (!session || !requested || session !== requested) {
    throw new Error("You can only access your own budget.");
  }
  return session;
}

/** Strip sensitive fields from objects before any logging. */
export function redactForLog(value, depth = 0) {
  if (value == null || depth > 4) return value;
  if (typeof value === "string") {
    if (value.length > 200) return `${value.slice(0, 40)}…[redacted]`;
    return value;
  }
  if (typeof value !== "object") return value;
  if (Array.isArray(value)) return value.slice(0, 20).map((item) => redactForLog(item, depth + 1));
  const out = {};
  for (const [key, nested] of Object.entries(value)) {
    out[key] = SENSITIVE_KEY_RE.test(key) ? "[redacted]" : redactForLog(nested, depth + 1);
  }
  return out;
}

/**
 * Safe logger — never prints passwords, tokens, or financial payloads.
 * In production builds, only errors are emitted.
 */
export function safeLog(level, message, meta) {
  const isDev =
    typeof location !== "undefined" &&
    (location.hostname === "localhost" || location.hostname === "127.0.0.1");
  if (!isDev && level !== "error") return;
  const payload = meta === undefined ? undefined : redactForLog(meta);
  const fn = console[level] || console.log;
  if (payload === undefined) fn(`[Budget Studio] ${message}`);
  else fn(`[Budget Studio] ${message}`, payload);
}

function readAuthRate(storage) {
  try {
    const raw = storage.getItem(AUTH_RATE_KEY);
    if (!raw) return { failures: 0, lockedUntil: 0 };
    const parsed = JSON.parse(raw);
    return {
      failures: Number(parsed.failures) || 0,
      lockedUntil: Number(parsed.lockedUntil) || 0,
    };
  } catch {
    return { failures: 0, lockedUntil: 0 };
  }
}

function writeAuthRate(storage, state) {
  storage.setItem(AUTH_RATE_KEY, JSON.stringify(state));
}

/** Client UX lockout after repeated auth failures (not a substitute for Supabase rate limits). */
export function getAuthLockout(storage = globalThis.sessionStorage) {
  if (!storage) return { locked: false, retryAfterMs: 0 };
  const state = readAuthRate(storage);
  const now = Date.now();
  if (state.lockedUntil > now) {
    return { locked: true, retryAfterMs: state.lockedUntil - now };
  }
  if (state.lockedUntil && state.lockedUntil <= now) {
    writeAuthRate(storage, { failures: 0, lockedUntil: 0 });
  }
  return { locked: false, retryAfterMs: 0 };
}

export function recordAuthFailure(storage = globalThis.sessionStorage) {
  if (!storage) return getAuthLockout(storage);
  const state = readAuthRate(storage);
  const now = Date.now();
  const failures = (state.lockedUntil > now ? state.failures : state.failures) + 1;
  const next = {
    failures,
    lockedUntil: failures >= AUTH_MAX_FAILURES ? now + AUTH_LOCKOUT_MS : 0,
  };
  writeAuthRate(storage, next);
  return getAuthLockout(storage);
}

export function clearAuthFailures(storage = globalThis.sessionStorage) {
  if (!storage) return;
  try {
    storage.removeItem(AUTH_RATE_KEY);
  } catch {
    // ignore
  }
}

/**
 * Map Supabase Auth errors to generic user-facing copy.
 * Avoids leaking whether an email is registered.
 */
export function sanitizeAuthError(error) {
  const message = String(error?.message || error || "").toLowerCase();
  if (message.includes("rate limit") || message.includes("too many") || message.includes("over_request")) {
    return "Too many attempts. Wait a minute and try again.";
  }
  if (message.includes("fetch") || message.includes("network") || message.includes("failed to fetch")) {
    return "No connection. Check your internet and try again.";
  }
  if (message.includes("valid email") || message.includes("invalid format") || message.includes("unable to validate email")) {
    return "Enter a valid email address.";
  }
  if (message.includes("at least") && message.includes("character")) {
    return "Password does not meet the requirements.";
  }
  if (message.includes("same password") || message.includes("should be different")) {
    return "Choose a different password than your current one.";
  }
  if (
    message.includes("invalid login") ||
    message.includes("invalid credentials") ||
    message.includes("already registered") ||
    message.includes("user not found") ||
    message.includes("email not confirmed") ||
    message.includes("signup") ||
    message.includes("signups not allowed")
  ) {
    return "Unable to sign in with those details. Check your email and password, or create an account.";
  }
  return "Something went wrong. Please try again.";
}

export const AUTH_PASSWORD_HINT = "At least 8 characters, with a letter and a number";
