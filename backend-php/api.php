<?php
// GOT9 API — PHP 8.2 ล้วน (ไม่ใช้ framework) สำหรับแชร์โฮสต์ cPanel
// เรียก: POST /auth/login, GET /me, GET+POST /plots, PUT /plots/{id}/verify,
//       GET+POST /logs, GET /products, POST /orders, GET /workshops,
//       POST /workshops/{id}/book, GET /trace/{plot_id}, POST /upload
declare(strict_types=1);

require_once __DIR__ . '/db.php';

// ---------- CORS ----------
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, ALLOWED_ORIGINS, true)) {
  header("Access-Control-Allow-Origin: $origin");
}
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;

header('Content-Type: application/json; charset=utf-8');

function send($data, int $code = 200): void {
  http_response_code($code);
  echo json_encode($data, JSON_UNESCAPED_UNICODE);
  exit;
}
function body(): array {
  $raw = file_get_contents('php://input') ?: '';
  $j = json_decode($raw, true);
  return is_array($j) ? $j : [];
}
function new_id(string $prefix): string {
  $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  $s = '';
  for ($i = 0; $i < 8; $i++) $s .= $chars[random_int(0, strlen($chars) - 1)];
  return $prefix . '-' . $s;
}

// ---------- Auth (mock เฟส 1/2: เลือก role แล้วออกโทเค็น, หมดอายุ 30 วัน) ----------
function current_user(): ?array {
  $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
  if (!str_starts_with($h, 'Bearer ')) return null;
  $token = substr($h, 7);
  $st = db()->prepare('SELECT u.* FROM api_tokens t JOIN users u ON u.id = t.user_id WHERE t.token = ? AND t.expires_at > NOW()');
  $st->execute([$token]);
  $u = $st->fetch();
  return $u ?: null;
}
function require_auth(): array {
  $u = current_user();
  if (!$u) send(['error' => 'unauthorized'], 401);
  return $u;
}

// ---------- Router ----------
$route = trim($_GET['_route'] ?? '', '/');
if ($route === '') {
  // fallback: ตัด base path ออกจาก REQUEST_URI (กรณี .htaccess ไม่ทำงาน)
  $uri = trim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');
  $parts = explode('/', $uri);
  $route = implode('/', array_slice($parts, -2)); // เช่น plots / trace/PLOT-1
}
$method = $_SERVER['REQUEST_METHOD'];
$seg = $route === '' ? [] : explode('/', $route);

// ---------- POST /auth/login {role: F|B|C, phone, display_name?} ----------
if ($method === 'POST' && ($seg[0] ?? '') === 'auth' && ($seg[1] ?? '') === 'login') {
  $b = body();
  $role = strtoupper(substr($b['role'] ?? '', 0, 1));
  if (!in_array($role, ['F', 'B', 'C'], true)) send(['error' => 'role must be F/B/C'], 400);
  $phone = preg_replace('/\D/', '', (string)($b['phone'] ?? ''));
  if (strlen($phone) < 9) send(['error' => 'invalid phone'], 400);
  $pdo = db();
  $st = $pdo->prepare('SELECT * FROM users WHERE phone = ? AND role = ?');
  $st->execute([$phone, $role]);
  $user = $st->fetch();
  if (!$user) {
    // mock-auth: สร้าง user ใหม่ให้เลย (เฟส 2 ค่อยผูก OTP/LINE จริง)
    $id = $role . '-' . str_pad((string)random_int(1, 99999), 5, '0', STR_PAD_LEFT);
    $name = trim((string)($b['display_name'] ?? '')) ?: ($role . '-Demo ' . $id);
    $pdo->prepare('INSERT INTO users (id, role, display_name, phone, kyc_status) VALUES (?,?,?,?,?)')
        ->execute([$id, $role, $name, $phone, 'pending']);
    $user = ['id' => $id, 'role' => $role, 'display_name' => $name, 'phone' => $phone, 'kyc_status' => 'pending'];
  }
  $token = bin2hex(random_bytes(32));
  $pdo->prepare('INSERT INTO api_tokens (token, user_id, expires_at) VALUES (?,?,DATE_ADD(NOW(), INTERVAL 30 DAY))')
      ->execute([$token, $user['id']]);
  send(['token' => $token, 'user' => $user]);
}

