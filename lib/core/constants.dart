/// Locked business constants for GOT9 Phase 1 MVP. DO NOT change without board sign-off.
library;

/// SaaS / marketplace economics
const double platformGpRate = 0.05; // 5% (within 3-5% fair GP policy)
const double vatRate = 0.07; // 7% VAT on platform GP only
const double mockPaymentFeeRate = 0.0365; // ~3.65% mock Opn fee

/// Pre-order yield buffer: only (100 - buffer)% of harvest may be sold.
const double defaultStockBufferPct = 70.0;

/// Workshop policy
const double workshopPrice = 399.0;
const int workshopMinCapacity = 4;
const int workshopMaxCapacity = 12;
const double workshopDepositRate = 0.30;

/// Map policy
const double defaultBufferMeters = 2.0;
const double overlapWarnPct = 10.0;

/// Reference products (external pilot examples, NOT core business)
const double coffeeScrubPriceLow = 120.0;
const double coffeeScrubPriceHigh = 150.0;

/// Timezone for all dates
const String appTimeZone = 'Asia/Bangkok';

/// Trace history scope for V1
const String traceHistoryLabel = 'Year 1';
