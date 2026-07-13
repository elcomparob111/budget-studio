-- Budget Studio — Shared/couples budgets (P0). DO NOT run against production
-- until reviewed; see docs/SHARED_BUDGETS.md. Safe to re-run (idempotent).
--
-- Additive design: personal budgets in public.budgets are untouched. A shared
-- budget is a separate row both partners read/write, joined via invite token.

-- 1. Shared budget state (same JSON-blob + last-write-wins model as budgets).
create table if not exists public.shared_budgets (
  id uuid primary key default gen_random_uuid(),
  state jsonb not null,
  updated_at bigint not null default 0,
  name text not null default '',
  created_by uuid not null references auth.users (id) on delete cascade
);

-- 2. Membership (owner + members; couples = 2 rows, but not limited to 2).
create table if not exists public.budget_members (
  budget_id uuid not null references public.shared_budgets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (budget_id, user_id)
);

-- 3. Invite links (single-use, expiring). The token IS the secret — the app
--    builds the link as https://<app>/?join=<token>.
create table if not exists public.budget_invites (
  token uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.shared_budgets (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by uuid references auth.users (id)
);

alter table public.shared_budgets enable row level security;
alter table public.budget_members enable row level security;
alter table public.budget_invites enable row level security;

revoke all on table public.shared_budgets from anon;
revoke all on table public.budget_members from anon;
revoke all on table public.budget_invites from anon;
grant select, insert, update, delete on table public.shared_budgets to authenticated;
grant select, delete on table public.budget_members to authenticated;
grant select, insert, delete on table public.budget_invites to authenticated;

-- Membership check helper. SECURITY DEFINER so shared_budgets policies can
-- consult budget_members without recursive RLS evaluation.
create or replace function public.is_budget_member(bid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.budget_members
    where budget_id = bid and user_id = auth.uid()
  );
$$;

-- shared_budgets: members read/write; anyone authed may create (becoming owner
-- via the RPC below — direct inserts must name themselves as creator).
drop policy if exists "Members read shared budget" on public.shared_budgets;
create policy "Members read shared budget"
  on public.shared_budgets for select
  to authenticated
  using (public.is_budget_member(id));

drop policy if exists "Creator inserts shared budget" on public.shared_budgets;
create policy "Creator inserts shared budget"
  on public.shared_budgets for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "Members update shared budget" on public.shared_budgets;
create policy "Members update shared budget"
  on public.shared_budgets for update
  to authenticated
  using (public.is_budget_member(id))
  with check (public.is_budget_member(id));

drop policy if exists "Owner deletes shared budget" on public.shared_budgets;
create policy "Owner deletes shared budget"
  on public.shared_budgets for delete
  to authenticated
  using (
    exists (
      select 1 from public.budget_members m
      where m.budget_id = id and m.user_id = auth.uid() and m.role = 'owner'
    )
  );

-- budget_members: members see the roster; a user may remove THEMSELF (leave).
-- Rows are inserted only by the security-definer RPCs below.
drop policy if exists "Members read roster" on public.budget_members;
create policy "Members read roster"
  on public.budget_members for select
  to authenticated
  using (public.is_budget_member(budget_id));

drop policy if exists "Member leaves budget" on public.budget_members;
create policy "Member leaves budget"
  on public.budget_members for delete
  to authenticated
  using (user_id = auth.uid());

-- budget_invites: creator manages their own invites. NOT selectable by token
-- holders — acceptance goes through the RPC so tokens never leak via SELECT.
drop policy if exists "Creator reads own invites" on public.budget_invites;
create policy "Creator reads own invites"
  on public.budget_invites for select
  to authenticated
  using (created_by = auth.uid());

drop policy if exists "Owner creates invites" on public.budget_invites;
create policy "Owner creates invites"
  on public.budget_invites for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.budget_members m
      where m.budget_id = budget_invites.budget_id
        and m.user_id = auth.uid() and m.role = 'owner'
    )
  );

drop policy if exists "Creator revokes invites" on public.budget_invites;
create policy "Creator revokes invites"
  on public.budget_invites for delete
  to authenticated
  using (created_by = auth.uid());

-- RPC: create a shared budget seeded from the caller's state, owner membership
-- included, all-or-nothing.
create or replace function public.create_shared_budget(initial_state jsonb, budget_name text default '')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  bid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.shared_budgets (state, updated_at, name, created_by)
  values (initial_state, (extract(epoch from now()) * 1000)::bigint, budget_name, auth.uid())
  returning id into bid;
  insert into public.budget_members (budget_id, user_id, role)
  values (bid, auth.uid(), 'owner');
  return bid;
end;
$$;

-- RPC: redeem an invite token. Validates expiry + single use, adds caller as
-- member, marks token used. Returns the budget id to switch to.
create or replace function public.accept_budget_invite(invite_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  select * into inv from public.budget_invites
  where token = invite_token
  for update;
  if not found then
    raise exception 'invite not found';
  end if;
  if inv.used_by is not null then
    raise exception 'invite already used';
  end if;
  if inv.expires_at < now() then
    raise exception 'invite expired';
  end if;
  insert into public.budget_members (budget_id, user_id, role)
  values (inv.budget_id, auth.uid(), 'member')
  on conflict (budget_id, user_id) do nothing;
  update public.budget_invites set used_by = auth.uid() where token = invite_token;
  return inv.budget_id;
end;
$$;

revoke all on function public.create_shared_budget(jsonb, text) from anon, public;
revoke all on function public.accept_budget_invite(uuid) from anon, public;
grant execute on function public.create_shared_budget(jsonb, text) to authenticated;
grant execute on function public.accept_budget_invite(uuid) to authenticated;

-- Realtime: partners get live updates when the other writes.
-- Requires the table added to the supabase_realtime publication:
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'shared_budgets'
  ) then
    alter publication supabase_realtime add table public.shared_budgets;
  end if;
end;
$$;

-- Verify after run:
--   select tablename, rowsecurity from pg_tables where schemaname='public'
--     and tablename in ('shared_budgets','budget_members','budget_invites');
--   select policyname, tablename, cmd from pg_policies
--     where tablename in ('shared_budgets','budget_members','budget_invites');
