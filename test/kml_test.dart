import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:got9_phase1/core/kml_parser.dart';
import 'package:got9_phase1/core/thai_units.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('sample KML imports 2 plots with correct area', () {
    final bytes = File('assets/sample_ling.kml').readAsBytesSync();
    final plots = parseLingFile('sample_ling.kml', bytes);
    expect(plots.length, 2);
    expect(plots.first.plotName, contains('บ้านหลังสวน'));

    // 0.003° lng x 0.0025° lat near lat 17.4 ≈ 319m x 278m ≈ 55 rai
    final double gross = sqmToRai(polygonAreaSqm(plots.first.polygon));
    expect(gross, greaterThan(50.0));
    expect(gross, lessThan(60.0));

    final double net = sqmToRai(netAreaSqm(plots.first.polygon, 2.0));
    expect(net, lessThan(gross)); // buffer subtracted
    expect(net, greaterThan(0));
  });

  test('thai units format', () {
    expect(formatRaiNganWah(1600), '1 ไร่ 0 งาน 0.0 ตารางวา');
    expect(formatRaiNganWah(2000), '1 ไร่ 1 งาน 0.0 ตารางวา');
  });

  test('degenerate polygon returns 0', () {
    expect(polygonAreaSqm([const LatLng(0, 0)]), 0);
  });

  test('manual rai-ngan-wah converts + square net approx', () {
    expect(raiNganWahToSqm(1, 2, 50), 1600 + 800 + 200);
    // 1 rai square ≈ 40m side; buffer 2m -> net < gross, > 0
    final double net = netSquareApproxSqm(1600, 2.0);
    expect(net, lessThan(1600));
    expect(net, greaterThan(1000));
    expect(netSquareApproxSqm(0, 2.0), 0);
  });
}
