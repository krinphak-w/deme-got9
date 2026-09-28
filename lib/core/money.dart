import 'constants.dart';

/// Money math: VAT 7% applies to platform GP ONLY (never to product price).

class OrderBreakdown {
  OrderBreakdown({
    required this.subtotal,
    required this.gpFee,
    required this.vat,
    required this.paymentFee,
    required this.farmerReceives,
    required this.buyerPays,
  });

  final double subtotal;
  final double gpFee;
  final double vat;
  final double paymentFee;
  final double farmerReceives;
  final double buyerPays;
}

OrderBreakdown breakdownOrder(double subtotal,
    {double gpRate = platformGpRate}) {
  final double gpFee = _round2(subtotal * gpRate);
  final double vat = _round2(gpFee * vatRate);
  final double paymentFee = _round2(subtotal * mockPaymentFeeRate);
  final double buyerPays = _round2(subtotal + paymentFee);
  final double farmerReceives = _round2(subtotal - gpFee);
  return OrderBreakdown(
    subtotal: _round2(subtotal),
    gpFee: gpFee,
    vat: vat,
    paymentFee: paymentFee,
    farmerReceives: farmerReceives,
    buyerPays: buyerPays,
  );
}

/// Sellable quantity under Yield Buffer policy.
/// Only (100 - bufferPct)% of [harvestQty] may be pre-sold.
int sellableQty(int harvestQty, double bufferPct) {
  if (harvestQty <= 0) return 0;
  return ((harvestQty * (100 - bufferPct)) / 100).floor();
}

/// Returns true when [requested] units can still be sold given [sold] units.
bool canSell(int harvestQty, int sold, int requested, double bufferPct) {
  return sold + requested <= sellableQty(harvestQty, bufferPct);
}

/// 30% workshop deposit.
double workshopDeposit(double price) =>
    _round2(price * workshopDepositRate);

double _round2(double v) => (v * 100).round() / 100;

/// Format THB without currency symbol (e.g. 1,699.00).
String thb(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final String intPart = parts[0];
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    final int rev = intPart.length - i;
    buf.write(intPart[i]);
    if (rev > 1 && rev % 3 == 1) buf.write(',');
  }
  return '${buf.toString()}.${parts[1]}';
}
