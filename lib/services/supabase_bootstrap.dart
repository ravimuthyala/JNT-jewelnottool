import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/environment.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<bool> ensureInitialized() async {
    try {
      debugPrint('========================================');
      debugPrint('Starting Supabase initialization');
      debugPrint('Environment: ${Environment.name}');
      debugPrint('Supabase URL: ${Environment.supabaseUrl}');
      debugPrint('========================================');

      await Supabase.initialize(
        url: Environment.supabaseUrl,
        publishableKey: Environment.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
        debug: false,
      );

      _lastError = null;

      debugPrint('========================================');
      debugPrint('Supabase initialization successful');
      debugPrint('Environment: ${Environment.name}');
      debugPrint('========================================');

      return true;
    } catch (error, stackTrace) {
      _lastError = error.toString();

      debugPrint('========================================');
      debugPrint('Supabase initialization failed');
      debugPrint('Environment: ${Environment.name}');
      debugPrint('Error: $_lastError');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('========================================');

      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String userMessage() {
    if (kIsWeb) {
      return 'Supabase is not initialized for Web. '
          'Check the selected environment, Supabase URL, and publishable key.';
    }

    return 'Supabase is not initialized. '
        'Check the selected environment and restart the app.';
  }
}