-- Budget Studio — Row Level Security (run in Supabase SQL Editor before launch)
-- Ensures every authenticated user can only read/write their own budget row.
-- Safe to re-run: policies are dropped/recreated; table is created if missing.

create table if not exists public.budgets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  state jsonb not null,
  updated_at bigint not null default 0,
  name text not null default ''
);

alter table public.budgets enable row level security;

-- Revoke broad grants; authenticated role uses RLS policies below.
revoke all on table public.budgets from anon;
grant select, insert, update, delete on table public.budgets to authenticated;

drop policy if exists "Users read own budget" on public.budgets;
create policy "Users read own budget"
  on public.budgets for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users insert own budget" on public.budgets;
create policy "Users insert own budget"
  on public.budgets for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users update own budget" on public.budgets;
create policy "Users update own budget"
  on public.budgets for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own budget" on public.budgets;
create policy "Users delete own budget"
  on public.budgets for delete
  to authenticated
  using (auth.uid() = user_id);

-- Optional: block PostgREST from exposing the table to the anon role entirely.
-- (Anon key is still used for Auth; RLS + revoke above is the real control.)

-- Verify after run:
--   select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename = 'budgets';
--   select policyname, cmd from pg_policies where tablename = 'budgets';
-- Expect rowsecurity = true and four policies (SELECT/INSERT/UPDATE/DELETE).
