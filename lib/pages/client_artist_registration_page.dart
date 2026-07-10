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
import '../widgets/coin_selector_page.dart';
import '../widgets/jnt_modal_app_bar.dart';

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
  int _registrationStep = 0;
  int? _validationTriggeredStep;

  static const List<String> _registrationStepTitles = <String>[
    'Profile &\nAddress',
    'Nail Preference',
    'Portfolio',
    'Specialization &\nService Area',
    'Payment &\nPayout',
    'Bundles &\nAccount',
  ];

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
  final Map<String, Uint8List> _guidedMeasurementPhotos = {};
  String _measurementCoinReference = 'US Penny (1¢)';

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

  void _registrationLog(String message) {
    debugPrint('[CLIENT-ARTIST-REG] $message');
  }

  static const List<_NailCaptureStep> _nailCaptureSteps = <_NailCaptureStep>[
    _NailCaptureStep(
      key: 'lThumb',
      hand: 'left',
      finger: 'thumb',
      title: 'Left Thumb',
    ),
    _NailCaptureStep(
      key: 'lIndex',
      hand: 'left',
      finger: 'index',
      title: 'Left Index',
    ),
    _NailCaptureStep(
      key: 'lMiddle',
      hand: 'left',
      finger: 'middle',
      title: 'Left Middle',
    ),
    _NailCaptureStep(
      key: 'lRing',
      hand: 'left',
      finger: 'ring',
      title: 'Left Ring',
    ),
    _NailCaptureStep(
      key: 'lPinky',
      hand: 'left',
      finger: 'pinky',
      title: 'Left Pinky',
    ),
    _NailCaptureStep(
      key: 'rThumb',
      hand: 'right',
      finger: 'thumb',
      title: 'Right Thumb',
    ),
    _NailCaptureStep(
      key: 'rIndex',
      hand: 'right',
      finger: 'index',
      title: 'Right Index',
    ),
    _NailCaptureStep(
      key: 'rMiddle',
      hand: 'right',
      finger: 'middle',
      title: 'Right Middle',
    ),
    _NailCaptureStep(
      key: 'rRing',
      hand: 'right',
      finger: 'ring',
      title: 'Right Ring',
    ),
    _NailCaptureStep(
      key: 'rPinky',
      hand: 'right',
      finger: 'pinky',
      title: 'Right Pinky',
    ),
  ];

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
  final Set<String> _services = <String>{};
  final _minPriceCtrl = TextEditingController(text: '15');
  final _maxPriceCtrl = TextEditingController(text: '5000');
  bool _rush = false;

  bool _directRequestsEnabled = true;
  bool _nfcRequestEnabled = true;
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
    '3-6 months',
    '6-12 months',
    '1-2 years',
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

    final optimized =
        _optimizePortfolioBytes(bytes, maxEdge: 900, maxBytes: 650 * 1024) ??
        bytes;

    final path = 'client_artists/$uid/profile/avatar.jpg';

    try {
      final storage = Supabase.instance.client.storage.from('profile-pictures');

      await storage.uploadBinary(
        path,
        optimized,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final publicUrl = storage.getPublicUrl(path).trim();

      debugPrint('CLIENT ARTIST PROFILE URL = $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('CLIENT ARTIST PROFILE UPLOAD FAILED: $e');
      return '';
    }
  }

  Future<Map<String, String>> _uploadGuidedMeasurementPhotos(String uid) async {
    if (_guidedMeasurementPhotos.isEmpty) {
      return const <String, String>{};
    }

    final storage = Supabase.instance.client.storage.from('profile-pictures');
    final uploaded = <String, String>{};

    for (final entry in _guidedMeasurementPhotos.entries) {
      final path = 'client_artists/$uid/guided_measurements/${entry.key}.jpg';
      try {
        await storage.uploadBinary(
          path,
          entry.value,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
        uploaded[entry.key] = storage.getPublicUrl(path).trim();
      } catch (e) {
        debugPrint(
          'CLIENT ARTIST GUIDED MEASUREMENT UPLOAD FAILED (${entry.key}): $e',
        );
      }
    }

    return uploaded;
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
      'panel_nfcRequestEnabled': _nfcRequestEnabled,
      'panel_artist_nfcRequestEnabled': _nfcRequestEnabled,
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
        'nfcRequestEnabled': _nfcRequestEnabled,
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
          'nfcRequestEnabled': _nfcRequestEnabled,
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
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
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
                                tileColor: _snow,
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

  String? _atLeastOneSocialValidator() {
    if (_instagramCtrl.text.trim().isEmpty && _tiktokCtrl.text.trim().isEmpty) {
      return 'Enter Instagram or TikTok';
    }
    return null;
  }

  String? _servicesValidator() {
    if (_services.isEmpty) {
      return 'Select at least one specialization';
    }
    return null;
  }

  String? _cardNumberValidator(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Card Number is required';
    if (digits.length < 13 || digits.length > 19) {
      return 'Enter a valid card number';
    }
    return null;
  }

  String? _expiryValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Expiration Date is required';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(raw)) {
      return 'Enter MM/YY';
    }
    return null;
  }

  String? _cvvValidator(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'CVV is required';
    if (digits.length != 3 && digits.length != 4) {
      return 'Enter a valid CVV';
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

  NailDimensions _dimensionsWithOverrides(Map<String, double> measured) {
    final d = _nailPrefs.dimensions;
    return NailDimensions(
      lThumb: measured['lThumb'] ?? d.lThumb,
      lIndex: measured['lIndex'] ?? d.lIndex,
      lMiddle: measured['lMiddle'] ?? d.lMiddle,
      lRing: measured['lRing'] ?? d.lRing,
      lPinky: measured['lPinky'] ?? d.lPinky,
      rThumb: measured['rThumb'] ?? d.rThumb,
      rIndex: measured['rIndex'] ?? d.rIndex,
      rMiddle: measured['rMiddle'] ?? d.rMiddle,
      rRing: measured['rRing'] ?? d.rRing,
      rPinky: measured['rPinky'] ?? d.rPinky,
    );
  }

  Future<double?> _askManualMeasurement(String fingerTitle) async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Enter $fingerTitle (mm)'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: _inputFs),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'e.g. 14.5',
            border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCatLight,
              foregroundColor: AppColors.snow,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              textStyle: Theme.of(
                ctx,
              ).textTheme.labelLarge?.copyWith(fontFamily: 'Arial'),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, parsed);
            },
            style: ElevatedButton.styleFrom(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              textStyle: Theme.of(
                ctx,
              ).textTheme.labelLarge?.copyWith(fontFamily: 'Arial'),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  Map<String, double> _currentMeasuredMap() {
    final d = _nailPrefs.dimensions;
    final out = <String, double>{};
    void put(String key, double? v) {
      if (v != null) out[key] = v;
    }

    put('lThumb', d.lThumb);
    put('lIndex', d.lIndex);
    put('lMiddle', d.lMiddle);
    put('lRing', d.lRing);
    put('lPinky', d.lPinky);
    put('rThumb', d.rThumb);
    put('rIndex', d.rIndex);
    put('rMiddle', d.rMiddle);
    put('rRing', d.rRing);
    put('rPinky', d.rPinky);
    return out;
  }

  void _persistMeasuredMap(Map<String, double> measured) {
    setState(() {
      _nailPrefs = NailPreferences(
        dimensions: _dimensionsWithOverrides(measured),
        shape: _nailPrefs.shape,
        length: _nailPrefs.length,
      );
    });
  }

  Future<bool> _showMeasurementGuide() async {
    final allowed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: AppColors.snow,
          appBar: AppBar(
            backgroundColor: AppColors.snow,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context, false),
            ),
            centerTitle: true,
            title: const Text(
              'Nail Measurement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: AppColors.blackCat.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.straighten_rounded, size: 26),
                        SizedBox(height: 12),
                        Text(
                          'How to Measure Your Nails',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "We'll use a coin or currency as a reference guide to accurately measure your nail width.",
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _MeasureStepTile(
                    step: 1,
                    title: 'Keep It Flat',
                    subtitle:
                        'Position your finger flat on a table for maximum accuracy.',
                  ),
                  const _MeasureStepTile(
                    step: 2,
                    title: 'Use a Reference Coin',
                    subtitle:
                        'Place the coin next to your fingernail to use as a measurement guide.',
                  ),
                  const _MeasureStepTile(
                    step: 3,
                    title: 'Scan with Camera',
                    subtitle:
                        "Point your phone's camera to capture both your nail and the reference coin.",
                  ),
                  const _MeasureStepTile(
                    step: 4,
                    title: 'Confirm Measurement',
                    subtitle:
                        "We'll calculate your nail width based on the coin reference.",
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.snow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return allowed == true;
  }

  Future<String?> _showCoinSelector() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CoinSelectorPage(
          items: coinReferences,
          progressText: '${_currentMeasuredMap().length}/10',
          title: 'Select Coin',
          initialSelection: _measurementCoinReference,
        ),
      ),
    );
    return selected;
  }

  Future<void> _startGuidedNailMeasurement() async {
    if (!mounted) return;
    final proceed = await _showMeasurementGuide();
    if (!proceed || !mounted) return;

    final selectedCoin = await _showCoinSelector();
    if (selectedCoin == null || selectedCoin.trim().isEmpty || !mounted) {
      return;
    }
    _measurementCoinReference = selectedCoin;

    final measured = _currentMeasuredMap();
    var stepIndex = 0;
    var measuring = false;
    var sheetClosed = false;
    final pageContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCat,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final step = _nailCaptureSteps[stepIndex];
            final progressLabel =
                '${measured.length}/${_nailCaptureSteps.length}';

            Future<void> saveCurrentAndMoveNext(double mm) async {
              if (!mm.isFinite || mm <= 0) {
                _registrationLog('invalid measurement for ${step.key}: $mm');
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid measurement value. Please try again.',
                    ),
                  ),
                );
                return;
              }
              _registrationLog('saving measurement ${step.key} => $mm');
              measured[step.key] = (mm * 10).roundToDouble() / 10.0;
              _persistMeasuredMap(measured);
              if (stepIndex < _nailCaptureSteps.length - 1) {
                _registrationLog('moving to next step index=${stepIndex + 1}');
                setModalState(() => stepIndex += 1);
              } else {
                _registrationLog(
                  'final step complete; closing measurement sheet',
                );
                sheetClosed = true;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(
                    content: Text('Nail measurements saved for both hands.'),
                  ),
                );
              }
            }

            Future<void> captureCurrentStep() async {
              if (measuring) return;
              setModalState(() => measuring = true);
              try {
                _registrationLog('opening camera for ${step.key}');
                final image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 1080,
                  maxHeight: 1080,
                );
                if (image == null) {
                  _registrationLog('camera canceled for ${step.key}');
                  return;
                }

                final bytes = await image.readAsBytes();
                _guidedMeasurementPhotos[step.key] = bytes;
                _registrationLog(
                  'captured photo for ${step.key}: ${bytes.lengthInBytes} bytes',
                );

                final mm = await _askManualMeasurement(step.title);
                if (mm == null) return;
                await saveCurrentAndMoveNext(mm);
              } catch (_) {
                _registrationLog('capture failed for ${step.key}');
                if (mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to measure from photo. Please try again.',
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted && !sheetClosed) {
                  setModalState(() => measuring = false);
                }
              }
            }

            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16 + MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Measure Your Nail',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        Text(
                          progressLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final s = _nailCaptureSteps[i];
                          final done = measured[s.key] != null;
                          final current = i == stepIndex;
                          return InkWell(
                            onTap: () => setModalState(() => stepIndex = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: current
                                    ? AppColors.blackCat
                                    : (done
                                          ? AppColors.balletSlippers
                                          : AppColors.snow),
                                border: Border.all(
                                  color: current
                                      ? AppColors.blackCat
                                      : AppColors.blackCat.withValues(
                                          alpha: 0.12,
                                        ),
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                s.finger,
                                style: TextStyle(
                                  color: current
                                      ? AppColors.snow
                                      : AppColors.blackCat,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: _nailCaptureSteps.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 320,
                      decoration: const BoxDecoration(
                        color: AppColors.blackCat,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              size: 70,
                              color: AppColors.snow,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Scan your ${step.title}',
                              style: const TextStyle(
                                color: AppColors.snow,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reference: $_measurementCoinReference',
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        fontFamily: 'ArialBold',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter width in mm for each finger (you can re-image any finger and latest value is saved).',
                      style: TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 13,
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Text(
                        'Captured photos will upload with your client-artist account when you sign up.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: measuring
                                ? null
                                : () async {
                                    try {
                                      _registrationLog(
                                        'manual entry opened for ${step.key}',
                                      );
                                      final manual =
                                          await _askManualMeasurement(
                                            step.title,
                                          );
                                      if (manual == null) return;
                                      await saveCurrentAndMoveNext(manual);
                                    } catch (e) {
                                      _registrationLog(
                                        'manual save failed for ${step.key}: $e',
                                      );
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: const Text('Enter Manually'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: measuring ? null : captureCurrentStep,
                            icon: measuring
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              measuring
                                  ? 'Measuring...'
                                  : (measured[step.key] == null
                                        ? 'Capture'
                                        : 'Re-image'),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final nextCoin = await _showCoinSelector();
                        if (nextCoin == null || nextCoin.trim().isEmpty) return;
                        setModalState(
                          () => _measurementCoinReference = nextCoin,
                        );
                      },
                      child: const Text('Change Coin/Currency'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -----------------------
  // Submit
  // -----------------------
  String get _registrationDraftId {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isNotEmpty) return email;
    return 'local_${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> _criticalRegistrationPayload({required String uid}) {
    final payload = _buildCombinedFirestorePayload(uid: uid);
    final basic = <String, dynamic>{
      'name': _displayNameCtrl.text.trim().isNotEmpty
          ? _displayNameCtrl.text.trim()
          : _fullNameOrStudioCtrl.text.trim(),
      'email': _emailCtrl.text.trim().toLowerCase(),
      'phone': _fullPhone,
      'profileImageUrl': '',
    };
    final now = DateTime.now().toIso8601String();
    return <String, dynamic>{
      'id': uid,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'account_type': 'client_artist',
      'profile': payload['profile'],
      'basic': basic,
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
      'displayName': _displayNameCtrl.text.trim(),
      'studioName': _fullNameOrStudioCtrl.text.trim(),
      'name': _displayNameCtrl.text.trim().isNotEmpty
          ? _displayNameCtrl.text.trim()
          : _fullNameOrStudioCtrl.text.trim(),
      'nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
      'fullName': _displayNameCtrl.text.trim().isNotEmpty
          ? _displayNameCtrl.text.trim()
          : _fullNameOrStudioCtrl.text.trim(),
      'profileImageUrl': '',
      'profilePhotoUrl': '',
      'photoUrl': '',
      'avatarUrl': '',
      'panel_displayName': _displayNameCtrl.text.trim(),
      'panel_nameOrStudio': _fullNameOrStudioCtrl.text.trim(),
      'panel_profileImageUrl': '',
      'updated_at': now,
    };
  }

  Future<void> _persistRegistrationDraftStep({int? step}) async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    try {
      final payload = _buildCombinedFirestorePayload(uid: _registrationDraftId);
      final basic = <String, dynamic>{
        'name': _displayNameCtrl.text.trim().isNotEmpty
            ? _displayNameCtrl.text.trim()
            : _fullNameOrStudioCtrl.text.trim(),
        'email': email,
        'phone': _fullPhone,
        'profileImageUrl': '',
      };

      await Supabase.instance.client
          .from('client_artist_registration_drafts')
          .upsert(<String, dynamic>{
            'id': _registrationDraftId,
            'email': email,
            'current_step': step ?? _registrationStep,
            'account_type': 'client_artist',
            'profile': payload['profile'],
            'basic': basic,
            'address': payload['address'],
            'payment': payload['payment'],
            'nail_preferences': payload['nailPreferences'],
            'artist_profile': payload['artist'],
            'registration': payload['registration'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      // Draft saving should never block the user from continuing the wizard.
      debugPrint('CLIENT ARTIST DRAFT SAVE SKIPPED: $e');
    }
  }

  Future<bool> _validateCurrentRegistrationStep() async {
    if (_validationTriggeredStep != _registrationStep) {
      setState(() => _validationTriggeredStep = _registrationStep);
    }
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) return false;

    if (_registrationStep == 0 && _isUnitedStates) {
      try {
        final addressValidation =
            await AddressValidationService.validateUsAddress(
              street: _streetCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              state: _resolvedState,
              zip: _zipCtrl.text.trim(),
            ).timeout(const Duration(seconds: 8));
        if (!addressValidation.isValid) {
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addressValidation.message ?? 'Invalid U.S. mailing address.',
              ),
            ),
          );
          return false;
        }
      } on TimeoutException {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address validation timed out. Please try again.'),
          ),
        );
        return false;
      }
    }

    if (_registrationStep == 2 &&
        _instagramCtrl.text.trim().isEmpty &&
        _tiktokCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide at least one social media detail: Instagram or TikTok.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveCriticalClientArtistRows(User supabaseUser) async {
    final uid = supabaseUser.id;
    final supabase = Supabase.instance.client;
    final critical = _criticalRegistrationPayload(uid: uid);
    final now = DateTime.now().toIso8601String();

    // Save the combined role first so the app can render the correct account
    // immediately after auth succeeds.
    await supabase
        .from('client_artist')
        .upsert(critical)
        .timeout(const Duration(seconds: 12));

    // Keep the client table in sync because client-artist can also receive
    // client requests. This is much smaller than the old full final submit.
    await supabase
        .from('client')
        .upsert(<String, dynamic>{
          'id': uid,
          'email': critical['email'],
          'account_type': 'client_artist',
          'profile': critical['profile'],
          'basic': critical['basic'],
          'address': critical['address'],
          'payment': critical['payment'],
          'nail_preferences': critical['nail_preferences'],
          'registration': critical['registration'],
          'updated_at': now,
        })
        .timeout(const Duration(seconds: 12));
  }

  Future<void> _finishNonBlockingRegistrationSave(User supabaseUser) async {
    final uid = supabaseUser.id;
    final supabase = Supabase.instance.client;

    try {
      final profilePhotoUrl = await _uploadProfileImage(uid);
      final portfolioImageUrls = await _uploadPortfolioImages(uid);
      final guidedMeasurementPhotoUrls = await _uploadGuidedMeasurementPhotos(
        uid,
      );

      final payload = _buildCombinedFirestorePayload(
        uid: uid,
        profilePhotoUrl: profilePhotoUrl.trim(),
        portfolioImageUrls: portfolioImageUrls,
      );
      final basic = <String, dynamic>{
        'name': _displayNameCtrl.text.trim().isNotEmpty
            ? _displayNameCtrl.text.trim()
            : _fullNameOrStudioCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'phone': _fullPhone,
        'profileImageUrl': profilePhotoUrl.trim(),
      };
      final registration = Map<String, dynamic>.from(
        (payload['registration'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      )..['guidedMeasurementPhotos'] = guidedMeasurementPhotoUrls;
      final now = DateTime.now().toIso8601String();

      await supabase.from('client_artist').upsert(<String, dynamic>{
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
        'basic': basic,
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
        'registration': registration,
        'updated_at': now,
      });

      await supabase.from('client').upsert(<String, dynamic>{
        'id': uid,
        'email': _emailCtrl.text.trim().toLowerCase(),
        'account_type': 'client_artist',
        'profile': payload['profile'],
        'basic': basic,
        'address': payload['address'],
        'payment': payload['payment'],
        'nail_preferences': payload['nailPreferences'],
        'registration': registration,
        'updated_at': now,
      });

      // Artist table is a mirror only. Do not block account creation if this
      // table has triggers/schema differences.
      try {
        await supabase.from('artist').upsert(<String, dynamic>{
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
          'updated_at': now,
        });
      } catch (e) {
        debugPrint('CLIENT ARTIST BACKGROUND ARTIST MIRROR SKIPPED: $e');
      }
    } catch (e, st) {
      debugPrint('CLIENT ARTIST BACKGROUND SAVE ERROR');
      debugPrint(e.toString());
      debugPrint(st.toString());
    }
  }

  Future<void> _continue() async {
    if (!await _validateCurrentRegistrationStep()) return;

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

    try {
      await _persistRegistrationDraftStep(step: _registrationStep);
      await SupabaseAuthService.logout().timeout(const Duration(seconds: 8));

      User? supabaseUser;
      try {
        supabaseUser = await SupabaseAuthService.signup(
          email: _emailCtrl.text.trim().toLowerCase(),
          password: _passCtrl.text.trim(),
        ).timeout(const Duration(seconds: 18));
      } on AuthException catch (e) {
        final alreadyRegistered = e.message.toLowerCase().contains('already');
        if (!alreadyRegistered) rethrow;

        final existingUser = await SupabaseAuthService.login(
          email: _emailCtrl.text.trim().toLowerCase(),
          password: _passCtrl.text.trim(),
        ).timeout(const Duration(seconds: 18));
        if (existingUser == null) rethrow;
        supabaseUser = existingUser;
      }

      if (supabaseUser == null) {
        throw Exception('Unable to create user.');
      }

      await _saveCriticalClientArtistRows(supabaseUser);

      if (!mounted) return;
      final draft = _buildClientProfileDraft();
      final enableAllTabs =
          draft.isComplete && (_hasSizingKitAlready || _kitPaid || _bundlePaid);

      unawaited(_finishNonBlockingRegistrationSave(supabaseUser));

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
    } on TimeoutException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration timed out: $e')));
    } on AuthException catch (e) {
      if (!mounted) return;
      final message = e.message.toLowerCase().contains('already')
          ? 'Email already registered. Please sign in.'
          : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e, st) {
      debugPrint('CLIENT_ARTIST_REGISTRATION_ERROR');
      debugPrint(e.toString());
      debugPrint(st.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
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

  Widget _basicProfileSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Basic Profile',
        subtitle: 'Enter your profile details.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profilePicTile(),
            const SizedBox(height: 16),

            _FieldLabel.required('Full Name / Studio Name'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullNameOrStudioCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Name', 'Enter Name'),
              validator: (v) => _requiredValidator(v, 'Name'),
            ),
            const SizedBox(height: 16),

            _FieldLabel.required('Display Name'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Display Name', 'Enter Display Name'),
              validator: (v) => _requiredValidator(v, 'Display Name'),
            ),
            const SizedBox(height: 16),

            _FieldLabel.required('Language Spoken'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _languageSpokenCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Language Spoken', 'Enter language(s) spoken'),
              validator: (v) => _requiredValidator(v, 'Language Spoken'),
            ),
            const SizedBox(height: 16),

            _FieldLabel.required('Currency'),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioCtrl,
              style: const TextStyle(fontSize: _inputFs),
              maxLines: 3,
              decoration: _dec('Bio', 'Tell us about you'),
            ),
            const SizedBox(height: 16),

            _FieldLabel.required('Phone'),
            const SizedBox(height: 16),
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
                                () => _phoneAreaCode = code.dialCode ?? '+1',
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
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
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
                                contentPadding: const EdgeInsets.symmetric(
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
                        padding: const EdgeInsets.only(top: 6, left: 4),
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
            const SizedBox(height: 16),

            _FieldLabel.required('Email ID'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              style: const TextStyle(fontSize: _inputFs),
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email', 'Enter Email'),
              validator: _emailValidator,
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCredentialsSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Account Credentials',
        subtitle: 'Enter your details.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel.required('Email'),
            const SizedBox(height: 16),
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
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: _passwordValidator,
            ),
            const SizedBox(height: 16),
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
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
          ],
        ),
      ),
    );
  }

  Widget _addressInfoSection() {
    return Builder(
      builder: (context) => _sectionCard(
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
              decoration: _dec('Street Address', 'Enter Street Address'),
              onChanged: (_) => _autofillAddressFromStreet(),
              validator: (v) => _requiredValidator(v, 'Street Address'),
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
                  final menuHeight = AutocompleteDropdownSizing.menuHeight(
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
                    constraints: BoxConstraints(maxHeight: menuHeight),
                    child: ListView.separated(
                      shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                        suggestionCount,
                      ),
                      physics: AutocompleteDropdownSizing.scrollPhysics(
                        suggestionCount,
                      ),
                      itemCount: suggestionCount,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(
                          _streetSuggestions[i].displayLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () =>
                            _applyStreetSuggestion(_streetSuggestions[i]),
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
                          onChanged: (v) => setState(() => _state = v),
                          validator: (v) => (v == null || v.trim().isEmpty)
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
                        decoration: _dec('Zip Code', 'Enter Zip Code'),
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
    );
  }

  Widget _nailPreferencesSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Nail Preferences',
        subtitle: 'Your preferred nail shape and length.',
        child: NailPreferencesInlineEditor(
          initial: _nailPrefs,
          showDimensionImages: false,
          onChanged: (updated) => setState(() => _nailPrefs = updated),
        ),
      ),
    );
  }

  Widget _nailMeasurementApiSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Nail Measurement API',
        subtitle: 'Nail measurement with camera.',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: AppColors.blackCat.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nail Photos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Capture each finger photo here. The photos will upload with your client-artist account when you sign up.',
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startGuidedNailMeasurement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Capture Photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portfolioSection() {
    return Builder(
      builder: (context) => _sectionCard(
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._portfolioImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bytes = entry.value;
                  return SizedBox(
                    width: 86,
                    height: 86,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              color: _snow,
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(
                              () => _portfolioImages.removeAt(index),
                            ),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.82,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.snow,
                              ),
                            ),
                          ),
                        ),
                      ],
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
            TextFormField(
              controller: _projectNotesCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Project Notes', 'Project notes'),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _instagramCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec(
                'Instagram or TikTok (one required)',
                'Instagram',
              ),
              validator: (_) => _atLeastOneSocialValidator(),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tiktokCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('TikTok', 'TikTok'),
              validator: (_) => null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearCalendarSection() {
    return Builder(
      builder: (context) => _sectionCard(
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
              onChanged: (v) => setState(() => _directRequestsEnabled = v),
              title: const Text(
                'Enable direct requests',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Allow clients to request specific dates.',
                style: TextStyle(
                  fontSize: _smallFs,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _nfcRequestEnabled,
              activeThumbColor: _blackCat,
              activeTrackColor: _blackCat.withValues(alpha: 0.45),
              inactiveThumbColor: _blackCat.withValues(alpha: 0.55),
              inactiveTrackColor: _blackCat.withValues(alpha: 0.25),
              onChanged: (v) => setState(() => _nfcRequestEnabled = v),
              title: const Text(
                'Accepts NFC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Allow clients to send NFC upgrade requests.',
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
                  _yearCalendarNonce = DateTime.now().millisecondsSinceEpoch;
                }
              }),
              child: Row(
                children: [
                  Icon(
                    _showYearCalendar ? Icons.expand_less : Icons.expand_more,
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
    );
  }

  Widget _locationServiceAreaSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Location & Service Area',
        subtitle: 'Set where you offer services.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _cityCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('City *', 'City'),
              validator: (v) => _requiredValidator(v, 'City'),
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
            if (_isUnitedStates)
              _FieldLabel.required('State')
            else
              _FieldLabel.normal('State / Region'),
            const SizedBox(height: 6),
            if (_isUnitedStates)
              _typeAheadPicker(
                label: 'State',
                hint: 'Select State',
                options: usStates,
                selectedValue: _state,
                onChanged: (v) => setState(() => _state = v),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'State is required'
                    : null,
              )
            else
              TextFormField(
                controller: _manualStateCtrl,
                style: const TextStyle(fontSize: _inputFs),
                decoration: _dec('State / Region', 'Enter State / Region'),
                validator: (_) => null,
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
    );
  }

  Widget _specializationPricingSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Specialization & Pricing',
        subtitle: 'Select services and set your range.',
        gradient: const LinearGradient(colors: [_snow, _snow]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            FormField<List<String>>(
              initialValue: _services.toList(growable: false),
              validator: (_) => _servicesValidator(),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Gel / Acrylic',
                        selected: _services.contains('Gel / Acrylic'),
                        onTap: () => setState(() {
                          _services.contains('Gel / Acrylic')
                              ? _services.remove('Gel / Acrylic')
                              : _services.add('Gel / Acrylic');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        '3D Nail Art',
                        selected: _services.contains('3D Nail Art'),
                        onTap: () => setState(() {
                          _services.contains('3D Nail Art')
                              ? _services.remove('3D Nail Art')
                              : _services.add('3D Nail Art');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Airbrush/Stamping',
                        selected: _services.contains('Airbrush/Stamping'),
                        onTap: () => setState(() {
                          _services.contains('Airbrush/Stamping')
                              ? _services.remove('Airbrush/Stamping')
                              : _services.add('Airbrush/Stamping');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Encapsulation',
                        selected: _services.contains('Encapsulation '),
                        onTap: () => setState(() {
                          _services.contains('Encapsulation ')
                              ? _services.remove('Encapsulation ')
                              : _services.add('Encapsulation ');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Dip Powder',
                        selected: _services.contains('Dip Powder'),
                        onTap: () => setState(() {
                          _services.contains('Dip Powder')
                              ? _services.remove('Dip Powder')
                              : _services.add('Dip Powder');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Sculptured',
                        selected: _services.contains('Sculptured'),
                        onTap: () => setState(() {
                          _services.contains('Sculptured')
                              ? _services.remove('Sculptured')
                              : _services.add('Sculptured');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'PolyGel',
                        selected: _services.contains('PolyGel'),
                        onTap: () => setState(() {
                          _services.contains('PolyGel')
                              ? _services.remove('PolyGel')
                              : _services.add('PolyGel');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                      _chip(
                        'Chrome & Metallic',
                        selected: _services.contains('Chrome & Metallic'),
                        onTap: () => setState(() {
                          _services.contains('Chrome & Metallic')
                              ? _services.remove('Chrome & Metallic')
                              : _services.add('Chrome & Metallic');
                          field.didChange(_services.toList(growable: false));
                        }),
                      ),
                    ],
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
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
              ),
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
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }

  Widget _paymentMethodSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Payment Method',
        subtitle: 'Select a method and save it (required).',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioTheme(
              data: RadioThemeData(
                fillColor: WidgetStateProperty.resolveWith((_) => _blackCat),
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
                        decoration: _dec('PayPal Email', 'name@email.com'),
                        validator: _emailValidator,
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
                        decoration: _dec('Venmo', '@handle or phone/email'),
                        validator: (v) => _requiredValidator(v, 'Venmo Handle'),
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
                        validator: (v) =>
                            _requiredValidator(v, 'Apple Pay Name'),
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
                        validator: _phoneValidator,
                      ),
                      const SizedBox(height: 6),
                      _FieldLabel.required('Apple Pay Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _applePayPaymentEmailCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('Email', 'Email'),
                        validator: _emailValidator,
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
                        validator: (v) => _requiredValidator(v, 'Card Name'),
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
                        decoration: _dec('Number', '1234 5678 9012 3456'),
                        validator: _cardNumberValidator,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel.required('Expiration Date'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cardExpiryCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                    ExpiryDateTextInputFormatter(),
                                  ],
                                  decoration: _dec('Expiration Date', 'MM/YY'),
                                  validator: _expiryValidator,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel.required('CVV'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cardCvvCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: _dec('CVV', '123'),
                                  validator: _cvvValidator,
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
                        validator: (v) => _requiredValidator(v, 'Billing Zip'),
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
                  final paymentValid = _paymentFieldsValid();
                  if (!paymentValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please complete the payment method details to save.',
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
                  _paymentSaved ? 'Saved: $_paymentMethod' : 'Not saved yet',
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
    );
  }

  Widget _bundlesSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Nail Material Bundles',
        subtitle: 'Starter bundles for gel, tips, tools and more. (Required)',
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
                        (_bundlePurchased && _selectedBundle == 'Starter') ||
                        (_bundleInCart && _bundleCartKey == 'Starter'),
                    purchased: _bundlePurchased && _selectedBundle == 'Starter',
                    disableAdd: _bundlePurchased,
                    onTap: () => setState(() => _bundleCartKey = 'Starter'),
                    onAdd: () => _addBundleToCart('Starter'),
                  ),
                  const SizedBox(width: 12),
                  _bundleCard(
                    title: 'Pro Material Bundle',
                    subtitle: 'Gel, tools & tips.',
                    price: '\$100',
                    imageAsset: 'assets/images/nail_bundle_100.png',
                    selected:
                        (_bundlePurchased && _selectedBundle == 'Pro') ||
                        (_bundleInCart && _bundleCartKey == 'Pro'),
                    purchased: _bundlePurchased && _selectedBundle == 'Pro',
                    disableAdd: _bundlePurchased,
                    onTap: () => setState(() => _bundleCartKey = 'Pro'),
                    onAdd: () => _addBundleToCart('Pro'),
                  ),
                  const SizedBox(width: 12),
                  _bundleCard(
                    title: 'Elite Bundle',
                    subtitle: 'For high volume artists.',
                    price: '\$150',
                    imageAsset: 'assets/images/nail_bundle_150.png',
                    selected:
                        (_bundlePurchased && _selectedBundle == 'Elite') ||
                        (_bundleInCart && _bundleCartKey == 'Elite'),
                    purchased: _bundlePurchased && _selectedBundle == 'Elite',
                    disableAdd: _bundlePurchased,
                    onTap: () => setState(() => _bundleCartKey = 'Elite'),
                    onAdd: () => _addBundleToCart('Elite'),
                  ),
                ],
              ),
            ),
            if (!_bundlePurchased) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _payoutSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Payout',
        subtitle: 'How you receive payouts (can be updated later).',
        gradient: const LinearGradient(colors: [_snow, _snow]),
        child: Column(
          children: [
            DropdownButtonFormField<PayoutMethod>(
              initialValue: _payoutMethod,
              dropdownColor: _snow,
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
              decoration: _dec('Payout Method *', 'Select payout method'),
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
              onChanged: (v) =>
                  setState(() => _payoutMethod = v ?? PayoutMethod.paypal),
            ),
            const SizedBox(height: 6),

            if (_payoutMethod == PayoutMethod.paypal ||
                _payoutMethod == PayoutMethod.venmo) ...[
              TextFormField(
                controller: _legalNameCtrl,
                style: const TextStyle(fontSize: _inputFs),
                decoration: _dec('Legal Name *', 'Legal Name'),
                validator: (v) => _requiredValidator(v, 'Legal Name'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _payoutEmailCtrl,
                style: const TextStyle(fontSize: _inputFs),
                keyboardType: TextInputType.emailAddress,
                decoration: _dec(
                  _payoutMethod == PayoutMethod.venmo
                      ? 'Venmo Email *'
                      : 'PayPal Email *',
                  'Email',
                ),
                validator: _emailValidator,
              ),
            ],

            if (_payoutMethod == PayoutMethod.bankTransfer) ...[
              TextFormField(
                controller: _legalNameCtrl,
                style: const TextStyle(fontSize: _inputFs),
                decoration: _dec('Legal Name *', 'Legal Name'),
                validator: (v) => _requiredValidator(v, 'Legal Name'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bankNameCtrl,
                style: const TextStyle(fontSize: _inputFs),
                decoration: _dec('Bank Name *', 'Bank name'),
                validator: (v) => _requiredValidator(v, 'Bank Name'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _routingCtrl,
                style: const TextStyle(fontSize: _inputFs),
                keyboardType: TextInputType.number,
                decoration: _dec('Routing Number *', 'Routing number'),
                validator: (v) => _requiredValidator(v, 'Routing Number'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountNumberCtrl,
                style: const TextStyle(fontSize: _inputFs),
                keyboardType: TextInputType.number,
                decoration: _dec('Account Number *', 'Account number'),
                validator: (v) => _requiredValidator(v, 'Account Number'),
              ),
            ],

            if (_payoutMethod == PayoutMethod.applePay) ...[
              TextFormField(
                controller: _applePayNameCtrl,
                style: const TextStyle(fontSize: _inputFs),
                decoration: _dec('Full Name *', 'Name on Apple Pay'),
                validator: (v) => _requiredValidator(v, 'Full Name'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _applePayPhoneCtrl,
                style: const TextStyle(fontSize: _inputFs),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  UsPhoneTextInputFormatter(),
                ],
                decoration: _dec('Phone Number *', 'Apple Pay phone'),
                validator: _phoneValidator,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _applePayEmailCtrl,
                style: const TextStyle(fontSize: _inputFs),
                keyboardType: TextInputType.emailAddress,
                decoration: _dec(
                  'Apple ID Email *',
                  'Email linked to Apple Pay',
                ),
                validator: _emailValidator,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agreementsSection() {
    return Builder(
      builder: (context) => _sectionCard(
        title: 'Agreements',
        subtitle: 'Required to create your account.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _smallCheckboxRow(
              value: _agreeTerms,
              onChanged: (v) => setState(() => _agreeTerms = v ?? false),
              text: 'I agree to the Terms',
            ),
            _smallCheckboxRow(
              value: _noCopyright,
              onChanged: (v) => setState(() => _noCopyright = v ?? false),
              text: 'I confirm my content does not violate copyright',
            ),
            _smallCheckboxRow(
              value: _agreeSafety,
              onChanged: (v) => setState(() => _agreeSafety = v ?? false),
              text: 'I agree to safety guidelines',
            ),
            Row(
              children: [
                const Text(
                  'Receive updates',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: _receiveUpdates,
                    onChanged: (v) => setState(() => _receiveUpdates = v),
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
    );
  }

  Widget _registrationProgressTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: List.generate(_registrationStepTitles.length, (index) {
          final selected = index == _registrationStep;
          final completed = index < _registrationStep;
          final showConnector = index < _registrationStepTitles.length - 1;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() {
                _registrationStep = index;
                _validationTriggeredStep = null;
              }),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: completed
                                  ? AppColors.blackCat.withValues(alpha: 0.55)
                                  : AppColors.blackCat.withValues(alpha: 0.18),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 6),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (selected || completed)
                                ? AppColors.blackCat
                                : AppColors.blackCat.withValues(alpha: 0.10),
                          ),
                          child: completed
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: AppColors.snow,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontFamily: 'Arial',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppColors.snow
                                        : AppColors.blackCat,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        if (showConnector)
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: (completed || selected)
                                  ? AppColors.blackCat.withValues(alpha: 0.55)
                                  : AppColors.blackCat.withValues(alpha: 0.18),
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: Text(
                      _registrationStepTitles[index],
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 9,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: AppColors.blackCat.withValues(
                          alpha: selected ? 1 : 0.65,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    color: selected ? AppColors.blackCat : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _goToNextRegistrationStep() async {
    if (!await _validateCurrentRegistrationStep()) return;
    await _persistRegistrationDraftStep(step: _registrationStep + 1);
    if (!mounted) return;
    setState(() {
      _registrationStep += 1;
      _validationTriggeredStep = null;
    });
  }

  Widget _wizardNavButtons() {
    final isLast = _registrationStep == _registrationStepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      color: AppColors.snow,
      child: Row(
        children: [
          if (_registrationStep > 0)
            SizedBox(
              height: 44,
              width: 96,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  side: const BorderSide(color: AppColors.blackCatBorderLight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => setState(() {
                  _registrationStep -= 1;
                  _validationTriggeredStep = null;
                }),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 96),
          const Spacer(),
          SizedBox(
            height: 44,
            width: isLast ? 170 : 96,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : isLast
                  ? ((_bundlePurchased && _canStartCheckout) ? _continue : null)
                  : _goToNextRegistrationStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                disabledBackgroundColor: AppColors.blackCat.withValues(
                  alpha: 0.16,
                ),
                foregroundColor: AppColors.snow,
                shape: const RoundedRectangleBorder(
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.snow,
                        ),
                      ),
                    )
                  : Text(
                      isLast ? 'Create account' : 'Next',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: AppColors.snow,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _currentRegistrationStepWidgets() {
    switch (_registrationStep) {
      case 0:
        return <Widget>[
          _basicProfileSection(),
          const SizedBox(height: 8),
          _addressInfoSection(),
        ];
      case 1:
        return <Widget>[
          _nailMeasurementApiSection(),
          const SizedBox(height: 8),
          _nailPreferencesSection(),
        ];
      case 2:
        return <Widget>[_portfolioSection()];
      case 3:
        return <Widget>[
          _specializationPricingSection(),
          const SizedBox(height: 8),
          _locationServiceAreaSection(),
          const SizedBox(height: 8),
          _yearCalendarSection(),
        ];
      case 4:
        return <Widget>[
          _paymentMethodSection(),
          const SizedBox(height: 8),
          _payoutSection(),
        ];
      case 5:
      default:
        return <Widget>[
          _accountCredentialsSection(),
          const SizedBox(height: 8),
          _bundlesSection(),
          if (widget.showAdaCompliance) ...<Widget>[
            const SizedBox(height: 8),
            _agreementsSection(),
          ],
        ];
    }
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
        appBar: JntModalAppBar(
          onClose: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/register', (route) => false),
          closeTooltip: 'Close client-artist registration',
          closeIcon: const Icon(Icons.close),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _validationTriggeredStep == _registrationStep
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  _registrationProgressTabs(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: _currentRegistrationStepWidgets(),
                      ),
                    ),
                  ),
                  _wizardNavButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NailCaptureStep {
  const _NailCaptureStep({
    required this.key,
    required this.hand,
    required this.finger,
    required this.title,
  });

  final String key;
  final String hand;
  final String finger;
  final String title;
}

class _MeasureStepTile extends StatelessWidget {
  const _MeasureStepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.blackCat,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                color: AppColors.snow,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinReference {
  const _CoinReference({
    required this.group,
    required this.name,
    required this.diameterMm,
    required this.icon,
  });

  final String group;
  final String name;
  final double diameterMm;
  final String icon;
}

const List<_CoinReference> _coinReferences = <_CoinReference>[
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Penny (1¢)',
    diameterMm: 19.05,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Nickel (5¢)',
    diameterMm: 21.21,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Dime (10¢)',
    diameterMm: 17.91,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'UNITED STATES',
    name: 'US Quarter (25¢)',
    diameterMm: 24.26,
    icon: '🇺🇸',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian Quarter',
    diameterMm: 23.88,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian Dollar (Loonie)',
    diameterMm: 26.50,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'CANADA',
    name: 'Canadian 2 Dollar (Toonie)',
    diameterMm: 28.00,
    icon: '🇨🇦',
  ),
  _CoinReference(
    group: 'MEXICO',
    name: 'Mexico 10 Peso',
    diameterMm: 28.00,
    icon: '🇲🇽',
  ),
];

class _CoinSelectorPage extends StatefulWidget {
  const _CoinSelectorPage({required this.items, required this.progressText});

  final List<_CoinReference> items;
  final String progressText;

  @override
  State<_CoinSelectorPage> createState() => _CoinSelectorPageState();
}

class _CoinSelectorPageState extends State<_CoinSelectorPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.items
        .where((e) {
          if (query.isEmpty) return true;
          return e.name.toLowerCase().contains(query) ||
              e.group.toLowerCase().contains(query);
        })
        .toList(growable: false);

    String? previousGroup;
    final groupedWidgets = <Widget>[];
    for (final item in filtered) {
      if (previousGroup != item.group) {
        previousGroup = item.group;
        groupedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              item.group,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      }
      groupedWidgets.add(
        InkWell(
          onTap: () => Navigator.pop(context, item.name),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.diameterMm.toStringAsFixed(2)}mm diameter',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat.withValues(alpha: 0.65),
                        ),
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

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Select Coin / Currency',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choose the coin or currency you will place next to your nail.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.progressText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search coin or country',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: ListView(children: groupedWidgets)),
            ],
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
