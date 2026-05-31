-- More Properties Supabase schema
-- Run this first in the Supabase SQL editor.

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

create type public.user_role as enum ('buyer', 'renter', 'agent', 'agency_admin', 'admin');
create type public.listing_mode as enum ('buy', 'rent', 'developments', 'commercial');
create type public.listing_status as enum ('draft', 'active', 'under_offer', 'sold', 'rented', 'archived');
create type public.lead_status as enum ('new', 'contacted', 'viewing_booked', 'qualified', 'closed', 'lost');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'buyer',
  full_name text,
  phone text,
  avatar_url text,
  preferred_city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.agencies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  logo_url text,
  website text,
  office_phone text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.agents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  agency_id uuid references public.agencies(id) on delete cascade,
  display_name text not null,
  email text not null,
  phone text not null,
  area text not null,
  bio text,
  avatar_url text,
  rating numeric(2,1) not null default 5.0,
  response_minutes int not null default 30,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.listings (
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
  virtual_tour_url text,
  video_url text,
  features text[] not null default '{}',
  amenities text[] not null default '{}',
  is_featured boolean not null default false,
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

create table public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  image_url text not null,
  alt_text text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.favourites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  criteria jsonb not null default '{}'::jsonb,
  cadence text not null default 'instant' check (cadence in ('instant', 'daily', 'weekly')),
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.leads (
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.viewing_appointments (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  agent_id uuid references public.agents(id) on delete set null,
  requested_for timestamptz not null,
  status text not null default 'requested' check (status in ('requested', 'confirmed', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create table public.listing_views (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  anonymous_id text,
  source text,
  viewed_at timestamptz not null default now()
);

create index listings_mode_status_idx on public.listings(mode, status);
create index listings_price_idx on public.listings(price);
create index listings_location_idx on public.listings(province, city, suburb);
create index listings_search_idx on public.listings using gin(search_vector);
create index leads_agent_status_idx on public.leads(agent_id, status, created_at desc);
create index listing_views_listing_idx on public.listing_views(listing_id, viewed_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger listings_updated_at before update on public.listings for each row execute function public.set_updated_at();
create trigger leads_updated_at before update on public.leads for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.search_listings(
  query_text text default '',
  mode_filter public.listing_mode default null,
  min_price numeric default null,
  max_price numeric default null,
  city_filter text default null,
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
    and (min_price is null or price >= min_price)
    and (max_price is null or price <= max_price)
    and (city_filter is null or city ilike city_filter)
    and (query_text = '' or search_vector @@ plainto_tsquery('english', query_text))
  order by is_featured desc, published_at desc nulls last, created_at desc
  limit limit_count;
$$;

alter table public.profiles enable row level security;
alter table public.agencies enable row level security;
alter table public.agents enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.favourites enable row level security;
alter table public.saved_searches enable row level security;
alter table public.leads enable row level security;
alter table public.viewing_appointments enable row level security;
alter table public.listing_views enable row level security;

create policy "Profiles are readable by owner" on public.profiles for select using (auth.uid() = id);
create policy "Profiles are editable by owner" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "Agencies are public" on public.agencies for select using (true);
create policy "Agents are public" on public.agents for select using (true);
create policy "Active listings are public" on public.listings for select using (status = 'active');
create policy "Listing images are public" on public.listing_images for select using (true);

create policy "Users manage their favourites" on public.favourites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their saved searches" on public.saved_searches for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Anyone can create leads" on public.leads for insert with check (true);
create policy "Users read own leads" on public.leads for select using (auth.uid() = user_id);
create policy "Agents read assigned leads" on public.leads for select using (
  exists (select 1 from public.agents where agents.id = leads.agent_id and agents.profile_id = auth.uid())
);
create policy "Agents update assigned leads" on public.leads for update using (
  exists (select 1 from public.agents where agents.id = leads.agent_id and agents.profile_id = auth.uid())
);

create policy "Anyone can record listing views" on public.listing_views for insert with check (true);
create policy "Agents read listing views" on public.listing_views for select using (
  exists (
    select 1 from public.listings
    join public.agents on agents.id = listings.agent_id
    where listings.id = listing_views.listing_id and agents.profile_id = auth.uid()
  )
);

create policy "Users read their appointments" on public.viewing_appointments for select using (
  exists (select 1 from public.leads where leads.id = viewing_appointments.lead_id and leads.user_id = auth.uid())
);
create policy "Agents manage appointments" on public.viewing_appointments for all using (
  exists (select 1 from public.agents where agents.id = viewing_appointments.agent_id and agents.profile_id = auth.uid())
);

insert into storage.buckets (id, name, public)
values ('listing-media', 'listing-media', true)
on conflict (id) do nothing;

create policy "Listing media is public" on storage.objects for select using (bucket_id = 'listing-media');
create policy "Authenticated users can upload listing media" on storage.objects for insert with check (bucket_id = 'listing-media' and auth.role() = 'authenticated');
