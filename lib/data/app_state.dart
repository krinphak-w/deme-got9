import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/money.dart';
import '../core/thai_units.dart';
import '../l10n/strings.dart';
import 'hive_cache.dart';
import 'models.dart';

/// Central V1 store (mock-first). Wraps seed data, Hive offline-lite cache,
/// and rule enforcement (Yield Buffer, workshop capacity).
class AppState extends ChangeNotifier {
  AppUser? currentUser;
  AppLang lang = AppLang.th;
  double fontScale = 1.0;

  final List<FarmPlot> plots = [];
  final List<OrganicLog> logs = [];
  final List<Product> products = [];
  final List<ShopOrder> orders = [];
  final List<Workshop> workshops = [];
  final List<Booking> bookings = [];

  /// In-memory photo bytes for session display (web + mock).
  final Map<String, Uint8List> productPhotos = {};
  final Map<String, Uint8List> avatarBytes = {};

  int _seq = 100;

  String _next(String prefix) => '$prefix-${(_seq++).toString().padLeft(5, '0')}';

  void setLang(AppLang v) {
    lang = v;
    notifyListeners();
  }

  void bumpFont(double delta) {
    fontScale = (fontScale + delta).clamp(0.85, 1.6);
    notifyListeners();
  }

  String tr(String key) => t(key, lang);

  // ---------- auth (mock OTP) ----------
  bool sendMockOtp(String phone) => phone.replaceAll(RegExp(r'\D'), '').length >= 9;

  bool verifyMockOtp(String code) => code == '123456';

  void signIn({required String phone, required UserRole role}) {
    const demoIds = {
      UserRole.farmer: 'F-00001',
      UserRole.buyer: 'B-00001',
      UserRole.corporate: 'C-00001',
    };
    currentUser = AppUser(
      id: demoIds[role]!,
      role: role,
      displayName: '${role.code}-Demo ${demoIds[role]}',
      phone: phone,
      kycStatus: 'verified',
      consentPdpa: true,
    );
    loadProfile(currentUser!);
    notifyListeners();
  }

  void signOut() {
    currentUser = null;
    notifyListeners();
  }

  // ---------- profile ----------
  Future<void> loadProfile(AppUser user) async {
    user.displayName = HiveCache.getPref<String>('profile:${user.id}:name') ??
        user.displayName;
    user.phone =
        HiveCache.getPref<String>('profile:${user.id}:phone') ?? user.phone;
    user.avatarPath =
        HiveCache.getPref<String>('profile:${user.id}:avatar');
    notifyListeners();
  }

  Future<void> updateProfile({
    String? displayName,
    String? phone,
    String? avatarPath,
    Uint8List? avatarMemBytes,
    bool? consentPdpa,
  }) async {
    final AppUser? user = currentUser;
    if (user == null) return;
    if (displayName != null) {
      user.displayName = displayName;
      await HiveCache.setPref('profile:${user.id}:name', displayName);
    }
    if (phone != null) {
      user.phone = phone;
      await HiveCache.setPref('profile:${user.id}:phone', phone);
    }
    if (avatarPath != null) {
      user.avatarPath = avatarPath;
      await HiveCache.setPref('profile:${user.id}:avatar', avatarPath);
    }
    if (avatarMemBytes != null) {
      avatarBytes[user.id] = avatarMemBytes;
    }
    if (consentPdpa != null) user.consentPdpa = consentPdpa;
    notifyListeners();
  }

  // ---------- product photo (farmer, own farm only) ----------
  bool canEditProduct(String productId) {
    final AppUser? user = currentUser;
    if (user == null || user.role != UserRole.farmer) return false;
    final Product product =
        products.firstWhere((p) => p.id == productId);
    return plots.any(
        (plot) => plot.id == product.farmId && plot.ownerFid == user.id);
  }

  void setProductPhoto(String productId, String path, Uint8List memBytes) {
    if (!canEditProduct(productId)) return;
    products.firstWhere((p) => p.id == productId).photoPath = path;
    productPhotos[productId] = memBytes;
    notifyListeners();
  }

