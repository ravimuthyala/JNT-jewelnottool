import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/client_registration_page.dart';
import 'pages/client_shell_page.dart';
import 'pages/artist_login_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/reset_password_success_page.dart';

import 'config/environment.dart';
import 'theme/app_colors.dart';
import 'utlis/responsive_text.dart';
import 'services/supabase_bootstrap.dart';
import 'services/startup_frame_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/client_profile_models.dart';
import 'pages/artist_registration/artist_registration_flow.dart';
import 'pages/review_artist_page.dart';
import 'pages/tip_artist_page.dart';

// Sentry DSN is intentionally blank by default: the Sentry SDK safely no-ops
// (runs the app normally, just doesn't send events) when the DSN is empty.
// Supply the real DSN at build time with:
//   flutter run --dart-define=SENTRY_DSN=https://...
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = Environment.name;
      options.tracesSampleRate = 0.2;
    },
    appRunner: _startApp,
  );
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupFrameGate.deferFirstFrame();
  final supabaseOk = await SupabaseBootstrap.ensureInitialized();
  if (!supabaseOk) {
    debugPrint(
      'Supabase initialization failed: ${SupabaseBootstrap.lastError}',
    );
    runApp(_SupabaseInitFailedApp(error: SupabaseBootstrap.lastError));
    return;
  }
  runApp(const JntApp());
}

/// Shown only when Supabase fails to initialize at startup (e.g. no network,
/// bad config). Lets the user retry instead of the app silently proceeding
/// into a broken state with no working backend client.
class _SupabaseInitFailedApp extends StatefulWidget {
  const _SupabaseInitFailedApp({this.error});

  final String? error;

  @override
  State<_SupabaseInitFailedApp> createState() =>
      _SupabaseInitFailedAppState();
}

class _SupabaseInitFailedAppState extends State<_SupabaseInitFailedApp> {
  bool _retrying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final ok = await SupabaseBootstrap.ensureInitialized();
    if (!mounted) return;
    if (ok) {
      runApp(const JntApp());
      return;
    }
    setState(() {
      _retrying = false;
      _error = SupabaseBootstrap.lastError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: Scaffold(
        backgroundColor: const Color(0xFF292222),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.white70,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We could not reach our servers. Please check your '
                    'connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retrying ? null : _retry,
                    child: _retrying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JntApp extends StatelessWidget {
  const JntApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return _DeepLinkBootstrap(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'JewelNotTool',
        debugShowCheckedModeBanner: false,

        localizationsDelegates: const [
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        supportedLocales: const [
          Locale('en'),
        ],

        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Arial',
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.blackCat,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFF292222),
          canvasColor: const Color(0xFF292222),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppColors.blackCat,
            selectionColor: AppColors.alabaster,
            selectionHandleColor: AppColors.blackCat,
          ),
          iconTheme: const IconThemeData(color: AppColors.blackCat),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.blackCat,
            ),
          ),
          textTheme: ThemeData.light().textTheme
              .apply(
                bodyColor: AppColors.blackCat,
                displayColor: AppColors.blackCat,
              )
              .copyWith(
                displayLarge: ThemeData.light().textTheme.displayLarge
                    ?.copyWith(color: AppColors.blackCat),
                displayMedium: ThemeData.light().textTheme.displayMedium
                    ?.copyWith(color: AppColors.blackCat),
                displaySmall: ThemeData.light().textTheme.displaySmall
                    ?.copyWith(color: AppColors.blackCat),
                headlineLarge: ThemeData.light().textTheme.headlineLarge
                    ?.copyWith(color: AppColors.blackCat),
                headlineMedium: ThemeData.light().textTheme.headlineMedium
                    ?.copyWith(color: AppColors.blackCat),
                headlineSmall: ThemeData.light().textTheme.headlineSmall
                    ?.copyWith(color: AppColors.blackCat),
                titleLarge: ThemeData.light().textTheme.titleLarge
                    ?.copyWith(color: AppColors.blackCat),
                titleMedium: ThemeData.light().textTheme.titleMedium
                    ?.copyWith(color: AppColors.blackCat),
                titleSmall: ThemeData.light().textTheme.titleSmall
                    ?.copyWith(color: AppColors.blackCat),
              ),
          primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
                bodyColor: AppColors.blackCat,
                displayColor: AppColors.blackCat,
              ),
          appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(
              color: AppColors.blackCat,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arial',
            ),
            iconTheme: IconThemeData(color: AppColors.blackCat),
          ),
          inputDecorationTheme: InputDecorationTheme(
            hintStyle: const TextStyle(fontSize: 12),
            labelStyle: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.82),
            ),
            floatingLabelStyle: const TextStyle(
              color: AppColors.blackCat,
            ),
            helperStyle: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.72),
            ),
            prefixStyle: const TextStyle(
              color: AppColors.blackCat,
            ),
            suffixStyle: const TextStyle(
              color: AppColors.blackCat,
            ),
            counterStyle: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.72),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat,
                width: 1.2,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat,
                width: 1,
              ),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: AppColors.blackCat,
                width: 1.2,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              textStyle: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              textStyle: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              side: const BorderSide(color: AppColors.blackCat),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              textStyle: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),

        builder: (context, child) {
          final scale = fontScale(context);
          final baseTheme = Theme.of(context);
          final mediaQuery = MediaQuery.of(context);
          final safeInsets = mediaQuery.viewPadding;

          return ColoredBox(
            color: const Color(0xFF292222),
            child: Theme(
              data: baseTheme.copyWith(
                scaffoldBackgroundColor: const Color(0xFF292222),
                canvasColor: const Color(0xFF292222),
                textTheme: baseTheme.textTheme.apply(
                  fontSizeFactor: scale,
                ),
              ),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  padding: EdgeInsets.only(
                    top: safeInsets.top,
                    bottom: safeInsets.bottom,
                    left: safeInsets.left,
                    right: safeInsets.right,
                  ),
                ),
                child: SafeArea(
                  top: true,
                  bottom: true,
                  left: true,
                  right: true,
                  // MaterialApp always invokes `builder` with a non-null
                  // child when `home`/`routes` are configured (as above).
                  child: child!,
                ),
              ),
            ),
          );
        },

        home: const HomePage(),

        routes: {
          '/login': (_) => const LoginDialog(),
          '/register': (_) => const RegisterPage(),
          '/client-register': (_) => const ClientRegistrationPage(),
          '/client-shell': (_) => ClientShellPage(
                profile: ClientProfileDraft.mock(),
              ),
          '/artist-login': (_) => const ArtistLoginPage(),
          '/artist-register-v2': (_) => const ArtistRegistrationFlow(),
          '/reset-password-success': (_) => const ResetPasswordSuccessPage(),
        },
      ),
    );
  }
}

