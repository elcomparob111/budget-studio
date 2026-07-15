/**
 * Security unit tests — run with: npm test
 * Uses Node's built-in test runner (no browser required).
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  assertImportFileSize,
  assertOwnUserId,
  BUDGET_LIMITS,
  clearAuthFailures,
  escapeHtml,
  getAuthLockout,
  recordAuthFailure,
  redactForLog,
  sanitizeAuthError,
  sanitizeBudgetState,
  sanitizeCloudPayload,
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
    assert.throws(() => assertOwnUserId("abc", "xyz"), /own budget/i);
    assert.throws(() => assertOwnUserId("", "abc"), /signed in/i);
    assert.throws(() => assertOwnUserId("abc", ""), /own budget/i);
    assert.throws(() => assertOwnUserId(null, "abc"), /signed in/i);
  });
});

describe("sanitizeBudgetState", () => {
  it("strips prototype pollution and unexpected keys", () => {
    const polluted = JSON.parse(
      '{"categories":[{"name":"Rent","type":"Expense","group":"Needs","budget":100,"__proto__":{"polluted":true}}],"transactions":[],"evil":1}',
    );
    const out = sanitizeBudgetState(polluted);
    assert.equal(Object.prototype.polluted, undefined);
    assert.equal(out.evil, undefined);
    assert.equal(out.categories.length, 1);
    assert.equal(out.categories[0].name, "Rent");
    assert.ok(!Object.hasOwn(out.categories[0], "__proto__"));
    assert.ok(!Object.hasOwn(out, "evil"));
  });

  it("caps oversized arrays and strips XSS-ish names", () => {
    const cats = Array.from({ length: BUDGET_LIMITS.maxCategories + 50 }, (_, i) => ({
      name: i === 0 ? "<script>x</script>" : `Cat${i}`,
      type: "Expense",
      group: "Needs",
      budget: 10,
    }));
    const txs = Array.from({ length: 5 }, () => ({
      id: "1",
      date: "2026-07-09",
      type: "Expense",
      category: "Cat1",
      description: "<img onerror=1>",
      account: "Checking",
      amount: 5,
    }));
    const out = sanitizeBudgetState({ categories: cats, transactions: txs, setupComplete: true });
    assert.ok(out.categories.length <= BUDGET_LIMITS.maxCategories);
    assert.ok(!out.categories[0].name.includes("<"));
    assert.ok(!out.transactions[0].description.includes("<"));
  });

  it("strips attribute-breaking characters from transaction ids", () => {
    const out = sanitizeBudgetState({
      categories: [{ name: "Salary", type: "Income", group: "Income", budget: 0 }],
      transactions: [
        {
          id: `evil"><img src=x onerror=alert(1)>`,
          date: "2026-07-09",
          type: "Expense",
          category: "X",
          description: "ok",
          account: "Checking",
          amount: 5,
          addedBy: `uid"><script>`,
          addedByName: "Alex",
        },
      ],
    });
    assert.equal(out.transactions.length, 1);
    assert.equal(out.transactions[0].id, "evilimgsrcxonerroralert1");
    assert.equal(out.transactions[0].addedBy, "uidscript");
  });

  it("drops invalid transactions", () => {
    const out = sanitizeBudgetState({
      categories: [{ name: "Salary", type: "Income", group: "Income", budget: 0 }],
      transactions: [
        { id: "a", date: "bad", type: "Expense", category: "X", description: "y", account: "Checking", amount: 1 },
        { id: "b", date: "2026-07-09", type: "Hack", category: "X", description: "y", account: "Checking", amount: 1 },
        { id: "c", date: "2026-07-09", type: "Expense", category: "X", description: "y", account: "Checking", amount: -1 },
        {
          id: "d",
          date: "2026-07-09",
          type: "Expense",
          category: "X",
          description: "ok",
          account: "Checking",
          amount: 12.345,
        },
      ],
    });
    assert.equal(out.transactions.length, 1);
    assert.equal(out.transactions[0].amount, 12.35);
  });
});

describe("sanitizeCloudPayload", () => {
  it("requires categories and clamps name", () => {
    assert.throws(() => sanitizeCloudPayload({ state: { categories: [], transactions: [] } }));
    const safe = sanitizeCloudPayload({
      state: {
        categories: [{ name: "Salary", type: "Income", group: "Income", budget: 0 }],
        transactions: [],
      },
      updatedAt: Date.now(),
      name: "x".repeat(200),
      user_id: "attacker-uid",
    });
    assert.equal(safe.name.length, BUDGET_LIMITS.maxPayloadNameLength);
    assert.equal(safe.user_id, undefined);
  });
});

describe("assertImportFileSize", () => {
  it("rejects empty and oversized files", () => {
    assert.throws(() => assertImportFileSize(0));
    assert.throws(() => assertImportFileSize(BUDGET_LIMITS.maxImportBytes + 1));
    assert.equal(assertImportFileSize(100), 100);
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
