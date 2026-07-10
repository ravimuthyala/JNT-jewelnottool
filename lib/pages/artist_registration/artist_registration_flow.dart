import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../../theme/app_colors.dart';
import '../../config/auth_flags.dart';
import '../../services/supabase_auth_service.dart';
import '../artist_login_page.dart';
import '../artist_shell_page.dart';
import '../email_verification_pending_page.dart';
import '../../widgets/jnt_modal_app_bar.dart';
import 'registration_draft.dart';
import '_widgets/reg_helpers.dart';
import 'step1_account.dart';
import 'step2_location.dart';
import 'step3_specialization.dart';
import 'step4_credentials.dart';
import '_widgets/step_progress_bar.dart';
import '_widgets/continue_button.dart';

class ArtistRegistrationFlow extends StatefulWidget {
  const ArtistRegistrationFlow({super.key});

  @override
  State<ArtistRegistrationFlow> createState() => _ArtistRegistrationFlowState();
}

class _ArtistRegistrationFlowState extends State<ArtistRegistrationFlow> {
  static const int _totalSteps = 4;

  static const _stepLabels = ['Account', 'Location', 'Services', 'Payments'];

  static const _stepSubtitles = [
    'Account Credentials & Artist Profile',
    'Location & Service Area',
    'Specialization, Calendar & Portfolio',
    'Credentials, Payment & Agreements',
  ];

  int _currentStep = 1;
  bool _submitting = false;
  final RegistrationDraft _draft = RegistrationDraft();

  final _step1Key = GlobalKey<Step1AccountState>();
  final _step2Key = GlobalKey<Step2LocationState>();
  final _step3Key = GlobalKey<Step3SpecializationState>();
  final _step4Key = GlobalKey<Step4CredentialsState>();

