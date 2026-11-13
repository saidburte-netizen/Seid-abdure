-- Guarantees line totals and purchase order header totals stay consistent
-- regardless of whether the write came from the app, an RPC, or a migration.

create or replace function public.recalculate_purchase_order_totals(
  target_order uuid
)
returns void
language sql
as $$
  update public.purchase_orders
     set subtotal = coalesce((
           select sum(line_total)
           from public.purchase_order_items
           where purchase_order_id = target_order
         ), 0),
         total = coalesce((
           select sum(line_total)
           from public.purchase_order_items
           where purchase_order_id = target_order
         ), 0) + tax_total
   where id = target_order;
$$;

create or replace function public.set_purchase_order_item_total()
returns trigger
language plpgsql
as $$
begin
  new.line_total := round(new.quantity * new.unit_cost, 2);
  return new;
end;
$$;

create trigger purchase_order_items_total_guard
  before insert or update of quantity, unit_cost on public.purchase_order_items
  for each row execute function public.set_purchase_order_item_total();

create or replace function public.recalculate_purchase_order_from_trigger()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_purchase_order_totals(
    coalesce(new.purchase_order_id, old.purchase_order_id)
  );
  return null;
end;
$$;

create trigger purchase_order_items_header_guard
  after insert or update or delete on public.purchase_order_items
  for each row execute function public.recalculate_purchase_order_from_trigger();

create or replace function public.recalculate_purchase_order_from_tax_trigger()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_purchase_order_totals(new.id);
  return null;
end;
$$;

create trigger purchase_orders_total_guard
  after update of tax_total on public.purchase_orders
  for each row execute function public.recalculate_purchase_order_from_tax_trigger();

create or replace function public.set_sale_item_total()
returns trigger
language plpgsql
as $$
begin
  new.line_total := round(new.quantity * new.unit_price, 2);
  return new;
end;
$$;

create trigger sale_items_total_guard
  before insert or update of quantity, unit_price on public.sale_items
  for each row execute function public.set_sale_item_total();

create or replace function public.set_goods_receipt_item_total()
returns trigger
language plpgsql
as $$
begin
  new.line_total := round(new.quantity * new.unit_cost, 2);
  return new;
end;
$$;

create trigger goods_receipt_items_total_guard
  before insert or update of quantity, unit_cost on public.goods_receipt_items
  for each row execute function public.set_goods_receipt_item_total();

create or replace function public.set_sale_return_item_total()
returns trigger
language plpgsql
as $$
begin
  new.line_total := round(new.quantity * new.unit_price, 2);
  return new;
end;
$$;

create trigger sale_return_items_total_guard
  before insert or update of quantity, unit_price on public.sale_return_items
  for each row execute function public.set_sale_return_item_total();

-- Backfill any historical rows that predate the guards.
update public.purchase_order_items
   set line_total = round(quantity * unit_cost, 2);

update public.sale_items
   set line_total = round(quantity * unit_price, 2);

update public.goods_receipt_items
   set line_total = round(quantity * unit_cost, 2);

update public.sale_return_items
   set line_total = round(quantity * unit_price, 2);
