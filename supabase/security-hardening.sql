-- Budget Studio — security hardening (P0/P1 from security review).
-- Safe to re-run. Run in Supabase SQL Editor after rls.sql / shared-budgets.sql.
--
-- 1) Server authority for updated_at (ignore client clocks / forged timestamps)
-- 2) Soft size cap on JSON state blobs (abuse / partner DoS)

-- ---------------------------------------------------------------------------
-- updated_at: always set from server clock on insert/update
-- ---------------------------------------------------------------------------
create or replace function public.set_budget_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  NEW.updated_at := (extract(epoch from now()) * 1000)::bigint;
  return NEW;
end;
$$;

drop trigger if exists budgets_set_updated_at on public.budgets;
create trigger budgets_set_updated_at
  before insert or update on public.budgets
  for each row
  execute function public.set_budget_updated_at();

drop trigger if exists shared_budgets_set_updated_at on public.shared_budgets;
create trigger shared_budgets_set_updated_at
  before insert or update on public.shared_budgets
  for each row
  execute function public.set_budget_updated_at();

-- ---------------------------------------------------------------------------
-- State size caps (~1.5 MB). Client already caps arrays; this blocks REST abuse.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'budgets'
  ) then
    alter table public.budgets drop constraint if exists budgets_state_size;
    alter table public.budgets
      add constraint budgets_state_size
      check (pg_column_size(state) <= 1500000);
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'shared_budgets'
  ) then
    alter table public.shared_budgets drop constraint if exists shared_budgets_state_size;
    alter table public.shared_budgets
      add constraint shared_budgets_state_size
      check (pg_column_size(state) <= 1500000);
  end if;
end;
$$;

-- Verify:
--   select tgname from pg_trigger where tgname like '%set_updated_at%';
--   select conname from pg_constraint where conname like '%state_size%';
