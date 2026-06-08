-- =============================================================================
-- More Properties — Demo seed data (v2)
-- =============================================================================
-- Run this AFTER schema.sql. Idempotent via on conflict do nothing.
-- Mirrors the curated demo dataset that ships inside the Flutter app so the
-- app behaves identically against an empty Supabase project.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Agencies
-- -----------------------------------------------------------------------------
insert into public.agencies (id, name, slug, website, office_phone, verified) values
  ('a0000000-0000-4000-8000-000000000001', 'Northern Suburbs Realty', 'northern-suburbs-realty', 'https://nsr.co.za', '+27 11 555 1000', true),
  ('a0000000-0000-4000-8000-000000000002', 'Atlantic Coast Properties', 'atlantic-coast-properties', 'https://atlanticcoast.co.za', '+27 21 555 2200', true),
  ('a0000000-0000-4000-8000-000000000003', 'Umhlanga Premium', 'umhlanga-premium', 'https://umhlangapremium.co.za', '+27 31 555 3300', true),
  ('a0000000-0000-4000-8000-000000000004', 'Capital Living', 'capital-living', 'https://capitalliving.co.za', '+27 12 555 4400', true),
  ('a0000000-0000-4000-8000-000000000005', 'Winelands Estates', 'winelands-estates', 'https://winelands.co.za', '+27 21 555 5500', true)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Market snapshot (fallback baseline for runtime sync)
-- -----------------------------------------------------------------------------
insert into public.market_snapshot (
  id,
  prime_rate,
  prime_rate_as_of,
  prime_rate_source,
  cape_town_house_price_yoy,
  cape_town_source,
  gauteng_rentals_yoy,
  gauteng_source,
  transfer_duty_effective_label,
  transfer_duty_source,
  transfer_duty_brackets,
  synced_at
) values (
  'za',
  10.50,
  '08 Jun 2026',
  'SARB current market rates',
  '+8.4%',
  'House price index',
  '+5.1%',
  'PayProp rental index',
  'SARS 2025/26',
  'SARS transfer duty rates',
  '[
    {"min_value":1, "max_value":1210000, "base_amount":0, "marginal_rate":0, "threshold":1210000},
    {"min_value":1210001, "max_value":1663800, "base_amount":0, "marginal_rate":0.03, "threshold":1210000},
    {"min_value":1663801, "max_value":2329300, "base_amount":13614, "marginal_rate":0.06, "threshold":1663800},
    {"min_value":2329301, "max_value":2994800, "base_amount":53544, "marginal_rate":0.08, "threshold":2329300},
    {"min_value":2994801, "max_value":13310000, "base_amount":106784, "marginal_rate":0.11, "threshold":2994800},
    {"min_value":13310001, "max_value":null, "base_amount":1241456, "marginal_rate":0.13, "threshold":13310000}
  ]'::jsonb,
  now()
)
on conflict (id) do update set
  prime_rate = excluded.prime_rate,
  prime_rate_as_of = excluded.prime_rate_as_of,
  prime_rate_source = excluded.prime_rate_source,
  cape_town_house_price_yoy = excluded.cape_town_house_price_yoy,
  cape_town_source = excluded.cape_town_source,
  gauteng_rentals_yoy = excluded.gauteng_rentals_yoy,
  gauteng_source = excluded.gauteng_source,
  transfer_duty_effective_label = excluded.transfer_duty_effective_label,
  transfer_duty_source = excluded.transfer_duty_source,
  transfer_duty_brackets = excluded.transfer_duty_brackets,
  synced_at = excluded.synced_at;

-- -----------------------------------------------------------------------------
-- Agents
-- -----------------------------------------------------------------------------
insert into public.agents
  (id, agency_id, display_name, email, phone, area, bio, avatar_url,
   ppra_number, rating, response_minutes, listings_active, verified)