class _DeepLinkBootstrap extends StatefulWidget {
  const _DeepLinkBootstrap({
    required this.child,
  });

  final Widget child;

  @override
  State<_DeepLinkBootstrap> createState() => _DeepLinkBootstrapState();
}

class _DeepLinkBootstrapState extends State<_DeepLinkBootstrap> {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }

      _appLinks.uriLinkStream.listen(
        (Uri uri) async {
          await _handleDeepLink(uri);
        },
      );
    } catch (e) {
      debugPrint('Deep link error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Received deep link: $uri');

    final extractedUri = _extractDeepLink(uri);

    final mode = extractedUri.queryParameters['mode'];
    final oobCode = extractedUri.queryParameters['oobCode'];
    final email = extractedUri.queryParameters['email'];
    final isSupabaseResetLink =
        extractedUri.path.contains('reset-password') ||
        extractedUri.queryParameters['type'] == 'recovery' ||
        extractedUri.queryParameters.containsKey('code') ||
        extractedUri.queryParameters.containsKey('token_hash') ||
        extractedUri.fragment.contains('access_token=');

    if (isSupabaseResetLink) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(extractedUri);
      } catch (_) {}

      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            oobCode: extractedUri.queryParameters['code'] ??
                extractedUri.queryParameters['token_hash'] ??
                oobCode ??
                '',
            email: email,
          ),
        ),
      );

      return;
    }

    if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            oobCode: oobCode,
            email: email,
          ),
        ),
      );

      return;
    }

    final path = extractedUri.path;
    final orderId = extractedUri.queryParameters['orderId'];
    final artistId = extractedUri.queryParameters['artistId'];
    final tipPercentRaw = extractedUri.queryParameters['tipPercent'];

    if (path.contains('review-order') &&
        orderId != null &&
        artistId != null) {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ReviewArtistPage(
            orderId: orderId,
            artistId: artistId,
          ),
        ),
      );

      return;
    }

    if (path.contains('tip-artist') && orderId != null && artistId != null) {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      final tipPercent = int.tryParse(tipPercentRaw ?? '') ?? 15;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => TipArtistPage(
            orderId: orderId,
            artistId: artistId,
            tipPercent: tipPercent,
          ),
        ),
      );

      return;
    }

    final type = extractedUri.queryParameters['type'];

    if (type == 'account-verified') {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      return;
    }

    debugPrint('Deep link ignored: $extractedUri');
  }

  Uri _extractDeepLink(Uri uri) {
    for (final key in [
      'link',
      'continueUrl',
      'deep_link_id',
    ]) {
      final value = uri.queryParameters[key];

      if (value != null && value.isNotEmpty) {
        final decoded = Uri.decodeFull(value);
        final parsed = Uri.tryParse(decoded);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return uri;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
