import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseBootstrap {
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<bool> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  static String userMessage() {
    if (kIsWeb) {
      return 'Firebase is not initialized for Web. Check firebase_options.dart and restart.';
    }
    return 'Firebase is not initialized. Check Firebase setup and restart the app.';
  }
}
