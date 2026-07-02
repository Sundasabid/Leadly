-- =============================================================
-- Migration: 20260620000001_full_backend_schema.sql
-- Closes Phase 1 — all tables, indexes, RLS, triggers, views,
-- storage buckets. Run once on the dev Supabase project.
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- PART A: Fix `profiles` table to match backend-schema.md §2
-- ─────────────────────────────────────────────────────────────

-- A1. Drop the auto-create-profile trigger we built earlier.
--     The spec (§1) says profiles must be created by the app
--     during Onboarding, NOT automatically on signup — their
--     absence is exactly how the router knows to send a
--     logged-in user to Onboarding instead of Dashboard.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- A2. Rename columns that have wrong names.
alter table public.profiles rename column full_name to name;
alter table public.profiles rename column phone to phone_number;

-- A3. Drop columns that are not in the spec.
alter table public.profiles drop column if exists experience_years;
alter table public.profiles drop column if exists subscription_tier;
alter table public.profiles drop column if exists ai_credits;

-- A4. Add the three columns the spec requires that are missing.
alter table public.profiles
  add column if not exists agency_name  text not null default '',
  add column if not exists email        text,
  add column if not exists theme_preference text not null default 'light'
    check (theme_preference in ('light', 'dark'));

-- A5. Ensure updated_at is not null (it already has a default).
alter table public.profiles
  alter column created_at set not null,
  alter column updated_at set not null;


-- ─────────────────────────────────────────────────────────────
-- PART B: Generic updated_at trigger function
--         Write once, attach to every table with updated_at.
-- ─────────────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Attach to profiles
drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- ─────────────────────────────────────────────────────────────
-- PART C: `notifications` table — built BEFORE leads because
--         the hot-lead trigger references it.
--         Per backend-schema.md §5.
-- ─────────────────────────────────────────────────────────────

create table public.notifications (
  id            uuid        primary key default gen_random_uuid(),
  agent_id      uuid        not null references public.profiles(id) on delete cascade,
  type          text        not null
                            check (type in (
                              'new_hot_lead', 'follow_up_due',
                              'overdue', 'weekly_insight', 'system_update'
                            )),
  title         text        not null,
  message       text        not null,
  -- FK to leads added below after leads table is created (avoids forward-reference)
  related_lead_id uuid,
  is_read       boolean     not null default false,
  created_at    timestamptz not null default now()
);

-- Fast unread-count query for the bell badge
create index notifications_agent_read_idx
  on public.notifications(agent_id, is_read);

alter table public.notifications enable row level security;

