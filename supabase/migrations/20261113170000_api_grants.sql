-- Explicit API grants.
--
-- Supabase projects normally install default grants for the API roles, but the
-- application must not depend on project-level defaults. RLS remains the
-- enforcement boundary; these grants only make the exposed schema reachable.

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;
revoke all on all tables in schema public from public;

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to service_role;
grant insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
grant execute on all functions in schema public to authenticated, service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage, select on sequences to authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;
alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges in schema public
  grant usage, select on sequences to service_role;
alter default privileges in schema public
  grant execute on functions to service_role;
