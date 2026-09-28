import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /workshop — calendar list + 30% deposit mock + QR ticket.
class WorkshopPage extends StatelessWidget {
  const WorkshopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final DateFormat fmt = DateFormat('d MMM yyyy HH:mm', 'th');
    return Scaffold(
      appBar: Got9Bar(title: state.tr('workshop')),
      bottomNavigationBar:
          state.currentUser == null ? null : const Got9Nav(index: 2),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final w in state.workshops)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title,
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${fmt.format(w.dateTime)} • ฿${thb(w.price)} • ${state.tr('seatsLeft')}: ${w.seatsLeft}/${w.capacity}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: w.bookedCount / w.capacity,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: w.seatsLeft <= 0
                              ? null
                              : () => _book(context, state, w),
                          child: Text(w.seatsLeft <= 0
                              ? state.tr('full')
                              : state.tr('book')),
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

  void _book(BuildContext context, AppState state, Workshop w) {
    int persons = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(w.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${state.tr('deposit30')}: ฿${thb(workshopDeposit(w.price))}/ท่าน'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: persons > 1
                        ? () => setD(() => persons--)
                        : null,
                  ),
                  Text('$persons'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: persons < w.seatsLeft
                        ? () => setD(() => persons++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: () {
                final res = state.bookWorkshop(
                    workshopId: w.id, persons: persons);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.ok
                        ? 'จองสำเร็จ มัดจำ ฿${thb(res.booking!.deposit)} (mock)'
                        : res.reason)));
                if (res.ok) {
                  _showTicket(context, res.booking!);
                }
              },
              child: Text(state.tr('book')),
            ),
          ],
        ),
      ),
    );
  }

  void _showTicket(BuildContext context, Booking b) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตั๋ว QR / Ticket'),
        content: SizedBox(
          width: 220,
          height: 260,
          child: Column(
            children: [
              QrImageView(data: 'got9://ticket/${b.id}', size: 200),
              Text('${b.id} • ${b.persons} ท่าน'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
