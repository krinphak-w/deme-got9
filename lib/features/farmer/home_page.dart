import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
import '../../core/thai_units.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /farmer/home — my plots + add-plot menu (4 channels) + QR per plot.
class FarmerHomePage extends StatefulWidget {
  const FarmerHomePage({super.key});

  @override
  State<FarmerHomePage> createState() => _FarmerHomePageState();
}

class _FarmerHomePageState extends State<FarmerHomePage> {
  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final String fid = state.currentUser?.id ?? 'F-00001';
    final List<FarmPlot> mine =
        state.plots.where((p) => p.ownerFid == fid).toList();

    return Scaffold(
      appBar: Got9Bar(title: state.tr('myPlots'), actions: [
        IconButton(
          tooltip: state.tr('trace'),
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => _scanHint(context, state),
        ),
      ]),
      bottomNavigationBar: const Got9Nav(index: 0),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.add_location_alt),
            label: Text(state.tr('addPlot')),
            onPressed: () => context.go('/farmer/plot/add'),
          ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: Text(state.tr('farmLog')),
                  onPressed: () => context.go('/farmer/log'),
                ),
                const SizedBox(height: 8),
                for (final plot in mine) _plotCard(context, state, plot),
                if (mine.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('ยังไม่มีแปลง — กดนำเข้าจาก Ling ด้านบน',
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
    );
  }

  Widget _plotCard(BuildContext context, AppState state, FarmPlot plot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plot.plotName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _landChip(plot.landType),
                const SizedBox(width: 6),
                Icon(
                  plot.verified ? Icons.verified : Icons.pending,
                  color: plot.verified ? Colors.green : Colors.orange,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(plot.channelLabel,
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
                if (plot.docPhotoPath != null)
                  const Chip(
                    label: Text('มีเอกสารสิทธิ์',
                        style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(
                'รวม ${formatRaiNganWah(plot.areaGrossRai * 1600)} • ปลูกได้ ${formatRaiNganWah(plot.areaNetRai * 1600)}'),
            if (plot.lingSourceId != null)
              Text('Ling: ${plot.lingSourceId}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (plot.hasMap)
              SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: centroid(plot.polygon!),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: plot.polygon!,
                          color: Colors.green.withValues(alpha: 0.35),
                          borderColor: Colors.green.shade800,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('ไม่มีแผนที่ (กรอกข้อมูลเอง) — ไปวาดเพิ่มได้จากเมนู + เพิ่มแปลง'),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Trace'),
                    onPressed: () =>
                        _showQr(context, state, plot),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    child: Text(state.tr('verify')),
                    onPressed: () => context.go('/admin/verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _landChip(String landType) {
    const labels = {
      'chanote': 'โฉนด',
      'spk': 'ส.ป.ก.',
      'khor_tor_chor': 'คทช.',
    };
    return Chip(
      label: Text(labels[landType] ?? landType),
      visualDensity: VisualDensity.compact,
    );
  }

  void _showQr(BuildContext context, AppState state, FarmPlot plot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(plot.plotName),
        content: SizedBox(
          width: 220,
          height: 260,
          child: Column(
            children: [
              QrImageView(data: 'got9://trace/${plot.id}', size: 200),
              Text('/trace/${plot.id}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/trace/${plot.id}');
            },
            child: Text(state.tr('trace')),
          ),
        ],
      ),
    );
  }

  void _scanHint(BuildContext context, AppState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('V1: เปิดกล้องสแกน QR หน้าแปลง หรือกด QR Trace จากการ์ดแปลง')),
    );
  }
}

/// Reusable polygon preview (also used by trace page).
class PlotMiniMap extends StatelessWidget {
  const PlotMiniMap(
      {super.key, required this.polygon, this.height = 160});

  final List<LatLng> polygon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: centroid(polygon),
          initialZoom: 15,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygon,
                color: Colors.green.withValues(alpha: 0.35),
                borderColor: Colors.green.shade800,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
