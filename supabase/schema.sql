-- Skylines · database schema
-- Run this once in your Supabase project: SQL Editor -> New query -> paste -> Run.
-- Safe to re-run; every statement is idempotent.

-- ---------------------------------------------------------------- flights
create table if not exists public.flights (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  flown_on    date not null,
  from_code   text not null check (char_length(from_code) between 3 and 4),
  to_code     text not null check (char_length(to_code)   between 3 and 4),
  airline     text not null default '',
  flight_no   text not null default '',
  miles       integer check (miles is null or miles >= 0),
  duration    text not null default '',          -- 'HH:MM'
  cabin       text not null default '',
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.flights is 'One row per flown segment. A round trip is two rows.';

create index if not exists flights_user_date_idx on public.flights (user_id, flown_on desc);

-- keep updated_at honest
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists flights_touch_updated_at on public.flights;
create trigger flights_touch_updated_at
  before update on public.flights
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------- row level security
-- Without these policies the anon key can read nothing. With them, a signed-in
-- user can only ever touch rows whose user_id matches their own auth.uid().
alter table public.flights enable row level security;

drop policy if exists "read own flights"   on public.flights;
drop policy if exists "insert own flights" on public.flights;
drop policy if exists "update own flights" on public.flights;
drop policy if exists "delete own flights" on public.flights;

create policy "read own flights" on public.flights
  for select to authenticated
  using (auth.uid() = user_id);

create policy "insert own flights" on public.flights
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "update own flights" on public.flights
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "delete own flights" on public.flights
  for delete to authenticated
  using (auth.uid() = user_id);

-- Supabase grants these by default; stating them explicitly means the schema
-- still works on a project whose default privileges have been changed.
grant select, insert, update, delete on public.flights to authenticated;

-- --------------------------------------------------------------- profiles
-- Optional: a display name to greet people with. Created automatically on signup.
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  home_airport text not null default '',
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile"   on public.profiles;
drop policy if exists "upsert own profile" on public.profiles;
drop policy if exists "update own profile" on public.profiles;

create policy "read own profile" on public.profiles
  for select to authenticated using (auth.uid() = id);
create policy "upsert own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "update own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

grant select, insert, update on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
