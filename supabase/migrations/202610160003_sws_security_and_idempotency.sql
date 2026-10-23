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
create policy sws_documents_admin_read on public.traveler_documents for select to authenticated using (public.sws_is_active_admin());
create policy sws_documents_admin_insert on public.traveler_documents for insert to authenticated with check (public.sws_is_active_admin());
create policy sws_private_documents_delete on storage.objects for delete to authenticated using (bucket_id='sws-private-documents' and public.sws_is_active_admin());

create policy sws_travelers_admin_read on public.travelers for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.financial_movements;
create policy sws_movements_admin_read on public.financial_movements for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.office_expenses;
create policy sws_expenses_admin_read on public.office_expenses for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.payroll_records;
create policy sws_payroll_admin_read on public.payroll_records for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.monthly_closings;
create policy sws_monthly_closings_admin_read on public.monthly_closings for select to authenticated using (public.sws_is_active_admin());

drop policy if exists sws_admin_all on public.audit_log;
create policy sws_audit_admin_read on public.audit_log for select to authenticated using (public.sws_is_active_admin());

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
