-- Avisos y grupos por junta. Las cuentas líderes concretas se asignan fuera del repositorio.
alter table public.profiles add column if not exists leader_community_id uuid references public.communities(id);
update public.profiles set leader_community_id=community_id where role='LIDER_VECINAL' and leader_community_id is null;

create or replace function public.is_community_leader(p_community_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles p where p.id=auth.uid() and p.status='ACTIVO'
    and p.role='LIDER_VECINAL' and p.community_id=p_community_id and p.leader_community_id=p_community_id);
$$;
revoke all on function public.is_community_leader(uuid) from public,anon,authenticated;
grant execute on function public.is_community_leader(uuid) to authenticated;

create table if not exists public.community_groups (
  community_id uuid not null references public.communities(id) on delete cascade,
  member_id uuid references public.profiles(id) on delete cascade,
  demo_key text,
  group_code text not null check(group_code in ('BRIGADA','EMPRENDEDORES','DONADORES')),
  assigned_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now(),
  constraint community_groups_one_target check((member_id is null)<>(demo_key is null)),
  constraint community_groups_member_unique unique(community_id,member_id),
  constraint community_groups_demo_unique unique(community_id,demo_key),
  constraint community_groups_demo_known check(demo_key is null or demo_key in ('demo-rosa','demo-carlos'))
);
alter table public.community_groups enable row level security;
revoke all on public.community_groups from anon,authenticated;
grant select on public.community_groups to authenticated;
drop policy if exists community_groups_read on public.community_groups;
create policy community_groups_read on public.community_groups for select to authenticated
  using(public.is_active_neighbor() and community_id=public.my_community_id());

create or replace function public.assign_community_group(p_member_id uuid,p_demo_key text,p_group_code text)
returns void language plpgsql security definer set search_path='' as $$
declare v_community uuid:=public.my_community_id();
begin
  if v_community is null or not public.is_community_leader(v_community) then raise exception 'LEADER_REQUIRED'; end if;
  if (p_member_id is null)=(p_demo_key is null)
    or (p_group_code is not null and p_group_code not in ('BRIGADA','EMPRENDEDORES','DONADORES'))
    then raise exception 'INVALID_GROUP'; end if;
  if p_member_id is not null then
    if not exists(select 1 from public.profiles p where p.id=p_member_id
      and p.community_id=v_community and p.status='ACTIVO' and p.id<>auth.uid()
      and not(p.role='LIDER_VECINAL' and p.leader_community_id=v_community))
      then raise exception 'MEMBER_NOT_ALLOWED'; end if;
    if p_group_code is null then
      delete from public.community_groups where community_id=v_community and member_id=p_member_id;
    else
      insert into public.community_groups(community_id,member_id,group_code,assigned_by)
      values(v_community,p_member_id,p_group_code,auth.uid())
      on conflict(community_id,member_id) do update set group_code=excluded.group_code,
        assigned_by=excluded.assigned_by,updated_at=now();
    end if;
  else
    if p_demo_key not in ('demo-rosa','demo-carlos') then raise exception 'INVALID_DEMO_MEMBER'; end if;
    if p_group_code is null then
      delete from public.community_groups where community_id=v_community and demo_key=p_demo_key;
    else
      insert into public.community_groups(community_id,demo_key,group_code,assigned_by)
      values(v_community,p_demo_key,p_group_code,auth.uid())
      on conflict(community_id,demo_key) do update set group_code=excluded.group_code,
        assigned_by=excluded.assigned_by,updated_at=now();
    end if;
  end if;
end; $$;
revoke all on function public.assign_community_group(uuid,text,text) from public,anon,authenticated;
grant execute on function public.assign_community_group(uuid,text,text) to authenticated;

