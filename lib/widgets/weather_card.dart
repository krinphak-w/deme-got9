import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/hive_cache.dart';

// Free weather for the F-ID dashboard (Open-Meteo, no API key).
// Falls back to the last cached value when offline.
class WeatherCard extends StatefulWidget {
  const WeatherCard(
      {super.key, this.lat = 17.4105, this.lng = 101.3650, this.label = 'ภูเรือ'});

  final double lat;
  final double lng;
  final String label;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  double? _temp;
  int? _humidity;
  String? _time;
  bool _live = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Show cache first (works offline).
    final double? cTemp = HiveCache.getPref<double>('weather:temp');
    final int? cHum = HiveCache.getPref<int>('weather:humidity');
    final String? cTime = HiveCache.getPref<String>('weather:time');
    if (mounted && cTemp != null) {
      setState(() {
        _temp = cTemp;
        _humidity = cHum;
        _time = cTime;
      });
    }
    try {
      final Uri url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${widget.lat}&longitude=${widget.lng}&current=temperature_2m,relative_humidity_2m&timezone=Asia%2FBangkok');
      final http.Response res =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final Map<String, dynamic> json =
          jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, dynamic> cur =
          json['current'] as Map<String, dynamic>;
      final double temp = (cur['temperature_2m'] as num).toDouble();
      final int hum = (cur['relative_humidity_2m'] as num).toInt();
      final String time = (cur['time'] as String).replaceAll('T', ' ');
      await HiveCache.setPref('weather:temp', temp);
      await HiveCache.setPref('weather:humidity', hum);
      await HiveCache.setPref('weather:time', time);
      if (mounted) {
        setState(() {
          _temp = temp;
          _humidity = hum;
          _time = time;
          _live = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.lightBlue.shade50,
      child: ListTile(
        leading: Icon(_live ? Icons.wb_sunny : Icons.cloud_off,
            size: 36, color: Colors.orange.shade700),
        title: _loading && _temp == null
            ? const Text('กำลังโหลดอากาศ...')
            : Text(_temp == null
                ? 'ไม่มีข้อมูลอากาศ (ออฟไลน์)'
                : '${widget.label} ${_temp!.toStringAsFixed(1)}°C • ชื้น $_humidity%'),
        subtitle: Text(_live
            ? 'สดจาก Open-Meteo • $_time'
            : 'ค่าล่าสุดที่บันทึกไว้ (ออฟไลน์) • ${_time ?? '-'}'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      ),
    );
  }
}