  void _onBack() {
    if (_currentStep == 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _currentStep--);
    }
  }

  void _onContinue() {
    switch (_currentStep) {
      case 1:
        if (_step1Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 2);

      case 2:
        if (_step2Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 3);

      case 3:
        if (_step3Key.currentState?.validateAndSave(_draft) != true) return;
        setState(() => _currentStep = 4);

      case 4:
        if (_step4Key.currentState?.validateAndSave(_draft) != true) return;
        _submit();
    }
  }

  void _autofillCurrentStep() {
    switch (_currentStep) {
      case 1: _step1Key.currentState?.autofill();
      case 2: _step2Key.currentState?.autofill();
      case 3: _step3Key.currentState?.autofill();
      case 4: _step4Key.currentState?.autofill();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final email = _draft.email.trim().toLowerCase();
      final password = _draft.password.trim();

      await SupabaseAuthService.logout();

      dynamic supabaseUser;
      try {
        supabaseUser = await SupabaseAuthService.signup(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 20));
      } on AuthException catch (e) {
        final message = e.message.toLowerCase();
        if (!message.contains('already')) rethrow;
        supabaseUser = await SupabaseAuthService.login(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 20));
      }

      final supabaseUid = (supabaseUser?.id ?? '').toString().trim();
      if (supabaseUid.isEmpty) {
        throw const AuthException(
          'Unable to create user. Check Supabase email confirmation settings.',
        );
      }

      final profilePhotoUrl = await _uploadProfileImage(supabaseUid);
      final portfolioImageUrls = await _uploadPortfolioImages(
        supabaseUid,
      ).timeout(const Duration(seconds: 35), onTimeout: () => <String>[]);

      final payload = _buildArtistPayload(
        supabaseUid: supabaseUid,
        email: email,
        profilePhotoUrl: profilePhotoUrl,
        portfolioImageUrls: portfolioImageUrls,
      );

      await Supabase.instance.client.from('artist').upsert(payload);

      if (!mounted) return;

      if (kRequireEmailVerification) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPendingPage(
              email: email,
              loginPageBuilder: (_) => const ArtistLoginPage(),
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ArtistShellPage()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final message = e.message.toLowerCase().contains('already')
          ? 'Email already registered. Please sign in.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Registration failed.' : message)),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request timed out. Please check network and try again.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed. ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Uint8List? _optimizeImageBytes(
    Uint8List source, {
    required int maxEdge,
    required int maxBytes,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;

    img.Image processed = decoded;
    final maxSide = processed.width > processed.height ? processed.width : processed.height;
    if (maxSide > maxEdge) {
      final scale = maxEdge / maxSide;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }

    for (var quality = 88; quality >= 60; quality -= 8) {
      final encoded = img.encodeJpg(processed, quality: quality);
      final bytes = Uint8List.fromList(encoded);
      if (bytes.lengthInBytes <= maxBytes) return bytes;
    }
    return Uint8List.fromList(img.encodeJpg(processed, quality: 58));
  }

  Future<String> _uploadProfileImage(String uid) async {
    final bytes = _draft.profileBytes;
    if (bytes == null || bytes.isEmpty) return '';

    final optimized = _optimizeImageBytes(bytes, maxEdge: 700, maxBytes: 2 * 1024 * 1024) ?? bytes;
    final path = 'artists/$uid/profile/avatar.jpg';

    try {
      final storage = Supabase.instance.client.storage.from('profile-pictures');
      await storage.uploadBinary(
        path,
        optimized,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return storage.getPublicUrl(path).trim();
    } catch (_) {
      return '';
    }
  }

  Future<List<String>> _uploadPortfolioImages(String uid) async {
    if (_draft.portfolioImages.isEmpty) return const <String>[];

    final storage = Supabase.instance.client.storage.from('portfolio-images');
    final now = DateTime.now().millisecondsSinceEpoch;
    final uploadedUrls = <String>[];

    for (var i = 0; i < _draft.portfolioImages.length; i++) {
      final optimized = _optimizeImageBytes(
        _draft.portfolioImages[i],
        maxEdge: 1600,
        maxBytes: 2 * 1024 * 1024,
      ) ?? _draft.portfolioImages[i];

      final path = 'artists/$uid/portfolio/${now}_${i + 1}.jpg';
      try {
        await storage.uploadBinary(
          path,
          optimized,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        final publicUrl = storage.getPublicUrl(path).trim();
        if (publicUrl.isNotEmpty) uploadedUrls.add(publicUrl);
      } catch (_) {}
    }

    return uploadedUrls;
  }

  Map<String, dynamic> _buildArtistPayload({
    required String supabaseUid,
    required String email,
    required String profilePhotoUrl,
    required List<String> portfolioImageUrls,
  }) {
    final portfolioItems = portfolioImageUrls
        .map((url) => <String, dynamic>{'imageUrl': url, 'style': 'All'})
        .toList(growable: false);

    final payout = <String, dynamic>{
      'method': _draft.payoutMethod.name,
      'legalName': _draft.legalName.trim(),
      'email': _draft.payoutEmail.trim(),
      'bankName': _draft.bankName.trim(),
      'routing': _draft.routing.trim(),
      'accountNumber': _draft.accountNumber.trim(),
      'applePayName': _draft.applePayName.trim(),
      'applePayPhone': _draft.applePayPhone.trim(),
      'applePayEmail': _draft.applePayEmail.trim(),
      'applePay': {
        'enabled': _draft.payoutMethod == PayoutMethod.applePay,
        'fullName': _draft.applePayName.trim(),
        'email': _draft.applePayEmail.trim(),
        'phone': _draft.applePayPhone.trim(),
      },
      'paypal': {
        'enabled': _draft.payoutMethod == PayoutMethod.paypal,
        'email': _draft.payoutMethod == PayoutMethod.paypal ? _draft.payoutEmail.trim() : '',
      },
      'ach': {
        'enabled': _draft.payoutMethod == PayoutMethod.bankTransfer,
        'accountHolder': _draft.legalName.trim(),
        'bankName': _draft.bankName.trim(),
        'routingNumber': _draft.routing.trim(),
        'accountNumber': _draft.accountNumber.trim(),
      },
      'venmo': {
        'enabled': _draft.payoutMethod == PayoutMethod.venmo,
        'username': _draft.payoutMethod == PayoutMethod.venmo ? _draft.payoutEmail.trim() : '',
      },
    };

    final fullPhone = '${_draft.phoneAreaCode.trim()}${_draft.phone.trim()}';
    final nameOrStudio = _draft.displayName.trim().isNotEmpty
        ? _draft.displayName.trim()
        : _draft.studioName.trim();
    final resolvedState = _draft.state ?? _draft.manualState.trim();
    final photo = profilePhotoUrl.trim();

    // NOTE: public.artist has accumulated multiple casing variants of the same
    // logical column (e.g. avatarUrl / avatar_url / avatarurl) from past ad-hoc
    // migrations. PostgREST rejects the *entire* upsert if any top-level key
    // doesn't match a real column, so every key below is verified against the
    // live schema (see `information_schema.columns` for public.artist) — do not
    // add a key here without confirming the column exists.
    return {
      'id': supabaseUid,
      'email': email,
      'account_type': 'artist',
      'roles': {'client': false, 'artist': true, 'company': false},
      'updated_at': DateTime.now().toIso8601String(),

      // Core identity — populate every existing casing variant for compatibility.
      'name': nameOrStudio,
      'nameOrStudio': nameOrStudio,
      'displayName': _draft.displayName.trim(),
      'displayname': _draft.displayName.trim(),
      'fullName': nameOrStudio,
      'studioName': _draft.studioName.trim(),
      'studioname': _draft.studioName.trim(),
      'bio': _draft.bio.trim(),
      'city': _draft.city.trim(),
      'state': resolvedState,
      'country': _draft.country.trim(),
      'instagram': _draft.instagram.trim(),
      'tiktok': _draft.tiktok.trim(),
      'currency': _draft.currency.trim(),
      'language_spoken': _draft.languageSpoken.trim(),
      'avatarUrl': photo,
      'avatar_url': photo,
      'avatarurl': photo,
      'photoUrl': photo,
      'photo_url': photo,
      'photourl': photo,
      'profileImageUrl': photo,
      'profileimageurl': photo,
      'profilePhotoUrl': photo,

      // Panel-friendly columns (consumed by artist dashboard/admin views) — snake_case matches the real schema.
      'panel_studio_name': _draft.studioName.trim(),
      'panel_display_name': _draft.displayName.trim(),
      'panel_displayName': _draft.displayName.trim(),
      'panel_fullName': nameOrStudio,
      'panel_nameOrStudio': nameOrStudio,
      'panel_name': nameOrStudio,
      'panel_email': email,
      'panel_language_spoken': _draft.languageSpoken.trim(),
      'panel_currency': _draft.currency.trim(),
      'panel_phone': fullPhone,
      'panel_phone_area_code': _draft.phoneAreaCode.trim(),
      'panel_phone_local': _draft.phone.trim(),
      'panel_bio': _draft.bio.trim(),
      'panel_instagram': _draft.instagram.trim(),
      'panel_tiktok': _draft.tiktok.trim(),
      'panel_time_zone': _draft.timeZone,
      'panel_city': _draft.city.trim(),
      'panel_state': resolvedState,
      'panel_country': _draft.country.trim(),
      'panel_address_line1': _draft.addressLine1.trim(),
      'panel_address_city': _draft.addressCity.trim(),
      'panel_address_line2': _draft.addressLine2.trim(),
      'panel_zip': _draft.zip.trim(),
      'panel_is_shipping_address_same': true,
      'panel_shipping_address_line1': _draft.addressLine1.trim(),
      'panel_shipping_address_line2': _draft.addressLine2.trim(),
      'panel_shipping_city': _draft.addressCity.trim(),
      'panel_shipping_state': resolvedState,
      'panel_shipping_zip': _draft.zip.trim(),
      'panel_shipping_country': _draft.country.trim(),
      'panel_shipping_time_zone': _draft.timeZone,
      'panel_nail_tech_type': _draft.nailTechType.name,
      'panel_services': _draft.services.toList(),
      'panel_min_price': _draft.minPrice.trim(),
      'panel_max_price': _draft.maxPrice.trim(),
      'panel_rush_available': _draft.rush,
      'panel_direct_requests_enabled': _draft.directRequestsEnabled,
      'panel_direct_request_year': _draft.directRequestYear,
      'panel_blocked_dates': _draft.blockedDates.map((d) => d.toIso8601String()).toList(),
      'panel_project_notes': _draft.projectNotes.trim(),
      'panel_portfolio_image_count': portfolioImageUrls.length,
      'panel_portfolio_images': portfolioImageUrls,
      'panel_artist_portfolio_images': portfolioImageUrls,
      'panel_license_number': _draft.licenseNumber.trim(),
      'panel_jurisdiction': (_draft.jurisdiction ?? '').trim(),
      'panel_pro_years_experience': (_draft.proYearsExp ?? '').trim(),
      'panel_school': _draft.school.trim(),
      'panel_practice_duration': (_draft.practiceDuration ?? '').trim(),
      'panel_selected_bundle': _draft.selectedBundle,
      'panel_bundle_purchased': _draft.bundlePurchased,
      'panel_bundle_payment_saved': _draft.paymentSaved,
      'panel_bundle_payment_method': _draft.paymentMethod,
      'panel_bundle_paypal_email': _draft.paypalEmail.trim(),
      'panel_bundle_venmo_handle': _draft.venmoHandle.trim(),
      'panel_payout': payout,
      'panel_payout_method': _draft.payoutMethod.name,
      'panel_payout_legal_name': _draft.legalName.trim(),
      'panel_payout_email': _draft.payoutEmail.trim(),
      'panel_profile_image_url': photo,
      'panel_profileImageUrl': photo,
      'panel_agree_terms': _draft.agreeTerms,
      'panel_no_copyright': _draft.noCopyright,
      'panel_agree_safety': _draft.agreeSafety,
      'panel_receive_updates': _draft.receiveUpdates,

      'profile': {
        'studioName': _draft.studioName.trim(),
        'displayName': _draft.displayName.trim(),
        'languageSpoken': _draft.languageSpoken.trim(),
        'currency': _draft.currency.trim(),
        'photoUrl': profilePhotoUrl.trim(),
        'avatarUrl': profilePhotoUrl.trim(),
        'profileImageUrl': profilePhotoUrl.trim(),
        'profilePhotoUrl': profilePhotoUrl.trim(),
        'name': _draft.displayName.trim().isNotEmpty ? _draft.displayName.trim() : _draft.studioName.trim(),
        'fullName': _draft.displayName.trim().isNotEmpty ? _draft.displayName.trim() : _draft.studioName.trim(),
        'phone': fullPhone,
        'phoneAreaCode': _draft.phoneAreaCode.trim(),
        'phoneLocal': _draft.phone.trim(),
        'bio': _draft.bio.trim(),
        'instagram': _draft.instagram.trim(),
        'tiktok': _draft.tiktok.trim(),
        'timeZone': _draft.timeZone,
        'city': _draft.city.trim(),
        'state': _draft.state ?? _draft.manualState.trim(),
        'country': _draft.country.trim(),
        'addressLine1': _draft.addressLine1.trim(),
        'addressCity': _draft.addressCity.trim(),
        'addressLine2': _draft.addressLine2.trim(),
        'zip': _draft.zip.trim(),
        'nailTechType': _draft.nailTechType.name,
      },

      'services': _draft.services.toList(),
      'pricing': {
        'minPrice': _draft.minPrice.trim(),
        'maxPrice': _draft.maxPrice.trim(),
        'rushAvailable': _draft.rush,
      },
      'availability': {
        'directRequestsEnabled': _draft.directRequestsEnabled,
        'blockedDates': _draft.blockedDates.map((d) => d.toIso8601String()).toList(),
        'directRequestYear': _draft.directRequestYear,
      },
      'portfolio': {
        'projectNotes': _draft.projectNotes.trim(),
        'imageCount': portfolioImageUrls.length,
        'images': portfolioImageUrls,
        'items': portfolioItems,
      },
      'portfolio_images': portfolioImageUrls,
      'portfolio_items': portfolioItems,
      'credentials': {
        'licenseNumber': _draft.licenseNumber.trim(),
        'jurisdiction': (_draft.jurisdiction ?? '').trim(),
        'proYearsExperience': (_draft.proYearsExp ?? '').trim(),
        'school': _draft.school.trim(),
        'practiceDuration': (_draft.practiceDuration ?? '').trim(),
      },
      'bundle': {
        'selected': _draft.selectedBundle,
        'purchased': _draft.bundlePurchased,
        'paymentSaved': _draft.paymentSaved,
        'paymentMethod': _draft.paymentMethod,
        'paymentDetails': {
          'paypalEmail': _draft.paypalEmail.trim(),
          'venmoHandle': _draft.venmoHandle.trim(),
          'applePayName': _draft.applePayPaymentName.trim(),
          'applePayPhone': _draft.applePayPaymentPhone.trim(),
          'applePayEmail': _draft.applePayPaymentEmail.trim(),
          'cardName': _draft.cardName.trim(),
          'cardNumber': _draft.cardNumber.trim(),
          'cardExpiry': _draft.cardExpiry.trim(),
          'cardCvv': _draft.cardCvv.trim(),
          'cardZip': _draft.cardZip.trim(),
        },
      },
      'payout': payout,
      'agreements': {
        'agreeTerms': _draft.agreeTerms,
        'noCopyright': _draft.noCopyright,
        'agreeSafety': _draft.agreeSafety,
        'receiveUpdates': _draft.receiveUpdates,
      },
    };
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return Step1Account(key: _step1Key, draft: _draft);
      case 2:
        return Step2Location(key: _step2Key, draft: _draft);
      case 3:
        return Step3Specialization(key: _step3Key, draft: _draft);
      case 4:
        return Step4Credentials(key: _step4Key, draft: _draft);
      default:
        return const Center(child: Text('Coming soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntModalAppBar(
        onClose: () => Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/register', (route) => false),
        closeTooltip: 'Close artist registration',
        closeIcon: const Icon(Icons.close),
        leadingWidth: 60,
        leading: Tooltip(
          message: 'Fill dummy data',
          child: IconButton(
            icon: const Icon(Icons.auto_fix_high),
            iconSize: 20,
            color: AppColors.blackCat,
            onPressed: _autofillCurrentStep,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.blackCat,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              shape: const RoundedRectangleBorder(),
            ),
          ),
        ),
      ),
      body: ColoredBox(
        color: AppColors.snow,
        child: SafeArea(
          child: Column(
            children: [
            // ── Progress bar ───────────────────────────────────────────────
            StepProgressBar(
              current: _currentStep,
              total: _totalSteps,
              stepLabels: _stepLabels,
              sectionSubtitle: _stepSubtitles[_currentStep - 1],
            ),

            // ── Step content ───────────────────────────────────────────────
            Expanded(child: _buildCurrentStep()),

            // ── Bottom action row ──────────────────────────────────────────
            Container(
              color: AppColors.snow,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep > 1) ...[
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _onBack,
                        style: regSecondaryButtonStyle().copyWith(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Arial',
                                fontSize: 12,
                                color: AppColors.snow,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ContinueButton(
                    onTap: _onContinue,
                    loading: _submitting,
                    embedded: true,
                    label: _currentStep == _totalSteps
                        ? 'Create My Account'
                        : 'Continue',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