create table if not exists public.community_announcements (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  author_id uuid not null references public.profiles(id),
  kind text not null check(kind in ('GENERAL','MEETING','EMERGENCY')),
  title text not null check(char_length(trim(title)) between 5 and 100),
  body text not null check(char_length(trim(body)) between 10 and 2000),
  meeting_at timestamptz,
  meeting_place text,
  status text not null default 'ACTIVE' check(status in ('ACTIVE','CLOSED')),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  closed_at timestamptz,
  constraint meeting_details_required check(
    (kind='MEETING' and meeting_at is not null and char_length(trim(coalesce(meeting_place,''))) between 3 and 200)
    or (kind<>'MEETING' and meeting_at is null and meeting_place is null))
);
create index if not exists community_announcements_feed_idx on public.community_announcements(community_id,created_at desc);
alter table public.community_announcements enable row level security;
revoke all on public.community_announcements from anon,authenticated;
grant select on public.community_announcements to authenticated;
drop policy if exists community_announcements_read on public.community_announcements;
create policy community_announcements_read on public.community_announcements for select to authenticated
  using(public.is_active_neighbor() and community_id=public.my_community_id()
    and status='ACTIVE' and (expires_at is null or expires_at>now()));

create or replace function public.create_community_announcement(
  p_kind text,p_title text,p_body text,p_meeting_at timestamptz,p_meeting_place text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_community uuid:=public.my_community_id();v_id uuid;
begin
  if v_community is null or not public.is_community_leader(v_community) then raise exception 'LEADER_REQUIRED'; end if;
  if p_kind not in ('GENERAL','MEETING','EMERGENCY')
    or char_length(trim(coalesce(p_title,''))) not between 5 and 100
    or char_length(trim(coalesce(p_body,''))) not between 10 and 2000
    then raise exception 'INVALID_ANNOUNCEMENT'; end if;
  if p_kind='MEETING' then
    if p_meeting_at is null or p_meeting_at<=now()
      or char_length(trim(coalesce(p_meeting_place,''))) not between 3 and 200
      then raise exception 'INVALID_MEETING'; end if;
  elsif p_meeting_at is not null or p_meeting_place is not null then
    raise exception 'INVALID_ANNOUNCEMENT';
  end if;
  insert into public.community_announcements(community_id,author_id,kind,title,body,
    meeting_at,meeting_place,expires_at)
  values(v_community,auth.uid(),p_kind,trim(p_title),trim(p_body),p_meeting_at,
    nullif(trim(p_meeting_place),''),case when p_kind='EMERGENCY' then now()+interval '24 hours' end)
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.create_community_announcement(text,text,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.create_community_announcement(text,text,text,timestamptz,text) to authenticated;

create or replace function public.close_community_announcement(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_community uuid:=public.my_community_id();
begin
  if v_community is null or not public.is_community_leader(v_community) then raise exception 'LEADER_REQUIRED'; end if;
  update public.community_announcements set status='CLOSED',closed_at=now()
  where id=p_id and community_id=v_community and status='ACTIVE';
  if not found then raise exception 'ANNOUNCEMENT_NOT_FOUND'; end if;
end; $$;
revoke all on function public.close_community_announcement(uuid) from public,anon,authenticated;
grant execute on function public.close_community_announcement(uuid) to authenticated;

create table if not exists public.community_announcement_reads (
  announcement_id uuid not null references public.community_announcements(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(announcement_id,user_id)
);
alter table public.community_announcement_reads enable row level security;
revoke all on public.community_announcement_reads from anon,authenticated;
grant select on public.community_announcement_reads to authenticated;
drop policy if exists community_announcement_reads_own on public.community_announcement_reads;
create policy community_announcement_reads_own on public.community_announcement_reads
  for select to authenticated using(user_id=auth.uid());

create or replace function public.mark_community_announcement_read(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from public.community_announcements a where a.id=p_id
    and a.community_id=public.my_community_id() and a.status='ACTIVE'
    and (a.expires_at is null or a.expires_at>now())) then raise exception 'ANNOUNCEMENT_NOT_FOUND'; end if;
  insert into public.community_announcement_reads(announcement_id,user_id)
    values(p_id,auth.uid()) on conflict do nothing;
end; $$;
revoke all on function public.mark_community_announcement_read(uuid) from public,anon,authenticated;
grant execute on function public.mark_community_announcement_read(uuid) to authenticated;