create policy "agent own notifications" on public.notifications
  for all using     (agent_id = auth.uid())
  with check        (agent_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- PART D: `leads` table — per backend-schema.md §3.
-- ─────────────────────────────────────────────────────────────

create table public.leads (
  id                   uuid        primary key default gen_random_uuid(),
  agent_id             uuid        not null references public.profiles(id) on delete cascade,
  name                 text        not null,
  phone                text        not null,
  budget_pkr           numeric,
  area_society         text        not null,
  property_type        text        not null
                                   check (property_type in (
                                     'house', 'plot', 'apartment', 'commercial', 'other'
                                   )),
  intent               text        not null
                                   check (intent in ('buy', 'rent', 'invest')),
  timeline             text        not null
                                   check (timeline in (
                                     'immediate', 'within_1_month',
                                     '1_3_months', '3_6_months', '6_plus_months'
                                   )),
  notes                text,
  status               text        not null default 'new'
                                   check (status in ('new', 'hot', 'warm', 'cold', 'done')),
  source               text        not null default 'manual'
                                   check (source in ('manual', 'voice')),
  extraction_confidence numeric    check (extraction_confidence between 0 and 1),
  -- Self-referencing FK: set when agent chooses "Continue Anyway" on
  -- the S10 duplicate warning. Points at the lead it was flagged against.
  linked_duplicate_of  uuid        references public.leads(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- Duplicate-phone lookup for S10, and fast status filtering for S05/S11
create index leads_agent_phone_idx  on public.leads(agent_id, phone);
create index leads_agent_status_idx on public.leads(agent_id, status);

alter table public.leads enable row level security;

create policy "agent own leads" on public.leads
  for all using     (agent_id = auth.uid())
  with check        (agent_id = auth.uid());

-- Now that leads exists, add the FK from notifications to leads
alter table public.notifications
  add constraint notifications_related_lead_id_fkey
  foreign key (related_lead_id) references public.leads(id) on delete set null;

-- Attach updated_at trigger
create trigger trg_leads_updated_at
  before update on public.leads
  for each row execute function public.set_updated_at();


-- ─────────────────────────────────────────────────────────────
-- PART E: Hot-lead trigger — per §3.
--         Fires on insert or status-change TO 'hot'.
--         Lives in the DB so it fires regardless of which
--         client (app, Edge Function, dashboard) makes the change.
-- ─────────────────────────────────────────────────────────────

create or replace function public.notify_hot_lead()
returns trigger as $$
begin
  if (tg_op = 'INSERT' and new.status = 'hot') or
     (tg_op = 'UPDATE' and new.status = 'hot' and old.status <> 'hot')
  then
    insert into public.notifications
      (agent_id, type, title, message, related_lead_id)
    values (
      new.agent_id,
      'new_hot_lead',
      'Hot Lead Alert',
      new.name || ' has been marked as a hot lead',
      new.id
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_hot_lead_notify
  after insert or update of status on public.leads
  for each row execute function public.notify_hot_lead();


-- ─────────────────────────────────────────────────────────────
-- PART F: `follow_ups` + `follow_ups_with_status` view
--         Per backend-schema.md §4.
-- ─────────────────────────────────────────────────────────────

create table public.follow_ups (
  id               uuid        primary key default gen_random_uuid(),
  lead_id          uuid        not null references public.leads(id)    on delete cascade,
  agent_id         uuid        not null references public.profiles(id) on delete cascade,
  task_description text        not null,
  due_at           timestamptz not null,
  priority         text        not null default 'warm'
                               check (priority in ('hot', 'warm', 'cold')),
  completed_at     timestamptz,
  -- Set every time a reminder notification is sent for this follow-up.
  -- Prevents the recurring-reminders job from spamming on every cron run.
  last_reminded_at timestamptz,
  created_at       timestamptz not null default now()
);

create index follow_ups_agent_due_idx on public.follow_ups(agent_id, due_at);

alter table public.follow_ups enable row level security;

create policy "agent own follow_ups" on public.follow_ups
  for all using     (agent_id = auth.uid())
  with check        (agent_id = auth.uid());

-- View: derived status column so S13's four tabs are simple
-- filters on one column, not four separate queries with
-- duplicated date logic. security_invoker = true means the
-- view runs with the caller's permissions, so RLS still applies.
create or replace view public.follow_ups_with_status
  with (security_invoker = true)
as
select
  f.*,
  case
    when f.completed_at is not null
      then 'completed'
    when f.due_at < date_trunc('day', now())
      then 'overdue'
    when f.due_at < date_trunc('day', now()) + interval '1 day'
      then 'due_today'
    else
      'upcoming'
  end as derived_status
from public.follow_ups f;


-- ─────────────────────────────────────────────────────────────
-- PART G: `insights_cache` — per backend-schema.md §7.
--         Agents can only SELECT their own rows.
--         INSERT/UPDATE/DELETE are service-role only (no client
--         policy = RLS denies authenticated clients by default).
-- ─────────────────────────────────────────────────────────────

create table public.insights_cache (
  agent_id                uuid   not null references public.profiles(id) on delete cascade,
  period_start            date   not null,
  period_end              date   not null,
  top_performing_area     jsonb,
  trending_property_type  jsonb,
  most_active_budget_range jsonb,
  hottest_demand_category jsonb,
  demand_trend            jsonb,
  area_performance        jsonb,
  computed_at             timestamptz not null default now(),
  primary key (agent_id, period_start)
);

alter table public.insights_cache enable row level security;

-- Read-only for the authenticated client; service role bypasses RLS for writes
create policy "agent select insights" on public.insights_cache
  for select using (agent_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- PART H: `device_tokens` — per §6.
-- ─────────────────────────────────────────────────────────────

create table public.device_tokens (
  id         uuid        primary key default gen_random_uuid(),
  agent_id   uuid        not null references public.profiles(id) on delete cascade,
  token      text        not null unique,
  platform   text        not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now()
);

create index device_tokens_agent_idx on public.device_tokens(agent_id);

alter table public.device_tokens enable row level security;

create policy "agent own device_tokens" on public.device_tokens
  for all using     (agent_id = auth.uid())
  with check        (agent_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- PART I: `app_events` — from dev plan §0.
--         Schema not in backend-schema.md so kept minimal:
--         a simple event log scoped per agent.
-- ─────────────────────────────────────────────────────────────

create table public.app_events (
  id         uuid        primary key default gen_random_uuid(),
  agent_id   uuid        not null references public.profiles(id) on delete cascade,
  event_type text        not null,
  payload    jsonb,
  created_at timestamptz not null default now()
);

create index app_events_agent_idx on public.app_events(agent_id);

alter table public.app_events enable row level security;

-- Agents read their own events; app writes via authenticated client
create policy "agent read app_events" on public.app_events
  for select using  (agent_id = auth.uid());

create policy "agent insert app_events" on public.app_events
  for insert with check (agent_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- PART J: Table-level GRANTs for the authenticated role
--         Layer 1 of Postgres security — who can access the table.
--         RLS policies (layer 2) then control which rows they see.
-- ─────────────────────────────────────────────────────────────

grant usage on schema public to authenticated;

grant select, insert, update         on public.profiles       to authenticated;
grant select, insert, update, delete on public.leads          to authenticated;
grant select, insert, update, delete on public.follow_ups     to authenticated;
grant select, insert, update, delete on public.notifications  to authenticated;
grant select                         on public.insights_cache to authenticated;
grant select, insert, update, delete on public.device_tokens  to authenticated;
grant select, insert                 on public.app_events     to authenticated;


-- ─────────────────────────────────────────────────────────────
-- PART K: Storage buckets + path-based ownership RLS
--         Per backend-schema.md §8.
--         Convention: every file path starts with {agent_id}/
-- ─────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('voice-recordings', 'voice-recordings', false)
on conflict (id) do nothing;

-- avatars: publicly readable, but only owner can write under their folder
create policy "avatars public read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars agent insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars agent update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars agent delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- voice-recordings: fully private, only owner can read or write
create policy "voice agent insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'voice-recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "voice agent select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'voice-recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "voice agent delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'voice-recordings'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
