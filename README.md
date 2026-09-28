# GOT9 Phase 1 MVP — ปลูก-รับรอง-แปรรูป-เที่ยว ใน QR เดียว

Pilot: 20 แปลง ภูเรือ จ.เลย | Thai + English | Mock payment + mock OTP

## โครงสร้าง
```
lib/
  main.dart            entry (Hive + Supabase init + seed)
  app.dart             router (go_router) + theme + TH/EN + A-/A/A+
  core/                constants, thai_units, kml_parser, money, pdpa
  data/                models, app_state (store), supabase_service, hive_cache
  features/auth        /auth (OTP mock 123456 + role F/B/C + PDPA consent)
  features/farmer      /farmer/home (plots + QR), /farmer/log (6 PGS)
                       /farmer/plot/add (เมนู 4 ช่องทาง), /draw (วาดแผนที่),
                       /walk (เดินเก็บ GPS), /manual (กรอกไร่-งาน-วา+รูปเอกสารสิทธิ์)
  features/shop        /shop (Yield Buffer 70% + receipt mock)
  features/workshop    /workshop (30% deposit + QR ticket)
  features/trace       /trace/{plot_id} (public, no login)
  features/corporate   /corporate (B2B + VAT invoice mock)
  features/admin       /admin/verify (village + agri approve)
  features/profile     /profile (แก้ชื่อ/เบอร์/รูปโปรไฟล์, ปุ่ม 👤 บนทุกหน้า)
  l10n/strings.dart    TH/EN
supabase/migrations.sql  Postgres schema + RLS + seed
assets/sample_ling.kml   2 แปลงตัวอย่างนำเข้าจาก Ling
```

## วิธีรัน
```powershell
# 1) ติดตั้ง Flutter 3.47+ (ครั้งแรกครั้งเดียว)
#    แตก zip ลง D:\devtools\flutter แล้วเพิ่ม D:\devtools\flutter\bin ใน PATH

# 2) ในโฟลเดอร์โปรเจกต์
flutter pub get
flutter run            # เลือก Chrome / Edge รันเป็น Web ได้ทันที
flutter analyze        # ต้องผ่านแบบ no errors
flutter test           # unit tests (money + KML + thai units)
```

ต่อ Supabase จริง (ไม่บังคับ — ค่า default คือ MOCK):
```powershell
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```
แล้วรัน `supabase/migrations.sql` ใน SQL editor + สร้าง Storage buckets (public read): `organic-photos`, `avatars`, `product-photos`

รูปสินค้า: farmer กดไอคอนกล้องบนรูปสินค้าของฟาร์มตัวเองใน /shop ได้ (บีบอัด <2MB เหมือนกัน)

## Demo accounts (OTP mock: `123456`)
| Role | เบอร์ | เข้าแล้วไปหน้า |
|---|---|---|
| F-ID farmer | 0811111111 | /farmer/home (แปลง PLOT-00001 โฉนด, รับรองแล้ว) |
| B-ID buyer | 0822222222 | /shop |
| C-ID corporate | 0333333333 | /corporate |
| F-ID คทช. (รอรับรอง) | 0811111113 | /farmer/home (PLOT-00003) |

ติ๊ก ✅ PDPA consent ก่อนปุ่ม login จะกดได้

## Test checklist (20 แปลงนำร่อง)
- [ ] Import `assets/sample_ling.kml` → ได้ 2 แปลง (แปลงละ ~55 ไร่), net < gross (หัก buffer 2 ม.)
- [ ] สร้าง log + ถ่ายรูป → ไฟล์ <2MB (ดูขนาดใต้รูป), ขึ้น "รอ sync", Hive queue +1
- [ ] สั่ง P-03 (harvest 100, sold 90, buffer 70 → ขายได้สูงสุด 30): สั่งเกินแล้วโดน block พร้อมข้อความ Yield Buffer
- [ ] จอง W-01 (booked 11/12): จอง 2 ท่านโดน block, จอง 1 ท่านได้ + QR ticket + มัดจำ ฿119.70
- [ ] สแกน QR `got9://trace/PLOT-00001` → เปิด trace โดยไม่ต้อง login, พิกัดเบลอระดับตำบล
- [ ] /admin/verify: กดรับรองผู้ใหญ่บ้าน + เกษตรอำเภอให้ PLOT-00003 → badge เปลี่ยนเป็น verified
- [ ] สลับ TH/EN + กด A+/A- ฟอนต์ขยายทั้งแอป
- [ ] `flutter analyze` → No issues found

## ของที่ห้ามใน V1 (ตามสเปก — อย่าเพิ่ม)
Escrow, Cold Chain API, IoT MQTT, AI พยากรณ์โรค, RAG, OCR reward, ภาษาที่ 3-4, Dark mode, Live gifting, ประวัติ 30 ปี (โชว์ Year 1 เท่านั้น), Offline-first เต็มรูปแบบ (มีแค่ Hive cache + queue)
