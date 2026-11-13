-- Align stored defaults with the official business identity.

alter table public.organization_settings
  alter column legal_name set default 'Brade and Cake House',
  alter column trade_name set default 'Brade and Cake House',
  alter column receipt_footer set default 'Thank you for choosing Brade and Cake House.';

update public.organization_settings
   set legal_name = 'Brade and Cake House'
 where legal_name in ('Bread & Cake', 'Bread & Cake Management');

update public.organization_settings
   set trade_name = 'Brade and Cake House'
 where trade_name in ('Bread & Cake', 'Bread & Cake Management');

update public.organization_settings
   set receipt_footer = 'Thank you for choosing Brade and Cake House.'
 where receipt_footer = 'Thank you for your business.';
