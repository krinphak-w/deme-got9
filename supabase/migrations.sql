-- GOT9 Phase 1 MVP — Supabase Postgres migrations
-- Run: supabase db push  (or paste into SQL editor)

-- ============ TABLES ============
create table if not exists users (
  id text primary key,               -- F-00001 / B-00001 / C-00001
  role text not null check (role in ('F','B','C')),
  display_name text not null,
  phone text not null,
  kyc_status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists farm_plots (
  id text primary key,               -- PLOT-00001
  owner_fid text not null references users(id),
  plot_name text not null,
  geom_geojson jsonb not null,       -- GeoJSON Polygon (WGS84)
  area_gross_rai numeric not null,
  area_net_rai numeric not null,     -- after buffer subtraction
  ling_source_id text,
  land_type text not null default 'chanote'
    check (land_type in ('chanote','spk','khor_tor_chor')),
  verifier_village boolean not null default false,
  verifier_agri_officer boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists organic_logs (
  id text primary key,
  plot_id text not null references farm_plots(id) on delete cascade,
  log_type text not null
    check (log_type in ('seed','input','cleaning','harvest','activity','neighbor')),
  detail_json jsonb not null default '{}'::jsonb,
  photo_url text,
  log_date timestamptz not null default now()
);

create table if not exists products (
  id text primary key,
  farm_id text not null references farm_plots(id) on delete cascade,
  name text not null,
  price numeric not null,
  cost numeric not null,
  stock_buffer_pct numeric not null default 70,
  active boolean not null default true
);

create table if not exists orders (
  id text primary key,
  buyer_bid text not null references users(id),
  items_json jsonb not null default '[]'::jsonb,
  total numeric not null,
  gp_fee numeric not null,
  status text not null default 'pending'
    check (status in ('pending','paid','preparing','shipped','done'))
);

create table if not exists workshops (
  id text primary key,
  title text not null,
  price numeric not null default 399,
  capacity int not null check (capacity between 4 and 12),
  date_time timestamptz not null,
  booked_count int not null default 0,
  status text not null default 'open'
);

create table if not exists bookings (
  id text primary key,
  workshop_id text not null references workshops(id) on delete cascade,
  buyer_bid text not null references users(id),
  persons int not null default 1,
  deposit_30 numeric not null,
  status text not null default 'confirmed'
);

-- ============ RLS (open read for public trace; writes via service role in V1) ============
alter table users enable row level security;
alter table farm_plots enable row level security;
alter table organic_logs enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table workshops enable row level security;
alter table bookings enable row level security;

create policy "public read plots" on farm_plots for select using (true);
create policy "public read logs" on organic_logs for select using (true);
create policy "public read products" on products for select using (true);
create policy "public read workshops" on workshops for select using (true);

-- ============ SEED (3 farms, 5 products, 2 workshops, 1 corporate) ============
insert into users (id, role, display_name, phone, kyc_status) values
  ('F-00001','F','เกษตรกร ภูเรือเหนือ','0811111111','verified'),
  ('F-00002','F','เกษตรกร สวนหลังหมู่บ้าน','0811111112','verified'),
  ('F-00003','F','เกษตรกร ห้วยไผ่ (คทช.)','0811111113','pending'),
  ('B-00001','B','นักท่องเที่ยว ตัวอย่าง','0822222222','verified'),
  ('C-00001','C','โรงแรมภูเรือ (ตัวอย่าง)','0333333333','verified')
on conflict (id) do nothing;

insert into farm_plots (id, owner_fid, plot_name, geom_geojson, area_gross_rai, area_net_rai, ling_source_id, land_type, verifier_village, verifier_agri_officer) values
  ('PLOT-00001','F-00001','ไร่ภูเรือเหนือ',
   '{"type":"Polygon","coordinates":[[[101.3650,17.4105],[101.3680,17.4105],[101.3680,17.4080],[101.3650,17.4080],[101.3650,17.4105]]]}',
   55.30, 53.82, 'seed-ling#1', 'chanote', true, true),
  ('PLOT-00002','F-00002','สวนหลังหมู่บ้าน',
   '{"type":"Polygon","coordinates":[[[101.3720,17.4150],[101.3750,17.4150],[101.3750,17.4125],[101.3720,17.4125],[101.3720,17.4150]]]}',
   55.30, 53.82, 'seed-ling#2', 'spk', true, false),
  ('PLOT-00003','F-00003','แปลง คทช. ห้วยไผ่',
   '{"type":"Polygon","coordinates":[[[101.3600,17.4020],[101.3625,17.4020],[101.3625,17.4000],[101.3600,17.4000],[101.3600,17.4020]]]}',
   36.87, 35.66, 'seed-ling#3', 'khor_tor_chor', false, false)
on conflict (id) do nothing;

insert into products (id, farm_id, name, price, cost, stock_buffer_pct) values
  ('P-01','PLOT-00001','สบู่สครับกาแฟ (120g)',135,60,70),
  ('P-02','PLOT-00001','น้ำมันนวดโรลออน (10ml)',199,90,70),
  ('P-03','PLOT-00002','กาแฟคั่วภูเรือ (250g)',280,150,70),
  ('P-04','PLOT-00002','ชาสมุนไพรรวม (20 ซอง)',160,70,70),
  ('P-05','PLOT-00003','ผักสลัดรวมปลอดสาร (500g)',99,45,70)
on conflict (id) do nothing;

insert into workshops (id, title, price, capacity, date_time, booked_count) values
  ('W-01','Workshop ทำโรลออนสมุนไพร',399,12, now() + interval '7 days', 11),
  ('W-02','เดินสวน + ชิมกาแฟภูเรือ',399,8, now() + interval '14 days', 3)
on conflict (id) do nothing;

-- V2: profile avatars + product photos
alter table users add column if not exists avatar_url text;
alter table products add column if not exists photo_url text;

-- V3: multi-channel plot entry (ling/draw/gps_walk/manual + land doc)
alter table farm_plots add column if not exists entry_channel text not null default 'ling';
alter table farm_plots add column if not exists doc_photo_url text;
alter table farm_plots alter column geom_geojson drop not null;
