-- Esquema inicial para revisión antes de aplicar a un proyecto Supabase.
-- No se ha ejecutado: aún no existe proyecto del equipo.
create schema if not exists private;

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  area_label text not null,
  center_lat double precision,
  center_lng double precision,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  community_id uuid not null references public.communities(id),
  display_name text not null check (char_length(trim(display_name)) between 2 and 80),
  avatar_code text not null default 'duck',
  role text not null default 'VECINO' check (role in ('VECINO','LIDER_VECINAL','OPERADOR_MUNICIPAL')),
  status text not null default 'ACTIVO' check (status in ('PENDIENTE','ACTIVO','SUSPENDIDO')),
  created_at timestamptz not null default now()
);

create table if not exists private.identity_documents (
  user_id uuid primary key references auth.users(id) on delete cascade,
  doc_type text not null check (doc_type in ('DNI','CE','PASAPORTE')),
  doc_number_normalized text not null,
  photo_storage_path text not null,
  created_at timestamptz not null default now(),
  unique (doc_type, doc_number_normalized)
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id),
  community_id uuid not null references public.communities(id),
  kind text not null check (kind in ('PRODUCT','SERVICE')),
  category text not null,
  title text not null check (char_length(trim(title)) between 5 and 80),
  description text not null check (char_length(trim(description)) between 10 and 2000),
  price numeric(10,2) not null check (price >= 0),
  zone text not null,
  lat double precision,
  lng double precision,
  whatsapp_public text,
  photo_storage_path text not null,
  status text not null default 'ACTIVO' check (status in ('ACTIVO','CERRADO','OCULTO')),
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (seller_id, client_request_id)
);

create table if not exists public.recommendations (
  listing_id uuid not null references public.listings(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (listing_id, voter_id)
);

create table if not exists public.solidarity_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id),
  community_id uuid not null references public.communities(id),
  direction text not null check (direction in ('NEED','OFFER')),
  mode text not null check (mode in ('DONATION','LOAN','BARTER','VOLUNTEER')),
  title text not null check (char_length(trim(title)) between 5 and 80),
  description text not null check (char_length(trim(description)) between 10 and 2000),
  status text not null default 'ABIERTA' check (status in ('ABIERTA','EN_COORDINACION','RESUELTA','CANCELADA')),
  accepted_response_id uuid,
  client_request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (author_id, client_request_id)
);

create table if not exists public.solidarity_responses (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.solidarity_posts(id) on delete cascade,
  responder_id uuid not null references public.profiles(id),
  message text not null check (char_length(trim(message)) between 2 and 500),
  created_at timestamptz not null default now()
);
alter table public.solidarity_posts drop constraint if exists solidarity_posts_accepted_response_id_fkey;
alter table public.solidarity_posts add constraint solidarity_posts_accepted_response_id_fkey
  foreign key (accepted_response_id) references public.solidarity_responses(id);

create table if not exists public.emergency_resources (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id),
  title text not null,
  kind text not null,
  details text not null default '',
  lat double precision,
  lng double precision,
  is_demo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id),
  community_id uuid not null references public.communities(id),
  status text not null default 'ACTIVA' check (status in ('ACTIVA','FINALIZADA','EXPIRADA','CANCELADA')),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  ended_at timestamptz,
  client_request_id uuid not null,
  unique (sender_id, client_request_id)
);

