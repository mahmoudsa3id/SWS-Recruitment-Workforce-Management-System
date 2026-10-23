-- SWS dashboard analytics: safe additive update.
-- Adds aggregate traveler balances and chart series to the existing monthly dashboard RPC.
-- Does not alter or delete business records.
begin;

create or replace function public.sws_get_monthly_dashboard_summary(p_month_start date)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m date := date_trunc('month', p_month_start)::date;
  n date;
  result jsonb;
begin
  perform public.sws_require_admin();
  n := (m + interval '1 month')::date;

  select jsonb_build_object(
    -- Existing month-scoped KPIs retained for compatibility.
    'traveler_count', (
      select count(*) from public.travelers t
      where t.archived_at is null
        and t.created_at >= (m::timestamp at time zone 'Africa/Cairo')
        and t.created_at < (n::timestamp at time zone 'Africa/Cairo')
    ),
    'employee_count', (
      select count(*) from public.payroll_records p where p.month_start = m
    ),
    'total_collections', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'traveler_collection'
        and fm.direction = 'credit'
    ), 0),
    'general_revenue', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'general_revenue'
        and fm.direction = 'credit'
    ), 0),
    'office_expenses', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'office_expense'
        and fm.direction = 'debit'
    ), 0),
    'payroll_paid', coalesce(sum(fm.amount) filter (
      where fm.status = 'posted'
        and fm.movement_type = 'payroll_payment'
        and fm.direction = 'debit'
    ), 0),
    'cash_balance', (
      select coalesce(sum(case when direction = 'credit' then amount else -amount end), 0)
      from public.financial_movements
      where status in ('posted', 'reversed')
        and created_at < (n::timestamp at time zone 'Africa/Cairo')
    ),

    -- All-time current outstanding for active (not archived) travelers.
    'total_travelers_count', (
      select count(*) from public.travelers t where t.archived_at is null
    ),
    'traveler_agreement_total', (
      select coalesce(sum(t.agreement_total), 0)
      from public.travelers t where t.archived_at is null
    ),
    'traveler_paid_total', (
      select coalesce(sum(p.paid), 0)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
    ),
    'traveler_remaining_total', (
      select coalesce(sum(greatest(t.agreement_total - coalesce(p.paid, 0), 0)), 0)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
    ),
    'travelers_fully_paid', (
      select count(*)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
        and greatest(t.agreement_total - coalesce(p.paid, 0), 0) <= 0
    ),
    'travelers_with_balance', (
      select count(*)
      from public.travelers t
      left join lateral (
        select coalesce(sum(f.amount), 0) as paid
        from public.financial_movements f
        where f.traveler_id = t.id
          and f.movement_type = 'traveler_collection'
          and f.direction = 'credit'
          and f.status = 'posted'
      ) p on true
      where t.archived_at is null
        and greatest(t.agreement_total - coalesce(p.paid, 0), 0) > 0
    ),
    'traveler_stages', (
      select jsonb_build_object(
        'new', count(*) filter (where not t.stage_submitted and not t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'submitted', count(*) filter (where t.stage_submitted and not t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'inspected', count(*) filter (where t.stage_inspected and not t.stage_visa and not t.stage_flight),
        'visa', count(*) filter (where t.stage_visa and not t.stage_flight),
        'flight', count(*) filter (where t.stage_flight)
      )
      from public.travelers t where t.archived_at is null
    ),
    'monthly_trend', (
      select coalesce(jsonb_agg(to_jsonb(trend) order by trend.month_start), '[]'::jsonb)
      from (
        select
          gs.month_start::date as month_start,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'traveler_collection'
              and f.direction = 'credit'
          ), 0) as collections,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'general_revenue'
              and f.direction = 'credit'
          ), 0) as general_revenue,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'office_expense'
              and f.direction = 'debit'
          ), 0) as office_expenses,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted'
              and f.movement_type = 'payroll_payment'
              and f.direction = 'debit'
          ), 0) as payroll_paid,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted' and f.direction = 'credit'
          ), 0) as total_credits,
          coalesce(sum(f.amount) filter (
            where f.status = 'posted' and f.direction = 'debit'
          ), 0) as total_debits
        from generate_series(m - interval '5 months', m, interval '1 month') as gs(month_start)
        left join public.financial_movements f
          on f.created_at >= (gs.month_start::date::timestamp at time zone 'Africa/Cairo')
         and f.created_at < ((gs.month_start::date + interval '1 month')::timestamp at time zone 'Africa/Cairo')
         and f.status in ('posted', 'reversed')
        group by gs.month_start
      ) trend
    )
  ) into result
  from public.financial_movements fm
  where fm.status in ('posted', 'reversed')
    and fm.created_at >= (m::timestamp at time zone 'Africa/Cairo')
    and fm.created_at < (n::timestamp at time zone 'Africa/Cairo');

  return coalesce(result, '{}'::jsonb);
end;
$$;

revoke all on function public.sws_get_monthly_dashboard_summary(date) from public;
grant execute on function public.sws_get_monthly_dashboard_summary(date) to authenticated;

commit;
