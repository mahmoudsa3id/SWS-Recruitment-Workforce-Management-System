-- SWS complete schema install. Apply only to an empty/test database. Keep migration order.



-- ===== 202610160001_sws_clean_schema.sql =====
-- SWS clean schema baseline. Review and apply to a NEW/test Supabase project first.
begin;
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 email text, full_name text not null default '', role text not null default 'admin' check (role='admin'),
 is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.travelers (
 id uuid primary key default gen_random_uuid(), file_no text unique,
 full_name text not null check(length(trim(full_name))>0), phone text not null,
 agreement_total numeric(14,2) not null default 0 check(agreement_total>=0),
 sales_person text, destination_country text,
 stage_submitted boolean not null default false, stage_inspected boolean not null default false,
 stage_visa boolean not null default false, stage_flight boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id)
);
create table if not exists public.financial_movements (
 id uuid primary key default gen_random_uuid(), receipt_no text unique,
 traveler_id uuid references public.travelers(id), movement_type text not null check(movement_type in ('traveler_collection','general_revenue','office_expense','payroll_payment','reversal','correction')),
 direction text not null check(direction in ('credit','debit')), amount numeric(14,2) not null check(amount>0),
 payment_method text not null default 'cash' check(payment_method in ('cash','instapay','bank_transfer','wallet','other')),
 note text, status text not null default 'posted' check(status in ('posted','reversed','void')),
 reverses_movement_id uuid references public.financial_movements(id), created_at timestamptz not null default now(),
 created_by uuid references auth.users(id), idempotency_key uuid unique
);
create table if not exists public.traveler_documents (
 id uuid primary key default gen_random_uuid(), traveler_id uuid not null references public.travelers(id) on delete cascade,
 document_type text not null check(document_type in ('الصورة والباسبور','التأشيرة','إثبات التاريخ','تذكرة الطيران','مستندات أخرى')),
 file_name text not null, storage_path text not null, mime_type text, file_size bigint check(file_size is null or file_size>=0),
 created_at timestamptz not null default now(), created_by uuid references auth.users(id)
);
create table if not exists public.office_expenses (
 id uuid primary key default gen_random_uuid(), movement_id uuid not null unique references public.financial_movements(id), category text not null, description text not null default '', created_at timestamptz not null default now()
);
create table if not exists public.payroll_records (
 id uuid primary key default gen_random_uuid(), employee_name text not null, month_start date not null,
 base_salary numeric(14,2) not null default 0 check(base_salary>=0), commission numeric(14,2) not null default 0,
 deductions numeric(14,2) not null default 0, paid_amount numeric(14,2) not null default 0 check(paid_amount>=0),
 status text not null default 'open' check(status in ('open','closed')), created_at timestamptz not null default now(), unique(employee_name,month_start)
);
create table if not exists public.monthly_closings (
 id uuid primary key default gen_random_uuid(), month_start date not null unique, opening_balance numeric(14,2) not null default 0,
 closing_balance numeric(14,2) not null default 0, closed_at timestamptz, closed_by uuid references auth.users(id),
 reopened_at timestamptz, reopened_by uuid references auth.users(id), reopen_reason text, status text not null default 'open' check(status in ('open','closed'))
);
create table if not exists public.audit_log (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id), action text not null,
 entity_type text not null, entity_id text, before_data jsonb, after_data jsonb, reason text, created_at timestamptz not null default now()
);
create index if not exists idx_travelers_created_at on public.travelers(created_at desc);
create index if not exists idx_travelers_name on public.travelers using gin(to_tsvector('simple',full_name));
create index if not exists idx_movements_traveler_created on public.financial_movements(traveler_id,created_at desc);
create index if not exists idx_movements_created on public.financial_movements(created_at desc);
create index if not exists idx_documents_traveler on public.traveler_documents(traveler_id,created_at desc);
create or replace function public.sws_record_traveler_payment(p_traveler_id uuid,p_amount numeric,p_payment_method text default 'cash',p_note text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_receipt text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.profiles where user_id=auth.uid() and role='admin' and is_active) then raise exception 'Admin access required'; end if;
 if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
 if not exists(select 1 from public.travelers where id=p_traveler_id) then raise exception 'Traveler not found'; end if;
 v_receipt := 'SWS-'||to_char(now(),'YYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
 insert into public.financial_movements(receipt_no,traveler_id,movement_type,direction,amount,payment_method,note,created_by)
 values(v_receipt,p_traveler_id,'traveler_collection','credit',p_amount,p_payment_method,p_note,auth.uid()) returning id into v_id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'payment_recorded','financial_movement',v_id::text,jsonb_build_object('traveler_id',p_traveler_id,'amount',p_amount,'receipt_no',v_receipt));
 return v_id;
end $$;
create or replace function public.sws_reverse_movement(p_movement_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.financial_movements%rowtype; v_id uuid; v_receipt text;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where user_id=auth.uid() and role='admin' and is_active) then raise exception 'Admin access required'; end if;
 if coalesce(trim(p_reason),'')='' then raise exception 'A reversal reason is required'; end if;
 select * into m from public.financial_movements where id=p_movement_id for update;
 if not found then raise exception 'Movement not found'; end if;
 if m.status<>'posted' then raise exception 'Only posted movements can be reversed'; end if;
 if m.movement_type='reversal' then raise exception 'A reversal movement cannot be reversed'; end if;
 if exists(select 1 from public.financial_movements where reverses_movement_id=m.id) then raise exception 'Movement already reversed'; end if;
 v_receipt := 'REV-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
 insert into public.financial_movements(receipt_no,traveler_id,movement_type,direction,amount,payment_method,note,status,reverses_movement_id,created_by)
 values(v_receipt,m.traveler_id,'reversal',case when m.direction='credit' then 'debit' else 'credit' end,m.amount,m.payment_method,'عكس حركة '||m.receipt_no||' — '||trim(p_reason),'posted',m.id,auth.uid()) returning id into v_id;
 update public.financial_movements set status='reversed' where id=m.id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason) values(auth.uid(),'movement_reversed','financial_movement',m.id::text,to_jsonb(m),jsonb_build_object('reversal_id',v_id,'receipt_no',v_receipt),trim(p_reason));
 return v_id;
end $$;
create or replace function public.sws_is_active_admin() returns boolean language sql stable security definer set search_path=public,pg_temp as $$ select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.role='admin' and p.is_active) $$;
revoke all on function public.sws_is_active_admin() from public; grant execute on function public.sws_is_active_admin() to authenticated;
alter table public.profiles enable row level security; alter table public.travelers enable row level security; alter table public.financial_movements enable row level security; alter table public.traveler_documents enable row level security; alter table public.office_expenses enable row level security; alter table public.payroll_records enable row level security; alter table public.monthly_closings enable row level security; alter table public.audit_log enable row level security;
drop policy if exists sws_admin_all on public.profiles; drop policy if exists sws_profile_self_read on public.profiles; create policy sws_profile_self_read on public.profiles for select to authenticated using (user_id=auth.uid()); drop policy if exists sws_profile_admin_update on public.profiles; create policy sws_profile_admin_update on public.profiles for update to authenticated using (public.sws_is_active_admin()) with check (public.sws_is_active_admin());
do $$ declare t text; begin foreach t in array array['travelers','financial_movements','traveler_documents','office_expenses','payroll_records','monthly_closings','audit_log'] loop execute format('drop policy if exists sws_admin_all on public.%I',t); execute format('create policy sws_admin_all on public.%I for all to authenticated using (public.sws_is_active_admin()) with check (public.sws_is_active_admin())',t); end loop; end $$;
grant execute on function public.sws_record_traveler_payment(uuid,numeric,text,text) to authenticated;
grant execute on function public.sws_reverse_movement(uuid,text) to authenticated;
commit;



-- ===== 202610160002_sws_operations.sql =====
-- SWS operational RPCs. Apply after 202610160001_sws_clean_schema.sql on a test project first.
begin;
create or replace function public.sws_require_admin() returns void language plpgsql security definer set search_path=public,auth as $$
begin if auth.uid() is null or not exists(select 1 from public.profiles where user_id=auth.uid() and role='admin' and is_active) then raise exception 'Admin access required'; end if; end $$;
revoke all on function public.sws_require_admin() from public;
create or replace function public.sws_record_office_expense(p_amount numeric,p_payment_method text,p_category text,p_description text default '') returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_receipt text;
begin perform public.sws_require_admin(); if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if; if coalesce(trim(p_category),'')='' then raise exception 'Category is required'; end if; if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
 v_receipt:='EXP-'||to_char(now(),'YYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
 insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by) values(v_receipt,'office_expense','debit',p_amount,p_payment_method,trim(coalesce(p_description,'')),auth.uid()) returning id into v_id;
 insert into public.office_expenses(movement_id,category,description) values(v_id,trim(p_category),trim(coalesce(p_description,'')));
 insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'office_expense_created','financial_movement',v_id::text,jsonb_build_object('amount',p_amount,'category',p_category,'receipt_no',v_receipt)); return v_id; end $$;
create or replace function public.sws_record_general_revenue(p_amount numeric,p_payment_method text,p_note text) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; begin perform public.sws_require_admin(); if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if; insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by) values('REVN-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),'general_revenue','credit',p_amount,p_payment_method,trim(coalesce(p_note,'')),auth.uid()) returning id into v_id; insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'general_revenue_created','financial_movement',v_id::text,jsonb_build_object('amount',p_amount,'note',p_note)); return v_id; end $$;
create or replace function public.sws_pay_payroll(p_payroll_id uuid,p_amount numeric,p_payment_method text default 'cash',p_note text default null) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.payroll_records%rowtype; v_id uuid; v_due numeric;
begin perform public.sws_require_admin(); if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if; select * into r from public.payroll_records where id=p_payroll_id for update; if not found then raise exception 'Payroll record not found'; end if; v_due:=r.base_salary+r.commission-r.deductions-r.paid_amount; if p_amount>v_due then raise exception 'Payment exceeds outstanding payroll amount'; end if;
 insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by) values('PAY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),'payroll_payment','debit',p_amount,p_payment_method,coalesce(p_note,'دفع راتب: '||r.employee_name),auth.uid()) returning id into v_id;
 update public.payroll_records set paid_amount=paid_amount+p_amount,status=case when paid_amount+p_amount>=base_salary+commission-deductions then 'closed' else 'open' end where id=p_payroll_id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data) values(auth.uid(),'payroll_payment_recorded','payroll_record',p_payroll_id::text,jsonb_build_object('movement_id',v_id,'amount',p_amount)); return v_id; end $$;
