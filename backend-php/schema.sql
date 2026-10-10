-- GOT9 Phase 1/2 — MariaDB 10.6 schema (phpMyAdmin import)
-- แปลงจาก supabase/migrations.sql: jsonb->JSON, timestamptz->TIMESTAMP, boolean->TINYINT(1)
-- วิธีใช้: เปิด phpMyAdmin > เลือกฐานข้อมูล > Import > เลือกไฟล์นี้ > Go

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(16) PRIMARY KEY,               -- F-00001 / B-00001 / C-00001
  role CHAR(1) NOT NULL,                    -- F B C
  display_name VARCHAR(120) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  avatar_url TEXT NULL,
  kyc_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_users_role CHECK (role IN ('F','B','C'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS farm_plots (
  id VARCHAR(16) PRIMARY KEY,              -- PLOT-00001
  owner_fid VARCHAR(16) NOT NULL,
  plot_name VARCHAR(150) NOT NULL,
  geom_geojson JSON NULL,                   -- GeoJSON Polygon (WGS84), NULL = กรอกเอง
  area_gross_rai DECIMAL(10,2) NOT NULL,
  area_net_rai DECIMAL(10,2) NOT NULL,
  ling_source_id VARCHAR(120) NULL,
  land_type VARCHAR(20) NOT NULL DEFAULT 'chanote',
  entry_channel VARCHAR(20) NOT NULL DEFAULT 'ling',
  doc_photo_url TEXT NULL,
  verifier_village TINYINT(1) NOT NULL DEFAULT 0,
  verifier_agri_officer TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_land CHECK (land_type IN ('chanote','spk','khor_tor_chor')),
  CONSTRAINT chk_channel CHECK (entry_channel IN ('ling','draw','gps_walk','manual')),
  INDEX idx_plots_owner (owner_fid),
  CONSTRAINT fk_plots_owner FOREIGN KEY (owner_fid) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS organic_logs (
  id VARCHAR(16) PRIMARY KEY,
  plot_id VARCHAR(16) NOT NULL,
  log_type VARCHAR(20) NOT NULL,
  detail_json JSON NOT NULL,
  photo_url TEXT NULL,
  log_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_logtype CHECK (log_type IN ('seed','input','cleaning','harvest','activity','neighbor')),
  INDEX idx_logs_plot (plot_id),
  CONSTRAINT fk_logs_plot FOREIGN KEY (plot_id) REFERENCES farm_plots(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(16) PRIMARY KEY,
  farm_id VARCHAR(16) NOT NULL,
  name VARCHAR(150) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  cost DECIMAL(10,2) NOT NULL,
  photo_url TEXT NULL,
  stock_buffer_pct DECIMAL(5,2) NOT NULL DEFAULT 70.00,
  harvest_qty INT NOT NULL DEFAULT 0,
  sold_qty INT NOT NULL DEFAULT 0,
  active TINYINT(1) NOT NULL DEFAULT 1,
  INDEX idx_products_farm (farm_id),
  CONSTRAINT fk_products_farm FOREIGN KEY (farm_id) REFERENCES farm_plots(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders (
  id VARCHAR(16) PRIMARY KEY,
  buyer_bid VARCHAR(16) NOT NULL,
  items_json JSON NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  gp_fee DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_order_status CHECK (status IN ('pending','paid','preparing','shipped','done')),
  INDEX idx_orders_buyer (buyer_bid),
  CONSTRAINT fk_orders_buyer FOREIGN KEY (buyer_bid) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS workshops (
  id VARCHAR(16) PRIMARY KEY,
  title VARCHAR(150) NOT NULL,
  price DECIMAL(10,2) NOT NULL DEFAULT 399.00,
  capacity INT NOT NULL,
  date_time DATETIME NOT NULL,
  booked_count INT NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'open',
  CONSTRAINT chk_ws_cap CHECK (capacity BETWEEN 4 AND 12)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bookings (
  id VARCHAR(16) PRIMARY KEY,
  workshop_id VARCHAR(16) NOT NULL,
  buyer_bid VARCHAR(16) NOT NULL,
  persons INT NOT NULL DEFAULT 1,
  deposit_30 DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'confirmed',
  INDEX idx_bookings_ws (workshop_id),
  CONSTRAINT fk_book_ws FOREIGN KEY (workshop_id) REFERENCES workshops(id) ON DELETE CASCADE,
  CONSTRAINT fk_book_buyer FOREIGN KEY (buyer_bid) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- โทเค็นล็อกอิน (mock-auth เฟส 1/2: ออกโทเค็นให้หลังเลือก role, หมดอายุ 30 วัน)
CREATE TABLE IF NOT EXISTS api_tokens (
  token VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(16) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_tokens_user (user_id),
  CONSTRAINT fk_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============ SEED (ฟาร์มทดลอง 3 แปลง / สินค้า 5 / workshop 2 / corporate 1) ============
INSERT IGNORE INTO users (id, role, display_name, phone, kyc_status) VALUES
  ('F-00001','F','เกษตรกร ภูเรือเหนือ','0811111111','verified'),
  ('F-00002','F','เกษตรกร สวนหลังหมู่บ้าน','0811111112','verified'),
  ('F-00003','F','เกษตรกร ห้วยไผ่ (คทช.)','0811111113','pending'),
  ('B-00001','B','นักท่องเที่ยว ตัวอย่าง','0822222222','verified'),
  ('C-00001','C','โรงแรมภูเรือ (ตัวอย่าง)','0333333333','verified');

INSERT IGNORE INTO farm_plots (id, owner_fid, plot_name, geom_geojson, area_gross_rai, area_net_rai, ling_source_id, land_type, entry_channel, verifier_village, verifier_agri_officer) VALUES
  ('PLOT-00001','F-00001','ไร่ภูเรือเหนือ',
   '{"type":"Polygon","coordinates":[[[101.3650,17.4105],[101.3680,17.4105],[101.3680,17.4080],[101.3650,17.4080],[101.3650,17.4105]]]}',
   55.30, 53.82, 'seed-ling#1', 'chanote', 'ling', 1, 1),
  ('PLOT-00002','F-00002','สวนหลังหมู่บ้าน',
   '{"type":"Polygon","coordinates":[[[101.3720,17.4150],[101.3750,17.4150],[101.3750,17.4125],[101.3720,17.4125],[101.3720,17.4150]]]}',
   55.30, 53.82, 'seed-ling#2', 'spk', 'ling', 1, 0),
  ('PLOT-00003','F-00003','แปลง คทช. ห้วยไผ่',
   '{"type":"Polygon","coordinates":[[[101.3600,17.4020],[101.3625,17.4020],[101.3625,17.4000],[101.3600,17.4000],[101.3600,17.4020]]]}',
   36.87, 35.66, 'seed-ling#3', 'khor_tor_chor', 'ling', 0, 0);

INSERT IGNORE INTO products (id, farm_id, name, price, cost, stock_buffer_pct, harvest_qty, sold_qty) VALUES
  ('P-01','PLOT-00001','สบู่สครับกาแฟ (120g)',135,60,70,200,40),
  ('P-02','PLOT-00001','น้ำมันนวดโรลออน (10ml)',199,90,70,150,20),
  ('P-03','PLOT-00002','กาแฟคั่วภูเรือ (250g)',280,150,70,100,90),
  ('P-04','PLOT-00002','ชาสมุนไพรรวม (20 ซอง)',160,70,70,120,10),
  ('P-05','PLOT-00003','ผักสลัดรวมปลอดสาร (500g)',99,45,70,300,0);

INSERT IGNORE INTO workshops (id, title, price, capacity, date_time, booked_count) VALUES
  ('W-01','Workshop ทำโรลออนสมุนไพร',399,12, NOW() + INTERVAL 7 DAY, 11),
  ('W-02','เดินสวน + ชิมกาแฟภูเรือ',399,8, NOW() + INTERVAL 14 DAY, 3);
