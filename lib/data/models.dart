// Plain data models shared by mock store and Supabase rows.
import 'package:latlong2/latlong.dart';

enum UserRole { farmer, buyer, corporate }

extension UserRoleX on UserRole {
  String get code => switch (this) {
        UserRole.farmer => 'F',
        UserRole.buyer => 'B',
        UserRole.corporate => 'C',
      };

  static UserRole fromCode(String code) => switch (code) {
        'F' => UserRole.farmer,
        'C' => UserRole.corporate,
        _ => UserRole.buyer,
      };
}

class AppUser {
  AppUser({
    required this.id,
    required this.role,
    required this.displayName,
    required this.phone,
    this.kycStatus = 'pending',
    this.consentPdpa = false,
    this.avatarPath,
  });

  final String id; // e.g. F-00001
  final UserRole role;
  String displayName;
  String phone;
  String kycStatus;
  bool consentPdpa;
  String? avatarPath;
}

class FarmPlot {
  FarmPlot({
    required this.id,
    required this.ownerFid,
    required this.plotName,
    this.polygon,
    required this.areaGrossRai,
    required this.areaNetRai,
    this.lingSourceId,
    this.landType = 'chanote',
    this.verifierVillage = false,
    this.verifierAgriOfficer = false,
    this.synced = true,
    this.docPhotoPath,
    this.entryChannel = 'ling',
  });

  final String id;
  final String ownerFid;
  String plotName;
  /// Null when the plot was entered manually without a map shape.
  List<LatLng>? polygon;
  double areaGrossRai;
  double areaNetRai;
  String? lingSourceId;
  String landType; // chanote | spk | khor_tor_chor
  bool verifierVillage;
  bool verifierAgriOfficer;
  bool synced; // false = waiting for Hive queue sync
  String? docPhotoPath; // land-right document photo (proof of land)
  /// ling | draw | gps_walk | manual
  String entryChannel;

  bool get verified => verifierVillage && verifierAgriOfficer;
  bool get hasMap => polygon != null && polygon!.length >= 3;

  String get channelLabel => switch (entryChannel) {
        'ling' => 'นำเข้าจาก Ling',
        'draw' => 'วาดบนแผนที่',
        'gps_walk' => 'เดินเก็บ GPS',
        _ => 'กรอกเอง',
      };

  Map<String, dynamic> toCache() => {
        'id': id,
        'ownerFid': ownerFid,
        'plotName': plotName,
        'polygon': polygon
            ?.map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'areaGrossRai': areaGrossRai,
        'areaNetRai': areaNetRai,
        'lingSourceId': lingSourceId,
        'landType': landType,
        'verifierVillage': verifierVillage,
        'verifierAgriOfficer': verifierAgriOfficer,
        'docPhotoPath': docPhotoPath,
        'entryChannel': entryChannel,
      };

  static FarmPlot fromCache(Map<dynamic, dynamic> m) {
    final List<dynamic>? polyRaw = m['polygon'] as List?;
    return FarmPlot(
      id: m['id'] as String,
      ownerFid: m['ownerFid'] as String,
      plotName: m['plotName'] as String,
      polygon: polyRaw
          ?.map((e) => LatLng((e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble()))
          .toList(),
      areaGrossRai: (m['areaGrossRai'] as num).toDouble(),
      areaNetRai: (m['areaNetRai'] as num).toDouble(),
      lingSourceId: m['lingSourceId'] as String?,
      landType: (m['landType'] as String?) ?? 'chanote',
      verifierVillage: (m['verifierVillage'] as bool?) ?? false,
      verifierAgriOfficer: (m['verifierAgriOfficer'] as bool?) ?? false,
      docPhotoPath: m['docPhotoPath'] as String?,
      entryChannel: (m['entryChannel'] as String?) ?? 'ling',
    );
  }
}

class OrganicLog {
  OrganicLog({
    required this.id,
    required this.plotId,
    required this.logType,
    required this.detail,
    required this.logDate,
    this.photoPath,
    this.synced = true,
  });

  final String id;
  final String plotId;
  final String logType; // seed|input|cleaning|harvest|activity|neighbor
  final String detail;
  final DateTime logDate;
  final String? photoPath;
  bool synced;

  Map<String, dynamic> toCache() => {
        'id': id,
        'plotId': plotId,
        'logType': logType,
        'detail': detail,
        'logDate': logDate.toIso8601String(),
        'photoPath': photoPath,
      };

  static OrganicLog fromCache(Map<dynamic, dynamic> m) => OrganicLog(
        id: m['id'] as String,
        plotId: m['plotId'] as String,
        logType: m['logType'] as String,
        detail: m['detail'] as String,
        logDate: DateTime.parse(m['logDate'] as String),
        photoPath: m['photoPath'] as String?,
      );
}

class Product {
  Product({
    required this.id,
    required this.farmId,
    required this.name,
    required this.price,
    required this.cost,
    required this.harvestQty,
    required this.soldQty,
    this.stockBufferPct = 70,
    this.active = true,
    this.photoPath,
  });

  final String id;
  final String farmId;
  final String name;
  final double price;
  final double cost;
  final int harvestQty;
  int soldQty;
  final double stockBufferPct;
  bool active;
  String? photoPath;
}

class ShopOrder {
  ShopOrder({
    required this.id,
    required this.buyerBid,
    required this.productId,
    required this.qty,
    required this.total,
    required this.gpFee,
    this.status = 'pending',
  });

  final String id;
  final String buyerBid;
  final String productId;
  final int qty;
  final double total;
  final double gpFee;
  String status;
}

class Workshop {
  Workshop({
    required this.id,
    required this.title,
    required this.price,
    required this.capacity,
    required this.dateTime,
    required this.bookedCount,
    this.status = 'open',
  });

  final String id;
  final String title;
  final double price;
  final int capacity;
  final DateTime dateTime;
  int bookedCount;
  String status;

  int get seatsLeft => capacity - bookedCount;
}

class Booking {
  Booking({
    required this.id,
    required this.workshopId,
    required this.buyerBid,
    required this.persons,
    required this.deposit,
    this.status = 'confirmed',
  });

  final String id;
  final String workshopId;
  final String buyerBid;
  final int persons;
  final double deposit;
  String status;
}
