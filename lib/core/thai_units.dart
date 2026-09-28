// Thai land-unit helpers. 1 rai = 4 ngan = 400 sq wah = 1600 sqm.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Project [points] (lat/lng) to meters with an equirectangular projection
/// around the polygon centroid, then apply the shoelace formula.
double polygonAreaSqm(List<LatLng> points) {
  if (points.length < 3) return 0;
  double sumLat = 0;
  for (final p in points) {
    sumLat += p.latitude;
  }
  final double lat0 = (sumLat / points.length) * math.pi / 180;
  const double earthR = 6371000.0;
  final List<math.Point<double>> xy = points.map((p) {
    final double x = earthR *
        (p.longitude * math.pi / 180) *
        math.cos(lat0);
    final double y = earthR * (p.latitude * math.pi / 180);
    return math.Point<double>(x, y);
  }).toList();
  double area = 0;
  for (int i = 0; i < xy.length; i++) {
    final a = xy[i];
    final b = xy[(i + 1) % xy.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area.abs() / 2;
}

/// Approximate perimeter in meters (same projection as [polygonAreaSqm]).
double polygonPerimeterM(List<LatLng> points) {
  if (points.length < 2) return 0;
  double sumLat = 0;
  for (final p in points) {
    sumLat += p.latitude;
  }
  final double lat0 = (sumLat / points.length) * math.pi / 180;
  const double earthR = 6371000.0;
  double dist(math.Point<double> a, math.Point<double> b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  final List<math.Point<double>> xy = points.map((p) {
    final double x = earthR *
        (p.longitude * math.pi / 180) *
        math.cos(lat0);
    final double y = earthR * (p.latitude * math.pi / 180);
    return math.Point<double>(x, y);
  }).toList();
  double total = 0;
  for (int i = 0; i < xy.length; i++) {
    total += dist(xy[i], xy[(i + 1) % xy.length]);
  }
  return total;
}

/// Net plantable area after subtracting a buffer strip of [bufferM] meters
/// around the polygon edge: net = gross - perimeter*buffer + pi*buffer^2.
double netAreaSqm(List<LatLng> points, double bufferM) {
  final double gross = polygonAreaSqm(points);
  final double perim = polygonPerimeterM(points);
  final double net =
      gross - perim * bufferM + math.pi * bufferM * bufferM;
  return net < 0 ? 0 : net;
}

/// Convert square meters to rai (1 rai = 1600 sqm).
double sqmToRai(double sqm) => sqm / 1600.0;

/// Convert rai-ngan-wah to square meters.
double raiNganWahToSqm(int rai, int ngan, double wah) =>
    rai * 1600.0 + ngan * 400.0 + wah * 4.0;

/// Net-area estimate for manually entered plots without a map shape:
/// assumes a square field of [sqm] then subtracts the buffer strip.
double netSquareApproxSqm(double sqm, double bufferM) {
  if (sqm <= 0) return 0;
  final double side = math.sqrt(sqm);
  final double net = sqm - 4 * side * bufferM + math.pi * bufferM * bufferM;
  return net < 0 ? 0 : net;
}

/// Format "X ไร่ Y งาน Z ตารางวา" from square meters.
String formatRaiNganWah(double sqm) {
  final double totalWah = sqm / 4;
  final int rai = totalWah ~/ 400;
  final int ngan = (totalWah % 400) ~/ 100;
  final double wah = totalWah % 100;
  return '$rai ไร่ $ngan งาน ${wah.toStringAsFixed(1)} ตารางวา';
}

/// Centroid of a polygon (simple average, good enough for MVP labels).
LatLng centroid(List<LatLng> points) {
  double lat = 0, lng = 0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}
