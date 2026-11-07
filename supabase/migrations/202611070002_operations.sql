-- Operaciones seguras propuestas. Sin proyecto Supabase para ejecutarlas o probarlas todavía.

insert into storage.buckets (id, name, public)
values ('identity-documents', 'identity-documents', false),
       ('listing-photos', 'listing-photos', false)
on conflict (id) do nothing;

create policy identity_upload_own on storage.objects for insert to authenticated
with check (bucket_id = 'identity-documents' and name like auth.uid()::text || '/%');
create policy listing_photo_upload_own on storage.objects for insert to authenticated
with check (bucket_id = 'listing-photos' and name like auth.uid()::text || '/%');
create policy listing_photo_read_community on storage.objects for select to authenticated
using (bucket_id = 'listing-photos' and exists (
  select 1 from public.listings l where l.photo_storage_path = name
  and l.community_id = public.my_community_id() and l.status = 'ACTIVO'));

create or replace function public.complete_registration(
  p_display_name text, p_community_id uuid, p_doc_type text,
  p_doc_number text, p_photo_path text
) returns uuid language plpgsql security definer
set search_path = public, private, storage, pg_temp as $$
declare v_user uuid := auth.uid(); v_number text;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  if exists(select 1 from public.profiles where id = v_user) then raise exception 'PROFILE_EXISTS'; end if;
  if not exists(select 1 from public.communities where id = p_community_id) then raise exception 'COMMUNITY_NOT_FOUND'; end if;
  if p_doc_type not in ('DNI','CE','PASAPORTE') or char_length(trim(p_display_name)) not between 2 and 80 then
    raise exception 'INVALID_REGISTRATION';
  end if;
  v_number := upper(regexp_replace(coalesce(p_doc_number,''), '[^A-Za-z0-9]', '', 'g'));
  if char_length(v_number) not between 5 and 20 then raise exception 'INVALID_DOCUMENT'; end if;
  if p_photo_path not like v_user::text || '/%' or not exists (
    select 1 from storage.objects where bucket_id = 'identity-documents' and name = p_photo_path
  ) then raise exception 'DOCUMENT_PHOTO_REQUIRED'; end if;
  insert into private.identity_documents(user_id, doc_type, doc_number_normalized, photo_storage_path)
    values (v_user, p_doc_type, v_number, p_photo_path);
  insert into public.profiles(id, community_id, display_name, role, status)
    values (v_user, p_community_id, trim(p_display_name), 'VECINO', 'ACTIVO');
  return v_user;
exception when unique_violation then
  raise exception 'DOCUMENT_ALREADY_USED';
end; $$;

