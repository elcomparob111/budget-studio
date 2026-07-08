-- Budget Studio: one row per user, locked down with row level security.
create table if not exists public.budgets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  state jsonb not null,
  updated_at bigint not null default 0,
  name text not null default ''
);

alter table public.budgets enable row level security;

drop policy if exists "Users read own budget" on public.budgets;
create policy "Users read own budget"
  on public.budgets for select
  using (auth.uid () = user_id);

drop policy if exists "Users insert own budget" on public.budgets;
create policy "Users insert own budget"
  on public.budgets for insert
  with check (auth.uid () = user_id);

drop policy if exists "Users update own budget" on public.budgets;
create policy "Users update own budget"
  on public.budgets for update
  using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

drop policy if exists "Users delete own budget" on public.budgets;
create policy "Users delete own budget"
  on public.budgets for delete
  using (auth.uid () = user_id);
