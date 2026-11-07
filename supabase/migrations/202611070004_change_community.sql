-- Cambio de comunidad solamente por una acción explícita del titular.
create or replace function public.change_my_community(p_community_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from public.communities c where c.id = p_community_id and c.boundary is not null and not c.is_demo) then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;
  update public.profiles set community_id = p_community_id
  where id = auth.uid() and status = 'ACTIVO';
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
end; $$;
revoke all on function public.change_my_community(uuid) from public, anon, authenticated;
grant execute on function public.change_my_community(uuid) to authenticated;