create or replace function public.sws_close_month(p_month date,p_note text default '') returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month)::date; n date; v_open numeric:=0; v_in numeric:=0; v_out numeric:=0; v_id uuid;
begin perform public.sws_require_admin(); n:=(m+interval '1 month')::date; if exists(select 1 from public.monthly_closings where month_start=m and status='closed') then raise exception 'Month is already closed'; end if;
 select coalesce((select closing_balance from public.monthly_closings where month_start<m and status='closed' order by month_start desc limit 1),0) into v_open;
 select coalesce(sum(amount) filter(where direction='credit' and status='posted'),0),coalesce(sum(amount) filter(where direction='debit' and status='posted'),0) into v_in,v_out from public.financial_movements where created_at>=m and created_at<n;
 insert into public.monthly_closings(month_start,opening_balance,closing_balance,closed_at,closed_by,status) values(m,v_open,v_open+v_in-v_out,now(),auth.uid(),'closed') on conflict(month_start) do update set opening_balance=excluded.opening_balance,closing_balance=excluded.closing_balance,closed_at=now(),closed_by=auth.uid(),status='closed' returning id into v_id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'month_closed','monthly_closing',v_id::text,jsonb_build_object('month_start',m,'opening_balance',v_open,'total_in',v_in,'total_out',v_out,'closing_balance',v_open+v_in-v_out),trim(coalesce(p_note,''))); return v_id; end $$;
create or replace function public.sws_reopen_month(p_month date,p_reason text) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month)::date; v_id uuid;
begin perform public.sws_require_admin(); if coalesce(trim(p_reason),'')='' then raise exception 'Reopen reason is required'; end if; update public.monthly_closings set status='open',reopened_at=now(),reopened_by=auth.uid(),reopen_reason=trim(p_reason) where month_start=m and status='closed' returning id into v_id; if v_id is null then raise exception 'Closed month not found'; end if; insert into public.audit_log(actor_id,action,entity_type,entity_id,reason) values(auth.uid(),'month_reopened','monthly_closing',v_id::text,trim(p_reason)); return v_id; end $$;
create or replace function public.sws_block_closed_month_movements() returns trigger language plpgsql security definer set search_path=public as $$
begin if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',coalesce(new.created_at,now()))::date and c.status='closed') then raise exception 'Accounting month is closed'; end if; return new; end $$;
drop trigger if exists sws_guard_closed_month_movements on public.financial_movements;
create trigger sws_guard_closed_month_movements before insert on public.financial_movements for each row execute function public.sws_block_closed_month_movements();
create or replace function public.sws_block_closed_payroll() returns trigger language plpgsql security definer set search_path=public as $$
begin if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',coalesce(new.month_start,old.month_start))::date and c.status='closed') then raise exception 'Payroll month is closed'; end if; if tg_op='DELETE' then return old; else return new; end if; end $$;
drop trigger if exists sws_guard_closed_payroll on public.payroll_records;
create trigger sws_guard_closed_payroll before insert or update or delete on public.payroll_records for each row execute function public.sws_block_closed_payroll();
grant execute on function public.sws_record_office_expense(numeric,text,text,text) to authenticated;
grant execute on function public.sws_record_general_revenue(numeric,text,text) to authenticated;
grant execute on function public.sws_pay_payroll(uuid,numeric,text,text) to authenticated;
grant execute on function public.sws_close_month(date,text) to authenticated;
grant execute on function public.sws_reopen_month(date,text) to authenticated;
-- Private documents bucket; use Storage API for uploads/downloads (never delete storage.objects directly).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('sws-private-documents','sws-private-documents',false,15728640,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=15728640,allowed_mime_types=array['application/pdf','image/jpeg','image/png','image/webp'];
drop policy if exists sws_private_documents_read on storage.objects;
drop policy if exists sws_private_documents_insert on storage.objects;
drop policy if exists sws_private_documents_update on storage.objects;
drop policy if exists sws_private_documents_read on storage.objects; create policy sws_private_documents_read on storage.objects for select to authenticated using(bucket_id='sws-private-documents' and public.sws_is_active_admin());
drop policy if exists sws_private_documents_insert on storage.objects; create policy sws_private_documents_insert on storage.objects for insert to authenticated with check(bucket_id='sws-private-documents' and public.sws_is_active_admin());
drop policy if exists sws_private_documents_update on storage.objects; create policy sws_private_documents_update on storage.objects for update to authenticated using(bucket_id='sws-private-documents' and public.sws_is_active_admin()) with check(bucket_id='sws-private-documents' and public.sws_is_active_admin());
commit;



-- ===== 202610160003_sws_security_and_idempotency.sql =====
-- SWS production hardening migration (apply after 001 and 002, on a TEST project first).
begin;

-- Operations that affect money or privileged status must go through audited RPCs.

-- Accurate server-side reports: no client row-limit truncation for accounting totals.
create or replace function public.sws_get_dashboard_summary()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare out_json jsonb;
begin
  perform public.sws_require_admin();
  select jsonb_build_object(
    'traveler_count',(select count(*) from public.travelers),
    'employee_count',(select count(distinct lower(trim(employee_name))) from public.payroll_records),
    'total_collections',coalesce(sum(amount) filter(where status='posted' and movement_type='traveler_collection' and direction='credit'),0),
    'general_revenue',coalesce(sum(amount) filter(where status='posted' and movement_type='general_revenue' and direction='credit'),0),
    'office_expenses',coalesce(sum(amount) filter(where status='posted' and movement_type='office_expense' and direction='debit'),0),
    'payroll_paid',coalesce(sum(amount) filter(where status='posted' and movement_type='payroll_payment' and direction='debit'),0),
    'cash_balance',coalesce(sum(case when status='posted' and direction='credit' then amount when status='posted' and direction='debit' then -amount else 0 end),0)
  ) into out_json from public.financial_movements;
  return out_json;
end $$;

create or replace function public.sws_monthly_financial_report(p_month_start date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month_start)::date; n date; opening numeric:=0; totals jsonb;
begin
  perform public.sws_require_admin();
  n:=(m+interval '1 month')::date;
  select coalesce(sum(case when direction='credit' then amount else -amount end),0) into opening
    from public.financial_movements where created_at < (m::timestamp at time zone 'Africa/Cairo') and status='posted';
  select jsonb_build_object(
    'month_start',m,
    'opening_balance',coalesce(opening,0),
    'traveler_collections',coalesce(sum(amount) filter(where status='posted' and movement_type='traveler_collection' and direction='credit'),0),
    'general_revenue',coalesce(sum(amount) filter(where status='posted' and movement_type='general_revenue' and direction='credit'),0),
    'office_expenses',coalesce(sum(amount) filter(where status='posted' and movement_type='office_expense' and direction='debit'),0),
    'payroll_payments',coalesce(sum(amount) filter(where status='posted' and movement_type='payroll_payment' and direction='debit'),0),
    'other_credits',coalesce(sum(amount) filter(where status='posted' and direction='credit' and movement_type not in ('traveler_collection','general_revenue')),0),
    'other_debits',coalesce(sum(amount) filter(where status='posted' and direction='debit' and movement_type not in ('office_expense','payroll_payment')),0)
  ) into totals from public.financial_movements where created_at >= (m::timestamp at time zone 'Africa/Cairo') and created_at < (n::timestamp at time zone 'Africa/Cairo');
  return totals;
end $$;

-- If there is no earlier monthly closing, compute opening cash from the historical ledger.
create or replace function public.sws_close_month(p_month date,p_note text default '')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month)::date; n date; v_open numeric; v_in numeric:=0; v_out numeric:=0; v_id uuid;
begin
  perform public.sws_require_admin(); n:=(m+interval '1 month')::date;
  if m>date_trunc('month',now())::date then raise exception 'Cannot close a future month'; end if;
  if exists(select 1 from public.monthly_closings where month_start=m and status='closed') then raise exception 'Month is already closed'; end if;
  select coalesce(sum(case when direction='credit' then amount else -amount end),0) into v_open from public.financial_movements where created_at < (m::timestamp at time zone 'Africa/Cairo') and status='posted';
  select coalesce(sum(amount) filter(where direction='credit' and status='posted'),0),coalesce(sum(amount) filter(where direction='debit' and status='posted'),0) into v_in,v_out from public.financial_movements where created_at >= (m::timestamp at time zone 'Africa/Cairo') and created_at < (n::timestamp at time zone 'Africa/Cairo');
  insert into public.monthly_closings(month_start,opening_balance,closing_balance,closed_at,closed_by,status) values(m,coalesce(v_open,0),coalesce(v_open,0)+v_in-v_out,now(),auth.uid(),'closed') on conflict(month_start) do update set opening_balance=excluded.opening_balance,closing_balance=excluded.closing_balance,closed_at=now(),closed_by=auth.uid(),status='closed' returning id into v_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data,reason) values(auth.uid(),'month_closed','monthly_closing',v_id::text,jsonb_build_object('month_start',m,'opening_balance',coalesce(v_open,0),'total_in',v_in,'total_out',v_out,'closing_balance',coalesce(v_open,0)+v_in-v_out),trim(coalesce(p_note,'')));
  return v_id;
end $$;


drop policy if exists sws_travelers_admin_read on public.travelers;
drop policy if exists sws_movements_admin_read on public.financial_movements;
drop policy if exists sws_expenses_admin_read on public.office_expenses;
drop policy if exists sws_payroll_admin_read on public.payroll_records;
drop policy if exists sws_monthly_closings_admin_read on public.monthly_closings;
drop policy if exists sws_audit_admin_read on public.audit_log;
drop policy if exists sws_documents_admin_read on public.traveler_documents;
drop policy if exists sws_documents_admin_insert on public.traveler_documents;
drop policy if exists sws_private_documents_delete on storage.objects;
create or replace function public.sws_create_traveler(
  p_full_name text, p_phone text, p_agreement_total numeric default 0,
  p_sales_person text default null, p_country text default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.travelers%rowtype; v_file_no text;
begin
  perform public.sws_require_admin();
  if coalesce(trim(p_full_name),'')='' then raise exception 'Traveler full name is required'; end if;
  if coalesce(trim(p_phone),'')='' then raise exception 'Traveler phone is required'; end if;
  if p_agreement_total is null or p_agreement_total<0 then raise exception 'Agreement total cannot be negative'; end if;
  v_file_no := 'SWS-'||to_char(now(),'YYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  insert into public.travelers(file_no,full_name,phone,agreement_total,sales_person,destination_country,created_by)
    values(v_file_no,trim(p_full_name),trim(p_phone),p_agreement_total,nullif(trim(coalesce(p_sales_person,'')),''),nullif(trim(coalesce(p_country,'')),''),auth.uid()) returning * into t;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'traveler_created','traveler',t.id::text,to_jsonb(t));
  return to_jsonb(t);
end $$;

create or replace function public.sws_set_traveler_stage(p_traveler_id uuid,p_stage text,p_value boolean)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype;
begin
  perform public.sws_require_admin();
  if p_stage not in ('submitted','inspected','visa','flight') then raise exception 'Invalid traveler stage'; end if;
  select * into old_row from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  update public.travelers set
    stage_submitted=case when p_stage='submitted' then p_value else stage_submitted end,
    stage_inspected=case when p_stage='inspected' then p_value else stage_inspected end,
    stage_visa=case when p_stage='visa' then p_value else stage_visa end,
    stage_flight=case when p_stage='flight' then p_value else stage_flight end,
    updated_at=now()
    where id=p_traveler_id returning * into new_row;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'traveler_stage_changed','traveler',p_traveler_id::text,to_jsonb(old_row),to_jsonb(new_row));
  return p_traveler_id;
