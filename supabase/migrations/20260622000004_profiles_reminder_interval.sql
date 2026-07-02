-- Adds reminder_interval_hours to profiles so agents can configure
-- how often the Edge Function re-reminds them about overdue follow-ups.
-- NOT NULL DEFAULT 12 backfills all existing rows at migration time.
-- CHECK constraint mirrors the four options shown in the UI, so the DB
-- rejects any value that didn't come from the picker.

alter table public.profiles
  add column reminder_interval_hours integer not null default 12
  check (reminder_interval_hours in (4, 12, 24, 48));
