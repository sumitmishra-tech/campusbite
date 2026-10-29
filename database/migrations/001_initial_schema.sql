create extension if not exists pgcrypto;
create type public.app_role as enum ('student','staff','owner');
create type public.student_category as enum ('day_scholar','hosteller');
create type public.order_status as enum ('pending_advance','payment_failed','confirmed','accepted','preparing','ready','collected','cancelled');
create type public.payment_status as enum ('created','pending','authorized','captured','failed','refund_pending','refunded','not_due');
create type public.emergency_status as enum ('requested','accepted','rejected','preparing','ready','collected');
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '',student_id text unique,department text,year smallint check(year between 1 and 4),role public.app_role not null default 'student',student_category public.student_category not null default 'day_scholar',hostel_verified boolean not null default false,is_blocked boolean not null default false,blocked_until timestamptz,abuse_count integer not null default 0 check(abuse_count>=0),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create index profiles_role_idx on public.profiles(role);create index profiles_blocked_idx on public.profiles(is_blocked,blocked_until);
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name,student_id,department,year,student_category) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),nullif(new.raw_user_meta_data->>'student_id',''),nullif(new.raw_user_meta_data->>'department',''),nullif(new.raw_user_meta_data->>'year','')::smallint,case when new.raw_user_meta_data->>'student_category'='hosteller' then 'hosteller'::public.student_category else 'day_scholar'::public.student_category end) on conflict(id) do nothing;return new;end;$$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create table public.menu_categories(id uuid primary key default gen_random_uuid(),name text not null unique,sort_order integer not null default 0,created_at timestamptz not null default now());
create table public.menu_items(id text primary key,name text not null,description text not null default '',category text not null references public.menu_categories(name),price_paise integer not null check(price_paise>0),image_url text,stock integer not null default 0 check(stock>=0),is_available boolean not null default true,is_archived boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create index menu_items_availability_idx on public.menu_items(is_available,is_archived,category);
create table public.pickup_slots(id uuid primary key default gen_random_uuid(),label text not null,starts_at timestamptz not null,ends_at timestamptz not null,capacity integer not null check(capacity>0),booked_count integer not null default 0 check(booked_count>=0),is_active boolean not null default true,created_at timestamptz not null default now(),check(ends_at>starts_at),check(booked_count<=capacity));create index pickup_slots_time_idx on public.pickup_slots(starts_at) where is_active;
create table public.orders(id uuid primary key default gen_random_uuid(),student_id uuid not null references public.profiles(id),status public.order_status not null,total_paise integer not null check(total_paise>=0),advance_due_paise integer not null default 0 check(advance_due_paise>=0),advance_paid_paise integer not null default 0 check(advance_paid_paise>=0),balance_due_paise integer not null default 0 check(balance_due_paise>=0),balance_collected_paise integer not null default 0 check(balance_collected_paise>=0),discount_paise integer not null default 0 check(discount_paise=0),pickup_slot_id uuid references public.pickup_slots(id),pickup_slot_label text not null,student_category_snapshot public.student_category not null,payment_mode text not null check(payment_mode in('razorpay','simulator','none')),payment_status public.payment_status not null default 'pending',idempotency_key text not null unique,cancellation_reason text,cancelled_at timestamptz,collected_at timestamptz,refund_status text not null default 'not_applicable' check(refund_status in('not_applicable','refund_pending','refunded','refund_failed')),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(advance_paid_paise<=total_paise),check(balance_due_paise+balance_collected_paise<=total_paise));
create index orders_student_created_idx on public.orders(student_id,created_at desc);create index orders_status_created_idx on public.orders(status,created_at desc);
create table public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,menu_item_id text references public.menu_items(id) on delete set null,item_name_snapshot text not null,unit_price_paise integer not null check(unit_price_paise>0),quantity integer not null check(quantity between 1 and 20),line_total_paise integer not null check(line_total_paise=unit_price_paise*quantity),created_at timestamptz not null default now());create index order_items_order_idx on public.order_items(order_id);
create table public.payments(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id),student_id uuid not null references public.profiles(id),provider text not null check(provider in('razorpay','simulator','counter')),provider_order_id text,provider_payment_id text,amount_paise integer not null check(amount_paise>=0),status public.payment_status not null default 'created',signature_verified boolean not null default false,webhook_event_id text unique,idempotency_key text not null unique,captured_at timestamptz,created_at timestamptz not null default now(),unique(provider,provider_payment_id));create index payments_order_idx on public.payments(order_id,status);
create table public.refunds(id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.payments(id),order_id uuid not null references public.orders(id),provider_payment_id text,provider_refund_id text unique,amount_paise integer not null check(amount_paise>0),status text not null default 'refund_pending' check(status in('refund_pending','processed','failed')),reason text,requested_by uuid references public.profiles(id),processed_at timestamptz,created_at timestamptz not null default now());
create table public.emergency_requests(id uuid primary key default gen_random_uuid(),student_id uuid not null references public.profiles(id),order_id uuid references public.orders(id),description text not null,items jsonb not null default '[]'::jsonb,status public.emergency_status not null default 'requested',assigned_staff_id uuid references public.profiles(id),staff_note text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());create index emergency_requests_status_idx on public.emergency_requests(status,created_at desc);
create table public.cancellations(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id),student_id uuid not null references public.profiles(id),reason text not null,refund_status text not null default 'not_applicable',misuse_confirmed boolean not null default false,reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,created_at timestamptz not null default now());create index cancellations_student_idx on public.cancellations(student_id,created_at desc);
create table public.order_status_history(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,from_status public.order_status,to_status public.order_status not null,actor_id uuid references public.profiles(id),note text,created_at timestamptz not null default now());create index order_history_order_idx on public.order_status_history(order_id,created_at);
create table public.audit_logs(id uuid primary key default gen_random_uuid(),actor_id uuid references public.profiles(id),action text not null,entity_type text not null,entity_id text,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default now());create index audit_logs_created_idx on public.audit_logs(created_at desc);
create table public.app_settings(key text primary key,value jsonb not null,updated_by uuid references public.profiles(id),updated_at timestamptz not null default now());insert into public.app_settings(key,value) values('anti_prank_policy','{"warning_after":2,"block_after":3,"block_hours":24}'::jsonb) on conflict do nothing;
create function public.current_app_role() returns public.app_role language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() $$;
create function public.is_canteen_staff() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role in('staff','owner')) $$;
alter table public.profiles enable row level security;alter table public.menu_categories enable row level security;alter table public.menu_items enable row level security;alter table public.pickup_slots enable row level security;alter table public.orders enable row level security;alter table public.order_items enable row level security;alter table public.payments enable row level security;alter table public.refunds enable row level security;alter table public.emergency_requests enable row level security;alter table public.cancellations enable row level security;alter table public.order_status_history enable row level security;alter table public.audit_logs enable row level security;alter table public.app_settings enable row level security;
create policy "profiles read own or staff" on public.profiles for select to authenticated using(id=auth.uid() or public.is_canteen_staff());
-- Profile changes are mediated by the authenticated API so students cannot self-promote or change verification/restriction fields.
create policy "menu categories public read" on public.menu_categories for select using(true);create policy "menu public read" on public.menu_items for select using(is_archived=false);create policy "slots public read" on public.pickup_slots for select using(is_active=true);
create policy "orders own or staff read" on public.orders for select to authenticated using(student_id=auth.uid() or public.is_canteen_staff());create policy "order items own or staff read" on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and(o.student_id=auth.uid() or public.is_canteen_staff())));create policy "payments own or staff read" on public.payments for select to authenticated using(student_id=auth.uid() or public.is_canteen_staff());create policy "refunds own or staff read" on public.refunds for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and(o.student_id=auth.uid() or public.is_canteen_staff())));create policy "emergency own or staff read" on public.emergency_requests for select to authenticated using(student_id=auth.uid() or public.is_canteen_staff());create policy "cancellations own or staff read" on public.cancellations for select to authenticated using(student_id=auth.uid() or public.is_canteen_staff());create policy "order history own or staff read" on public.order_status_history for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and(o.student_id=auth.uid() or public.is_canteen_staff())));create policy "audit owner read" on public.audit_logs for select to authenticated using(public.current_app_role()='owner');create policy "settings authenticated read" on public.app_settings for select to authenticated using(true);
-- Financial/order mutations intentionally have no browser write policies; validated server routes use service-role credentials.

