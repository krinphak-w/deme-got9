import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/pdpa.dart';
import '../../core/thai_units.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../widgets/plot_map.dart';

/// /trace/{plot_id} — PUBLIC, no login. Story + map + cert + buy again.
class TracePage extends StatelessWidget {
  const TracePage({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<FarmPlot> found =
        state.plots.where((p) => p.id == plotId).toList();
    if (found.isEmpty) {
      return Scaffold(
        appBar: Got9Bar(title: state.tr('trace')),
        body: const Center(child: Text('ไม่พบแปลง / Plot not found')),
      );
    }
    final FarmPlot plot = found.first;
    final List<OrganicLog> plotLogs =
        state.logs.where((l) => l.plotId == plot.id).toList();
    final List<Product> items =
        state.products.where((p) => p.farmId == plot.id).toList();
    final String? publicGps = plot.hasMap
        ? (() {
            final blurred = blurToSubdistrict(
                centroid(plot.polygon!).latitude,
                centroid(plot.polygon!).longitude);
            return '${blurred.lat}, ${blurred.lng}';
          })()
        : null;

    return Scaffold(
      appBar: Got9Bar(title: state.tr('trace')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(plot.plotName,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(
              'เกษตรกร ${plot.ownerFid} • ${formatRaiNganWah(plot.areaNetRai * 1600)} • ${state.tr('year1')}'),
          const SizedBox(height: 8),
          if (plot.hasMap) ...[
            PlotMapView(
                polygon: plot.polygon!,
                height: 200,
                interactive: false),
            Text(
                'พิกัดสาธารณะ (เบลอระดับตำบล): $publicGps',
                style: Theme.of(context).textTheme.bodySmall),
          ] else
            Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('แปลงนี้ยังไม่มีแผนที่ (แจ้งข้อมูลแบบกรอกเอง)'),
            ),
          const SizedBox(height: 8),
          _certRow(context, plot),
          const SizedBox(height: 8),
          Text('บันทึกแปลง (${plotLogs.length})',
              style: Theme.of(context).textTheme.titleMedium),
          for (final log in plotLogs)
            ListTile(
              leading: const Icon(Icons.eco),
              title: Text(log.detail),
              subtitle: Text(
                  '${log.logType} • ${log.logDate.toLocal().toString().split(' ').first}'),
            ),
          const SizedBox(height: 8),
          Text('รีวิว',
              style: Theme.of(context).textTheme.titleMedium),
          const Card(
            child: ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('★★★★★ ผักสดจริง เห็นหน้าแปลงแล้วมั่นใจ'),
              subtitle: Text('B-ID นักท่องเที่ยวภูเรือ'),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            ListTile(
              title: Text(item.name),
              subtitle: Text('฿${item.price.toStringAsFixed(0)}'),
              trailing: FilledButton(
                child: Text(state.tr('buyAgain')),
                onPressed: () => context.go('/shop'),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('LINE OA'),
                  onPressed: () async {
                    final Uri url =
                        Uri.parse('https://line.me/R/ti/p/@got9farm');
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () => SharePlus.instance.share(
                      ShareParams(text: 'GOT9 ${plot.plotName} — got9://trace/${plot.id}')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _certRow(BuildContext context, FarmPlot plot) {
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: Icon(
            plot.verified ? Icons.verified_user : Icons.hourglass_empty,
            color: plot.verified ? Colors.green : Colors.orange),
        title: Text(plot.verified
            ? 'รับรองแล้ว: ผู้ใหญ่บ้าน + เกษตรอำเภอ'
            : 'รอรับรอง: ผู้ใหญ่บ้าน${plot.verifierVillage ? ' ✓' : ''} / เกษตรอำเภอ${plot.verifierAgriOfficer ? ' ✓' : ''}'),
        subtitle: const Text('PGS • Year 1'),
      ),
    );
  }
}
