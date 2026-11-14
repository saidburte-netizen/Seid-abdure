-- Customer self-service sign-up switch and anonymous-safe reader.
--
-- The app must never read app_settings directly before sign-in: anonymous
-- visitors cannot select that table under RLS. It calls this security-definer
-- RPC instead. The live project already owns the setting and the function; the
-- statements below are idempotent and are kept in the repository so a local
-- disposable stack can reproduce the same contract.

insert into public.app_settings (key, value)
values ('allow_customer_signup', '{"enabled": true}'::jsonb)
on conflict (key) do update
set value = excluded.value;

create or replace function public.customer_signup_allowed()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case
        when jsonb_typeof(value) = 'boolean' then (value)::text::boolean
        when jsonb_typeof(value) = 'object' then (value->>'enabled')::boolean
        else false
      end
      from public.app_settings
      where key = 'allow_customer_signup'
    ),
    false
  );
$$;

grant execute on function public.customer_signup_allowed() to anon, authenticated;

comment on column public.app_settings.key is 'Business setting key.';
comment on column public.app_settings.value is 'JSON value for the setting.';