// ---------- GET /me ----------
if ($method === 'GET' && ($seg[0] ?? '') === 'me') {
  send(['user' => require_auth()]);
}

// ---------- GET /plots / POST /plots ----------
if (($seg[0] ?? '') === 'plots' && count($seg) === 1) {
  if ($method === 'GET') {
    $owner = $_GET['owner'] ?? null;
    if ($owner) {
      $st = db()->prepare('SELECT * FROM farm_plots WHERE owner_fid = ? ORDER BY created_at DESC');
      $st->execute([$owner]);
    } else {
      $st = db()->query('SELECT * FROM farm_plots ORDER BY created_at DESC');
    }
    $rows = $st->fetchAll();
    foreach ($rows as &$r) {
      $r['geom'] = $r['geom_geojson'] ? json_decode($r['geom_geojson'], true) : null;
      unset($r['geom_geojson']);
      $r['verified'] = (bool)$r['verifier_village'] && (bool)$r['verifier_agri_officer'];
    }
    send(['plots' => $rows]);
  }
  if ($method === 'POST') {
    $me = require_auth();
    if ($me['role'] !== 'F') send(['error' => 'farmers only'], 403);
    $b = body();
    $name = trim((string)($b['plot_name'] ?? ''));
    if ($name === '') send(['error' => 'plot_name required'], 400);
    $id = preg_match('/^[A-Za-z0-9-]{4,32}$/', (string)($b['id'] ?? '')) ? $b['id'] : new_id('PLOT');
    $land = in_array($b['land_type'] ?? '', ['chanote', 'spk', 'khor_tor_chor'], true) ? $b['land_type'] : 'chanote';
    $ch = in_array($b['entry_channel'] ?? '', ['ling', 'draw', 'gps_walk', 'manual'], true) ? $b['entry_channel'] : 'manual';
    db()->prepare('INSERT INTO farm_plots (id, owner_fid, plot_name, geom_geojson, area_gross_rai, area_net_rai, ling_source_id, land_type, entry_channel, doc_photo_url) VALUES (?,?,?,?,?,?,?,?,?,?)')
      ->execute([$id, $me['id'], $name, isset($b['geom']) ? json_encode($b['geom'], JSON_UNESCAPED_UNICODE) : null,
        (float)($b['area_gross_rai'] ?? 0), (float)($b['area_net_rai'] ?? 0),
        $b['ling_source_id'] ?? null, $land, $ch, $b['doc_photo_url'] ?? null]);
    send(['id' => $id], 201);
  }
}

// ---------- PUT /plots/{id}/verify {by: village|agri} ----------
if ($method === 'PUT' && ($seg[0] ?? '') === 'plots' && ($seg[2] ?? '') === 'verify') {
  require_auth(); // เฟส 2 ค่อยแยกสิทธิ์ verifier จริง
  $by = body()['by'] ?? '';
  $col = $by === 'village' ? 'verifier_village' : ($by === 'agri' ? 'verifier_agri_officer' : null);
  if (!$col) send(['error' => 'by must be village|agri'], 400);
  $st = db()->prepare("UPDATE farm_plots SET $col = 1 WHERE id = ?");
  $st->execute([$seg[1]]);
  send(['ok' => $st->rowCount() > 0]);
}

