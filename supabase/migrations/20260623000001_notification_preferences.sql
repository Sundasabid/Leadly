-- Adds per-agent notification type toggles to profiles.
-- weekly_insight is pre-built for a future feature; the toggle is stored
-- now so the preference is respected as soon as the job is added.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notify_hot_leads      boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_follow_up_due  boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_weekly_insight boolean NOT NULL DEFAULT true;