create or replace function public.accept_solidarity_response(p_response_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_post public.solidarity_posts%rowtype;
begin
  select p.* into v_post from public.solidarity_posts p
  join public.solidarity_responses r on r.post_id = p.id
  where r.id = p_response_id for update of p;
  if not found or v_post.author_id <> auth.uid() or v_post.status <> 'ABIERTA' then
    raise exception 'NOT_ALLOWED';
  end if;
  update public.solidarity_posts set status = 'EN_COORDINACION', accepted_response_id = p_response_id
  where id = v_post.id;
end; $$;

create or replace function public.close_solidarity_post(p_post_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if p_status not in ('RESUELTA','CANCELADA') then raise exception 'INVALID_STATUS'; end if;
  update public.solidarity_posts set status = p_status where id = p_post_id
    and author_id = auth.uid() and status in ('ABIERTA','EN_COORDINACION');
  if not found then raise exception 'NOT_ALLOWED'; end if;
end; $$;

create or replace function public.activate_sos(
  p_request_id uuid, p_lat double precision, p_lng double precision
) returns uuid language plpgsql security definer
set search_path = public, private, pg_temp as $$
declare v_id uuid; v_community uuid := public.my_community_id();
begin
  if v_community is null or p_request_id is null or p_lat not between -90 and 90
    or p_lng not between -180 and 180 then raise exception 'INVALID_SOS'; end if;
  select id into v_id from public.emergency_alerts
    where sender_id = auth.uid() and client_request_id = p_request_id;
  if v_id is not null then return v_id; end if;
  if exists(select 1 from public.emergency_alerts where sender_id = auth.uid()
    and status = 'ACTIVA' and expires_at > now()) then raise exception 'SOS_ALREADY_ACTIVE'; end if;
  insert into public.emergency_alerts(sender_id, community_id, expires_at, client_request_id)
    values(auth.uid(), v_community, now() + interval '15 minutes', p_request_id)
    returning id into v_id;
  insert into private.emergency_locations(alert_id, lat, lng) values(v_id, p_lat, p_lng);
  return v_id;
end; $$;

create or replace function public.push_sos_location(p_alert_id uuid, p_lat double precision, p_lng double precision)
returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
begin
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'INVALID_LOCATION'; end if;
  if not exists(select 1 from public.emergency_alerts where id = p_alert_id
    and sender_id = auth.uid() and status = 'ACTIVA' and expires_at > now()) then
    raise exception 'SOS_NOT_ACTIVE';
  end if;
  insert into private.emergency_locations(alert_id, lat, lng, captured_at)
    values(p_alert_id, p_lat, p_lng, now())
    on conflict (alert_id) do update set lat = excluded.lat, lng = excluded.lng,
      captured_at = excluded.captured_at;
end; $$;

create or replace function public.extend_sos(p_alert_id uuid)
returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare v_expires timestamptz;
begin
  update public.emergency_alerts set expires_at = expires_at + interval '15 minutes'
    where id = p_alert_id and sender_id = auth.uid() and status = 'ACTIVA' and expires_at > now()
    returning expires_at into v_expires;
  if v_expires is null then raise exception 'SOS_NOT_ACTIVE'; end if;
  return v_expires;
end; $$;

create or replace function public.end_sos(p_alert_id uuid)
returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
begin
  update public.emergency_alerts set status = 'FINALIZADA', ended_at = now()
    where id = p_alert_id and sender_id = auth.uid() and status = 'ACTIVA';
  if not found then raise exception 'SOS_NOT_ACTIVE'; end if;
  delete from private.emergency_locations where alert_id = p_alert_id;
end; $$;

create or replace function public.get_active_sos_locations()
returns table(alert_id uuid, sender_id uuid, lat double precision, lng double precision,
  captured_at timestamptz, expires_at timestamptz)
language sql stable security definer set search_path = public, private, pg_temp as $$
  select a.id, a.sender_id, l.lat, l.lng, l.captured_at, a.expires_at
  from public.emergency_alerts a join private.emergency_locations l on l.alert_id = a.id
  where public.is_active_neighbor() and a.community_id = public.my_community_id()
    and a.status = 'ACTIVA' and a.expires_at > now()
$$;

create or replace function public.expire_sos()
returns integer language plpgsql security definer set search_path = public, private, pg_temp as $$
declare v_count integer;
begin
  update public.emergency_alerts set status = 'EXPIRADA', ended_at = now()
    where status = 'ACTIVA' and expires_at <= now();
  get diagnostics v_count = row_count;
  delete from private.emergency_locations l where exists (
    select 1 from public.emergency_alerts a where a.id = l.alert_id and a.status <> 'ACTIVA');
  return v_count;
end; $$;

revoke all on function public.complete_registration(text,uuid,text,text,text) from public, anon, authenticated;
revoke all on function public.accept_solidarity_response(uuid) from public, anon, authenticated;
revoke all on function public.close_solidarity_post(uuid,text) from public, anon, authenticated;
revoke all on function public.activate_sos(uuid,double precision,double precision) from public, anon, authenticated;
revoke all on function public.push_sos_location(uuid,double precision,double precision) from public, anon, authenticated;
revoke all on function public.extend_sos(uuid) from public, anon, authenticated;
revoke all on function public.end_sos(uuid) from public, anon, authenticated;
revoke all on function public.get_active_sos_locations() from public, anon, authenticated;
revoke all on function public.expire_sos() from public, anon, authenticated;
grant execute on function public.complete_registration(text,uuid,text,text,text) to authenticated;
grant execute on function public.accept_solidarity_response(uuid) to authenticated;
grant execute on function public.close_solidarity_post(uuid,text) to authenticated;
grant execute on function public.activate_sos(uuid,double precision,double precision) to authenticated;
grant execute on function public.push_sos_location(uuid,double precision,double precision) to authenticated;
grant execute on function public.extend_sos(uuid) to authenticated;
grant execute on function public.end_sos(uuid) to authenticated;
grant execute on function public.get_active_sos_locations() to authenticated;
-- expire_sos debe programarse con un job de servidor que posea permisos suficientes.
