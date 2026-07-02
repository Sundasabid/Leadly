-- ─────────────────────────────────────────────────────────────────────────────
-- generate_weekly_insights() + pg_cron schedule
-- Runs every Monday at 00:05 UTC over the Mon-Sun window that just closed.
-- Demand is read from leads.created_at — no calls table exists yet.
-- All date boundaries use Asia/Karachi to match Pakistani calendar days.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.generate_weekly_insights()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today         date;
  v_period_start  date;
  v_period_end    date;

  v_agent_id  uuid;
  v_notify    boolean;

  v_demand_trend      jsonb;
  v_top_area          text;   v_top_area_count      int;
  v_top_prop          text;   v_top_prop_count      int;
  v_top_budget        text;   v_top_budget_count    int;
  v_top_intent        text;   v_top_intent_count    int;

  v_prior_area_count    int;
  v_prior_prop_count    int;
  v_prior_budget_count  int;
  v_prior_intent_count  int;
begin
  v_today        := (now() AT TIME ZONE 'Asia/Karachi')::date;
  v_period_start := (date_trunc('week', v_today) - interval '7 days')::date;
  v_period_end   := (date_trunc('week', v_today) - interval '1 day')::date;

  for v_agent_id, v_notify in
    select distinct l.agent_id, p.notify_weekly_insight
    from   public.leads    l
    join   public.profiles p on p.id = l.agent_id
    where  (l.created_at AT TIME ZONE 'Asia/Karachi')::date
             between v_period_start and v_period_end
  loop
    begin

      select jsonb_agg(
               jsonb_build_object(
                 'date',  to_char(gs.day::date, 'YYYY-MM-DD'),
                 'count', coalesce(c.cnt, 0)
               )
               order by gs.day
             )
      into   v_demand_trend
      from   generate_series(
               v_period_start::timestamptz,
               v_period_end::timestamptz,
               '1 day'
             ) as gs(day)
      left join (
        select (created_at AT TIME ZONE 'Asia/Karachi')::date as d,
               count(*)::int as cnt
        from   public.leads
        where  agent_id = v_agent_id
          and  (created_at AT TIME ZONE 'Asia/Karachi')::date
                 between v_period_start and v_period_end
        group  by 1
      ) c on c.d = gs.day::date;

      select area_society, count(*)::int
      into   v_top_area, v_top_area_count
      from   public.leads
      where  agent_id = v_agent_id
        and  (created_at AT TIME ZONE 'Asia/Karachi')::date
               between v_period_start and v_period_end
      group  by area_society
      order  by count(*) desc
      limit  1;

      select property_type, count(*)::int
      into   v_top_prop, v_top_prop_count
      from   public.leads
      where  agent_id = v_agent_id
        and  (created_at AT TIME ZONE 'Asia/Karachi')::date
               between v_period_start and v_period_end
      group  by property_type
      order  by count(*) desc
      limit  1;

      select bucket, cnt
      into   v_top_budget, v_top_budget_count
      from (
        select
          case
            when budget_pkr is null          then 'Unspecified'
            when budget_pkr < 5000000        then 'Under 50L'
            when budget_pkr < 10000000       then '50L - 1Cr'
            when budget_pkr < 20000000       then '1Cr - 2Cr'
            when budget_pkr < 50000000       then '2Cr - 5Cr'
            else                                  '5Cr+'
          end          as bucket,
          count(*)::int as cnt
        from   public.leads
        where  agent_id = v_agent_id
          and  (created_at AT TIME ZONE 'Asia/Karachi')::date
                 between v_period_start and v_period_end
        group  by 1
        order  by 2 desc
        limit  1
      ) t;

      select intent, count(*)::int
      into   v_top_intent, v_top_intent_count
      from   public.leads
      where  agent_id = v_agent_id
        and  (created_at AT TIME ZONE 'Asia/Karachi')::date
               between v_period_start and v_period_end
      group  by intent
      order  by count(*) desc
      limit  1;

      select
        (top_performing_area     ->>'count')::int,
        (trending_property_type  ->>'count')::int,
        (most_active_budget_range->>'count')::int,
        (hottest_demand_category ->>'count')::int
      into
        v_prior_area_count,
        v_prior_prop_count,
        v_prior_budget_count,
        v_prior_intent_count
      from   public.insights_cache
      where  agent_id    = v_agent_id
        and  period_start = v_period_start - 7;

      insert into public.insights_cache (
        agent_id, period_start, period_end,
        demand_trend,
        top_performing_area,
        trending_property_type,
        most_active_budget_range,
        hottest_demand_category,
        area_performance,
        computed_at
      )
      values (
        v_agent_id, v_period_start, v_period_end,
        v_demand_trend,
        jsonb_build_object(
          'name',       v_top_area,
          'count',      v_top_area_count,
          'change_pct', case
            when v_prior_area_count is null or v_prior_area_count = 0 then null::numeric
            else round(((v_top_area_count - v_prior_area_count)::numeric
                        / v_prior_area_count) * 100, 1)
          end
        ),
        jsonb_build_object(
          'name',       v_top_prop,
          'count',      v_top_prop_count,
          'change_pct', case
            when v_prior_prop_count is null or v_prior_prop_count = 0 then null::numeric
            else round(((v_top_prop_count - v_prior_prop_count)::numeric
                        / v_prior_prop_count) * 100, 1)
          end
        ),
        jsonb_build_object(
          'name',       v_top_budget,
          'count',      v_top_budget_count,
          'change_pct', case
            when v_prior_budget_count is null or v_prior_budget_count = 0 then null::numeric
            else round(((v_top_budget_count - v_prior_budget_count)::numeric
                        / v_prior_budget_count) * 100, 1)
          end
        ),
        jsonb_build_object(
          'name',       v_top_intent,
          'count',      v_top_intent_count,
          'change_pct', case
            when v_prior_intent_count is null or v_prior_intent_count = 0 then null::numeric
            else round(((v_top_intent_count - v_prior_intent_count)::numeric
                        / v_prior_intent_count) * 100, 1)
          end
        ),
        null,
        now()
      )
      on conflict (agent_id, period_start) do update set
        period_end               = excluded.period_end,
        demand_trend             = excluded.demand_trend,
        top_performing_area      = excluded.top_performing_area,
        trending_property_type   = excluded.trending_property_type,
        most_active_budget_range = excluded.most_active_budget_range,
        hottest_demand_category  = excluded.hottest_demand_category,
        area_performance         = excluded.area_performance,
        computed_at              = excluded.computed_at;

      if v_notify then
        insert into public.notifications (agent_id, type, title, message)
        values (
          v_agent_id,
          'weekly_insight',
          'Your Weekly Insights Are Ready',
          'Based on your leads from ' ||
            to_char(v_period_start, 'Mon DD') || ' - ' ||
            to_char(v_period_end,   'Mon DD') || '.'
        );
      end if;

    exception when others then
      null;
    end;

  end loop;
end;
$$;

-- Register cron schedule (idempotent: remove any prior schedule by name first)
select cron.unschedule(jobid)
from   cron.job
where  jobname = 'generate-weekly-insights';

select cron.schedule(
  'generate-weekly-insights',
  '5 0 * * 1',
  $$select public.generate_weekly_insights();$$
);