end $$;

create or replace function public.sws_update_traveler(
  p_traveler_id uuid,p_full_name text,p_phone text,p_agreement_total numeric,p_sales_person text default null,p_country text default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype; v_net_paid numeric:=0;
begin
  perform public.sws_require_admin();
  if coalesce(trim(p_full_name),'')='' then raise exception 'Traveler full name is required'; end if;
  if coalesce(trim(p_phone),'')='' then raise exception 'Traveler phone is required'; end if;
  if p_agreement_total is null or p_agreement_total<0 then raise exception 'Agreement total cannot be negative'; end if;
  select * into old_row from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  select coalesce(sum(amount),0) into v_net_paid from public.financial_movements
    where traveler_id=p_traveler_id and movement_type='traveler_collection' and direction='credit' and status='posted';
  if p_agreement_total < v_net_paid then raise exception 'Agreement total cannot be lower than net collections already received'; end if;
  update public.travelers set full_name=trim(p_full_name),phone=trim(p_phone),agreement_total=p_agreement_total,
    sales_person=nullif(trim(coalesce(p_sales_person,'')),''),destination_country=nullif(trim(coalesce(p_country,'')),''),updated_at=now()
    where id=p_traveler_id returning * into new_row;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'traveler_updated','traveler',p_traveler_id::text,to_jsonb(old_row),to_jsonb(new_row));
  return to_jsonb(new_row);
end $$;

-- One function signature accepts the idempotency key: repeat requests return the same movement ID.
drop function if exists public.sws_record_traveler_payment(uuid,numeric,text,text);
create or replace function public.sws_record_traveler_payment(
  p_traveler_id uuid,p_amount numeric,p_payment_method text default 'cash',p_note text default null,p_idempotency_key uuid default null
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_receipt text; t public.travelers%rowtype; v_paid numeric:=0; v_remaining numeric:=0;
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  if p_idempotency_key is not null then
    select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
    if found then return v_id; end if;
  end if;
  select * into t from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  -- Recheck after the row lock to handle simultaneous retries with the same key.
  if p_idempotency_key is not null then
    select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
    if found then return v_id; end if;
  end if;
  select coalesce(sum(amount),0) into v_paid from public.financial_movements
    where traveler_id=p_traveler_id and movement_type='traveler_collection' and direction='credit' and status='posted';
  v_remaining:=greatest(t.agreement_total-v_paid,0);
  if p_amount>v_remaining then raise exception 'Payment exceeds traveler outstanding balance'; end if;
  v_receipt := 'SWS-'||to_char(now(),'YYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into public.financial_movements(receipt_no,traveler_id,movement_type,direction,amount,payment_method,note,created_by,idempotency_key)
  values(v_receipt,p_traveler_id,'traveler_collection','credit',p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),''),auth.uid(),p_idempotency_key)
  on conflict(idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_id;
  if not exists(select 1 from public.audit_log where action='payment_recorded' and entity_id=v_id::text) then
    insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'payment_recorded','financial_movement',v_id::text,jsonb_build_object('traveler_id',p_traveler_id,'amount',p_amount,'receipt_no',v_receipt));
  end if;
  return v_id;
end $$;

create or replace function public.sws_create_payroll_record(
  p_employee_name text,p_month_start date,p_base_salary numeric,p_commission numeric default 0,p_deductions numeric default 0
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; m date:=date_trunc('month',p_month_start)::date;
begin
  perform public.sws_require_admin();
  if coalesce(trim(p_employee_name),'')='' then raise exception 'Employee name is required'; end if;
  if p_base_salary is null or p_base_salary<=0 or coalesce(p_commission,0)<0 or coalesce(p_deductions,0)<0 then raise exception 'Invalid payroll amounts'; end if;
  if coalesce(p_deductions,0)>p_base_salary+coalesce(p_commission,0) then raise exception 'Deductions exceed earnings'; end if;
  insert into public.payroll_records(employee_name,month_start,base_salary,commission,deductions,paid_amount,status)
  values(trim(p_employee_name),m,p_base_salary,coalesce(p_commission,0),coalesce(p_deductions,0),0,'open') returning id into v_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
  values(auth.uid(),'payroll_record_created','payroll_record',v_id::text,jsonb_build_object('employee_name',trim(p_employee_name),'month_start',m,'base_salary',p_base_salary,'commission',coalesce(p_commission,0),'deductions',coalesce(p_deductions,0)));
  return v_id;
end $$;

-- Harden direct table permissions via RLS. Reads remain available to the active admin;
-- financial mutations must use the audited security-definer procedures above.
drop policy if exists sws_admin_all on public.travelers;
drop policy if exists sws_documents_admin_read on public.traveler_documents; create policy sws_documents_admin_read on public.traveler_documents for select to authenticated using (public.sws_is_active_admin());
drop policy if exists sws_documents_admin_insert on public.traveler_documents; create policy sws_documents_admin_insert on public.traveler_documents for insert to authenticated with check (public.sws_is_active_admin());
drop policy if exists sws_private_documents_delete on storage.objects; create policy sws_private_documents_delete on storage.objects for delete to authenticated using (bucket_id='sws-private-documents' and public.sws_is_active_admin());

drop policy if exists sws_travelers_admin_read on public.travelers; create policy sws_travelers_admin_read on public.travelers for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.financial_movements;
drop policy if exists sws_movements_admin_read on public.financial_movements; create policy sws_movements_admin_read on public.financial_movements for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.office_expenses;
drop policy if exists sws_expenses_admin_read on public.office_expenses; create policy sws_expenses_admin_read on public.office_expenses for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.payroll_records;
drop policy if exists sws_payroll_admin_read on public.payroll_records; create policy sws_payroll_admin_read on public.payroll_records for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.monthly_closings;
drop policy if exists sws_monthly_closings_admin_read on public.monthly_closings; create policy sws_monthly_closings_admin_read on public.monthly_closings for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.audit_log;
drop policy if exists sws_audit_admin_read on public.audit_log; create policy sws_audit_admin_read on public.audit_log for select to authenticated using (public.sws_is_active_admin());

revoke all on function public.sws_get_dashboard_summary() from public;
revoke all on function public.sws_monthly_financial_report(date) from public;
revoke all on function public.sws_close_month(date,text) from public;
revoke all on function public.sws_create_traveler(text,text,numeric,text,text) from public;
revoke all on function public.sws_set_traveler_stage(uuid,text,boolean) from public;
revoke all on function public.sws_update_traveler(uuid,text,text,numeric,text,text) from public;
revoke all on function public.sws_record_traveler_payment(uuid,numeric,text,text,uuid) from public;
revoke all on function public.sws_create_payroll_record(text,date,numeric,numeric,numeric) from public;
grant execute on function public.sws_get_dashboard_summary() to authenticated;
grant execute on function public.sws_monthly_financial_report(date) to authenticated;
grant execute on function public.sws_close_month(date,text) to authenticated;
grant execute on function public.sws_create_traveler(text,text,numeric,text,text) to authenticated;
grant execute on function public.sws_set_traveler_stage(uuid,text,boolean) to authenticated;
grant execute on function public.sws_update_traveler(uuid,text,text,numeric,text,text) to authenticated;
grant execute on function public.sws_record_traveler_payment(uuid,numeric,text,text,uuid) to authenticated;
grant execute on function public.sws_create_payroll_record(text,date,numeric,numeric,numeric) to authenticated;
commit;



-- ===== 202610160004_sws_operations_completion.sql =====
-- SWS additional operational hardening. Apply after migrations 001, 002 and 003.
-- Run against a disposable/test project first, then promote after verifying the schema.
begin;

-- Return traveler rows with a complete server-side paid total (not a client-limited sum).
create or replace function public.sws_list_travelers(
  p_search text default null,
  p_limit integer default 500,
  p_offset integer default 0
) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  perform public.sws_require_admin();
  select coalesce(jsonb_agg(to_jsonb(result_rows) order by result_rows.created_at desc), '[]'::jsonb)
    into result
  from (
    select t.id,t.file_no,t.full_name,t.phone,t.agreement_total,t.sales_person,t.destination_country,
      t.stage_submitted,t.stage_inspected,t.stage_visa,t.stage_flight,t.created_at,t.updated_at,t.created_by,
      coalesce(p.paid_amount,0)::numeric(14,2) as paid_amount
    from public.travelers t
    left join lateral (
      select sum(m.amount) as paid_amount
      from public.financial_movements m
      where m.traveler_id=t.id and m.movement_type='traveler_collection'
        and m.direction='credit' and m.status='posted'
    ) p on true
    where nullif(trim(coalesce(p_search,'')),'') is null
      or t.full_name ilike '%'||trim(p_search)||'%'
      or t.phone ilike '%'||trim(p_search)||'%'
      or coalesce(t.file_no,'') ilike '%'||trim(p_search)||'%'
    order by t.created_at desc
    limit greatest(1,least(coalesce(p_limit,500),1000)) offset greatest(coalesce(p_offset,0),0)
  ) result_rows;
  return result;
end $$;

create or replace function public.sws_get_traveler_paid_total(p_traveler_id uuid)
returns numeric language plpgsql security definer set search_path=public,pg_temp as $$
declare result numeric;
begin
  perform public.sws_require_admin();
  select coalesce(sum(amount),0) into result from public.financial_movements
    where traveler_id=p_traveler_id and movement_type='traveler_collection'
      and direction='credit' and status='posted';
  return result;
end $$;

-- Consistent month boundary: Cairo local time is the accounting timezone.
create or replace function public.sws_block_closed_month_movements()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare movement_month date;
begin
  movement_month := date_trunc('month', (coalesce(new.created_at,now()) at time zone 'Africa/Cairo'))::date;
  if exists(select 1 from public.monthly_closings c where c.month_start=movement_month and c.status='closed') then
    raise exception 'Accounting month is closed';
  end if;
  return new;
end $$;

-- Closed payroll periods are immutable except settling an existing obligation.
-- The settlement RPC sets a transaction-local flag and this trigger additionally
-- verifies that the employee, month, accrual, commissions and deductions are unchanged.
create or replace function public.sws_block_closed_payroll()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare payroll_month date;
begin
  payroll_month := case when tg_op='DELETE' then old.month_start else new.month_start end;
  if exists(select 1 from public.monthly_closings c where c.month_start=payroll_month and c.status='closed') then
    if tg_op='UPDATE'
       and current_setting('sws.allow_payroll_settlement',true)='on'
       and (to_jsonb(new)-'paid_amount'-'status')=(to_jsonb(old)-'paid_amount'-'status')
       and new.paid_amount>=old.paid_amount then
      return new;
    end if;
    raise exception 'Payroll month is closed';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

-- Accounting reports operate on immutable ledger events. A reversed original remains
-- in its creation period and is balanced by the separately posted reversal event.
create or replace function public.sws_get_dashboard_summary()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare out_json jsonb;
begin
  perform public.sws_require_admin();
  select jsonb_build_object(
    'traveler_count',(select count(*) from public.travelers),
    'employee_count',(select count(distinct lower(trim(employee_name))) from public.payroll_records),
    'total_collections',coalesce(sum(amount) filter(where status='posted' and movement_type='traveler_collection' and direction='credit'),0),
    'general_revenue',coalesce(sum(amount) filter(where status='posted' and movement_type='general_revenue' and direction='credit'),0),
    'office_expenses',coalesce(sum(amount) filter(where status='posted' and movement_type='office_expense' and direction='debit'),0),
    'payroll_paid',coalesce(sum(amount) filter(where status='posted' and movement_type='payroll_payment' and direction='debit'),0),
    'cash_balance',coalesce(sum(case when status in ('posted','reversed') and direction='credit' then amount when status in ('posted','reversed') and direction='debit' then -amount else 0 end),0)
  ) into out_json from public.financial_movements;
  return out_json;
end $$;

create or replace function public.sws_monthly_financial_report(p_month_start date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month_start)::date; n date; opening numeric:=0; totals jsonb;
begin
  perform public.sws_require_admin();
  n:=(m+interval '1 month')::date;
  select coalesce(sum(case when direction='credit' then amount else -amount end),0) into opening
    from public.financial_movements
    where created_at < (m::timestamp at time zone 'Africa/Cairo') and status in ('posted','reversed');
  select jsonb_build_object(
    'month_start',m,
    'opening_balance',coalesce(opening,0),
    'traveler_collections',coalesce(sum(amount) filter(where status in ('posted','reversed') and movement_type='traveler_collection' and direction='credit'),0),
    'general_revenue',coalesce(sum(amount) filter(where status in ('posted','reversed') and movement_type='general_revenue' and direction='credit'),0),
    'office_expenses',coalesce(sum(amount) filter(where status in ('posted','reversed') and movement_type='office_expense' and direction='debit'),0),
    'payroll_payments',coalesce(sum(amount) filter(where status in ('posted','reversed') and movement_type='payroll_payment' and direction='debit'),0),
    'other_credits',coalesce(sum(amount) filter(where status in ('posted','reversed') and direction='credit' and movement_type not in ('traveler_collection','general_revenue')),0),
    'other_debits',coalesce(sum(amount) filter(where status in ('posted','reversed') and direction='debit' and movement_type not in ('office_expense','payroll_payment')),0)
  ) into totals from public.financial_movements
  where created_at >= (m::timestamp at time zone 'Africa/Cairo') and created_at < (n::timestamp at time zone 'Africa/Cairo');
  return totals;
end $$;

create or replace function public.sws_close_month(p_month date,p_note text default '')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month)::date; n date; v_open numeric:=0; v_in numeric:=0; v_out numeric:=0; v_id uuid;
begin
  perform public.sws_require_admin(); n:=(m+interval '1 month')::date;
  if m>date_trunc('month',now() at time zone 'Africa/Cairo')::date then raise exception 'Cannot close a future month'; end if;
  if exists(select 1 from public.monthly_closings where month_start=m and status='closed') then raise exception 'Month is already closed'; end if;
  select coalesce(sum(case when direction='credit' then amount else -amount end),0) into v_open
    from public.financial_movements where created_at < (m::timestamp at time zone 'Africa/Cairo') and status in ('posted','reversed');
  select coalesce(sum(amount) filter(where direction='credit' and status in ('posted','reversed')),0),
         coalesce(sum(amount) filter(where direction='debit' and status in ('posted','reversed')),0)
    into v_in,v_out from public.financial_movements
    where created_at >= (m::timestamp at time zone 'Africa/Cairo') and created_at < (n::timestamp at time zone 'Africa/Cairo');
  insert into public.monthly_closings(month_start,opening_balance,closing_balance,closed_at,closed_by,status)
    values(m,coalesce(v_open,0),coalesce(v_open,0)+v_in-v_out,now(),auth.uid(),'closed')
    on conflict(month_start) do update set opening_balance=excluded.opening_balance,closing_balance=excluded.closing_balance,closed_at=now(),closed_by=auth.uid(),status='closed' returning id into v_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data,reason)
    values(auth.uid(),'month_closed','monthly_closing',v_id::text,jsonb_build_object('month_start',m,'opening_balance',coalesce(v_open,0),'total_in',v_in,'total_out',v_out,'closing_balance',coalesce(v_open,0)+v_in-v_out),trim(coalesce(p_note,'')));
  return v_id;
