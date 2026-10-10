# GOT9 backend-php — วิธีเอาขึ้นแชร์โฮสต์ (ไม่ต้องใช้ terminal)

> สเปกโฮสต์: cPanel (134.0.30.x, FTP) • PHP 8.2.31 • MariaDB 10.6.27 (phpMyAdmin)
> โค้ด PHP ล้วน ไม่มี framework ไม่ต้อง composer — อัปโหลดไฟล์แล้วใช้ได้เลย

## ขั้นที่ 1 — สร้างฐานข้อมูล (5 นาที, ใน cPanel)
1. เข้า cPanel → **MySQL Databases** → สร้างฐานข้อมูลชื่อ `got9` (จะได้ชื่อเต็มเช่น `user_got9`)
2. สร้าง MySQL user + ตั้งรหัสผ่าน → **Add User To Database** ติ๊ก **ALL PRIVILEGES**
3. จดไว้: ชื่อฐานข้อมูล / ชื่อ user / รหัสผ่าน

## ขั้นที่ 2 — นำเข้า schema (3 นาที)
1. เข้า **phpMyAdmin** → เลือกฐานข้อมูลที่สร้าง → แท็บ **Import**
2. เลือกไฟล์ `schema.sql` ในโฟลเดอร์นี้ → กด **Go**
3. ต้องได้ 8 ตาราง (`users, farm_plots, organic_logs, products, orders, workshops, bookings, api_tokens`) + ข้อมูลตัวอย่าง

## ขั้นที่ 3 — อัปโหลดไฟล์ (5 นาที)
อัปโหลดไฟล์ทั้งหมดในโฟลเดอร์นี้ไปที่ `public_html/got9-api/` (ผ่าน **File Manager** หรือ FTP):
- `api.php`, `db.php`, `.htaccess`
- `config.php` ← **สร้างจาก `config.example.php`** แล้วกรอก DB_HOST/DB_NAME/DB_USER/DB_PASS + APP_SECRET
- ห้ามอัปโหลด `config.php` ขึ้น git (`.gitignore` กันไว้แล้ว — ตรวจว่ามีบรรทัด `backend-php/config.php`)

## ขั้นที่ 4 — ทดสอบ (2 นาที)
เปิดเบราว์เซอร์:
- `https://โดเมนของคุณ/got9-api/trace/PLOT-00001` → ต้องได้ JSON แปลงตัวอย่าง
- `https://โดเมนของคุณ/got9-api/workshops` → ต้องได้รายการ workshop

ถ้า error 500: เช็ก (1) ชื่อฐานข้อมูลใน config.php (2) import schema แล้วหรือยัง (3) PHP version 8.2 ใน cPanel > Select PHP Version

## รายการ API (JSON ทั้งหมด)
| Method | Path | Auth | หมายเหตุ |
|---|---|---|---|
| POST | `/auth/login` `{role, phone, display_name?}` | — | mock-auth ออกโทเค็น 30 วัน |
| GET | `/me` | Bearer | ข้อมูลตัวเอง |
| GET/POST | `/plots` `?owner=` | POST ต้อง F-ID | สร้างแปลง (คีย์ geom/ไร่-งาน-วา คำนวณฝั่งแอป) |
| PUT | `/plots/{id}/verify` `{by: village\|agri}` | Bearer | รับรองแปลง |
| GET/POST | `/logs` `?plot=` | POST ต้องเจ้าของแปลง | บันทึกกิจกรรม |
| GET | `/products` `?farm=` | — | รายการสินค้า |
| POST | `/orders` `{product_id, qty}` | Bearer | **บังคับ Yield Buffer + คำนวณ GP/VAT ฝั่งเซิร์ฟเวอร์** |
| GET | `/workshops` | — | พร้อม `seats_left` |
| POST | `/workshops/{id}/book` `{persons}` | Bearer | **กันจองเกิน + คำนวณมัดจำ 30%** |
| GET | `/trace/{plot_id}` | — | สาธารณะ (พิกัดเบลอแล้ว) |
| POST | `/upload` (multipart `photo`) | Bearer | jpg/png/webp ≤8MB → `uploads/YYYYMM/` |

## หมายเหตุเฟส 2
- Auth จริง (OTP/LINE), สิทธิ์ verifier แยกตามบทบาท, e-KYC, rate-limit, และ Opn Payments จะมาเติมในไฟล์นี้
- `uploads/` ควรกัน list ไฟล์ + ใส่ cron ลบไฟล์เคลมเกิน 30 วัน (Auto-Delete ตาม Blueprint 7.3)
