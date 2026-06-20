// lib/pages/artist_registration_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;

import '../services/address_validation_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/auth_email_alias_service.dart';
import '../config/auth_flags.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';
import '../constants/currency_options.dart';
import 'artist_checkout_page.dart';
import 'artist_login_page.dart';
import 'artist_shell_page.dart';
import 'email_verification_pending_page.dart';
import '../widgets/direct_request_year_calendar.dart';
import '../widgets/registration_profile_upload.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';

const Color _artistRegSnow = AppColors.snow;
const Color _artistRegInk = AppColors.blackCat;
const Color snow = AppColors.snow;

class ArtistRegistrationPage extends StatefulWidget {
  const ArtistRegistrationPage({super.key, this.showAdaCompliance = false});

  final bool showAdaCompliance;

  @override
  State<ArtistRegistrationPage> createState() => _ArtistRegistrationPageState();
}

enum PayoutMethod { paypal, venmo, bankTransfer, applePay }

enum NailTechType { professional, student }

class _ArtistRegistrationPageState extends State<ArtistRegistrationPage> {
  static const int _maxPortfolioImageBytes = 2 * 1024 * 1024; // <2MB
  static const int _portfolioMaxEdge = 1600;
  static const Set<String> _allowedPortfolioExts = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };
  final _formKey = GlobalKey<FormState>();

  // TEMP: allow registration even if bundle checkout isn't complete.
  // Flip to false when checkout is enforced.
  static const bool kAllowRegistrationWithoutCheckout = false;

  bool _submitting = false;
  String _submitStatus = 'Create Artist Account';

  // ✅ Only allow create if all required gates are true
  bool get _canCreateArtistAccount =>
      _paymentSaved &&
      _bundlePurchased &&
      (!widget.showAdaCompliance ||
          (_agreeTerms && _noCopyright && _agreeSafety));

  // -----------------------
  // Profile image (tap avatar to upload)
  // -----------------------
  final ImagePicker _picker = ImagePicker();
  Uint8List? _profileBytes;

  // -----------------------
  // Account credentials
  // -----------------------
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // -----------------------
  // ✅ Artist Profile (AFTER Account Credentials)
  // -----------------------
  final _studioNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _languageSpokenCtrl = TextEditingController();
  String? _currency = 'US Dollar (USD)';
  //String? _experience; // dropdown
  final _bioCtrl = TextEditingController();

  // -----------------------
  // Location & Service
  // -----------------------
  final _cityCtrl = TextEditingController();
  final _addressCityCtrl = TextEditingController();
  final _manualStateCtrl = TextEditingController();
  final _addressLine1Ctrl = TextEditingController();
  final _addressLine2Ctrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final bool _isShippingAddressSame = true;
  final _shippingAddressLine1Ctrl = TextEditingController();
  final _shippingAddressLine2Ctrl = TextEditingController();
  final _shippingCityCtrl = TextEditingController();
  final _shippingStateCtrl = TextEditingController();
  final _shippingZipCtrl = TextEditingController();
  final _shippingCountryCtrl = TextEditingController();
  final _shippingTimeZoneCtrl = TextEditingController();
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
  // Services & Pricing
  // -----------------------
  final Set<String> _services = {'Custom Press-ons', 'Nail Art'};
  final _minPriceCtrl = TextEditingController(text: '15');
  final _maxPriceCtrl = TextEditingController(text: '5000');
  bool _rush = false;
  // -----------------------
  // Year Calendar Availability (NEW)
  // -----------------------
  bool _directRequestsEnabled = true;
  bool _showYearCalendar = false;
  int _yearCalendarNonce = 0;

  int _directRequestYear = DateTime.now().year;
  final Set<DateTime> _blockedDates = <DateTime>{};

  // store blocked dates/months (backend-ready)
  //  final Set<int> _blockedMonths = {}; // 1–12

  // -----------------------
  // Availability (sample)
  // -----------------------
  //final Set<String> _days = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  //String _startTime = '10:00 AM';
  //String _endTime = '6:00 PM';
  //String _duration = '15 min';
  //String _bufferTime = '10 min';
  //String _leadTime = '24 hours';
  //bool _sameDay = false;

  // -----------------------
  // ✅ Portfolio (below Availability per your request)
  // ✅ add upload images ABOVE "No previous projects uploaded yet"
  // -----------------------
  final List<Uint8List> _portfolioImages = [];
  String? _lastPortfolioUploadErrorDetail;
  final _projectNotesCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _portfolioLinkCtrl = TextEditingController();
  NailTechType _nailTechType = NailTechType.professional;

  // Professional fields
  final _licenseCtrl = TextEditingController();
  String? _jurisdiction; // dropdown (use usStates)
  String? _proYearsExp; // dropdown

  // Student/Unlicensed fields
  final _schoolCtrl = TextEditingController();
  String? _practiceDuration; // dropdown

  static const List<String> practiceDurations = [
    '< 3 months',
    '3–6 months',
    '6–12 months',
    '1–2 years',
    '2+ years',
  ];

  static const List<String> proYearsOptions = [
    '0–1 years (Beginner)',
    '1–3 years (Intermediate)',
    '3–5 years (Skilled)',
    '5–10 years (Advanced)',
    '10+ years (Expert)',
  ];
  // -----------------------
  // Font sizes (match ClientRegistrationPage)
  // -----------------------
  static const double _titleFs = 16; // section title
  static const double _subFs = 14; // section subtitle / helper text
  static const double _labelFs = 16; // input label
  static const double _hintFs = 12.5; // input hint
  static const double _inputFs = 13; // typed text
  static const double _paymentInputFs = 12; // payment method field text
  static const double _chipFs = 13; // chip text
  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 14;

  // -----------------------
  // Payment Method (for bundle checkout)
  // -----------------------
  String _paymentMethod = 'PayPal';

  // PayPal
  final _paypalEmailCtrl = TextEditingController();

  // Venmo
  final _venmoHandleCtrl = TextEditingController(); // @handle OR phone/email

  // Apple Pay
  final _applePayPaymentNameCtrl = TextEditingController();
  final _applePayPaymentPhoneCtrl = TextEditingController();
  final _applePayPaymentEmailCtrl = TextEditingController();

  // Credit Card
  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController(); // MM/YY
  final _cardCvvCtrl = TextEditingController();
  final _cardZipCtrl = TextEditingController();

  bool _paymentSaved = false;

  bool _isValidEmail(String v) => v.contains('@') && v.contains('.');
  bool _isDigits(String v) => RegExp(r'^\d+$').hasMatch(v);

  String _selectedBundle = 'Starter';
  bool _bundlePurchased = false;

  PayoutMethod _payoutMethod = PayoutMethod.paypal;

  // payout: PayPal/Venmo/Bank
  final _legalNameCtrl = TextEditingController();
  final _payoutEmailCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _routingCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  // ✅ payout: Apple Pay fields
  final _applePayNameCtrl = TextEditingController();
  final _applePayPhoneCtrl = TextEditingController();
  final _applePayEmailCtrl = TextEditingController();

  bool _agreeTerms = false;
  bool _noCopyright = false;
  bool _agreeSafety = false;
  bool _receiveUpdates = true;

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
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'India',
    'Germany',
    'France',
    'Japan',
    'Mexico',
    'Brazil',
  ];

  Map<String, dynamic> _buildArtistFirestorePayload({
    required String uid,
    String profilePhotoUrl = '',
    List<String> portfolioImageUrls = const <String>[],
  }) {
    final billingCountry = _selectedCountry.trim();
    final shippingCountry = _isShippingAddressSame
        ? billingCountry
        : _shippingCountryCtrl.text.trim();
    final shippingTimeZone = _isShippingAddressSame
        ? _timeZone
        : _shippingTimeZoneCtrl.text.trim();
    final shippingAddressLine1 = _isShippingAddressSame
        ? _addressLine1Ctrl.text.trim()
        : _shippingAddressLine1Ctrl.text.trim();
    final shippingAddressLine2 = _isShippingAddressSame
        ? _addressLine2Ctrl.text.trim()
        : _shippingAddressLine2Ctrl.text.trim();
    final shippingCity = _isShippingAddressSame
        ? _addressCityCtrl.text.trim()
        : _shippingCityCtrl.text.trim();
    final shippingState = _isShippingAddressSame
        ? _resolvedState
        : _shippingStateCtrl.text.trim();
    final shippingZip = _isShippingAddressSame
        ? _zipCtrl.text.trim()
        : _shippingZipCtrl.text.trim();

    final portfolioItems = portfolioImageUrls
        .map((url) => <String, dynamic>{'imageUrl': url, 'style': 'All'})
        .toList(growable: false);
    final portfolioImageCount = portfolioImageUrls.isNotEmpty
        ? portfolioImageUrls.length
        : _portfolioImages.length;
    final payout = _normalizedPayoutPayload();

    return {
      'uid': uid,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'accountType': 'artist',
      'roles': {'client': false, 'artist': true, 'company': false},
      // Panel-friendly top-level columns
      'panel_studioName': _studioNameCtrl.text.trim(),
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
      'panel_city': _cityCtrl.text.trim(),
      'panel_state': _resolvedState,
      'panel_country': billingCountry,
      'panel_addressLine1': _addressLine1Ctrl.text.trim(),
      'panel_addressCity': _addressCityCtrl.text.trim(),
      'panel_addressLine2': _addressLine2Ctrl.text.trim(),
      'panel_zip': _zipCtrl.text.trim(),
      'panel_isShippingAddressSame': _isShippingAddressSame,
      'panel_shippingAddressLine1': shippingAddressLine1,
      'panel_shippingAddressLine2': shippingAddressLine2,
      'panel_shippingCity': shippingCity,
      'panel_shippingState': shippingState,
      'panel_shippingZip': shippingZip,
      'panel_shippingCountry': shippingCountry,
      'panel_shippingTimeZone': shippingTimeZone,
      'panel_nailTechType': _nailTechType.name,
      'panel_services': _services.toList(),
      'panel_minPrice': _minPriceCtrl.text.trim(),
      'panel_maxPrice': _maxPriceCtrl.text.trim(),
      'panel_rushAvailable': _rush,
      'panel_directRequestsEnabled': _directRequestsEnabled,
      'panel_directRequestYear': _directRequestYear,
      'panel_blockedDates': _blockedDates
          .map((d) => d.toIso8601String())
          .toList(),
      'panel_projectNotes': _projectNotesCtrl.text.trim(),
      'panel_portfolioLink': _portfolioLinkCtrl.text.trim(),
      'panel_portfolioImageCount': portfolioImageCount,
      'panel_portfolioImages': portfolioImageUrls,
      'panel_licenseNumber': _licenseCtrl.text.trim(),
      'panel_jurisdiction': (_jurisdiction ?? '').trim(),
      'panel_proYearsExperience': (_proYearsExp ?? '').trim(),
      'panel_school': _schoolCtrl.text.trim(),
      'panel_practiceDuration': (_practiceDuration ?? '').trim(),
      'panel_selectedBundle': _selectedBundle,
      'panel_bundlePurchased': _bundlePurchased,
      'panel_bundlePaymentSaved': _paymentSaved,
      'panel_bundlePaymentMethod': _paymentMethod,
      'panel_bundlePaypalEmail': _paypalEmailCtrl.text.trim(),
      'panel_bundleVenmoHandle': _venmoHandleCtrl.text.trim(),
      'panel_payout': payout,
      'panel_payoutMethod': _payoutMethod.name,
      'panel_payoutLegalName': _legalNameCtrl.text.trim(),
      'panel_payoutEmail': _payoutEmailCtrl.text.trim(),
      'panel_profileImageUrl': profilePhotoUrl.trim(),
      'panel_agreeTerms': _agreeTerms,
      'panel_noCopyright': _noCopyright,
      'panel_agreeSafety': _agreeSafety,
      'panel_receiveUpdates': _receiveUpdates,
      'photoUrl': profilePhotoUrl.trim(),
      'avatarUrl': profilePhotoUrl.trim(),
      'profile': {
        'studioName': _studioNameCtrl.text.trim(),
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
        'city': _cityCtrl.text.trim(),
        'state': _resolvedState,
        'country': billingCountry,
        'addressLine1': _addressLine1Ctrl.text.trim(),
        'addressCity': _addressCityCtrl.text.trim(),
        'addressLine2': _addressLine2Ctrl.text.trim(),
        'zip': _zipCtrl.text.trim(),
        'shippingAddress': {
          'isSameAsBilling': _isShippingAddressSame,
          'addressLine1': shippingAddressLine1,
          'addressLine2': shippingAddressLine2,
          'city': shippingCity,
          'state': shippingState,
          'zip': shippingZip,
          'country': shippingCountry,
          'timeZone': shippingTimeZone,
        },
        'nailTechType': _nailTechType.name,
      },
      'languageSpoken': _languageSpokenCtrl.text.trim(),
      'currency': (_currency ?? '').trim(),
      'services': _services.toList(),
      'pricing': {
        'minPrice': _minPriceCtrl.text.trim(),
        'maxPrice': _maxPriceCtrl.text.trim(),
        'rushAvailable': _rush,
      },
      'availability': {
        'directRequestsEnabled': _directRequestsEnabled,
        'blockedDates': _blockedDates.map((d) => d.toIso8601String()).toList(),
        'directRequestYear': _directRequestYear,
      },
      'portfolio': {
        'projectNotes': _projectNotesCtrl.text.trim(),
        'portfolioLink': _portfolioLinkCtrl.text.trim(),
        'imageCount': portfolioImageCount,
        'images': portfolioImageUrls,
        'items': portfolioItems,
      },
      'portfolioImages': portfolioImageUrls,
      'portfolioItems': portfolioItems,
      'credentials': {
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
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  String _paymentDetailForCheckout() {
    switch (_paymentMethod) {
      case 'PayPal':
        return _paypalEmailCtrl.text.trim();
      case 'Venmo':
        return _venmoHandleCtrl.text.trim();
      case 'Apple Pay':
        final name = _applePayPaymentNameCtrl.text.trim();
        final phone = _applePayPaymentPhoneCtrl.text.trim();
        final email = _applePayPaymentEmailCtrl.text.trim();
        return '$name • $phone • $email';
      case 'Credit Card':
        final last4 = _cardNumberCtrl.text.trim();
        final last = last4.length >= 4
            ? last4.substring(last4.length - 4)
            : last4;
        return '${_cardNameCtrl.text.trim()} • **** $last • ${_cardExpiryCtrl.text.trim()}';
      default:
        return '';
    }
  }

  Map<String, dynamic> _normalizedPayoutPayload() {
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

  bool _paymentFieldsValid() {
    if (_paymentMethod == 'PayPal') {
      final v = _paypalEmailCtrl.text.trim();
      return v.isNotEmpty && _isValidEmail(v);
    }

    if (_paymentMethod == 'Venmo') {
      final v = _venmoHandleCtrl.text.trim();
      return v.isNotEmpty; // allow @handle or phone/email
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

  static const List<String> timeZones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
  ];

  @override
  void initState() {
    super.initState();
    _shippingCountryCtrl.text = _selectedCountry;
    _shippingTimeZoneCtrl.text = _timeZone;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();

    _studioNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _languageSpokenCtrl.dispose();
    _bioCtrl.dispose();

    _cityCtrl.dispose();
    _addressCityCtrl.dispose();
    _manualStateCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _zipCtrl.dispose();
    _shippingAddressLine1Ctrl.dispose();
    _shippingAddressLine2Ctrl.dispose();
    _shippingCityCtrl.dispose();
    _shippingStateCtrl.dispose();
    _shippingZipCtrl.dispose();
    _shippingCountryCtrl.dispose();
    _shippingTimeZoneCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();

    _projectNotesCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _portfolioLinkCtrl.dispose();
    _licenseCtrl.dispose();
    _schoolCtrl.dispose();
    _paypalEmailCtrl.dispose();

    _legalNameCtrl.dispose();
    _payoutEmailCtrl.dispose();

    _bankNameCtrl.dispose();
    _routingCtrl.dispose();
    _accountNumberCtrl.dispose();

    _applePayNameCtrl.dispose();
    _applePayPhoneCtrl.dispose();
    _applePayEmailCtrl.dispose();
    _venmoHandleCtrl.dispose();

    _applePayPaymentNameCtrl.dispose();
    _applePayPaymentPhoneCtrl.dispose();
    _applePayPaymentEmailCtrl.dispose();

    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardZipCtrl.dispose();

    super.dispose();
  }

  // -----------------------
  // Pickers
  // -----------------------
  Future<void> _pickProfilePic() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _profileBytes = bytes);
  }

  Future<void> _pickPortfolioImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;

    final bytesList = <Uint8List>[];
    int rejectedType = 0;
    int rejectedSize = 0;
    int rejectedDecode = 0;

    for (final f in files) {
      if (!_isAllowedPortfolioFile(f)) {
        rejectedType++;
        continue;
      }
      final raw = await f.readAsBytes();
      final optimized = _optimizePortfolioBytes(raw);
      if (optimized == null) {
        rejectedDecode++;
        continue;
      }
      if (optimized.lengthInBytes > _maxPortfolioImageBytes) {
        rejectedSize++;
        continue;
      }
      bytesList.add(optimized);
    }
    if (!mounted) return;
    if (bytesList.isNotEmpty) {
      setState(() => _portfolioImages.addAll(bytesList));
    }

    if (rejectedSize > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload failed for one or more files: each image must be less than 2MB.',
          ),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
    }

    final summary = <String>[];
    if (bytesList.isNotEmpty) summary.add('${bytesList.length} added');
    if (rejectedType > 0) summary.add('$rejectedType invalid format');
    if (rejectedDecode > 0) summary.add('$rejectedDecode unreadable');
    if (summary.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Portfolio upload: ${summary.join(', ')}.')),
      );
    }
  }

  bool _isAllowedPortfolioFile(XFile file) {
    final name = file.name.trim().isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = name.substring(dot).toLowerCase();
    return _allowedPortfolioExts.contains(ext);
  }

  Uint8List? _optimizePortfolioBytes(
    Uint8List source, {
    int maxEdge = _portfolioMaxEdge,
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

    // Final aggressive fallback for large images.
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
    final uploadedUrls = <String>[];

    for (var i = 0; i < _portfolioImages.length; i++) {
      Uint8List bytes = _portfolioImages[i];

      final optimized = _optimizePortfolioBytes(bytes);
      if (optimized != null && optimized.isNotEmpty) {
        bytes = optimized;
      }

      if (bytes.lengthInBytes > _maxPortfolioImageBytes) {
        _lastPortfolioUploadErrorDetail ??=
            'Selected image exceeds 2MB after optimization.';
        continue;
      }

      final path = 'artists/$uid/portfolio/${now}_${i + 1}.jpg';

      try {
        await storage.uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

        final publicUrl = storage.getPublicUrl(path).trim();

        debugPrint('ARTIST PORTFOLIO URL ${i + 1} = $publicUrl');

        if (publicUrl.isNotEmpty) {
          uploadedUrls.add(publicUrl);
        }
      } catch (e) {
        _lastPortfolioUploadErrorDetail ??= e.toString();
        debugPrint('ARTIST PORTFOLIO UPLOAD FAILED ${i + 1}: $e');
      }
    }

    return uploadedUrls;
  }

  Future<String> _uploadProfileImage(String uid) async {
    final bytes = _profileBytes;

    debugPrint('ARTIST PROFILE BYTES NULL = ${bytes == null}');
    debugPrint('ARTIST PROFILE BYTES LENGTH = ${bytes?.length ?? 0}');

    if (bytes == null || bytes.isEmpty) return '';

    Uint8List optimizedProfileBytes(Uint8List source) {
      final decoded = img.decodeImage(source);
      if (decoded == null) return source;

      img.Image processed = decoded;
      final maxSide = processed.width > processed.height
          ? processed.width
          : processed.height;

      if (maxSide > 700) {
        final scale = 700 / maxSide;
        processed = img.copyResize(
          processed,
          width: (processed.width * scale).round(),
          height: (processed.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }

      return Uint8List.fromList(img.encodeJpg(processed, quality: 62));
    }

    final optimizedBytes = optimizedProfileBytes(bytes);
    final path = 'artists/$uid/profile/avatar.jpg';

    try {
      final storage = Supabase.instance.client.storage.from('profile-pictures');

      await storage.uploadBinary(
        path,
        optimizedBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final publicUrl = storage.getPublicUrl(path).trim();

      debugPrint('ARTIST SUPABASE PROFILE URL = $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('ARTIST SUPABASE PROFILE UPLOAD FAILED: $e');
      return '';
    }
  }

  // -----------------------
  // UI helpers
  // -----------------------
  InputDecoration _dec(String label, String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: _hintFs,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
      labelStyle: TextStyle(fontSize: _labelFs, color: AppColors.blackCat),
      errorStyle: const TextStyle(
        fontSize: 10.5,
        height: 1.1,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.snow,
      suffixIcon: suffixIcon,
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _fieldVerticalPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.blackCat.withValues(alpha: 0.35),
          width: 1.4,
        ),
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
          color: _artistRegSnow,
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
                    fontSize: _inputFs,
                    color: AppColors.blackCat,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _firstExactMatch(List<String> options, String input) {
    final needle = input.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final option in options) {
      if (option.trim().toLowerCase() == needle) return option;
    }
    return null;
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
                        color: AppColors.blackCat,
                      ),
                      decoration: _dec(
                        label,
                        hint,
                      ).copyWith(fillColor: AppColors.snow),
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
                      color: AppColors.snow,
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
                                  color: AppColors.blackCat,
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
                style: const TextStyle(fontSize: 10.5, color: Colors.red),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
    Gradient? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _artistRegSnow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'ArialBold',
              color: AppColors.blackCat,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.blackCat,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blackCat.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? AppColors.blackCat
                : AppColors.blackCat.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: AppColors.blackCat),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: _chipFs,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requiredFieldLabel(String text) {
    return const SizedBox.shrink();
  }

  Widget _fieldLabel(String text) {
    return const SizedBox.shrink();
  }

  Widget _techTypeToggle() {
    Widget option({required NailTechType type, required String label}) {
      final selected = _nailTechType == type;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => setState(() => _nailTechType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: selected
                    ? AppColors.blackCat
                    : AppColors.blackCat.withValues(alpha: 0.08),
                width: selected ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: _inputFs,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 22,
                    color: AppColors.blackCat,
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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
              label: 'Student / Unlicensed Nail Technician',
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

          DropdownButtonFormField<String>(
            initialValue: _proYearsExp,
            style: const TextStyle(
              fontSize: _inputFs,
              color: AppColors.blackCat,
              fontWeight: FontWeight.w400,
            ),
            dropdownColor: AppColors.snow,
            decoration: _dec(
              'Years of Experience *',
              'Select years of experience',
            ),
            items: proYearsOptions
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: _inputFs,
                        color: AppColors.blackCat,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _proYearsExp = v),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Years of experience is required'
                : null,
          ),
        ],
      );
    }

    // Student / Unlicensed
    return Column(
      children: [
        TextFormField(
          controller: _schoolCtrl,
          style: const TextStyle(fontSize: _inputFs),
          decoration: _dec(
            'School / Training Program *',
            'Enter school or program name',
          ),
          validator: (v) {
            if (_nailTechType != NailTechType.student) return null;
            if (v == null || v.trim().isEmpty) {
              return 'School/Program is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),

        DropdownButtonFormField<String>(
          initialValue: _practiceDuration,
          style: const TextStyle(
            fontSize: _inputFs,
            color: AppColors.blackCat,
            fontWeight: FontWeight.w400,
          ),
          decoration: _dec(
            'How long have you been practicing? *',
            'Select duration',
          ),
          items: practiceDurations
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: _inputFs,
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _practiceDuration = v),
          validator: (v) {
            if (_nailTechType != NailTechType.student) return null;
            if (v == null || v.trim().isEmpty) {
              return 'Practice duration is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _profilePicTile() {
    return RegistrationProfileUpload(
      onTap: _pickProfilePic,
      imageBytes: _profileBytes,
      // label: 'Profile picture',
      // helperText: 'Tap to upload your profile photo',
    );
  }

  Future<void> _openBundleCheckout({
    required String bundleKey,
    required String title,
    required String subtitle,
    required String priceText,
    required String imageAsset,
  }) async {
    final String prefilledArtistName = _displayNameCtrl.text.trim().isNotEmpty
        ? _displayNameCtrl.text.trim()
        : (_studioNameCtrl.text.trim().isNotEmpty
              ? _studioNameCtrl.text.trim()
              : _emailCtrl.text.trim());
    final String prefilledCountry = _selectedCountry.trim();
    final String shippingCountry = _isShippingAddressSame
        ? prefilledCountry
        : _shippingCountryCtrl.text.trim();
    final String shippingTimeZone = _isShippingAddressSame
        ? _timeZone
        : _shippingTimeZoneCtrl.text.trim();

    // Build checkout data from current registration fields.
    final info = ArtistCheckoutInfo(
      artistName: prefilledArtistName,
      email: _emailCtrl.text.trim(),
      phone: _fullPhone,
      city: _cityCtrl.text.trim(),
      state: _resolvedState,
      timeZone: _timeZone,
      addressLine1: _addressLine1Ctrl.text.trim(),
      addressLine2: _addressLine2Ctrl.text.trim(),
      zip: _zipCtrl.text.trim(),
      country: prefilledCountry,
      isShippingAddressSame: _isShippingAddressSame,
      shippingAddressLine1: _isShippingAddressSame
          ? _addressLine1Ctrl.text.trim()
          : _shippingAddressLine1Ctrl.text.trim(),
      shippingAddressLine2: _isShippingAddressSame
          ? _addressLine2Ctrl.text.trim()
          : _shippingAddressLine2Ctrl.text.trim(),
      shippingCity: _isShippingAddressSame
          ? _cityCtrl.text.trim()
          : _shippingCityCtrl.text.trim(),
      shippingState: _isShippingAddressSame
          ? _resolvedState
          : _shippingStateCtrl.text.trim(),
      shippingZip: _isShippingAddressSame
          ? _zipCtrl.text.trim()
          : _shippingZipCtrl.text.trim(),
      shippingCountry: shippingCountry,
      shippingTimeZone: shippingTimeZone,
      paymentMethod: _paymentMethod,
      paymentDetail: _paymentDetailForCheckout(),
      productTitle: title,
      productSubtitle: subtitle,
      productPriceText: priceText,
      productImageAsset: imageAsset,
    );

    final bool purchased =
        (await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (_) => ArtistCheckoutPage(initial: info)),
        )) ??
        false;

    if (purchased) {
      setState(() {
        _bundlePurchased = true;
        _selectedBundle = bundleKey;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before continuing.'),
        ),
      );
      return;
    }

    if (_instagramCtrl.text.trim().isEmpty && _tiktokCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide at least one social media detail: Instagram or TikTok.',
          ),
        ),
      );
      return;
    }

    if (_isUnitedStates && !kIsWeb) {
      final cityStateValidation =
          await AddressValidationService.validateUsCityState(
            city: _cityCtrl.text.trim(),
            state: _resolvedState,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => const AddressValidationResult(
              isValid: false,
              message: 'Unable to validate city/state right now. Try again.',
            ),
          );

      if (!cityStateValidation.isValid) {
        final message = cityStateValidation.message ?? '';
        final isTransientValidationFailure =
            message.contains('Network error') ||
            message.contains('Unable to validate') ||
            message.contains('Unexpected response');

        if (isTransientValidationFailure) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$message Continuing with registration.')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cityStateValidation.message ??
                    'Invalid U.S. city/state combination.',
              ),
            ),
          );
          return;
        }
      }
    }

    if (!mounted) return;

    if (!kAllowRegistrationWithoutCheckout) {
      if (!_canCreateArtistAccount) {
        final missing = <String>[];
        if (!_paymentSaved) missing.add('save payment details');
        if (!_bundlePurchased) missing.add('purchase a bundle');
        if (widget.showAdaCompliance) {
          if (!_agreeTerms) missing.add('accept Terms & Conditions');
          if (!_noCopyright) missing.add('accept copyright policy');
          if (!_agreeSafety) missing.add('accept safety policy');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete required steps: ${missing.join(', ')}.'),
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

    setState(() {
      _submitting = true;
      _submitStatus = 'Creating account...';
    });

    final firebaseAuth = FirebaseAuth.instance;
    var createdFirebaseUser = false;
    late UserCredential firebaseUserCred;

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text.trim();

      await SupabaseAuthService.logout();
      await firebaseAuth.signOut();

      try {
        firebaseUserCred = await firebaseAuth
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 20));
        createdFirebaseUser = true;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use' &&
            e.code != 'email-already-exists') {
          rethrow;
        }
        firebaseUserCred = await firebaseAuth
            .signInWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 20));
      }
      final firebaseUid = firebaseUserCred.user?.uid;
      if (firebaseUid == null || firebaseUid.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Unable to create Firebase user.',
        );
      }

      dynamic supabaseUser;
      try {
        supabaseUser = await SupabaseAuthService.signup(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 20));
      } on AuthException catch (e) {
        final message = e.message.toLowerCase();
        if (!message.contains('already')) {
          rethrow;
        }
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

      await AuthEmailAliasService.saveAliasMapping(
        loginEmail: email,
        authEmail: supabaseUser?.email ?? email,
        uid: firebaseUid,
      );

      final profilePhotoUrl = await _uploadProfileImage(firebaseUid);

      if (mounted) {
        setState(() => _submitStatus = 'Preparing photos...');
      }

      final portfolioImageUrls = await _uploadPortfolioImages(
        firebaseUid,
      ).timeout(const Duration(seconds: 35), onTimeout: () => <String>[]);

      final remotePortfolioImageUrls = portfolioImageUrls
          .where((u) => !u.trim().startsWith('data:image/'))
          .toList(growable: false);

      final payload = _buildArtistFirestorePayload(
        uid: firebaseUid,
        profilePhotoUrl: profilePhotoUrl,
        portfolioImageUrls: remotePortfolioImageUrls,
      );

      if (mounted) {
        setState(() => _submitStatus = 'Saving profile...');
      }

      final supabase = Supabase.instance.client;

      await supabase.from('artist').upsert({
        'id': supabaseUid,
        'email': email,
        'account_type': 'artist',

        'profile': {
          ...Map<String, dynamic>.from(payload['profile'] as Map),
          'displayName': _displayNameCtrl.text.trim(),
          'studioName': _studioNameCtrl.text.trim(),
          'name': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _studioNameCtrl.text.trim(),
          'fullName': _displayNameCtrl.text.trim().isNotEmpty
              ? _displayNameCtrl.text.trim()
              : _studioNameCtrl.text.trim(),
          'profileImageUrl': profilePhotoUrl.trim(),
          'profilePhotoUrl': profilePhotoUrl.trim(),
          'photoUrl': profilePhotoUrl.trim(),
          'avatarUrl': profilePhotoUrl.trim(),
        },

        'services': payload['services'],
        'pricing': payload['pricing'],
        'availability': payload['availability'],
        'portfolio': payload['portfolio'],
        'credentials': payload['credentials'],
        'bundle': payload['bundle'],
        'payout': payload['payout'],
        'agreements': payload['agreements'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      await FirebaseFirestore.instance
          .collection('artist')
          .doc(firebaseUid)
          .set(payload, SetOptions(merge: true));
      // Firestore portfolio subcollection writes stay disabled for now.

      if (kRequireEmailVerification) {
        try {
          await firebaseUserCred.user?.sendEmailVerification();
        } catch (_) {}
      }

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
        SnackBar(
          content: Text(message.isEmpty ? 'Registration failed.' : message),
        ),
      );
      if (createdFirebaseUser) {
        try {
          await firebaseAuth.currentUser?.delete();
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed.')),
      );
      if (createdFirebaseUser) {
        try {
          await firebaseAuth.currentUser?.delete();
        } catch (_) {}
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request timed out. Please check network and try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed. ${e.toString()}')),
      );
      if (createdFirebaseUser) {
        try {
          await firebaseAuth.currentUser?.delete();
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStatus = 'Create Artist Account';
        });
      }
    }
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final dropdownTextColor = _artistRegInk;
    final dropdownBackground = _artistRegSnow;

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: dropdownBackground,
        switchTheme: const SwitchThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          splashRadius: 12,
        ),
        textTheme: Theme.of(context).textTheme.apply(
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
                // ✅ Artist Profile (AFTER Account Credentials)
                // -----------------------
                _sectionCard(
                  title: 'Artist Profile',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
                  ),
                  child: Column(
                    children: [
                      _profilePicTile(),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _studioNameCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Full Name / Studio Name *',
                          'Full Name / Studio Name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _displayNameCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('Display Name *', 'Display Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _languageSpokenCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Language Spoken *',
                          'Enter language(s) spoken',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 6),

                      _typeAheadPicker(
                        label: 'Currency *',
                        hint: 'Select currency',
                        options: currencyOptions,
                        selectedValue: _currency,
                        onChanged: (v) => setState(() => _currency = v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Currency is required'
                            : null,
                      ),
                      const SizedBox(height: 6),

                      /*   DropdownButtonFormField<String>(
                      value: _experience,
                      decoration: _dec('Years of Experience *', 'Select'),
                      items: const [
                      '0–1 years (Beginner)',
                      '1–3 years (Intermediate)',
                      '3–5 years (Skilled)',
                      '5–10 years (Advanced)',
                      '10+ years (Expert)',]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _experience = v),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 6),*/
                      TextFormField(
                        controller: _bioCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        maxLines: 5,
                        decoration: _dec(
                          'Bio / About *',
                          'Tell clients about you',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                // -----------------------
                // Account Credentials
                // -----------------------
                _sectionCard(
                  title: 'Account Credentials',
                  subtitle: 'Used to sign in to your artist account.',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('Email *', 'Email'),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Email is required';
                          if (!RegistrationInputUtils.isValidEmail(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _passCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        obscureText: _obscurePassword,
                        decoration: _dec(
                          'Password *',
                          'Enter password',
                          suffixIcon: IconButton(
                            iconSize: 18,
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Password is required';
                          if (!RegistrationInputUtils.isStrongPassword(value)) {
                            return 'Use 8+ chars with upper, lower, number, and symbol';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Password must include uppercase, lowercase, number, and symbol.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ✅ Confirm password with eye icon
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Confirm Password *',
                          'Confirm password',
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
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Confirm password is required';
                          }
                          if (v.trim() != _passCtrl.text.trim()) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),

                      FormField<String>(
                        validator: (value) {
                          final digits = RegistrationInputUtils.normalizePhone(
                            _phoneCtrl.text,
                          );
                          return digits.length != 10
                              ? 'Enter exactly 10 digits'
                              : null;
                        },
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
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 106,
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
                                    const SizedBox(width: 8),
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
                                            fontSize: 13,
                                            color: AppColors.blackCat,
                                            fontWeight: FontWeight.w500,
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
                                      fontWeight: FontWeight.w500,
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
                // Location & Service Area
                // -----------------------
                _sectionCard(
                  title: 'Location & Service Area',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF7F2), Color(0xFFF5F0FF)],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cityCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('City *', 'City'),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'City is required';
                          if (!RegExp(r"^[A-Za-z .'-]{2,}$").hasMatch(value)) {
                            return 'Enter a valid city';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const SizedBox(height: 6),
                      _typeAheadPicker(
                        label: 'Country *',
                        hint: 'Select country',
                        options: countries,
                        selectedValue: _selectedCountry,
                        onChanged: (v) {
                          setState(() {
                            _selectedCountry = v ?? 'United States';
                            if (!_isUnitedStates) _state = null;
                            if (_isShippingAddressSame) {
                              _shippingCountryCtrl.text = _selectedCountry;
                            }
                          });
                        },
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Country is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      if (_isUnitedStates) ...[
                        _typeAheadPicker(
                          label: 'State *',
                          hint: 'Select state',
                          options: usStates,
                          selectedValue: _state,
                          onChanged: (v) => setState(() => _state = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'State is required'
                              : null,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _manualStateCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec('State / Region', 'Enter region'),
                          validator: (_) => null,
                        ),
                      ],
                      const SizedBox(height: 6),

                      DropdownButtonFormField<String>(
                        initialValue: _timeZone,
                        style: const TextStyle(
                          fontSize: _inputFs,
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: _dec('Time Zone *', 'America/New_York'),
                        items: timeZones
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: _inputFs,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _timeZone = v ?? _timeZone;
                          if (_isShippingAddressSame) {
                            _shippingTimeZoneCtrl.text = _timeZone;
                          }
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // Address Information
                // -----------------------
                _sectionCard(
                  title: 'Address Information',
                  subtitle:
                      'Provide your shipping address (all fields required)',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _requiredFieldLabel('Street Address'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressLine1Ctrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec(
                          'Street Address',
                          'Enter Street Address',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) {
                            return 'Street Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _requiredFieldLabel('City'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressCityCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        decoration: _dec('City', 'Enter City'),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'City is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _isUnitedStates
                          ? _requiredFieldLabel('State')
                          : _fieldLabel('State / Region'),
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
                      const SizedBox(height: 16),
                      _isUnitedStates
                          ? _requiredFieldLabel('Zip Code')
                          : _fieldLabel('Zip Code'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _zipCtrl,
                        style: const TextStyle(fontSize: _inputFs),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
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
                      const SizedBox(height: 16),
                      _requiredFieldLabel('Country'),
                      const SizedBox(height: 6),
                      _typeAheadPicker(
                        label: 'Country',
                        hint: 'Select Country',
                        options: countries,
                        selectedValue: _selectedCountry,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedCountry = v;
                            if (_selectedCountry != 'United States') {
                              _state = null;
                              _zipCtrl.clear();
                            }
                          });
                        },
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Country is required'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // Services & Pricing
                // -----------------------
                _sectionCard(
                  title: 'Specialization & Pricing',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /*const Text(
                        'Specializations Offered',
                        style: TextStyle(
                          fontSize: _subFs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),*/
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip(
                            'Intricate Nail Art',
                            _services.contains('Intricate Nail Art'),
                            () {
                              setState(
                                () => _services.contains('Intricate Nail Art')
                                    ? _services.remove('Intricate Nail Art')
                                    : _services.add('Intricate Nail Art'),
                              );
                            },
                          ),
                          _chip(
                            'Gel / Acrylic',
                            _services.contains('Gel / Acrylic'),
                            () {
                              setState(
                                () => _services.contains('Gel / Acrylic')
                                    ? _services.remove('Gel / Acrylic')
                                    : _services.add('Gel / Acrylic'),
                              );
                            },
                          ),
                          _chip(
                            '3D Nail Art',
                            _services.contains('3D Nail Art'),
                            () {
                              setState(
                                () => _services.contains('3D Nail Art')
                                    ? _services.remove('3D Nail Art')
                                    : _services.add('3D Nail Art'),
                              );
                            },
                          ),
                          _chip(
                            'Airbrush/Stamping',
                            _services.contains('Airbrush/Stamping'),
                            () {
                              setState(
                                () => _services.contains('Airbrush/Stamping')
                                    ? _services.remove('Airbrush/Stamping')
                                    : _services.add('Airbrush/Stamping'),
                              );
                            },
                          ),
                          _chip(
                            'Encapsulation',
                            _services.contains('Encapsulation '),
                            () {
                              setState(
                                () => _services.contains('Encapsulation ')
                                    ? _services.remove('Encapsulation ')
                                    : _services.add('Encapsulation '),
                              );
                            },
                          ),
                          _chip(
                            'Dip Powder',
                            _services.contains('Dip Powder'),
                            () {
                              setState(
                                () => _services.contains('Dip Powder')
                                    ? _services.remove('Dip Powder')
                                    : _services.add('Dip Powder'),
                              );
                            },
                          ),
                          _chip(
                            'Sculptured',
                            _services.contains('Sculptured'),
                            () {
                              setState(
                                () => _services.contains('Sculptured')
                                    ? _services.remove('Sculptured')
                                    : _services.add('Sculptured'),
                              );
                            },
                          ),
                          _chip('PolyGel', _services.contains('PolyGel'), () {
                            setState(
                              () => _services.contains('PolyGel')
                                  ? _services.remove('PolyGel')
                                  : _services.add('PolyGel'),
                            );
                          }),
                          _chip(
                            'Chrome & Metallic',
                            _services.contains('Chrome & Metallic'),
                            () {
                              setState(
                                () => _services.contains('Chrome & Metallic')
                                    ? _services.remove('Chrome & Metallic')
                                    : _services.add('Chrome & Metallic'),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minPriceCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.number,
                              decoration: _dec('Min Price (\$) *', '50'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxPriceCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.number,
                              decoration: _dec('Max Price (\$) *', '200'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rush availability',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Arial',
                                    color: AppColors.blackCat,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enable if you can take expedited requests.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.blackCat,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Arial',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.88,
                            child: Switch(
                              value: _rush,
                              onChanged: (v) => setState(() => _rush = v),
                              activeThumbColor: const Color(0xFF1F1B24),
                              activeTrackColor: const Color(
                                0xFF1F1B24,
                              ).withValues(alpha: 0.45),
                              inactiveThumbColor: AppColors.blackCatLight,
                              inactiveTrackColor: AppColors.blackCatLight
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ✅ Year Calendar Availability (UPDATED to use the real multi-month calendar widget)
                // Requires:
                // 1) import '../widgets/direct_request_year_calendar.dart';
                // 2) state vars: bool _directRequestsEnabled, bool _showYearCalendar;
                //    int _directRequestYear; Set<DateTime> _blockedDates;
                _sectionCard(
                  title: 'Year Calendar Availability',
                  subtitle:
                      'Control when your Direct Request button is available. '
                      'Block off specific days, weeks, or months. Optional.',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Direct Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'ArialBold',
                              color: AppColors.blackCat,
                            ),
                          ),
                          const Spacer(),
                          Transform.scale(
                            scale: 0.88,
                            child: Switch(
                              value: _directRequestsEnabled,
                              onChanged: (v) =>
                                  setState(() => _directRequestsEnabled = v),
                              activeThumbColor: const Color(0xFF1F1B24),
                              activeTrackColor: const Color(
                                0xFF1F1B24,
                              ).withValues(alpha: 0.45),
                              inactiveThumbColor: AppColors.blackCatLight,
                              inactiveTrackColor: AppColors.blackCatLight
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _directRequestsEnabled
                            ? 'Clients can send Direct Requests on unblocked dates.'
                            : 'Direct Requests are currently turned OFF.',
                        style: TextStyle(
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Arial',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: Icon(
                            _showYearCalendar
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () => setState(() {
                            _showYearCalendar = !_showYearCalendar;
                            if (_showYearCalendar) {
                              _yearCalendarNonce =
                                  DateTime.now().millisecondsSinceEpoch;
                            }
                          }),
                        ),
                      ),

                      // Collapsible calendar
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.snow,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppColors.blackCat.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ This is the actual multi-month calendar UI (year dropdown + day/week/month block)
                              DirectRequestYearCalendar(
                                key: ValueKey(_yearCalendarNonce),
                                initialDirectRequestsOn: _directRequestsEnabled,
                                initialYear: _directRequestYear,
                                initialMonth: DateTime.now().month,
                                initialBlockedDays: _blockedDates,
                                showDirectRequestsFooter: false,
                                onChanged: (directOn, year, blocked) {
                                  // keep parent state in sync
                                  setState(() {
                                    _directRequestsEnabled = directOn;
                                    _directRequestYear = year;
                                    _blockedDates
                                      ..clear()
                                      ..addAll(blocked);
                                  });
                                },
                              ),

                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tip: Tap a day to block it. Tap the left week strip to block a week. '
                                      'Tap the month title to block the whole month.',
                                      style: TextStyle(
                                        color: AppColors.blackCat.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontWeight: FontWeight.w400,
                                        fontSize: 13,
                                        fontFamily: 'Arial',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _showYearCalendar
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),

                // -----------------------
                // Availability & Booking
                // -----------------------
                /*_sectionCard(
                title: 'Your Calendar',
                subtitle: 'Provide your working days and timings',
                gradient: const LinearGradient(colors: [Color(0xFFEAF7F2), Color(0xFFF5F0FF)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Working Days', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d) {
                        final selected = _days.contains(d);
                        return _chip(d, selected, () {
                          setState(() => selected ? _days.remove(d) : _days.add(d));
                        });
                      }).toList(),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _startTime = '10:00 AM'),
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 18,
                                    color: AppColors.blackCat.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Start Time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.blackCat.withValues(alpha: 0.55),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _startTime,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.blackCat.withValues(alpha: 0.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _endTime = '6:00 PM'),
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 18,
                                    color: AppColors.blackCat.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'End Time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.blackCat.withValues(alpha: 0.55),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _endTime,
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.blackCat.withValues(alpha: 0.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    const Text('Appointment Durations', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      children: ['15 min','30 min','60 min'].map((d) {
                        return _chip(d, _duration == d, () => setState(() => _duration = d));
                      }).toList(),
                    ),
                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      value: _bufferTime,
                      style: const TextStyle(color: Colors.black),
                      decoration: _dec('Buffer Time (mins)', '10 min'),
                      items: ['5 min','10 min','15 min','20 min']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v,
                                style: const TextStyle(color: Colors.black),),
                          ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _bufferTime = v ?? _bufferTime),
                    ),
                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      value: _leadTime,
                      style: const TextStyle(color: Colors.black),
                      decoration: _dec('Booking Lead Time', '24 hours'),
                      items: ['12 hours','24 hours','48 hours']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v,
                                style: const TextStyle(color: Colors.black),),
                          ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _leadTime = v ?? _leadTime),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Expanded(
                          child: Text('Allow same-day bookings', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        Transform.scale(scale: 0.88, child: Switch(
                          value: _sameDay,
                          onChanged: (v) => setState(() => _sameDay = v),
                          activeColor: AppColors.deepPlum,
                          inactiveThumbColor: AppColors.blackCatLight,
                          inactiveTrackColor:
                              AppColors.blackCatLight.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ],
                ),
              ),*/
                const SizedBox(height: 14),

                // -----------------------
                // ✅ Portfolio (below availability)
                // ✅ upload images ABOVE the "No previous projects..." row
                // -----------------------
                _sectionCard(
                  title: 'Portfolio',
                  subtitle:
                      'Upload Previous Art. (${_portfolioImages.length} photo(s))',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ NEW: "I am" section right after Portfolio heading
                      _techTypeToggle(),
                      const SizedBox(height: 6),
                      _techTypeFields(),

                      const SizedBox(height: 6),

                      // ✅ Upload previous projects (single header + single Upload button)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Upload previous Art',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                          /* TextButton(
                          onPressed: _pickPortfolioImages,
                          child: const Text(
                            'Upload',
                            style: TextStyle(
                              fontSize: _inputFs,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepPlum,
                            ),),
                          ),*/
                        ],
                      ),
                      Text(
                        'Allowed: JPG, JPEG, PNG, WEBP. Each file must be <2MB.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.blackCat.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                                color: AppColors.snow,
                                child: Image.memory(b, fit: BoxFit.cover),
                              ),
                            );
                          }),
                          InkWell(
                            onTap: _pickPortfolioImages,
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: AppColors.snow,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Add',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      if (_portfolioImages.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.snow,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppColors.blackCat.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'No previous art uploaded yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ✅ Then Project Notes + Instagram + TikTok (NO portfolio link)
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

                const SizedBox(height: 18),

                // -----------------------
                // Payment Method
                // -----------------------
                _sectionCard(
                  title: 'Payment Method',
                  subtitle: 'Select a method and save it (required).',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip('PayPal', _paymentMethod == 'PayPal', () {
                            setState(() {
                              _paymentMethod = 'PayPal';
                              _paymentSaved = false;
                            });
                          }),
                          _chip('Venmo', _paymentMethod == 'Venmo', () {
                            setState(() {
                              _paymentMethod = 'Venmo';
                              _paymentSaved = false;
                            });
                          }),
                          _chip('Apple Pay', _paymentMethod == 'Apple Pay', () {
                            setState(() {
                              _paymentMethod = 'Apple Pay';
                              _paymentSaved = false;
                            });
                          }),
                          _chip(
                            'Credit Card',
                            _paymentMethod == 'Credit Card',
                            () {
                              setState(() {
                                _paymentMethod = 'Credit Card';
                                _paymentSaved = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ---- PayPal ----
                      if (_paymentMethod == 'PayPal') ...[
                        TextField(
                          controller: _paypalEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          decoration: _dec(
                            'PayPal Email *',
                            'name@example.com',
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // ---- Venmo ----
                      if (_paymentMethod == 'Venmo') ...[
                        TextField(
                          controller: _venmoHandleCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          decoration: _dec(
                            'Venmo Handle / Phone *',
                            '@yourhandle or phone',
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // ---- Apple Pay ----
                      if (_paymentMethod == 'Apple Pay') ...[
                        TextField(
                          controller: _applePayPaymentNameCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          decoration: _dec('Full Name *', 'Name on Apple Pay'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _applePayPaymentPhoneCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
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
                          controller: _applePayPaymentEmailCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(
                            'Apple ID Email *',
                            'email linked to Apple Pay',
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // ---- Credit Card ----
                      if (_paymentMethod == 'Credit Card') ...[
                        TextField(
                          controller: _cardNameCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          decoration: _dec('Name on Card *', 'Full name'),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cardNumberCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(19),
                            CardNumberTextInputFormatter(),
                          ],
                          decoration: _dec(
                            'Card Number *',
                            '1234 5678 9012 3456',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cardExpiryCtrl,
                                style: const TextStyle(
                                  fontSize: _paymentInputFs,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  ExpiryDateTextInputFormatter(),
                                ],
                                decoration: _dec(
                                  'Expiration Date (MM/YY) *',
                                  'MM/YY',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _cardCvvCtrl,
                                style: const TextStyle(
                                  fontSize: _paymentInputFs,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: _dec('CVV *', '123'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cardZipCtrl,
                          style: const TextStyle(fontSize: _paymentInputFs),
                          keyboardType: TextInputType.number,
                          decoration: _dec('Billing ZIP *', 'ZIP code'),
                        ),
                        const SizedBox(height: 6),
                      ],

                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepPlum,
                            foregroundColor: Colors.white,
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
                            setState(() => _paymentSaved = true);
                          },
                          child: const Text(
                            'Save Payment Method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.snow,
                              fontFamily: 'Arial',
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
                            _paymentSaved ? 'Saved ✅' : 'Not saved yet',
                            style: TextStyle(
                              color: AppColors.blackCat,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -----------------------
                // Nail Material Bundles
                // -----------------------
                _sectionCard(
                  title: 'Nail Material Bundles',
                  subtitle:
                      'Starter bundles for gel, tips, tools and more. (Required)',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F0FF), Color(0xFFEAF7F2)],
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
                              selected: _selectedBundle == 'Starter',
                              purchased:
                                  _bundlePurchased &&
                                  _selectedBundle == 'Starter',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _selectedBundle = 'Starter'),
                              onAdd: () => _openBundleCheckout(
                                bundleKey: 'Starter',
                                title: 'Starter Material Bundle',
                                subtitle: 'Perfect for new artists.',
                                priceText: '\$50',
                                imageAsset: 'assets/images/nail_bundle_50.png',
                              ),
                            ),

                            const SizedBox(width: 12),
                            _bundleCard(
                              title: 'Pro Material Bundle',
                              subtitle: 'Gel, tools & tips.',
                              price: '\$100',
                              imageAsset: 'assets/images/nail_bundle_100.png',
                              selected: _selectedBundle == 'Pro',
                              purchased:
                                  _bundlePurchased && _selectedBundle == 'Pro',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _selectedBundle = 'Pro'),
                              onAdd: () => _openBundleCheckout(
                                bundleKey: 'Pro',
                                title: 'Pro Material Bundle',
                                subtitle: 'Gel, tools & tips.',
                                priceText: '\$100',
                                imageAsset: 'assets/images/nail_bundle_100.png',
                              ),
                            ),
                            const SizedBox(width: 12),
                            _bundleCard(
                              title: 'Studio Bundle',
                              subtitle: 'For high volume artists.',
                              price: '\$150',
                              imageAsset: 'assets/images/nail_bundle_150.png',
                              selected: _selectedBundle == 'Studio',
                              purchased:
                                  _bundlePurchased &&
                                  _selectedBundle == 'Studio',
                              disableAdd: _bundlePurchased,
                              onTap: () =>
                                  setState(() => _selectedBundle = 'Studio'),
                              onAdd: () => _openBundleCheckout(
                                bundleKey: 'Studio',
                                title: 'Studio Bundle',
                                subtitle: 'For high volume artists.',
                                priceText: '\$150',
                                imageAsset: 'assets/images/nail_bundle_150.png',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            _bundlePurchased
                                ? Icons.check_circle_outline
                                : Icons.lock_outline,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _bundlePurchased
                                  ? 'Purchased'
                                  : 'You must purchase a bundle before account creation.',
                              style: TextStyle(
                                color: AppColors.blackCat,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
                // ✅ Payout (add Apple Pay + fields)
                // -----------------------
                _sectionCard(
                  title: 'Payout',
                  subtitle: 'How you receive payouts (can be updated later).',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF7F2), Color(0xFFF5F0FF)],
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<PayoutMethod>(
                        initialValue: _payoutMethod,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w500,
                        ),

                        // ✅ controls the "Select state" when value is null
                        hint: Text(
                          'Select state',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackCat,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.venmo,
                            child: Text(
                              'Venmo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackCat,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.bankTransfer,
                            child: Text(
                              'Bank Transfer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackCat,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: PayoutMethod.applePay,
                            child: Text(
                              'Apple Pay',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackCat,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _payoutMethod = v ?? PayoutMethod.paypal,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_payoutMethod == PayoutMethod.paypal ||
                          _payoutMethod == PayoutMethod.venmo) ...[
                        TextField(
                          controller: _legalNameCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          decoration: _dec('Legal Name *', 'Legal Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _payoutEmailCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          decoration: _dec('Legal Name *', 'Legal Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bankNameCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          decoration: _dec('Bank Name *', 'Bank name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _routingCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          keyboardType: TextInputType.number,
                          decoration: _dec(
                            'Routing Number *',
                            'Routing number',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _accountNumberCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          decoration: _dec('Full Name *', 'Name on Apple Pay'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _applePayPhoneCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            UsPhoneTextInputFormatter(),
                          ],
                          decoration: _dec('Phone Number *', 'Apple Pay phone'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _applePayEmailCtrl,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
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
                  // Policies & Agreements
                  // -----------------------
                  _sectionCard(
                    title: 'Policies & Agreements',
                    child: Column(
                      children: [
                        _checkRow(
                          value: _agreeTerms,
                          text: 'I agree to the Terms & Conditions *',
                          onChanged: (v) => setState(() => _agreeTerms = v),
                        ),
                        _checkRow(
                          value: _noCopyright,
                          text:
                              'I will not use copyrighted designs without permission *',
                          onChanged: (v) => setState(() => _noCopyright = v),
                        ),
                        _checkRow(
                          value: _agreeSafety,
                          text:
                              'I agree to follow safety & hygiene guidelines *',
                          onChanged: (v) => setState(() => _agreeSafety = v),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Receive JNT Nail updates & offers',
                                style: TextStyle(
                                  fontSize: _inputFs,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.88,
                              child: Switch(
                                value: _receiveUpdates,
                                onChanged: (v) =>
                                    setState(() => _receiveUpdates = v),
                                activeThumbColor: AppColors.blackCat,
                                inactiveThumbColor: AppColors.blackCatLight,
                                inactiveTrackColor: AppColors.blackCatLight
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // -----------------------
                // Create Artist Account
                // -----------------------
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      disabledBackgroundColor: AppColors.blackCat.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.snow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _submitStatus,
                                style: const TextStyle(
                                  fontSize: _inputFs,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.snow,
                              fontFamily: 'Arial',
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

  // -----------------------
  // Small widgets
  // -----------------------
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
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? AppColors.blackCat.withValues(alpha: 0.45)
                : AppColors.blackCat.withValues(alpha: 0.06),
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
                  color: const Color(0xFFF5F0FF),
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
                        color: AppColors.blackCat.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w800,
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
                fontSize: _subFs,
                color: AppColors.blackCat.withValues(alpha: 0.55),
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
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: (purchased || disableAdd) ? null : onAdd,
                child: Text(
                  purchased ? 'Purchased' : 'Add to Cart',
                  style: TextStyle(
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

  Widget _checkRow({
    required bool value,
    required String text,
    required ValueChanged<bool> onChanged,
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
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.blackCat,
              checkColor: AppColors.snow,
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: _subFs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*String _monthName(int m) {
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  return months[m - 1];
}*/
