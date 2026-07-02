-- Fixes day-boundary computation to use Pakistan timezone (Asia/Karachi,
-- UTC+5) instead of UTC midnight, so overdue/due_today/upcoming
-- derived_status matches what the agent's phone shows in Lahore/Pakistan.
--
-- WITH (security_invoker = true) re-stated explicitly — Postgres does not
-- carry this forward on CREATE OR REPLACE VIEW.

create or replace view public.follow_ups_with_status
  with (security_invoker = true)
as
select
  f.*,
  case
    when f.completed_at is not null
      then 'completed'
    when f.due_at < date_trunc('day', now() AT TIME ZONE 'Asia/Karachi') AT TIME ZONE 'Asia/Karachi'
      then 'overdue'
    when f.due_at < (date_trunc('day', now() AT TIME ZONE 'Asia/Karachi') AT TIME ZONE 'Asia/Karachi') + interval '1 day'
      then 'due_today'
    else
      'upcoming'
  end as derived_status,
  l.name         as lead_name,
  l.area_society as lead_area
from public.follow_ups f
join public.leads l on l.id = f.lead_id;
