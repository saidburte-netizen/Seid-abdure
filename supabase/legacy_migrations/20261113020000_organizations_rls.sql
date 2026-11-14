create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  currency text not null default 'ETB'
    check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.branches
  add column organization_id uuid;

alter table public.roles
  add column organization_id uuid;

alter table public.branch_memberships
  add column organization_id uuid;

do $$
declare
  legacy_organization_id uuid;
begin
  if exists (select 1 from public.branches)
    or exists (select 1 from public.roles) then
    insert into public.organizations (name, slug)
    values ('Migrated organization', 'migrated-organization')
    returning id into legacy_organization_id;

    update public.branches
    set organization_id = legacy_organization_id
    where organization_id is null;

    update public.roles role
    set organization_id = coalesce(
      (select branch.organization_id
       from public.branches branch
       where branch.id = role.branch_id),
      legacy_organization_id
    )
    where role.organization_id is null;

    update public.branch_memberships membership
    set organization_id = branch.organization_id
    from public.branches branch
    where branch.id = membership.branch_id
      and membership.organization_id is null;
  end if;
end;
$$;

alter table public.branches
  alter column organization_id set not null,
  drop constraint branches_code_key,
  add constraint branches_organization_id_fkey
    foreign key (organization_id)
    references public.organizations (id) on delete cascade,
  add constraint branches_id_organization_id_key
    unique (id, organization_id),
  add constraint branches_organization_code_key
    unique (organization_id, code);

alter table public.roles
  alter column organization_id set not null,
  drop constraint roles_branch_id_slug_key,
  drop constraint roles_branch_id_fkey,
  add constraint roles_organization_id_fkey
    foreign key (organization_id)
    references public.organizations (id) on delete cascade,
  add constraint roles_branch_organization_fkey
    foreign key (branch_id, organization_id)
    references public.branches (id, organization_id) on delete cascade,
  add constraint roles_id_organization_id_key
    unique (id, organization_id),
  add constraint roles_organization_scope_slug_key
    unique nulls not distinct (organization_id, branch_id, slug);

alter table public.branch_memberships
  alter column organization_id set not null,
  drop constraint branch_memberships_branch_id_fkey,
  drop constraint branch_memberships_role_id_fkey,
  add constraint branch_memberships_organization_id_fkey
    foreign key (organization_id)
    references public.organizations (id) on delete cascade,
  add constraint branch_memberships_branch_organization_fkey
    foreign key (branch_id, organization_id)
    references public.branches (id, organization_id) on delete cascade,
  add constraint branch_memberships_role_organization_fkey
    foreign key (role_id, organization_id)
    references public.roles (id, organization_id);

create index branches_organization_idx
  on public.branches (organization_id);
create index branch_memberships_organization_user_active_idx
  on public.branch_memberships (organization_id, user_id)
  where is_active;

create or replace function public.user_has_organization_access(
  target_organization uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.branch_memberships membership
    join public.branches branch
      on branch.id = membership.branch_id
     and branch.organization_id = membership.organization_id
    where branch.organization_id = target_organization
      and membership.user_id = auth.uid()
      and membership.is_active
  );
$$;

revoke all on function public.user_has_organization_access(uuid)
  from public, anon;
grant execute on function public.user_has_organization_access(uuid)
  to authenticated;

create or replace function public.check_membership_role_branch()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  role_branch_id uuid;
begin
  select role.branch_id
  into role_branch_id
  from public.roles role
  where role.id = new.role_id
    and role.organization_id = new.organization_id;

  if not found then
    raise exception 'Role must belong to the membership organization'
      using errcode = '23503';
  end if;

  if role_branch_id is not null
    and role_branch_id is distinct from new.branch_id then
    raise exception 'Branch-scoped role must match the membership branch'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function public.check_membership_role_branch()
  from public, anon, authenticated;

create trigger check_membership_role_branch
  before insert or update of branch_id, organization_id, role_id
  on public.branch_memberships
  for each row execute function public.check_membership_role_branch();

alter table public.organizations enable row level security;

create policy "Members can read their organizations"
  on public.organizations for select to authenticated
  using (public.user_has_organization_access(id));

drop policy "Authenticated users can read role catalog"
  on public.roles;
create policy "Members can read organization roles"
  on public.roles for select to authenticated
  using (
    public.user_has_organization_access(organization_id)
    and (
      branch_id is null
      or public.user_has_branch_access(branch_id)
    )
  );

drop policy "Authenticated users can read role permissions"
  on public.role_permissions;
create policy "Members can read their role permissions"
  on public.role_permissions for select to authenticated
  using (
    exists (
      select 1
      from public.roles role
      where role.id = role_id
        and public.user_has_organization_access(role.organization_id)
        and (
          role.branch_id is null
          or public.user_has_branch_access(role.branch_id)
        )
    )
  );
