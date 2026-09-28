import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/money.dart';
import '../../core/photo.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /shop — pre-order list with Yield Buffer badge + mock checkout.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final Map<String, int> _qty = {};

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: state.tr('shop')),
      bottomNavigationBar:
          state.currentUser == null ? null : const Got9Nav(index: 1),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final p in state.products.where((e) => e.active))
            _productCard(context, state, p),
        ],
      ),
    );
  }

  Widget _productCard(
      BuildContext context, AppState state, Product p) {
    final int sellable = sellableQty(p.harvestQty, p.stockBufferPct);
    final int left = sellable - p.soldQty;
    final int qty = _qty[p.id] ?? 1;
    final bytes = state.productPhotos[p.id];
    final bool editable = state.canEditProduct(p.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: bytes != null
                          ? Image.memory(bytes,
                              width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              color: Colors.green.shade50,
                              child: const Icon(Icons.image,
                                  size: 36, color: Colors.green),
                            ),
                    ),
                    if (editable)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _addProductPhoto(state, p.id),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      Text(
                          '฿${thb(p.price)} • Buffer ${p.stockBufferPct.toInt()}%'),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                      '${state.tr('sellableLeft')} $left',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: left > 0
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: qty > 1
                      ? () => setState(() => _qty[p.id] = qty - 1)
                      : null,
                ),
                Text('$qty',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: qty < left
                      ? () => setState(() => _qty[p.id] = qty + 1)
                      : null,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: left <= 0
                      ? null
                      : () {
                          final res = state.placeOrder(
                              productId: p.id, qty: qty);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(res.ok
                                    ? 'สั่ง ${res.order!.id} สำเร็จ (mock ชำระแล้ว)'
                                    : res.reason)),
                          );
                          if (res.ok) {
                            _showReceipt(context, state, res.order!, p);
                          }
                        },
                  child: Text(state.tr('order')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProductPhoto(AppState state, String productId) async {
    final bytes = await pickCompressedPhoto(ImageSource.gallery);
    if (bytes == null) return;
    final String? path = await storePhoto(bytes,
        bucket: 'product-photos', objectName: '$productId.jpg');
    if (path == null) return;
    state.setProductPhoto(productId, path, bytes);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เพิ่มรูปสินค้าแล้ว')));
    }
  }

  void _showReceipt(      BuildContext context, AppState state, ShopOrder o, Product p) {
    final OrderBreakdown b = breakdownOrder(p.price * o.qty);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ใบเสร็จ mock / Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.name} x${o.qty} = ฿${thb(b.subtotal)}'),
            Text('Platform GP 5% = ฿${thb(b.gpFee)}'),
            Text('VAT 7% (บน GP) = ฿${thb(b.vat)}'),
            Text('Payment fee mock = ฿${thb(b.paymentFee)}'),
            Text('เกษตรกรรับ = ฿${thb(b.farmerReceives)}'),
            Text('ผู้ซื้อจ่าย = ฿${thb(b.buyerPays)}'),
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
