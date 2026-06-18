// lib/pages/client_artist_registration_page.dart
import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/address_validation_service.dart';
import '../services/supabase_auth_service.dart';
import '../config/auth_flags.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';
import '../constants/currency_options.dart';
import '../widgets/registration_profile_upload.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';

import '../widgets/nail_preferences_inline_editor.dart';
import '../models/client_profile_models.dart';
//import 'artist_checkout_page.dart';
// ---- Artist-side widgets/pages (already used in your ArtistRegistrationPage) ----
import '../widgets/direct_request_year_calendar.dart';
import 'email_verification_pending_page.dart';
import 'home_page.dart';
import 'client_artist_home_page.dart';
import 'artist_checkout_page_modal_edit.dart';

class ClientArtistRegistrationPage extends StatefulWidget {
  const ClientArtistRegistrationPage({
    super.key,
    this.showAdaCompliance = false,
  });

  final bool showAdaCompliance;

  @override
  State<ClientArtistRegistrationPage> createState() =>
      _ClientArtistRegistrationPageState();
}

enum PayoutMethod { paypal, venmo, bankTransfer, applePay }

enum NailTechType { professional, student }

class _ClientArtistRegistrationPageState
    extends State<ClientArtistRegistrationPage> {
  static const int _maxPortfolioImageBytes = 2 * 1024 * 1024;
  static const int _maxPortfolioImages = 10;
  final _formKey = GlobalKey<FormState>();
  Timer? _streetAutocompleteDebounce;
  List<AddressSuggestion> _streetSuggestions = const [];
  bool _streetSuggestionsLoading = false;

  // TEMP: allow registration even if checkout isn't complete.
  // Flip to false when checkout is enforced.
  static const bool kAllowRegistrationWithoutCheckout = false;

  bool _submitting = false;

  // -----------------------
  // Font sizes (match your existing pages)
  // -----------------------
  static const double _titleFs = 14.5; // section title
  static const double _subFs = 14.5; // section subtitle / helper text
  static const double _labelFs = 14; // input label
  static const double _hintFs = 13.5; // input hint
  static const double _inputFs = 14; // typed text
  static const double _chipFs = 12; // chip text
  static const double _smallFs = 13.5; // tiny helper lines
  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 14;
  static const Color _snow = AppColors.snow;
  static const Color _blackCat = AppColors.blackCat;

  // -----------------------
  // Profile image (tap avatar to upload)
  // -----------------------
  final ImagePicker _picker = ImagePicker();
  Uint8List? _profileBytes;

  // -----------------------
  // Shared Account Credentials (no duplicates)
  // -----------------------
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController(); // needed for Artist
  final _phoneCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // -----------------------
  // Shared Basic Profile (no duplicates)
  // -----------------------
  final _fullNameOrStudioCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController(); // needed for Artist
  final _languageSpokenCtrl = TextEditingController();
  String? _currency = 'US Dollar (\$)';
  final _bioCtrl = TextEditingController();

  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();

  // -----------------------
  // Address / Location (merged, no duplicates)
  // -----------------------
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _manualStateCtrl = TextEditingController();

  String? _state;
  String _selectedCountry = 'United States';
  String _phoneAreaCode = '+1';
  static final List<Map<String, String>> _phonePickerCountries = codes
      .where(
        (c) =>
            (c['code'] ?? '').isNotEmpty && (c['dial_code'] ?? '').isNotEmpty,
      )
      .map(
        (c) => <String, String>{
          'name': (c['code'] ?? '').toUpperCase(),
          'code': (c['code'] ?? '').toUpperCase(),
          'dial_code': c['dial_code'] ?? '',
        },
      )
      .toList(growable: false);
  bool get _isUnitedStates => _selectedCountry == 'United States';
  String get _resolvedState =>
      _isUnitedStates ? (_state ?? '').trim() : _manualStateCtrl.text.trim();
  String get _normalizedAreaCode =>
      RegistrationInputUtils.normalizeAreaCode(_phoneAreaCode);
  String get _normalizedPhone =>
      RegistrationInputUtils.normalizePhone(_phoneCtrl.text);
  String get _fullPhone => '$_normalizedAreaCode$_normalizedPhone';
  String _timeZone = 'America/New_York';

  // -----------------------
  // âœ… Checkout/cart state (ONLY changes are here + gating)
  // -----------------------
  bool _bundleInCart = false;
  String? _bundleCartKey; // 'Starter'/'Pro'/'Studio'/'Elite'

  // paid states (used to gate Continue)
  final bool _kitPaid = false;
  bool _bundlePaid = false;

  static const List<String> usStates = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
  ];

  static const List<String> countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Antigua and Barbuda',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Chile',
    'China',
    'Colombia',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czechia',
    'Denmark',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Estonia',
    'Ethiopia',
    'Finland',
    'France',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Guatemala',
    'Haiti',
    'Honduras',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lithuania',
    'Luxembourg',
    'Malaysia',
    'Maldives',
    'Malta',
    'Mexico',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Morocco',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Nigeria',
    'Norway',
    'Oman',
    'Pakistan',
    'Panama',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'South Africa',
    'South Korea',
    'Spain',
    'Sri Lanka',
    'Sweden',
    'Switzerland',
    'Thailand',
    'Tunisia',
    'Turkey',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Venezuela',
    'Vietnam',
    'Zambia',
    'Zimbabwe',
  ];

  // -----------------------
  // Client-specific (kept as-is)
  // -----------------------
  final bool _kitPurchased =
      false; // scenario 2 (kept, but now driven by _kitPaid)
  final bool _hasSizingKitAlready = false; // scenario 1
  var _nailPrefs = NailPreferences.empty();

  PaymentInfo _payment = const PaymentInfo(
    method: PaymentMethod.applePay,
    saveForFuture: true,
  );

  // -----------------------
  // Artist-specific (kept as-is)
  // -----------------------
  final Set<String> _services = {'Custom Press-ons', 'Nail Art'};
  final _minPriceCtrl = TextEditingController(text: '15');
  final _maxPriceCtrl = TextEditingController(text: '5000');
  bool _rush = false;

  bool _directRequestsEnabled = true;
  bool _showYearCalendar = false;
  int _yearCalendarNonce = 0;
  int _directRequestYear = DateTime.now().year;
  final Set<DateTime> _blockedDates = <DateTime>{};

  final List<Uint8List> _portfolioImages = [];
  String? _lastPortfolioUploadErrorDetail;
  final _projectNotesCtrl = TextEditingController();
  final _portfolioLinkCtrl = TextEditingController();

  NailTechType _nailTechType = NailTechType.professional;
  final _licenseCtrl = TextEditingController();
  String? _jurisdiction; // dropdown (use usStates)
  String? _proYearsExp; // dropdown
  bool _proYearsDropdownOpen = false;

  final _schoolCtrl = TextEditingController();
  String? _practiceDuration; // dropdown
  bool _practiceDurationDropdownOpen = false;

  static const List<String> practiceDurations = [
    '< 3 months',
    '3â€“6 months',
    '6â€“12 months',
    '1â€“2 years',
    '2+ years',
  ];

  static const List<String> proYearsOptions = [
    '0 - 1 years (Beginner)',
    '1 - 3 years (Intermediate)',
    '3 - 5 years (Skilled)',
    '5 - 10 years (Advanced)',
    '10+ years (Expert)',
  ];

  // -----------------------
  // Artist payment/bundle/payout gates (kept)
  // -----------------------
  String _paymentMethod = 'PayPal';

  final _paypalEmailCtrl = TextEditingController();
  final _venmoHandleCtrl = TextEditingController();
  final _applePayPaymentNameCtrl = TextEditingController();
  final _applePayPaymentPhoneCtrl = TextEditingController();
  final _applePayPaymentEmailCtrl = TextEditingController();

  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();
  final _cardZipCtrl = TextEditingController();

  bool _paymentSaved = false;

  String _selectedBundle = 'Starter';
  bool _bundlePurchased = false;

  PayoutMethod _payoutMethod = PayoutMethod.paypal;

  final _legalNameCtrl = TextEditingController();
  final _payoutEmailCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _routingCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  final _applePayNameCtrl = TextEditingController();
  final _applePayPhoneCtrl = TextEditingController();
  final _applePayEmailCtrl = TextEditingController();

  bool _agreeTerms = false;
  bool _noCopyright = false;
  bool _agreeSafety = false;
  bool _receiveUpdates = true;

  bool _isDigits(String v) => RegExp(r'^\d+$').hasMatch(v);
  bool _isValidEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);

  PaymentInfo _currentPaymentInfo() {
    if (_paymentMethod == 'PayPal') {
      return PaymentInfo(
        method: PaymentMethod.paypal,
        saveForFuture: true,
        paypalEmail: _paypalEmailCtrl.text.trim(),
      );
    }

    if (_paymentMethod == 'Venmo') {
      return PaymentInfo(
        method: PaymentMethod.venmo,
        saveForFuture: true,
        venmoHandle: _venmoHandleCtrl.text.trim(),
      );
    }

    if (_paymentMethod == 'Credit Card') {
      return PaymentInfo(
        method: PaymentMethod.card,
        saveForFuture: true,
        cardNumber: _cardNumberCtrl.text.trim(),
        nameOnCard: _cardNameCtrl.text.trim(),
        expiryMMYY: _cardExpiryCtrl.text.trim(),
        cvv: _cardCvvCtrl.text.trim(),
        zip: _cardZipCtrl.text.trim(),
      );
    }

    return PaymentInfo(
      method: PaymentMethod.applePay,
      saveForFuture: true,
      nameOnCard: _applePayPaymentNameCtrl.text.trim(),
      cardNumber: _applePayPaymentPhoneCtrl.text.trim(),
      paypalEmail: _applePayPaymentEmailCtrl.text.trim(),
    );
  }

  String _savedPaymentDetailForCheckout() {
    if (!_paymentSaved) return '';

    if (_paymentMethod == 'PayPal') {
      return _paypalEmailCtrl.text.trim();
    }

    if (_paymentMethod == 'Venmo') {
      return _venmoHandleCtrl.text.trim();
    }

    if (_paymentMethod == 'Apple Pay') {
      final email = _applePayPaymentEmailCtrl.text.trim();
      final phone = _applePayPaymentPhoneCtrl.text.trim();
      if (email.isNotEmpty && phone.isNotEmpty) return '$email • $phone';
      return email.isNotEmpty ? email : phone;
    }

    final digits = _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '';
    return last4.isEmpty ? 'Credit Card' : 'Card ending in $last4';
  }

  String _bundleTitle(String bundleKey) {
    switch (bundleKey) {
      case 'Pro':
        return 'Pro Material Bundle';
      case 'Elite':
        return 'Elite Bundle';
      case 'Starter':
      default:
        return 'Starter Material Bundle';
    }
  }

  String _bundleSubtitle(String bundleKey) {
    switch (bundleKey) {
      case 'Pro':
        return 'Gel, tools & tips.';
      case 'Elite':
        return 'For high volume artists.';
      case 'Starter':
      default:
        return 'Perfect for new artists.';
    }
  }

  String _bundlePrice(String bundleKey) {
    switch (bundleKey) {
      case 'Pro':
        return '\$100';
      case 'Elite':
        return '\$150';
      case 'Starter':
      default:
        return '\$50';
    }
  }

  String _bundleImageAsset(String bundleKey) {
    switch (bundleKey) {
      case 'Pro':
        return 'assets/images/nail_bundle_100.png';
      case 'Elite':
        return 'assets/images/nail_bundle_150.png';
      case 'Starter':
      default:
        return 'assets/images/nail_bundle_50.png';
    }
  }

  bool _paymentFieldsValid() {
    if (_paymentMethod == 'PayPal') {
      final v = _paypalEmailCtrl.text.trim();
      return v.isNotEmpty && _isValidEmail(v);
    }

    if (_paymentMethod == 'Venmo') {
      final v = _venmoHandleCtrl.text.trim();
      return v.isNotEmpty;
    }

    if (_paymentMethod == 'Apple Pay') {
      final name = _applePayPaymentNameCtrl.text.trim();
      final phone = _applePayPaymentPhoneCtrl.text.trim().replaceAll(
        RegExp(r'\D'),
        '',
      );
      final email = _applePayPaymentEmailCtrl.text.trim();
      return name.isNotEmpty && phone.length >= 10 && _isValidEmail(email);
    }

    if (_paymentMethod == 'Credit Card') {
      final name = _cardNameCtrl.text.trim();
      final number = _cardNumberCtrl.text.trim().replaceAll(' ', '');
      final expiry = _cardExpiryCtrl.text.trim();
      final cvv = _cardCvvCtrl.text.trim();
      final zip = _cardZipCtrl.text.trim();

      final expiryOk = RegExp(r'^\d{2}\/\d{2}$').hasMatch(expiry);
      final numberOk =
          _isDigits(number) && number.length >= 13 && number.length <= 19;
      final cvvOk = _isDigits(cvv) && (cvv.length == 3 || cvv.length == 4);
      final zipOk = zip.isNotEmpty;

      return name.isNotEmpty && numberOk && expiryOk && cvvOk && zipOk;
    }

    return false;
  }

  bool get _canStartCheckout =>
      _paymentSaved &&
      (!widget.showAdaCompliance ||
          (_agreeTerms && _noCopyright && _agreeSafety));

  // âœ… checkout requirements for gating continue
  Uint8List? _optimizePortfolioBytes(
    Uint8List source, {
    int maxEdge = 1600,
    int maxBytes = _maxPortfolioImageBytes,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;

    img.Image processed = decoded;
    final maxSide = processed.width > processed.height
        ? processed.width
        : processed.height;
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

    final fallback = img.copyResize(
      processed,
      width: processed.width > processed.height ? 1200 : null,
      height: processed.height >= processed.width ? 1200 : null,
      interpolation: img.Interpolation.average,
    );
    final encoded = img.encodeJpg(fallback, quality: 58);
    return Uint8List.fromList(encoded);
  }

  Future<List<String>> _uploadPortfolioImages(String uid) async {
    if (_portfolioImages.isEmpty) return const <String>[];

    _lastPortfolioUploadErrorDetail = null;

    final storage = Supabase.instance.client.storage.from('portfolio-images');
    final now = DateTime.now().millisecondsSinceEpoch;
    final uploaded = <String>[];

    for (var i = 0; i < _portfolioImages.length; i++) {
      Uint8List bytes = _portfolioImages[i];

      final optimized = _optimizePortfolioBytes(bytes);
      if (optimized != null && optimized.isNotEmpty) {
        bytes = optimized;
      }

      if (bytes.lengthInBytes > _maxPortfolioImageBytes) {
        final aggressive = _optimizePortfolioBytes(
          bytes,
          maxEdge: 900,
          maxBytes: 200 * 1024,
        );
        if (aggressive != null && aggressive.isNotEmpty) {
          bytes = aggressive;
        }
      }

      try {
        final path = 'client_artists/$uid/portfolio/${now}_${i + 1}.jpg';

        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

        final publicUrl = storage.getPublicUrl(path).trim();

        debugPrint('CLIENT ARTIST PORTFOLIO URL = $publicUrl');

        if (publicUrl.isNotEmpty) {
          uploaded.add(publicUrl);
        }
      } catch (e) {
        _lastPortfolioUploadErrorDetail ??= e.toString();
        debugPrint('CLIENT ARTIST PORTFOLIO UPLOAD FAILED: $e');
      }
    }

    return uploaded;
  }

  Future<String> _uploadProfileImage(String uid) async {
    final bytes = _profileBytes;
    if (bytes == null || bytes.isEmpty) return '';

    final optimized = _optimizePortfolioBytes(
          bytes,
          maxEdge: 900,
          maxBytes: 650 * 1024,
        ) ??
        bytes;

    final path = 'client_artists/$uid/profile/avatar.jpg';

    try {
      final storage = Supabase.instance.client.storage.from('profile-pictures');

      await storage.uploadBinary(
        path,
        optimized,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = storage.getPublicUrl(path).trim();

      debugPrint('CLIENT ARTIST PROFILE URL = $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('CLIENT ARTIST PROFILE UPLOAD FAILED: $e');
      return '';
    }
  }

  Map<String, dynamic> _normalizedArtistPayout() {
    final isPaypal = _payoutMethod == PayoutMethod.paypal;
    final isVenmo = _payoutMethod == PayoutMethod.venmo;
    final isBank = _payoutMethod == PayoutMethod.bankTransfer;
    final isApplePay = _payoutMethod == PayoutMethod.applePay;
    return <String, dynamic>{
      'method': _payoutMethod.name,
      'legalName': _legalNameCtrl.text.trim(),
      'email': _payoutEmailCtrl.text.trim(),
      'bankName': _bankNameCtrl.text.trim(),
      'routing': _routingCtrl.text.trim(),
      'accountNumber': _accountNumberCtrl.text.trim(),
      'applePayName': _applePayNameCtrl.text.trim(),
      'applePayPhone': _applePayPhoneCtrl.text.trim(),
      'applePayEmail': _applePayEmailCtrl.text.trim(),
      'applePay': {
        'enabled': isApplePay,
        'fullName': _applePayNameCtrl.text.trim(),
        'email': _applePayEmailCtrl.text.trim(),
        'phone': _applePayPhoneCtrl.text.trim(),
      },
      'paypal': {
        'enabled': isPaypal,
        'email': isPaypal ? _payoutEmailCtrl.text.trim() : '',
      },
      'ach': {
        'enabled': isBank,
        'accountHolder': _legalNameCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'routingNumber': _routingCtrl.text.trim(),
        'accountNumber': _accountNumberCtrl.text.trim(),
      },
      'venmo': {
        'enabled': isVenmo,
        'username': isVenmo ? _payoutEmailCtrl.text.trim() : '',
      },
    };
  }

  Map<String, dynamic> _buildCombinedFirestorePayload({
    required String uid,
    String profilePhotoUrl = '',
    List<String> portfolioImageUrls = const <String>[],
  }) {
    final dimensions = _nailPrefs.dimensions;
    final artistServices = _services.toList();
    final blockedDates = _blockedDates.map((d) => d.toIso8601String()).toList();
    final payout = _normalizedArtistPayout();

    return {
      'uid': uid,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'accountType': 'client+artist',
      'roles': {'client': true, 'artist': true, 'company': false},
      // Panel-friendly top-level columns
      'panel_nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
      'panel_displayName': _displayNameCtrl.text.trim(),
      'panel_languageSpoken': _languageSpokenCtrl.text.trim(),
      'panel_currency': (_currency ?? '').trim(),
      'panel_phone': _fullPhone,
      'panel_phoneAreaCode': _normalizedAreaCode,
      'panel_phoneLocal': _normalizedPhone,
      'panel_bio': _bioCtrl.text.trim(),
      'panel_instagram': _instagramCtrl.text.trim(),
      'panel_tiktok': _tiktokCtrl.text.trim(),
      'panel_timeZone': _timeZone,
      'panel_street': _streetCtrl.text.trim(),
      'panel_city': _cityCtrl.text.trim(),
      'panel_state': _resolvedState,
      'panel_zip': _zipCtrl.text.trim(),
      'panel_country': _selectedCountry.trim(),
      'panel_client_hasSizingKitAlready': _hasSizingKitAlready,
      'panel_client_kitPurchased': _kitPurchased,
      'panel_client_paymentMethod': _payment.method.name,
      'panel_client_paymentSaveForFuture': _payment.saveForFuture,
      'panel_client_nailShape': _nailPrefs.shape,
      'panel_client_nailLength': _nailPrefs.length.name,
      'panel_artist_services': artistServices,
      'panel_artist_minPrice': _minPriceCtrl.text.trim(),
      'panel_artist_maxPrice': _maxPriceCtrl.text.trim(),
      'panel_artist_rushAvailable': _rush,
      'panel_artist_directRequestsEnabled': _directRequestsEnabled,
      'panel_artist_directRequestYear': _directRequestYear,
      'panel_artist_blockedDates': blockedDates,
      'panel_portfolioImages': portfolioImageUrls,
      'panel_artist_portfolioImages': portfolioImageUrls,
      'panel_artist_nailTechType': _nailTechType.name,
      'panel_artist_selectedBundle': _selectedBundle,
      'panel_artist_bundlePurchased': _bundlePurchased,
      'panel_artist_paymentSaved': _paymentSaved,
      'panel_artist_paymentMethod': _paymentMethod,
      'panel_payout': payout,
      'panel_artist_payoutMethod': _payoutMethod.name,
      'panel_artist_payoutLegalName': _legalNameCtrl.text.trim(),
      'panel_artist_payoutEmail': _payoutEmailCtrl.text.trim(),
      'panel_profileImageUrl': profilePhotoUrl.trim(),
      'panel_agreeTerms': _agreeTerms,
      'panel_noCopyright': _noCopyright,
      'panel_agreeSafety': _agreeSafety,
      'panel_registration_kitPaid': _kitPaid,
      'panel_registration_bundlePaid': _bundlePaid,
      'photoUrl': profilePhotoUrl.trim(),
      'avatarUrl': profilePhotoUrl.trim(),
      'payment': {
        'method': _payment.method.name,
        'saveForFuture': _payment.saveForFuture,
        'cardNumber': _payment.cardNumber.trim(),
        'nameOnCard': _payment.nameOnCard.trim(),
        'expiryMMYY': _payment.expiryMMYY.trim(),
        'cvv': _payment.cvv.trim(),
        'zip': _payment.zip.trim(),
        'venmoHandle': _payment.venmoHandle.trim(),
        'paypalEmail': _payment.paypalEmail.trim(),
      },
      'nailPreferences': {
        'shape': _nailPrefs.shape,
        'length': _nailPrefs.length.name,
        'dimensions': {
          'lThumb': dimensions.lThumb,
          'lIndex': dimensions.lIndex,
          'lMiddle': dimensions.lMiddle,
          'lRing': dimensions.lRing,
          'lPinky': dimensions.lPinky,
          'rThumb': dimensions.rThumb,
          'rIndex': dimensions.rIndex,
          'rMiddle': dimensions.rMiddle,
          'rRing': dimensions.rRing,
          'rPinky': dimensions.rPinky,
        },
      },
      'profile': {
        'name': _displayNameCtrl.text.trim().isNotEmpty
            ? _displayNameCtrl.text.trim()
            : _fullNameOrStudioCtrl.text.trim(),
        'nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
        'displayName': _displayNameCtrl.text.trim(),
        'languageSpoken': _languageSpokenCtrl.text.trim(),
        'currency': (_currency ?? '').trim(),
        'photoUrl': profilePhotoUrl.trim(),
        'avatarUrl': profilePhotoUrl.trim(),
        'profileImageUrl': profilePhotoUrl.trim(),
        'profilePhotoUrl': profilePhotoUrl.trim(),
        'phone': _fullPhone,
        'phoneAreaCode': _normalizedAreaCode,
        'phoneLocal': _normalizedPhone,
        'bio': _bioCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'tiktok': _tiktokCtrl.text.trim(),
        'timeZone': _timeZone,
      },
      'address': {
        'street': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _resolvedState,
        'zip': _zipCtrl.text.trim(),
        'country': _selectedCountry.trim(),
      },
      'languageSpoken': _languageSpokenCtrl.text.trim(),
      'currency': (_currency ?? '').trim(),
      'client': {
        'hasSizingKitAlready': _hasSizingKitAlready,
        'kitPurchased': _kitPurchased,
        'payment': {
          'method': _payment.method.name,
          'saveForFuture': _payment.saveForFuture,
          // NOTE: storing raw payment data is not recommended for production.
          'cardNumber': _payment.cardNumber.trim(),
          'nameOnCard': _payment.nameOnCard.trim(),
          'expiryMMYY': _payment.expiryMMYY.trim(),
          'cvv': _payment.cvv.trim(),
          'zip': _payment.zip.trim(),
          'venmoHandle': _payment.venmoHandle.trim(),
          'paypalEmail': _payment.paypalEmail.trim(),
        },
        'nailPreferences': {
          'shape': _nailPrefs.shape,
          'length': _nailPrefs.length.name,
          'dimensions': {
            'lThumb': dimensions.lThumb,
            'lIndex': dimensions.lIndex,
            'lMiddle': dimensions.lMiddle,
            'lRing': dimensions.lRing,
            'lPinky': dimensions.lPinky,
            'rThumb': dimensions.rThumb,
            'rIndex': dimensions.rIndex,
            'rMiddle': dimensions.rMiddle,
            'rRing': dimensions.rRing,
            'rPinky': dimensions.rPinky,
          },
        },
      },
      'artist': {
        'photoUrl': profilePhotoUrl.trim(),
        'avatarUrl': profilePhotoUrl.trim(),
        'services': _services.toList(),
        'pricing': {
          'minPrice': _minPriceCtrl.text.trim(),
          'maxPrice': _maxPriceCtrl.text.trim(),
          'rushAvailable': _rush,
        },
        'availability': {
          'directRequestsEnabled': _directRequestsEnabled,
          'blockedDates': _blockedDates
              .map((d) => d.toIso8601String())
              .toList(),
          'directRequestYear': _directRequestYear,
        },
        'portfolio': {
          'projectNotes': _projectNotesCtrl.text.trim(),
          'portfolioLink': _portfolioLinkCtrl.text.trim(),
          'imageCount': portfolioImageUrls.length,
          'images': portfolioImageUrls,
          'items': portfolioImageUrls
              .map((url) => <String, dynamic>{'imageUrl': url, 'style': 'All'})
              .toList(growable: false),
        },
        'credentials': {
          'nailTechType': _nailTechType.name,
          'licenseNumber': _licenseCtrl.text.trim(),
          'jurisdiction': (_jurisdiction ?? '').trim(),
          'proYearsExperience': (_proYearsExp ?? '').trim(),
          'school': _schoolCtrl.text.trim(),
          'practiceDuration': (_practiceDuration ?? '').trim(),
        },
        'bundle': {
          'selected': _selectedBundle,
          'purchased': _bundlePurchased,
          'paymentSaved': _paymentSaved,
          'paymentMethod': _paymentMethod,
          'paymentDetails': {
            'paypalEmail': _paypalEmailCtrl.text.trim(),
            'venmoHandle': _venmoHandleCtrl.text.trim(),
            'applePayName': _applePayPaymentNameCtrl.text.trim(),
            'applePayPhone': _applePayPaymentPhoneCtrl.text.trim(),
            'applePayEmail': _applePayPaymentEmailCtrl.text.trim(),
            'cardName': _cardNameCtrl.text.trim(),
            'cardNumber': _cardNumberCtrl.text.trim(),
            'cardExpiry': _cardExpiryCtrl.text.trim(),
            'cardCvv': _cardCvvCtrl.text.trim(),
            'cardZip': _cardZipCtrl.text.trim(),
          },
        },
        'payout': payout,
        'agreements': {
          'agreeTerms': _agreeTerms,
          'noCopyright': _noCopyright,
          'agreeSafety': _agreeSafety,
          'receiveUpdates': _receiveUpdates,
        },
      },
      'registration': {
        'bypassCheckoutUsed': kAllowRegistrationWithoutCheckout,
        'kitPaid': _kitPaid,
        'bundlePaid': _bundlePaid,
      },
      'portfolioImages': portfolioImageUrls,
      'portfolioItems': portfolioImageUrls
          .map((url) => <String, dynamic>{'imageUrl': url, 'style': 'All'})
          .toList(growable: false),
      'payout': payout,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  ClientProfileDraft _buildClientProfileDraft({String profilePhotoUrl = ''}) {
    return ClientProfileDraft(
      basic: BasicInfo(
        name: _displayNameCtrl.text.trim().isNotEmpty
            ? _displayNameCtrl.text.trim()
            : _fullNameOrStudioCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        phone: _fullPhone,
        profileImageUrl: profilePhotoUrl.trim(),
      ),
      address: AddressInfo(
        street: _streetCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _resolvedState,
        zip: _zipCtrl.text.trim(),
        country: _selectedCountry.trim(),
      ),
      payment: _payment,
      nail: _nailPrefs,
    );
  }

  // -----------------------
  // Decorations / Validators
  // -----------------------
  InputDecoration _dec(String label, String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: _hintFs - 0.5,
        color: _blackCat.withValues(alpha: 0.45),
        fontFamily: 'Arial',
      ),
      labelStyle: TextStyle(
        fontSize: _labelFs,
        color: _blackCat.withValues(alpha: 0.75),
        fontFamily: 'Arial',
      ),
      errorStyle: const TextStyle(
        fontSize: 10.5,
        height: 1.05,
        fontFamily: 'Arial',
      ),
      filled: true,
      fillColor: _snow,
      suffixIcon: suffixIcon,
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: _fieldVerticalPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: _blackCat, width: 1.4),
      ),
    );
  }

  Widget _countryCodeDropdown({
    required String value,
    required ValueChanged<CountryCode> onChanged,
    bool embedded = false,
  }) {
    return Localizations.override(
      context: context,
      locale: const Locale('en'),
      child: Container(
        height: _fieldHeight,
        decoration: BoxDecoration(
          color: _snow,
          borderRadius: BorderRadius.zero,
          border: embedded
              ? null
              : Border.all(color: AppColors.blackCatBorderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CountryCodePicker(
          onChanged: onChanged,
          initialSelection: value == '+1' ? 'US' : value,
          favorite: const ['US', '+1', '+44', '+91'],
          countryList: _phonePickerCountries,
          showFlag: false,
          showFlagMain: false,
          showFlagDialog: true,
          showCountryOnly: true,
          hideMainText: true,
          alignLeft: true,
          flagWidth: 20,
          padding: EdgeInsets.zero,
          builder: (code) {
            final flagUri = code?.flagUri;
            final countryAbbr = (code?.code ?? 'US').toUpperCase();
            return Row(
              children: [
                if (flagUri != null)
                  Image.asset(
                    flagUri,
                    package: 'country_code_picker',
                    width: 20,
                    height: 14,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(width: 8),
                Text(
                  countryAbbr,
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: _inputFs,
                    color: Colors.black,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _requiredValidator(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _firstExactMatch(List<String> options, String input) {
    final needle = input.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final option in options) {
      if (option.trim().toLowerCase() == needle) return option;
    }
    return null;
  }

  Widget _snowPopupDropdown<T>({
    required String label,
    required String hint,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    final menuHeight = AutocompleteDropdownSizing.menuHeight(
      itemCount: items.length,
      itemExtent: 40,
    );
    return PopupMenuButton<T>(
      color: _snow,
      surfaceTintColor: _snow,
      elevation: 4,
      offset: const Offset(0, _fieldHeight + 6),
      constraints: BoxConstraints(maxHeight: menuHeight),
      onSelected: onChanged,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(
                  fontSize: _inputFs,
                  color: _blackCat,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(growable: false),
      child: InputDecorator(
        decoration: _dec(label, hint),
        child: Row(
          children: [
            Expanded(
              child: Text(
                itemLabel(value),
                style: const TextStyle(
                  fontSize: _inputFs,
                  color: _blackCat,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _blackCat),
          ],
        ),
      ),
    );
  }

  Widget _inlineSnowDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required bool isOpen,
    required VoidCallback onToggle,
    String? Function(T?)? validator,
  }) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        final selected = field.value;
        final hasValue = selected != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.zero,
              onTap: onToggle,
              child: InputDecorator(
                decoration: _dec(label, hint),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? itemLabel(selected as T) : hint,
                        style: TextStyle(
                          fontSize: _inputFs,
                          color: hasValue
                              ? _blackCat
                              : _blackCat.withValues(alpha: 0.45),
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: _blackCat,
                    ),
                  ],
                ),
              ),
            ),
            if (isOpen)
              Builder(
                builder: (context) {
                  final itemCount = items.length;
                  final menuHeight = AutocompleteDropdownSizing.menuHeight(
                    itemCount: itemCount,
                    itemExtent: 48,
                  );
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: _snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.blackCatBorderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blackCat.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(maxHeight: menuHeight),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                        itemCount,
                      ),
                      physics: AutocompleteDropdownSizing.scrollPhysics(
                        itemCount,
                      ),
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: _blackCat.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selectedItem = selected == item;
                        return InkWell(
                          onTap: () {
                            field.didChange(item);
                            onChanged(item);
                            onToggle();
                          },
                          child: Container(
                            color: selectedItem
                                ? _blackCat.withValues(alpha: 0.10)
                                : _snow,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Text(
                              itemLabel(item),
                              style: const TextStyle(
                                fontSize: _inputFs,
                                color: _blackCat,
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText ?? '',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.red,
                  fontFamily: 'Arial',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _typeAheadPicker({
    required String label,
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      initialValue: selectedValue,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: field.value ?? ''),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<String>.empty();
                return options.where(
                  (option) => option.toLowerCase().contains(query),
                );
              },
              onSelected: (value) {
                field.didChange(value);
                onChanged(value);
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: _inputFs,
                        color: _blackCat,
                        fontFamily: 'Arial',
                      ),
                      decoration: _dec(label, hint),
                      onTapOutside: (_) => focusNode.unfocus(),
                      onChanged: (value) {
                        final match = _firstExactMatch(options, value);
                        field.didChange(match);
                        onChanged(match);
                      },
                    );
                  },
              optionsViewBuilder: (context, onSelected, optionsList) {
                final maxW = MediaQuery.of(context).size.width - 48;
                final optionCount = optionsList.length;
                final menuHeight = AutocompleteDropdownSizing.menuHeight(
                  itemCount: optionCount,
                  itemExtent: 40,
                );
                return TextFieldTapRegion(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: _snow,
                      elevation: 4,
                      borderRadius: BorderRadius.zero,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: menuHeight,
                          maxWidth: maxW < 260 ? 260 : maxW,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                            optionCount,
                          ),
                          physics: AutocompleteDropdownSizing.scrollPhysics(
                            optionCount,
                          ),
                          itemCount: optionCount,
                          itemBuilder: (context, index) {
                            final option = optionsList.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: _inputFs,
                                  color: _blackCat,
                                  fontFamily: 'Arial',
                                ),
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText ?? '',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.red,
                  fontFamily: 'Arial',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String? _emailValidator(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Email is required';
    if (!RegistrationInputUtils.isValidEmail(t)) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    final t = (v ?? '');
    if (t.isEmpty) return 'Password is required';
    if (!RegistrationInputUtils.isStrongPassword(t)) {
      return 'Use 8+ chars with upper, lower, number, and symbol';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? v) {
    final t = (v ?? '');
    if (t.isEmpty) return 'Confirm your password';
    if (t != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  String? _phoneValidator(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Phone is required';
    if (RegistrationInputUtils.normalizePhone(t).length != 10) {
      return 'Enter exactly 10 digits';
    }
    return null;
  }

  // -----------------------
  // UI helpers
  // -----------------------
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    LinearGradient? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? _snow : null,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: _blackCat.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Arial',
              fontSize: _titleFs,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: _subFs,
              color: _blackCat.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _bundleCard({
    required String title,
    required String subtitle,
    required String price,
    required String imageAsset,
    required bool selected,
    required bool purchased,
    required bool disableAdd,
    required VoidCallback onTap,
    required VoidCallback onAdd,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? _blackCat.withValues(alpha: 0.55)
                : _blackCat.withValues(alpha: 0.24),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _snow,
                  borderRadius: BorderRadius.zero,
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => Text(
                      'Image',
                      style: TextStyle(
                        color: _blackCat.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: _titleFs,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: _subFs,
                color: _blackCat.withValues(alpha: 0.68),
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFFF06C7A),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: purchased
                      ? _blackCat.withValues(alpha: 0.85)
                      : _blackCat,
                  foregroundColor: _snow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: disableAdd ? null : onAdd,
                child: Text(
                  purchased ? 'Purchased' : 'Add to cart',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: _inputFs,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String text, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _blackCat.withValues(alpha: 0.10) : _snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? _blackCat.withValues(alpha: 0.75)
                : _blackCat.withValues(alpha: 0.24),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Arial',
            fontSize: _chipFs,
            fontWeight: FontWeight.w600,
            color: selected ? _blackCat : _blackCat.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }

  Widget _techTypeToggle() {
    Widget option({required NailTechType type, required String label}) {
      final selected = _nailTechType == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => setState(() => _nailTechType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: selected
                    ? _blackCat.withValues(alpha: 0.55)
                    : _blackCat.withValues(alpha: 0.22),
                width: selected ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: _inputFs - 2,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: _blackCat.withValues(alpha: 0.9),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I am:',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: _inputFs,
            fontFamily: 'Arial',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            option(
              type: NailTechType.professional,
              label: 'Professional Nail Technician',
            ),
            const SizedBox(width: 12),
            option(
              type: NailTechType.student,
              label: 'Student / Unlicensed Nail Tech',
            ),
          ],
        ),
      ],
    );
  }

  Widget _techTypeFields() {
    if (_nailTechType == NailTechType.professional) {
      return Column(
        children: [
          TextFormField(
            controller: _licenseCtrl,
            style: const TextStyle(fontSize: _inputFs),
            decoration: _dec('License # *', 'Enter license number'),
            validator: (v) {
              if (_nailTechType != NailTechType.professional) return null;
              if (v == null || v.trim().isEmpty) return 'License # is required';
              return null;
            },
          ),
          const SizedBox(height: 6),
          _typeAheadPicker(
            label: 'Juridisction *',
            hint: 'Select state',
            options: usStates,
            selectedValue: _jurisdiction,
            onChanged: (v) => setState(() => _jurisdiction = v),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Jurisdiction is required' : null,
          ),
          const SizedBox(height: 6),
          _inlineSnowDropdown<String>(
            label: 'Years of Experience *',
            hint: 'Select years of experience',
            value: _proYearsExp,
            items: proYearsOptions,
            itemLabel: (v) => v,
            isOpen: _proYearsDropdownOpen,
            onToggle: () => setState(() {
              _proYearsDropdownOpen = !_proYearsDropdownOpen;
              _practiceDurationDropdownOpen = false;
            }),
            onChanged: (v) => setState(() => _proYearsExp = v),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Years of experience is required'
                : null,
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: _schoolCtrl,
          style: const TextStyle(fontSize: _inputFs),
          decoration: _dec('School / Program *', 'School / Program'),
          validator: (v) => _requiredValidator(v, 'School / Program'),
        ),
        const SizedBox(height: 6),
        _inlineSnowDropdown<String>(
          label: 'Practice Duration *',
          hint: 'Select duration',
          value: _practiceDuration,
          items: practiceDurations,
          itemLabel: (v) => v,
          isOpen: _practiceDurationDropdownOpen,
          onToggle: () => setState(() {
            _practiceDurationDropdownOpen = !_practiceDurationDropdownOpen;
            _proYearsDropdownOpen = false;
          }),
          onChanged: (v) => setState(() => _practiceDuration = v),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Practice duration is required' : null,
        ),
      ],
    );
  }

  Widget _profilePicTile() {
    return RegistrationProfileUpload(
      onTap: _pickProfilePhoto,
      imageBytes: _profileBytes,
      label: 'Profile picture',
      helperText: _profileBytes == null
          ? 'Tap to upload your profile photo'
          : 'Profile photo selected',
    );
  }

  // -----------------------
  // Image pickers
  // -----------------------
  Future<void> _pickProfilePhoto() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() => _profileBytes = bytes);
  }

  Future<void> _pickPortfolioImages() async {
    final remainingSlots = _maxPortfolioImages - _portfolioImages.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 inspiration photos.'),
        ),
      );
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    final selectedFiles = files.take(remainingSlots).toList(growable: false);
    final bytesList = <Uint8List>[];
    for (final file in selectedFiles) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        bytesList.add(bytes);
      }
    }

    if (!mounted || bytesList.isEmpty) return;
    setState(() => _portfolioImages.addAll(bytesList));

    if (files.length > remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only 10 inspiration photos are allowed. Extra photos were not added.',
          ),
        ),
      );
    }
  }

  // -----------------------
  // âœ… Checkout process (UPDATED to support kit + bundle at same time)
  // -----------------------
  Future<void> _addBundleToCart(String bundleKey) async {
    if (_bundlePurchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bundle already purchased âœ…')),
      );
      return;
    }

    setState(() {
      _bundleInCart = true;
      _bundleCartKey = bundleKey;
    });
    final completed = await _openBundleCheckout(bundleKey);
    if (!completed && mounted) {
      setState(() => _bundleInCart = false);
    }
  }

  Future<bool> _openBundleCheckout(String bundleKey) async {
    if (_formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields first')),
      );
      return false;
    }

    if (!_paymentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please save your payment method before adding a bundle.',
          ),
        ),
      );
      return false;
    }

    final checkoutInfo = ArtistCheckoutInfo(
      artistName: _fullNameOrStudioCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      phone: _fullPhone,
      city: _cityCtrl.text.trim(),
      state: _resolvedState,
      timeZone: _timeZone,
      addressLine1: _streetCtrl.text.trim(),
      addressLine2: '',
      zip: _zipCtrl.text.trim(),
      country: _selectedCountry.trim(),
      isShippingAddressSame: true,
      shippingAddressLine1: _streetCtrl.text.trim(),
      shippingAddressLine2: '',
      shippingCity: _cityCtrl.text.trim(),
      shippingState: _resolvedState,
      shippingZip: _zipCtrl.text.trim(),
      shippingCountry: _selectedCountry.trim(),
      shippingTimeZone: _timeZone,
      paymentMethod: _paymentMethod,
      paymentDetail: _savedPaymentDetailForCheckout(),
      productTitle: _bundleTitle(bundleKey),
      productSubtitle: _bundleSubtitle(bundleKey),
      productPriceText: _bundlePrice(bundleKey),
      productImageAsset: _bundleImageAsset(bundleKey),
    );

    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistCheckoutPage(initial: checkoutInfo),
      ),
    );

    if (result != true) return false;

    setState(() {
      _bundlePaid = true;
      _bundlePurchased = true;
      _bundleInCart = false;
      _selectedBundle = bundleKey;
      _bundleCartKey = bundleKey;
      _payment = _currentPaymentInfo();
    });

    if (!mounted) return false;
    return true;
  }

  Future<void> _autofillAddressFromStreet() async {
    _streetAutocompleteDebounce?.cancel();
    final query = _streetCtrl.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _streetSuggestionsLoading = false;
        _streetSuggestions = const [];
      });
      return;
    }

    setState(() => _streetSuggestionsLoading = true);
    _streetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _streetSuggestionsLoading = false;
          _streetSuggestions = results;
        });
      },
    );
  }

  void _applyStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _streetCtrl.text = selected.street;
      _cityCtrl.text = selected.city;
      _zipCtrl.text = selected.zip;
      _selectedCountry = 'United States';
      final resolved =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      final matched = usStates.where((s) => s == resolved).toList();
      _state = matched.isNotEmpty ? matched.first : null;
      _manualStateCtrl.clear();
      _streetSuggestions = const [];
    });
  }

  // -----------------------
  // Submit
  // -----------------------
  Future<void> _continue() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_instagramCtrl.text.trim().isEmpty && _tiktokCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide at least one social media detail: Instagram or TikTok.',
          ),
        ),
      );
      return;
    }
    if (_isUnitedStates) {
      final addressValidation =
          await AddressValidationService.validateUsAddress(
            street: _streetCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            state: _resolvedState,
            zip: _zipCtrl.text.trim(),
          );
      if (!addressValidation.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              addressValidation.message ?? 'Invalid U.S. mailing address.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;

    if (!kAllowRegistrationWithoutCheckout) {
      if (!_canStartCheckout) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please complete payment setup and required agreements to continue.',
            ),
          ),
        );
        return;
      }

      if (!_bundlePurchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please purchase a bundle to continue.'),
          ),
        );
        return;
      }
    } else {
      if (widget.showAdaCompliance &&
          !(_agreeTerms && _noCopyright && _agreeSafety)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the required agreements.'),
          ),
        );
        return;
      }
    }

    if (_submitting) return;
    setState(() => _submitting = true);

    Future<void> rollbackCreatedUserIfNeeded() async {
      // Supabase user deletion must be handled server-side/admin-side.
      // For Phase 3, we avoid deleting the auth user from the app if profile saving fails.
    }

    try {
      await SupabaseAuthService.logout();
      final supabaseUser = await SupabaseAuthService.signup(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text.trim(),
      );

      if (supabaseUser == null) {
        throw Exception('Unable to create user.');
      }

      final uid = supabaseUser.id;
      // Disabled during Supabase Phase 4 because this helper still writes to Firebase/Firestore.
      // Recreate this mapping in Supabase if the app still needs login email aliases.
      // await AuthEmailAliasService.saveAliasMapping(
      //   loginEmail: _emailCtrl.text,
      //   authEmail: supabaseUser.email ?? _emailCtrl.text.trim().toLowerCase(),
      //   uid: uid,
      // );

      final profilePhotoUrl = await _uploadProfileImage(uid);
      debugPrint('CLIENT ARTIST FINAL PROFILE URL = $profilePhotoUrl');

      final portfolioImageUrls = await _uploadPortfolioImages(uid);
      debugPrint('CLIENT ARTIST FINAL PORTFOLIO URLS = $portfolioImageUrls');

      final payload = _buildCombinedFirestorePayload(
        uid: uid,
        profilePhotoUrl: profilePhotoUrl.trim(),
        portfolioImageUrls: portfolioImageUrls,
      );
      final draft = _buildClientProfileDraft(profilePhotoUrl: profilePhotoUrl);
      try {
        final supabase = Supabase.instance.client;

        await supabase.from('client').upsert({
          'id': uid,
          'email': _emailCtrl.text.trim().toLowerCase(),
          'account_type': 'client_artist',

          'profile': payload['profile'],
          'basic': {
            'name': _displayNameCtrl.text.trim().isNotEmpty
                ? _displayNameCtrl.text.trim()
                : _fullNameOrStudioCtrl.text.trim(),
            'email': _emailCtrl.text.trim().toLowerCase(),
            'phone': _fullPhone,
            'profileImageUrl': profilePhotoUrl.trim(),
          },
          'address': payload['address'],
          'payment': payload['payment'],
          'nail_preferences': payload['nailPreferences'],
          'registration': payload['registration'],

          'updated_at': DateTime.now().toIso8601String(),
        });

        await supabase.from('artist').upsert({
          'id': uid,
          'email': _emailCtrl.text.trim().toLowerCase(),
          'account_type': 'client_artist',
          'displayName': _displayNameCtrl.text.trim(),
          'studioName': _fullNameOrStudioCtrl.text.trim(),
          'name': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _fullNameOrStudioCtrl.text.trim(),
          'nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
          'fullName': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _fullNameOrStudioCtrl.text.trim(),
          'profileImageUrl': profilePhotoUrl.trim(),
          'profilePhotoUrl': profilePhotoUrl.trim(),
          'photoUrl': profilePhotoUrl.trim(),
          'avatarUrl': profilePhotoUrl.trim(),
          'panel_displayName': _displayNameCtrl.text.trim(),
          'panel_nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
          'panel_profileImageUrl': profilePhotoUrl.trim(),

          'profile': payload['profile'],
          'services': payload['artist']['services'],
          'pricing': payload['artist']['pricing'],
          'availability': payload['artist']['availability'],
          'portfolio': payload['artist']['portfolio'],
          'credentials': payload['artist']['credentials'],
          'bundle': payload['artist']['bundle'],
          'payout': payload['artist']['payout'],
          'agreements': payload['artist']['agreements'],

          'updated_at': DateTime.now().toIso8601String(),
        });

        await supabase.from('client_artist').upsert({
          'id': uid,
          'email': _emailCtrl.text.trim().toLowerCase(),
          'account_type': 'client_artist',
          'displayName': _displayNameCtrl.text.trim(),
          'studioName': _fullNameOrStudioCtrl.text.trim(),
          'name': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _fullNameOrStudioCtrl.text.trim(),
          'nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
          'fullName': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _fullNameOrStudioCtrl.text.trim(),
          'profileImageUrl': profilePhotoUrl.trim(),
          'profilePhotoUrl': profilePhotoUrl.trim(),
          'photoUrl': profilePhotoUrl.trim(),
          'avatarUrl': profilePhotoUrl.trim(),
          'panel_displayName': _displayNameCtrl.text.trim(),
          'panel_nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
          'panel_profileImageUrl': profilePhotoUrl.trim(),

          'profile': payload['profile'],
          'address': payload['address'],
          'payment': payload['payment'],
          'nail_preferences': payload['nailPreferences'],

          'artist_profile': payload['artist'],
          'services': payload['artist']['services'],
          'pricing': payload['artist']['pricing'],
          'availability': payload['artist']['availability'],
          'portfolio': payload['artist']['portfolio'],
          'credentials': payload['artist']['credentials'],
          'bundle': payload['artist']['bundle'],
          'payout': payload['artist']['payout'],
          'agreements': payload['artist']['agreements'],
          'registration': payload['registration'],

          'updated_at': DateTime.now().toIso8601String(),
        });

      } catch (e, st) {
        debugPrint('CLIENT ARTIST SUPABASE SAVE ERROR');
        debugPrint(e.toString());
        debugPrint(st.toString());

        await rollbackCreatedUserIfNeeded();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supabase error: $e')),
        );
        return;
      }

      if (!mounted) return;

      // Supabase handles email verification from your Supabase Auth settings.
      if (!mounted) return;
      if (kRequireEmailVerification) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPendingPage(
              email: _emailCtrl.text.trim().toLowerCase(),
              loginPageBuilder: (_) => const HomePage(),
            ),
          ),
          (_) => false,
        );
      } else {
        final hasSizingKitAlready =
            payload['panel_client_hasSizingKitAlready'] == true ||
            ((payload['client']
                    as Map<String, dynamic>?)?['hasSizingKitAlready'] ==
                true);
        final kitPurchased =
            payload['panel_client_kitPurchased'] == true ||
            payload['panel_registration_kitPaid'] == true ||
            ((payload['client'] as Map<String, dynamic>?)?['kitPurchased'] ==
                true);
        final bundlePurchased =
            payload['panel_registration_bundlePaid'] == true ||
            payload['panel_artist_bundlePurchased'] == true ||
            (((payload['artist'] as Map<String, dynamic>?)?['bundle']
                    as Map<String, dynamic>?)?['purchased'] ==
                true);
        final enableAllTabs =
            draft.isComplete &&
            (hasSizingKitAlready || kitPurchased || bundlePurchased);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ClientArtistHomePage(
              profile: draft,
              showContinueProfileCard: !draft.isComplete,
              enableAllTabs: enableAllTabs,
            ),
          ),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      await rollbackCreatedUserIfNeeded();
      if (!mounted) return;
      final message = e.message.toLowerCase().contains('already')
          ? 'Email already registered. Please sign in.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e, st) {
      debugPrint('CLIENT_ARTIST_REGISTRATION_ERROR');
      debugPrint(e.toString());
      debugPrint(st.toString());

      await rollbackCreatedUserIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _streetAutocompleteDebounce?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();

    _fullNameOrStudioCtrl.dispose();
    _displayNameCtrl.dispose();
    _languageSpokenCtrl.dispose();
    _bioCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();

    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    _manualStateCtrl.dispose();

    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _projectNotesCtrl.dispose();
    _portfolioLinkCtrl.dispose();

    _licenseCtrl.dispose();
    _schoolCtrl.dispose();

    _paypalEmailCtrl.dispose();
    _venmoHandleCtrl.dispose();
    _applePayPaymentNameCtrl.dispose();
    _applePayPaymentPhoneCtrl.dispose();
    _applePayPaymentEmailCtrl.dispose();

    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardZipCtrl.dispose();

    _legalNameCtrl.dispose();
    _payoutEmailCtrl.dispose();
    _bankNameCtrl.dispose();
    _routingCtrl.dispose();
    _accountNumberCtrl.dispose();

    _applePayNameCtrl.dispose();
    _applePayPhoneCtrl.dispose();
    _applePayEmailCtrl.dispose();

    super.dispose();
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final dropdownTextColor = _blackCat;
    final dropdownBackground = _snow;

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: dropdownBackground,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Arial',
          bodyColor: dropdownTextColor,
          displayColor: dropdownTextColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Image.asset(
            'assets/images/jnt_logo_black.png',
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamedAndRemoveUntil('/register', (route) => false),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                // -----------------------
                // 1) Basic Profile (merged)
                // -----------------------
                _sectionCard(
                  title: 'Basic Profile',
                  subtitle: 'Enter your profile details.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profilePicTile(),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Full Name / Studio Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameOrStudioCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('Name', 'Enter Name'),
                        validator: (v) => _requiredValidator(v, 'Name'),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Display Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _displayNameCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('Display Name', 'Enter Display Name'),
                        validator: (v) => _requiredValidator(v, 'Display Name'),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Language Spoken'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _languageSpokenCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Language Spoken',
                          'Enter language(s) spoken',
                        ),
                        validator: (v) =>
                            _requiredValidator(v, 'Language Spoken'),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Currency'),
                      const SizedBox(height: 6),
                      _typeAheadPicker(
                        label: 'Currency',
                        hint: 'Select Currency',
                        options: currencyOptions,
                        selectedValue: _currency,
                        onChanged: (v) => setState(() => _currency = v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Currency is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.normal('Bio'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bioCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        maxLines: 3,
                        decoration: _dec('Bio', 'Tell us about you'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 2) Account Credentials (shared)
                // -----------------------
                _sectionCard(
                  title: 'Account Credentials',
                  subtitle: 'Enter your details.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel.required('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('Email', 'Enter Email'),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        obscureText: _obscurePassword,
                        decoration: _dec(
                          'Password',
                          'Enter Password',
                          suffixIcon: IconButton(
                            iconSize: 18,
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Password must be 8+ characters and include uppercase, lowercase, number, and symbol.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Confirm Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        obscureText: _obscureConfirmPassword,
                        decoration: _dec(
                          'Confirm Password',
                          'Re-enter Password',
                          suffixIcon: IconButton(
                            iconSize: 18,
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: _confirmPasswordValidator,
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Phone'),
                      const SizedBox(height: 6),
                      FormField<String>(
                        validator: (value) => _phoneValidator(_phoneCtrl.text),
                        builder: (field) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: _fieldHeight,
                                decoration: BoxDecoration(
                                  color: AppColors.snow,
                                  borderRadius: BorderRadius.zero,
                                  border: Border.all(
                                    color: AppColors.blackCatBorderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 132,
                                      child: _countryCodeDropdown(
                                        value: _phoneAreaCode,
                                        embedded: true,
                                        onChanged: (code) => setState(
                                          () => _phoneAreaCode =
                                              code.dialCode ?? '+1',
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      color: AppColors.blackCatBorderLight,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneCtrl,
                                        style: const TextStyle(
                                          fontSize: _inputFs,
                                        ),
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                          UsPhoneTextInputFormatter(),
                                        ],
                                        onChanged: field.didChange,
                                        decoration: InputDecoration(
                                          hintText: 'Enter 10-digit phone',
                                          hintStyle: TextStyle(
                                            fontSize: _hintFs - 0.5,
                                            color: _blackCat.withValues(alpha: 0.45),
                                            fontFamily: 'Arial',
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: _fieldVerticalPadding,
                                              ),
                                          isDense: false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                ),
                              ),
                              if (field.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 4,
                                  ),
                                  child: Text(
                                    field.errorText!,
                                    style: const TextStyle(
                                      color: Color(0xFFB3261E),
                                      fontSize: 10.5,
                                      height: 1.1,
                                      fontFamily: 'Arial',
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 3) Address Information (merged)
                // -----------------------
                _sectionCard(
                  title: 'Address Information',
                  subtitle: 'Enter your Shipping Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel.required('Street Address'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _streetCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Street Address',
                          'Enter Street Address',
                        ),
                        onChanged: (_) => _autofillAddressFromStreet(),
                        validator: (v) =>
                            _requiredValidator(v, 'Street Address'),
                      ),
                      if (_streetSuggestionsLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_streetSuggestions.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final suggestionCount = _streetSuggestions.length;
                            final menuHeight =
                                AutocompleteDropdownSizing.menuHeight(
                                  itemCount: suggestionCount,
                                  itemExtent: 40,
                                );
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: _snow,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                  color: _blackCat.withValues(alpha: 0.20),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxHeight: menuHeight,
                              ),
                              child: ListView.separated(
                                shrinkWrap:
                                    AutocompleteDropdownSizing.shrinkWrap(
                                      suggestionCount,
                                    ),
                                physics:
                                    AutocompleteDropdownSizing.scrollPhysics(
                                      suggestionCount,
                                    ),
                                itemCount: suggestionCount,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) => ListTile(
                                  dense: true,
                                  title: Text(
                                    _streetSuggestions[i].displayLabel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _applyStreetSuggestion(
                                    _streetSuggestions[i],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('City'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cityCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('City', 'City'),
                        validator: (v) => _requiredValidator(v, 'City'),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isUnitedStates
                                    ? _FieldLabel.required('State')
                                    : _FieldLabel.normal('State / Region'),
                                const SizedBox(height: 6),
                                if (_isUnitedStates)
                                  _typeAheadPicker(
                                    label: 'State',
                                    hint: 'Select State',
                                    options: usStates,
                                    selectedValue: _state,
                                    onChanged: (v) =>
                                        setState(() => _state = v),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'State is required'
                                        : null,
                                  )
                                else
                                  TextFormField(
                                    controller: _manualStateCtrl,
                                    style: const TextStyle(fontSize: _inputFs),
                                    decoration: _dec(
                                      'State / Region',
                                      'Enter State / Region',
                                    ),
                                    validator: (_) => null,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isUnitedStates
                                    ? _FieldLabel.required('Zip Code')
                                    : _FieldLabel.normal('Zip Code'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _zipCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec(
                                    'Zip Code',
                                    'Enter Zip Code',
                                  ),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) {
                                      return _isUnitedStates
                                          ? 'Zip Code is required'
                                          : null;
                                    }
                                    if (!_isUnitedStates) return null;
                                    final ok = RegExp(
                                      r'^\d{5}(-\d{4})?$',
                                    ).hasMatch(value);
                                    if (!ok) return 'Enter a valid ZIP code';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Country'),
                      const SizedBox(height: 6),
                      _typeAheadPicker(
                        label: 'Country',
                        hint: 'Select Country',
                        options: countries,
                        selectedValue: _selectedCountry,
                        onChanged: (v) => setState(() {
                          if (v == null) return;
                          _selectedCountry = v;
                          if (_isUnitedStates) {
                            _manualStateCtrl.clear();
                          } else {
                            _state = null;
                          }
                        }),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Country is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel.required('Time Zone'),
                      const SizedBox(height: 6),
                      _snowPopupDropdown<String>(
                        label: 'Time Zone',
                        hint: 'Select Time Zone',
                        value: _timeZone,
                        items: const [
                          'America/New_York',
                          'America/Chicago',
                          'America/Denver',
                          'America/Los_Angeles',
                        ],
                        itemLabel: (v) => v,
                        onChanged: (v) =>
                            setState(() => _timeZone = v ?? 'America/New_York'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 4) Nail Preferences
                // -----------------------
                _sectionCard(
                  title: 'Nail Preferences',
                  subtitle: 'Your preferred nail shape and length.',
                  child: NailPreferencesInlineEditor(
                    initial: _nailPrefs,
                    showDimensionImages: false,
                    onChanged: (updated) =>
                        setState(() => _nailPrefs = updated),
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 5) Portfolio
                // -----------------------
                _sectionCard(
                  title: 'Portfolio',
                  subtitle:
                      'Upload inspiration photos. (${_portfolioImages.length}/$_maxPortfolioImages photo(s))',
                  gradient: const LinearGradient(colors: [_snow, _snow]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _techTypeToggle(),
                      const SizedBox(height: 6),
                      _techTypeFields(),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Upload inspiration photos',
                              style: TextStyle(
                                fontSize: _inputFs,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Allowed: JPG, JPEG, PNG, WEBP. Each file must be <2MB. Maximum 10 photos.',
                        style: TextStyle(
                          fontSize: _smallFs,
                          color: AppColors.blackCat.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_portfolioImages.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(_portfolioImages.clear),
                            child: const Text(
                              'Clear all',
                              style: TextStyle(
                                color: _blackCat,
                                fontSize: _inputFs,
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: _blackCat,
                              ),
                            ),
                          ),
                        ),
                      if (_portfolioImages.isNotEmpty)
                        const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ..._portfolioImages.map((b) {
                            return ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: Container(
                                width: 86,
                                height: 86,
                                color: _snow,
                                child: Image.memory(b, fit: BoxFit.cover),
                              ),
                            );
                          }),
                          if (_portfolioImages.length < _maxPortfolioImages)
                            InkWell(
                              onTap: _pickPortfolioImages,
                              borderRadius: BorderRadius.zero,
                              child: Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  color: _snow,
                                  borderRadius: BorderRadius.zero,
                                  border: Border.all(
                                    color: AppColors.blackCat.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: AppColors.blackCat.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Add',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_portfolioImages.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _snow,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppColors.blackCat.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: AppColors.blackCat.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'No previous art uploaded yet',
                                  style: TextStyle(
                                    fontSize: _inputFs,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _projectNotesCtrl,
                        decoration: _dec('Project Notes', 'Project notes'),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _instagramCtrl,
                        decoration: _dec(
                          'Instagram or TikTok (one required)',
                          'Instagram',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tiktokCtrl,
                        decoration: _dec('TikTok', 'TikTok'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 6) Year Calendar Availability
                // -----------------------
                _sectionCard(
                  title: 'Year Calendar Availability',
                  subtitle: 'Direct requests and blocked dates.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _directRequestsEnabled,
                        activeThumbColor: _blackCat,
                        activeTrackColor: _blackCat.withValues(alpha: 0.45),
                        inactiveThumbColor: _blackCat.withValues(alpha: 0.55),
                        inactiveTrackColor: _blackCat.withValues(alpha: 0.25),
                        onChanged: (v) =>
                            setState(() => _directRequestsEnabled = v),
                        title: const Text(
                          'Enable direct requests',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Allow clients to request specific dates.',
                          style: TextStyle(
                            fontSize: _smallFs,
                            color: AppColors.blackCat.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      InkWell(
                        onTap: () => setState(() {
                          _showYearCalendar = !_showYearCalendar;
                          if (_showYearCalendar) {
                            _yearCalendarNonce =
                                DateTime.now().millisecondsSinceEpoch;
                          }
                        }),
                        child: Row(
                          children: [
                            Icon(
                              _showYearCalendar
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.blackCat.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showYearCalendar
                                  ? 'Hide year calendar'
                                  : 'Show year calendar',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_showYearCalendar) ...[
                        const SizedBox(height: 6),
                        DirectRequestYearCalendar(
                          key: ValueKey(_yearCalendarNonce),
                          initialDirectRequestsOn: _directRequestsEnabled,
                          initialYear: _directRequestYear,
                          initialMonth: DateTime.now().month,
                          initialBlockedDays: _blockedDates,
                          showDirectRequestsFooter: false,
                          onChanged: (directRequestsOn, year, blockedDays) {
                            setState(() {
                              _directRequestsEnabled = directRequestsOn;
                              _directRequestYear = year;
                              _blockedDates
                                ..clear()
                                ..addAll(blockedDays);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 7) Specialization & Pricing
                // -----------------------
                _sectionCard(
                  title: 'Specialization & Pricing',
                  subtitle: 'Select services and set your range.',
                  gradient: const LinearGradient(colors: [_snow, _snow]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip(
                            'Intricate Nail Art',
                            selected: _services.contains('Intricate Nail Art'),
                            onTap: () => setState(() {
                              _services.contains('Intricate Nail Art')
                                  ? _services.remove('Intricate Nail Art')
                                  : _services.add('Intricate Nail Art');
                            }),
                          ),
                          _chip(
                            'Gel / Acrylic',
                            selected: _services.contains('Gel / Acrylic'),
                            onTap: () => setState(() {
                              _services.contains('Gel / Acrylic')
                                  ? _services.remove('Gel / Acrylic')
                                  : _services.add('Gel / Acrylic');
                            }),
                          ),
                          _chip(
                            '3D Nail Art',
                            selected: _services.contains('3D Nail Art'),
                            onTap: () => setState(() {
                              _services.contains('3D Nail Art')
                                  ? _services.remove('3D Nail Art')
                                  : _services.add('3D Nail Art');
                            }),
                          ),
                          _chip(
                            'Airbrush/Stamping',
                            selected: _services.contains('Airbrush/Stamping'),
                            onTap: () => setState(() {
                              _services.contains('Airbrush/Stamping')
                                  ? _services.remove('Airbrush/Stamping')
                                  : _services.add('Airbrush/Stamping');
                            }),
                          ),
                          _chip(
                            'Encapsulation',
                            selected: _services.contains('Encapsulation '),
                            onTap: () => setState(() {
                              _services.contains('Encapsulation ')
                                  ? _services.remove('Encapsulation ')
                                  : _services.add('Encapsulation ');
                            }),
                          ),
                          _chip(
                            'Dip Powder',
                            selected: _services.contains('Dip Powder'),
                            onTap: () => setState(() {
                              _services.contains('Dip Powder')
                                  ? _services.remove('Dip Powder')
                                  : _services.add('Dip Powder');
                            }),
                          ),
                          _chip(
                            'Sculptured',
                            selected: _services.contains('Sculptured'),
                            onTap: () => setState(() {
                              _services.contains('Sculptured')
                                  ? _services.remove('Sculptured')
                                  : _services.add('Sculptured');
                            }),
                          ),
                          _chip(
                            'PolyGel',
                            selected: _services.contains('PolyGel'),
                            onTap: () => setState(() {
                              _services.contains('PolyGel')
                                  ? _services.remove('PolyGel')
                                  : _services.add('PolyGel');
                            }),
                          ),
                          _chip(
                            'Chrome & Metallic',
                            selected: _services.contains('Chrome & Metallic'),
                            onTap: () => setState(() {
                              _services.contains('Chrome & Metallic')
                                  ? _services.remove('Chrome & Metallic')
                                  : _services.add('Chrome & Metallic');
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel.required('Min Price'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minPriceCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('Min Price (\$) *', '15'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel.required('Max Price'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _maxPriceCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('Max Price (\$) *', '5000'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rush availability',
                                  style: TextStyle(
                                    fontSize: _subFs,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enable if you can take expedited requests.',
                                  style: TextStyle(
                                    fontSize: _smallFs,
                                    color: AppColors.blackCat.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: _rush,
                              onChanged: (v) => setState(() => _rush = v),
                              activeThumbColor: _blackCat,
                              activeTrackColor: _blackCat.withValues(alpha: 0.45),
                              inactiveThumbColor: _blackCat.withValues(alpha: 0.55),
                              inactiveTrackColor: _blackCat.withValues(alpha: 0.25),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 8) Payment Method
                // -----------------------
                _sectionCard(
                  title: 'Payment Method',
                  subtitle: 'Select a method and save it (required).',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioTheme(
                        data: RadioThemeData(
                          fillColor: WidgetStateProperty.resolveWith(
                            (_) => _blackCat,
                          ),
                        ),
                        child: RadioGroup<String>(
                          groupValue: _paymentMethod,
                          onChanged: (value) => setState(() {
                            if (value == null) return;
                            _paymentMethod = value;
                            _paymentSaved = false;
                          }),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile<String>(
                                value: 'PayPal',
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'PayPal',
                                  style: TextStyle(
                                    fontSize: _inputFs,
                                    color: _blackCat,
                                    fontFamily: 'Arial',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_paymentMethod == 'PayPal') ...[
                                _FieldLabel.required('PayPal Email'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _paypalEmailCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec(
                                    'PayPal Email',
                                    'name@email.com',
                                  ),
                                  validator: (v) =>
                                      _bundlePurchased ? _emailValidator(v) : null,
                                ),
                                const SizedBox(height: 6),
                              ],
                              RadioListTile<String>(
                                value: 'Venmo',
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Venmo',
                                  style: TextStyle(
                                    fontSize: _inputFs,
                                    color: _blackCat,
                                    fontFamily: 'Arial',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_paymentMethod == 'Venmo') ...[
                                _FieldLabel.required('Venmo Handle'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _venmoHandleCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec(
                                    'Venmo',
                                    '@handle or phone/email',
                                  ),
                                  validator: (v) {
                                    if (!_bundlePurchased) return null;
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Venmo handle is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 6),
                              ],
                              RadioListTile<String>(
                                value: 'Apple Pay',
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Apple Pay',
                                  style: TextStyle(
                                    fontSize: _inputFs,
                                    color: _blackCat,
                                    fontFamily: 'Arial',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_paymentMethod == 'Apple Pay') ...[
                                _FieldLabel.required('Apple Pay Name'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _applePayPaymentNameCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec('Name', 'Name on Apple Pay'),
                                  validator: (v) => !_bundlePurchased
                                      ? null
                                      : _requiredValidator(v, 'Apple Pay Name'),
                                ),
                                const SizedBox(height: 6),
                                _FieldLabel.required('Apple Pay Phone'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _applePayPaymentPhoneCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                    UsPhoneTextInputFormatter(),
                                  ],
                                  decoration: _dec('Phone', 'Phone'),
                                  validator: (v) =>
                                      !_bundlePurchased ? null : _phoneValidator(v),
                                ),
                                const SizedBox(height: 6),
                                _FieldLabel.required('Apple Pay Email'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _applePayPaymentEmailCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec('Email', 'Email'),
                                  validator: (v) =>
                                      !_bundlePurchased ? null : _emailValidator(v),
                                ),
                                const SizedBox(height: 6),
                              ],
                              RadioListTile<String>(
                                value: 'Credit Card',
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Credit Card',
                                  style: TextStyle(
                                    fontSize: _inputFs,
                                    color: _blackCat,
                                    fontFamily: 'Arial',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_paymentMethod == 'Credit Card') ...[
                                _FieldLabel.required('Card Name'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cardNameCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec('Name', 'Name on card'),
                                  validator: (v) => !_bundlePurchased
                                      ? null
                                      : _requiredValidator(v, 'Card Name'),
                                ),
                                const SizedBox(height: 6),
                                _FieldLabel.required('Card Number'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cardNumberCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(19),
                                    CardNumberTextInputFormatter(),
                                  ],
                                  decoration: _dec(
                                    'Number',
                                    '1234 5678 9012 3456',
                                  ),
                                  validator: (v) => !_bundlePurchased
                                      ? null
                                      : _requiredValidator(v, 'Card Number'),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FieldLabel.required('Expiration Date'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _cardExpiryCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(4),
                                              ExpiryDateTextInputFormatter(),
                                            ],
                                            decoration: _dec(
                                              'Expiration Date',
                                              'MM/YY',
                                            ),
                                            validator: (v) => !_bundlePurchased
                                                ? null
                                                : _requiredValidator(
                                                    v,
                                                    'Expiration Date',
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FieldLabel.required('CVV'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _cardCvvCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(4),
                                            ],
                                            decoration: _dec('CVV', '123'),
                                            validator: (v) => !_bundlePurchased
                                                ? null
                                                : _requiredValidator(v, 'CVV'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _FieldLabel.required('Billing Zip'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cardZipCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('Zip', 'Zip'),
                                  validator: (v) => !_bundlePurchased
                                      ? null
                                      : _requiredValidator(v, 'Billing Zip'),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blackCat,
                            foregroundColor: _snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: () {
                            final ok = _paymentFieldsValid();
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fill required payment fields.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _paymentSaved = true;
                              _payment = _currentPaymentInfo();
                            });
                          },
                          child: const Text(
                            'Save Payment Method',
                            style: TextStyle(
                              fontSize: _inputFs,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.blackCat.withValues(alpha: 0.55),
                            size: _inputFs * 1.2,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _paymentSaved
                                ? 'Saved: $_paymentMethod'
                                : 'Not saved yet',
                            style: TextStyle(
                              color: AppColors.blackCat.withValues(alpha: 0.65),
                              fontSize: _inputFs,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 9) Nail Material Bundles (Required)
                // -----------------------
                _sectionCard(
                  title: 'Nail Material Bundles',
                  subtitle:
                      'Starter bundles for gel, tips, tools and more. (Required)',
                  gradient: const LinearGradient(
                    colors: [_snow, _snow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 320,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _bundleCard(
                              title: 'Starter Material Bundle',
                              subtitle: 'Perfect for new artists.',
                              price: '\$50',
                              imageAsset: 'assets/images/nail_bundle_50.png',
                              selected:
                                  (_bundlePurchased &&
                                      _selectedBundle == 'Starter') ||
                                  (_bundleInCart &&
                                      _bundleCartKey == 'Starter'),
                              purchased:
                                  _bundlePurchased &&
                                  _selectedBundle == 'Starter',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _bundleCartKey = 'Starter'),
                              onAdd: () => _addBundleToCart('Starter'),
                            ),
                            const SizedBox(width: 12),
                            _bundleCard(
                              title: 'Pro Material Bundle',
                              subtitle: 'Gel, tools & tips.',
                              price: '\$100',
                              imageAsset: 'assets/images/nail_bundle_100.png',
                              selected:
                                  (_bundlePurchased &&
                                      _selectedBundle == 'Pro') ||
                                  (_bundleInCart && _bundleCartKey == 'Pro'),
                              purchased:
                                  _bundlePurchased && _selectedBundle == 'Pro',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _bundleCartKey = 'Pro'),
                              onAdd: () => _addBundleToCart('Pro'),
                            ),
                            const SizedBox(width: 12),
                            _bundleCard(
                              title: 'Elite Bundle',
                              subtitle: 'For high volume artists.',
                              price: '\$150',
                              imageAsset: 'assets/images/nail_bundle_150.png',
                              selected:
                                  (_bundlePurchased &&
                                      _selectedBundle == 'Elite') ||
                                  (_bundleInCart && _bundleCartKey == 'Elite'),
                              purchased:
                                  _bundlePurchased &&
                                  _selectedBundle == 'Elite',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _bundleCartKey = 'Elite'),
                              onAdd: () => _addBundleToCart('Elite'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: AppColors.blackCat.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You must purchase a bundle before account creation.',
                              style: TextStyle(
                                fontSize: _smallFs,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // 10) Payout
                // -----------------------
                _sectionCard(
                  title: 'Payout',
                  subtitle: 'How you receive payouts (can be updated later).',
                  gradient: const LinearGradient(colors: [_snow, _snow]),
                  child: Column(
                    children: [
                      DropdownButtonFormField<PayoutMethod>(
                        initialValue: _payoutMethod,
                        style: const TextStyle(
                          fontSize: _inputFs,
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                        hint: Text(
                          'Select state',
                          style: TextStyle(
                            fontSize: _inputFs,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blackCat.withValues(alpha: 0.45),
                          ),
                        ),
                        decoration: _dec(
                          'Payout Method *',
                          'Select payout method',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PayoutMethod.paypal,
                            child: Text(
                              'PayPal',
                              style: TextStyle(
                                fontSize: _inputFs,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.venmo,
                            child: Text(
                              'Venmo',
                              style: TextStyle(
                                fontSize: _inputFs,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.bankTransfer,
                            child: Text(
                              'Bank Transfer',
                              style: TextStyle(
                                fontSize: _inputFs,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.applePay,
                            child: Text(
                              'Apple Pay',
                              style: TextStyle(
                                fontSize: _inputFs,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _payoutMethod = v ?? PayoutMethod.paypal,
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (_payoutMethod == PayoutMethod.paypal ||
                          _payoutMethod == PayoutMethod.venmo) ...[
                        TextField(
                          controller: _legalNameCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec('Legal Name *', 'Legal Name'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _payoutEmailCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(
                            _payoutMethod == PayoutMethod.venmo
                                ? 'Venmo Email *'
                                : 'PayPal Email *',
                            'Email',
                          ),
                        ),
                      ],

                      if (_payoutMethod == PayoutMethod.bankTransfer) ...[
                        TextField(
                          controller: _legalNameCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec('Legal Name *', 'Legal Name'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bankNameCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec('Bank Name *', 'Bank name'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _routingCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          keyboardType: TextInputType.number,
                          decoration: _dec(
                            'Routing Number *',
                            'Routing number',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accountNumberCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          keyboardType: TextInputType.number,
                          decoration: _dec(
                            'Account Number *',
                            'Account number',
                          ),
                        ),
                      ],

                      if (_payoutMethod == PayoutMethod.applePay) ...[
                        TextField(
                          controller: _applePayNameCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec('Full Name *', 'Name on Apple Pay'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _applePayPhoneCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            UsPhoneTextInputFormatter(),
                          ],
                          decoration: _dec('Phone Number *', 'Apple Pay phone'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _applePayEmailCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(
                            'Apple ID Email *',
                            'Email linked to Apple Pay',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                if (widget.showAdaCompliance) ...[
                  // -----------------------
                  // 11) Agreements
                  // -----------------------
                  _sectionCard(
                    title: 'Agreements',
                    subtitle: 'Required to create your account.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _smallCheckboxRow(
                          value: _agreeTerms,
                          onChanged: (v) =>
                              setState(() => _agreeTerms = v ?? false),
                          text: 'I agree to the Terms',
                        ),
                        _smallCheckboxRow(
                          value: _noCopyright,
                          onChanged: (v) =>
                              setState(() => _noCopyright = v ?? false),
                          text:
                              'I confirm my content does not violate copyright',
                        ),
                        _smallCheckboxRow(
                          value: _agreeSafety,
                          onChanged: (v) =>
                              setState(() => _agreeSafety = v ?? false),
                          text: 'I agree to safety guidelines',
                        ),
                        Row(
                          children: [
                            const Text(
                              'Receive updates',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Transform.scale(
                              scale: 0.9,
                              child: Switch(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                value: _receiveUpdates,
                                onChanged: (v) =>
                                    setState(() => _receiveUpdates = v),
                                activeThumbColor: _blackCat,
                                activeTrackColor: _blackCat.withValues(alpha: 0.45),
                                inactiveThumbColor: _blackCat.withValues(alpha: 0.55),
                                inactiveTrackColor: _blackCat.withValues(alpha: 0.25),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (_bundlePurchased && _canStartCheckout && !_submitting)
                        ? _continue
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blackCat,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_snow),
                            ),
                          )
                        : Text(
                            'Create account',
                            style: const TextStyle(
                              color: _snow,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel._(this.text, this.requiredField);

  final String text;
  final bool requiredField;

  factory _FieldLabel.required(String text) => _FieldLabel._(text, true);
  factory _FieldLabel.normal(String text) => _FieldLabel._(text, false);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

Widget _smallCheckboxRow({
  required bool value,
  required ValueChanged<bool?> onChanged,
  required String text,
}) {
  return InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.zero,
    overlayColor: WidgetStateColor.resolveWith(
      (_) => AppColors.blackCat.withValues(alpha: 0.12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.85, // âœ… smaller checkbox
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              activeColor: AppColors.blackCat,
              checkColor: AppColors.snow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
