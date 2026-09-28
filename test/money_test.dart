import 'package:flutter_test/flutter_test.dart';
import 'package:got9_phase1/core/money.dart';

void main() {
  test('VAT 7% applies to GP only', () {
    final b = breakdownOrder(1000);
    expect(b.gpFee, 50.0); // 5% of 1000
    expect(b.vat, 3.5); // 7% of 50
    expect(b.farmerReceives, 950.0);
  });

  test('Yield Buffer 70% blocks oversell', () {
    expect(sellableQty(200, 70), 60); // only 30% sellable
    expect(canSell(200, 40, 20, 70), isTrue); // 40+20 <= 60
    expect(canSell(200, 40, 21, 70), isFalse); // 61 > 60 blocked
  });

  test('workshop deposit is 30%', () {
    expect(workshopDeposit(399), 119.7);
  });
}
