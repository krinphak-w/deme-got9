import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /corporate — B2B price + mock VAT invoice.
class CorporatePage extends StatelessWidget {
  const CorporatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: state.tr('corporateTitle')),
      bottomNavigationBar: const Got9Nav(index: 3),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.business),
              title: Text('C-00001 • โรงแรมภูเรือ (ตัวอย่าง)'),
              subtitle: Text('B2B Premium: ส่วนลด GP + ป้ายร้านแนะนำ'),
            ),
          ),
          for (final p in state.products)
            Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text(
                    'B2B ฿${thb(p.price * 0.9)} (ลด 10%) • มีใบกำกับภาษี mock'),
                trailing: OutlinedButton(
                  child: const Text('ใบกำกับฯ'),
                  onPressed: () => _showInvoice(context, p),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showInvoice(BuildContext context, Product p) {
    final OrderBreakdown b = breakdownOrder(p.price * 0.9);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ใบกำกับภาษี mock / TAX INVOICE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ผู้ขาย: F-ID ${p.farmId} (ภูเรือ)'),
            Text('สินค้า: ${p.name}'),
            Text('มูลค่า: ฿${thb(b.subtotal)}'),
            Text('GP 5%: ฿${thb(b.gpFee)} + VAT 7%: ฿${thb(b.vat)}'),
            Text('รวมเรียกเก็บ: ฿${thb(b.buyerPays)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
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
