/**
 * Shared-budget SQL contract checks — run with: npm test
 * These are source-level guards; live RLS behavior still needs a Supabase
 * staging smoke test.
 */
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import assert from "node:assert/strict";

const sql = readFileSync(new URL("../supabase/shared-budgets.sql", import.meta.url), "utf8");

describe("shared-budget membership invariants", () => {
  it("enforces one shared budget per user", () => {
    assert.match(
      sql,
      /create unique index if not exists budget_members_one_shared_budget_per_user\s+on public\.budget_members \(user_id\);/i,
    );
  });

  it("allows self-leave only for non-owners", () => {
    assert.match(
      sql,
      /create policy "Member leaves budget"[\s\S]*?using \(user_id = auth\.uid\(\) and role = 'member'\);/i,
    );
  });

  it("keeps shared-budget deletion owner-only", () => {
    assert.match(
      sql,
      /create policy "Owner deletes shared budget"[\s\S]*?m\.role = 'owner'/i,
    );
  });

  it("rejects duplicate memberships before invite acceptance", () => {
    assert.match(
      sql,
      /if exists \([\s\S]*?from public\.budget_members[\s\S]*?where user_id = new\.requester_id[\s\S]*?raise exception 'user already has a shared budget'/i,
    );
  });
});
