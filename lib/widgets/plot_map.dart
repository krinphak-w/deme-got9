import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/buffer_zone.dart';
import '../core/constants.dart';
import '../core/thai_units.dart';

// Shared OSM plot map: green plot fill + red buffer-zone ring underneath.
// Used by farmer home, trace page and the mock showcase.
class PlotMapView extends StatelessWidget {
  const PlotMapView({
    super.key,
    required this.polygon,
    this.height = 160,
    this.interactive = true,
    this.neighbor,
    this.bufferMeters = defaultBufferMeters,
  });

  final List<LatLng> polygon;
  final double height;
  final bool interactive;
  final List<LatLng>? neighbor;
  final double bufferMeters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: centroid(polygon),
              initialZoom: 15,
              interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points:
                        bufferedPolygon(polygon, bufferMeters),
                    color: Colors.red.withValues(alpha: 0.28),
                    borderColor: Colors.red.shade400,
                    borderStrokeWidth: 1,
                  ),
                  if (neighbor != null)
                    Polygon(
                      points: neighbor!,
                      color: Colors.grey.withValues(alpha: 0.30),
                      borderColor: Colors.grey,
                      borderStrokeWidth: 1,
                    ),
                  Polygon(
                    points: polygon,
                    color: Colors.green.withValues(alpha: 0.40),
                    borderColor: Colors.green.shade800,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          'เขียว = แปลงปลูก • แดง = แนวกันชน ${bufferMeters.toInt()} ม. (กันปนเปื้อน)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
