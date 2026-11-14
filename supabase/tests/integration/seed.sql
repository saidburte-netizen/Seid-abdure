-- Minimal catalog rows required by the integration contract.
-- These are idempotent so they work with the live schema fixture and with a
-- complete set of uploaded migrations.

insert into public.roles (code, name) values
  ('admin', 'Administrator'),
  ('manager', 'Manager'),
  ('cashier', 'Cashier'),
  ('baker', 'Baker'),
  ('store_keeper', 'Store keeper'),
  ('hr_officer', 'HR officer'),
  ('accountant', 'Accountant'),
  ('staff', 'Staff'),
  ('customer', 'Customer')
on conflict (code) do nothing;

insert into public.permissions (code, module) values
  ('sales.view', 'Sales'),
  ('sales.void', 'Sales'),
  ('production.manage', 'Production'),
  ('inventory.view', 'Inventory'),
  ('inventory.manage', 'Inventory'),
  ('products.view', 'Products'),
  ('cash.view', 'Cash'),
  ('cash.manage', 'Cash'),
  ('hr.view', 'HR'),
  ('hr.manage', 'HR'),
  ('payroll.manage', 'Payroll'),
  ('reports.view', 'Reports'),
  ('attendance.self', 'Attendance')
on conflict (code) do nothing;

insert into public.role_permissions (role_code, permission_code) values
  ('admin', 'sales.view'),
  ('admin', 'sales.void'),
  ('admin', 'production.manage'),
  ('admin', 'inventory.view'),
  ('admin', 'inventory.manage'),
  ('admin', 'products.view'),
  ('admin', 'cash.view'),
  ('admin', 'cash.manage'),
  ('admin', 'hr.view'),
  ('admin', 'hr.manage'),
  ('admin', 'payroll.manage'),
  ('admin', 'reports.view'),
  ('customer', 'products.view')
on conflict (role_code, permission_code) do nothing;

insert into public.app_settings (key, value, description)
values (
  'allow_customer_signup',
  '{"enabled": true}'::jsonb,
  'Show the customer create-account option on the login screen'
)
on conflict (key) do update set value = excluded.value;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;
