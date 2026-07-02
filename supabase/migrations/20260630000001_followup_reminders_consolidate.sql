-- ─────────────────────────────────────────────────────────────────────────────
-- Consolidate follow-up reminder notifications: one per agent per cron run.
-- Adds related_follow_up_id to notifications for single-lead traceability.
--
-- Fixes vs prior live function:
--   1. last_reminded_at/interval gate removed from outer FOR loop (v_interval_hours
--      was unbound there, silently excluding re-remind-eligible agents).
--   2. All day-boundary comparisons use v_today_pkt (Asia/Karachi), not UTC now().
--   3. l.status != 'done' restored in both outer and inner queries.
--   4. One notification per agent per run (count=1 keeps per-lead format;
--      count>1 becomes a summary with up to 2 named leads + "N others").
-- ─────────────────────────────────────────────────────────────────────────────

-- Part 1: Traceability column — links single-lead notifications back to the
-- specific follow_up row that triggered them. Null for multi-lead summaries.
alter table public.notifications
  add column if not exists related_follow_up_id uuid
    references public.follow_ups(id) on delete set null;

-- Part 2: Rewritten function
create or replace function public.run_followup_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_pkt       timestamptz;

  v_agent_id        uuid;
  v_interval_hours  int;

  v_eligible_ids    uuid[];
  v_eligible_count  int;
  v_overdue_count   int;
  v_all_names       text[];

  v_notif_type      text;
  v_title           text;
  v_message         text;
  v_fu_id           uuid;
  v_remaining       int;
  v_names_str       text;
begin
  v_today_pkt := date_trunc('day', now() AT TIME ZONE 'Asia/Karachi')
                   AT TIME ZONE 'Asia/Karachi';

  -- Outer loop: agents with any incomplete, non-done-lead follow-up due within
  -- the PKT window. No last_reminded_at filter here — v_interval_hours is not
  -- yet bound; the timing gate runs in the inner query where it is bound.
  for v_agent_id, v_interval_hours in
    select distinct fu.agent_id, p.reminder_interval_hours
    from   public.follow_ups fu
    join   public.leads      l on l.id = fu.lead_id
    join   public.profiles   p on p.id = fu.agent_id
    where  fu.completed_at is null
      and  l.status != 'done'
      and  fu.due_at < v_today_pkt + interval '1 day'
      and  p.notify_follow_up_due = true
  loop
    begin

      -- Single pass collects all eligible rows for this agent.
      -- v_interval_hours is correctly bound here.
      select
        array_agg(fu.id   order by fu.due_at),
        count(*)::int,
        count(*) filter (where fu.due_at < v_today_pkt)::int,
        array_agg(l.name  order by fu.due_at)
      into v_eligible_ids, v_eligible_count, v_overdue_count, v_all_names
      from public.follow_ups fu
      join public.leads l on l.id = fu.lead_id
      where fu.agent_id = v_agent_id
        and fu.completed_at is null
        and l.status != 'done'
        and fu.due_at < v_today_pkt + interval '1 day'
        and (fu.last_reminded_at is null
             or fu.last_reminded_at < now() - (v_interval_hours::text || ' hours')::interval);

      if v_eligible_count is null or v_eligible_count = 0 then
        continue;
      end if;

      v_notif_type := case when v_overdue_count > 0 then 'overdue' else 'follow_up_due' end;

      if v_eligible_count = 1 then
        -- Single follow-up: keep per-lead format; populate related_follow_up_id.
        v_fu_id   := v_eligible_ids[1];
        v_title   := case when v_overdue_count > 0
                       then 'Overdue: ' || v_all_names[1]
                       else 'Follow-up due: ' || v_all_names[1]
                     end;
        v_message := case when v_overdue_count > 0
                       then v_all_names[1] || ' has an overdue follow-up. Tap to review.'
                       else v_all_names[1] || ' has a follow-up due today. Tap to review.'
                     end;

        insert into public.notifications
          (agent_id, type, title, message, related_lead_id, related_follow_up_id)
        select v_agent_id, v_notif_type, v_title, v_message, fu.lead_id, v_fu_id
        from   public.follow_ups fu
        where  fu.id = v_fu_id;

      else
        -- Multiple follow-ups: one summary notification.
        -- related_lead_id and related_follow_up_id both null.
        if v_eligible_count = 2 then
          v_names_str := v_all_names[1] || ' and ' || v_all_names[2];
        else
          v_remaining := v_eligible_count - 2;
          v_names_str := v_all_names[1] || ', ' || v_all_names[2]
            || ', and ' || v_remaining
            || ' other' || case when v_remaining > 1 then 's' else '' end;
        end if;

        v_title   := v_eligible_count || ' follow-ups need attention';
        v_message := v_names_str || case
          when v_overdue_count = v_eligible_count then ' are overdue.'
          when v_overdue_count > 0                then ' are overdue or due soon.'
          else                                         ' have follow-ups due today.'
        end;

        insert into public.notifications
          (agent_id, type, title, message)
        values
          (v_agent_id, v_notif_type, v_title, v_message);
      end if;

      -- Advance the gate on every included row whether count=1 or N.
      update public.follow_ups
      set    last_reminded_at = now()
      where  id = any(v_eligible_ids);

    exception when others then
      null;
    end;
  end loop;
end;
$$;
