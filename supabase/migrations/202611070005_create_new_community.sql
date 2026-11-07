-- Crear otra junta dibujada y cambiarse a ella solo por solicitud explícita.
create or replace function public.create_and_join_community(p_name text, p_boundary jsonb)
returns uuid language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_boundary extensions.geometry(Polygon,4326);
  v_id uuid;
begin
  if v_user is null or not exists(select 1 from public.profiles where id = v_user and status = 'ACTIVO') then
    raise exception 'PROFILE_NOT_FOUND';
  end if;
  if char_length(trim(coalesce(p_name,''))) not between 3 and 80 or p_boundary is null then
    raise exception 'INVALID_COMMUNITY_REQUEST';
  end if;
  begin
    v_boundary := extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON(p_boundary::text),4326)::extensions.geometry(Polygon,4326);
  exception when others then raise exception 'INVALID_BOUNDARY'; end;
  if v_boundary is null or not extensions.ST_IsValid(v_boundary)
    or extensions.ST_NPoints(v_boundary) not between 4 and 31 then
    raise exception 'INVALID_BOUNDARY';
  end if;
  if extensions.ST_Area(v_boundary::extensions.geography) not between 10000 and 50000000 then
    raise exception 'BOUNDARY_SIZE';
  end if;
  perform pg_advisory_xact_lock(827406);
  if exists(select 1 from public.communities c where c.boundary is not null and not c.is_demo
    and extensions.ST_Intersects(c.boundary,v_boundary)
    and extensions.ST_Area(extensions.ST_Intersection(c.boundary,v_boundary)) > 0) then
    raise exception 'COMMUNITY_OVERLAP';
  end if;
  insert into public.communities(name,area_label,center_lat,center_lng,boundary,created_by,verification_status,is_demo)
  values(trim(p_name),'Zona creada por vecinos',
    extensions.ST_Y(extensions.ST_PointOnSurface(v_boundary)),
    extensions.ST_X(extensions.ST_PointOnSurface(v_boundary)),
    v_boundary,v_user,'NO_VERIFICADA',false)
  returning id into v_id;
  update public.profiles set community_id = v_id where id = v_user;
  return v_id;
end; $$;
revoke all on function public.create_and_join_community(text,jsonb) from public, anon, authenticated;
grant execute on function public.create_and_join_community(text,jsonb) to authenticated;