end $$;

-- Replace older signatures so new writes all support an idempotency token.
drop function if exists public.sws_record_general_revenue(numeric,text,text);
create or replace function public.sws_record_general_revenue(
  p_amount numeric,p_payment_method text,p_note text,p_idempotency_key uuid
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_receipt text;
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  if p_idempotency_key is not null then
    select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
    if found then return v_id; end if;
  end if;
  v_receipt:='REVN-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by,idempotency_key)
    values(v_receipt,'general_revenue','credit',p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),''),auth.uid(),p_idempotency_key)
    on conflict(idempotency_key) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; return v_id; end if;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'general_revenue_created','financial_movement',v_id::text,jsonb_build_object('amount',p_amount,'note',p_note,'receipt_no',v_receipt));
  return v_id;
end $$;

drop function if exists public.sws_record_office_expense(numeric,text,text,text);
create or replace function public.sws_record_office_expense(
  p_amount numeric,p_payment_method text,p_category text,p_description text,p_idempotency_key uuid
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_receipt text;
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if coalesce(trim(p_category),'')='' then raise exception 'Category is required'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  if p_idempotency_key is not null then
    select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
    if found then return v_id; end if;
  end if;
  v_receipt:='EXP-'||to_char(now(),'YYMM')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by,idempotency_key)
    values(v_receipt,'office_expense','debit',p_amount,p_payment_method,nullif(trim(coalesce(p_description,'')),''),auth.uid(),p_idempotency_key)
    on conflict(idempotency_key) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; return v_id; end if;
  insert into public.office_expenses(movement_id,category,description) values(v_id,trim(p_category),trim(coalesce(p_description,'')));
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'office_expense_created','financial_movement',v_id::text,jsonb_build_object('amount',p_amount,'category',p_category,'receipt_no',v_receipt));
  return v_id;
end $$;

drop function if exists public.sws_pay_payroll(uuid,numeric,text,text);
create or replace function public.sws_pay_payroll(
  p_payroll_id uuid,p_amount numeric,p_payment_method text,p_note text,p_idempotency_key uuid
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.payroll_records%rowtype; v_id uuid; v_due numeric; v_receipt text;
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  select * into r from public.payroll_records where id=p_payroll_id for update;
  if not found then raise exception 'Payroll record not found'; end if;
  if p_idempotency_key is not null then
    select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
    if found then return v_id; end if;
  end if;
  v_due:=r.base_salary+r.commission-r.deductions-r.paid_amount;
  if v_due<=0 or p_amount>v_due then raise exception 'Payment exceeds outstanding payroll amount'; end if;
  v_receipt:='PAY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by,idempotency_key)
    values(v_receipt,'payroll_payment','debit',p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),'')::text,auth.uid(),p_idempotency_key)
    on conflict(idempotency_key) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; return v_id; end if;
  perform set_config('sws.allow_payroll_settlement','on',true);
  update public.payroll_records set paid_amount=paid_amount+p_amount,
    status=case when paid_amount+p_amount>=base_salary+commission-deductions then 'closed' else 'open' end
    where id=p_payroll_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'payroll_payment_recorded','payroll_record',p_payroll_id::text,jsonb_build_object('movement_id',v_id,'amount',p_amount,'receipt_no',v_receipt));
  return v_id;
end $$;

revoke all on function public.sws_get_dashboard_summary() from public;
revoke all on function public.sws_monthly_financial_report(date) from public;
revoke all on function public.sws_close_month(date,text) from public;
revoke all on function public.sws_list_travelers(text,integer,integer) from public;
revoke all on function public.sws_get_traveler_paid_total(uuid) from public;
revoke all on function public.sws_record_general_revenue(numeric,text,text,uuid) from public;
revoke all on function public.sws_record_office_expense(numeric,text,text,text,uuid) from public;
revoke all on function public.sws_pay_payroll(uuid,numeric,text,text,uuid) from public;
grant execute on function public.sws_get_dashboard_summary() to authenticated;
grant execute on function public.sws_monthly_financial_report(date) to authenticated;
grant execute on function public.sws_close_month(date,text) to authenticated;
grant execute on function public.sws_list_travelers(text,integer,integer) to authenticated;
grant execute on function public.sws_get_traveler_paid_total(uuid) to authenticated;
grant execute on function public.sws_record_general_revenue(numeric,text,text,uuid) to authenticated;
grant execute on function public.sws_record_office_expense(numeric,text,text,text,uuid) to authenticated;
grant execute on function public.sws_pay_payroll(uuid,numeric,text,text,uuid) to authenticated;
commit;



-- ===== 202610160005_sws_monthly_workflow_crud_live.sql =====
-- SWS monthly-first workflows, CRUD controls, payroll extras and realtime support.
-- Apply after 001-004. Test on a disposable Supabase project before production.
begin;

alter table public.travelers add column if not exists archived_at timestamptz;
alter table public.payroll_records add column if not exists bonus numeric(14,2) not null default 0 check (bonus >= 0);
alter table public.payroll_records add column if not exists overtime_hours numeric(10,2) not null default 0 check (overtime_hours >= 0);
alter table public.payroll_records add column if not exists overtime_rate numeric(14,2) not null default 0 check (overtime_rate >= 0);
alter table public.financial_movements add column if not exists payroll_record_id uuid references public.payroll_records(id);
create index if not exists idx_payroll_month_start on public.payroll_records(month_start desc);
create index if not exists idx_expenses_created_at on public.office_expenses(created_at desc);
create index if not exists idx_audit_created_at on public.audit_log(created_at desc);

