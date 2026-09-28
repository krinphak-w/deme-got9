import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/photo.dart';
import '../../data/app_state.dart';

/// /farmer/log — 6 PGS forms + photo (auto-compress <2MB) + Hive queue.
class FarmerLogPage extends StatefulWidget {
  const FarmerLogPage({super.key});

  @override
  State<FarmerLogPage> createState() => _FarmerLogPageState();
}

const List<(String, String)> logTypes = [
  ('seed', 'บันทึกเมล็ดพันธุ์ / Seed'),
  ('input', 'ปัจจัยการผลิต / Input'),
  ('cleaning', 'ล้างเครื่องจักร / Cleaning'),
  ('harvest', 'เก็บเกี่ยว / Harvest'),
  ('activity', 'กิจกรรมแปลง / Activity'),
  ('neighbor', 'แจ้งแปลงข้างเคียง / Neighbor'),
];

class _FarmerLogPageState extends State<FarmerLogPage> {
  String? _plotId;
  String _logType = 'seed';
  final TextEditingController _detail = TextEditingController();
  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final Uint8List? compressed =
        await pickCompressedPhoto(ImageSource.camera);
    if (compressed == null) return;
    setState(() => _photoBytes = compressed);
  }

  Future<String?> _storePhoto(String logId) async {
    if (_photoBytes == null) return null;
    return storePhoto(_photoBytes!,
        bucket: 'organic-photos', objectName: '$logId.jpg');
  }

  Future<void> _save(AppState state) async {
    if (_plotId == null || _detail.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เลือกแปลง + กรอกรายละเอียดก่อน')));
      return;
    }
    setState(() => _saving = true);
    try {
      final String tmpId =
          'LOG-${DateTime.now().millisecondsSinceEpoch}';
      final String? photoPath = await _storePhoto(tmpId);
      await state.addLog(
        plotId: _plotId!,
        logType: _logType,
        detail: _detail.text.trim(),
        photoPath: photoPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกแล้ว (รอ sync)')));
        context.go('/farmer/home');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    _plotId ??= state.plots.isNotEmpty ? state.plots.first.id : null;
    return Scaffold(
      appBar: Got9Bar(title: state.tr('farmLog')),
      bottomNavigationBar: const Got9Nav(index: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _plotId,
            decoration: const InputDecoration(
                labelText: 'แปลง / Plot',
                border: OutlineInputBorder()),
            items: [
              for (final p in state.plots)
                DropdownMenuItem(value: p.id, child: Text(p.plotName)),
            ],
            onChanged: (v) => setState(() => _plotId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _logType,
            decoration: const InputDecoration(
                labelText: 'แบบฟอร์ม PGS (6)', border: OutlineInputBorder()),
            items: [
              for (final (v, label) in logTypes)
                DropdownMenuItem(value: v, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _logType = v ?? 'seed'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detail,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'รายละเอียด / Detail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text(state.tr('photoHint')),
            onPressed: _takePhoto,
          ),
          if (_photoBytes != null) ...[
            const SizedBox(height: 8),
            Image.memory(_photoBytes!, height: 180, fit: BoxFit.cover),
            Text(
                'ขนาดหลังบีบอัด: ${(_photoBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => _save(state),
            child: _saving
                ? const CircularProgressIndicator()
                : Text(state.tr('save')),
          ),
        ],
      ),
    );
  }
}
