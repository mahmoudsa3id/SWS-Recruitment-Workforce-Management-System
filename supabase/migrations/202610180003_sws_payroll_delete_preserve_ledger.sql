-- SWS: allow deleting a payroll record even when it has payment history.
-- Financial movements are NEVER deleted; they are detached from the deleted payroll row.
-- Deletion is blocked if either the payroll month or any linked payment month is closed.
-- Run this additive migration only after the existing SWS migrations.
begin;

create or replace function public.sws_delete_payroll_record(
  p_payroll_id uuid,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.payroll_records%rowtype;
  linked_movements jsonb;
  payroll_month date;
begin
  perform public.sws_require_admin();

  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'Deletion reason is required';
  end if;

  select * into r
  from public.payroll_records
  where id = p_payroll_id
  for update;

  if not found then
    raise exception 'Payroll record not found';
  end if;

  payroll_month := date_trunc('month', r.month_start)::date;

  if exists (
    select 1
    from public.monthly_closings c
    where c.month_start = payroll_month
      and c.status = 'closed'
  ) then
    raise exception 'Accounting month is closed; reopen it before deleting this payroll record';
  end if;

  -- A payroll record may have payments recorded in a different month.
  -- Do not alter the linkage of a locked month's financial report.
  if exists (
    select 1
    from public.financial_movements fm
    join public.monthly_closings c
      on c.month_start = date_trunc('month', fm.created_at at time zone 'Africa/Cairo')::date
     and c.status = 'closed'
    where fm.payroll_record_id = r.id
  ) then
    raise exception 'A linked payroll payment belongs to a closed month; reopen that month first';
  end if;

  select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at, fm.id), '[]'::jsonb)
    into linked_movements
  from public.financial_movements fm
  where fm.payroll_record_id = r.id;

  -- Keep all cash-ledger entries and reversal history. Only remove the FK link.
  update public.financial_movements
     set payroll_record_id = null
   where payroll_record_id = r.id;

  delete from public.payroll_records where id = r.id;

  insert into public.audit_log(
    actor_id, action, entity_type, entity_id, before_data, reason
  ) values (
    auth.uid(),
    'payroll_record_deleted',
    'payroll_record',
    r.id::text,
    jsonb_build_object(
      'payroll_record', to_jsonb(r),
      'linked_financial_movements', linked_movements
    ),
    trim(p_reason)
  );
end;
$$;

revoke all on function public.sws_delete_payroll_record(uuid, text) from public;
grant execute on function public.sws_delete_payroll_record(uuid, text) to authenticated;

commit;
