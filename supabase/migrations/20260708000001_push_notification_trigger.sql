-- ─────────────────────────────────────────────────────────────────────────────
-- Push notification trigger
-- AFTER INSERT on public.notifications → calls send-push-notification Edge Fn
--
-- Prerequisites (run once in Supabase Dashboard > Vault):
--   1. Add secret name="supabase_url"          value="https://ndcafxuwdnighewzbdyp.supabase.co"
--   2. Add secret name="supabase_service_role"  value="<your service role key>"
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable pg_net if not already enabled
create extension if not exists pg_net schema extensions;

-- ── Trigger function ──────────────────────────────────────────────────────────

create or replace function public.notify_push_on_notification_insert()
returns trigger
language plpgsql
security definer
-- net and vault must be in search_path for pg_net and vault access to work
set search_path = public, extensions, net, vault
as $$
declare
  v_url          text;
  v_service_key  text;
  v_payload      jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'supabase_url';

  select decrypted_secret into v_service_key
  from vault.decrypted_secrets
  where name = 'supabase_service_role';

  if v_url is null or v_service_key is null then
    return new;
  end if;

  v_payload := jsonb_build_object(
    'agent_id',        new.agent_id,
    'title',           new.title,
    'message',         new.message,
    'related_lead_id', new.related_lead_id
  );

  perform net.http_post(
    url     := v_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body    := v_payload
  );

  return new;
exception when others then
  raise warning '[push] trigger error: %', sqlerrm;
  return new;
end;
$$;

-- Grant service_role access to device_tokens (needed by edge function)
grant select, delete on public.device_tokens to service_role;

-- ── Trigger ───────────────────────────────────────────────────────────────────

drop trigger if exists push_on_notification_insert on public.notifications;

create trigger push_on_notification_insert
  after insert on public.notifications
  for each row
  execute function public.notify_push_on_notification_insert();