-- Atomic checkout: lock the profile, pickup slot and menu rows; snapshot prices and reserve stock/capacity in one transaction.
create or replace function public.create_campusbite_order(p_student_id uuid,p_items jsonb,p_pickup_label text,p_payment_mode text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare prof public.profiles%rowtype; slot_row public.pickup_slots%rowtype; menu_row public.menu_items%rowtype; new_order public.orders%rowtype; item jsonb; line jsonb; lines jsonb:='[]'::jsonb; qty integer; total integer:=0; advance integer:=0; mode text; new_status public.order_status; pay_status public.payment_status;
begin
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>30 then raise exception 'Invalid order items'; end if;
  if exists(select 1 from (select value->>'menuItemId' as item_id,count(*) as n from jsonb_array_elements(p_items) group by value->>'menuItemId') d where n>1) then raise exception 'Duplicate menu items are not allowed'; end if;
  select * into prof from public.profiles where id=p_student_id for update;
  if not found or prof.role<>'student' then raise exception 'Student account required'; end if;
  if prof.is_blocked and (prof.blocked_until is null or prof.blocked_until>now()) then raise exception 'User is blocked from ordering'; end if;
  if prof.is_blocked and prof.blocked_until<=now() then update public.profiles set is_blocked=false,blocked_until=null where id=p_student_id; end if;
  if prof.student_category='hosteller' and not prof.hostel_verified then raise exception 'Hosteller verification is required'; end if;
  if p_payment_mode not in ('razorpay','simulator','none') then raise exception 'Invalid payment mode'; end if;
  mode:=case when prof.student_category='hosteller' then 'none' else p_payment_mode end;
  select * into slot_row from public.pickup_slots where label=p_pickup_label and is_active for update;
  if not found then raise exception 'Pickup slot is unavailable'; end if;
  if slot_row.booked_count>=slot_row.capacity then raise exception 'Pickup slot capacity is full'; end if;
  for item in select value from jsonb_array_elements(p_items) order by value->>'menuItemId' loop
    qty:=(item->>'quantity')::integer;
    if qty<1 or qty>20 then raise exception 'Invalid item quantity'; end if;
    select * into menu_row from public.menu_items where id=item->>'menuItemId' and is_available and not is_archived for update;
    if not found then raise exception 'Menu item is unavailable'; end if;
    if menu_row.stock<qty then raise exception 'Insufficient stock for %',menu_row.name; end if;
    total:=total+(menu_row.price_paise*qty);
    lines:=lines||jsonb_build_array(jsonb_build_object('menu_item_id',menu_row.id,'item_name_snapshot',menu_row.name,'unit_price_paise',menu_row.price_paise,'quantity',qty,'line_total_paise',menu_row.price_paise*qty));
  end loop;
  advance:=case when prof.student_category='day_scholar' then ceil(total*0.10)::integer else 0 end;
  new_status:=case when prof.student_category='hosteller' then 'confirmed'::public.order_status else 'pending_advance'::public.order_status end;
  pay_status:=case when prof.student_category='hosteller' then 'not_due'::public.payment_status else 'pending'::public.payment_status end;
  insert into public.orders(student_id,status,total_paise,advance_due_paise,balance_due_paise,discount_paise,pickup_slot_id,pickup_slot_label,student_category_snapshot,payment_mode,payment_status,idempotency_key)
  values(p_student_id,new_status,total,advance,total-advance,0,slot_row.id,slot_row.label,prof.student_category,mode,pay_status,p_idempotency_key) returning * into new_order;
  for line in select value from jsonb_array_elements(lines) loop
    insert into public.order_items(order_id,menu_item_id,item_name_snapshot,unit_price_paise,quantity,line_total_paise)
    values(new_order.id,line->>'menu_item_id',line->>'item_name_snapshot',(line->>'unit_price_paise')::integer,(line->>'quantity')::integer,(line->>'line_total_paise')::integer);
    update public.menu_items set stock=stock-(line->>'quantity')::integer,updated_at=now() where id=line->>'menu_item_id';
  end loop;
  update public.pickup_slots set booked_count=booked_count+1 where id=slot_row.id;
  insert into public.order_status_history(order_id,from_status,to_status,actor_id,note) values(new_order.id,null,new_status,p_student_id,'Order created atomically');
  return jsonb_build_object('order',to_jsonb(new_order),'items',lines);
end; $$;
revoke all on function public.create_campusbite_order(uuid,jsonb,text,text,text) from public,anon,authenticated;
grant execute on function public.create_campusbite_order(uuid,jsonb,text,text,text) to service_role;


-- Staff acceptance converts an emergency request into a normal hosteller order (zero advance, full balance after pickup).
create or replace function public.accept_campusbite_emergency_request(p_request_id uuid,p_staff_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare req public.emergency_requests%rowtype; prof public.profiles%rowtype; menu_row public.menu_items%rowtype; item jsonb; line jsonb; lines jsonb:='[]'::jsonb; qty integer; total integer:=0; new_order public.orders%rowtype;
begin
  select * into req from public.emergency_requests where id=p_request_id for update;
  if not found or req.status<>'requested' then raise exception 'Emergency request is no longer actionable'; end if;
  if jsonb_typeof(req.items)<>'array' or jsonb_array_length(req.items)<1 then raise exception 'Emergency request has no items'; end if;
  if exists(select 1 from (select value->>'menuItemId' as item_id,count(*) as n from jsonb_array_elements(req.items) group by value->>'menuItemId') d where n>1) then raise exception 'Duplicate emergency items are not allowed'; end if;
  select * into prof from public.profiles where id=req.student_id for update;
  if not found or prof.student_category<>'hosteller' or not prof.hostel_verified then raise exception 'Verified Hosteller required'; end if;
  if prof.is_blocked and (prof.blocked_until is null or prof.blocked_until>now()) then raise exception 'User is blocked from ordering'; end if;
  for item in select value from jsonb_array_elements(req.items) order by value->>'menuItemId' loop
    qty:=(item->>'quantity')::integer;
    if qty<1 or qty>10 then raise exception 'Invalid emergency item quantity'; end if;
    select * into menu_row from public.menu_items where id=item->>'menuItemId' and is_available and not is_archived for update;
    if not found then raise exception 'Emergency item is unavailable'; end if;
    if menu_row.stock<qty then raise exception 'Insufficient stock for %',menu_row.name; end if;
    total:=total+menu_row.price_paise*qty;
    lines:=lines||jsonb_build_array(jsonb_build_object('menu_item_id',menu_row.id,'item_name_snapshot',menu_row.name,'unit_price_paise',menu_row.price_paise,'quantity',qty,'line_total_paise',menu_row.price_paise*qty));
  end loop;
  insert into public.orders(student_id,status,total_paise,advance_due_paise,balance_due_paise,discount_paise,pickup_slot_id,pickup_slot_label,student_category_snapshot,payment_mode,payment_status,idempotency_key)
  values(req.student_id,'accepted',total,0,total,0,null,'Emergency pickup','hosteller','none','not_due','emergency-'||req.id::text) returning * into new_order;
  for line in select value from jsonb_array_elements(lines) loop
    insert into public.order_items(order_id,menu_item_id,item_name_snapshot,unit_price_paise,quantity,line_total_paise) values(new_order.id,line->>'menu_item_id',line->>'item_name_snapshot',(line->>'unit_price_paise')::integer,(line->>'quantity')::integer,(line->>'line_total_paise')::integer);
    update public.menu_items set stock=stock-(line->>'quantity')::integer,updated_at=now() where id=line->>'menu_item_id';
  end loop;
  update public.emergency_requests set status='accepted',assigned_staff_id=p_staff_id,order_id=new_order.id,updated_at=now() where id=req.id returning * into req;
  insert into public.order_status_history(order_id,from_status,to_status,actor_id,note) values(new_order.id,null,'accepted',p_staff_id,'Emergency request accepted by staff');
  return jsonb_build_object('request',to_jsonb(req),'order',to_jsonb(new_order));
end; $$;
revoke all on function public.accept_campusbite_emergency_request(uuid,uuid) from public,anon,authenticated;
grant execute on function public.accept_campusbite_emergency_request(uuid,uuid) to service_role;
