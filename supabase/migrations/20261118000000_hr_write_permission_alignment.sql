-- 20261118000000_hr_write_permission_alignment.sql
--
-- The HR screen is permission-based (`hr.manage`), while the live employees
-- write policy only allowed the admin and hr_officer roles. A manager who has
-- hr.manage could therefore open the form and then receive a row-level
-- security error on save. Align the write policy with the same roles that can
-- already read the employee list.
--
-- Safe to run more than once.

begin;

drop policy if exists "employees_write" on public.employees;

create policy "employees_write"
  on public.employees
  as permissive
  for all
  to authenticated
  using (public.has_any_role(array['admin', 'manager', 'hr_officer']))
  with check (public.has_any_role(array['admin', 'manager', 'hr_officer']));

commit;
