import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../data/app_state.dart';

/// /admin/verify — village head + agri officer approve buttons.
class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: state.tr('verify')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final plot in state.plots)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${plot.plotName} (${plot.id})',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    Text(
                        'เจ้าของ ${plot.ownerFid} • ที่ดิน: ${_landLabel(plot.landType)}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: plot.verifierVillage
                                ? null
                                : () => state.approvePlot(plot.id,
                                    byVillage: true),
                            child: Text(
                                '${state.tr('villageHead')}${plot.verifierVillage ? ' ✓' : ''}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: plot.verifierAgriOfficer
                                ? null
                                : () => state.approvePlot(plot.id,
                                    byVillage: false),
                            child: Text(
                                '${state.tr('agriOfficer')}${plot.verifierAgriOfficer ? ' ✓' : ''}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _landLabel(String t) => switch (t) {
        'chanote' => 'โฉนด',
        'spk' => 'ส.ป.ก.',
        'khor_tor_chor' => 'คทช.',
        _ => t,
      };
}