-- Month-scoped traveler list. A traveler appears in the month they were registered.
create or replace function public.sws_list_travelers(
  p_search text default null,
  p_limit integer default 500,
  p_offset integer default 0,
  p_month_start date default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; m date; n date;
begin
  perform public.sws_require_admin();
  if p_month_start is not null then m:=date_trunc('month',p_month_start)::date; n:=(m+interval '1 month')::date; end if;
  select coalesce(jsonb_agg(to_jsonb(rows) order by rows.created_at desc),'[]'::jsonb) into result
  from (
    select t.id,t.file_no,t.full_name,t.phone,t.agreement_total,t.sales_person,t.destination_country,
      t.stage_submitted,t.stage_inspected,t.stage_visa,t.stage_flight,t.created_at,t.updated_at,t.created_by,
      coalesce(p.paid_amount,0)::numeric(14,2) as paid_amount
    from public.travelers t
    left join lateral (
      select coalesce(sum(case when m.direction='credit' then m.amount else -m.amount end),0) paid_amount
      from public.financial_movements m where m.traveler_id=t.id
        and m.movement_type in ('traveler_collection','reversal') and m.status in ('posted','reversed')
    ) p on true
    where t.archived_at is null
      and (p_month_start is null or (t.created_at >= (m::timestamp at time zone 'Africa/Cairo') and t.created_at < (n::timestamp at time zone 'Africa/Cairo')))
      and (nullif(trim(coalesce(p_search,'')),'') is null or t.full_name ilike '%'||trim(p_search)||'%' or t.phone ilike '%'||trim(p_search)||'%' or coalesce(t.file_no,'') ilike '%'||trim(p_search)||'%')
    order by t.created_at desc limit greatest(1,least(coalesce(p_limit,500),1000)) offset greatest(coalesce(p_offset,0),0)
  ) rows;
  return result;
end $$;

create or replace function public.sws_archive_traveler(p_traveler_id uuid,p_reason text default 'أرشفة من الإدارة')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.travelers%rowtype;
begin
  perform public.sws_require_admin();
  select * into t from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  if t.archived_at is not null then raise exception 'Traveler already archived'; end if;
  update public.travelers set archived_at=now(),updated_at=now() where id=t.id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
    values(auth.uid(),'traveler_archived','traveler',t.id::text,to_jsonb(t),jsonb_build_object('archived_at',now()),nullif(trim(coalesce(p_reason,'')),''));
end $$;

create or replace function public.sws_restore_traveler(p_traveler_id uuid,p_reason text default 'استعادة من الأرشيف')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.travelers%rowtype;
begin
  perform public.sws_require_admin();
  select * into t from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  if t.archived_at is null then raise exception 'Traveler is not archived'; end if;
  update public.travelers set archived_at=null,updated_at=now() where id=t.id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
    values(auth.uid(),'traveler_restored','traveler',t.id::text,to_jsonb(t),jsonb_build_object('archived_at',null),nullif(trim(coalesce(p_reason,'')),''));
end $$;

-- Monthly traveler ledger includes travelers registered this month and travelers paid this month.
create or replace function public.sws_monthly_traveler_ledger(p_month_start date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month_start)::date; n date; result jsonb;
begin
  perform public.sws_require_admin(); n:=(m+interval '1 month')::date;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into result from (
    select t.id,t.file_no,t.full_name,t.phone,t.sales_person,t.agreement_total,t.created_at,
      coalesce(before_m.paid_before,0)::numeric(14,2) paid_before_month,
      coalesce(current_m.paid_in,0)::numeric(14,2) paid_in_month,
      (coalesce(before_m.paid_before,0)+coalesce(current_m.paid_in,0))::numeric(14,2) paid_to_month_end,
      greatest(t.agreement_total-(coalesce(before_m.paid_before,0)+coalesce(current_m.paid_in,0)),0)::numeric(14,2) remaining_at_month_end
    from public.travelers t
    left join lateral (
      select sum(case when fm.direction='credit' then fm.amount else -fm.amount end) paid_before
      from public.financial_movements fm where fm.traveler_id=t.id and fm.movement_type in ('traveler_collection','reversal') and fm.status in ('posted','reversed') and fm.created_at < (m::timestamp at time zone 'Africa/Cairo')
    ) before_m on true
    left join lateral (
      select sum(case when fm.direction='credit' then fm.amount else -fm.amount end) paid_in
      from public.financial_movements fm where fm.traveler_id=t.id and fm.movement_type in ('traveler_collection','reversal') and fm.status in ('posted','reversed') and fm.created_at >= (m::timestamp at time zone 'Africa/Cairo') and fm.created_at < (n::timestamp at time zone 'Africa/Cairo')
    ) current_m on true
    where t.archived_at is null and (
      (t.created_at >= (m::timestamp at time zone 'Africa/Cairo') and t.created_at < (n::timestamp at time zone 'Africa/Cairo'))
      or exists(select 1 from public.financial_movements fm where fm.traveler_id=t.id and fm.movement_type in ('traveler_collection','reversal') and fm.created_at >= (m::timestamp at time zone 'Africa/Cairo') and fm.created_at < (n::timestamp at time zone 'Africa/Cairo'))
    )
  ) q;
  return result;
end $$;

create or replace function public.sws_get_monthly_dashboard_summary(p_month_start date)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m date:=date_trunc('month',p_month_start)::date; n date; result jsonb;
begin
  perform public.sws_require_admin(); n:=(m+interval '1 month')::date;
  select jsonb_build_object(
    'traveler_count',(select count(*) from public.travelers t where t.archived_at is null and t.created_at >= (m::timestamp at time zone 'Africa/Cairo') and t.created_at < (n::timestamp at time zone 'Africa/Cairo')),
    'employee_count',(select count(*) from public.payroll_records p where p.month_start=m),
    'total_collections',coalesce(sum(amount) filter(where movement_type='traveler_collection' and direction='credit'),0),
    'general_revenue',coalesce(sum(amount) filter(where movement_type='general_revenue' and direction='credit'),0),
    'office_expenses',coalesce(sum(amount) filter(where movement_type='office_expense' and direction='debit'),0),
    'payroll_paid',coalesce(sum(amount) filter(where movement_type='payroll_payment' and direction='debit'),0),
    'cash_balance',(select coalesce(sum(case when direction='credit' then amount else -amount end),0) from public.financial_movements where status in ('posted','reversed') and created_at < (n::timestamp at time zone 'Africa/Cairo'))
  ) into result from public.financial_movements fm
  where fm.status in ('posted','reversed') and fm.created_at >= (m::timestamp at time zone 'Africa/Cairo') and fm.created_at < (n::timestamp at time zone 'Africa/Cairo');
  return result;
end $$;

-- Extended payroll fields: bonus, overtime hours and overtime hourly rate.
drop function if exists public.sws_create_payroll_record(text,date,numeric,numeric,numeric);
create or replace function public.sws_create_payroll_record(
 p_employee_name text,p_month_start date,p_base_salary numeric,p_commission numeric,p_deductions numeric,
 p_bonus numeric,p_overtime_hours numeric,p_overtime_rate numeric
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; m date:=date_trunc('month',p_month_start)::date; ot numeric;
begin
  perform public.sws_require_admin();
  if coalesce(trim(p_employee_name),'')='' then raise exception 'Employee name is required'; end if;
  if p_base_salary is null or p_base_salary<=0 or coalesce(p_commission,0)<0 or coalesce(p_deductions,0)<0 or coalesce(p_bonus,0)<0 or coalesce(p_overtime_hours,0)<0 or coalesce(p_overtime_rate,0)<0 then raise exception 'Invalid payroll amounts'; end if;
  ot:=round(coalesce(p_overtime_hours,0)*coalesce(p_overtime_rate,0),2);
  if coalesce(p_deductions,0)>p_base_salary+coalesce(p_commission,0)+coalesce(p_bonus,0)+ot then raise exception 'Deductions exceed earnings'; end if;
  insert into public.payroll_records(employee_name,month_start,base_salary,commission,deductions,paid_amount,status,bonus,overtime_hours,overtime_rate)
  values(trim(p_employee_name),m,p_base_salary,coalesce(p_commission,0),coalesce(p_deductions,0),0,'open',coalesce(p_bonus,0),coalesce(p_overtime_hours,0),coalesce(p_overtime_rate,0)) returning id into v_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
  values(auth.uid(),'payroll_record_created','payroll_record',v_id::text,jsonb_build_object('employee_name',trim(p_employee_name),'month_start',m,'base_salary',p_base_salary,'commission',coalesce(p_commission,0),'bonus',coalesce(p_bonus,0),'overtime_hours',coalesce(p_overtime_hours,0),'overtime_rate',coalesce(p_overtime_rate,0),'overtime_amount',ot,'deductions',coalesce(p_deductions,0)));
  return v_id;
end $$;

create or replace function public.sws_update_payroll_record(
 p_payroll_id uuid,p_employee_name text,p_base_salary numeric,p_commission numeric,p_deductions numeric,
 p_bonus numeric,p_overtime_hours numeric,p_overtime_rate numeric
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.payroll_records%rowtype; ot numeric;
begin
  perform public.sws_require_admin();
  select * into r from public.payroll_records where id=p_payroll_id for update;
  if not found then raise exception 'Payroll record not found'; end if;
  if r.paid_amount>0 then raise exception 'Reverse payroll payments before changing salary details'; end if;
  if coalesce(trim(p_employee_name),'')='' or p_base_salary is null or p_base_salary<=0 or coalesce(p_commission,0)<0 or coalesce(p_deductions,0)<0 or coalesce(p_bonus,0)<0 or coalesce(p_overtime_hours,0)<0 or coalesce(p_overtime_rate,0)<0 then raise exception 'Invalid payroll values'; end if;
  ot:=round(coalesce(p_overtime_hours,0)*coalesce(p_overtime_rate,0),2);
  if coalesce(p_deductions,0)>p_base_salary+coalesce(p_commission,0)+coalesce(p_bonus,0)+ot then raise exception 'Deductions exceed earnings'; end if;
  update public.payroll_records set employee_name=trim(p_employee_name),base_salary=p_base_salary,commission=coalesce(p_commission,0),deductions=coalesce(p_deductions,0),bonus=coalesce(p_bonus,0),overtime_hours=coalesce(p_overtime_hours,0),overtime_rate=coalesce(p_overtime_rate,0),status='open' where id=r.id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
   values(auth.uid(),'payroll_record_updated','payroll_record',r.id::text,to_jsonb(r),jsonb_build_object('employee_name',trim(p_employee_name),'base_salary',p_base_salary,'commission',coalesce(p_commission,0),'deductions',coalesce(p_deductions,0),'bonus',coalesce(p_bonus,0),'overtime_hours',coalesce(p_overtime_hours,0),'overtime_rate',coalesce(p_overtime_rate,0),'overtime_amount',ot));
end $$;

create or replace function public.sws_delete_payroll_record(p_payroll_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.payroll_records%rowtype;
begin
 perform public.sws_require_admin();
 select * into r from public.payroll_records where id=p_payroll_id for update;
 if not found then raise exception 'Payroll record not found'; end if;
 if r.paid_amount>0 or exists(select 1 from public.financial_movements where payroll_record_id=r.id and status in ('posted','reversed')) then raise exception 'A payroll record with payments cannot be deleted; reverse its payments first'; end if;
 if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Deletion reason is required'; end if;
 delete from public.payroll_records where id=r.id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,reason)
  values(auth.uid(),'payroll_record_deleted','payroll_record',r.id::text,to_jsonb(r),trim(p_reason));
end $$;

-- Tie each payroll disbursement to the payroll record and support retro-date for monthly scope.
drop function if exists public.sws_pay_payroll(uuid,numeric,text,text,uuid);
create or replace function public.sws_pay_payroll(
 p_payroll_id uuid,p_amount numeric,p_payment_method text,p_note text,p_idempotency_key uuid,p_effective_at timestamptz
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.payroll_records%rowtype; v_id uuid; v_due numeric; v_receipt text; at_time timestamptz:=coalesce(p_effective_at,now());
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  select * into r from public.payroll_records where id=p_payroll_id for update;
  if not found then raise exception 'Payroll record not found'; end if;
  if p_idempotency_key is not null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; if found then return v_id; end if; end if;
  v_due:=r.base_salary+r.commission+r.bonus+(r.overtime_hours*r.overtime_rate)-r.deductions-r.paid_amount;
  if v_due<=0 or p_amount>v_due then raise exception 'Payment exceeds outstanding payroll amount'; end if;
  v_receipt:='PAY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by,idempotency_key,created_at,payroll_record_id)
    values(v_receipt,'payroll_payment','debit',p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),''),auth.uid(),p_idempotency_key,at_time,r.id)
    on conflict(idempotency_key) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; return v_id; end if;
  perform set_config('sws.allow_payroll_settlement','on',true);
  update public.payroll_records set paid_amount=paid_amount+p_amount,status=case when paid_amount+p_amount>=base_salary+commission+bonus+(overtime_hours*overtime_rate)-deductions then 'closed' else 'open' end where id=r.id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'payroll_payment_recorded','payroll_record',r.id::text,jsonb_build_object('movement_id',v_id,'amount',p_amount,'receipt_no',v_receipt,'effective_at',at_time));
  return v_id;
end $$;

create or replace function public.sws_update_office_expense(p_expense_id uuid,p_category text,p_description text,p_reason text default 'تعديل بيانات المصروف')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.office_expenses%rowtype; movement_time timestamptz;
begin
 perform public.sws_require_admin();
 select * into e from public.office_expenses where id=p_expense_id for update;
 if not found then raise exception 'Expense not found'; end if;
 select created_at into movement_time from public.financial_movements where id=e.movement_id;
 if exists(select 1 from public.monthly_closings where month_start=date_trunc('month',movement_time at time zone 'Africa/Cairo')::date and status='closed') then raise exception 'Accounting month is closed'; end if;
 if nullif(trim(coalesce(p_category,'')),'') is null then raise exception 'Expense category is required'; end if;
 update public.office_expenses set category=trim(p_category),description=trim(coalesce(p_description,'')) where id=e.id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
  values(auth.uid(),'office_expense_details_updated','office_expense',e.id::text,to_jsonb(e),jsonb_build_object('category',trim(p_category),'description',trim(coalesce(p_description,''))),nullif(trim(coalesce(p_reason,'')),''));
end $$;

create or replace function public.sws_update_movement_note(p_movement_id uuid,p_note text,p_reason text default 'تعديل البيان')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare mrow public.financial_movements%rowtype;
begin
 perform public.sws_require_admin();
 select * into mrow from public.financial_movements where id=p_movement_id for update;
 if not found then raise exception 'Movement not found'; end if;
 if exists(select 1 from public.monthly_closings where month_start=date_trunc('month',mrow.created_at at time zone 'Africa/Cairo')::date and status='closed') then raise exception 'Accounting month is closed'; end if;
 update public.financial_movements set note=nullif(trim(coalesce(p_note,'')),'') where id=mrow.id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'financial_movement_note_updated','financial_movement',mrow.id::text,to_jsonb(mrow),jsonb_build_object('note',nullif(trim(coalesce(p_note,'')),'')),nullif(trim(coalesce(p_reason,'')),''));
