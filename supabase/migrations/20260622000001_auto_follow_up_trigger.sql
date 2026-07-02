-- ─────────────────────────────────────────────────────────────
-- Migration: auto-schedule a follow-up on every new lead insert.
--
-- OPTION B — rule-based automation.
-- TODO: Replace / augment with OPTION A (AI-suggested timing +
--       draft message) when that phase is built.  The trigger can
--       remain for guaranteed creation; the AI layer should then
--       update due_at and task_description in a second step rather
--       than skipping this row.
-- ─────────────────────────────────────────────────────────────

create or replace function public.auto_schedule_follow_up()
returns trigger as $$
declare
  v_due_at     timestamptz;
  v_priority   text;
begin
  -- 1. Compute due_at from NEW.timeline
  v_due_at := case NEW.timeline
    when 'immediate'      then now() + interval '1 day'
    when 'within_1_month' then now() + interval '3 days'
    when '1_3_months'     then now() + interval '7 days'
    when '3_6_months'     then now() + interval '14 days'
    when '6_plus_months'  then now() + interval '30 days'
    else                       now() + interval '7 days'
  end;

  -- 2. Derive priority from timeline + intent.
  --    New leads are always status='new' so status is not useful here.
  --    intent='buy' signals higher urgency than rent/invest.
  v_priority := case
    when NEW.timeline = 'immediate'
      then 'hot'
    when NEW.timeline = 'within_1_month' and NEW.intent = 'buy'
      then 'hot'
    when NEW.timeline = 'within_1_month'
      then 'warm'
    when NEW.timeline = '1_3_months'
      then 'warm'
    when NEW.timeline = '3_6_months' and NEW.intent = 'buy'
      then 'warm'
    else
      'warm'
  end;

  -- 3. Insert the follow-up row.
  insert into public.follow_ups
    (lead_id, agent_id, task_description, due_at, priority)
  values (
    NEW.id,
    NEW.agent_id,
    'Follow up with ' || NEW.name,
    v_due_at,
    v_priority
  );

  return NEW;
end;
$$ language plpgsql security definer;

create trigger trg_auto_follow_up
  after insert on public.leads
  for each row execute function public.auto_schedule_follow_up();
