-- SWS Admin Finance & Traveler Management schema.
-- Run after creating a Supabase project. No service-role key belongs in Flutter.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  role text not null default 'admin' check (role = 'admin'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.company_settings (
  id integer primary key default 1 check(id=1),
  company_name text not null default 'شركة شمس الإبداع',
  notes text not null default '',
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.company_settings(id) values(1) on conflict(id) do nothing;

create sequence if not exists public.sws_file_no_seq start 1001;
create sequence if not exists public.sws_receipt_seq start 1001;
create or replace function public.sws_next_file_no() returns text language sql volatile as $$ select 'SWS-' || lpad(nextval('public.sws_file_no_seq')::text, 6, '0'); $$;
create or replace function public.sws_next_receipt_no() returns text language sql volatile as $$ select 'SWS-' || to_char(now(),'YYMM') || '-' || lpad(nextval('public.sws_receipt_seq')::text, 8, '0'); $$;

create table if not exists public.travelers (
 id uuid primary key default gen_random_uuid(), file_no text not null unique default public.sws_next_file_no(),
 full_name text not null check(length(trim(full_name))>=2), phone text not null,
 sales_person text not null default '', agreement_total numeric(14,2) not null default 0 check(agreement_total>=0),
 stage text not null default 'قدم' check(stage in ('قدم','كشف','تأشيرة','طيارة')),
 stage_submitted boolean not null default true, stage_check boolean not null default false, stage_visa boolean not null default false, stage_flight boolean not null default false,
 passport_number text not null default '', destination_country text not null default '', profession text not null default '', nationality text not null default '', address text not null default '', notes text not null default '',
 is_archived boolean not null default false, archive_reason text not null default '', created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version integer not null default 1
);
create or replace function public.sws_normalize_file_no() returns trigger language plpgsql as $$
declare v_existing_file_no text; begin if new.file_no like 'PENDING-%' or trim(new.file_no)='' then select file_no into v_existing_file_no from public.travelers where id=new.id; if v_existing_file_no is not null then new.file_no:=v_existing_file_no; else new.file_no:=public.sws_next_file_no(); end if; end if; return new; end; $$;
drop trigger if exists sws_normalize_file_no on public.travelers;
create trigger sws_normalize_file_no before insert on public.travelers for each row execute function public.sws_normalize_file_no();

-- Idempotent compatibility for an already-created SWS schema.
alter table public.travelers add column if not exists stage_submitted boolean not null default true;
alter table public.travelers add column if not exists stage_check boolean not null default false;
alter table public.travelers add column if not exists stage_visa boolean not null default false;
alter table public.travelers add column if not exists stage_flight boolean not null default false;
alter table public.travelers alter column sales_person set default '';
create index if not exists sws_travelers_created_idx on public.travelers(created_at desc);
create index if not exists sws_travelers_phone_idx on public.travelers(phone);
create index if not exists sws_travelers_stage_idx on public.travelers(stage) where not is_archived;
create table if not exists public.traveler_stage_history (
 id uuid primary key default gen_random_uuid(), traveler_id uuid not null references public.travelers(id) on delete restrict,
 old_stage text not null, new_stage text not null, reason text not null check(length(trim(reason))>0), changed_by uuid references auth.users(id), changed_at timestamptz not null default now()
);
create table if not exists public.traveler_agreement_history (
 id uuid primary key default gen_random_uuid(), traveler_id uuid not null references public.travelers(id) on delete restrict,
 old_amount numeric(14,2) not null, new_amount numeric(14,2) not null, reason text not null check(length(trim(reason))>0), changed_by uuid references auth.users(id), changed_at timestamptz not null default now()
);

create table if not exists public.financial_accounts (
 id uuid primary key default gen_random_uuid(), name text not null, account_type text not null check(account_type in ('خزنة نقدية','حساب بنكي','محفظة إلكترونية')),
 provider_name text not null default '', account_identifier text not null default '', is_system boolean not null default false, notes text not null default '', opening_balance numeric(14,2) not null default 0 check(opening_balance>=0), opening_date date not null default current_date,
 is_active boolean not null default true, inactive_reason text not null default '', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
alter table public.financial_accounts add column if not exists is_system boolean not null default false;
create unique index if not exists sws_only_one_system_cash on public.financial_accounts(is_system) where is_system=true;
create table if not exists public.expense_categories (
 id uuid primary key default gen_random_uuid(), name text not null, parent_id uuid references public.expense_categories(id), parent_name text not null default '', notes text not null default '', is_active boolean not null default true, inactive_reason text not null default '', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.entities (
 id uuid primary key default gen_random_uuid(), name text not null, entity_type text not null default 'شخص', phone text not null default '', notes text not null default '', is_active boolean not null default true, inactive_reason text not null default '', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
insert into public.expense_categories(name,parent_name,notes)
select x.name,'','تصنيف افتراضي قابل للتعديل'
from (values ('إيجار المكتب'),('مرافق وكهرباء'),('إنترنت واتصالات'),('أدوات مكتبية'),('انتقالات ومواصلات'),('صيانة'),('ضيافة'),('مصروفات أخرى')) as x(name)
where not exists (select 1 from public.expense_categories c where c.name=x.name);
create table if not exists public.payroll_settlements (
 id uuid primary key default gen_random_uuid(), employee_name text not null, month_start date not null check(month_start=date_trunc('month',month_start)::date),
 base_salary numeric(14,2) not null default 0 check(base_salary>=0), additions numeric(14,2) not null default 0 check(additions>=0), commissions numeric(14,2) not null default 0 check(commissions>=0),
 deductions numeric(14,2) not null default 0 check(deductions>=0), deduction_reason text not null default '', advances numeric(14,2) not null default 0 check(advances>=0),
 net_due numeric(14,2) generated always as (base_salary+additions+commissions-deductions-advances) stored,
 paid_amount numeric(14,2) not null default 0 check(paid_amount>=0), remaining_amount numeric(14,2) generated always as (base_salary+additions+commissions-deductions-advances-paid_amount) stored,
 status text not null default 'unpaid' check(status in ('unpaid','partial','paid')), notes text not null default '', created_by uuid references auth.users(id), updated_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(employee_name,month_start)
);
create table if not exists public.period_closures (
 id uuid primary key default gen_random_uuid(), month_start date not null unique check(month_start=date_trunc('month',month_start)::date), status text not null default 'closed' check(status in ('closed','reopened')),
 snapshot jsonb not null default '{}'::jsonb, note text not null default '', closed_by uuid references auth.users(id), closed_by_name text not null default '', closed_at timestamptz not null default now(), reopen_reason text not null default '', reopened_by uuid references auth.users(id), reopened_at timestamptz
);

create table if not exists public.financial_movements (
 id uuid primary key default gen_random_uuid(), receipt_no text not null unique default public.sws_next_receipt_no(),
 movement_type text not null check(movement_type in ('opening_balance','traveler_collection','general_revenue','expense','refund','payroll_payment','transfer_out','transfer_in','reversal','correction')),
 account_id uuid not null references public.financial_accounts(id) on delete restrict, traveler_id uuid references public.travelers(id) on delete restrict,
 payroll_id uuid references public.payroll_settlements(id) on delete restrict, category_id uuid references public.expense_categories(id) on delete restrict,
 transfer_group uuid, reversal_of uuid references public.financial_movements(id) on delete restrict,
 movement_date date not null default current_date, counterparty text not null default '', amount numeric(14,2) not null check(amount>0), direction text not null check(direction in ('credit','debit')),
 payment_method text not null default '', reason text not null check(length(trim(reason))>0), reference_number text not null default '', notes text not null default '',
 status text not null default 'posted' check(status in ('posted','reversed')), created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists sws_movements_date_idx on public.financial_movements(movement_date desc);
create index if not exists sws_movements_account_idx on public.financial_movements(account_id,movement_date desc);
create index if not exists sws_movements_traveler_idx on public.financial_movements(traveler_id,movement_date desc);
create unique index if not exists sws_one_reversal_per_movement on public.financial_movements(reversal_of) where reversal_of is not null;

create or replace view public.traveler_financial_summary with (security_invoker=true) as
 select t.id as traveler_id,
 coalesce(sum(case when m.direction='credit' then m.amount else -m.amount end),0)::numeric(14,2) as net_paid
 from public.travelers t left join public.financial_movements m on m.traveler_id=t.id group by t.id;

create or replace view public.account_balances with (security_invoker=true) as
 select a.id,a.name,a.account_type,a.provider_name,a.account_identifier,a.is_active,
 coalesce(sum(case when m.direction='credit' then m.amount when m.direction='debit' then -m.amount else 0 end),0)::numeric(14,2) as balance, a.is_system
 from public.financial_accounts a left join public.financial_movements m on m.account_id=a.id group by a.id;

create table if not exists public.traveler_documents (
 id uuid primary key default gen_random_uuid(), traveler_id uuid not null references public.travelers(id) on delete restrict,
 document_type text not null check(document_type in ('الصورة والباسبور','التأشيرة','إثبات التاريخ','تذكرة الطيران','مستندات أخرى')),
 original_filename text not null, storage_path text not null, mime_type text not null default 'application/octet-stream', file_size bigint not null default 0,
 version_no integer not null default 1, is_current boolean not null default true, is_archived boolean not null default false, archive_reason text not null default '', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);

alter table public.traveler_documents drop constraint if exists traveler_documents_document_type_check;
alter table public.traveler_documents add constraint traveler_documents_document_type_check check(document_type in ('الصورة والباسبور','التأشيرة','إثبات التاريخ','تذكرة الطيران','مستندات أخرى'));
create index if not exists sws_docs_traveler_idx on public.traveler_documents(traveler_id,created_at desc);
create table if not exists public.audit_logs (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id), actor_email text not null default '', action text not null, entity_type text not null, entity_id text not null default '',
 before_data jsonb not null default '{}'::jsonb, after_data jsonb not null default '{}'::jsonb, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists sws_audit_created_idx on public.audit_logs(created_at desc);
create table if not exists public.sync_conflicts (
 id uuid primary key default gen_random_uuid(), table_name text not null, record_id text not null,
 local_data jsonb not null default '{}'::jsonb, server_data jsonb not null default '{}'::jsonb,
 detected_at timestamptz not null default now(), status text not null default 'pending' check(status in ('pending','resolved_local','resolved_server')),
 resolved_by uuid references auth.users(id), resolved_at timestamptz, resolution_reason text not null default ''
);
create index if not exists sws_sync_conflicts_status_idx on public.sync_conflicts(status,detected_at desc);


create or replace function public.sws_is_admin() returns boolean language sql stable security definer set search_path=public,auth as $$
 select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.role='admin' and p.is_active=true);
$$;
revoke all on function public.sws_is_admin() from public;
grant execute on function public.sws_is_admin() to authenticated;

create or replace function public.sws_log_change() returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_id text; v_before jsonb; v_after jsonb;
begin
 if tg_op='INSERT' then v_after=to_jsonb(new); v_id=coalesce(v_after->>'id',v_after->>'user_id','');
 elsif tg_op='UPDATE' then v_before=to_jsonb(old); v_after=to_jsonb(new); v_id=coalesce(v_after->>'id',v_after->>'user_id','');
 else v_before=to_jsonb(old); v_id=coalesce(v_before->>'id',v_before->>'user_id',''); end if;
 insert into public.audit_logs(actor_id,actor_email,action,entity_type,entity_id,before_data,after_data)
 values(auth.uid(),coalesce(auth.jwt()->>'email',''),lower(tg_op),tg_table_name,v_id,coalesce(v_before,'{}'::jsonb),coalesce(v_after,'{}'::jsonb));
 if tg_op='DELETE' then return old; else return new; end if;
end; $$;

create or replace function public.sws_account_balance(p_account uuid) returns numeric language sql stable security definer set search_path=public as $$
 select coalesce(sum(case when direction='credit' then amount else -amount end),0)::numeric(14,2) from public.financial_movements where account_id=p_account;
$$;
create or replace function public.sws_validate_movement() returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_balance numeric; v_month date; v_available numeric;
begin
 if tg_op='UPDATE' then
   if exists(select 1 from public.period_closures c where c.month_start=date_trunc('month',old.movement_date)::date and c.status='closed') then raise exception 'الشهر مغلق؛ أعد فتحه بسبب واضح قبل تصحيح الحركة'; end if;
   if old.status='posted' and new.status='reversed' and old.id=new.id and old.amount=new.amount and old.account_id=new.account_id then return new; end if;
   raise exception 'الحركات المالية غير قابلة للتعديل المباشر؛ استخدم إجراء العكس الموثق';
 end if;
 if tg_op='DELETE' then raise exception 'لا يمكن حذف حركة مالية'; end if;
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 v_month=date_trunc('month',new.movement_date)::date;
 if exists(select 1 from public.period_closures c where c.month_start=v_month and c.status='closed') and new.movement_type not in ('reversal','correction') then raise exception 'الشهر مغلق؛ استخدم إجراء تصحيح موثق'; end if;
 if new.movement_type in ('traveler_collection','refund') and new.traveler_id is null then raise exception 'حركة المسافر يجب أن ترتبط بملف مسافر'; end if;
 if new.movement_type='refund' then
   select coalesce(sum(case when movement_type='traveler_collection' then amount when movement_type='refund' then -amount when movement_type='reversal' and direction='credit' then amount when movement_type='reversal' and direction='debit' then -amount else 0 end),0) into v_available from public.financial_movements where traveler_id=new.traveler_id;
   if new.amount>v_available then raise exception 'قيمة الاسترداد أكبر من صافي التحصيل المتاح للمسافر'; end if;
 end if;
 if new.movement_type='traveler_collection' and length(trim(coalesce(new.payment_method,'')))=0 then raise exception 'طريقة الدفع إلزامية للتحصيل'; end if;
 if new.movement_type='expense' and new.category_id is null then raise exception 'تصنيف المصروف إلزامي'; end if;
 if new.movement_type='correction' and length(trim(coalesce(new.reference_number,'')))=0 then raise exception 'رقم الحركة الأصلية مطلوب للتصحيح'; end if;
 if new.movement_type in ('expense','general_revenue') and length(trim(coalesce(new.counterparty,'')))=0 then raise exception 'اسم المستلم أو الدافع إلزامي'; end if;
 if new.direction='debit' and new.movement_type not in ('opening_balance') then
   v_balance=public.sws_account_balance(new.account_id);
   if v_balance < new.amount then raise exception 'الرصيد غير كافٍ في الحساب المحدد'; end if;
 end if;
 if new.movement_type='opening_balance' then
   if new.direction<>'credit' then raise exception 'الرصيد الافتتاحي يجب أن يكون دائنًا'; end if;
   if not exists(select 1 from public.financial_accounts a where a.id=new.account_id and a.is_system=true) then raise exception 'الرصيد الافتتاحي مسموح فقط لرصيد المكتب'; end if;
   if exists(select 1 from public.financial_movements x where x.account_id=new.account_id and x.movement_type='opening_balance' and x.status='posted' and x.id is distinct from new.id) then raise exception 'تم تسجيل الرصيد الافتتاحي من قبل'; end if;
   if exists(select 1 from public.financial_movements x where x.account_id=new.account_id and x.movement_type<>'opening_balance' and x.status='posted') then raise exception 'لا يمكن إضافة رصيد افتتاحي بعد تسجيل حركات مالية؛ استخدم إجراء تصحيح موثق'; end if;
 end if;
 return new;
end; $$;
drop trigger if exists sws_validate_movement on public.financial_movements;
create trigger sws_validate_movement before insert or update or delete on public.financial_movements for each row execute function public.sws_validate_movement();

create or replace function public.sws_create_opening_movement() returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
 if new.opening_balance>0 then insert into public.financial_movements(movement_type,account_id,movement_date,counterparty,amount,direction,reason,created_by)
 values('opening_balance',new.id,new.opening_date,'رصيد افتتاحي',new.opening_balance,'credit','رصيد افتتاحي للحساب',auth.uid()); end if;
 return new;
end; $$;
drop trigger if exists sws_create_opening_movement on public.financial_accounts;
create trigger sws_create_opening_movement after insert on public.financial_accounts for each row execute function public.sws_create_opening_movement();

-- One internal cash ledger only; UI has no account/transfer management. Initial cash can be entered once before other movements.
insert into public.financial_accounts(name,account_type,is_system,opening_balance,opening_date,is_active,notes)
values('رصيد المكتب','خزنة نقدية',true,0,current_date,true,'حساب داخلي واحد للنقدية — لا يظهر كقسم مستقل في الواجهة')
on conflict do nothing;

drop function if exists public.sws_transfer_funds(uuid,uuid,numeric,date,text,text);

create or replace function public.sws_reverse_movement(p_movement_id uuid,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare m public.financial_movements%rowtype; peer public.financial_movements%rowtype; v_id uuid; v_peer_reversal uuid;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب العكس إلزامي'; end if;
 select * into m from public.financial_movements where id=p_movement_id for update;
 if not found then raise exception 'الحركة غير موجودة'; end if;
 if m.status<>'posted' then raise exception 'الحركة ليست معتمدة'; end if;
 if m.movement_type in ('transfer_out','transfer_in') then
   select * into peer from public.financial_movements where transfer_group=m.transfer_group and id<>m.id for update;
   if not found or peer.status<>'posted' then raise exception 'طرف التحويل الآخر غير متاح أو تم عكسه'; end if;
   update public.financial_movements set status='reversed' where id in (m.id,peer.id);
   insert into public.financial_movements(movement_type,account_id,reversal_of,transfer_group,movement_date,counterparty,amount,direction,reason,reference_number,notes,created_by)
   values('reversal',m.account_id,m.id,m.transfer_group,current_date,m.counterparty,m.amount,case when m.direction='credit' then 'debit' else 'credit' end,p_reason,m.receipt_no,'عكس التحويل '||m.receipt_no,auth.uid()) returning id into v_id;
   insert into public.financial_movements(movement_type,account_id,reversal_of,transfer_group,movement_date,counterparty,amount,direction,reason,reference_number,notes,created_by)
   values('reversal',peer.account_id,peer.id,peer.transfer_group,current_date,peer.counterparty,peer.amount,case when peer.direction='credit' then 'debit' else 'credit' end,p_reason,peer.receipt_no,'عكس التحويل '||peer.receipt_no,auth.uid()) returning id into v_peer_reversal;
 else
   update public.financial_movements set status='reversed' where id=m.id;
   insert into public.financial_movements(movement_type,account_id,traveler_id,payroll_id,category_id,reversal_of,movement_date,counterparty,amount,direction,payment_method,reason,reference_number,notes,created_by)
   values('reversal',m.account_id,m.traveler_id,m.payroll_id,m.category_id,m.id,current_date,m.counterparty,m.amount,case when m.direction='credit' then 'debit' else 'credit' end,m.payment_method,p_reason,m.receipt_no,'عكس الحركة '||m.receipt_no,auth.uid()) returning id into v_id;
 end if;
 if m.movement_type='payroll_payment' and m.payroll_id is not null then
   perform set_config('sws.allow_closed_payroll_correction','yes',true);
   update public.payroll_settlements set paid_amount=greatest(0,paid_amount-m.amount),status=case when greatest(0,paid_amount-m.amount)<=0 then 'unpaid' when greatest(0,paid_amount-m.amount)>=net_due then 'paid' else 'partial' end,updated_at=now(),updated_by=auth.uid() where id=m.payroll_id;
 end if;
 insert into public.audit_logs(actor_id,actor_email,action,entity_type,entity_id,details) values(auth.uid(),coalesce(auth.jwt()->>'email',''),'reverse','financial_movement',m.id::text,jsonb_build_object('reason',p_reason,'reversal_id',v_id));
 return v_id;
end; $$;
revoke all on function public.sws_reverse_movement(uuid,text) from public;
grant execute on function public.sws_reverse_movement(uuid,text) to authenticated;

create or replace function public.sws_correct_traveler_payment(p_movement_id uuid,p_new_amount numeric,p_new_date date,p_payment_method text,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare old_m public.financial_movements%rowtype; v_new uuid; v_reason text;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_new_amount<=0 then raise exception 'المبلغ يجب أن يكون أكبر من صفر'; end if;
 if length(trim(coalesce(p_payment_method,'')))=0 or length(trim(coalesce(p_reason,'')))=0 then raise exception 'طريقة الدفع وسبب التعديل مطلوبان'; end if;
 select * into old_m from public.financial_movements where id=p_movement_id for update;
 if not found or old_m.movement_type<>'traveler_collection' or old_m.status<>'posted' then raise exception 'الدفعة الأصلية غير متاحة للتعديل'; end if;
 v_reason := 'تصحيح دفعة: ' || trim(p_reason);
 perform public.sws_reverse_movement(p_movement_id,v_reason);
 insert into public.financial_movements(movement_type,account_id,traveler_id,movement_date,counterparty,amount,direction,payment_method,reason,reference_number,notes,created_by)
 values('traveler_collection',old_m.account_id,old_m.traveler_id,p_new_date,old_m.counterparty,p_new_amount,'credit',trim(p_payment_method),trim(p_reason),old_m.receipt_no,'دفعة بديلة بعد تصحيح حركة '||old_m.receipt_no,auth.uid()) returning id into v_new;
 insert into public.audit_logs(actor_id,actor_email,action,entity_type,entity_id,details) values(auth.uid(),coalesce(auth.jwt()->>'email',''),'correct','financial_movement',p_movement_id::text,jsonb_build_object('new_movement_id',v_new,'old_amount',old_m.amount,'new_amount',p_new_amount,'old_date',old_m.movement_date,'new_date',p_new_date,'reason',p_reason));
 return v_new;
end; $$;
revoke all on function public.sws_correct_traveler_payment(uuid,numeric,date,text,text) from public;
grant execute on function public.sws_correct_traveler_payment(uuid,numeric,date,text,text) to authenticated;


create or replace function public.sws_change_traveler_stage(p_traveler_id uuid,p_new_stage text,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_old text;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب تغيير المرحلة إلزامي'; end if;
 if p_new_stage not in ('قدم','كشف','تأشيرة','طيارة') then raise exception 'مرحلة غير صحيحة'; end if;
 select stage into v_old from public.travelers where id=p_traveler_id for update;
 if not found then raise exception 'ملف المسافر غير موجود'; end if;
 update public.travelers set stage=p_new_stage,updated_at=now(),updated_by=auth.uid(),version=version+1 where id=p_traveler_id;
 insert into public.traveler_stage_history(traveler_id,old_stage,new_stage,reason,changed_by) values(p_traveler_id,v_old,p_new_stage,trim(p_reason),auth.uid());
 return p_traveler_id;
end; $$;
revoke all on function public.sws_change_traveler_stage(uuid,text,text) from public;
grant execute on function public.sws_change_traveler_stage(uuid,text,text) to authenticated;

create or replace function public.sws_update_traveler_stages(
 p_traveler_id uuid, p_stage_submitted boolean, p_stage_check boolean, p_stage_visa boolean, p_stage_flight boolean, p_reason text
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare old_row public.travelers%rowtype; new_label text; old_label text;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب تغيير الحالة مطلوب'; end if;
 select * into old_row from public.travelers where id=p_traveler_id for update;
 if not found then raise exception 'ملف المسافر غير موجود'; end if;
 old_label := concat_ws('، ', case when old_row.stage_submitted then 'قدم' end, case when old_row.stage_check then 'كشف' end, case when old_row.stage_visa then 'تأشيرة' end, case when old_row.stage_flight then 'طيران' end);
 new_label := concat_ws('، ', case when p_stage_submitted then 'قدم' end, case when p_stage_check then 'كشف' end, case when p_stage_visa then 'تأشيرة' end, case when p_stage_flight then 'طيران' end);
 update public.travelers set stage_submitted=p_stage_submitted, stage_check=p_stage_check, stage_visa=p_stage_visa, stage_flight=p_stage_flight,
 stage=case when p_stage_flight then 'طيارة' when p_stage_visa then 'تأشيرة' when p_stage_check then 'كشف' else 'قدم' end,
 updated_at=now(), updated_by=auth.uid(), version=version+1 where id=p_traveler_id;
 insert into public.traveler_stage_history(traveler_id,old_stage,new_stage,reason,changed_by)
 values(p_traveler_id,coalesce(nullif(old_label,''),'لم تُحدد مرحلة'),coalesce(nullif(new_label,''),'لم تُحدد مرحلة'),trim(p_reason),auth.uid());
 return p_traveler_id;
end; $$;
revoke all on function public.sws_update_traveler_stages(uuid,boolean,boolean,boolean,boolean,text) from public;
grant execute on function public.sws_update_traveler_stages(uuid,boolean,boolean,boolean,boolean,text) to authenticated;


create or replace function public.sws_change_agreement_total(p_traveler_id uuid,p_new_amount numeric,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_old numeric;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_new_amount<0 then raise exception 'قيمة الاتفاق لا يمكن أن تكون سالبة'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب تعديل الاتفاق إلزامي'; end if;
 select agreement_total into v_old from public.travelers where id=p_traveler_id for update;
 if not found then raise exception 'ملف المسافر غير موجود'; end if;
 if v_old is distinct from p_new_amount then
  insert into public.traveler_agreement_history(traveler_id,old_amount,new_amount,reason,changed_by) values(p_traveler_id,v_old,p_new_amount,trim(p_reason),auth.uid());
  update public.travelers set agreement_total=p_new_amount,updated_at=now(),updated_by=auth.uid(),version=version+1 where id=p_traveler_id;
 end if;
 return p_traveler_id;
end; $$;
revoke all on function public.sws_change_agreement_total(uuid,numeric,text) from public;
grant execute on function public.sws_change_agreement_total(uuid,numeric,text) to authenticated;

create or replace function public.sws_pay_payroll(p_payroll_id uuid,p_account_id uuid,p_amount numeric,p_date date,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_row public.payroll_settlements%rowtype; v_movement uuid;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_amount<=0 then raise exception 'المبلغ يجب أن يكون أكبر من صفر'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب الصرف إلزامي'; end if;
 select * into v_row from public.payroll_settlements where id=p_payroll_id for update;
 if not found then raise exception 'تسوية المرتب غير موجودة'; end if;
 if p_amount>v_row.remaining_amount then raise exception 'المبلغ أكبر من المتبقي'; end if;
 insert into public.financial_movements(movement_type,account_id,payroll_id,movement_date,counterparty,amount,direction,reason,created_by)
 values('payroll_payment',p_account_id,p_payroll_id,p_date,v_row.employee_name,p_amount,'debit',trim(p_reason),auth.uid()) returning id into v_movement;
 update public.payroll_settlements set paid_amount=paid_amount+p_amount,status=case when paid_amount+p_amount>=net_due then 'paid' else 'partial' end,updated_at=now(),updated_by=auth.uid() where id=p_payroll_id;
 return v_movement;
end; $$;
revoke all on function public.sws_pay_payroll(uuid,uuid,numeric,date,text) from public;
grant execute on function public.sws_pay_payroll(uuid,uuid,numeric,date,text) to authenticated;

create or replace function public.sws_reopen_month(p_month date,p_reason text) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid; v_month date:=date_trunc('month',p_month)::date;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if length(trim(coalesce(p_reason,'')))=0 then raise exception 'سبب إعادة الفتح إلزامي'; end if;
 update public.period_closures set status='reopened',reopen_reason=trim(p_reason),reopened_by=auth.uid(),reopened_at=now() where month_start=v_month and status='closed' returning id into v_id;
 if v_id is null then raise exception 'الشهر غير مغلق'; end if;
 return v_id;
end; $$;
revoke all on function public.sws_reopen_month(date,text) from public;
grant execute on function public.sws_reopen_month(date,text) to authenticated;

create or replace function public.sws_close_month(p_month date,p_note text default '') returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_month date:=date_trunc('month',p_month)::date; v_id uuid; v_snapshot jsonb;
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if exists(select 1 from public.period_closures where month_start=v_month and status='closed') then raise exception 'الشهر مغلق بالفعل'; end if;
 select jsonb_build_object('movements',coalesce((select jsonb_agg(x) from (select movement_type,direction,sum(amount) amount from public.financial_movements where status='posted' and date_trunc('month',movement_date)::date=v_month group by movement_type,direction) x),'[]'::jsonb),
 'payroll',coalesce((select jsonb_agg(x) from (select employee_name,net_due,paid_amount,remaining_amount from public.payroll_settlements where month_start=v_month) x),'[]'::jsonb),
 'cash_balance',coalesce((select balance from public.account_balances where is_system=true limit 1),0)) into v_snapshot;
 insert into public.period_closures(month_start,snapshot,note,closed_by,closed_by_name,status,closed_at,reopen_reason,reopened_by,reopened_at) values(v_month,v_snapshot,coalesce(p_note,''),auth.uid(),coalesce(auth.jwt()->>'email',''),'closed',now(),' ',null,null) on conflict(month_start) do update set snapshot=excluded.snapshot,note=excluded.note,closed_by=excluded.closed_by,closed_by_name=excluded.closed_by_name,status='closed',closed_at=now(),reopen_reason='',reopened_by=null,reopened_at=null returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.sws_close_month(date,text) from public;
grant execute on function public.sws_close_month(date,text) to authenticated;

create or replace function public.sws_guard_closed_payroll() returns trigger language plpgsql security definer set search_path=public as $$
declare v_month date;
begin
 v_month:=case when tg_op='DELETE' then old.month_start else new.month_start end;
 if exists(select 1 from public.period_closures where month_start=v_month and status='closed') and coalesce(current_setting('sws.allow_closed_payroll_correction',true),'no') <> 'yes' then raise exception 'الشهر مغلق؛ لا يمكن تعديل تسوية المرتب مباشرة'; end if;
 if tg_op='DELETE' then return old; else return new; end if;
end; $$;
drop trigger if exists sws_guard_closed_payroll on public.payroll_settlements;
create trigger sws_guard_closed_payroll before insert or update or delete on public.payroll_settlements for each row execute function public.sws_guard_closed_payroll();

create or replace function public.sws_account_period_report(p_start date,p_end date) returns table(account_id uuid,account_name text,account_type text,opening_balance numeric,total_in numeric,total_out numeric,transfer_in numeric,transfer_out numeric,closing_balance numeric) language plpgsql stable security definer set search_path=public,auth as $$
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_end<p_start then raise exception 'تاريخ النهاية يجب ألا يسبق تاريخ البداية'; end if;
 return query
 select a.id,a.name,a.account_type,
 coalesce(sum(case when m.movement_date<p_start or (m.movement_date=p_start and m.movement_type='opening_balance') then case when m.direction='credit' then m.amount else -m.amount end else 0 end),0)::numeric(14,2) as opening_balance,
 coalesce(sum(case when m.movement_date between p_start and p_end and m.movement_type not in ('transfer_in','transfer_out') and not (m.movement_type='opening_balance' and m.movement_date=p_start) and m.direction='credit' then m.amount else 0 end),0)::numeric(14,2) as total_in,
 coalesce(sum(case when m.movement_date between p_start and p_end and m.movement_type not in ('transfer_in','transfer_out','opening_balance') and m.direction='debit' then m.amount else 0 end),0)::numeric(14,2) as total_out,
 coalesce(sum(case when m.movement_date between p_start and p_end and m.movement_type='transfer_in' then m.amount else 0 end),0)::numeric(14,2) as transfer_in,
 coalesce(sum(case when m.movement_date between p_start and p_end and m.movement_type='transfer_out' then m.amount else 0 end),0)::numeric(14,2) as transfer_out,
 coalesce(sum(case when m.movement_date<=p_end then case when m.direction='credit' then m.amount else -m.amount end else 0 end),0)::numeric(14,2) as closing_balance
 from public.financial_accounts a left join public.financial_movements m on m.account_id=a.id where a.is_system=true group by a.id,a.name,a.account_type order by a.name;
end; $$;
revoke all on function public.sws_account_period_report(date,date) from public;
grant execute on function public.sws_account_period_report(date,date) to authenticated;

create or replace function public.sws_financial_summary(p_start date,p_end date) returns table(movement_group text,total_credit numeric,total_debit numeric,net_amount numeric,movement_count bigint) language plpgsql stable security definer set search_path=public,auth as $$
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_end<p_start then raise exception 'تاريخ النهاية يجب ألا يسبق تاريخ البداية'; end if;
 return query
 select case coalesce(orig.movement_type,m.movement_type)
  when 'traveler_collection' then 'تحصيلات المسافرين' when 'general_revenue' then 'الإيرادات العامة' when 'expense' then 'المصروفات' when 'refund' then 'الاستردادات' when 'payroll_payment' then 'صرف الرواتب' when 'transfer_in' then 'تحويلات واردة' when 'transfer_out' then 'تحويلات صادرة' when 'opening_balance' then 'الأرصدة الافتتاحية' else 'تصحيحات / حركات أخرى' end,
 greatest(coalesce(sum(case when m.direction='credit' then m.amount else -m.amount end),0),0)::numeric(14,2),
 greatest(-coalesce(sum(case when m.direction='credit' then m.amount else -m.amount end),0),0)::numeric(14,2),
 coalesce(sum(case when m.direction='credit' then m.amount else -m.amount end),0)::numeric(14,2),count(*) filter (where m.movement_type<>'reversal' and m.status='posted')
 from public.financial_movements m left join public.financial_movements orig on orig.id=m.reversal_of
 where m.movement_date between p_start and p_end group by 1 order by 1;
end; $$;
revoke all on function public.sws_financial_summary(date,date) from public;
grant execute on function public.sws_financial_summary(date,date) to authenticated;

create or replace function public.sws_expense_summary(p_start date,p_end date) returns table(category_name text,recipient text,total_amount numeric,movement_count bigint) language plpgsql stable security definer set search_path=public,auth as $$
begin
 if not public.sws_is_admin() then raise exception 'Admin only'; end if;
 if p_end<p_start then raise exception 'تاريخ النهاية يجب ألا يسبق تاريخ البداية'; end if;
 return query
 select coalesce(ec.name,'بدون تصنيف'),m.counterparty,
 coalesce(sum(case when m.direction='debit' then m.amount else -m.amount end),0)::numeric(14,2),count(*) filter (where m.movement_type<>'reversal' and m.status='posted')
 from public.financial_movements m left join public.financial_movements orig on orig.id=m.reversal_of left join public.expense_categories ec on ec.id=coalesce(m.category_id,orig.category_id)
 where m.movement_date between p_start and p_end and coalesce(orig.movement_type,m.movement_type)='expense'
 group by ec.name,m.counterparty order by ec.name,m.counterparty;
end; $$;
revoke all on function public.sws_expense_summary(date,date) from public;
grant execute on function public.sws_expense_summary(date,date) to authenticated;

-- RLS: single active admin only. All table policies are explicit.
do $$ declare t text; begin
 foreach t in array array['profiles','company_settings','travelers','traveler_stage_history','traveler_agreement_history','financial_accounts','expense_categories','entities','payroll_settlements','period_closures','financial_movements','traveler_documents','audit_logs','sync_conflicts'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists sws_admin_all on public.%I',t);
  execute format('create policy sws_admin_all on public.%I for all to authenticated using (public.sws_is_admin()) with check (public.sws_is_admin())',t);
 end loop;
end $$;
grant select,insert,update on public.profiles,public.company_settings,public.travelers,public.traveler_stage_history,public.traveler_agreement_history,public.financial_accounts,public.expense_categories,public.entities,public.payroll_settlements,public.period_closures,public.financial_movements,public.traveler_documents,public.audit_logs,public.sync_conflicts to authenticated;
grant select on public.account_balances,public.traveler_financial_summary to authenticated;
grant usage,select on all sequences in schema public to authenticated;

-- Private document bucket. Uploads/downloads are restricted to the authenticated admin.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('sws-private-documents','sws-private-documents',false,52428800,array['image/jpeg','image/png','application/pdf','image/webp']) on conflict(id) do update set public=false,file_size_limit=52428800;
drop policy if exists sws_private_documents_admin_select on storage.objects;
drop policy if exists sws_private_documents_admin_insert on storage.objects;
drop policy if exists sws_private_documents_admin_update on storage.objects;
drop policy if exists sws_private_documents_admin_delete on storage.objects;
create policy sws_private_documents_admin_select on storage.objects for select to authenticated using(bucket_id='sws-private-documents' and public.sws_is_admin());
create policy sws_private_documents_admin_insert on storage.objects for insert to authenticated with check(bucket_id='sws-private-documents' and public.sws_is_admin());
create policy sws_private_documents_admin_update on storage.objects for update to authenticated using(bucket_id='sws-private-documents' and public.sws_is_admin()) with check(bucket_id='sws-private-documents' and public.sws_is_admin());
create policy sws_private_documents_admin_delete on storage.objects for delete to authenticated using(bucket_id='sws-private-documents' and public.sws_is_admin());

-- Audit triggers for core mutable records.
do $$ declare t text; begin
 foreach t in array array['travelers','financial_accounts','expense_categories','entities','payroll_settlements','period_closures','traveler_documents','company_settings','financial_movements','sync_conflicts'] loop
  execute format('drop trigger if exists sws_audit_change on public.%I',t);
  execute format('create trigger sws_audit_change after insert or update or delete on public.%I for each row execute function public.sws_log_change()',t);
 end loop;
end $$;
