import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants.dart';
import '../../core/kml_parser.dart';
import '../../data/app_state.dart';

/// /farmer/plot/add — 4 ช่องทางให้ข้อมูลแปลงเกษตร.
class PlotAddMenuPage extends StatefulWidget {
  const PlotAddMenuPage({super.key});

  @override
  State<PlotAddMenuPage> createState() => _PlotAddMenuPageState();
}

class _PlotAddMenuPageState extends State<PlotAddMenuPage> {
  bool _busy = false;

  Future<void> _importLing(AppState state) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kml', 'kmz', 'geojson', 'json'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    setState(() => _busy = true);
    try {
      final file = picked.files.single;
      final List<LingPlot> lingPlots =
          parseLingFile(file.name, file.bytes!);
      for (final lp in lingPlots) {
        await state.addPlotFromLing(
          plotName: lp.plotName,
          polygon: lp.polygon,
          lingSourceId: lp.sourceId,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'นำเข้า ${lingPlots.length} แปลงแล้ว (หักแนวกันชน ${defaultBufferMeters.toInt()} ม.)')));
        context.go('/farmer/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ไฟล์ใช้ไม่ได้: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: 'เพิ่มแปลง / Add plot'),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'เลือกวิธีให้ข้อมูลแปลง (ได้มากกว่า 1 วิธี รวมกันได้)'),
                const SizedBox(height: 12),
                _channelCard(
                  context,
                  icon: Icons.upload_file,
                  title: 'นำเข้าจาก Ling',
                  subtitle: 'ไฟล์ KML / KMZ / GeoJSON ที่ Share จากแอป Ling',
                  onTap: () => _importLing(state),
                ),
                _channelCard(
                  context,
                  icon: Icons.draw,
                  title: 'วาดแปลงบนแผนที่',
                  subtitle: 'แตะแผนที่ปักหมุดทีละจุด เหมาะกับแปลงเล็ก',
                  onTap: () => context.go('/farmer/plot/draw'),
                ),
                _channelCard(
                  context,
                  icon: Icons.directions_walk,
                  title: 'เดินรอบแปลงด้วย GPS',
                  subtitle: 'ถือมือถือเดินตามขอบแปลง แอปเก็บพิกัดให้อัตโนมัติ',
                  onTap: () => context.go('/farmer/plot/walk'),
                ),
                _channelCard(
                  context,
                  icon: Icons.edit_note,
                  title: 'กรอกข้อมูลเอง',
                  subtitle: 'ชื่อแปลง + ไร่-งาน-วา + ประเภทที่ดิน + รูปเอกสารสิทธิ์',
                  onTap: () => context.go('/farmer/plot/manual'),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.blue.shade50,
                  child: ExpansionTile(
                    leading: Icon(Icons.help_outline,
                        color: Colors.blue.shade800, size: 32),
                    title: const Text(
                        'ไม่มีไฟล์แผนที่? วาดฟรีใน Google Earth (ไม่เสียเงิน)'),
                    subtitle: const Text(
                        'ใช้คอม/แท็บเล็ตจะวาดแม่นกว่ามือถือ — แตะเพื่อดูวิธีทีละขั้น'),
                    children: const [
                      _GuideStep(
                          n: '1',
                          title: 'เปิด Google Earth หาที่ดิน',
                          detail:
                              'เปิด Chrome เข้า earth.google.com → กดแว่นขยายค้นหาหมู่บ้าน/อำเภอภูเรือ → ซูมจนเห็นแปลงตัวเองชัด'),
                      _GuideStep(
                          n: '2',
                          title: 'สร้างโปรเจกต์แล้ววาดแปลง',
                          detail:
                              'กดไอคอน "โปรเจกต์" ซ้ายมือ → โปรเจกต์ใหม่ → สร้างใน Google ไดรฟ์ → กด "วาดเส้นหรือรูปร่าง" → คลิกตามมุมที่ดินจนบรรจบ → ตั้งชื่อแปลง (เช่น แปลงสมุนไพร 1) → บันทึก'),
                      _GuideStep(
                          n: '3',
                          title: 'ส่งออกไฟล์ KML',
                          detail:
                              'ที่เมนูโปรเจกต์ กดจุด 3 จุดข้างชื่อ → "ส่งออกเป็นไฟล์ KML" → ได้ไฟล์ .kml ฟรี 100%'),
                      _GuideStep(
                          n: '4',
                          title: 'เอามาใส่ GOT9',
                          detail:
                              'กลับมาหน้านี้ กด "นำเข้าจาก Ling" (รับไฟล์ KML จาก Google Earth ด้วย) → ระบบสร้างแปลง + หักแนวกันชนให้อัตโนมัติ'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _channelCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 36, color: Colors.green.shade800),
        title: Text(title,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

/// คู่มือวาด Google Earth ทีละขั้น (เนื้อหาจากบทความต้นฉบับ — ใช้ในแชทบอทได้ด้วย).
class _GuideStep extends StatelessWidget {
  const _GuideStep(
      {required this.n, required this.title, required this.detail});

  final String n;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
          radius: 14,
          child: Text(n, style: const TextStyle(fontSize: 12))),
      title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(detail),
    );
  }
}