// ---------- GET /logs?plot= / POST /logs ----------
if (($seg[0] ?? '') === 'logs' && count($seg) === 1) {
  if ($method === 'GET') {
    $plot = $_GET['plot'] ?? '';
    $st = db()->prepare('SELECT * FROM organic_logs WHERE plot_id = ? ORDER BY log_date DESC');
    $st->execute([$plot]);
    send(['logs' => $st->fetchAll()]);
  }
  if ($method === 'POST') {
    $me = require_auth();
    $b = body();
    $allowed = ['seed', 'input', 'cleaning', 'harvest', 'activity', 'neighbor'];
    if (!in_array($b['log_type'] ?? '', $allowed, true)) send(['error' => 'bad log_type'], 400);
    // ตรวจว่าแปลงเป็นของตัวเอง
    $st = db()->prepare('SELECT id FROM farm_plots WHERE id = ? AND owner_fid = ?');
    $st->execute([$b['plot_id'] ?? '', $me['id']]);
    if (!$st->fetch()) send(['error' => 'not your plot'], 403);
    $id = new_id('LOG');
    db()->prepare('INSERT INTO organic_logs (id, plot_id, log_type, detail_json, photo_url) VALUES (?,?,?,?,?)')
      ->execute([$id, $b['plot_id'], $b['log_type'],
        json_encode(['detail' => $b['detail'] ?? ''], JSON_UNESCAPED_UNICODE),
        $b['photo_url'] ?? null]);
    send(['id' => $id], 201);
  }
}

// ---------- GET /products ----------
if ($method === 'GET' && ($seg[0] ?? '') === 'products') {
  $farm = $_GET['farm'] ?? null;
  if ($farm) {
    $st = db()->prepare('SELECT * FROM products WHERE farm_id = ? AND active = 1');
    $st->execute([$farm]);
  } else {
    $st = db()->query('SELECT * FROM products WHERE active = 1');
  }
  send(['products' => $st->fetchAll()]);
}

// ---------- POST /orders {product_id, qty} — บังคับ Yield Buffer + คำนวณ GP/VAT ฝั่งเซิร์ฟเวอร์ ----------
if ($method === 'POST' && ($seg[0] ?? '') === 'orders' && count($seg) === 1) {
  $me = require_auth();
  $b = body();
  $qty = max(1, (int)($b['qty'] ?? 1));
  $pdo = db();
  $pdo->beginTransaction();
  try {
    $st = $pdo->prepare('SELECT * FROM products WHERE id = ? AND active = 1 FOR UPDATE');
    $st->execute([$b['product_id'] ?? '']);
    $p = $st->fetch();
    if (!$p) { $pdo->rollBack(); send(['error' => 'product not found'], 404); }
    $sellable = (int)floor($p['harvest_qty'] * (100 - (float)$p['stock_buffer_pct']) / 100);
    if ($p['sold_qty'] + $qty > $sellable) {
      $pdo->rollBack();
      send(['error' => 'เกิน Yield Buffer', 'sellable' => $sellable, 'sold' => (int)$p['sold_qty']], 409);
    }
    $subtotal = round((float)$p['price'] * $qty, 2);
    $gp = round($subtotal * 0.05, 2);          // Platform GP 5%
    $vat = round($gp * 0.07, 2);               // VAT 7% บน GP เท่านั้น
    $id = new_id('ORD');
    $pdo->prepare('INSERT INTO orders (id, buyer_bid, items_json, total, gp_fee, status) VALUES (?,?,?,?,?,?)')
      ->execute([$id, $me['id'],
        json_encode([['product_id' => $p['id'], 'qty' => $qty, 'price' => $p['price']]], JSON_UNESCAPED_UNICODE),
        $subtotal, $gp, 'pending']);
    $pdo->prepare('UPDATE products SET sold_qty = sold_qty + ? WHERE id = ?')->execute([$qty, $p['id']]);
    $pdo->commit();
    send(['id' => $id, 'subtotal' => $subtotal, 'gp_fee' => $gp, 'vat_on_gp' => $vat], 201);
  } catch (Throwable $e) {
    $pdo->rollBack();
    send(['error' => 'order failed'], 500);
  }
}

