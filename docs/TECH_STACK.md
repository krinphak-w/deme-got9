# GOT9 Phase 1 — Tech Stack & Environment Report (Production)

> วันที่: 28 ก.ย. 2026 | แหล่งข้อมูล: โค้ดจริงใน repo (branch `main`) + `pubspec.lock`
> สถานะ: **MVP ใช้งานได้ (mock-first)** — backend จริงยังไม่ผูก (ดูช่องว่างข้อ 5)

## 1. Frontend

| ชั้น | เทคโนโลยี | เวอร์ชัน |
|---|---|---|
| Framework | Flutter (stable) | 3.47.5 |
| ภาษา | Dart | 3.13.4 |
| UI | Material 3, ฟอนต์ Prompt, รองรับ TH/EN, ปุ่ม A-/A/A+ (rem scaling) | — |
| State | `provider` (ChangeNotifier `AppState`) | 6.1.5+1 |
| Routing | `go_router` (deep-link `/trace/:id`, guard login) | 16.3.0 |
| แผนที่ | `flutter_map` (OSM tiles) + `latlong2` | 7.0.2 / 0.9.1 |
| QR | `qr_flutter` (สร้าง) + `mobile_scanner` (สแกน) | 4.1.0 / 7.4.2 |
| รูปภาพ | `image_picker` + `image` (บีบอัด <2MB) + `file_picker` (KML/KMZ) | 1.1.3 / 4.10.1 / 10.3.10 |
| GPS | `geolocator` (เดินรอบแปลง) | 14.0.2 |
| เก็บข้อมูลเครื่อง | `hive_ce` + `hive_ce_flutter` (plots/logs/queue) + `shared_preferences` (draft/prefs → localStorage บนเว็บ) | 2.20.1 / 2.4.0 / 2.5.5 |
| เครือข่าย | `http` (Open-Meteo) | 1.6.0 |
| ลิงก์ภายนอก | `url_launcher` (LINE OA), `share_plus` | 6.3.2 / 11.1.0 |
| วันที่/โซนเวลา | `intl` + `timezone` (Asia/Bangkok) | 0.20.3 / 0.10.1 |
| KML/KMZ | `xml` + `archive` (parse เองใน `lib/core/kml_parser.dart`) | 6.6.1 / 4.3.0 |
| Lint/Test | `flutter_lints`, `flutter_test` (9 tests ผ่าน) | — |

**Build targets**: Web (release ใช้งานจริง), Android/iOS (โค้ดพร้อม ยังไม่เคย build จริงจัง — ต้องทำก่อนลงเครื่องเกษตรกร)
**Bundle ปัจจุบัน**: `main.dart.js` ~5.1 MB (release, tree-shaken)

## 2. Backend

| ชั้น | เทคโนโลยี | สถานะ |
|---|---|---|
| Database | PostgreSQL ผ่าน **Supabase** (สคีมาใน `supabase/migrations.sql`) | มีไฟล์ migration, **ยังไม่สร้าง project จริง** |
| ตาราง (7) | `users, farm_plots, organic_logs, products, orders, workshops, bookings` (+คอลัมน์ V2/V3: avatar/photo/entry_channel/doc) | พร้อมรัน |
| Auth | ออกแบบใช้ Supabase Auth (OTP จริงในเฟส 2) — **ปัจจุบัน mock `123456`** | mock |
| Storage | buckets ที่ต้องสร้าง: `organic-photos, avatars, product-photos` (public read) | ยังไม่สร้าง |
| RLS | public read plots/logs/products/workshops; write ผ่าน service role (V1) | ในไฟล์แล้ว |
| Realtime/Edge Functions | ไม่ใช้ในเฟส 1 | — |
| SDK ฝั่งแอป | `supabase_flutter` (+`supabase, postgrest, gotrue, storage_client`) | 2.17.2 / 2.16.1 / 2.9.1 / 2.27.2 / 2.8.0 |
| โหมดปัจจุบัน | **MOCK** (keys ว่าง → seed data ในเครื่อง + Hive) | ดู `lib/data/supabase_service.dart` |

**Third-party APIs**: Open-Meteo (อากาศฟรี ไม่ใช้ key), OSM tiles (แผนที่ฟรี), LINE OA deep-link (`@got9farm`), Ling (import ไฟล์ KML/KMZ — ยังไม่มี API/MOU)

## 3. Environments

| Env | Frontend | Backend | URL |
|---|---|---|---|
| Dev (local) | `flutter run -d web-server --web-port 8080` (debug) | mock/Hive | http://localhost:8080 |
| Prod (static) | `flutter build web --release --base-href /deme-got9/` → branch `gh-pages` (+`404.html` fallback สำหรับ SPA routes) | mock/Hive (ชุดเดียวกัน) | https://krinphak-w.github.io/deme-got9/ |
| Prod backend (แผน) | — | สร้าง Supabase project → รัน migrations → ใส่ keys ผ่าน `--dart-define=SUPABASE_URL=... SUPABASE_ANON_KEY=...` → rebuild | — |

**Secrets**: ไม่มี secret ใน repo (`.gitignore` กัน `.env`; token deploy ล้างแล้ว) — keys ใส่ตอน build ผ่าน dart-define เท่านั้น

## 4. Toolchain & Repo

- Repo: `github.com/krinphak-w/deme-got9` (public) — `main` = source, `gh-pages` = static deploy
- SDK: Flutter 3.47.5 ที่ `D:\devtools\flutter` | git: PortableGit 2.55.0 ที่ `D:\devtools\PortableGit` | deploy: `gh` CLI
- CI/CD: **manual** (ยังไม่มี GitHub Actions) — ขั้นตอน: analyze → test → build → copy 404 → push `gh-pages`
- OS เครื่อง dev: Windows 11

## 5. ช่องว่างก่อน Production จริง (เรียงตามต้องทำก่อน)

1. **สร้าง Supabase project + รัน migrations + สร้าง 3 buckets** (P0 — 1 วัน)
2. **OTP/จ่ายเงินจริง** (P0 เฟส 2 — ปัจจุบัน mock ทั้งคู่ รับเงินจริงไม่ได้)
3. **Build + เทสต์ Android บนเครื่องจริง** โดยเฉพาะ GPS walk และกล้อง (P0)
4. **e-KYC + PDPA เต็ม + ทนาย Fintech** (P0 ตามแผนเฟส 2)
5. **Monitoring**: ยังไม่มี crash reporting/analytics (แนะนำ Sentry + Posthog ภายหลัง)
6. **CI**: ทำ GitHub Actions (analyze+test+build+deploy) กัน deploy มือพลาด
7. OSM tile usage policy: ถ้าผู้ใช้เยอะควรใช้ tile server ของตัวเองหรือจ่าย (MapTiler/Thunderforest)
