import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

// Buffer-zone geometry: expand a plot polygon outward by [meters] so the
// map can paint the red "no-spray" ring under the green plot fill.
// Pure math — unit tested.
List<LatLng> bufferedPolygon(List<LatLng> points, double meters) {
  if (points.length < 3 || meters <= 0) return List.of(points);
  double sumLat = 0;
  for (final p in points) {
    sumLat += p.latitude;
  }
  final double lat0 = (sumLat / points.length) * math.pi / 180;
  const double earthR = 6371000.0;
  math.Point<double> toXY(LatLng p) => math.Point<double>(
        earthR * (p.longitude * math.pi / 180) * math.cos(lat0),
        earthR * (p.latitude * math.pi / 180),
      );
  LatLng toLatLng(math.Point<double> m) => LatLng(
        (m.y / earthR) * 180 / math.pi,
        (m.x / earthR) * 180 / math.pi / math.cos(lat0),
      );
  final List<math.Point<double>> xy = points.map(toXY).toList();

  // Signed area: >0 means counter-clockwise in x-right/y-up space.
  double signed = 0;
  for (int i = 0; i < xy.length; i++) {
    final a = xy[i];
    final b = xy[(i + 1) % xy.length];
    signed += a.x * b.y - b.x * a.y;
  }
  final bool ccw = signed > 0;

  // Offset every edge outward, then intersect consecutive offset lines.
  final int n = xy.length;
  final List<({math.Point<double> p, math.Point<double> dir})> lines =
      [];
  for (int i = 0; i < n; i++) {
    final a = xy[i];
    final b = xy[(i + 1) % n];
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) continue;
    // Outward normal: right side of edge for CCW, left side for CW.
    final double nx = ccw ? dy / len : -dy / len;
    final double ny = ccw ? -dx / len : dx / len;
    lines.add((
      p: math.Point<double>(a.x + nx * meters, a.y + ny * meters),
      dir: math.Point<double>(dx / len, dy / len),
    ));
  }
  if (lines.length < 3) return List.of(points);

  math.Point<double> intersect(
      ({math.Point<double> p, math.Point<double> dir}) l1,
      ({math.Point<double> p, math.Point<double> dir}) l2) {
    final double cross =
        l1.dir.x * l2.dir.y - l1.dir.y * l2.dir.x;
    if (cross.abs() < 1e-9) {
      return l1.p; // near-parallel: fall back to offset point
    }
    final double dx = l2.p.x - l1.p.x;
    final double dy = l2.p.y - l1.p.y;
    final double t = (dx * l2.dir.y - dy * l2.dir.x) / cross;
    return math.Point<double>(
        l1.p.x + l1.dir.x * t, l1.p.y + l1.dir.y * t);
  }

  final List<LatLng> out = [];
  for (int i = 0; i < lines.length; i++) {
    final prev = lines[(i - 1 + lines.length) % lines.length];
    out.add(toLatLng(intersect(prev, lines[i])));
  }
  return out;
}

/// Fraction of the pre-order quota already sold (0..1), for progress bars.
double bufferFillPct(int harvestQty, int soldQty, double bufferPct) {
  final int sellable =
      ((harvestQty * (100 - bufferPct)) / 100).floor();
  if (sellable <= 0) return 1;
  return (soldQty / sellable).clamp(0.0, 1.0);
}
