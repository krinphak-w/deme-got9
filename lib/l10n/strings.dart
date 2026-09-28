/// TH + EN strings only (V1 scope). No ZH/JA yet.
library;

enum AppLang { th, en }

const Map<String, Map<AppLang, String>> strings = {
  'appTitle': {AppLang.th: 'GOT9 ฟาร์ม', AppLang.en: 'GOT9 Farm'},
  'login': {AppLang.th: 'เข้าสู่ระบบ', AppLang.en: 'Sign in'},
  'phone': {AppLang.th: 'เบอร์โทรศัพท์', AppLang.en: 'Phone number'},
  'otp': {AppLang.th: 'รหัส OTP (mock: 123456)', AppLang.en: 'OTP code (mock: 123456)'},
  'role': {AppLang.th: 'เลือกบทบาท', AppLang.en: 'Select role'},
  'farmer': {AppLang.th: 'เกษตรกร (F-ID)', AppLang.en: 'Farmer (F-ID)'},
  'buyer': {AppLang.th: 'ผู้ซื้อ/นักท่องเที่ยว (B-ID)', AppLang.en: 'Buyer/Tourist (B-ID)'},
  'corporate': {AppLang.th: 'องค์กร (C-ID)', AppLang.en: 'Corporate (C-ID)'},
  'consent': {
    AppLang.th: 'ยินยอมให้ใช้ข้อมูลพิกัดและข้อมูลส่วนบุคคลตาม PDPA',
    AppLang.en: 'Consent to location & personal data use (PDPA)',
  },
  'myPlots': {AppLang.th: 'แปลงของฉัน', AppLang.en: 'My plots'},
  'importLing': {
    AppLang.th: '+ นำเข้าแปลงจาก Ling (KML/KMZ/GeoJSON)',
    AppLang.en: '+ Import plot from Ling (KML/KMZ/GeoJSON)',
  },
  'addPlot': {
    AppLang.th: '+ เพิ่มแปลง (ไฟล์ Ling / วาด / เดิน GPS / กรอกเอง)',
    AppLang.en: '+ Add plot (Ling file / draw / GPS walk / manual)',
  },
  'farmLog': {AppLang.th: 'บันทึกออร์แกนิก (PGS)', AppLang.en: 'Organic log (PGS)'},
  'shop': {AppLang.th: 'ตะกร้าพรีออเดอร์', AppLang.en: 'Pre-order shop'},
  'workshop': {AppLang.th: 'เวิร์คช็อป', AppLang.en: 'Workshop'},
  'trace': {AppLang.th: 'สแกน QR ย้อนรอย', AppLang.en: 'Scan QR trace'},
  'corporateTitle': {AppLang.th: 'สำหรับองค์กร (B2B)', AppLang.en: 'For corporate (B2B)'},
  'verify': {AppLang.th: 'รับรองแปลง', AppLang.en: 'Verify plots'},
  'sellableLeft': {AppLang.th: 'เหลือขาย', AppLang.en: 'Left to sell'},
  'order': {AppLang.th: 'สั่งซื้อ', AppLang.en: 'Order'},
  'book': {AppLang.th: 'จอง', AppLang.en: 'Book'},
  'seatsLeft': {AppLang.th: 'ที่ว่าง', AppLang.en: 'Seats left'},
  'full': {AppLang.th: 'เต็มแล้ว', AppLang.en: 'Full'},
  'deposit30': {AppLang.th: 'มัดจำ 30%', AppLang.en: '30% deposit'},
  'year1': {AppLang.th: 'ข้อมูลปีที่ 1', AppLang.en: 'Year 1 data'},
  'buyAgain': {AppLang.th: 'ซื้ออีกครั้ง', AppLang.en: 'Buy again'},
  'approve': {AppLang.th: 'รับรอง', AppLang.en: 'Approve'},
  'villageHead': {AppLang.th: 'ผู้ใหญ่บ้าน', AppLang.en: 'Village head'},
  'agriOfficer': {AppLang.th: 'เกษตรอำเภอ', AppLang.en: 'Agri officer'},
  'save': {AppLang.th: 'บันทึก', AppLang.en: 'Save'},
  'photoHint': {
    AppLang.th: 'ถ่ายรูป (บีบอัดอัตโนมัติ <2MB)',
    AppLang.en: 'Take photo (auto-compress <2MB)',
  },
};

String t(String key, AppLang lang) =>
    strings[key]?[lang] ?? strings[key]?[AppLang.en] ?? key;