create table if not exists private.emergency_locations (
  alert_id uuid primary key references public.emergency_alerts(id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  captured_at timestamptz not null default now()
);

create index if not exists profiles_community_idx on public.profiles(community_id);
create index if not exists listings_visible_idx on public.listings(community_id, status, kind);
create index if not exists solidarity_visible_idx on public.solidarity_posts(community_id, status);
create index if not exists alerts_visible_idx on public.emergency_alerts(community_id, status, expires_at);

-- Los GRANT se restringen además de RLS; TRUNCATE no queda protegido por políticas.
revoke all on public.communities, public.profiles, public.listings,
  public.recommendations, public.solidarity_posts, public.solidarity_responses,
  public.emergency_resources, public.emergency_alerts from anon, authenticated;
revoke all on private.identity_documents, private.emergency_locations from anon, authenticated;
grant select on public.communities, public.profiles, public.listings,
  public.recommendations, public.solidarity_posts, public.solidarity_responses,
  public.emergency_resources, public.emergency_alerts to authenticated;
grant insert, update on public.listings to authenticated;
grant insert, delete on public.recommendations to authenticated;
grant insert on public.solidarity_posts, public.solidarity_responses to authenticated;

create or replace function public.my_community_id() returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select community_id from public.profiles where id = auth.uid() and status = 'ACTIVO'
$$;
create or replace function public.is_active_neighbor() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'ACTIVO')
$$;
revoke all on function public.my_community_id() from public, anon, authenticated;
revoke all on function public.is_active_neighbor() from public, anon, authenticated;
grant execute on function public.my_community_id() to authenticated;
grant execute on function public.is_active_neighbor() to authenticated;

alter table public.communities enable row level security;
alter table public.profiles enable row level security;
alter table private.identity_documents enable row level security;
alter table public.listings enable row level security;
alter table public.recommendations enable row level security;
alter table public.solidarity_posts enable row level security;
alter table public.solidarity_responses enable row level security;
alter table public.emergency_resources enable row level security;
alter table public.emergency_alerts enable row level security;
alter table private.emergency_locations enable row level security;

create policy communities_read on public.communities for select to authenticated using (true);
create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or (public.is_active_neighbor() and community_id = public.my_community_id() and status = 'ACTIVO'));
create policy listings_read on public.listings for select to authenticated
  using (public.is_active_neighbor() and community_id = public.my_community_id() and status = 'ACTIVO');
create policy listings_insert on public.listings for insert to authenticated
  with check (public.is_active_neighbor() and seller_id = auth.uid() and community_id = public.my_community_id()
    and photo_storage_path like auth.uid()::text || '/%' and status = 'ACTIVO');
create policy listings_update on public.listings for update to authenticated
  using (seller_id = auth.uid() and community_id = public.my_community_id() and status in ('ACTIVO','CERRADO'))
  with check (seller_id = auth.uid() and community_id = public.my_community_id()
    and photo_storage_path like auth.uid()::text || '/%' and status in ('ACTIVO','CERRADO'));
create policy recommendations_read on public.recommendations for select to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.community_id = public.my_community_id()));
create policy recommendations_insert on public.recommendations for insert to authenticated
  with check (voter_id = auth.uid() and public.is_active_neighbor() and exists (
    select 1 from public.listings l where l.id = listing_id and l.kind = 'SERVICE'
    and l.status = 'ACTIVO' and l.community_id = public.my_community_id() and l.seller_id <> auth.uid()));
create policy recommendations_delete on public.recommendations for delete to authenticated using (voter_id = auth.uid());
create policy solidarity_read on public.solidarity_posts for select to authenticated
  using (public.is_active_neighbor() and community_id = public.my_community_id());
create policy solidarity_insert on public.solidarity_posts for insert to authenticated
  with check (public.is_active_neighbor() and author_id = auth.uid() and community_id = public.my_community_id()
    and status = 'ABIERTA' and accepted_response_id is null);
create policy responses_read on public.solidarity_responses for select to authenticated
  using (exists(select 1 from public.solidarity_posts p where p.id = post_id and p.community_id = public.my_community_id()));
create policy responses_insert on public.solidarity_responses for insert to authenticated
  with check (responder_id = auth.uid() and public.is_active_neighbor() and exists(
    select 1 from public.solidarity_posts p where p.id = post_id and p.community_id = public.my_community_id()
    and p.status = 'ABIERTA' and p.author_id <> auth.uid()));
create policy resources_read on public.emergency_resources for select to authenticated
  using (public.is_active_neighbor() and community_id = public.my_community_id());
create policy alerts_read on public.emergency_alerts for select to authenticated
  using (public.is_active_neighbor() and community_id = public.my_community_id() and status = 'ACTIVA' and expires_at > now());

-- No se otorga lectura directa de identity_documents ni emergency_locations.
-- Fotos privadas requieren políticas de Storage y retención antes de uso real.
