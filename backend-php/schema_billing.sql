-- GOT9 billing — ดัดแปลงจากต้นแบบ Vikala Pro ให้เข้ากับแพลตฟอร์ม
-- หลักที่ดัดแปลง: หลายบริษัท -> หลายฟาร์มผู้ขาย (sellers), VAT ตาม Blueprint
--   (VAT 7% เฉพาะผู้ขายจด VAT; ฟาร์มบุคคลธรรมดาไม่จด VAT ออกใบกำกับภาษีไม่ได้)
-- วิธีใช้: import ต่อจาก schema.sql ใน phpMyAdmin (ไฟล์นี้พึ่งตาราง users อยู่แล้ว)

CREATE TABLE IF NOT EXISTS sellers (
  id VARCHAR(16) PRIMARY KEY,              -- F-00001 (ฟาร์ม) หรือ GREENICA (แพลตฟอร์ม)
  name VARCHAR(150) NOT NULL,
  tax_id VARCHAR(13) NULL,
  is_vat_registered TINYINT(1) NOT NULL DEFAULT 0,
  logo_url TEXT NULL,
  addr VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ทะเบียนลูกค้า "กลาง" ใช้ร่วมกันทุกฟาร์ม (ค้นด้วยชื่อ/Tax ID) — เพิ่ม/แก้ไขได้อย่างเดียว ห้ามลบ
CREATE TABLE IF NOT EXISTS customers (
  id VARCHAR(16) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  tax_id VARCHAR(13) NULL,
  phone VARCHAR(20) NULL,
  addr VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_cust_name (name),
  INDEX idx_cust_tax (tax_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ตัวนับเลขที่เอกสาร แยกตามผู้ขาย+ประเภท+ปี (รันเลขไม่มีชน)
CREATE TABLE IF NOT EXISTS doc_counters (
  seller_id VARCHAR(16) NOT NULL,
  doc_type VARCHAR(12) NOT NULL,
  yy CHAR(2) NOT NULL,
  last_no INT NOT NULL DEFAULT 0,
  PRIMARY KEY (seller_id, doc_type, yy)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS documents (
  id VARCHAR(16) PRIMARY KEY,
  seller_id VARCHAR(16) NOT NULL,
  customer_id VARCHAR(16) NULL,            -- NULL = ลูกค้าทั่วไป (ใบกำกับอย่างย่อ)
  order_id VARCHAR(16) NULL,               -- ผูกกับ orders ของ GOT9 (ถ้ามี)
  doc_type VARCHAR(12) NOT NULL,           -- invoice | receipt | tax | abbreviated
  doc_no VARCHAR(40) NOT NULL,             -- เช่น F00001-TAX-680001
  issue_date DATE NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL,
  vat DECIMAL(12,2) NOT NULL DEFAULT 0,
  withholding DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL,
  status VARCHAR(12) NOT NULL DEFAULT 'issued',  -- issued | cancelled
  cancel_reason VARCHAR(255) NULL,
  created_by VARCHAR(16) NULL,             -- user_id คนออก (ดูในรายงาน)
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_doc_no (seller_id, doc_no),
  INDEX idx_docs_seller_date (seller_id, issue_date),
  INDEX idx_docs_status (status),
  CONSTRAINT fk_docs_seller FOREIGN KEY (seller_id) REFERENCES sellers(id),
  CONSTRAINT fk_docs_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT chk_doctype CHECK (doc_type IN ('invoice','receipt','tax','abbreviated')),
  CONSTRAINT chk_docstatus CHECK (status IN ('issued','cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS document_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doc_id VARCHAR(16) NOT NULL,
  description VARCHAR(255) NOT NULL,
  qty DECIMAL(10,2) NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  INDEX idx_items_doc (doc_id),
  CONSTRAINT fk_items_doc FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============ SEED ============
-- ฟาร์ม = ผู้ขายบุคคลธรรมดา (ไม่จด VAT) / แพลตฟอร์ม = นิติบุคคลจด VAT (ออกใบกำกับค่า GP ในอนาคต)
INSERT IGNORE INTO sellers (id, name, tax_id, is_vat_registered, addr) VALUES
  ('F-00001','ไร่ภูเรือเหนือ (F-00001)', NULL, 0, 'ภูเรือ จ.เลย'),
  ('F-00002','สวนหลังหมู่บ้าน (F-00002)', NULL, 0, 'ภูเรือ จ.เลย'),
  ('F-00003','แปลง คทช. ห้วยไผ่ (F-00003)', NULL, 0, 'ภูเรือ จ.เลย'),
  ('GREENICA','Greenica OrgaTech (รอจดบริษัท)', NULL, 0, '-');

INSERT IGNORE INTO customers (id, name, tax_id, phone) VALUES
  ('CU-WALKIN','ลูกค้าทั่วไป (walk-in)', NULL, NULL),
  ('CU-HOTEL1','โรงแรมภูเรือ', '0123456789012', '0333333333');
