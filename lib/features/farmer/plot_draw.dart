import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/thai_units.dart';
import '../../data/app_state.dart';

/// /farmer/plot/draw — tap the map to drop boundary points, then save.
class PlotDrawPage extends StatefulWidget {
  const PlotDrawPage({super.key});

  @override
  State<PlotDrawPage> createState() => _PlotDrawPageState();
}

class _PlotDrawPageState extends State<PlotDrawPage> {
  final List<LatLng> _points = [];
  final MapController _map = MapController();
  final TextEditingController _name =
      TextEditingController(text: 'แปลงวาดใหม่');
  String _landType = 'chanote';
  bool _saving = false;

  static const LatLng _phuRuea = LatLng(17.4105, 101.3650);

  @override
  void dispose() {
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _save(AppState state) async {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แตะแผนที่อย่างน้อย 3 จุดก่อน')));
      return;
    }
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ตั้งชื่อแปลงก่อน')));
      return;
    }
    setState(() => _saving = true);
    await state.addPlot(
      plotName: _name.text.trim(),
      polygon: List.of(_points),
      landType: _landType,
      entryChannel: 'draw',
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกแปลงแล้ว')));
      context.go('/farmer/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final String area = _points.length >= 3
        ? formatRaiNganWah(polygonAreaSqm(_points))
        : '—';
    return Scaffold(
      appBar: Got9Bar(title: 'วาดแปลง / Draw', actions: [
        IconButton(
          tooltip: 'ย้อน 1 จุด',
          icon: const Icon(Icons.undo),
          onPressed: _points.isEmpty
              ? null
              : () => setState(() => _points.removeLast()),
        ),
        IconButton(
          tooltip: 'ล้างทั้งหมด',
          icon: const Icon(Icons.delete_outline),
          onPressed: _points.isEmpty
              ? null
              : () => setState(() => _points.clear()),
        ),
      ]),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _phuRuea,
                initialZoom: 15,
                onTap: (_, latlng) =>
                    setState(() => _points.add(latlng)),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (_points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _points,
                        color: Colors.green.withValues(alpha: 0.35),
                        borderColor: Colors.green.shade800,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (int i = 0; i < _points.length; i++)
                      Marker(
                        point: _points[i],
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('แตะแผนที่ปักหมุด (${_points.length} จุด) • เนื้อที่: $area'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อแปลง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _landType,
                      items: const [
                        DropdownMenuItem(
                            value: 'chanote', child: Text('โฉนด')),
                        DropdownMenuItem(
                            value: 'spk', child: Text('ส.ป.ก.')),
                        DropdownMenuItem(
                            value: 'khor_tor_chor',
                            child: Text('คทช.')),
                      ],
                      onChanged: (v) =>
                          setState(() => _landType = v ?? 'chanote'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _saving ? null : () => _save(state),
                    child: Text(state.tr('save')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
