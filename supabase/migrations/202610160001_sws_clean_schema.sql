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
