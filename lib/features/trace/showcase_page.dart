import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app.dart';
import '../../core/buffer_zone.dart';
import '../../core/constants.dart';
import '../../core/kml_parser.dart';

// Public AI-storytelling showcase (ALL DATA MOCK for demo).
// Simulates what a B-ID buyer sees after scanning a QR on the plot or box.
class TraceShowcasePage extends StatefulWidget {
  const TraceShowcasePage({super.key});

  @override
  State<TraceShowcasePage> createState() => _TraceShowcasePageState();
}

// Mock 7-day weather behind the story.
const List<({String day, double temp, double humidity})> _mockWeather = [
  (day: 'จ', temp: 24.5, humidity: 78),
  (day: 'อ', temp: 26.0, humidity: 74),
  (day: 'พ', temp: 28.5, humidity: 68),
  (day: 'พฤ', temp: 29.0, humidity: 65),
  (day: 'ศ', temp: 27.0, humidity: 72),
  (day: 'ส', temp: 25.5, humidity: 80),
  (day: 'อา', temp: 24.0, humidity: 84),
];

const List<({String title, String detail})> _timeline = [
  (title: 'เตรียมดิน (ส.ค.)', detail: 'ไถพรวน + ใส่ปุ๋ยหมัก ไม่ใช้สารเคมีมา 3 ปี'),
  (title: 'ปลูกขิง (ก.ย.)', detail: 'เหง้าพันธุ์ภูเรือ ระยะ 25x25 ซม. แปลงสาธิต 3 งาน'),
  (title: 'ดูแลอินทรีย์ (ก.ย.–ธ.ค.)', detail: 'น้ำหมักชีวภาพ + คลุมฟาง ตรวจแปลงทุก 2 สัปดาห์'),
  (title: 'เก็บเกี่ยว (ม.ค.)', detail: 'ขุดมือ คัดเหง้าแก่ ได้น้ำหนัก 420 กก.'),
  (title: 'แปรรูป (ก.พ.)', detail: 'ต้ม-เคี่ยว-ขึ้นรูปเยลลี่หมีขิง FREYA FLOW ล็อต #001'),
];

class _TraceShowcasePageState extends State<TraceShowcasePage> {
  List<LatLng>? _plot;
  List<LatLng>? _neighbor;

  @override
  void initState() {
    super.initState();
    _loadDemo();
  }

  Future<void> _loadDemo() async {
    final String text =
        await rootBundle.loadString('assets/demo_buffer.geojson');
    final List<LingPlot> plots = parseGeoJsonText(text, 'demo');
    if (!mounted) return;
    setState(() {
      _plot = plots.isNotEmpty ? plots.first.polygon : null;
      _neighbor = plots.length > 1 ? plots[1].polygon : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Got9Bar(title: 'QR Story / ตัวอย่าง'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: const Text(
              'ข้อมูลจำลองทั้งหมดเพื่อสาธิต (Mock) — แบรนด์ FREYA FLOW เป็นตัวอย่างประกอบ ไม่ใช่สินค้าจริงในระบบ',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Text('เยลลี่หมีขิง FREYA FLOW ล็อต #001',
              style: Theme.of(context).textTheme.headlineSmall),
          const Text('จากขิงอินทรีย์แปลงสาธิต 3 งาน ภูเรือ • PGS (mock) • Year 1'),
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Colors.green.shade800, size: 20),
                      const SizedBox(width: 6),
                      Text('เล่าโดย AI (จำลอง)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ขิงล็อตนี้โตในอากาศหนาวภูเรือ 24–29°C ช่วง ก.ย.–ม.ค. '
                    'ดินพักสารเคมีมา 3 ปีเต็ม น้ำค้างแรงทำให้เหง้าแก่ช้า '
                    'สะสมน้ำมันหอมระเหยมากกว่าขิงที่ราบประมาณ 2 เท่า '
                    'จึงเผ็ดหอมลึก เหมาะเคี่ยวเป็นเยลลี่ที่ไม่ต้องแต่งกลิ่นเลย',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('ไทม์ไลน์การปลูก → แปรรูป',
              style: Theme.of(context).textTheme.titleMedium),
          for (int i = 0; i < _timeline.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 12)),
              ),
              title: Text(_timeline[i].title),
              subtitle: Text(_timeline[i].detail),
            ),
          const SizedBox(height: 8),
          Text('สภาพอากาศจำลอง 7 วัน (Open-Meteo style)',
              style: Theme.of(context).textTheme.titleMedium),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _WeatherChartPainter(_mockWeather),
                  child: Container(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('แผนที่แปลง + แนวกันชน (จำลอง)',
              style: Theme.of(context).textTheme.titleMedium),
          if (_plot != null)
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _plot!.first,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: bufferedPolygon(
                            _plot!, defaultBufferMeters),
                        color: Colors.red.withValues(alpha: 0.30),
                        borderColor: Colors.red,
                        borderStrokeWidth: 1,
                      ),
                      if (_neighbor != null)
                        Polygon(
                          points: _neighbor!,
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderColor: Colors.grey,
                          borderStrokeWidth: 1,
                          label: 'แปลงข้างเคียง (เคมี)',
                        ),
                      Polygon(
                        points: _plot!,
                        color:
                            Colors.green.withValues(alpha: 0.45),
                        borderColor: Colors.green.shade800,
                        borderStrokeWidth: 2,
                        label: 'แปลงอินทรีย์',
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          const Text('เขียว = แปลงอินทรีย์ • แดง = แนวกันชน 2 ม. • เทา = แปลงข้างเคียง',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/shop'),
              child: const Text('พรีออเดอร์ล็อตนี้ / Pre-order'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherChartPainter extends CustomPainter {
  _WeatherChartPainter(this.data);

  final List<({String day, double temp, double humidity})> data;

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 30, padB = 20, padT = 8, padR = 8;
    final double w = size.width - padL - padR;
    final double h = size.height - padT - padB;
    double minT = data.map((e) => e.temp).reduce((a, b) => a < b ? a : b) - 1;
    double maxT = data.map((e) => e.temp).reduce((a, b) => a > b ? a : b) + 1;
    Offset pt(int i) => Offset(
          padL + w * i / (data.length - 1),
          padT + h * (1 - (data[i].temp - minT) / (maxT - minT)),
        );
    final Paint grid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final double y = padT + h * g / 4;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), grid);
    }
    final Paint line = Paint()
      ..color = Colors.orange.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final ui.Path path = ui.Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < data.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(path, line);
    final Paint dot = Paint()..color = Colors.orange.shade700;
    final TextPainter tp = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(pt(i), 4, dot);
      tp.text = TextSpan(
          text: data[i].day,
          style: const TextStyle(fontSize: 11, color: Colors.black87));
      tp.layout();
      tp.paint(
          canvas, Offset(pt(i).dx - tp.width / 2, padT + h + 4));
      tp.text = TextSpan(
          text: '${data[i].temp.toStringAsFixed(1)}°',
          style:
              const TextStyle(fontSize: 10, color: Colors.black54));
      tp.layout();
      tp.paint(canvas, Offset(pt(i).dx - tp.width / 2, pt(i).dy - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
