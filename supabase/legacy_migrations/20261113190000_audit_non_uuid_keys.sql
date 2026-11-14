-- Harden the generic audit trigger for singleton tables whose primary key is
-- not a UUID (organization_settings uses boolean true).

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  row_data jsonb;
  previous_data jsonb;
  branch uuid;
  entity uuid;
  action_name text;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
    previous_data := null;
    action_name := 'delete';
  elsif tg_op = 'UPDATE' then
    row_data := to_jsonb(new);
    previous_data := to_jsonb(old);
    action_name := 'update';
  else
    row_data := to_jsonb(new);
    previous_data := null;
    action_name := 'insert';
  end if;

  begin
    branch := nullif(row_data ->> 'branch_id', '')::uuid;
    if branch is null and tg_table_name = 'branches' then
      branch := nullif(row_data ->> 'id', '')::uuid;
    end if;
  exception when invalid_text_representation then
    branch := null;
  end;

  begin
    entity := nullif(row_data ->> 'id', '')::uuid;
  exception when invalid_text_representation then
    entity := null;
  end;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    branch,
    auth.uid(),
    action_name,
    tg_table_name,
    entity,
    jsonb_build_object('new', row_data, 'old', previous_data)
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.audit_row_change() from public, anon, authenticated;
