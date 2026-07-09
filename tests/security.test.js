/**
 * Security unit tests — run with: npm test
 * Uses Node's built-in test runner (no browser required).
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  assertOwnUserId,
  clearAuthFailures,
  escapeHtml,
  getAuthLockout,
  recordAuthFailure,
  redactForLog,
  sanitizeAuthError,
  validateAmount,
  validateCategoryName,
  validateDate,
  validateEmail,
  validatePassword,
} from "../security.js";

describe("escapeHtml", () => {
  it("escapes XSS vectors", () => {
    assert.equal(escapeHtml(`<img src=x onerror="alert(1)">`), "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;");
    assert.equal(escapeHtml("a & b"), "a &amp; b");
    assert.equal(escapeHtml("O'Reilly"), "O&#039;Reilly");
  });
});

describe("validateEmail", () => {
  it("accepts normal emails", () => {
    assert.equal(validateEmail("You@Example.com").ok, true);
    assert.equal(validateEmail("You@Example.com").value, "you@example.com");
  });
  it("rejects invalid emails", () => {
    assert.equal(validateEmail("").ok, false);
    assert.equal(validateEmail("not-an-email").ok, false);
    assert.equal(validateEmail("a@b").ok, false);
  });
});

describe("validatePassword", () => {
  it("enforces length and complexity", () => {
    assert.equal(validatePassword("short1").ok, false);
    assert.equal(validatePassword("allletters").ok, false);
    assert.equal(validatePassword("12345678").ok, false);
    assert.equal(validatePassword("GoodPass1").ok, true);
  });
});

describe("validateAmount / date / category", () => {
  it("rejects invalid amounts", () => {
    assert.equal(validateAmount(0).ok, false);
    assert.equal(validateAmount(-5).ok, false);
    assert.equal(validateAmount("abc").ok, false);
    assert.equal(validateAmount(12.345).value, 12.35);
  });
  it("validates dates", () => {
    assert.equal(validateDate("2026-07-09").ok, true);
    assert.equal(validateDate("07/09/2026").ok, false);
    assert.equal(validateDate("1999-01-01").ok, false);
  });
  it("rejects category XSS-ish names", () => {
    assert.equal(validateCategoryName("<script>").ok, false);
    assert.equal(validateCategoryName("  Groceries  ").value, "Groceries");
  });
});

describe("assertOwnUserId", () => {
  it("allows matching ids", () => {
    assert.equal(assertOwnUserId("abc", "abc"), "abc");
  });
  it("rejects mismatched or empty ids", () => {
    assert.throws(() => assertOwnUserId("abc", "xyz"));
    assert.throws(() => assertOwnUserId("", "abc"));
    assert.throws(() => assertOwnUserId("abc", ""));
  });
});

describe("auth rate limit helper", () => {
  it("locks after repeated failures", () => {
    const store = new Map();
    const storage = {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, v),
      removeItem: (k) => store.delete(k),
    };
    clearAuthFailures(storage);
    for (let i = 0; i < 4; i += 1) {
      const lock = recordAuthFailure(storage);
      assert.equal(lock.locked, false);
    }
    const locked = recordAuthFailure(storage);
    assert.equal(locked.locked, true);
    assert.ok(locked.retryAfterMs > 0);
    assert.equal(getAuthLockout(storage).locked, true);
    clearAuthFailures(storage);
    assert.equal(getAuthLockout(storage).locked, false);
  });
});

describe("sanitizeAuthError", () => {
  it("uses generic copy for credential and existence leaks", () => {
    const msg = sanitizeAuthError({ message: "Invalid login credentials" });
    assert.match(msg, /Unable to sign in/i);
    const exists = sanitizeAuthError({ message: "User already registered" });
    assert.match(exists, /Unable to sign in/i);
    assert.doesNotMatch(exists, /already has an account/i);
  });
});

describe("redactForLog", () => {
  it("redacts sensitive keys", () => {
    const out = redactForLog({ password: "secret", amount: 42, ok: true });
    assert.equal(out.password, "[redacted]");
    assert.equal(out.amount, "[redacted]");
    assert.equal(out.ok, true);
  });
});