values
  ('b0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000001',
   'Thandi Mokoena', 'thandi@nsr.co.za', '+27 82 555 1011',
   'Sandton & Hyde Park',
   'Luxury residential specialist for Sandhurst, Hyde Park and Houghton with 12 years closing record-breaking deals north of R30m.',
   'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=600',
   'PPRA-2025-NSR-1182', 4.9, 8, 24, true),
  ('b0000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000002',
   'Jaco van der Merwe', 'jaco@atlanticcoast.co.za', '+27 83 224 7890',
   'Atlantic Seaboard',
   'Born and raised in Clifton — Jaco specialises in Bantry Bay, Camps Bay and Llandudno trophy homes.',
   'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600',
   'PPRA-2025-ACP-0945', 4.8, 12, 18, true),
  ('b0000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000003',
   'Priya Naidoo', 'priya@umhlangapremium.co.za', '+27 84 901 3322',
   'KZN North Coast',
   'Zimbali, Umhlanga Ridge and Ballito coastal estates. Trilingual buyer concierge included with every sale.',
   'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=600',
   'PPRA-2025-UMP-2230', 4.95, 6, 31, true),
  ('b0000000-0000-4000-8000-000000000004',
   'a0000000-0000-4000-8000-000000000004',
   'Lerato Dlamini', 'lerato@capitalliving.co.za', '+27 81 408 7754',
   'Pretoria & Centurion',
   'Embassy belt, Waterkloof and Brooklyn — first-time buyer & relocation specialist for the diplomatic corps.',
   'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600',
   'PPRA-2025-CPL-0688', 4.7, 15, 22, true),
  ('b0000000-0000-4000-8000-000000000005',
   'a0000000-0000-4000-8000-000000000005',
   'Sam Petersen', 'sam@winelands.co.za', '+27 82 119 4467',
   'Stellenbosch & Paarl',
   'Boutique wine farms, country estates and Stellenbosch student lets — local network spanning three generations.',
   'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=600',
   'PPRA-2025-WLE-1410', 4.85, 18, 14, true)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Listings
-- -----------------------------------------------------------------------------

-- For sale
insert into public.listings (
  id, agency_id, agent_id, slug, title, description, mode, status,
  property_type, price, province, city, suburb,
  bedrooms, bathrooms, parking, floor_size, erf_size, levy, rates,
  latitude, longitude, hero_image_url, gallery_urls,
  lifestyle_features, security_features, resilience_features,
  load_shedding_score, safety_score, school_score, lifestyle_score,
  energy_rating, is_featured, is_verified, published_at
) values
(
  'c0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000002',
  'b0000000-0000-4000-8000-000000000002',
  'clifton-edge', 'Cliffside glass villa with ocean panorama',
  'Architect-designed five-bedroom glass villa cantilevered above Clifton Fourth. Infinity-edge pool, private cinema, wine cellar and direct beach lift access. Generator + 30kWh battery backup with full solar PV.',
  'buy', 'active', 'House', 87500000, 'Western Cape', 'Cape Town', 'Clifton',
  5, 5, 4, 720, 950, null, 14500,
  -33.937, 18.378,
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1400',
  array[
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=1400',
    'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1400',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1400'
  ],
  array['Pool', 'Sea view', 'Wine cellar', 'Home office'],
  array['24h estate security', 'Beams & sensors', 'Armed response', 'Biometric access', 'CCTV monitored'],
  array['Solar PV', 'Inverter & batteries', 'Generator', 'Gas hob', 'JoJo tanks', 'EV charger'],
  10, 9, 9, 10, 'A', true, true, now() - interval '2 days'
),
(
  'c0000000-0000-4000-8000-000000000002',
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'sandhurst-mansion', 'Sandhurst mansion with 4-suite guest wing',
  'Walled Sandhurst estate on 4 400m² with championship tennis court, full gym, staff suite, double-volume entertainment pavilion and a 100kW backup plant. Trophy-class executive lifestyle.',
  'buy', 'active', 'Estate Home', 64900000, 'Gauteng', 'Sandton', 'Sandhurst',
  7, 8, 6, 1180, 4400, null, 18900,
  -26.103, 28.052,
  'https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=1400',
  array[
    'https://images.unsplash.com/photo-1600573472556-e636c2acda88?w=1400',
    'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=1400',
    'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400'
  ],
  array['Pool', 'Garden', 'Gym', 'Wine cellar'],
  array['24h estate security', 'Electric fencing', 'Beams & sensors', 'Armed response', 'CCTV monitored'],
  array['Solar PV', 'Inverter & batteries', 'Generator', 'Borehole', 'JoJo tanks'],
  10, 9, 10, 9, 'A', true, true, now() - interval '5 days'
),
(
  'c0000000-0000-4000-8000-000000000003',
  'a0000000-0000-4000-8000-000000000003',
  'b0000000-0000-4000-8000-000000000003',
  'umhlanga-pearls', 'Pearls of Umhlanga sky-suite',
  'North-facing sky-suite in Pearls of Umhlanga with 270 degree ocean views, private plunge pool and concierge service. Bring your toothbrush — sold fully furnished.',
  'buy', 'active', 'Penthouse', 19500000, 'KwaZulu-Natal', 'Umhlanga', 'Umhlanga Ridge',
  4, 4, 4, 360, null, 14200, 6800,
  -29.732, 31.082,
  'https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=1400',
  array[
    'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400',
    'https://images.unsplash.com/photo-1600573472556-e636c2acda88?w=1400'
  ],
  array['Pool', 'Sea view', 'Concierge', 'Gym'],
  array['24h estate security', 'Biometric access', 'CCTV monitored'],
  array['Generator', 'Gas hob', 'JoJo tanks'],
  8, 9, 8, 10, 'B', true, true, now() - interval '1 day'
),
(
  'c0000000-0000-4000-8000-000000000004',
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'waterfall-family', 'Family home on the green in Waterfall Estate',
  'Pristine cluster overlooking the 7th green with eco-friendly pool, full solar + battery and dedicated home-office wing. Walk to Mall of Africa and the Reddam House campus.',
  'buy', 'active', 'Cluster', 14750000, 'Gauteng', 'Midrand', 'Waterfall Estate',
  5, 4, 3, 510, 920, 6200, 4100,
  -26.012, 28.108,
  'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1400',
  array[
    'https://images.unsplash.com/photo-1600585152915-d208bec867a1?w=1400',
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=1400'
  ],
  array['Pool', 'Garden', 'Home office', 'Pet friendly'],
  array['24h estate security', 'Electric fencing', 'Beams & sensors', 'Boomed-off precinct'],
  array['Solar PV', 'Inverter & batteries', 'Gas hob', 'JoJo tanks'],
  9, 10, 9, 9, 'A', false, true, now() - interval '4 days'
),
(
  'c0000000-0000-4000-8000-000000000005',
  'a0000000-0000-4000-8000-000000000005',
  'b0000000-0000-4000-8000-000000000005',
  'stellenbosch-estate', 'Working wine estate in Banhoek Valley',
  '22-hectare boutique wine farm with 6-bedroom Cape Dutch manor house, working cellar producing 18 000 bottles per year, tasting room, two guest cottages and views over Helderberg.',
  'buy', 'active', 'Farm', 42000000, 'Western Cape', 'Stellenbosch', 'Banhoek',
  6, 5, 8, 850, 220000, null, 8900,
  -33.916, 18.910,
  'https://images.unsplash.com/photo-1505228395891-9a51e7e86bf6?w=1400',
  array[
    'https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=1400',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1400'
  ],
  array['Pool', 'Garden', 'Wine cellar', 'Mountain view'],
  array['Electric fencing', 'Beams & sensors', 'Armed response'],
  array['Solar PV', 'Inverter & batteries', 'Generator', 'Borehole', 'JoJo tanks', 'Greywater system'],
  10, 7, 8, 10, 'A', true, true, now() - interval '9 days'
),
(
  'c0000000-0000-4000-8000-000000000006',
  'a0000000-0000-4000-8000-000000000004',
  'b0000000-0000-4000-8000-000000000004',
  'waterkloof-classic', 'Classic Waterkloof family residence',
  'Charming jacaranda-shaded home in old Waterkloof with sprawling garden, separate flatlet, generator and an entertainer''s lapa. Walk-to-school catchment for premier private schools.',
  'buy', 'active', 'House', 8950000, 'Gauteng', 'Pretoria', 'Waterkloof',
  4, 3, 3, 460, 1850, null, 4800,
  -25.795, 28.236,
  'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1400',
  array[
    'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1400',
    'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=1400'
  ],
  array['Garden', 'Pool', 'Pet friendly', 'Domestic quarters'],
  array['Electric fencing', 'Beams & sensors', 'Armed response', 'CCTV monitored'],
  array['Solar PV', 'Inverter & batteries', 'Generator', 'Gas hob'],
  8, 8, 10, 8, 'B', false, true, now() - interval '6 days'
),

