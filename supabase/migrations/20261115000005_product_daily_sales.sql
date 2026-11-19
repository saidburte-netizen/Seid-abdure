create or replace view public.v_product_sales as
select
  p.id as product_id,
  p.name as product_name,
  (s.sale_date at time zone 'Africa/Addis_Ababa')::date as sale_day,
  sum(si.quantity) as quantity_sold,
  sum(si.line_total) as revenue,
  s.branch_id,
  date_trunc(
    'month',
    s.sale_date at time zone 'Africa/Addis_Ababa'
  )::date as sale_month,
  max(s.sale_date) as last_sold_at
from public.sale_items si
join public.sales s
  on s.id = si.sale_id
  and s.status = 'completed'
join public.products p on p.id = si.product_id
group by
  p.id,
  p.name,
  (s.sale_date at time zone 'Africa/Addis_Ababa')::date,
  date_trunc('month', s.sale_date at time zone 'Africa/Addis_Ababa'),
  s.branch_id;
