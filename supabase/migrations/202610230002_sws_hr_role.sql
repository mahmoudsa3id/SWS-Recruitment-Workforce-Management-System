-- SWS HR role: traveler workflow and document upload only. Additive migration; preserves all existing rows.
begin;

do $$ declare c record; begin
  for c in select conname from pg_constraint where conrelid='public.profiles'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%role%' loop
    execute format('alter table public.profiles drop constraint %I',c.conname);
  end loop;
end $$;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','hr'));

create or replace function public.sws_is_active_hr_or_admin() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.role in ('admin','hr') and p.is_active)
$$;
revoke all on function public.sws_is_active_hr_or_admin() from public;
grant execute on function public.sws_is_active_hr_or_admin() to authenticated;

create or replace function public.sws_require_hr_or_admin() returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.sws_is_active_hr_or_admin() then raise exception 'HR or admin access required'; end if;
end $$;
revoke all on function public.sws_require_hr_or_admin() from public;
grant execute on function public.sws_require_hr_or_admin() to authenticated;

-- HR can read traveler records and traveler documents, but cannot access finance/payroll tables.
drop policy if exists sws_travelers_admin_read on public.travelers;
drop policy if exists sws_travelers_hr_admin_read on public.travelers;
create policy sws_travelers_hr_admin_read on public.travelers for select to authenticated using (public.sws_is_active_hr_or_admin());
drop policy if exists sws_documents_admin_read on public.traveler_documents;
drop policy if exists sws_documents_admin_insert on public.traveler_documents;
drop policy if exists sws_documents_hr_admin_read on public.traveler_documents;
drop policy if exists sws_documents_hr_admin_insert on public.traveler_documents;
create policy sws_documents_hr_admin_read on public.traveler_documents for select to authenticated using (public.sws_is_active_hr_or_admin());
create policy sws_documents_hr_admin_insert on public.traveler_documents for insert to authenticated with check (public.sws_is_active_hr_or_admin() and created_by=auth.uid());

-- Storage: HR may read existing private traveler files and upload new documents, but cannot delete/overwrite files or upload traveler avatars.
drop policy if exists sws_private_documents_read on storage.objects;
drop policy if exists sws_private_documents_insert on storage.objects;
drop policy if exists sws_private_documents_update on storage.objects;
drop policy if exists sws_private_documents_delete on storage.objects;
create policy sws_private_documents_read on storage.objects for select to authenticated
 using(bucket_id='sws-private-documents' and public.sws_is_active_hr_or_admin());
create policy sws_private_documents_insert on storage.objects for insert to authenticated
 with check(bucket_id='sws-private-documents' and public.sws_is_active_hr_or_admin() and (public.sws_is_active_admin() or (name not like 'traveler-avatars/%' and name ~ '^[0-9a-fA-F-]{36}/[^/]+$')));
create policy sws_private_documents_update on storage.objects for update to authenticated
 using(bucket_id='sws-private-documents' and public.sws_is_active_admin()) with check(bucket_id='sws-private-documents' and public.sws_is_active_admin());
create policy sws_private_documents_delete on storage.objects for delete to authenticated
 using(bucket_id='sws-private-documents' and public.sws_is_active_admin());

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
    select t.id,t.file_no,t.full_name,t.phone,case when public.sws_is_active_admin() then t.agreement_total else 0 end as agreement_total,t.sales_person,t.destination_country,
      t.stage_submitted,t.stage_inspected,t.stage_visa,t.stage_flight,
      t.avatar_path,t.ticket_booking_type,t.ticket_booking_note,
      t.created_at,t.updated_at,t.created_by,
      case when public.sws_is_active_admin() then coalesce(p.paid_amount,0)::numeric(14,2) else 0::numeric(14,2) end as paid_amount
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

create or replace function public.sws_set_traveler_stage(p_traveler_id uuid,p_stage text,p_value boolean)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare old_row public.travelers%rowtype; new_row public.travelers%rowtype;
begin
  perform public.sws_require_hr_or_admin();
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

revoke all on function public.sws_list_travelers(text,integer,integer,date) from public;
revoke all on function public.sws_set_traveler_stage(uuid,text,boolean) from public;
revoke all on function public.sws_set_traveler_ticket_booking(uuid,text,text) from public;
grant execute on function public.sws_list_travelers(text,integer,integer,date) to authenticated;
grant execute on function public.sws_set_traveler_stage(uuid,text,boolean) to authenticated;
grant execute on function public.sws_set_traveler_ticket_booking(uuid,text,text) to authenticated;
commit;