// ---------- GET /workshops / POST /workshops/{id}/book {persons} ----------
if (($seg[0] ?? '') === 'workshops') {
  if ($method === 'GET' && count($seg) === 1) {
    $st = db()->query('SELECT *, (capacity - booked_count) AS seats_left FROM workshops ORDER BY date_time');
    send(['workshops' => $st->fetchAll()]);
  }
  if ($method === 'POST' && ($seg[2] ?? '') === 'book') {
    $me = require_auth();
    $persons = max(1, (int)(body()['persons'] ?? 1));
    $pdo = db();
    $pdo->beginTransaction();
    try {
      $st = $pdo->prepare('SELECT * FROM workshops WHERE id = ? FOR UPDATE');
      $st->execute([$seg[1]]);
      $w = $st->fetch();
      if (!$w) { $pdo->rollBack(); send(['error' => 'workshop not found'], 404); }
      if ($w['booked_count'] + $persons > $w['capacity']) {
        $pdo->rollBack();
        send(['error' => 'เต็มแล้ว', 'capacity' => (int)$w['capacity'], 'booked' => (int)$w['booked_count']], 409);
      }
      $deposit = round((float)$w['price'] * $persons * 0.30, 2); // มัดจำ 30%
      $id = new_id('BK');
      $pdo->prepare('INSERT INTO bookings (id, workshop_id, buyer_bid, persons, deposit_30) VALUES (?,?,?,?,?)')
        ->execute([$id, $w['id'], $me['id'], $persons, $deposit]);
      $pdo->prepare('UPDATE workshops SET booked_count = booked_count + ? WHERE id = ?')->execute([$persons, $w['id']]);
      $pdo->commit();
      send(['id' => $id, 'deposit' => $deposit], 201);
    } catch (Throwable $e) {
      $pdo->rollBack();
      send(['error' => 'booking failed'], 500);
    }
  }
}

// ---------- GET /trace/{plot_id} — สาธารณะ ไม่ต้อง login (QR) ----------
if ($method === 'GET' && ($seg[0] ?? '') === 'trace' && isset($seg[1])) {
  $pdo = db();
  $st = $pdo->prepare('SELECT * FROM farm_plots WHERE id = ?');
  $st->execute([$seg[1]]);
  $plot = $st->fetch();
  if (!$plot) send(['error' => 'plot not found'], 404);
  $plot['geom'] = $plot['geom_geojson'] ? json_decode($plot['geom_geojson'], true) : null;
  unset($plot['geom_geojson']);
  // เบลอพิกัดบ้านเหลือระดับตำบลก่อนส่งให้สาธารณะ (PDPA)
  if (is_array($plot['geom'])) {
    array_walk_recursive($plot['geom'], function (&$v, $k) {
      if (is_float($v) || is_int($v)) $v = round((float)$v, 2);
    });
  }
  $st = $pdo->prepare('SELECT * FROM organic_logs WHERE plot_id = ? ORDER BY log_date DESC LIMIT 50');
  $st->execute([$plot['id']]);
  $st2 = $pdo->prepare('SELECT * FROM products WHERE farm_id = ? AND active = 1');
  $st2->execute([$plot['id']]);
  send(['plot' => $plot, 'logs' => $st->fetchAll(), 'products' => $st2->fetchAll()]);
}

// ---------- POST /upload (multipart field: photo) -> {path} ----------
if ($method === 'POST' && ($seg[0] ?? '') === 'upload') {
  require_auth();
  if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    send(['error' => 'no photo'], 400);
  }
  $f = $_FILES['photo'];
  if ($f['size'] > 8 * 1024 * 1024) send(['error' => 'file too large (8MB)'], 413);
  $ext = strtolower(pathinfo($f['name'], PATHINFO_EXTENSION));
  if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true)) send(['error' => 'jpg/png/webp only'], 415);
  $dir = __DIR__ . '/uploads/' . date('Ym');
  if (!is_dir($dir)) mkdir($dir, 0755, true);
  $name = bin2hex(random_bytes(12)) . '.' . $ext;
  if (!move_uploaded_file($f['tmp_name'], $dir . '/' . $name)) send(['error' => 'save failed'], 500);
  send(['path' => 'uploads/' . date('Ym') . '/' . $name], 201);
}

send(['error' => 'not found', 'route' => $route], 404);
