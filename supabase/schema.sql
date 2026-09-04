-- Skylines - database schema
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

-- ============================================================== scrapbook
-- Added after the first release; re-running the whole file is safe.

-- per-flight colour, empty string means "use the default amber"
alter table public.flights add column if not exists color text not null default '';

-- ------------------------------------------------------------- places
-- Pins dropped anywhere on the globe, for somewhere that is not an airport.
create table if not exists public.places (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  lat         double precision not null check (lat between -90 and 90),
  lon         double precision not null check (lon between -180 and 180),
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists places_user_idx on public.places (user_id);

drop trigger if exists places_touch_updated_at on public.places;
create trigger places_touch_updated_at
  before update on public.places
  for each row execute function public.touch_updated_at();

alter table public.places enable row level security;
drop policy if exists "read own places"   on public.places;
drop policy if exists "insert own places" on public.places;
drop policy if exists "update own places" on public.places;
drop policy if exists "delete own places" on public.places;
create policy "read own places"   on public.places for select to authenticated using (auth.uid() = user_id);
create policy "insert own places" on public.places for insert to authenticated with check (auth.uid() = user_id);
create policy "update own places" on public.places for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own places" on public.places for delete to authenticated using (auth.uid() = user_id);
grant select, insert, update, delete on public.places to authenticated;

-- ------------------------------------------------------------- entries
-- A note, photo or video attached to exactly one of: a flight, an airport
-- code, or a pinned place.
create table if not exists public.entries (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  flight_id    uuid references public.flights (id) on delete cascade,
  airport_code text check (airport_code is null or char_length(airport_code) between 3 and 4),
  place_id     uuid references public.places (id) on delete cascade,
  kind         text not null check (kind in ('note','photo','video')),
  body         text not null default '',   -- note text, or a caption
  storage_path text not null default '',   -- photos: object key in the scrapbook bucket
  video_url    text not null default '',   -- videos: the link to embed
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint entries_one_target check (num_nonnulls(flight_id, airport_code, place_id) = 1),
  constraint entries_payload check (
    (kind = 'note'  and body <> '') or
    (kind = 'photo' and storage_path <> '') or
    (kind = 'video' and video_url <> '')
  )
);
create index if not exists entries_user_idx    on public.entries (user_id, created_at desc);
create index if not exists entries_flight_idx  on public.entries (flight_id);
create index if not exists entries_airport_idx on public.entries (user_id, airport_code);
create index if not exists entries_place_idx   on public.entries (place_id);

drop trigger if exists entries_touch_updated_at on public.entries;
create trigger entries_touch_updated_at
  before update on public.entries
  for each row execute function public.touch_updated_at();

alter table public.entries enable row level security;
drop policy if exists "read own entries"   on public.entries;
drop policy if exists "insert own entries" on public.entries;
drop policy if exists "update own entries" on public.entries;
drop policy if exists "delete own entries" on public.entries;
create policy "read own entries"   on public.entries for select to authenticated using (auth.uid() = user_id);
create policy "insert own entries" on public.entries for insert to authenticated with check (auth.uid() = user_id);
create policy "update own entries" on public.entries for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own entries" on public.entries for delete to authenticated using (auth.uid() = user_id);
grant select, insert, update, delete on public.entries to authenticated;

-- ------------------------------------------------------------- storage
-- Private bucket; the app reads through short-lived signed URLs. Every object
-- lives under a folder named for its owner's uid, which is what the policies
-- below check.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scrapbook', 'scrapbook', false, 10485760,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "read own media"   on storage.objects;
drop policy if exists "insert own media" on storage.objects;
drop policy if exists "update own media" on storage.objects;
drop policy if exists "delete own media" on storage.objects;
create policy "read own media" on storage.objects for select to authenticated
  using (bucket_id = 'scrapbook' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "insert own media" on storage.objects for insert to authenticated
  with check (bucket_id = 'scrapbook' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "update own media" on storage.objects for update to authenticated
  using (bucket_id = 'scrapbook' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own media" on storage.objects for delete to authenticated
  using (bucket_id = 'scrapbook' and (storage.foldername(name))[1] = auth.uid()::text);

-- ------------------------------------------------------------- trips
-- Trips are derived from the flight chain by default; this column only holds
-- a name once you override the automatic grouping.
alter table public.flights add column if not exists trip text not null default '';
create index if not exists flights_trip_idx on public.flights (user_id, trip) where trip <> '';