end $$;

create or replace function public.sws_delete_traveler_document(p_document_id uuid,p_reason text default 'حذف مستند')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.traveler_documents%rowtype;
begin
 perform public.sws_require_admin();
 select * into d from public.traveler_documents where id=p_document_id for update;
 if not found then raise exception 'Document not found'; end if;
 delete from public.traveler_documents where id=d.id;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,reason)
 values(auth.uid(),'traveler_document_deleted','traveler_document',d.id::text,to_jsonb(d),nullif(trim(coalesce(p_reason,'')),''));
end $$;

-- Ensure RPC-only actions remain available to authenticated active admin.
revoke all on function public.sws_archive_traveler(uuid,text) from public;
revoke all on function public.sws_restore_traveler(uuid,text) from public;
revoke all on function public.sws_monthly_traveler_ledger(date) from public;
revoke all on function public.sws_get_monthly_dashboard_summary(date) from public;
revoke all on function public.sws_create_payroll_record(text,date,numeric,numeric,numeric,numeric,numeric,numeric) from public;
revoke all on function public.sws_update_payroll_record(uuid,text,numeric,numeric,numeric,numeric,numeric,numeric) from public;
revoke all on function public.sws_delete_payroll_record(uuid,text) from public;
revoke all on function public.sws_pay_payroll(uuid,numeric,text,text,uuid,timestamptz) from public;
revoke all on function public.sws_update_office_expense(uuid,text,text,text) from public;
revoke all on function public.sws_update_movement_note(uuid,text,text) from public;
revoke all on function public.sws_delete_traveler_document(uuid,text) from public;
grant execute on function public.sws_archive_traveler(uuid,text) to authenticated;
grant execute on function public.sws_restore_traveler(uuid,text) to authenticated;
grant execute on function public.sws_monthly_traveler_ledger(date) to authenticated;
grant execute on function public.sws_get_monthly_dashboard_summary(date) to authenticated;
grant execute on function public.sws_create_payroll_record(text,date,numeric,numeric,numeric,numeric,numeric,numeric) to authenticated;
grant execute on function public.sws_update_payroll_record(uuid,text,numeric,numeric,numeric,numeric,numeric,numeric) to authenticated;
grant execute on function public.sws_delete_payroll_record(uuid,text) to authenticated;
grant execute on function public.sws_pay_payroll(uuid,numeric,text,text,uuid,timestamptz) to authenticated;
grant execute on function public.sws_update_office_expense(uuid,text,text,text) to authenticated;
grant execute on function public.sws_update_movement_note(uuid,text,text) to authenticated;
grant execute on function public.sws_delete_traveler_document(uuid,text) to authenticated;
revoke all on function public.sws_list_travelers(text,integer,integer,date) from public;
grant execute on function public.sws_list_travelers(text,integer,integer,date) to authenticated;
commit;

-- ===== 202610180001_sws_safe_traveler_delete.sql =====
-- SWS safe traveler deletion for an EXISTING database.
-- Adds only a cleanup queue and RPC functions; it does not reset or rewrite existing records.
-- Apply only after reviewing this migration. Storage object deletion is performed by the app via Storage API.
begin;

create table if not exists public.sws_storage_cleanup_queue (
  storage_path text primary key,
  traveler_id text not null,
  queued_at timestamptz not null default now(),
  last_error text
);

alter table public.sws_storage_cleanup_queue enable row level security;
revoke all on public.sws_storage_cleanup_queue from anon, authenticated, public;

