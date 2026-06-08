-- =============================================================================
-- More Properties — Supabase schema (v2)
-- =============================================================================
-- Paste this entire file into the Supabase SQL editor and run.
-- Idempotent: it can be re-run safely. RLS is enabled on every table.
-- =============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('buyer', 'renter', 'agent', 'agency_admin', 'admin');
  end if;
  if not exists (select 1 from pg_type where typname = 'listing_mode') then
    create type public.listing_mode as enum ('buy', 'rent', 'developments', 'commercial');
  end if;
  if not exists (select 1 from pg_type where typname = 'listing_status') then
    create type public.listing_status as enum ('draft', 'active', 'under_offer', 'sold', 'rented', 'archived');
  end if;
  if not exists (select 1 from pg_type where typname = 'lead_status') then
    create type public.lead_status as enum ('new', 'contacted', 'viewing_booked', 'qualified', 'closed', 'lost');
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- Profiles
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'buyer',
  full_name text,
  phone text,
  avatar_url text,
  preferred_province text,
  preferred_city text,
  fica_verified boolean not null default false,
  popi_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Migration: add v2 columns to an existing v1 profiles table.
alter table public.profiles add column if not exists preferred_province text;
alter table public.profiles add column if not exists fica_verified boolean not null default false;
alter table public.profiles add column if not exists popi_consent_at timestamptz;

-- -----------------------------------------------------------------------------
-- Agencies & Agents
-- -----------------------------------------------------------------------------
create table if not exists public.agencies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  logo_url text,
  website text,
  office_phone text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.agents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  agency_id uuid references public.agencies(id) on delete cascade,
  display_name text not null,
  email text not null,
  phone text not null,
  area text not null,
  bio text,
  avatar_url text,
  ppra_number text,
  rating numeric(2,1) not null default 5.0 check (rating >= 0 and rating <= 5),
  response_minutes int not null default 30 check (response_minutes >= 0),
  listings_active int not null default 0 check (listings_active >= 0),
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists agents_agency_idx on public.agents(agency_id);
create index if not exists agents_area_idx on public.agents(area);

-- Migration: add v2 columns to an existing v1 agents table.
alter table public.agents add column if not exists ppra_number text;
alter table public.agents add column if not exists listings_active int not null default 0;

-- -----------------------------------------------------------------------------
-- Listings
-- -----------------------------------------------------------------------------
create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid references public.agencies(id) on delete cascade,
  agent_id uuid references public.agents(id) on delete set null,
  slug text not null unique,
  title text not null,
  description text not null,
  mode public.listing_mode not null,
  status public.listing_status not null default 'draft',
  property_type text not null,
  price numeric(14,2) not null check (price >= 0),
  province text not null,
  city text not null,
  suburb text not null,
  address text,
  bedrooms int not null default 0 check (bedrooms >= 0),
  bathrooms numeric(4,1) not null default 0 check (bathrooms >= 0),
  parking int not null default 0 check (parking >= 0),
  floor_size int check (floor_size >= 0),
  erf_size int check (erf_size >= 0),
  levy numeric(12,2),
  rates numeric(12,2),
  latitude numeric(9,6),
  longitude numeric(9,6),
  hero_image_url text,
  gallery_urls text[] not null default '{}',
  virtual_tour_url text,
  video_url text,

  -- South African-specific amenity taxonomies.
  lifestyle_features text[] not null default '{}',
  security_features text[] not null default '{}',
  resilience_features text[] not null default '{}',

  -- Suburb intelligence scores (1..10).
  load_shedding_score int not null default 7 check (load_shedding_score between 0 and 10),
  safety_score int not null default 7 check (safety_score between 0 and 10),
  school_score int not null default 7 check (school_score between 0 and 10),
  lifestyle_score int not null default 7 check (lifestyle_score between 0 and 10),
  energy_rating text not null default 'B',

  is_featured boolean not null default false,
  is_verified boolean not null default true,
  popi_compliant boolean not null default true,
  eaab_registered boolean not null default true,

  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  search_vector tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(suburb, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(city, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'C')
  ) stored
);

