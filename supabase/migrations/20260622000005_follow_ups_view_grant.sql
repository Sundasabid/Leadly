-- The authenticated role needs an explicit SELECT grant on the view
-- object itself. security_invoker controls whose RLS policies apply
-- (the caller's), but it does not substitute for object-level access.
-- The underlying tables (leads, follow_ups) already have grants from
-- the Phase 1 migration — this closes the gap on the view.

grant select on public.follow_ups_with_status to authenticated;
