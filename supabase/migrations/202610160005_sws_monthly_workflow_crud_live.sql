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
