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