-- Migration: add v2 columns to an existing v1 listings table.
-- Safe to re-run; columns only get added once.
alter table public.listings add column if not exists gallery_urls text[] not null default '{}';
alter table public.listings add column if not exists lifestyle_features text[] not null default '{}';
alter table public.listings add column if not exists security_features text[] not null default '{}';
alter table public.listings add column if not exists resilience_features text[] not null default '{}';
alter table public.listings add column if not exists load_shedding_score int not null default 7;
alter table public.listings add column if not exists safety_score int not null default 7;
alter table public.listings add column if not exists school_score int not null default 7;
alter table public.listings add column if not exists lifestyle_score int not null default 7;
alter table public.listings add column if not exists energy_rating text not null default 'B';
alter table public.listings add column if not exists is_verified boolean not null default true;
alter table public.listings add column if not exists popi_compliant boolean not null default true;
alter table public.listings add column if not exists eaab_registered boolean not null default true;

-- Re-add v1 array column defaults if they existed under different names.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listings'
      and column_name = 'features'
  ) then
    -- Carry pre-existing `features[]` content into the new `lifestyle_features` column.
    update public.listings
       set lifestyle_features = features
     where (lifestyle_features is null or array_length(lifestyle_features, 1) is null)
       and features is not null;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listings'
      and column_name = 'amenities'
  ) then
    update public.listings
       set security_features = amenities
     where (security_features is null or array_length(security_features, 1) is null)
       and amenities is not null;
  end if;
end $$;

create index if not exists listings_mode_status_idx on public.listings(mode, status);
create index if not exists listings_price_idx on public.listings(price);
create index if not exists listings_location_idx on public.listings(province, city, suburb);
create index if not exists listings_search_idx on public.listings using gin(search_vector);
create index if not exists listings_lifestyle_idx on public.listings using gin(lifestyle_features);
create index if not exists listings_security_idx on public.listings using gin(security_features);
create index if not exists listings_resilience_idx on public.listings using gin(resilience_features);
create index if not exists listings_featured_idx on public.listings(is_featured, published_at desc);

-- -----------------------------------------------------------------------------
-- Listing images (long form gallery)
-- -----------------------------------------------------------------------------
create table if not exists public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  image_url text not null,
  alt_text text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Favourites, saved searches & compare lists
-- -----------------------------------------------------------------------------
create table if not exists public.favourites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  criteria jsonb not null default '{}'::jsonb,
  cadence text not null default 'instant' check (cadence in ('instant', 'daily', 'weekly')),
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  last_run_at timestamptz,
  created_at timestamptz not null default now()
);

-- Migration: add v2 columns to an existing v1 saved_searches table.
alter table public.saved_searches add column if not exists last_run_at timestamptz;