create or replace function public.sws_delete_traveler(
  p_traveler_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t public.travelers%rowtype;
  v_paths text[] := array[]::text[];
  v_movement_ids uuid[] := array[]::uuid[];
  v_movements jsonb := '[]'::jsonb;
  v_documents jsonb := '[]'::jsonb;
  v_expense_count integer := 0;
begin
  perform public.sws_require_admin();
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'Deletion reason is required';
  end if;

  select * into t from public.travelers where id = p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;

  select coalesce(array_agg(d.storage_path), array[]::text[]),
         coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
    into v_paths, v_documents
  from public.traveler_documents d
  where d.traveler_id = t.id;

  -- Include all reversals that point to a traveler movement, including reversal chains.
  with recursive related(id) as (
    select fm.id from public.financial_movements fm where fm.traveler_id = t.id
    union
    select child.id
    from public.financial_movements child
    join related parent on child.reverses_movement_id = parent.id
  )
  select coalesce(array_agg(id), array[]::uuid[])
    into v_movement_ids from related;

  if cardinality(v_movement_ids) > 0 then
    if exists (
      select 1
      from public.financial_movements fm
      join public.monthly_closings mc
        on mc.month_start = date_trunc('month', fm.created_at at time zone 'Africa/Cairo')::date
       and mc.status = 'closed'
      where fm.id = any(v_movement_ids)
    ) then
      raise exception 'Traveler has financial movements in a closed month. Reopen the month with a reason first.';
    end if;

    select count(*) into v_expense_count
    from public.office_expenses oe
    where oe.movement_id = any(v_movement_ids);
    if v_expense_count > 0 then
      raise exception 'A linked movement is referenced by an office expense; deletion stopped to protect accounting links.';
    end if;

    if exists (
      select 1 from public.financial_movements fm
      where fm.id = any(v_movement_ids)
        and (fm.movement_type not in ('traveler_collection', 'reversal') or fm.payroll_record_id is not null)
    ) then
      raise exception 'Unexpected financial relationship found; deletion stopped to protect payroll or other accounting records.';
    end if;

    select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at), '[]'::jsonb)
      into v_movements
    from public.financial_movements fm
    where fm.id = any(v_movement_ids);
  end if;

  -- Preserve an audit snapshot before removing the traveler and linked financial records.
  insert into public.audit_log(actor_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (
    auth.uid(), 'traveler_permanently_deleted', 'traveler', t.id::text,
    jsonb_build_object('traveler', to_jsonb(t), 'documents', v_documents, 'financial_movements', v_movements),
    jsonb_build_object('deleted', true, 'movement_count', cardinality(v_movement_ids), 'document_count', cardinality(v_paths), 'storage_cleanup_pending', cardinality(v_paths)),
    trim(p_reason)
  );

  -- Queue private Storage paths durably; SQL cannot delete Storage objects transactionally.
  insert into public.sws_storage_cleanup_queue(storage_path, traveler_id)
  select path, t.id::text from unnest(v_paths) as u(path)
  on conflict (storage_path) do update
    set traveler_id = excluded.traveler_id, queued_at = now(), last_error = null;

  -- Break self-references within the set, then remove the linked movements.
  if cardinality(v_movement_ids) > 0 then
    update public.financial_movements
       set reverses_movement_id = null
     where id = any(v_movement_ids);
    delete from public.financial_movements where id = any(v_movement_ids);
  end if;

  -- traveler_documents rows are removed by the existing ON DELETE CASCADE relationship.
  delete from public.travelers where id = t.id;

  return jsonb_build_object(
    'traveler_id', t.id,
    'storage_paths', to_jsonb(v_paths),
    'deleted_movement_count', cardinality(v_movement_ids),
    'deleted_document_count', cardinality(v_paths)
  );
end;
$$;

create or replace function public.sws_list_pending_storage_cleanup()
returns text[]
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.sws_require_admin();
  return coalesce((select array_agg(storage_path order by queued_at) from public.sws_storage_cleanup_queue), array[]::text[]);
end;
$$;

create or replace function public.sws_ack_storage_cleanup(p_storage_paths text[])
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  perform public.sws_require_admin();
  if p_storage_paths is null or cardinality(p_storage_paths) = 0 then return 0; end if;
  delete from public.sws_storage_cleanup_queue where storage_path = any(p_storage_paths);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.sws_delete_traveler(uuid, text) from public, anon;
revoke all on function public.sws_list_pending_storage_cleanup() from public, anon;
revoke all on function public.sws_ack_storage_cleanup(text[]) from public, anon;
grant execute on function public.sws_delete_traveler(uuid, text) to authenticated;
grant execute on function public.sws_list_pending_storage_cleanup() to authenticated;
grant execute on function public.sws_ack_storage_cleanup(text[]) to authenticated;

commit;


-- ===== 202610180002_sws_full_crud_print.sql =====
-- Additive full CRUD support for office expenses and print workflows.
-- SWS: full edit/delete/print workflows for payroll, expenses and financial movement notes.
-- Additive migration for the existing schema. Does not reset or truncate business data.
begin;

create or replace function public.sws_update_office_expense_full(
  p_expense_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_category text,
  p_description text,
  p_reason text
) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  e public.office_expenses%rowtype;
  old_m public.financial_movements%rowtype;
  new_movement_id uuid;
  new_receipt text;
  old_data jsonb;
begin
  perform public.sws_require_admin();
  if p_amount is null or p_amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  if coalesce(trim(p_category),'') = '' then raise exception 'Expense category is required'; end if;
  if coalesce(trim(p_reason),'') = '' then raise exception 'Edit reason is required'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;

  select * into e from public.office_expenses where id=p_expense_id for update;
  if not found then raise exception 'Expense not found'; end if;
  select * into old_m from public.financial_movements where id=e.movement_id for update;
  if not found then raise exception 'Expense financial movement not found'; end if;
  if old_m.status <> 'posted' then raise exception 'Only posted expenses can be edited'; end if;
  if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',old_m.created_at at time zone 'Africa/Cairo')::date and c.status='closed') then
    raise exception 'Accounting month is closed';
  end if;
  old_data := jsonb_build_object('expense',to_jsonb(e),'movement',to_jsonb(old_m));

  if old_m.amount <> p_amount or old_m.payment_method <> p_payment_method then
    -- Reverse the original expense and post a corrected debit; never silently overwrite a cash movement.
    perform public.sws_reverse_movement(old_m.id, 'تعديل مصروف: '||trim(p_reason));
    new_receipt := 'EXP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
    insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,status,created_by,created_at)
    values(new_receipt,'office_expense','debit',p_amount,p_payment_method,trim(coalesce(p_description,'')),'posted',auth.uid(),now())
    returning id into new_movement_id;
    update public.office_expenses set movement_id=new_movement_id,category=trim(p_category),description=trim(coalesce(p_description,'')),created_at=now() where id=e.id;
  else
    update public.office_expenses set category=trim(p_category),description=trim(coalesce(p_description,'')) where id=e.id;
    update public.financial_movements set note=nullif(trim(coalesce(p_description,'')),'') where id=old_m.id;
  end if;

  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
  values(auth.uid(),'office_expense_updated','office_expense',e.id::text,old_data,
    jsonb_build_object('amount',p_amount,'payment_method',p_payment_method,'category',trim(p_category),'description',trim(coalesce(p_description,'')),'replacement_movement_id',new_movement_id),trim(p_reason));
end $$;

create or replace function public.sws_delete_office_expense(p_expense_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.office_expenses%rowtype; m public.financial_movements%rowtype;
begin
  perform public.sws_require_admin();
  if coalesce(trim(p_reason),'')='' then raise exception 'Deletion reason is required'; end if;
  select * into e from public.office_expenses where id=p_expense_id for update;
  if not found then raise exception 'Expense not found'; end if;
  select * into m from public.financial_movements where id=e.movement_id for update;
  if not found then raise exception 'Expense movement not found'; end if;
  if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',m.created_at at time zone 'Africa/Cairo')::date and c.status='closed') then
    raise exception 'Accounting month is closed';
  end if;
  if m.status<>'posted' then raise exception 'Only posted expenses can be deleted'; end if;
  if exists(select 1 from public.financial_movements where reverses_movement_id=m.id) then raise exception 'Expense movement already reversed'; end if;
  -- Preserve both the original movement and its reversal in the ledger; remove only the expense detail row.
  perform public.sws_reverse_movement(m.id,'حذف مصروف: '||trim(p_reason));
  delete from public.office_expenses where id=e.id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,reason)
  values(auth.uid(),'office_expense_deleted','office_expense',e.id::text,jsonb_build_object('expense',to_jsonb(e),'movement',to_jsonb(m)),trim(p_reason));
end $$;

revoke all on function public.sws_update_office_expense_full(uuid,numeric,text,text,text,text) from public;
revoke all on function public.sws_delete_office_expense(uuid,text) from public;
grant execute on function public.sws_update_office_expense_full(uuid,numeric,text,text,text,text) to authenticated;
grant execute on function public.sws_delete_office_expense(uuid,text) to authenticated;
commit;


-- ===== 202610190001_sws_dashboard_analytics.sql =====
-- SWS dashboard analytics: safe additive update.
-- Adds aggregate traveler balances and chart series to the existing monthly dashboard RPC.
-- Does not alter or delete business records.
begin;

create or replace function public.sws_get_monthly_dashboard_summary(p_month_start date)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m date := date_trunc('month', p_month_start)::date;
  n date;
  result jsonb;
begin
  perform public.sws_require_admin();
  n := (m + interval '1 month')::date;

  select jsonb_build_object(
    -- Existing month-scoped KPIs retained for compatibility.
    'traveler_count', (
      select count(*) from public.travelers t
      where t.archived_at is null
        and t.created_at >= (m::timestamp at time zone 'Africa/Cairo')
        and t.created_at < (n::timestamp at time zone 'Africa/Cairo')
    ),
    'employee_count', (
      select count(*) from public.payroll_records p where p.month_start = m
    ),
    'total_collections', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'traveler_collection'
        and fm.direction = 'credit'
    ), 0),
    'general_revenue', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'general_revenue'
        and fm.direction = 'credit'
    ), 0),
    'office_expenses', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'office_expense'
        and fm.direction = 'debit'
    ), 0),
    'payroll_paid', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'payroll_payment'
        and fm.direction = 'debit'
    ), 0),
    'cash_balance', (
      select coalesce(sum(case when direction = 'credit' then amount else -amount end), 0)
      from public.financial_movements
      where status in ('posted', 'reversed')
        and created_at < (n::timestamp at time zone 'Africa/Cairo')
    ),

    -- All-time current outstanding for active (not archived) travelers.
    'total_travelers_count', (
      select count(*) from public.travelers t where t.archived_at is null
    ),
    'traveler_agreement_total', (
      select coalesce(sum(t.agreement_total), 0)
      from public.travelers t where t.archived_at is null
    ),
    'traveler_paid_total', (
      select coalesce(sum(p.paid), 0)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
    ),
    'traveler_remaining_total', (
      select coalesce(sum(greatest(t.agreement_total - coalesce(p.paid, 0), 0)), 0)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
    ),
    'travelers_fully_paid', (
      select count(*)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
        and greatest(t.agreement_total - coalesce(p.paid, 0), 0) <= 0
    ),
    'travelers_with_balance', (
      select count(*)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
        and greatest(t.agreement_total - coalesce(p.paid, 0), 0) > 0
    ),
    'traveler_stages', (
      select jsonb_build_object(
        'new', count(*) filter (where not t.stage_submitted and not t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'submitted', count(*) filter (where t.stage_submitted and not t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'inspected', count(*) filter (where t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'visa', count(*) filter (where t.stage_visa and not t.stage_flight),
        'flight', count(*) filter (where t.stage_flight)
      )
      from public.travelers t where t.archived_at is null
    ),
    'monthly_trend', (
      select coalesce(jsonb_agg(to_jsonb(trend) order by trend.month_start), '[]'::jsonb)
      from (
        select
          gs.month_start::date as month_start,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'traveler_collection'
              and f.direction = 'credit'
          ), 0) as collections,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'general_revenue'
              and f.direction = 'credit'
          ), 0) as general_revenue,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'office_expense'
              and f.direction = 'debit'
          ), 0) as office_expenses,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'payroll_payment'
              and f.direction = 'debit'
          ), 0) as payroll_paid,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted' and f.direction = 'credit'
          ), 0) as total_credits,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted' and f.direction = 'debit'
          ), 0) as total_debits
        from generate_series(m - interval '5 months', m, interval '1 month') as gs(month_start)
        left join public.financial_movements f
          on f.created_at >= (gs.month_start::date::timestamp at time zone 'Africa/Cairo')
         and f.created_at < ((gs.month_start::date + interval '1 month')::timestamp at time zone 'Africa/Cairo')
         and f.status in ('posted', 'reversed')
        group by gs.month_start
      ) trend
    )
  ) into result
  from public.financial_movements fm
  where fm.status in ('posted', 'reversed')
    and fm.created_at >= (m::timestamp at time zone 'Africa/Cairo')
    and fm.created_at < (n::timestamp at time zone 'Africa/Cairo');

  return coalesce(result, '{}'::jsonb);
end;
$$;

revoke all on function public.sws_get_monthly_dashboard_summary(date) from public;
grant execute on function public.sws_get_monthly_dashboard_summary(date) to authenticated;

commit;


-- Latest additive migration: hard-delete entries without reversal movements.
-- SWS: hard-delete financial entries instead of creating reversal entries.
-- Fully paid payroll rows are removed from the active payroll list; payment movements remain in finance.
-- Run this migration alone on the existing database, not INSTALL_ALL_MIGRATIONS.sql.
begin;

