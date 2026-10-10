<?php
// GOT9 billing API — ดัดแปลงจากต้นแบบ Vikala Pro
// เส้นทาง (ต่อท้าย api.php): POST /billing/issue, POST /billing/{id}/cancel,
//   GET /billing/reports/sales, GET /billing/reports/by-user,
//   GET+POST /customers, GET /billing/print/{id} (HTML สำหรับพิมพ์)
declare(strict_types=1);

function billing_routes(array $seg, string $method): bool {
  if (($seg[0] ?? '') !== 'billing' && ($seg[0] ?? '') !== 'customers') return false;

  // ---------- GET+POST /customers (ทะเบียนกลาง เพิ่ม/แก้ได้อย่างเดียว ห้ามลบ) ----------
  if (($seg[0] ?? '') === 'customers' && count($seg) === 1) {
    if ($method === 'GET') {
      $q = '%' . trim($_GET['q'] ?? '') . '%';
      $st = db()->prepare('SELECT * FROM customers WHERE name LIKE ? OR tax_id LIKE ? ORDER BY name LIMIT 50');
      $st->execute([$q, $q]);
      send(['customers' => $st->fetchAll()]);
    }
    if ($method === 'POST') {
      require_auth();
      $b = body();
      $name = trim((string)($b['name'] ?? ''));
      if ($name === '') send(['error' => 'name required'], 400);
      if (!empty($b['id'])) {
        db()->prepare('UPDATE customers SET name=?, tax_id=?, phone=?, addr=? WHERE id=?')
          ->execute([$name, $b['tax_id'] ?? null, $b['phone'] ?? null, $b['addr'] ?? null, $b['id']]);
        send(['id' => $b['id']]);
      }
      $id = new_id('CU');
      db()->prepare('INSERT INTO customers (id, name, tax_id, phone, addr) VALUES (?,?,?,?,?)')
        ->execute([$id, $name, $b['tax_id'] ?? null, $b['phone'] ?? null, $b['addr'] ?? null]);
      send(['id' => $id], 201);
    }
  }

  // ---------- POST /billing/issue ----------
  if ($method === 'POST' && ($seg[1] ?? '') === 'issue' && count($seg) === 2) {
    $me = require_auth();
    $b = body();
    $pdo = db();
    $st = $pdo->prepare('SELECT * FROM sellers WHERE id = ?');
    $st->execute([$b['seller_id'] ?? '']);
    $seller = $st->fetch();
    if (!$seller) send(['error' => 'seller not found'], 404);

    $type = $b['doc_type'] ?? '';
    if (!in_array($type, ['invoice', 'receipt', 'tax', 'abbreviated'], true)) {
      send(['error' => 'doc_type must be invoice|receipt|tax|abbreviated'], 400);
    }
    // กฎ Vikala: บริษัทไม่จด VAT ออกใบกำกับภาษีไม่ได้
    if ($type === 'tax' && !(int)$seller['is_vat_registered']) {
      send(['error' => 'ผู้ขายรายนี้ไม่จด VAT ออกใบกำกับภาษีไม่ได้'], 422);
    }
    // ใบกำกับอย่างย่อ = ลูกค้าทั่วไปเสมอ
    $customerId = $type === 'abbreviated' ? 'CU-WALKIN' : ($b['customer_id'] ?? null);
    if ($type !== 'abbreviated' && !$customerId) send(['error' => 'customer_id required'], 400);

    $items = $b['items'] ?? [];
    if (!is_array($items) || !$items) send(['error' => 'items required'], 400);
    $subtotal = 0;
    foreach ($items as $it) {
      $subtotal += round((float)($it['qty'] ?? 0) * (float)($it['price'] ?? 0), 2);
    }
    $subtotal = round($subtotal, 2);
    // VAT 7% เฉพาะใบกำกับภาษีของผู้ขายจด VAT (ฟาร์มบุคคลธรรมดา = 0)
    $vat = ($type === 'tax') ? round($subtotal * 0.07, 2) : 0.0;
    $wht = round((float)($b['withholding'] ?? 0), 2);
    $total = round($subtotal + $vat - $wht, 2);

    $pdo->beginTransaction();
    try {
      // รันเลขที่: {SEELLER}-{TYPE}-{YY}{0001...} ล็อกแถวกันชน
      $yy = date('y');
      $code = ['invoice' => 'INV', 'receipt' => 'REC', 'tax' => 'TAX', 'abbreviated' => 'ABB'][$type];
      $prefix = preg_replace('/[^A-Z0-9]/', '', strtoupper($seller['id']));
      $st = $pdo->prepare('SELECT last_no FROM doc_counters WHERE seller_id=? AND doc_type=? AND yy=? FOR UPDATE');
      $st->execute([$seller['id'], $type, $yy]);
      $row = $st->fetch();
      $next = $row ? (int)$row['last_no'] + 1 : 1;
      if ($row) {
        $pdo->prepare('UPDATE doc_counters SET last_no=? WHERE seller_id=? AND doc_type=? AND yy=?')
            ->execute([$next, $seller['id'], $type, $yy]);
      } else {
        $pdo->prepare('INSERT INTO doc_counters (seller_id, doc_type, yy, last_no) VALUES (?,?,?,?)')
            ->execute([$seller['id'], $type, $yy, $next]);
      }
      $docNo = $prefix . '-' . $code . '-' . $yy . str_pad((string)$next, 4, '0', STR_PAD_LEFT);
      $id = new_id('DOC');
      $pdo->prepare('INSERT INTO documents (id, seller_id, customer_id, order_id, doc_type, doc_no, issue_date, subtotal, vat, withholding, total, created_by) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)')
        ->execute([$id, $seller['id'], $customerId, $b['order_id'] ?? null, $type, $docNo,
          $b['issue_date'] ?? date('Y-m-d'), $subtotal, $vat, $wht, $total, $me['id']]);
      $ist = $pdo->prepare('INSERT INTO document_items (doc_id, description, qty, price, amount) VALUES (?,?,?,?,?)');
      foreach ($items as $it) {
        $q = (float)($it['qty'] ?? 0);
        $p = (float)($it['price'] ?? 0);
        $ist->execute([$id, (string)($it['description'] ?? ''), $q, $p, round($q * $p, 2)]);
      }
      $pdo->commit();
      send(['id' => $id, 'doc_no' => $docNo, 'subtotal' => $subtotal, 'vat' => $vat, 'total' => $total], 201);
    } catch (Throwable $e) {
      $pdo->rollBack();
      send(['error' => 'issue failed'], 500);
    }
  }

  // ---------- POST /billing/{id}/cancel {reason} (ยกเลิกแต่ไม่ลบ, เห็นเฉพาะ admin) ----------
  if ($method === 'POST' && ($seg[1] ?? '') !== '' && ($seg[2] ?? '') === 'cancel') {
    $me = require_auth();
    $reason = trim((string)(body()['reason'] ?? ''));
    if ($reason === '') send(['error' => 'cancel reason required'], 400);
    $st = db()->prepare("UPDATE documents SET status='cancelled', cancel_reason=? WHERE id=? AND status='issued'");
    $st->execute([$reason . ' (โดย ' . $me['id'] . ')', $seg[1]]);
    send(['ok' => $st->rowCount() > 0]);
  }

  // ---------- GET /billing/reports/sales?seller=&month=&year= (ไม่นับใบยกเลิก) ----------
  if ($method === 'GET' && ($seg[1] ?? '') === 'reports' && ($seg[2] ?? '') === 'sales') {
    require_auth();
    $sql = "SELECT seller_id, COUNT(*) AS docs, SUM(subtotal) AS subtotal, SUM(vat) AS vat, SUM(total) AS total
            FROM documents WHERE status='issued'";
    $args = [];
    if (!empty($_GET['seller'])) { $sql .= ' AND seller_id=?'; $args[] = $_GET['seller']; }
    if (!empty($_GET['month'])) { $sql .= ' AND MONTH(issue_date)=?'; $args[] = (int)$_GET['month']; }
    if (!empty($_GET['year'])) { $sql .= ' AND YEAR(issue_date)=?'; $args[] = (int)$_GET['year']; }
    $sql .= ' GROUP BY seller_id';
    $st = db()->prepare($sql);
    $st->execute($args);
    send(['sales' => $st->fetchAll()]);
  }

  // ---------- GET /billing/reports/by-user?month=&year= (ใครออกอะไรบ้าง, ไม่โชว์ยอด — ไว้ตรวจงาน) ----------
  if ($method === 'GET' && ($seg[1] ?? '') === 'reports' && ($seg[2] ?? '') === 'by-user') {
    require_auth();
    $sql = 'SELECT created_by, doc_type, status, COUNT(*) AS docs FROM documents WHERE 1=1';
    $args = [];
    if (!empty($_GET['month'])) { $sql .= ' AND MONTH(issue_date)=?'; $args[] = (int)$_GET['month']; }
    if (!empty($_GET['year'])) { $sql .= ' AND YEAR(issue_date)=?'; $args[] = (int)$_GET['year']; }
    $sql .= ' GROUP BY created_by, doc_type, status ORDER BY created_by';
    $st = db()->prepare($sql);
    $st->execute($args);
    send(['by_user' => $st->fetchAll()]);
  }

  // ---------- GET /billing/print/{id} (HTML สำหรับพิมพ์ — ธีมเปลี่ยนได้) ----------
  if ($method === 'GET' && ($seg[1] ?? '') === 'print' && isset($seg[2])) {
    $pdo = db();
    $st = $pdo->prepare('SELECT d.*, s.name AS seller_name, s.tax_id AS seller_tax, s.addr AS seller_addr, s.logo_url, c.name AS cust_name, c.tax_id AS cust_tax, c.addr AS cust_addr FROM documents d JOIN sellers s ON s.id=d.seller_id LEFT JOIN customers c ON c.id=d.customer_id WHERE d.id=?');
    $st->execute([$seg[2]]);
    $d = $st->fetch();
    if (!$d) { http_response_code(404); echo 'ไม่พบเอกสาร'; exit; }
    $st = $pdo->prepare('SELECT * FROM document_items WHERE doc_id=?');
    $st->execute([$d['id']]);
    $items = $st->fetchAll();
    $titles = ['invoice' => 'ใบแจ้งหนี้', 'receipt' => 'ใบเสร็จรับเงิน', 'tax' => 'ใบกำกับภาษี', 'abbreviated' => 'ใบกำกับภาษีอย่างย่อ'];
    header('Content-Type: text/html; charset=utf-8');
    $h = fn($s) => htmlspecialchars((string)($s ?? ''), ENT_QUOTES, 'UTF-8');
    echo '<!DOCTYPE html><html lang="th"><head><meta charset="utf-8"><title>' . $h($d['doc_no']) . '</title>';
    echo '<style>body{font-family:sans-serif;max-width:640px;margin:auto;padding:16px;color:#222}' .
      'table{width:100%;border-collapse:collapse;margin:12px 0}td,th{border:1px solid #999;padding:6px 8px;font-size:14px}' .
      '.r{text-align:right}.c{text-align:center}.cancel{color:#b00;border:2px solid #b00;padding:4px 12px;display:inline-block}' .
      '@media print{button{display:none}}</style></head><body>';
    echo '<button onclick="window.print()">พิมพ์</button>';
    echo '<h2 class="c">' . $h($titles[$d['doc_type']] ?? $d['doc_type']) . '</h2>';
    if ($d['logo_url']) echo '<p class="c"><img src="' . $h($d['logo_url']) . '" style="height:64px"></p>';
    echo '<p><b>' . $h($d['seller_name']) . '</b><br>' . $h($d['seller_addr'] ?? '') .
      ($d['seller_tax'] ? '<br>เลขภาษี ' . $h($d['seller_tax']) : '') . '</p>';
    echo '<p>เลขที่ <b>' . $h($d['doc_no']) . '</b> วันที่ ' . $h($d['issue_date']) .
      '<br>ลูกค้า: ' . $h($d['cust_name'] ?? 'ลูกค้าทั่วไป') .
      ($d['cust_tax'] ? ' เลขภาษี ' . $h($d['cust_tax']) : '') . '</p>';
    if ($d['status'] === 'cancelled') echo '<p class="c"><span class="cancel">ยกเลิกแล้ว: ' . $h($d['cancel_reason']) . '</span></p>';
    echo '<table><tr><th>รายการ</th><th>จำนวน</th><th>ราคา</th><th>รวม</th></tr>';
    foreach ($items as $it) {
      echo '<tr><td>' . $h($it['description']) . '</td><td class="r">' . $h($it['qty']) . '</td><td class="r">' . number_format((float)$it['price'], 2) . '</td><td class="r">' . number_format((float)$it['amount'], 2) . '</td></tr>';
    }
    echo '</table><p class="r">รวม: ' . number_format((float)$d['subtotal'], 2);
    if ((float)$d['vat'] > 0) echo '<br>VAT 7%: ' . number_format((float)$d['vat'], 2);
    if ((float)$d['withholding'] > 0) echo '<br>หัก ณ ที่จ่าย: ' . number_format((float)$d['withholding'], 2);
    echo '<br><b>สุทธิ: ' . number_format((float)$d['total'], 2) . ' บาท</b></p></body></html>';
    exit;
  }

  return false;
}
