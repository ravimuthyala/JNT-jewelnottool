import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';
import '../services/supabase_auth_service.dart';
import 'artist_shell_page.dart';
import 'client_shell_page.dart';
import '../models/client_profile_models.dart';
import 'branding_company_shell_page.dart';
import 'client_artist_home_page.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  static String? pendingVerifiedRole;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  static const Color _blackCat = AppColors.blackCat;
  static const Color _snow = AppColors.snow;
  static const Color _linkShade = AppColors.blackCat;
  static const Color _focusRing = Color(0xFF5A5353);

  static const bool _bypassPostLoginFirestoreLookup = false;

  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 14;

  bool obscure = true;
  bool _isSubmitting = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode(debugLabel: 'emailField');
  final FocusNode _passwordFocusNode = FocusNode(debugLabel: 'passwordField');

  String? _error;

  void _authLog(String message) {
    debugPrint('[LOGIN] $message');
  }

  void _closeDialogAndPushReplacement(Widget page) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;

    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }

    if (!rootNavigator.mounted) return;

    Navigator.of(
      rootContext,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  static const _collectionClientArtist = 'client_artist';
  static const _collectionArtist = 'artist';
  static const _collectionClient = 'client';
  static const _collectionCompany = 'company';

  static final ButtonStyle _linkButtonStyle =
      TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        foregroundColor: _linkShade,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return _focusRing.withValues(alpha: 0.18);
          }
          if (states.contains(WidgetState.pressed)) {
            return _blackCat.withValues(alpha: 0.12);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: _focusRing, width: 1);
          }
          return BorderSide.none;
        }),
        shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
      );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _setError(String message) {
    final normalized = message.trim();

    final looksLikeEmailOnly = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(normalized);

    final safeMessage = looksLikeEmailOnly
        ? 'Invalid email or password.'
        : normalized;

    setState(() {
      _error = safeMessage;
      _isSubmitting = false;
    });
  }

  String? _normalizePendingRole(String? role) {
    final value = (role ?? '').trim().toLowerCase();

    switch (value) {
      case 'client':
        return 'client';
      case 'artist':
        return 'artist';
      case 'client+artist':
      case 'client_artist':
      case 'client-artist':
      case 'creator':
        return 'client+artist';
      case 'company':
      case 'brand':
        return 'company';
      default:
        return null;
    }
  }

  Future<void> _login() async {
    if (_isSubmitting) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    final sw = Stopwatch()..start();

    _authLog('submit tapped');
    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    _authLog(
      'input captured emailLen=${email.length} passwordLen=${pass.length}',
    );

    if (email.isEmpty && pass.isEmpty) {
      _authLog('validation failed: email and password empty');
      _setError('Please enter your email and password.');
      _emailFocusNode.requestFocus();
      return;
    }

    if (email.isEmpty) {
      _authLog('validation failed: email empty');
      _setError('Please enter your email.');
      _emailFocusNode.requestFocus();
      return;
    }

    if (pass.isEmpty) {
      _authLog('validation failed: password empty');
      _setError('Please enter your password.');
      _passwordFocusNode.requestFocus();
      return;
    }

    try {
      _authLog('calling SupabaseAuthService.login');
      final user = await SupabaseAuthService.login(
        email: email,
        password: pass,
      );
      _authLog('auth returned userId=${user?.id ?? 'null'}');

      final uid = user?.id ?? SupabaseAuthService.currentUserId;

      if (uid == null || uid.trim().isEmpty) {
        _authLog('login succeeded but uid is empty; forcing sign out');
        await SupabaseAuthService.logout();
        if (!mounted) return;
        _setError('Unable to sign in. Please try again.');
        return;
      }

      if (!mounted) return;

      if (_bypassPostLoginFirestoreLookup) {
        _authLog('bypassing post-login lookup; navigating to bypass page');
        _closeDialogAndPushReplacement(const _PostLoginBypassPage());
        return;
      }

      _authLog('loading account doc for uid=$uid');
      final accountDoc = await _loadAccountDocWithRetry(uid);
      final data = accountDoc?.data;
      final pendingRole = _normalizePendingRole(LoginDialog.pendingVerifiedRole);

      _authLog(
        'account doc loaded collection=${accountDoc?.collection ?? 'none'} '
        'hasData=${data != null} pendingRole=${pendingRole ?? 'none'}',
      );

      LoginDialog.pendingVerifiedRole = null;

      if (data != null) {
        final sourceCollection = accountDoc!.collection;
        final roles = (data['roles'] as Map<String, dynamic>?) ?? const {};

        final hasExplicitRoles = roles.isNotEmpty;
        final roleClient = roles['client'] == true;
        final roleArtist = roles['artist'] == true;
        final roleCompany = roles['company'] == true;

        final accountType = (data['account_type'] ?? data['accountType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final isClient = hasExplicitRoles
            ? roleClient
            : sourceCollection == _collectionClientArtist ||
                sourceCollection == _collectionClient ||
                accountType == 'client' ||
                accountType == 'client_artist' ||
                accountType == 'client+artist';

        final isArtist = hasExplicitRoles
            ? roleArtist
            : sourceCollection == _collectionClientArtist ||
                sourceCollection == _collectionArtist ||
                accountType == 'artist' ||
                accountType == 'client_artist' ||
                accountType == 'client+artist';

        final isCompany = hasExplicitRoles
            ? roleCompany
            : sourceCollection == _collectionCompany ||
                accountType == 'company';

        if ((isArtist && isClient) || pendingRole == 'client+artist') {
          _authLog('routing to ClientArtistHomePage');
          final draft = _draftFromSupabase(data);

          _closeDialogAndPushReplacement(
            ClientArtistHomePage(
              profile: draft,
              showContinueProfileCard: false,
              enableAllTabs: true,
            ),
          );
          return;
        }

        if (isArtist || pendingRole == 'artist') {
          _authLog('routing to ArtistShellPage');
          _closeDialogAndPushReplacement(const ArtistShellPage());
          return;
        }

        if (isClient || pendingRole == 'client') {
          _authLog('routing to ClientShellPage');
          final draft = _draftFromSupabase(data);
          _closeDialogAndPushReplacement(
            ClientShellPage(profile: draft, forceEnableAllTabs: true),
          );
          return;
        }

        if (isCompany || pendingRole == 'company') {
          _authLog('routing to BrandingCompanyShellPage');
          final companyMap = (data['company'] as Map<String, dynamic>?) ?? {};
          final panelName = (data['panel_companyName'] ?? '')
              .toString()
              .trim();

          final companyName = panelName.isNotEmpty
              ? panelName
              : (companyMap['name'] ?? '').toString().trim();

          _closeDialogAndPushReplacement(
            BrandingCompanyShellPage(
              companyDisplayName: companyName.isEmpty ? 'Brand' : companyName,
            ),
          );
          return;
        }
      }

      _authLog('no role mapped; signing out and showing error');
      await SupabaseAuthService.logout();

      if (!mounted) return;
      _setError('No role mapped for this account');
    } on AuthException catch (e) {
      _authLog('AuthException: ${e.message}');
      if (!mounted) return;
      _setError(_friendlyAuthError(e));
    } on PostgrestException catch (e) {
      _authLog('PostgrestException: ${e.message}');
      if (!mounted) return;
      debugPrint('LOGIN SUPABASE PROFILE ERROR: ${e.message}');
      _setError('Login succeeded, but profile lookup failed.');
    } catch (e, st) {
      _authLog('Unexpected error: $e');
      if (!mounted) return;
      debugPrint('LOGIN ERROR: $e');
      debugPrint(st.toString());
      _setError('Login failed. Please try again.');
    } finally {
      _authLog('finished in ${sw.elapsedMilliseconds}ms');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _friendlyAuthError(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }

    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }

    if (message.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }

    if (message.contains('network') || message.contains('failed to fetch')) {
      return 'Network error. Check your connection and try again.';
    }

    return 'Login failed. Please try again.';
  }

  Future<_AccountDoc?> _loadAccountDoc(String uid) async {
    final supabase = Supabase.instance.client;

    const collections = <String>[
      _collectionClientArtist,
      _collectionArtist,
      _collectionClient,
      _collectionCompany,
    ];

    final requests = collections.map((collection) {
      return supabase
          .from(collection)
          .select()
          .eq('id', uid)
          .maybeSingle()
          .then((data) {
            if (data != null) {
              return _AccountDoc(
                collection: collection,
                data: Map<String, dynamic>.from(data),
              );
            }
            return null;
          })
          .catchError((_) => null);
    });

    final results = await Future.wait(requests);
    for (final doc in results) {
      if (doc != null) {
        return doc;
      }
    }

    return null;
  }

  Future<_AccountDoc?> _loadAccountDocWithRetry(String uid) async {
    const int maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final doc = await _loadAccountDoc(
          uid,
        ).timeout(const Duration(seconds: 12));
        return doc;
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
      }
    }
    return null;
  }

  ClientProfileDraft _draftFromSupabase(Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
    final address = (data['address'] as Map<String, dynamic>?) ?? {};
    final client = (data['client'] as Map<String, dynamic>?) ?? {};

    final profileFromClient =
        (client['profile'] as Map<String, dynamic>?) ?? const {};
    final addressFromClient =
        (client['address'] as Map<String, dynamic>?) ?? const {};
    final paymentFromClient =
        (client['payment'] as Map<String, dynamic>?) ?? const {};
    final nailFromClient =
        (client['nailPreferences'] as Map<String, dynamic>?) ??
        (client['nail_preferences'] as Map<String, dynamic>?) ??
        const {};

    final payment =
        (data['payment'] as Map<String, dynamic>?)?.isNotEmpty == true
        ? data['payment'] as Map<String, dynamic>
        : paymentFromClient;

    final nail =
        (data['nailPreferences'] as Map<String, dynamic>?)?.isNotEmpty == true
        ? data['nailPreferences'] as Map<String, dynamic>
        : (data['nail_preferences'] as Map<String, dynamic>?)?.isNotEmpty ==
            true
        ? data['nail_preferences'] as Map<String, dynamic>
        : nailFromClient;

    final dimensions = (nail['dimensions'] as Map<String, dynamic>?) ?? {};

    PaymentMethod parsePaymentMethod(String? value) {
      switch (value) {
        case 'applePay':
          return PaymentMethod.applePay;
        case 'venmo':
          return PaymentMethod.venmo;
        case 'paypal':
          return PaymentMethod.paypal;
        case 'card':
          return PaymentMethod.card;
      }
      return PaymentMethod.applePay;
    }

    NailLength parseNailLength(String? value) {
      switch (value) {
        case 'short':
          return NailLength.short;
        case 'medium':
          return NailLength.medium;
        case 'long':
          return NailLength.long;
        case 'extraLong':
          return NailLength.extraLong;
        case 'xlLong':
          return NailLength.xlLong;
      }
      return NailLength.none;
    }

    return ClientProfileDraft(
      basic: BasicInfo(
        name:
            ((profile['name'] ?? '').toString().trim().isNotEmpty
                    ? profile['name']
                    : profile['displayName'] ??
                          profile['nameOrStudio'] ??
                          profileFromClient['name'] ??
                          profileFromClient['displayName'] ??
                          profileFromClient['nameOrStudio'] ??
                          data['panel_displayName'] ??
                          data['panel_nameOrStudio'] ??
                          '')
                .toString(),
        email: (data['email'] ?? '').toString(),
        phone:
            ((profile['phone'] ?? '').toString().trim().isNotEmpty
                    ? profile['phone']
                    : profileFromClient['phone'] ?? data['panel_phone'] ?? '')
                .toString(),
        profileImageUrl: '',
      ),
      address: AddressInfo(
        street:
            ((address['street'] ?? '').toString().trim().isNotEmpty
                    ? address['street']
                    : addressFromClient['street'] ?? data['panel_street'] ?? '')
                .toString(),
        city:
            ((address['city'] ?? '').toString().trim().isNotEmpty
                    ? address['city']
                    : addressFromClient['city'] ?? data['panel_city'] ?? '')
                .toString(),
        state:
            ((address['state'] ?? '').toString().trim().isNotEmpty
                    ? address['state']
                    : addressFromClient['state'] ?? data['panel_state'] ?? '')
                .toString(),
        zip:
            ((address['zip'] ?? '').toString().trim().isNotEmpty
                    ? address['zip']
                    : addressFromClient['zip'] ?? data['panel_zip'] ?? '')
                .toString(),
        country:
            ((address['country'] ?? '').toString().trim().isNotEmpty
                    ? address['country']
                    : addressFromClient['country'] ??
                          data['panel_country'] ??
                          '')
                .toString(),
      ),
      payment: PaymentInfo(
        method: parsePaymentMethod(payment['method']?.toString()),
        saveForFuture: payment['saveForFuture'] == true,
        cardNumber: (payment['cardNumber'] ?? '').toString(),
        nameOnCard: (payment['nameOnCard'] ?? '').toString(),
        expiryMMYY: (payment['expiryMMYY'] ?? '').toString(),
        cvv: (payment['cvv'] ?? '').toString(),
        zip: (payment['zip'] ?? '').toString(),
        venmoHandle: (payment['venmoHandle'] ?? '').toString(),
        paypalEmail: (payment['paypalEmail'] ?? '').toString(),
      ),
      nail: NailPreferences(
        shape: (nail['shape'] ?? '').toString(),
        length: parseNailLength(nail['length']?.toString()),
        dimensions: NailDimensions(
          lThumb: (dimensions['lThumb'] as num?)?.toDouble(),
          lIndex: (dimensions['lIndex'] as num?)?.toDouble(),
          lMiddle: (dimensions['lMiddle'] as num?)?.toDouble(),
          lRing: (dimensions['lRing'] as num?)?.toDouble(),
          lPinky: (dimensions['lPinky'] as num?)?.toDouble(),
          rThumb: (dimensions['rThumb'] as num?)?.toDouble(),
          rIndex: (dimensions['rIndex'] as num?)?.toDouble(),
          rMiddle: (dimensions['rMiddle'] as num?)?.toDouble(),
          rRing: (dimensions['rRing'] as num?)?.toDouble(),
          rPinky: (dimensions['rPinky'] as num?)?.toDouble(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final dialogMaxHeight =
        mediaQuery.size.height * (keyboardOpen ? 0.68 : 0.74);

    return Semantics(
      namesRoute: true,
      scopesRoute: true,
      label: 'Sign in dialog',
      container: true,
      explicitChildNodes: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 22,
          vertical: keyboardOpen ? 8 : 24,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        clipBehavior: Clip.hardEdge,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: dialogMaxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JntModalHeaderBar(
                onClose: () => Navigator.pop(context),
                closeTooltip: 'Close sign in dialog',
                autofocusClose: MediaQuery.of(context).accessibleNavigation,
              ),

              Flexible(
                child: Container(
                  color: _snow,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),

                        Semantics(
                          header: true,
                          child: Text(
                            'Sign In To Your Account',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'Arial',
                              color: _blackCat,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Column(
                          children: [
                            TextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocusNode,
                              autofocus: true,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: AppColors.blackCat,
                                fontSize: 12,
                                fontFamily: 'Arial',
                              ),
                              cursorColor: AppColors.blackCat,
                              onSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                              decoration: _fieldDecoration('Email'),
                            ),

                            const SizedBox(height: 6),

                            TextField(
                              controller: _passCtrl,
                              focusNode: _passwordFocusNode,
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                color: AppColors.blackCat,
                                fontSize: 12,
                                fontFamily: 'Arial',
                              ),
                              cursorColor: AppColors.blackCat,
                              onSubmitted: (_) => _login(),
                              decoration: _fieldDecoration(
                                'Password',
                                suffixIcon: IconButton(
                                  tooltip: obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.blackCat,
                                  ),
                                  color: AppColors.blackCat,
                                  onPressed: () {
                                    setState(() => obscure = !obscure);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          Semantics(
                            liveRegion: true,
                            container: true,
                            label: _error,
                            child: ExcludeSemantics(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 4),

                        Center(
                          child: TextButton(
                            style: _linkButtonStyle,
                            onPressed: () async {
                              final rootNavigator = Navigator.of(
                                context,
                                rootNavigator: true,
                              );
                              final rootContext = rootNavigator.context;

                              rootNavigator.pop();

                              await showForgotPasswordModal(rootContext);

                              if (!rootNavigator.mounted) return;

                              await showDialog(
                                context: rootContext,
                                barrierDismissible: true,
                                barrierColor: Colors.black.withValues(
                                  alpha: 0.45,
                                ),
                                builder: (_) => const LoginDialog(),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                fontFamily: 'Arial',
                                color: _linkShade,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        Center(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              style:
                                  ElevatedButton.styleFrom(
                                    backgroundColor: _blackCat,
                                    foregroundColor: _snow,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    minimumSize: const Size(156, 52),
                                  ).copyWith(
                                    side: WidgetStateProperty.resolveWith((
                                      states,
                                    ) {
                                      if (states.contains(
                                        WidgetState.focused,
                                      )) {
                                        return const BorderSide(
                                          color: _focusRing,
                                          width: 1,
                                        );
                                      }
                                      return BorderSide.none;
                                    }),
                                  ),
                              onPressed: _isSubmitting ? null : _login,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _snow,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'Arial',
                                        color: _snow,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: _linkShade,
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                fontFamily: 'Arial',
                              ),
                            ),
                            TextButton(
                              style: _linkButtonStyle,
                              onPressed: () {
                                Navigator.pop(context);
                                showRegisterModal(
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).context,
                                );
                              },
                              child: const Text(
                                'Create account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  fontFamily: 'Arial',
                                  color: _linkShade,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.blackCat,
        fontSize: 12,
        fontFamily: 'Arial',
      ),
      filled: true,
      fillColor: _snow,
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCatBorderLight),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _focusRing, width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _focusRing, width: 1),
      ),
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: _fieldVerticalPadding,
      ),
    );
  }
}

class _AccountDoc {
  const _AccountDoc({required this.collection, required this.data});

  final String collection;
  final Map<String, dynamic> data;
}

class _PostLoginBypassPage extends StatelessWidget {
  const _PostLoginBypassPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signed In')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You are signed in successfully.\n\n'
              'To prevent a known device crash, Firestore startup was temporarily skipped.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await SupabaseAuthService.logout();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
