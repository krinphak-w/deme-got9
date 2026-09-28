import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/photo.dart';
import '../../core/thai_units.dart';
import '../../data/app_state.dart';

/// /farmer/plot/manual — typed entry: name + rai-ngan-wah + land type +
/// village + land-right document photo. No map shape required.
class PlotManualPage extends StatefulWidget {
  const PlotManualPage({super.key});

  @override
  State<PlotManualPage> createState() => _PlotManualPageState();
}

class _PlotManualPageState extends State<PlotManualPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _rai = TextEditingController(text: '0');
  final TextEditingController _ngan = TextEditingController(text: '0');
  final TextEditingController _wah = TextEditingController(text: '0');
  final TextEditingController _village = TextEditingController();
  String _landType = 'chanote';
  Uint8List? _docBytes;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _rai.dispose();
    _ngan.dispose();
    _wah.dispose();
    _village.dispose();
    super.dispose();
  }

  double get _grossSqm {
    final int rai = int.tryParse(_rai.text.trim()) ?? 0;
    final int ngan = int.tryParse(_ngan.text.trim()) ?? 0;
    final double wah = double.tryParse(_wah.text.trim()) ?? 0;
    return raiNganWahToSqm(rai, ngan, wah);
  }

  Future<void> _pickDoc() async {
    final Uint8List? bytes =
        await pickCompressedPhoto(ImageSource.gallery);
    if (bytes != null) setState(() => _docBytes = bytes);
  }

  Future<void> _save(AppState state) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ตั้งชื่อแปลงก่อน')));
      return;
    }
    if (_grossSqm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรอกเนื้อที่ ไร่-งาน-ตารางวา ก่อน')));
      return;
    }
    setState(() => _saving = true);
    String? docPath;
    if (_docBytes != null) {
      final String objectName =
          'doc-${DateTime.now().millisecondsSinceEpoch}.jpg';
      docPath = await storePhoto(_docBytes!,
          bucket: 'organic-photos', objectName: objectName);
    }
    final String plotName = _village.text.trim().isEmpty
        ? _name.text.trim()
        : '${_name.text.trim()} (${_village.text.trim()})';
    await state.addPlot(
      plotName: plotName,
      landType: _landType,
      entryChannel: 'manual',
      declaredGrossSqm: _grossSqm,
      docPhotoPath: docPath,
    );
    if (mounted) {
      if (docPath != null && state.plots.isNotEmpty) {
        final String plotId = state.plots.last.id;
        await state.addLog(
          plotId: plotId,
          logType: 'activity',
          detail: 'แนบรูปเอกสารสิทธิ์ที่ดิน ($_landType)',
          photoPath: docPath,
        );
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('บันทึกแปลงแล้ว (รอผู้ใหญ่บ้านรับรอง)')));
      context.go('/farmer/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: 'กรอกเอง / Manual'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'ชื่อแปลง *', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text('เนื้อที่ (ไร่-งาน-ตารางวา) *',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rai,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'ไร่', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ngan,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'งาน', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _wah,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'ตร.ว.', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('≈ ${formatRaiNganWah(_grossSqm)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _landType,
            decoration: const InputDecoration(
                labelText: 'ประเภทที่ดิน', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: 'chanote', child: Text('โฉนด')),
              DropdownMenuItem(value: 'spk', child: Text('ส.ป.ก.')),
              DropdownMenuItem(
                  value: 'khor_tor_chor', child: Text('คทช.')),
            ],
            onChanged: (v) => setState(() => _landType = v ?? 'chanote'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _village,
            decoration: const InputDecoration(
                labelText: 'หมู่บ้าน/ตำบล (เช่น บ้านหลังสวน)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.badge),
            label: const Text('แนบรูปเอกสารสิทธิ์ (โฉนด/ส.ป.ก./คทช.)'),
            onPressed: _pickDoc,
          ),
          if (_docBytes != null) ...[
            const SizedBox(height: 8),
            Image.memory(_docBytes!, height: 180, fit: BoxFit.cover),
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