create or replace function public.sws_pay_payroll(
 p_payroll_id uuid,p_amount numeric,p_payment_method text,p_note text,p_idempotency_key uuid,p_effective_at timestamptz
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare
 r public.payroll_records%rowtype;
 v_id uuid;
 v_due numeric;
 v_total numeric;
 v_receipt text;
 at_time timestamptz:=coalesce(p_effective_at,now());
 v_movements jsonb;
begin
 perform public.sws_require_admin();
 if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
 if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
 select * into r from public.payroll_records where id=p_payroll_id for update;
 if not found then raise exception 'Payroll record not found'; end if;
 if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',r.month_start)::date and c.status='closed') then raise exception 'Accounting month is closed'; end if;
 if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',at_time at time zone 'Africa/Cairo')::date and c.status='closed') then raise exception 'Payment month is closed'; end if;
 if p_idempotency_key is not null then
   select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key;
   if found then return v_id; end if;
 end if;
 v_total:=r.base_salary+r.commission+r.bonus+(r.overtime_hours*r.overtime_rate)-r.deductions;
 v_due:=v_total-r.paid_amount;
 if v_due<=0 or p_amount>v_due then raise exception 'Payment exceeds outstanding payroll amount'; end if;
 v_receipt:='PAY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
 insert into public.financial_movements(receipt_no,movement_type,direction,amount,payment_method,note,created_by,idempotency_key,created_at,payroll_record_id)
 values(v_receipt,'payroll_payment','debit',p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),''),auth.uid(),p_idempotency_key,at_time,r.id)
 on conflict(idempotency_key) do nothing returning id into v_id;
 if v_id is null then select id into v_id from public.financial_movements where idempotency_key=p_idempotency_key; return v_id; end if;
 perform set_config('sws.allow_payroll_settlement','on',true);
 update public.payroll_records set paid_amount=paid_amount+p_amount,
   status=case when paid_amount+p_amount>=v_total then 'closed' else 'open' end
 where id=r.id returning * into r;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'payroll_payment_recorded','payroll_record',r.id::text,to_jsonb(r),jsonb_build_object('movement_id',v_id,'amount',p_amount,'receipt_no',v_receipt,'effective_at',at_time),
   case when r.paid_amount>=v_total then 'Fully paid; payroll row removed from active list' else null end);
 if r.paid_amount>=v_total then
   select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at,fm.id),'[]'::jsonb) into v_movements
   from public.financial_movements fm where fm.payroll_record_id=r.id;
   insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
   values(auth.uid(),'payroll_fully_paid_removed','payroll_record',r.id::text,
     jsonb_build_object('payroll_record',to_jsonb(r),'linked_movements',v_movements),
     jsonb_build_object('removed_from_active_payroll',true,'financial_movements_preserved',true),'تم صرف كامل الراتب');
   update public.financial_movements set payroll_record_id=null where payroll_record_id=r.id;
   delete from public.payroll_records where id=r.id;
 end if;
 return v_id;
end $$;

create or replace function public.sws_delete_payroll_record(p_payroll_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare
 r public.payroll_records%rowtype;
 ids uuid[];
 movements jsonb;
begin
 perform public.sws_require_admin();
 if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Deletion reason is required'; end if;
 select * into r from public.payroll_records where id=p_payroll_id for update;
 if not found then raise exception 'Payroll record not found'; end if;
 if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',r.month_start)::date and c.status='closed') then raise exception 'Accounting month is closed; reopen it first'; end if;
 with recursive related(id) as (
   select fm.id from public.financial_movements fm where fm.payroll_record_id=r.id
   union
   select child.id from public.financial_movements child join related parent on child.reverses_movement_id=parent.id
 ) select coalesce(array_agg(id),'{}'::uuid[]) into ids from related;
 if cardinality(ids)>0 and exists(select 1 from public.financial_movements fm join public.monthly_closings c on c.month_start=date_trunc('month',fm.created_at at time zone 'Africa/Cairo')::date and c.status='closed' where fm.id=any(ids)) then
   raise exception 'A linked payment belongs to a closed month; reopen it first';
 end if;
 select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at,fm.id),'[]'::jsonb) into movements from public.financial_movements fm where fm.id=any(ids);
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'payroll_record_deleted','payroll_record',r.id::text,jsonb_build_object('payroll_record',to_jsonb(r),'deleted_financial_movements',movements),jsonb_build_object('deleted',true),trim(p_reason));
 if cardinality(ids)>0 then
   update public.financial_movements set reverses_movement_id=null where id=any(ids);
   delete from public.financial_movements where id=any(ids);
 end if;
 delete from public.payroll_records where id=r.id;
end $$;

create or replace function public.sws_update_office_expense_full(
 p_expense_id uuid,p_amount numeric,p_payment_method text,p_category text,p_description text,p_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.office_expenses%rowtype; m public.financial_movements%rowtype;
begin
 perform public.sws_require_admin();
 if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
 if nullif(trim(coalesce(p_category,'')),'') is null then raise exception 'Expense category is required'; end if;
 if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Edit reason is required'; end if;
 if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
 select * into e from public.office_expenses where id=p_expense_id for update;
 if not found then raise exception 'Expense not found'; end if;
 select * into m from public.financial_movements where id=e.movement_id for update;
 if not found then raise exception 'Expense financial movement not found'; end if;
 if exists(select 1 from public.monthly_closings c where c.month_start=date_trunc('month',m.created_at at time zone 'Africa/Cairo')::date and c.status='closed') then raise exception 'Accounting month is closed'; end if;
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'office_expense_updated','office_expense',e.id::text,jsonb_build_object('expense',to_jsonb(e),'movement',to_jsonb(m)),
 jsonb_build_object('amount',p_amount,'payment_method',p_payment_method,'category',trim(p_category),'description',trim(coalesce(p_description,''))),trim(p_reason));
 update public.financial_movements set amount=p_amount,payment_method=p_payment_method,note=nullif(trim(coalesce(p_description,'')),'') where id=m.id;
 update public.office_expenses set category=trim(p_category),description=trim(coalesce(p_description,'')) where id=e.id;
end $$;

create or replace function public.sws_delete_office_expense(p_expense_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.office_expenses%rowtype; m public.financial_movements%rowtype; ids uuid[]; movement_data jsonb;
begin
 perform public.sws_require_admin();
 if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Deletion reason is required'; end if;
 select * into e from public.office_expenses where id=p_expense_id for update;
 if not found then raise exception 'Expense not found'; end if;
 select * into m from public.financial_movements where id=e.movement_id for update;
 if not found then raise exception 'Expense movement not found'; end if;
 with recursive related(id) as (select m.id union select child.id from public.financial_movements child join related parent on child.reverses_movement_id=parent.id)
 select coalesce(array_agg(id),'{}'::uuid[]) into ids from related;
 if exists(select 1 from public.financial_movements fm join public.monthly_closings c on c.month_start=date_trunc('month',fm.created_at at time zone 'Africa/Cairo')::date and c.status='closed' where fm.id=any(ids)) then raise exception 'Accounting month is closed'; end if;
 select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at,fm.id),'[]'::jsonb) into movement_data from public.financial_movements fm where fm.id=any(ids);
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'office_expense_deleted','office_expense',e.id::text,jsonb_build_object('expense',to_jsonb(e),'movements',movement_data),jsonb_build_object('deleted',true),trim(p_reason));
 delete from public.office_expenses where id=e.id;
 update public.financial_movements set reverses_movement_id=null where id=any(ids);
 delete from public.financial_movements where id=any(ids);
end $$;

create or replace function public.sws_delete_financial_movement(p_movement_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.financial_movements%rowtype; ids uuid[]; movement_data jsonb; expense_data jsonb; payroll_ids uuid[];
begin
 perform public.sws_require_admin();
 if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Deletion reason is required'; end if;
 select * into m from public.financial_movements where id=p_movement_id for update;
 if not found then raise exception 'Movement not found'; end if;
 with recursive related(id) as (
   select fm.id from public.financial_movements fm where fm.id=m.id or fm.reverses_movement_id=m.id
   union
   select child.id from public.financial_movements child join related parent on child.reverses_movement_id=parent.id
   union
   select parent.id from public.financial_movements parent join related child on child.reverses_movement_id=parent.id
 ) select coalesce(array_agg(id),'{}'::uuid[]) into ids from related;
 if exists(select 1 from public.financial_movements fm join public.monthly_closings c on c.month_start=date_trunc('month',fm.created_at at time zone 'Africa/Cairo')::date and c.status='closed' where fm.id=any(ids)) then raise exception 'Accounting month is closed; reopen it first'; end if;
 if exists(select 1 from public.financial_movements fm join public.payroll_records pr on pr.id=fm.payroll_record_id join public.monthly_closings c on c.month_start=date_trunc('month',pr.month_start)::date and c.status='closed' where fm.id=any(ids)) then raise exception 'Payroll month is closed; reopen it first'; end if;
 select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at,fm.id),'[]'::jsonb) into movement_data from public.financial_movements fm where fm.id=any(ids);
 select coalesce(array_agg(distinct fm.payroll_record_id) filter(where fm.payroll_record_id is not null),'{}'::uuid[]) into payroll_ids from public.financial_movements fm where fm.id=any(ids) and fm.movement_type='payroll_payment';
 select coalesce(jsonb_agg(to_jsonb(oe)),'[]'::jsonb) into expense_data from public.office_expenses oe where oe.movement_id=any(ids);
 insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
 values(auth.uid(),'financial_movement_deleted','financial_movement',m.id::text,jsonb_build_object('selected_movement',to_jsonb(m),'movements',movement_data,'expenses',expense_data),jsonb_build_object('deleted',true,'movement_count',cardinality(ids)),trim(p_reason));
 delete from public.office_expenses where movement_id=any(ids);
 if cardinality(payroll_ids)>0 then
   perform set_config('sws.allow_payroll_settlement','on',true);
   update public.payroll_records pr set paid_amount=greatest(0,pr.paid_amount-coalesce((select sum(fm.amount) from public.financial_movements fm where fm.id=any(ids) and fm.payroll_record_id=pr.id and fm.movement_type='payroll_payment'),0)),status='open'
   where pr.id=any(payroll_ids);
 end if;
 update public.financial_movements set reverses_movement_id=null where id=any(ids);
 delete from public.financial_movements where id=any(ids);
end $$;

-- Disable the old reversal RPC; all new delete actions now remove the selected records.
revoke all on function public.sws_reverse_movement(uuid,text) from public, authenticated;
revoke all on function public.sws_pay_payroll(uuid,numeric,text,text,uuid,timestamptz) from public;
revoke all on function public.sws_delete_payroll_record(uuid,text) from public;
revoke all on function public.sws_update_office_expense_full(uuid,numeric,text,text,text,text) from public;
revoke all on function public.sws_delete_office_expense(uuid,text) from public;
revoke all on function public.sws_delete_financial_movement(uuid,text) from public;
grant execute on function public.sws_pay_payroll(uuid,numeric,text,text,uuid,timestamptz) to authenticated;
grant execute on function public.sws_delete_payroll_record(uuid,text) to authenticated;
grant execute on function public.sws_update_office_expense_full(uuid,numeric,text,text,text,text) to authenticated;
grant execute on function public.sws_delete_office_expense(uuid,text) to authenticated;
grant execute on function public.sws_delete_financial_movement(uuid,text) to authenticated;
commit;