  // ---------- plots ----------
  Future<FarmPlot> addPlotFromLing({
    required String plotName,
    required List<LatLng> polygon,
    String? lingSourceId,
    String landType = 'chanote',
    double bufferM = defaultBufferMeters,
  }) =>
      addPlot(
        plotName: plotName,
        polygon: polygon,
        lingSourceId: lingSourceId,
        landType: landType,
        bufferM: bufferM,
        entryChannel: 'ling',
      );

  /// General plot entry used by all 4 channels (ling/draw/gps_walk/manual).
  Future<FarmPlot> addPlot({
    required String plotName,
    List<LatLng>? polygon,
    String? lingSourceId,
    String landType = 'chanote',
    double bufferM = defaultBufferMeters,
    String entryChannel = 'manual',
    double? declaredGrossSqm,
    String? docPhotoPath,
  }) async {
    double grossSqm;
    double netSqm;
    if (polygon != null && polygon.length >= 3) {
      grossSqm = polygonAreaSqm(polygon);
      netSqm = netAreaSqm(polygon, bufferM);
    } else {
      grossSqm = declaredGrossSqm ?? 0;
      netSqm = netSquareApproxSqm(grossSqm, bufferM);
    }
    final FarmPlot plot = FarmPlot(
      id: _next('PLOT'),
      ownerFid: currentUser?.id ?? 'F-00001',
      plotName: plotName,
      polygon: polygon,
      areaGrossRai:
          double.parse(sqmToRai(grossSqm).toStringAsFixed(2)),
      areaNetRai: double.parse(sqmToRai(netSqm).toStringAsFixed(2)),
      lingSourceId: lingSourceId,
      landType: landType,
      docPhotoPath: docPhotoPath,
      entryChannel: entryChannel,
      synced: false,
    );
    plots.add(plot);
    await HiveCache.savePlot(plot);
    await HiveCache.enqueue('upsert_plot', plot.toCache().map((k, v) => MapEntry(k.toString(), v)));
    notifyListeners();
    return plot;
  }

  // ---------- organic logs ----------
  Future<OrganicLog> addLog({
    required String plotId,
    required String logType,
    required String detail,
    String? photoPath,
  }) async {
    final OrganicLog log = OrganicLog(
      id: _next('LOG'),
      plotId: plotId,
      logType: logType,
      detail: detail,
      logDate: DateTime.now(),
      photoPath: photoPath,
      synced: false,
    );
    logs.add(log);
    await HiveCache.saveLog(log);
    await HiveCache.enqueue('upsert_log', {
      'id': log.id,
      'plotId': plotId,
      'logType': logType,
      'detail': detail,
      'photoPath': photoPath,
    });
    notifyListeners();
    return log;
  }

  // ---------- shop (Yield Buffer enforced) ----------
  ({bool ok, String reason, ShopOrder? order}) placeOrder({
    required String productId,
    required int qty,
  }) {
    final Product product =
        products.firstWhere((p) => p.id == productId);
    if (!canSell(product.harvestQty, product.soldQty, qty,
        product.stockBufferPct)) {
      return (
        ok: false,
        reason:
            'เกิน Yield Buffer ${product.stockBufferPct}% (ขายได้สูงสุด ${sellableQty(product.harvestQty, product.stockBufferPct)} ชิ้น)',
        order: null,
      );
    }
    final OrderBreakdown b = breakdownOrder(product.price * qty);
    final ShopOrder order = ShopOrder(
      id: _next('ORD'),
      buyerBid: currentUser?.id ?? 'B-00001',
      productId: productId,
      qty: qty,
      total: b.subtotal,
      gpFee: b.gpFee,
    );
    product.soldQty += qty;
    orders.add(order);
    notifyListeners();
    return (ok: true, reason: '', order: order);
  }

  // ---------- workshop (capacity enforced) ----------
  ({bool ok, String reason, Booking? booking}) bookWorkshop({
    required String workshopId,
    required int persons,
  }) {
    final Workshop ws =
        workshops.firstWhere((w) => w.id == workshopId);
    if (ws.bookedCount + persons > ws.capacity) {
      return (
        ok: false,
        reason: 'เต็มแล้ว (รับสูงสุด ${ws.capacity} ท่าน)',
        booking: null,
      );
    }
    final Booking booking = Booking(
      id: _next('BK'),
      workshopId: workshopId,
      buyerBid: currentUser?.id ?? 'B-00001',
      persons: persons,
      deposit: workshopDeposit(ws.price * persons),
    );
    ws.bookedCount += persons;
    bookings.add(booking);
    notifyListeners();
    return (ok: true, reason: '', booking: booking);
  }

