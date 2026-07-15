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
 * Also refuses missing session (no anonymous cloud access).
 */
export function assertOwnUserId(sessionUid, requestedUid) {
  const session = String(sessionUid || "");
  const requested = String(requestedUid || "");
  if (!session) {
    throw new Error("You must be signed in to access cloud budgets.");
  }
  if (!requested || session !== requested) {
    throw new Error("You can only access your own budget.");
  }
  return session;
}

/** Hard caps for import / cloud payloads (DoS + storage abuse). */
export const BUDGET_LIMITS = {
  maxImportBytes: 2_000_000,
  maxCategories: 200,
  maxTransactions: 20_000,
  maxRecurring: 100,
  maxNameLength: 40,
  maxDescriptionLength: 120,
  maxGroupLength: 40,
  maxAccountLength: 40,
  maxPayloadNameLength: 80,
  maxIdLength: 80,
};

const ALLOWED_TX_TYPES = new Set(["Income", "Expense"]);
const ALLOWED_CAT_TYPES = new Set(["Income", "Expense"]);
const DANGEROUS_KEYS = new Set(["__proto__", "prototype", "constructor"]);

function stripDangerousKeys(value) {
  if (value == null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(stripDangerousKeys);
  const out = Object.create(null);
  for (const [key, nested] of Object.entries(value)) {
    if (DANGEROUS_KEYS.has(key)) continue;
    out[key] = stripDangerousKeys(nested);
  }
  return out;
}

function sanitizeCategory(raw) {
  if (!raw || typeof raw !== "object") return null;
  const name = String(raw.name || "")
    .trim()
    .replace(/\s+/g, " ")
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxNameLength);
  if (!name) return null;
  const type = ALLOWED_CAT_TYPES.has(raw.type) ? raw.type : "Expense";
  const group = String(raw.group || (type === "Income" ? "Income" : "Needs"))
    .trim()
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxGroupLength);
  let budget = Number(raw.budget);
  if (!Number.isFinite(budget) || budget < 0) budget = 0;
  if (budget > 1_000_000_000) budget = 1_000_000_000;
  budget = Math.round(budget * 100) / 100;
  return { name, type, group: group || "Needs", budget };
}

function sanitizeTransaction(raw) {
  if (!raw || typeof raw !== "object") return null;
  const type = ALLOWED_TX_TYPES.has(raw.type) ? raw.type : null;
  if (!type) return null;
  const date = String(raw.date || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;
  const category = String(raw.category || "")
    .trim()
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxNameLength);
  if (!category) return null;
  const description = String(raw.description || "")
    .trim()
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxDescriptionLength);
  const account = String(raw.account || "Checking")
    .trim()
    .slice(0, BUDGET_LIMITS.maxAccountLength);
  let amount = Number(raw.amount);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1_000_000_000) return null;
  amount = Math.round(amount * 100) / 100;
  // IDs land in HTML attributes — allow only URL/attr-safe characters.
  let id = String(raw.id || "")
    .trim()
    .replace(/[^a-zA-Z0-9_-]/g, "")
    .slice(0, BUDGET_LIMITS.maxIdLength);
  const clean = {
    id: id || `import-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    date,
    type,
    category,
    description: description || category,
    account: account || "Checking",
    amount,
  };
  // Shared-budget authorship (optional; absent on personal/older transactions).
  let addedBy = String(raw.addedBy || "")
    .trim()
    .replace(/[^a-zA-Z0-9_-]/g, "")
    .slice(0, BUDGET_LIMITS.maxIdLength);
  if (addedBy) {
    clean.addedBy = addedBy;
    clean.addedByName = String(raw.addedByName || "")
      .trim()
      .replace(/[<>]/g, "")
      .slice(0, BUDGET_LIMITS.maxNameLength);
  }
  return clean;
}

function sanitizeRecurringItem(raw) {
  if (!raw || typeof raw !== "object") return null;
  const type = ALLOWED_TX_TYPES.has(raw.type) ? raw.type : null;
  if (!type) return null;
  const category = String(raw.category || "")
    .trim()
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxNameLength);
  if (!category) return null;
  const description = String(raw.description || "")
    .trim()
    .replace(/[<>]/g, "")
    .slice(0, BUDGET_LIMITS.maxDescriptionLength);
  const account = String(raw.account || "Checking")
    .trim()
    .slice(0, BUDGET_LIMITS.maxAccountLength);
  let amount = Number(raw.amount);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1_000_000_000) return null;
  amount = Math.round(amount * 100) / 100;
  const dayOfMonth = Math.min(31, Math.max(1, Math.round(Number(raw.dayOfMonth)) || 1));
  const lastPostedMonth = /^\d{4}-\d{2}$/.test(String(raw.lastPostedMonth || ""))
    ? String(raw.lastPostedMonth)
    : "";
  const id = String(raw.id || "")
    .trim()
    .slice(0, BUDGET_LIMITS.maxIdLength);
  return {
    id: id || `recurring-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    type,
    category,
    description: description || category,
    account: account || "Checking",
    amount,
    dayOfMonth,
    lastPostedMonth,
  };
}

