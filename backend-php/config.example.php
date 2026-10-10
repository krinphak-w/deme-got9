<?php
// GOT9 backend — ค่าตั้งต้นฐานข้อมูล (ก๊อปไฟล์นี้เป็น config.php แล้วกรอกค่าจริง)
// ห้าม commit config.php ขึ้น git (ดู .gitignore — ถ้ายังไม่มีให้เพิ่มเอง)

// สร้างฐานข้อมูล + user ใน cPanel > MySQL Databases ก่อน แล้วเอาค่ามากรอก:
define('DB_HOST', 'localhost');       // แชร์โฮสต์ส่วนใหญ่ใช้ localhost
define('DB_NAME', 'cpaneluser_got9'); // เปลี่ยนตามจริง
define('DB_USER', 'cpaneluser_got9'); // เปลี่ยนตามจริง
define('DB_PASS', 'ใส่รหัสผ่านตรงนี้'); // เปลี่ยนตามจริง

// คีย์สำหรับเซ็นโทเค็นล็อกอิน (สุ่มยาวๆ 1 เส้น เช่น เปิด https://passwordsgenerator.net)
define('APP_SECRET', 'เปลี่ยนเป็นข้อความสุ่มยาวๆ-ห้ามซ้ำกับที่อื่น');

// โดเมนเว็บแอป (Flutter web + static mock) ที่อนุญาตให้เรียก API (CORS)
define('ALLOWED_ORIGINS', ['https://krinphak-w.github.io']);