create table if not exists public.compare_items (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

-- -----------------------------------------------------------------------------
-- Leads, viewings, analytics
-- -----------------------------------------------------------------------------
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings(id) on delete set null,
  agent_id uuid references public.agents(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  name text not null,
  email text,
  phone text,
  message text,
  source text not null default 'mobile_app',
  status public.lead_status not null default 'new',
  popi_consent boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leads_agent_status_idx on public.leads(agent_id, status, created_at desc);
create index if not exists leads_listing_idx on public.leads(listing_id, created_at desc);

-- Migration: add v2 columns to an existing v1 leads table.
alter table public.leads add column if not exists popi_consent boolean not null default true;

create table if not exists public.viewing_appointments (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  agent_id uuid references public.agents(id) on delete set null,
  requested_for timestamptz not null,
  status text not null default 'requested' check (status in ('requested', 'confirmed', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.listing_views (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  anonymous_id text,
  source text,
  viewed_at timestamptz not null default now()
);

create index if not exists listing_views_listing_idx on public.listing_views(listing_id, viewed_at desc);

-- -----------------------------------------------------------------------------
-- Market snapshot (synced by scheduled Edge Function)
-- -----------------------------------------------------------------------------
create table if not exists public.market_snapshot (
  id text primary key,
  prime_rate numeric(5,2) not null,
  prime_rate_as_of text not null,
  prime_rate_source text not null,
  cape_town_house_price_yoy text not null,
  cape_town_source text not null,
  gauteng_rentals_yoy text not null,
  gauteng_source text not null,
  transfer_duty_effective_label text not null,
  transfer_duty_source text not null,
  transfer_duty_brackets jsonb not null,
  synced_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists listings_updated_at on public.listings;
create trigger listings_updated_at before update on public.listings
  for each row execute function public.set_updated_at();

drop trigger if exists leads_updated_at on public.leads;
create trigger leads_updated_at before update on public.leads
  for each row execute function public.set_updated_at();

drop trigger if exists market_snapshot_updated_at on public.market_snapshot;
create trigger market_snapshot_updated_at before update on public.market_snapshot
  for each row execute function public.set_updated_at();

-- Auto-create a profile when a Supabase auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- RPC: search_listings — used by the Flutter app for advanced search.
-- -----------------------------------------------------------------------------
create or replace function public.search_listings(
  query_text text default '',
  mode_filter public.listing_mode default null,
  province_filter text default null,
  city_filter text default null,
  min_price numeric default null,
  max_price numeric default null,
  min_bedrooms int default null,
  min_bathrooms numeric default null,
  required_lifestyle text[] default '{}',
  required_security text[] default '{}',
  required_resilience text[] default '{}',
  verified_only boolean default false,
  featured_only boolean default false,
  limit_count int default 30
)
returns setof public.listings
language sql
stable
as $$
  select *
  from public.listings
  where status = 'active'
    and (mode_filter is null or mode = mode_filter)
    and (province_filter is null or province = province_filter)
    and (city_filter is null or city ilike city_filter)
    and (min_price is null or price >= min_price)
    and (max_price is null or price <= max_price)
    and (min_bedrooms is null or bedrooms >= min_bedrooms)
    and (min_bathrooms is null or bathrooms >= min_bathrooms)
    and (coalesce(array_length(required_lifestyle, 1), 0) = 0
         or lifestyle_features @> required_lifestyle)
    and (coalesce(array_length(required_security, 1), 0) = 0
         or security_features @> required_security)
    and (coalesce(array_length(required_resilience, 1), 0) = 0
         or resilience_features @> required_resilience)
    and (not verified_only or is_verified = true)
    and (not featured_only or is_featured = true)
    and (query_text = '' or search_vector @@ plainto_tsquery('english', query_text))
  order by is_featured desc, published_at desc nulls last, created_at desc
  limit limit_count;
$$;

revoke execute on function public.search_listings(
  text, public.listing_mode, text, text, numeric, numeric, int, numeric,
  text[], text[], text[], boolean, boolean, int
) from public;
grant execute on function public.search_listings(
  text, public.listing_mode, text, text, numeric, numeric, int, numeric,
  text[], text[], text[], boolean, boolean, int
) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- RPC: record_listing_view — counted from the mobile app on detail open.
-- -----------------------------------------------------------------------------
create or replace function public.record_listing_view(
  p_listing_id uuid,
  p_anonymous_id text default null,
  p_source text default 'mobile_app'
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.listing_views (listing_id, user_id, anonymous_id, source)
  values (p_listing_id, auth.uid(), p_anonymous_id, p_source);
$$;

revoke execute on function public.record_listing_view(uuid, text, text) from public;
grant execute on function public.record_listing_view(uuid, text, text)
  to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.agencies enable row level security;
alter table public.agents enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.favourites enable row level security;
alter table public.saved_searches enable row level security;
alter table public.compare_items enable row level security;
alter table public.leads enable row level security;
alter table public.viewing_appointments enable row level security;
alter table public.listing_views enable row level security;
alter table public.market_snapshot enable row level security;

-- Drop & recreate policies so re-running this file is safe.
drop policy if exists "Profiles readable by owner" on public.profiles;
drop policy if exists "Profiles editable by owner" on public.profiles;
drop policy if exists "Profiles insertable by owner" on public.profiles;
create policy "Profiles readable by owner" on public.profiles
  for select using (auth.uid() = id);
create policy "Profiles editable by owner" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Profiles insertable by owner" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "Agencies are public" on public.agencies;
drop policy if exists "Agents are public" on public.agents;
create policy "Agencies are public" on public.agencies for select using (true);
create policy "Agents are public" on public.agents for select using (true);

drop policy if exists "Active listings are public" on public.listings;
drop policy if exists "Agents read their own listings" on public.listings;
drop policy if exists "Agents manage their listings" on public.listings;
create policy "Active listings are public" on public.listings
  for select using (status = 'active');
create policy "Agents read their own listings" on public.listings
  for select
  using (
    exists (
      select 1 from public.agents
      where agents.id = listings.agent_id
        and agents.profile_id = auth.uid()
    )
  );
create policy "Agents manage their listings" on public.listings
  for all
  using (
    exists (
      select 1 from public.agents
      where agents.id = listings.agent_id
        and agents.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.agents
      where agents.id = listings.agent_id
        and agents.profile_id = auth.uid()
    )
  );

drop policy if exists "Listing images are public" on public.listing_images;
drop policy if exists "Agents manage their listing images" on public.listing_images;
create policy "Listing images are public" on public.listing_images
  for select using (true);
create policy "Agents manage their listing images" on public.listing_images
  for all
  using (
    exists (
      select 1
      from public.listings l
      join public.agents a on a.id = l.agent_id
      where l.id = listing_images.listing_id
        and a.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.listings l
      join public.agents a on a.id = l.agent_id
      where l.id = listing_images.listing_id
        and a.profile_id = auth.uid()
    )
  );

drop policy if exists "Users manage their favourites" on public.favourites;
drop policy if exists "Users manage their saved searches" on public.saved_searches;
drop policy if exists "Users manage their compare" on public.compare_items;
create policy "Users manage their favourites" on public.favourites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their saved searches" on public.saved_searches
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their compare" on public.compare_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Anyone can create leads" on public.leads;
drop policy if exists "Users read own leads" on public.leads;
drop policy if exists "Agents read assigned leads" on public.leads;
drop policy if exists "Agents update assigned leads" on public.leads;
create policy "Anyone can create leads" on public.leads
  for insert with check (true);
create policy "Users read own leads" on public.leads
  for select using (auth.uid() = user_id);
create policy "Agents read assigned leads" on public.leads
  for select using (
    exists (
      select 1 from public.agents
      where agents.id = leads.agent_id
        and agents.profile_id = auth.uid()
    )
  );
create policy "Agents update assigned leads" on public.leads
  for update using (
    exists (
      select 1 from public.agents
      where agents.id = leads.agent_id
        and agents.profile_id = auth.uid()
    )
  );

drop policy if exists "Anyone can record listing views" on public.listing_views;
drop policy if exists "Agents read listing views" on public.listing_views;
create policy "Anyone can record listing views" on public.listing_views
  for insert with check (true);
create policy "Agents read listing views" on public.listing_views
  for select using (
    exists (
      select 1
      from public.listings l
      join public.agents a on a.id = l.agent_id
      where l.id = listing_views.listing_id
        and a.profile_id = auth.uid()
    )
  );

drop policy if exists "Users read their appointments" on public.viewing_appointments;
drop policy if exists "Anyone can request appointments" on public.viewing_appointments;
drop policy if exists "Agents manage appointments" on public.viewing_appointments;
create policy "Users read their appointments" on public.viewing_appointments
  for select using (
    exists (
      select 1 from public.leads
      where leads.id = viewing_appointments.lead_id
        and leads.user_id = auth.uid()
    )
  );
create policy "Anyone can request appointments" on public.viewing_appointments
  for insert with check (true);
create policy "Agents manage appointments" on public.viewing_appointments
  for all
  using (
    exists (
      select 1 from public.agents
      where agents.id = viewing_appointments.agent_id
        and agents.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.agents
      where agents.id = viewing_appointments.agent_id
        and agents.profile_id = auth.uid()
    )
  );

drop policy if exists "Market snapshot is public" on public.market_snapshot;
create policy "Market snapshot is public" on public.market_snapshot
  for select using (true);

grant select on table public.market_snapshot to anon, authenticated;

-- -----------------------------------------------------------------------------
-- Storage — public bucket for listing media
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('listing-media', 'listing-media', true)
on conflict (id) do nothing;

drop policy if exists "Listing media is public" on storage.objects;
drop policy if exists "Authenticated upload listing media" on storage.objects;
drop policy if exists "Owners manage listing media" on storage.objects;
drop policy if exists "Owners delete listing media" on storage.objects;
create policy "Listing media is public" on storage.objects
  for select using (bucket_id = 'listing-media');
create policy "Authenticated upload listing media" on storage.objects
  for insert with check (
    bucket_id = 'listing-media' and auth.role() = 'authenticated'
  );
create policy "Owners manage listing media" on storage.objects
  for update using (
    bucket_id = 'listing-media' and owner = auth.uid()
  )
  with check (
    bucket_id = 'listing-media' and owner = auth.uid()
  );
create policy "Owners delete listing media" on storage.objects
  for delete using (
    bucket_id = 'listing-media' and owner = auth.uid()
  );
