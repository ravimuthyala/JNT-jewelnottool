import 'package:flutter/services.dart';

enum AppEnvironment {
  dev,
  uat,
  production,
}

class Environment {
  const Environment._();

  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'production');

  static AppEnvironment get current {
    switch (_env.toLowerCase()) {
      case 'dev':
        return AppEnvironment.dev;

      case 'production':
        return AppEnvironment.production;

      case 'uat':
      default:
        return AppEnvironment.uat;
    }
  }

  static bool get isDev => current == AppEnvironment.dev;

  static bool get isUat => current == AppEnvironment.uat;

  static bool get isProduction =>
      current == AppEnvironment.production;

  static String get name {
    switch (current) {
      case AppEnvironment.dev:
        return 'DEV';

      case AppEnvironment.uat:
        return 'UAT';

      case AppEnvironment.production:
        return 'Production';
    }
  }

  static String get appName {
    switch (current) {
      case AppEnvironment.dev:
        return 'JNT DEV';

      case AppEnvironment.uat:
        return 'JNT UAT';

      case AppEnvironment.production:
        return 'JNT';
    }
  }

  static String get supabaseUrl {
    switch (current) {
      case AppEnvironment.dev:
        // Until you create a separate DEV project,
        // DEV safely uses UAT instead of production.
        return 'https://gonutknapmzhrzvvrfka.supabase.co';

      case AppEnvironment.uat:
        return 'https://gonutknapmzhrzvvrfka.supabase.co';

      case AppEnvironment.production:
        return 'https://mjvypuwrwcjylhizuhfw.supabase.co';
    }
  }

  static String get publishableKey {
    switch (current) {
      case AppEnvironment.dev:
        // Until you create a separate DEV project,
        // DEV safely uses the UAT publishable key.
        return 'sb_publishable_ZmYj_mPNuA2aodiqKgKRaA_R9WD3aK6';

      case AppEnvironment.uat:
        return 'sb_publishable_ZmYj_mPNuA2aodiqKgKRaA_R9WD3aK6';

      case AppEnvironment.production:
        return 'sb_publishable_VPMJRDPaTI7xdm5ti7HEjg_S_aJIPXD';
    }
  }

  static String get passwordResetScheme {
    switch (current) {
      case AppEnvironment.dev:
        return 'jntappdev';

      case AppEnvironment.uat:
        return 'jntappuat';

      case AppEnvironment.production:
        return 'jntapp';
    }
  }

  static String get passwordResetRedirectUrl {
    return '$passwordResetScheme://reset-password';
  }
}