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
