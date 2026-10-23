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
   select m.id
   union
   select case when fm.id=related.id then fm.reverses_movement_id else fm.id end
   from public.financial_movements fm
   join related on fm.id=related.id or fm.reverses_movement_id=related.id
   where case when fm.id=related.id then fm.reverses_movement_id else fm.id end is not null
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
