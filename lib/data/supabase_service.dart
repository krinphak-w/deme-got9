import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bootstrap. If [supabaseUrl]/[supabaseAnonKey] are left empty,
/// the app runs in MOCK mode (local seed data, no network).
class Supa {
  static bool get isMock =>
      supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static Future<void> init() async {
    if (isMock) {
      debugPrint('[GOT9] Supabase keys empty -> MOCK mode');
      return;
    }
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}

// TODO: paste your Supabase project values here (or --dart-define).
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: '');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: '');
