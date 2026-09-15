import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'utlis/responsive_layout.dart';
import 'services/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/client_profile_models.dart';
import 'pages/artist_registration/artist_registration_flow.dart';
import 'pages/tip_artist_page.dart';
import 'services/delivered_review_deep_link.dart';

// Sentry DSN is intentionally blank by default: the Sentry SDK safely no-ops
// (runs the app normally, just doesn't send events) when the DSN is empty.
// Supply the real DSN at build time with:
//   flutter run --dart-define=SENTRY_DSN=https://...
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  // Skip Sentry entirely when no DSN is configured: SentryFlutter.init()
  // still spins up the native SDK (file manager, ANR watchdog, transport
  // factory) even with a blank DSN, which repeatedly fails to parse it and
  // logs errors on every launch for no benefit.
  if (_sentryDsn.isEmpty) {
    await _startApp();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = Environment.name;
    options.tracesSampleRate = 0.2;
  }, appRunner: _startApp);
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Detect the physical display rather than the current Flutter view. During
  // a cold launch/session restore, the view can briefly report a stale or
  // letterboxed phone-sized window before Android/iOS delivers final metrics.
  // The display size is stable, so cold launch and hot restart now classify
  // the same device identically.
  final platformView = WidgetsBinding.instance.platformDispatcher.views.first;
  final display = platformView.display;
  final devicePixelRatio = display.devicePixelRatio <= 0
      ? 1.0
      : display.devicePixelRatio;
  final logicalDisplaySize = display.size / devicePixelRatio;
  final hasValidDisplaySize =
      logicalDisplaySize.width > 0 && logicalDisplaySize.height > 0;

  // If native display metrics are not ready, leave rotation unrestricted
  // instead of incorrectly forcing a tablet into portrait phone letterboxing.
  final isTablet = !hasValidDisplaySize || isTabletSize(logicalDisplaySize);
  await SystemChrome.setPreferredOrientations(
    isTablet
        ? DeviceOrientation.values
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  runApp(const _AppBootstrapper());
}

/// Renders initial app hierarchy while [SupabaseBootstrap.ensureInitialized]
/// runs in the background, then swaps to [JntApp] on success or
/// [_SupabaseInitFailedApp] on failure.
class _AppBootstrapper extends StatefulWidget {
  const _AppBootstrapper();

  @override
  State<_AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<_AppBootstrapper> {
  late Future<bool> _supabaseReady;
  final Stopwatch _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _supabaseReady = SupabaseBootstrap.ensureInitialized().then((ok) {
      debugPrint(
        '[STARTUP] SupabaseBootstrap.ensureInitialized: ${_sw.elapsedMilliseconds}ms '
        '(ok=$ok)',
      );
      return ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _supabaseReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LogoSplash();
        }
        if (snapshot.data != true) {
          debugPrint(
            'Supabase initialization failed: ${SupabaseBootstrap.lastError}',
          );
          return _SupabaseInitFailedApp(error: SupabaseBootstrap.lastError);
        }
        return const JntApp();
      },
    );
  }
}

/// The one loading frame shown throughout cold start, from native splash
/// hand-off through session restoration: same blackCat background as the
/// native launch theme, with the JNT logo, so there is no visible seam no
/// matter how long each async step underneath actually takes.
class _LogoSplash extends StatelessWidget {
  const _LogoSplash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.blackCat,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 72),
          child: Image(
            image: AssetImage('assets/images/JNTWhitelogo.png'),
            width: 160,
          ),
        ),
      ),
    );
  }
}

