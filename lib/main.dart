import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'app.dart';
import 'data/app_state.dart';
import 'data/hive_cache.dart';
import 'data/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await HiveCache.init();
  await Supa.init();
  final AppState state = AppState()..loadSeed();
  // Warm offline-lite cache with seed (first run).
  if (HiveCache.loadPlots().isEmpty) {
    for (final p in state.plots) {
      await HiveCache.savePlot(p);
    }
    for (final l in state.logs) {
      await HiveCache.saveLog(l);
    }
  }
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const Got9App(),
    ),
  );
}
