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
create policy sws_private_documents_read on storage.objects for select to authenticated using(bucket_id='sws-private-documents' and public.sws_is_active_admin());
create policy sws_private_documents_insert on storage.objects for insert to authenticated with check(bucket_id='sws-private-documents' and public.sws_is_active_admin());
create policy sws_private_documents_update on storage.objects for update to authenticated using(bucket_id='sws-private-documents' and public.sws_is_active_admin()) with check(bucket_id='sws-private-documents' and public.sws_is_active_admin());
commit;
