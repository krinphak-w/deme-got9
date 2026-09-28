import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'models.dart';

/// Offline-lite cache: farm_plots + organic_logs in Hive, FIFO sync queue.
/// Full offline-first is OUT of scope for V1 (see blueprint §13).
class HiveCache {
  static const String plotsBox = 'farm_plots';
  static const String logsBox = 'organic_logs';
  static const String queueBox = 'sync_queue';
  static const String prefsBox = 'prefs';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(plotsBox);
    await Hive.openBox(logsBox);
    await Hive.openBox(queueBox);
    await Hive.openBox(prefsBox);
  }

  static Box get _plots => Hive.box(plotsBox);
  static Box get _logs => Hive.box(logsBox);
  static Box get _queue => Hive.box(queueBox);
  static Box get _prefs => Hive.box(prefsBox);

  /// Simple key-value prefs (profile fields, settings).
  static Future<void> setPref(String key, dynamic value) =>
      _prefs.put(key, value);

  static T? getPref<T>(String key) {
    final v = _prefs.get(key);
    return v is T ? v : null;
  }

  static Future<void> savePlot(FarmPlot plot) =>
      _plots.put(plot.id, plot.toCache());

  static List<FarmPlot> loadPlots() => _plots.values
      .map((e) => FarmPlot.fromCache(
          Map<dynamic, dynamic>.from(e as Map)))
      .toList();

  static Future<void> saveLog(OrganicLog log) =>
      _logs.put(log.id, log.toCache());

  static List<OrganicLog> loadLogs() => _logs.values
      .map((e) => OrganicLog.fromCache(
          Map<dynamic, dynamic>.from(e as Map)))
      .toList();

  /// Queue a pending write for later sync when back online.
  static Future<void> enqueue(String op, Map<String, dynamic> payload) =>
      _queue.add({'op': op, 'payload': payload, 'ts': DateTime.now().toIso8601String()});

  static int get pendingCount => _queue.length;

  /// Flush the queue (mock sync: just clears and logs in V1).
  static Future<int> flushQueue() async {
    final int n = _queue.length;
    await _queue.clear();
    debugPrint('[GOT9] Synced $n queued ops (mock)');
    return n;
  }
}