-- Rentals
(
  'c0000000-0000-4000-8000-000000000007',
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'rent-sandton-apartment', 'Designer 2-bed at The Leonardo',
  '32nd-floor designer apartment in Africa''s tallest building. Concierge, sky-pool, gym, valet. Generator + UPS — work-from-home through any stage of load shedding.',
  'rent', 'active', 'Apartment', 38500, 'Gauteng', 'Sandton', 'Sandton CBD',
  2, 2, 2, 145, null, null, null,
  null, null,
  'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1400',
  array[
    'https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=1400',
    'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400'
  ],
  array['Concierge', 'Gym', 'Pool', 'Home office'],
  array['24h estate security', 'Biometric access', 'CCTV monitored'],
  array['Generator', 'Inverter & batteries', 'Gas hob'],
  10, 9, 7, 10, 'A', true, true, now() - interval '3 days'
),
(
  'c0000000-0000-4000-8000-000000000008',
  'a0000000-0000-4000-8000-000000000002',
  'b0000000-0000-4000-8000-000000000002',
  'rent-seapoint-loft', 'Sea Point promenade-facing loft',
  'North-facing loft a Frisbee from the promenade. Open-plan kitchen, gas hob, full backup power, secure parking and a rooftop pool.',
  'rent', 'active', 'Apartment', 27500, 'Western Cape', 'Cape Town', 'Sea Point',
  1, 1, 1, 78, null, null, null,
  null, null,
  'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1400',
  array['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1400'],
  array['Sea view', 'Pool', 'Pet friendly'],
  array['24h estate security', 'Biometric access'],
  array['Inverter & batteries', 'Gas hob'],
  8, 8, 7, 9, 'B', false, true, now() - interval '1 day'
),
(
  'c0000000-0000-4000-8000-000000000009',
  'a0000000-0000-4000-8000-000000000005',
  'b0000000-0000-4000-8000-000000000005',
  'rent-stellenbosch-cottage', 'Garden cottage in Mostertsdrift',
  'Quiet university-area cottage with mountain views, fully fenced garden and inverter-backed power. Pet-friendly with a 12-month minimum.',
  'rent', 'active', 'Townhouse', 18900, 'Western Cape', 'Stellenbosch', 'Mostertsdrift',
  2, 1, 1, 95, null, null, null,
  null, null,
  'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400',
  array['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1400'],
  array['Garden', 'Mountain view', 'Pet friendly'],
  array['Electric fencing', 'Armed response'],
  array['Inverter & batteries', 'Gas hob'],
  7, 8, 9, 8, 'B', false, true, now() - interval '7 days'
),

