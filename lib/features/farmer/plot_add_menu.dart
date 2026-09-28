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
