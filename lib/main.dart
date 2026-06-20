import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:country_code_picker/country_code_picker.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/client_registration_page.dart';
import 'pages/client_shell_page.dart';
import 'pages/artist_login_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/reset_password_success_page.dart';

import 'theme/app_colors.dart';
import 'utlis/responsive_text.dart';
import 'services/firebase_bootstrap.dart';
import 'services/supabase_bootstrap.dart';
import 'services/startup_frame_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/phone_verification_page.dart';
import 'models/client_profile_models.dart';
import 'pages/review_artist_page.dart';
import 'pages/tip_artist_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupFrameGate.deferFirstFrame();
  final supabaseOk = await SupabaseBootstrap.ensureInitialized();
  if (!supabaseOk) {
    debugPrint(
      'Supabase initialization failed: ${SupabaseBootstrap.lastError}',
    );
  }
  runApp(const JntApp());
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
    final firebaseOk = await FirebaseBootstrap.ensureInitialized();

    if (!firebaseOk) {
      debugPrint(
        'Firebase initialization failed: ${FirebaseBootstrap.lastError}',
      );
    }

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

    final extractedUri = _extractFirebaseDynamicLink(uri);

    final mode = extractedUri.queryParameters['mode'];
    final oobCode = extractedUri.queryParameters['oobCode'];
    final email = extractedUri.queryParameters['email'];

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
    final role = extractedUri.queryParameters['role'];

    if (type == 'account-verified') {
      final navigator = JntApp.navigatorKey.currentState;
      if (navigator == null) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        navigator.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        return;
      }

      final uid = user.uid;

      String collectionName = 'client';
      String accountType = role ?? 'client';

      switch (accountType) {
        case 'artist':
          collectionName = 'artist';
          break;
        case 'client+artist':
          collectionName = 'client_artist';
          break;
        case 'company':
          collectionName = 'company';
          break;
        default:
          collectionName = 'client';
      }

      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(uid)
          .get();

      final data = doc.data();

      if (data == null) {
        navigator.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PhoneVerificationPage(
            phoneNumber: data['phoneNumber'] ?? '',
            userEmail: data['email'] ?? '',
            userName: data['fullName'] ?? '',
            accountType: accountType,
            collectionName: collectionName,
            uid: uid,
          ),
        ),
        (route) => false,
      );

      return;
    }

    debugPrint('Deep link ignored: $extractedUri');
  }

  Uri _extractFirebaseDynamicLink(Uri uri) {
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
