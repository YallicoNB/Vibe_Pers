-- Vibe Pers: comunidades dibujadas, DNI de dos caras y recursos geográficos.
-- Ejecutar una sola vez después de 202611070001_core.sql y 202611070002_operations.sql.
create extension if not exists postgis with schema extensions;

alter table public.communities
  add column if not exists boundary extensions.geometry(Polygon, 4326),
  add column if not exists created_by uuid references auth.users(id),
  add column if not exists verification_status text not null default 'NO_VERIFICADA';
create index if not exists communities_boundary_gix on public.communities using gist (boundary);
alter table private.identity_documents
  add column if not exists photo_back_storage_path text;

alter table public.listings alter column client_request_id set default gen_random_uuid();

alter table public.emergency_resources
  add column if not exists verification_source text,
  add column if not exists verified_at timestamptz;

-- El usuario puede retirar cargas fallidas, nunca fotos ya ligadas a un DNI.
create or replace function public.is_own_identity_photo_attached(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_path like auth.uid()::text || '/%' and exists (
    select 1 from private.identity_documents d where d.user_id = auth.uid()
      and (d.photo_storage_path = p_path or d.photo_back_storage_path = p_path)
  )
$$;
revoke all on function public.is_own_identity_photo_attached(text) from public, anon, authenticated;
grant execute on function public.is_own_identity_photo_attached(text) to authenticated;
create policy identity_orphan_read on storage.objects for select to authenticated
using (bucket_id = 'identity-documents' and owner_id = auth.uid()::text
  and name like auth.uid()::text || '/%'
  and not public.is_own_identity_photo_attached(name));
create policy identity_orphan_delete on storage.objects for delete to authenticated
using (bucket_id = 'identity-documents' and owner_id = auth.uid()::text
  and name like auth.uid()::text || '/%'
  and not public.is_own_identity_photo_attached(name));

create or replace function public.list_community_areas()
returns table(id uuid, name text, boundary_geojson text, center_lat double precision, center_lng double precision)
language sql stable security invoker set search_path = ''
as $$
  select c.id, c.name, extensions.ST_AsGeoJSON(c.boundary), c.center_lat, c.center_lng
  from public.communities c
  where c.boundary is not null and c.is_demo = false
$$;
revoke all on function public.list_community_areas() from public, anon, authenticated;
grant execute on function public.list_community_areas() to authenticated;

create or replace function public.complete_registration_v2(
  p_display_name text,
  p_community_name text,
  p_boundary jsonb,
  p_existing_community_id uuid,
  p_doc_number text,
  p_front_path text,
  p_back_path text
) returns uuid
language plpgsql security definer
set search_path = public, private, storage, extensions, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_number text;
  v_boundary extensions.geometry(Polygon,4326);
  v_community uuid;
  v_area double precision;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  if exists(select 1 from public.profiles where id = v_user) then
    raise exception 'PROFILE_EXISTS';
  end if;
  if char_length(trim(coalesce(p_display_name,''))) not between 2 and 80 then
    raise exception 'INVALID_NAME';
  end if;
  v_number := regexp_replace(coalesce(p_doc_number,''), '[^0-9]', '', 'g');
  if v_number !~ '^[0-9]{8}$' then raise exception 'INVALID_DNI'; end if;
  if p_front_path is null or p_back_path is null or p_front_path = p_back_path
    or p_front_path not like v_user::text || '/%'
    or p_back_path not like v_user::text || '/%'
    or not exists(select 1 from storage.objects where bucket_id = 'identity-documents' and name = p_front_path)
    or not exists(select 1 from storage.objects where bucket_id = 'identity-documents' and name = p_back_path)
  then raise exception 'DOCUMENT_PHOTOS_REQUIRED'; end if;

  if p_existing_community_id is not null then
    if p_boundary is not null or nullif(trim(coalesce(p_community_name,'')), '') is not null then
      raise exception 'INVALID_COMMUNITY_REQUEST';
    end if;
    select c.id into v_community from public.communities c
    where c.id = p_existing_community_id and c.boundary is not null and not c.is_demo;
    if v_community is null then raise exception 'COMMUNITY_NOT_FOUND'; end if;
  else
    if char_length(trim(coalesce(p_community_name,''))) not between 3 and 80
      or p_boundary is null then raise exception 'INVALID_COMMUNITY_REQUEST'; end if;
    begin
      v_boundary := extensions.ST_SetSRID(
        extensions.ST_GeomFromGeoJSON(p_boundary::text), 4326
      )::extensions.geometry(Polygon,4326);
    exception when others then raise exception 'INVALID_BOUNDARY'; end;
    if v_boundary is null or not extensions.ST_IsValid(v_boundary)
      or extensions.ST_NPoints(v_boundary) not between 4 and 31 then
      raise exception 'INVALID_BOUNDARY';
    end if;
    v_area := extensions.ST_Area(v_boundary::extensions.geography);
    if v_area not between 10000 and 50000000 then raise exception 'BOUNDARY_SIZE'; end if;
    -- Serializa creaciones concurrentes para evitar comunidades superpuestas.
    perform pg_advisory_xact_lock(827406);
    if exists(
      select 1 from public.communities c
      where c.boundary is not null and not c.is_demo
      and extensions.ST_Intersects(c.boundary, v_boundary)
      and extensions.ST_Area(
        extensions.ST_Intersection(c.boundary, v_boundary)
      ) > 0
    ) then raise exception 'COMMUNITY_OVERLAP'; end if;
    insert into public.communities(name, area_label, center_lat, center_lng,
      boundary, created_by, verification_status, is_demo)
    values(trim(p_community_name), 'Zona creada por vecinos',
      extensions.ST_Y(extensions.ST_PointOnSurface(v_boundary)),
      extensions.ST_X(extensions.ST_PointOnSurface(v_boundary)),
      v_boundary, v_user, 'NO_VERIFICADA', false)
    returning id into v_community;
  end if;

  insert into private.identity_documents(
    user_id, doc_type, doc_number_normalized, photo_storage_path, photo_back_storage_path
  ) values(v_user, 'DNI', v_number, p_front_path, p_back_path);
  insert into public.profiles(id, community_id, display_name, role, status)
  values(v_user, v_community, trim(p_display_name), 'VECINO', 'ACTIVO');
  return v_user;
exception when unique_violation then
  raise exception 'DOCUMENT_ALREADY_USED';
end;
$$;

-- El registro anterior aceptaba una sola fotografía: ya no debe poder usarse.
revoke all on function public.complete_registration(text,uuid,text,text,text)
  from public, anon, authenticated;
revoke all on function public.complete_registration_v2(text,text,jsonb,uuid,text,text,text)
  from public, anon, authenticated;
grant execute on function public.complete_registration_v2(text,text,jsonb,uuid,text,text,text)
  to authenticated;
