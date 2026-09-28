import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/thai_units.dart';
import '../../data/app_state.dart';

/// /farmer/plot/walk — walk the boundary, GPS records the polygon.
class PlotWalkPage extends StatefulWidget {
  const PlotWalkPage({super.key});

  @override
  State<PlotWalkPage> createState() => _PlotWalkPageState();
}

class _PlotWalkPageState extends State<PlotWalkPage> {
  final List<LatLng> _track = [];
  final MapController _map = MapController();
  final TextEditingController _name =
      TextEditingController(text: 'แปลงเดิน GPS');
  String _landType = 'chanote';
  StreamSubscription<Position>? _sub;
  bool _recording = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _sub?.cancel();
      setState(() => _recording = false);
      return;
    }
    setState(() => _error = null);
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _error = 'ต้องอนุญาตใช้ตำแหน่งก่อน (Location permission)');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'กรุณาเปิด GPS ของเครื่องก่อน');
      return;
    }
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // record every ~5 m
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      if (!mounted || !_recording) return;
      final LatLng p = LatLng(pos.latitude, pos.longitude);
      if (_track.isEmpty ||
          const Distance()(p, _track.last) >= 3) {
        setState(() => _track.add(p));
        _map.move(p, _map.camera.zoom);
      }
    });
    setState(() => _recording = true);
  }

  Future<void> _save(AppState state) async {
    if (_track.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('เดินเก็บอย่างน้อย 3 จุดก่อน (เดินวนรอบแปลง)')));
      return;
    }
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ตั้งชื่อแปลงก่อน')));
      return;
    }
    await _sub?.cancel();
    setState(() {
      _recording = false;
      _saving = true;
    });
    await state.addPlot(
      plotName: _name.text.trim(),
      polygon: List.of(_track),
      landType: _landType,
      entryChannel: 'gps_walk',
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
    final LatLng center = _track.isNotEmpty
        ? _track.last
        : const LatLng(17.4105, 101.3650);
    final String area = _track.length >= 3
        ? formatRaiNganWah(polygonAreaSqm(_track))
        : '—';
    return Scaffold(
      appBar: Got9Bar(title: 'เดินรอบแปลง / GPS walk'),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (_track.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _track,
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderColor: Colors.blue.shade800,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: _track,
                        color: Colors.blue,
                        strokeWidth: 3),
                  ],
                ),
                if (_track.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _track.last,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_pin,
                              size: 18, color: Colors.white),
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
                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                Text(
                    '${_recording ? '● กำลังบันทึก' : 'หยุดบันทึก'} • ${_track.length} จุด • เนื้อที่: $area'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: Icon(_recording
                            ? Icons.stop
                            : Icons.play_arrow),
                        label: Text(_recording ? 'หยุด' : 'เริ่มเดิน'),
                        onPressed: _toggleRecord,
                      ),
                    ),
                    const SizedBox(width: 8),
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
