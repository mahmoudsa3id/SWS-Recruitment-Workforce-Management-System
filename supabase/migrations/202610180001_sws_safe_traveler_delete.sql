-- SWS safe traveler deletion for an EXISTING database.
-- Adds only a cleanup queue and RPC functions; it does not reset or rewrite existing records.
-- Apply only after reviewing this migration. Storage object deletion is performed by the app via Storage API.
begin;

create table if not exists public.sws_storage_cleanup_queue (
  storage_path text primary key,
  traveler_id text not null,
  queued_at timestamptz not null default now(),
  last_error text
);

alter table public.sws_storage_cleanup_queue enable row level security;
revoke all on public.sws_storage_cleanup_queue from anon, authenticated, public;

create or replace function public.sws_delete_traveler(
  p_traveler_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t public.travelers%rowtype;
  v_paths text[] := array[]::text[];
  v_movement_ids uuid[] := array[]::uuid[];
  v_movements jsonb := '[]'::jsonb;
  v_documents jsonb := '[]'::jsonb;
  v_expense_count integer := 0;
begin
  perform public.sws_require_admin();
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'Deletion reason is required';
  end if;

  select * into t from public.travelers where id = p_traveler_id for update;
  if not found then raise exception 'Traveler not found'; end if;

  select coalesce(array_agg(d.storage_path), array[]::text[]),
         coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
    into v_paths, v_documents
  from public.traveler_documents d
  where d.traveler_id = t.id;

  -- Include all reversals that point to a traveler movement, including reversal chains.
  with recursive related(id) as (
    select fm.id from public.financial_movements fm where fm.traveler_id = t.id
    union
    select child.id
    from public.financial_movements child
    join related parent on child.reverses_movement_id = parent.id
  )
  select coalesce(array_agg(id), array[]::uuid[])
    into v_movement_ids from related;

  if cardinality(v_movement_ids) > 0 then
    if exists (
      select 1
      from public.financial_movements fm
      join public.monthly_closings mc
        on mc.month_start = date_trunc('month', fm.created_at at time zone 'Africa/Cairo')::date
       and mc.status = 'closed'
      where fm.id = any(v_movement_ids)
    ) then
      raise exception 'Traveler has financial movements in a closed month. Reopen the month with a reason first.';
    end if;

    select count(*) into v_expense_count
    from public.office_expenses oe
    where oe.movement_id = any(v_movement_ids);
    if v_expense_count > 0 then
      raise exception 'A linked movement is referenced by an office expense; deletion stopped to protect accounting links.';
    end if;

    if exists (
      select 1 from public.financial_movements fm
      where fm.id = any(v_movement_ids)
        and (fm.movement_type not in ('traveler_collection', 'reversal') or fm.payroll_record_id is not null)
    ) then
      raise exception 'Unexpected financial relationship found; deletion stopped to protect payroll or other accounting records.';
    end if;

    select coalesce(jsonb_agg(to_jsonb(fm) order by fm.created_at), '[]'::jsonb)
      into v_movements
    from public.financial_movements fm
    where fm.id = any(v_movement_ids);
  end if;

  -- Preserve an audit snapshot before removing the traveler and linked financial records.
  insert into public.audit_log(actor_id, action, entity_type, entity_id, before_data, after_data, reason)
  values (
    auth.uid(), 'traveler_permanently_deleted', 'traveler', t.id::text,
    jsonb_build_object('traveler', to_jsonb(t), 'documents', v_documents, 'financial_movements', v_movements),
    jsonb_build_object('deleted', true, 'movement_count', cardinality(v_movement_ids), 'document_count', cardinality(v_paths), 'storage_cleanup_pending', cardinality(v_paths)),
    trim(p_reason)
  );

  -- Queue private Storage paths durably; SQL cannot delete Storage objects transactionally.
  insert into public.sws_storage_cleanup_queue(storage_path, traveler_id)
  select path, t.id::text from unnest(v_paths) as u(path)
  on conflict (storage_path) do update
    set traveler_id = excluded.traveler_id, queued_at = now(), last_error = null;

  -- Break self-references within the set, then remove the linked movements.
  if cardinality(v_movement_ids) > 0 then
    update public.financial_movements
       set reverses_movement_id = null
     where id = any(v_movement_ids);
    delete from public.financial_movements where id = any(v_movement_ids);
  end if;

  -- traveler_documents rows are removed by the existing ON DELETE CASCADE relationship.
  delete from public.travelers where id = t.id;

  return jsonb_build_object(
    'traveler_id', t.id,
    'storage_paths', to_jsonb(v_paths),
    'deleted_movement_count', cardinality(v_movement_ids),
    'deleted_document_count', cardinality(v_paths)
  );
end;
$$;

create or replace function public.sws_list_pending_storage_cleanup()
returns text[]
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.sws_require_admin();
  return coalesce((select array_agg(storage_path order by queued_at) from public.sws_storage_cleanup_queue), array[]::text[]);
end;
$$;

create or replace function public.sws_ack_storage_cleanup(p_storage_paths text[])
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  perform public.sws_require_admin();
  if p_storage_paths is null or cardinality(p_storage_paths) = 0 then return 0; end if;
  delete from public.sws_storage_cleanup_queue where storage_path = any(p_storage_paths);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.sws_delete_traveler(uuid, text) from public, anon;
revoke all on function public.sws_list_pending_storage_cleanup() from public, anon;
revoke all on function public.sws_ack_storage_cleanup(text[]) from public, anon;
grant execute on function public.sws_delete_traveler(uuid, text) to authenticated;
grant execute on function public.sws_list_pending_storage_cleanup() to authenticated;
grant execute on function public.sws_ack_storage_cleanup(text[]) to authenticated;

commit;
