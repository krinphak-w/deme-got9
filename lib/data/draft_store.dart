import 'package:shared_preferences/shared_preferences.dart';

// Offline-First simulation: form drafts persisted to browser localStorage
// (shared_preferences uses localStorage on web, native prefs on mobile).
// Refresh the page mid-field and the draft is still there.
class DraftStore {
  static const String _logPrefix = 'draft:log:';

  static Future<void> saveLogDraft({
    required String userId,
    String? plotId,
    required String logType,
    required String detail,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_logPrefix$userId:plotId', plotId ?? '');
    await prefs.setString('$_logPrefix$userId:logType', logType);
    await prefs.setString('$_logPrefix$userId:detail', detail);
    await prefs.setString(
        '$_logPrefix$userId:savedAt', DateTime.now().toIso8601String());
  }

  static Future<({String? plotId, String logType, String detail, DateTime? savedAt})>
      loadLogDraft(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? plotRaw =
        prefs.getString('$_logPrefix$userId:plotId');
    return (
      plotId: (plotRaw == null || plotRaw.isEmpty) ? null : plotRaw,
      logType: prefs.getString('$_logPrefix$userId:logType') ?? 'seed',
      detail: prefs.getString('$_logPrefix$userId:detail') ?? '',
      savedAt: DateTime.tryParse(
          prefs.getString('$_logPrefix$userId:savedAt') ?? ''),
    );
  }

  static Future<void> clearLogDraft(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_logPrefix$userId:plotId');
    await prefs.remove('$_logPrefix$userId:logType');
    await prefs.remove('$_logPrefix$userId:detail');
    await prefs.remove('$_logPrefix$userId:savedAt');
  }
}
