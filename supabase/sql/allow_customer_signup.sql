-- Optional customer self-service sign-up switch.
--
-- The app reads app_settings.allow_customer_signup while the visitor is still
-- signed out. If anonymous SELECT on app_settings is blocked by RLS, the app
-- safely falls back to "Contact the administrator to get an account."
insert into public.app_settings (key, value)
values ('allow_customer_signup', '{"enabled": true}'::jsonb)
on conflict (key) do update
set value = excluded.value;

comment on column public.app_settings.key is 'Business setting key.';
comment on column public.app_settings.value is 'JSON value for the setting.';