/// Shown on app resume when the restored session belongs to an account an
/// admin has deactivated (see AccountDeactivatedException). The session is
/// already signed out by this point, so the only way forward is back to the
/// public landing page's sign-in flow.
class _AccountDeactivatedPage extends StatelessWidget {
  const _AccountDeactivatedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackCat,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block_rounded,
                  size: 48,
                  color: AppColors.snow,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Account Deactivated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.snow,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account has been deactivated. Contact support for help.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.snow.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  },
                  child: const Text('Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Restores Supabase's persisted session and sends every supported account
/// role directly to its signed-in shell. The public landing page is only
/// shown when there is no session (normally after an explicit logout).
class _SessionHomeGate extends StatefulWidget {
  const _SessionHomeGate();

  @override
  State<_SessionHomeGate> createState() => _SessionHomeGateState();
}

class _SessionHomeGateState extends State<_SessionHomeGate> {
  late Future<Widget> _home;

  @override
  void initState() {
    super.initState();
    _home = _resolveHome();
  }

  Future<Widget> _resolveHome() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      return const HomePage();
    }
    await _waitForSessionRestoration(auth);

    if (auth.currentSession == null) {
      return const HomePage();
    }
    try {
      return await LoginDialog.restoredSessionHome() ?? const HomePage();
    } on AccountDeactivatedException {
      return const _AccountDeactivatedPage();
    }
  }

  Future<void> _waitForSessionRestoration(GoTrueClient auth) async {
    if (auth.currentSession != null) return;

    final restored = Completer<void>();
    late final StreamSubscription<AuthState> subscription;
    subscription = auth.onAuthStateChange.listen((state) {
      final isInitialAuthEvent =
          state.event == AuthChangeEvent.initialSession ||
          state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed;
      if (isInitialAuthEvent && !restored.isCompleted) {
        restored.complete();
      }
    });

    try {
      if (auth.currentSession == null) {
        await restored.future.timeout(const Duration(seconds: 2));
      }
    } catch (_) {
    } finally {
      await subscription.cancel();
    }
  }

  void _retry() {
    setState(() => _home = _resolveHome());
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    setState(() => _home = Future<Widget>.value(const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _home,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Not the marketing HomePage: whether this resolves in a few
          // milliseconds (session already cached) or takes the full
          // restoration wait, a signed-in user must see one consistent
          // frame throughout, not a flash of the logged-out landing page
          // (with its "Sign In" button) that only appears when resolution
          // happens to be slow enough for this frame to actually paint.
          return const _LogoSplash();
        }
        if (snapshot.hasData) return snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.blackCat,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: AppColors.snow,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to restore your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.snow,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your login is still saved. Check your connection and '
                      'try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.snow.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _logout,
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shown only when Supabase fails to initialize at startup (e.g. no network,
/// bad config). Lets the user retry instead of the app silently proceeding
/// into a broken state with no working backend client.
class _SupabaseInitFailedApp extends StatefulWidget {
  const _SupabaseInitFailedApp({this.error});

  final String? error;

  @override
  State<_SupabaseInitFailedApp> createState() => _SupabaseInitFailedAppState();
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
      themeMode: ThemeMode.light,
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
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
    return _AccountStatusWatchdog(
      child: _DeepLinkBootstrap(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [jntRouteObserver],
          title: 'JewelNotTool',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light,

          localizationsDelegates: const [
            CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          supportedLocales: const [Locale('en')],

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
              style: IconButton.styleFrom(foregroundColor: AppColors.blackCat),
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
                  titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(
                    color: AppColors.blackCat,
                  ),
                  titleMedium: ThemeData.light().textTheme.titleMedium
                      ?.copyWith(color: AppColors.blackCat),
                  titleSmall: ThemeData.light().textTheme.titleSmall?.copyWith(
                    color: AppColors.blackCat,
                  ),
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
              floatingLabelStyle: const TextStyle(color: AppColors.blackCat),
              helperStyle: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.72),
              ),
              prefixStyle: const TextStyle(color: AppColors.blackCat),
              suffixStyle: const TextStyle(color: AppColors.blackCat),
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
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
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
                borderSide: BorderSide(color: AppColors.blackCat, width: 1),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
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
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
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
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ),

          builder: (context, child) {
            final scale = fontScale(context);
            final baseTheme = Theme.of(context);
            final mediaQuery = MediaQuery.of(context);
            final safeInsets = mediaQuery.viewPadding;
            final isTablet = isTabletSize(mediaQuery.size);

            // Theme scaling does not affect Text widgets that declare their own
            // fontSize, which most JNT pages do. On tablets/iPads, compose the
            // responsive factor with the platform text scaler so every label,
            // field, button and heading receives the same controlled increase
            // while the user's Android/iOS accessibility preference is kept.
            // Phones retain the existing theme-only scaling behavior exactly.
            final effectiveTextScaler = isTablet
                ? TextScaler.linear(mediaQuery.textScaler.scale(1.0) * scale)
                : mediaQuery.textScaler;

            final themedChild = Theme(
              data: baseTheme.copyWith(
                scaffoldBackgroundColor: const Color(0xFF292222),
                canvasColor: const Color(0xFF292222),
                textTheme: baseTheme.textTheme.apply(
                  fontSizeFactor: isTablet ? 1.0 : scale,
                ),
              ),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: effectiveTextScaler,
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
            );

            // Always pass the device's real logical width to the current page.
            // The previous tablet-only ConstrainedBox(maxWidth: 520) made every
            // route render as a centered phone screen on Android tablets and
            // iPads. Removing that parent constraint does not affect phones;
            // their available width is already unchanged. Individual pages can
            // now respond to the actual tablet/iPad viewport with LayoutBuilder
            // or MediaQuery while preserving their existing UI and behavior.
            return ColoredBox(
              color: const Color(0xFF292222),
              child: themedChild,
            );
          },

          home: const _SessionHomeGate(),

          routes: {
            '/login': (_) => const LoginDialog(),
            '/register': (_) => const RegisterPage(),
            '/client-register': (_) => const ClientRegistrationPage(),
            '/client-shell': (_) =>
                ClientShellPage(profile: ClientProfileDraft.mock()),
            '/artist-login': (_) => const ArtistLoginPage(),
            '/artist-register-v2': (_) => const ArtistRegistrationFlow(),
            '/reset-password-success': (_) => const ResetPasswordSuccessPage(),
          },
        ),
      ),
    );
  }
}