function sanitizeSetupProfile(profile) {
  if (!profile || typeof profile !== "object") return null;
  const payFrequency = ["weekly", "biweekly", "semimonthly", "monthly"].includes(profile.payFrequency)
    ? profile.payFrequency
    : "biweekly";
  const payAmount = Number(profile.payAmount);
  const income = Number(profile.income);
  return {
    presetId: String(profile.presetId || "single").slice(0, 40),
    income: Number.isFinite(income) && income > 0 ? Math.min(income, 1_000_000_000) : 0,
    payAmount: Number.isFinite(payAmount) && payAmount > 0 ? Math.min(payAmount, 1_000_000_000) : 0,
    payFrequency,
    nextPayDate: /^\d{4}-\d{2}-\d{2}$/.test(String(profile.nextPayDate || ""))
      ? String(profile.nextPayDate)
      : "",
    completedAt: profile.completedAt ? String(profile.completedAt).slice(0, 40) : null,
    demo: Boolean(profile.demo),
  };
}

/**
 * Whitelist + cap budget state from import / cloud.
 * Drops unexpected keys (prototype pollution / gadget fields) and oversized arrays.
 */
export function sanitizeBudgetState(raw) {
  const safe = stripDangerousKeys(raw && typeof raw === "object" ? raw : {});
  const categories = Array.isArray(safe.categories)
    ? safe.categories
        .slice(0, BUDGET_LIMITS.maxCategories)
        .map(sanitizeCategory)
        .filter(Boolean)
    : [];
  const transactions = Array.isArray(safe.transactions)
    ? safe.transactions
        .slice(0, BUDGET_LIMITS.maxTransactions)
        .map(sanitizeTransaction)
        .filter(Boolean)
    : [];
  const recurring = Array.isArray(safe.recurring)
    ? safe.recurring
        .slice(0, BUDGET_LIMITS.maxRecurring)
        .map(sanitizeRecurringItem)
        .filter(Boolean)
    : [];
  return {
    categories,
    transactions,
    recurring,
    setupComplete: Boolean(safe.setupComplete ?? true),
    setupProfile: sanitizeSetupProfile(safe.setupProfile),
  };
}

/**
 * Validate / sanitize a cloud upsert payload before network write.
 * Returns a safe payload or throws.
 */
export function sanitizeCloudPayload(payload) {
  if (!payload || typeof payload !== "object") {
    throw new Error("Invalid budget payload.");
  }
  const state = sanitizeBudgetState(payload.state);
  if (!state.categories.length) {
    throw new Error("Budget payload is missing categories.");
  }
  let updatedAt = Number(payload.updatedAt);
  if (!Number.isFinite(updatedAt) || updatedAt < 0) updatedAt = Date.now();
  // Reject absurd future timestamps (clock skew abuse / overflow).
  if (updatedAt > Date.now() + 86_400_000) updatedAt = Date.now();
  const name = String(payload.name || "").slice(0, BUDGET_LIMITS.maxPayloadNameLength);
  return { state, updatedAt, name };
}

/** Reject oversized import files before parsing. */
export function assertImportFileSize(byteLength) {
  const size = Number(byteLength) || 0;
  if (size <= 0) throw new Error("Backup file is empty.");
  if (size > BUDGET_LIMITS.maxImportBytes) {
    throw new Error("Backup file is too large (max 2 MB).");
  }
  return size;
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
