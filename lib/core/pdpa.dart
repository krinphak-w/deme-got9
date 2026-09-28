/// PDPA helpers: consent, ID masking, public GPS blurring.
library;

/// Show only the last 4 digits of a Thai national ID (e.g. XXX-XXX-**1234).
String maskIdCard(String id) {
  final String digits = id.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '****';
  return 'XXX-XXX-**${digits.substring(digits.length - 4)}';
}

/// Blur a home GPS point to subdistrict level for public display:
/// rounds coordinates to ~1.1 km grid so the exact house is hidden.
({double lat, double lng}) blurToSubdistrict(double lat, double lng) {
  return (
    lat: (lat * 100).round() / 100,
    lng: (lng * 100).round() / 100,
  );
}

/// Mask a phone number: 08X-XXX-**12.
String maskPhone(String phone) {
  final String digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return '****';
  final String tail = digits.substring(digits.length - 2);
  return '${digits.substring(0, 3)}-XXX-**$tail';
}