  // ---------- verify ----------
  void approvePlot(String plotId, {required bool byVillage}) {
    final FarmPlot plot = plots.firstWhere((p) => p.id == plotId);
    if (byVillage) {
      plot.verifierVillage = true;
    } else {
      plot.verifierAgriOfficer = true;
    }
    HiveCache.savePlot(plot);
    notifyListeners();
  }

  // ---------- seed ----------
  void loadSeed() {
    plots.clear();
    logs.clear();
    products.clear();
    orders.clear();
    workshops.clear();
    bookings.clear();
    // 3 pilot farms around Phu Ruea (Loei)
    final List<List<LatLng>> polys = [
      [
        const LatLng(17.4105, 101.3650),
        const LatLng(17.4105, 101.3680),
        const LatLng(17.4080, 101.3680),
        const LatLng(17.4080, 101.3650),
      ],
      [
        const LatLng(17.4150, 101.3720),
        const LatLng(17.4150, 101.3750),
        const LatLng(17.4125, 101.3750),
        const LatLng(17.4125, 101.3720),
      ],
      [
        const LatLng(17.4020, 101.3600),
        const LatLng(17.4020, 101.3625),
        const LatLng(17.4000, 101.3625),
        const LatLng(17.4000, 101.3600),
      ],
    ];
    const names = ['ไร่ภูเรือเหนือ', 'สวนหลังหมู่บ้าน', 'แปลง คทช. ห้วยไผ่'];
    const landTypes = ['chanote', 'spk', 'khor_tor_chor'];
    for (int i = 0; i < 3; i++) {
      plots.add(FarmPlot(
        id: 'PLOT-0000${i + 1}',
        ownerFid: 'F-0000${i + 1}',
        plotName: names[i],
        polygon: polys[i],
        areaGrossRai: double.parse(
            sqmToRai(polygonAreaSqm(polys[i])).toStringAsFixed(2)),
        areaNetRai: double.parse(sqmToRai(
                netAreaSqm(polys[i], defaultBufferMeters))
            .toStringAsFixed(2)),
        lingSourceId: 'seed-ling#$i',
        landType: landTypes[i],
        verifierVillage: i != 2,
        verifierAgriOfficer: i == 0,
      ));
    }
    products.addAll([
      Product(id: 'P-01', farmId: 'PLOT-00001', name: 'สบู่สครับกาแฟ (120g)', price: 135, cost: 60, harvestQty: 200, soldQty: 40),
      Product(id: 'P-02', farmId: 'PLOT-00001', name: 'น้ำมันนวดโรลออน (10ml)', price: 199, cost: 90, harvestQty: 150, soldQty: 20),
      Product(id: 'P-03', farmId: 'PLOT-00002', name: 'กาแฟคั่วภูเรือ (250g)', price: 280, cost: 150, harvestQty: 100, soldQty: 90),
      Product(id: 'P-04', farmId: 'PLOT-00002', name: 'ชาสมุนไพรรวม (20 ซอง)', price: 160, cost: 70, harvestQty: 120, soldQty: 10),
      Product(id: 'P-05', farmId: 'PLOT-00003', name: 'ผักสลัดรวมปลอดสาร (500g)', price: 99, cost: 45, harvestQty: 300, soldQty: 0),
    ]);
    final DateTime now = DateTime.now();
    workshops.addAll([
      Workshop(id: 'W-01', title: 'Workshop ทำโรลออนสมุนไพร', price: 399, capacity: 12, dateTime: now.add(const Duration(days: 7)), bookedCount: 11),
      Workshop(id: 'W-02', title: 'เดินสวน + ชิมกาแฟภูเรือ', price: 399, capacity: 8, dateTime: now.add(const Duration(days: 14)), bookedCount: 3),
    ]);
    logs.add(OrganicLog(
      id: 'LOG-00001',
      plotId: 'PLOT-00001',
      logType: 'seed',
      detail: 'เพาะเมล็ดกาแฟอาราบิก้า แปลงที่ 1',
      logDate: now.subtract(const Duration(days: 30)),
    ));
    notifyListeners();
  }
}
