-- HR can see traveler financial details and submit requests; only admins can post financial movements.
-- Additive and data-preserving: no existing tables or rows are dropped.
begin;

-- Permit HR to read only ledger movements tied to travelers, never general finance/payroll movements.
drop policy if exists sws_hr_traveler_movements_read on public.financial_movements;
create policy sws_hr_traveler_movements_read
on public.financial_movements for select to authenticated
using (
  public.sws_is_active_hr_or_admin()
  and traveler_id is not null
  and movement_type in ('traveler_collection','reversal','correction')
);

-- Expose the real agreement and paid totals in the existing monthly traveler list for HR.
create or replace function public.sws_list_travelers(
  p_search text default null,
  p_limit integer default 500,
  p_offset integer default 0,
  p_month_start date default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; m date; n date;
begin
  perform public.sws_require_hr_or_admin();
  if p_month_start is not null then
    m:=date_trunc('month',p_month_start)::date;
    n:=(m+interval '1 month')::date;
  end if;
  select coalesce(jsonb_agg(to_jsonb(rows) order by rows.created_at desc),'[]'::jsonb)
    into result
  from (
    select t.id,t.file_no,t.full_name,t.phone,t.agreement_total,t.sales_person,t.destination_country,
      t.stage_submitted,t.stage_inspected,t.stage_visa,t.stage_flight,
      t.avatar_path,t.ticket_booking_type,t.ticket_booking_note,
      t.created_at,t.updated_at,t.created_by,
      coalesce(p.paid_amount,0)::numeric(14,2) as paid_amount
    from public.travelers t
    left join lateral (
      select coalesce(sum(case when fm.direction='credit' then fm.amount else -fm.amount end),0) paid_amount
      from public.financial_movements fm
      where fm.traveler_id=t.id
        and fm.movement_type in ('traveler_collection','reversal','correction')
        and fm.status in ('posted','reversed')
    ) p on true
    where t.archived_at is null
      and (p_month_start is null or (t.created_at >= (m::timestamp at time zone 'Africa/Cairo') and t.created_at < (n::timestamp at time zone 'Africa/Cairo')))
      and (nullif(trim(coalesce(p_search,'')),'') is null
        or t.full_name ilike '%'||trim(p_search)||'%'
        or t.phone ilike '%'||trim(p_search)||'%'
        or coalesce(t.file_no,'') ilike '%'||trim(p_search)||'%')
    order by t.created_at desc
    limit greatest(1,least(coalesce(p_limit,500),1000))
    offset greatest(coalesce(p_offset,0),0)
  ) rows;
  return result;
end $$;

-- HR can calculate a traveler's paid total; the function reveals only the requested traveler's total.
create or replace function public.sws_get_traveler_paid_total(p_traveler_id uuid)
returns numeric language plpgsql security definer set search_path=public,pg_temp as $$
declare result numeric;
begin
  perform public.sws_require_hr_or_admin();
  if not exists(select 1 from public.travelers where id=p_traveler_id and archived_at is null) then
    raise exception 'Traveler not found';
  end if;
  select coalesce(sum(case when direction='credit' then amount else -amount end),0) into result
  from public.financial_movements
  where traveler_id=p_traveler_id
    and movement_type in ('traveler_collection','reversal','correction')
    and status in ('posted','reversed');
  return result;
end $$;

-- Ticket booking is part of traveler workflow; HR may update it but not finance.
create or replace function public.sws_set_traveler_ticket_booking(
  p_traveler_id uuid, p_booking_type text, p_note text default null
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype;
begin
  perform public.sws_require_hr_or_admin();
  if p_booking_type is not null and p_booking_type not in ('company','external') then raise exception 'Invalid ticket booking type'; end if;
  if p_booking_type='company' and coalesce(trim(p_note),'')='' then raise exception 'A booking note is required when the company books the ticket'; end if;
  select * into old_row from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  update public.travelers set ticket_booking_type=p_booking_type,
    ticket_booking_note=case when p_booking_type='company' then nullif(trim(coalesce(p_note,'')),'') else null end,
    updated_at=now() where id=p_traveler_id returning * into new_row;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'traveler_ticket_booking_updated','traveler',p_traveler_id::text,to_jsonb(old_row),to_jsonb(new_row));
  return p_traveler_id;
end $$;

create table if not exists public.financial_operation_requests (
  id uuid primary key default gen_random_uuid(),
  traveler_id uuid not null references public.travelers(id),
  request_type text not null check (request_type in ('traveler_payment')),
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null check (payment_method in ('cash','instapay','bank_transfer','wallet','other')),
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  movement_id uuid references public.financial_movements(id)
);
create index if not exists idx_financial_requests_status_created on public.financial_operation_requests(status,created_at desc);
create index if not exists idx_financial_requests_traveler on public.financial_operation_requests(traveler_id,created_at desc);
alter table public.financial_operation_requests enable row level security;
revoke all on public.financial_operation_requests from anon, authenticated;

create or replace function public.sws_create_financial_request(
  p_traveler_id uuid, p_request_type text, p_amount numeric,
  p_payment_method text default 'cash', p_note text default null
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  perform public.sws_require_hr_or_admin();
  if p_request_type <> 'traveler_payment' then raise exception 'Unsupported financial request type'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','instapay','bank_transfer','wallet','other') then raise exception 'Invalid payment method'; end if;
  if not exists(select 1 from public.travelers where id=p_traveler_id and archived_at is null) then raise exception 'Traveler not found'; end if;
  insert into public.financial_operation_requests(traveler_id,request_type,amount,payment_method,note,requested_by)
    values(p_traveler_id,p_request_type,p_amount,p_payment_method,nullif(trim(coalesce(p_note,'')),''),auth.uid()) returning id into v_id;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,after_data)
    values(auth.uid(),'financial_operation_requested','financial_operation_request',v_id::text,
      jsonb_build_object('traveler_id',p_traveler_id,'request_type',p_request_type,'amount',p_amount,'payment_method',p_payment_method));
  return v_id;
end $$;

create or replace function public.sws_list_financial_requests()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  perform public.sws_require_admin();
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb) into result
  from (
    select q.id,q.traveler_id,q.request_type,q.amount,q.payment_method,q.note,q.status,q.created_at,
      q.requested_by,q.reviewed_by,q.reviewed_at,q.review_note,q.movement_id,
      t.full_name as traveler_name,t.file_no,
      coalesce(p.full_name,p.email,'موظف') as requester_name,
      rp.full_name as reviewer_name
    from public.financial_operation_requests q
    join public.travelers t on t.id=q.traveler_id
    left join public.profiles p on p.user_id=q.requested_by
    left join public.profiles rp on rp.user_id=q.reviewed_by
  ) r;
  return result;
