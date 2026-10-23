-- Safe additive update for SWS traveler workflow/profile fields.
-- Does not delete, rewrite, or reset existing traveler or financial data.
begin;

alter table public.travelers add column if not exists avatar_path text;
alter table public.travelers add column if not exists ticket_booking_type text;
alter table public.travelers add column if not exists ticket_booking_note text;

-- Constrain only the new optional value; existing rows remain NULL and untouched.
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'travelers_ticket_booking_type_check'
      and conrelid = 'public.travelers'::regclass
  ) then
    alter table public.travelers add constraint travelers_ticket_booking_type_check
      check (ticket_booking_type is null or ticket_booking_type in ('company','external'));
  end if;
end $$;

create or replace function public.sws_set_traveler_ticket_booking(
  p_traveler_id uuid,
  p_booking_type text,
  p_note text default null
) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype;
begin
  perform public.sws_require_admin();
  if p_booking_type is not null and p_booking_type not in ('company','external') then
    raise exception 'Invalid ticket booking type';
  end if;
  if p_booking_type = 'company' and coalesce(trim(p_note),'') = '' then
    raise exception 'A booking note is required when the company books the ticket';
  end if;
  select * into old_row from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  update public.travelers
    set ticket_booking_type=p_booking_type,
        ticket_booking_note=case when p_booking_type='company' then nullif(trim(coalesce(p_note,'')),'') else null end,
        updated_at=now()
    where id=p_traveler_id returning * into new_row;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'traveler_ticket_booking_updated','traveler',p_traveler_id::text,to_jsonb(old_row),to_jsonb(new_row));
  return p_traveler_id;
end $$;

create or replace function public.sws_set_traveler_avatar(
  p_traveler_id uuid,
  p_avatar_path text
) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype;
begin
  perform public.sws_require_admin();
  if p_avatar_path is null or p_avatar_path !~ ('^traveler-avatars/'||p_traveler_id::text||'/[^/]+$') then
    raise exception 'Invalid traveler avatar path';
  end if;
  select * into old_row from public.travelers where id=p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;
  update public.travelers set avatar_path=p_avatar_path,updated_at=now()
    where id=p_traveler_id returning * into new_row;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
    values(auth.uid(),'traveler_avatar_updated','traveler',p_traveler_id::text,to_jsonb(old_row),to_jsonb(new_row));
  return p_traveler_id;
end $$;

-- Preserve the existing RPC signature used by the app; expose only the new profile fields.
create or replace function public.sws_list_travelers(
  p_search text default null,
  p_limit integer default 500,
  p_offset integer default 0,
  p_month_start date default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; m date; n date;
begin
  perform public.sws_require_admin();
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
        and fm.movement_type in ('traveler_collection','reversal')
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

revoke all on function public.sws_set_traveler_ticket_booking(uuid,text,text) from public;
revoke all on function public.sws_set_traveler_avatar(uuid,text) from public;
revoke all on function public.sws_list_travelers(text,integer,integer,date) from public;
grant execute on function public.sws_set_traveler_ticket_booking(uuid,text,text) to authenticated;
grant execute on function public.sws_set_traveler_avatar(uuid,text) to authenticated;
grant execute on function public.sws_list_travelers(text,integer,integer,date) to authenticated;

commit;
