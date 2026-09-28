import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// Result of parsing one Ling-exported plot file.
class LingPlot {
  LingPlot({
    required this.plotName,
    required this.polygon,
    this.sourceId,
  });

  final String plotName;
  final List<LatLng> polygon;
  final String? sourceId;

  Map<String, dynamic> toGeoJson() => {
        'type': 'Polygon',
        'coordinates': [
          [
            ...polygon.map((p) => [p.longitude, p.latitude]),
            [polygon.first.longitude, polygon.first.latitude],
          ],
        ],
      };
}

/// Parse KML / KMZ / GeoJSON bytes exported from Ling into [LingPlot]s.
///
/// KML coordinates are lng,lat[,alt] tuples. KMZ is a zip containing a
/// `doc.kml`. GeoJSON accepts Polygon / MultiPolygon / FeatureCollection.
List<LingPlot> parseLingFile(String fileName, List<int> bytes) {
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.kmz')) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('.kml') && file.isFile) {
        return _parseKml(
            utf8.decode(file.content as List<int>), fileName);
      }
    }
    throw const FormatException('KMZ contains no doc.kml');
  }
  final String text = utf8.decode(bytes);
  if (lower.endsWith('.geojson') || lower.endsWith('.json')) {
    return _parseGeoJson(text, fileName);
  }
  return _parseKml(text, fileName); // default: .kml
}

List<LingPlot> _parseKml(String text, String fileName) {
  final XmlDocument doc = XmlDocument.parse(text);
  final List<LingPlot> plots = [];
  int index = 0;
  for (final placemark in doc.findAllElements('Placemark')) {
    final String name = placemark
            .getElement('name')
            ?.innerText
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .replaceAll(RegExp(r'^$'), 'แปลงไม่มีชื่อ') ??
        'แปลงไม่มีชื่อ';
    final coords = placemark
        .findAllElements('coordinates')
        .map((e) => e.innerText)
        .join(' ');
    final List<LatLng> polygon = _parseKmlCoords(coords);
    if (polygon.length < 3) continue;
    index++;
    plots.add(LingPlot(
      plotName: name.isEmpty ? 'แปลงไม่มีชื่อ' : name,
      polygon: polygon,
      sourceId: '$fileName#$index',
    ));
  }
  if (plots.isEmpty) {
    throw const FormatException('No Polygon Placemark found in KML');
  }
  return plots;
}

List<LatLng> _parseKmlCoords(String raw) {
  final List<LatLng> points = [];
  for (final token in raw.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final List<String> parts = token.split(',');
    if (parts.length < 2) continue;
    final double? lng = double.tryParse(parts[0]);
    final double? lat = double.tryParse(parts[1]);
    if (lng == null || lat == null) continue;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    points.add(LatLng(lat, lng));
  }
  return points;
}

List<LingPlot> _parseGeoJson(String text, String fileName) {
  final dynamic json = jsonDecode(text);
  final List<dynamic> features = [];
  if (json is Map<String, dynamic>) {
    if (json['type'] == 'FeatureCollection') {
      features.addAll(json['features'] as List<dynamic>);
    } else if (json['type'] == 'Feature') {
      features.add(json);
    } else {
      features.add({'type': 'Feature', 'properties': {}, 'geometry': json});
    }
  }
  final List<LingPlot> plots = [];
  int index = 0;
  for (final f in features) {
    final Map<String, dynamic> feature = f as Map<String, dynamic>;
    final Map<String, dynamic>? geometry =
        feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;
    final List<List<dynamic>> rings = _geoJsonRings(geometry);
    if (rings.isEmpty) continue;
    final Map<String, dynamic>? props =
        feature['properties'] as Map<String, dynamic>?;
    index++;
    plots.add(LingPlot(
      plotName: props?['name']?.toString() ??
          props?['plot_name']?.toString() ??
          'แปลงที่ $index',
      polygon: rings.first
          .map((c) => LatLng((c[1] as num).toDouble(),
              (c[0] as num).toDouble()))
          .toList(),
      sourceId: '$fileName#$index',
    ));
  }
  if (plots.isEmpty) {
    throw const FormatException('No Polygon geometry found in GeoJSON');
  }
  return plots;
}

List<List<dynamic>> _geoJsonRings(Map<String, dynamic> geometry) {
  final String? type = geometry['type'] as String?;
  final dynamic coords = geometry['coordinates'];
  if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    return [(coords.first as List).cast<dynamic>()];
  }
  if (type == 'MultiPolygon' && coords is List && coords.isNotEmpty) {
    return coords
        .map((poly) => ((poly as List).first as List).cast<dynamic>())
        .toList();
  }
  return [];
}