class _DeepLinkBootstrap extends StatefulWidget {
  const _DeepLinkBootstrap({required this.child});

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

      _appLinks.uriLinkStream.listen((Uri uri) async {
        await _handleDeepLink(uri);
      });
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
            oobCode:
                extractedUri.queryParameters['code'] ??
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
          builder: (_) => ResetPasswordPage(oobCode: oobCode, email: email),
        ),
      );

      return;
    }

    final path = extractedUri.path;
    final orderId = extractedUri.queryParameters['orderId'];
    final artistId = extractedUri.queryParameters['artistId'];
    final tipPercentRaw = extractedUri.queryParameters['tipPercent'];

    if (path.contains('review-order') && orderId != null) {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      await openDeliveredReviewOrder(navigator, orderId);

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
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    debugPrint('Deep link ignored: $extractedUri');
  }

  Uri _extractDeepLink(Uri uri) {
    for (final key in ['link', 'continueUrl', 'deep_link_id']) {
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

/// Detects an admin deactivating the signed-in user's account *while the app
/// is already open* (the login-time and session-restore checks in
/// login_page.dart only catch a deactivation that happened before this
/// launch/sign-in). Subscribes to postgres_changes on whichever role table
/// the signed-in user's row lives in and, the moment that row flips to
/// blocked, force-signs-out and shows the same deactivated-account page used
/// elsewhere.
class _AccountStatusWatchdog extends StatefulWidget {
  const _AccountStatusWatchdog({required this.child});

  final Widget child;

  @override
  State<_AccountStatusWatchdog> createState() => _AccountStatusWatchdogState();
}

class _AccountStatusWatchdogState extends State<_AccountStatusWatchdog> {
  static const _watchedTables = <String>[
    'client',
    'artist',
    'client_artist',
    'company',
  ];

  StreamSubscription<AuthState>? _authSub;
  final List<RealtimeChannel> _channels = [];
  String? _watchedUid;
  bool _handlingDeactivation = false;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    final currentUid = auth.currentUser?.id;
    if (currentUid != null && currentUid.isNotEmpty) {
      _subscribeFor(currentUid);
    }
    _authSub = auth.onAuthStateChange.listen((state) {
      final uid = state.session?.user.id;
      debugPrint('[WATCHDOG] authStateChange event=${state.event} uid=$uid');
      switch (state.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (uid != null && uid.isNotEmpty && uid != _watchedUid) {
            _subscribeFor(uid);
          }
          break;
        case AuthChangeEvent.signedOut:
          _unsubscribeAll();
          break;
        default:
          break;
      }
    });
  }

  void _subscribeFor(String uid) {
    _unsubscribeAll();
    _watchedUid = uid;
    _handlingDeactivation = false;
    debugPrint('[WATCHDOG] subscribing for uid=$uid on $_watchedTables');
    final supabase = Supabase.instance.client;
    for (final table in _watchedTables) {
      final channel = supabase
          .channel('account_status_watch_${table}_$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: uid,
            ),
            callback: (payload) {
              debugPrint(
                '[WATCHDOG] postgres_changes fired on $table for uid=$uid: '
                '${payload.newRecord}',
              );
              _onRowUpdated(payload.newRecord);
            },
          )
          .subscribe((status, error) {
            debugPrint(
              '[WATCHDOG] channel($table) status=$status error=$error',
            );
          });
      _channels.add(channel);
    }
  }

  void _onRowUpdated(Map<String, dynamic> newRecord) {
    if (_handlingDeactivation) return;
    if (!isAccountBlocked(newRecord)) return;
    debugPrint('[WATCHDOG] blocked row detected, forcing sign-out');
    _handlingDeactivation = true;
    unawaited(_forceSignOutForDeactivation());
  }

  Future<void> _forceSignOutForDeactivation() async {
    _unsubscribeAll();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    final navigator = JntApp.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _AccountDeactivatedPage()),
      (route) => false,
    );
  }

  void _unsubscribeAll() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
    _watchedUid = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _unsubscribeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