-- Developments
(
  'c0000000-0000-4000-8000-000000000010',
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'dev-steyn-city', 'Steyn City Park — phase 7 launch',
  'Off-plan 1 & 2 bed units inside SA''s flagship lifestyle resort. No transfer duty, 100% solar microgrid, 30km of MTB trails and access to The Capital concierge.',
  'developments', 'active', 'Apartment', 4850000, 'Gauteng', 'Midrand', 'Steyn City',
  2, 2, 2, 115, null, 3200, null,
  null, null,
  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1400',
  array['https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=1400'],
  array['Pool', 'Gym', 'Concierge', 'Home office'],
  array['24h estate security', 'Boomed-off precinct'],
  array['Solar PV', 'Inverter & batteries', 'Borehole'],
  10, 10, 9, 10, 'A', true, true, now() - interval '10 days'
),
(
  'c0000000-0000-4000-8000-000000000011',
  'a0000000-0000-4000-8000-000000000003',
  'b0000000-0000-4000-8000-000000000003',
  'dev-zimbali-lakes', 'Zimbali Lakes — beach-club residences',
  'Designer beach-club residences inside Zimbali Lakes Resort. 10%% deposit secures launch pricing, includes membership to the new Mark Mulligan-designed golf course.',
  'developments', 'active', 'Apartment', 5750000, 'KwaZulu-Natal', 'Ballito', 'Zimbali',
  3, 2, 2, 142, null, 3800, null,
  null, null,
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1400',
  array['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1400'],
  array['Pool', 'Sea view', 'Concierge'],
  array['24h estate security', 'Boomed-off precinct'],
  array['Solar PV', 'Inverter & batteries'],
  9, 10, 8, 10, 'A', false, true, now() - interval '12 days'
),

-- Commercial (price stored as R/m² per month)
(
  'c0000000-0000-4000-8000-000000000012',
  'a0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000001',
  'comm-rosebank', 'Rosebank P-grade office floor',
  'Premium-grade office in 144 Oxford. 4-star Green Star rated, full backup, fibre redundancy and Gautrain at the door.',
  'commercial', 'active', 'Office', 220, 'Gauteng', 'Johannesburg', 'Rosebank',
  0, 4, 24, 1180, null, null, null,
  null, null,
  'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1400',
  array['https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1400'],
  array['Home office', 'Gym'],
  array['24h estate security', 'Biometric access', 'CCTV monitored'],
  array['Solar PV', 'Generator', 'Inverter & batteries'],
  10, 9, 6, 9, 'A', false, true, now() - interval '8 days'
),
(
  'c0000000-0000-4000-8000-000000000013',
  'a0000000-0000-4000-8000-000000000002',
  'b0000000-0000-4000-8000-000000000002',
  'comm-cape-town-retail', 'V&A Waterfront retail flagship',
  'Rare flagship retail opportunity on the V&A promenade. Triple-volume frontage, 24m of glazing, footfall in excess of 1.4m visitors per month.',
  'commercial', 'active', 'Retail', 850, 'Western Cape', 'Cape Town', 'V&A Waterfront',
  0, 2, 8, 340, null, null, null,
  null, null,
  'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?w=1400',
  array['https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1400'],
  array['Sea view', 'Concierge'],
  array['24h estate security', 'CCTV monitored', 'Armed response'],
  array['Generator', 'Solar PV'],
  10, 10, 7, 10, 'A', true, true, now() - interval '14 days'
)
on conflict (id) do nothing;
