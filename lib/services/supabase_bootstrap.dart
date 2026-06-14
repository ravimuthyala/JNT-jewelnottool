import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<bool> ensureInitialized() async {
    try {
      await Supabase.initialize(
        url: 'https://mjvypuwrwcjylhizuhfw.supabase.co',
        anonKey: 'sb_publishable_VPMJRDPaTI7xdm5ti7HEjg_S_aJIPXD',
      );

      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String userMessage() {
    if (kIsWeb) {
      return 'Supabase is not initialized for Web. Check your Supabase URL and anon key.';
    }
    return 'Supabase is not initialized. Check Supabase setup and restart the app.';
  }
}