end $$;

create or replace function public.sws_review_financial_request(
  p_request_id uuid, p_decision text, p_review_note text default null
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare q public.financial_operation_requests%rowtype; v_movement uuid;
begin
  perform public.sws_require_admin();
  if p_decision not in ('approve','reject') then raise exception 'Invalid decision'; end if;
  select * into q from public.financial_operation_requests where id=p_request_id for update;
  if not found then raise exception 'Financial request not found'; end if;
  if q.status <> 'pending' then raise exception 'This request has already been reviewed'; end if;
  if p_decision='approve' then
    v_movement := public.sws_record_traveler_payment(q.traveler_id,q.amount,q.payment_method,
      concat_ws(' | ',nullif(q.note,''),'طلب مالي معتمد: '||q.id::text),gen_random_uuid());
    update public.financial_operation_requests set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),
      review_note=nullif(trim(coalesce(p_review_note,'')),''),movement_id=v_movement where id=q.id;
  else
    update public.financial_operation_requests set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),
      review_note=nullif(trim(coalesce(p_review_note,'')),'') where id=q.id;
  end if;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data,reason)
    values(auth.uid(),case when p_decision='approve' then 'financial_operation_approved' else 'financial_operation_rejected' end,
      'financial_operation_request',q.id::text,to_jsonb(q),jsonb_build_object('decision',p_decision,'movement_id',v_movement),nullif(trim(coalesce(p_review_note,'')),''));
  return q.id;
end $$;

revoke all on function public.sws_list_travelers(text,integer,integer,date) from public, anon;
revoke all on function public.sws_get_traveler_paid_total(uuid) from public, anon;
revoke all on function public.sws_set_traveler_ticket_booking(uuid,text,text) from public, anon;
revoke all on function public.sws_create_financial_request(uuid,text,numeric,text,text) from public, anon;
revoke all on function public.sws_list_financial_requests() from public, anon;
revoke all on function public.sws_review_financial_request(uuid,text,text) from public, anon;
grant execute on function public.sws_list_travelers(text,integer,integer,date) to authenticated;
grant execute on function public.sws_get_traveler_paid_total(uuid) to authenticated;
grant execute on function public.sws_set_traveler_ticket_booking(uuid,text,text) to authenticated;
grant execute on function public.sws_create_financial_request(uuid,text,numeric,text,text) to authenticated;
grant execute on function public.sws_list_financial_requests() to authenticated;
grant execute on function public.sws_review_financial_request(uuid,text,text) to authenticated;
commit;
