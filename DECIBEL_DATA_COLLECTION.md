# Decibel: Data Collection Pipeline & Supabase Architecture

**Target:** 20 Beta Testers | Per-Install Anonymous Identifiers | Offline-First SQLite | Supabase Postgres with RLS

---

## 1. High-Level Flow

```
 User plays / skips / likes / imports playlist
                 │
                 ▼
   PlaybackLogger (tags origin, records event & periodic checkpoints)
                 │
                 ▼
   Local SQLite  ──  play_events (synced = 0)      ← Works 100% offline
                 │
     flush triggers: app start, app resume, every 20 events, every ~15 min
                 │
                 ▼
   EventUploader: upsert tracks → upsert events (batch of 200, idempotent by UUID)
                 │   HTTPS + anonymous-auth JWT (No service-role key in app!)
                 ▼
   Supabase (Postgres + Row Level Security)
        installs · tracks · play_events · playlist_imports
                 │
                 ▼
   training_events view  →  CSV / Python  →  Evaluation, persona check, model fitting
```

---

## 2. Supabase SQL Schema (Run in Supabase SQL Editor)

Run the following block in Supabase **SQL Editor** -> **New Query**:

```sql
-- ============================================================
-- 1. TABLES
-- ============================================================

-- Installs: Each anonymous install gets a row tied to auth.uid()
create table if not exists public.installs (
  id            uuid primary key,                 -- = auth.uid()
  created_at    timestamptz not null default now(),
  consent_at    timestamptz,
  last_seen_at  timestamptz default now(),
  app_version   text,
  device_model  text,
  os_version    text,
  languages     text[],
  fav_artists   text[]
);

-- Tracks: Normalized shared track catalog
create table if not exists public.tracks (
  track_key         text primary key,
  artist_primary    text not null,
  artists_all       text[],
  language          text,
  genre             text,
  mood              text,
  era               text,
  tag_confidence    real default 1.0,
  provider          text,
  provider_track_id text,
  schema_version    int  not null default 1
);

-- Play Events: Every individual playback interaction
create table if not exists public.play_events (
  id                uuid primary key,             -- client-generated UUID
  install_id        uuid not null references public.installs(id) on delete cascade,
  track_key         text not null references public.tracks(track_key),
  seed_track_key    text,
  origin            text not null
                    check (origin in ('search','recommended','baseline','radio')),
  listened_ms       int  not null check (listened_ms >= 0),
  duration_ms       int  not null check (duration_ms > 0),
  liked             boolean not null default false,
  added_to_playlist boolean not null default false,
  downloaded        boolean not null default false,
  buffer_stall      boolean not null default false,
  score             real,
  score_parts       jsonb,
  temperature       real,
  model_version     text,
  hour_bucket       text check (hour_bucket in ('morning','afternoon','evening','night')),
  tz_offset_minutes int not null default 0,
  status            text not null default 'closed' check (status in ('closed','interrupted')),
  ended_reason      text check (ended_reason in ('completed','skipped','next','unknown')),
  occurred_at       timestamptz not null default now(),
  schema_version    int not null default 1,
  constraint score_parts_has_version check (score_parts is null or score_parts ? 'v')
);

-- Playlist Imports: Matched track keys only (privacy preserved)
create table if not exists public.playlist_imports (
  id               uuid primary key,
  install_id       uuid not null references public.installs(id) on delete cascade,
  source_platform  text not null,                 -- youtube | spotify | file | manual
  track_keys       text[] not null,               -- matched track_keys only
  matched          int not null,
  unmatched        int not null,
  imported_at      timestamptz not null default now()
);

-- ============================================================
-- MIGRATION STATEMENTS (Run if tables were already created previously)
-- ============================================================
-- alter table public.installs add column if not exists last_seen_at timestamptz default now();
-- alter table public.play_events add column if not exists status text not null default 'closed' check (status in ('closed','interrupted'));
-- alter table public.play_events add column if not exists ended_reason text check (ended_reason in ('completed','skipped','next','unknown'));
-- alter table public.play_events add column if not exists tz_offset_minutes int default 0;
-- alter table public.play_events drop constraint if exists score_parts_has_version;
-- alter table public.play_events add constraint score_parts_has_version check (score_parts is null or score_parts ? 'v');

-- Indexes for fast queries
create index if not exists idx_events_install on public.play_events(install_id);
create index if not exists idx_events_track   on public.play_events(track_key);
create index if not exists idx_events_time    on public.play_events(occurred_at);

-- ============================================================
-- 2. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

alter table public.installs         enable row level security;
alter table public.tracks           enable row level security;
alter table public.play_events      enable row level security;
alter table public.playlist_imports enable row level security;

-- Installs: Each install can only read, insert, and update its own profile
create policy installs_select_own on public.installs
  for select to authenticated using (id = auth.uid());
create policy installs_insert_own on public.installs
  for insert to authenticated with check (id = auth.uid());
create policy installs_update_own on public.installs
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Tracks: Shared catalog. Anyone signed in can read or add normalized track features
create policy tracks_select on public.tracks
  for select to authenticated using (true);
create policy tracks_insert on public.tracks
  for insert to authenticated with check (true);

-- Play Events: Insert only after consent, can only read own events
create policy events_insert_own on public.play_events
  for insert to authenticated
  with check (
    install_id = auth.uid()
    and exists (
      select 1 from public.installs i
      where i.id = auth.uid() and i.consent_at is not null
    )
  );
create policy events_select_own on public.play_events
  for select to authenticated using (install_id = auth.uid());

-- Playlist Imports: Same pattern
create policy imports_insert_own on public.playlist_imports
  for insert to authenticated
  with check (
    install_id = auth.uid()
    and exists (
      select 1 from public.installs i
      where i.id = auth.uid() and i.consent_at is not null
    )
  );
create policy imports_select_own on public.playlist_imports
  for select to authenticated using (install_id = auth.uid());

-- ============================================================
-- 3. USER DATA DELETION RPC (Cascades to all events & imports)
-- ============================================================

create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.installs where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_data() from public;
grant execute on function public.delete_my_data() to authenticated;

-- ============================================================
-- 4. TRAINING VIEW (For training/analysis)
-- ============================================================

create or replace view public.training_events
with (security_invoker = true) as
select
  e.id, e.install_id, e.origin, e.listened_ms, e.duration_ms,
  e.liked, e.added_to_playlist, e.downloaded, e.buffer_stall,
  e.score, e.score_parts, e.temperature, e.model_version,
  e.hour_bucket, e.tz_offset_minutes, e.status, e.ended_reason, e.occurred_at,
  t.track_key, t.artist_primary, t.language, t.genre, t.mood, t.era,
  s.artist_primary as seed_artist, s.language as seed_language,
  s.genre as seed_genre, s.mood as seed_mood
from public.play_events e
join public.tracks t on t.track_key = e.track_key
left join public.tracks s on s.track_key = e.seed_track_key;
```

---

## 3. Configuring Project Credentials
For security and open-source hygiene, database credentials are not committed to source control.

You can supply your Supabase project credentials via `--dart-define`:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Or copy `.env.json.example` to `.env.json` (which is git-ignored) and run:
```bash
flutter run --dart-define-from-file=.env.json
```
