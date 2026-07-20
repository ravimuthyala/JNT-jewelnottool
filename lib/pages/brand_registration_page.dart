// lib/pages/brand_registration_page.dart
//
// âœ… NEW VERSION (keep your existing page as-is)
// This file is a "Brand Registration" that INCLUDES everything you already had,
// PLUS company-specific fields to support the Company Nail Request Modal.
// You can finalize later based on client requirement.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../config/auth_flags.dart';
import '../models/company_business_options.dart';
import '../services/address_validation_service.dart';
import '../services/supabase_auth_service.dart';
import '../utils/registration_input_utils.dart';
import '../widgets/registration_profile_upload.dart';

import 'email_verification_pending_page.dart';
import 'home_page.dart';
import 'branding_company_shell_page.dart';
import 'company_profile_page.dart';

class BrandRegistrationPage extends StatefulWidget {
  const BrandRegistrationPage({super.key});

  @override
  State<BrandRegistrationPage> createState() => _BrandRegistrationPageState();
}

@Deprecated('Use BrandRegistrationPage instead.')
typedef CompanyRegistrationPageV2 = BrandRegistrationPage;

enum CompanyPayoutMethod { paypal, venmo, bankTransfer, applePay }

class _BrandRegistrationPageState extends State<BrandRegistrationPage> {
  static const Duration _registrationStepTimeout = Duration(seconds: 20);
  static const Duration _logoUploadTimeout = Duration(seconds: 20);
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _logoUploadFocusNode = FocusNode(debugLabel: 'companyLogoUpload');
  Timer? _billingStreetAutocompleteDebounce;
  Timer? _shippingStreetAutocompleteDebounce;
  List<AddressSuggestion> _billingStreetSuggestions = const [];
  List<AddressSuggestion> _shippingStreetSuggestions = const [];
  bool _billingStreetSuggestionsLoading = false;
  bool _shippingStreetSuggestionsLoading = false;
  bool _submitting = false;
  bool _showValidationErrors = false;
  int _registrationStep = 0;
  int? _validationTriggeredStep;

  static const List<String> _registrationStepTitles = <String>[
    'Company Profile\n& Primary Contact',
    'Address\n& Payment',
  ];

  // -----------------------
  // EXISTING (kept)
  // -----------------------
  final _nameCtrl = TextEditingController(); // (kept) original "Name"
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  // âœ… NEW: for the updated Company Profile + Account Creation section
  final _confirmPassCtrl = TextEditingController();
  String? _businessType;

  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  String _companyPhoneAreaCode = '+1';
  String _contactPhoneAreaCode = '+1';
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
  String get _normalizedCompanyAreaCode =>
      RegistrationInputUtils.normalizeAreaCode(_companyPhoneAreaCode);
  String get _normalizedContactAreaCode =>
      RegistrationInputUtils.normalizeAreaCode(_contactPhoneAreaCode);

  // Address info (kept)
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _manualStateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _shipStreetCtrl = TextEditingController();
  final _shipCityCtrl = TextEditingController();
  final _shipManualStateCtrl = TextEditingController();
  final _shipZipCtrl = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  Uint8List? _logoBytes;
  String? _logoPath;

  // State/Country dropdown values (kept)
  String? _selectedState;
  String _selectedCountry = 'United States';
  bool get _isBillingUnitedStates => _selectedCountry == 'United States';

  // -----------------------
  // âœ… COMPANY ADDITIONS (NEW)
  // -----------------------
  final _companyNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _companyUrlCtrl = TextEditingController(); // optional
  final _brandColorsCtrl =
      TextEditingController(); // "comma separated" or "#HEX"
  final _quantityMinCtrl = TextEditingController(); // optional defaults
  final _quantityMaxCtrl = TextEditingController(); // optional defaults

  // Shipping toggle + billing method
  bool _shippingSameAsBilling = true;
  String? _shipSelectedState;
  String _shipSelectedCountry = 'United States';
  bool get _isShippingUnitedStates => _shipSelectedCountry == 'United States';
  String _billingMethod = 'Credit/Debit Card';
  bool _saveBillingForFutureUse = true;

  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  final _achAccountNameCtrl = TextEditingController();
  final _achRoutingCtrl = TextEditingController();
  final _achAccountCtrl = TextEditingController();

  final _applePayEmailCtrl = TextEditingController();
  final _googlePayEmailCtrl = TextEditingController();

  CompanyPayoutMethod _payoutMethod = CompanyPayoutMethod.paypal;
  final _payoutLegalNameCtrl = TextEditingController();
  final _payoutEmailCtrl = TextEditingController();
  final _payoutBankNameCtrl = TextEditingController();
  final _payoutRoutingCtrl = TextEditingController();
  final _payoutAccountNumberCtrl = TextEditingController();
  final _payoutApplePayNameCtrl = TextEditingController();
  final _payoutApplePayPhoneCtrl = TextEditingController();
  final _payoutApplePayEmailCtrl = TextEditingController();

  static const List<String> _billingMethods = [
    'Credit/Debit Card',
    'ACH Transfer',
    'Apple Pay',
    'Google Pay',
  ];

  // -----------------------
  // Lists
  // -----------------------

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

  @override
  void dispose() {
    _billingStreetAutocompleteDebounce?.cancel();
    _shippingStreetAutocompleteDebounce?.cancel();
    _logoUploadFocusNode.dispose();
    // existing
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _bioCtrl.dispose();
    _confirmPassCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _manualStateCtrl.dispose();
    _zipCtrl.dispose();
    _shipStreetCtrl.dispose();
    _shipCityCtrl.dispose();
    _shipManualStateCtrl.dispose();
    _shipZipCtrl.dispose();

    // âœ… new
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _companyUrlCtrl.dispose();
    _brandColorsCtrl.dispose();
    _quantityMinCtrl.dispose();
    _quantityMaxCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _achAccountNameCtrl.dispose();
    _achRoutingCtrl.dispose();
    _achAccountCtrl.dispose();
    _applePayEmailCtrl.dispose();
    _googlePayEmailCtrl.dispose();
    _payoutLegalNameCtrl.dispose();
    _payoutEmailCtrl.dispose();
    _payoutBankNameCtrl.dispose();
    _payoutRoutingCtrl.dispose();
    _payoutAccountNumberCtrl.dispose();
    _payoutApplePayNameCtrl.dispose();
    _payoutApplePayPhoneCtrl.dispose();
    _payoutApplePayEmailCtrl.dispose();

    super.dispose();
  }

  Future<void> _pickCompanyLogo() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1200,
    );
    if (img == null) {
      _restoreLogoUploadFocus();
      return;
    }
    if (!mounted) return;

    if (kIsWeb) {
      final bytes = await img.readAsBytes();
      if (!mounted) return;
      setState(() {
        _logoBytes = bytes;
        _logoPath = null;
      });
      _restoreLogoUploadFocus();
      return;
    }

    setState(() {
      _logoPath = img.path;
      _logoBytes = null;
    });
    _restoreLogoUploadFocus();
  }

  // The OS image picker steals accessibility focus; after it returns, put
  // focus back on the avatar (not wherever the platform happens to land it,
  // which is often the Close button) so screen reader users stay in place.
  void _restoreLogoUploadFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_logoUploadFocusNode);
    });
  }

  // -----------------------
  // Font sizes (kept)
  // -----------------------
  static const double _labelFs = 14;
  static const double _inputFs = 14;
  static const double _hintFs = 13.5;
  static const double _dropFs = 14;
  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 14;

  InputDecoration _dec(String label, String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: _hintFs,
        color: Colors.black.withValues(alpha: 0.35),
      ),
      labelStyle: TextStyle(
        fontSize: _labelFs,
        color: Colors.black.withValues(alpha: 0.7),
      ),
      errorStyle: const TextStyle(
        fontSize: 10.5,
        height: 1.1,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.snow,
      suffixIcon: suffixIcon,
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
        borderSide: const BorderSide(color: AppColors.blackCat, width: 1.4),
      ),
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _fieldVerticalPadding,
      ),
    );
  }

  /// Marks a form field as required (or not) for screen readers, matching
  /// the visible required/optional state already tracked by `_FieldLabel`.
  /// Uses Semantics.required rather than embedding the word "required" in a
  /// label string, so it's announced consistently the same way for every
  /// field instead of only the ones that happen to spell it out.
  Widget _req(bool required, Widget child) {
    return Semantics(isRequired: required, child: child);
  }

  /// Wraps a DropdownButtonFormField-style widget so screen readers announce
  /// it as a dropdown (with its current value) instead of a generic button.
  Widget _dropdownSemantics({
    required String label,
    required String? value,
    required Widget child,
    bool required = false,
  }) {
    return Semantics(
      label: label,
      value: (value == null || value.trim().isEmpty) ? 'Not selected' : value,
      hint: 'Dropdown. Double tap to open.',
      isRequired: required,
      child: ExcludeSemantics(child: child),
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
          color: AppColors.snow,
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
    bool required = false,
  }) {
    return _req(required, _typeAheadPickerField(
      label: label,
      hint: hint,
      options: options,
      selectedValue: selectedValue,
      onChanged: onChanged,
      validator: validator,
    ));
  }

  Widget _typeAheadPickerField({
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
                        color: Colors.black,
                      ),
                      decoration: _dec(label, hint),
                      onTapOutside: (_) => focusNode.unfocus(),
                      onEditingComplete: () {
                        final match = _firstExactMatch(
                          options,
                          textController.text,
                        );
                        if (match != null) {
                          field.didChange(match);
                          onChanged(match);
                        }
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
                                style: const TextStyle(fontSize: _inputFs),
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
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w400,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // -----------------------
  // Validators (existing + new)
  // -----------------------
  String? _requiredValidator(String? v, String fieldName) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegistrationInputUtils.isValidEmail(v.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Password is required';
    if (!RegistrationInputUtils.isStrongPassword(value)) {
      return 'Use 8+ chars with upper, lower, number, and symbol';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Confirm Password is required';
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final digits = RegistrationInputUtils.normalizePhone(v);
    if (digits.length != 10) return 'Enter exactly 10 digits';
    return null;
  }

  String? _zipValidator(String? v, {bool enforceUsPattern = true}) {
    if (v == null || v.trim().isEmpty) {
      return enforceUsPattern ? 'Zip Code is required' : null;
    }
    if (!enforceUsPattern) return null;
    final ok = RegExp(r'^\d{5}(-\d{4})?$').hasMatch(v.trim());
    if (!ok) return 'Enter a valid ZIP code';
    return null;
  }

  // optional URL validator (validate only if user typed something)
  String? _optionalUrlValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    final ok =
        uri != null &&
        uri.hasScheme &&
        (value.startsWith('http://') || value.startsWith('https://')) &&
        (uri.host.isNotEmpty);
    if (!ok) return 'Enter a valid URL (https://...)';
    return null;
  }

  String? _socialRequiredValidator(String? _) {
    final instagram = _instagramCtrl.text.trim();
    final tiktok = _tiktokCtrl.text.trim();
    if (instagram.isEmpty && tiktok.isEmpty) {
      return 'Provide Instagram or TikTok';
    }
    return null;
  }

  String? _billingRequiredIfSelected(
    String? value, {
    required String method,
    required String fieldName,
  }) {
    if (_billingMethod != method) return null;
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  bool _hasRequiredBillingMethod() {
    switch (_billingMethod) {
      case 'Credit/Debit Card':
        final cardNumber = _cardNumberCtrl.text.trim().replaceAll(' ', '');
        final cvv = _cardCvvCtrl.text.trim();
        return _cardNameCtrl.text.trim().isNotEmpty &&
            cardNumber.length >= 13 &&
            cardNumber.length <= 19 &&
            RegExp(r'^\d{2}\/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim()) &&
            (cvv.length == 3 || cvv.length == 4);
      case 'ACH Transfer':
        return _achAccountNameCtrl.text.trim().isNotEmpty &&
            _achRoutingCtrl.text.trim().isNotEmpty &&
            _achAccountCtrl.text.trim().isNotEmpty;
      case 'Apple Pay':
        return _applePayEmailCtrl.text.trim().isNotEmpty;
      case 'Google Pay':
        return _googlePayEmailCtrl.text.trim().isNotEmpty;
    }
    return false;
  }

  bool _showBillingValidationMessage(String message) {
    if (!mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    return false;
  }

  String? _payoutRequiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  Map<String, dynamic> _normalizedCompanyPayoutPayload() {
    final isPaypal = _payoutMethod == CompanyPayoutMethod.paypal;
    final isVenmo = _payoutMethod == CompanyPayoutMethod.venmo;
    final isBank = _payoutMethod == CompanyPayoutMethod.bankTransfer;
    final isApplePay = _payoutMethod == CompanyPayoutMethod.applePay;
    return <String, dynamic>{
      'method': _payoutMethod.name,
      'paypal': {
        'enabled': isPaypal,
        'email': isPaypal ? _payoutEmailCtrl.text.trim() : '',
      },
      'venmo': {
        'enabled': isVenmo,
        'username': isVenmo ? _payoutEmailCtrl.text.trim() : '',
      },
      'ach': {
        'enabled': isBank,
        'accountHolder': isBank ? _payoutLegalNameCtrl.text.trim() : '',
        'bankName': isBank ? _payoutBankNameCtrl.text.trim() : '',
        'routingNumber': isBank ? _payoutRoutingCtrl.text.trim() : '',
        'accountNumber': isBank ? _payoutAccountNumberCtrl.text.trim() : '',
      },
      'applePay': {
        'enabled': isApplePay,
        'fullName': isApplePay ? _payoutApplePayNameCtrl.text.trim() : '',
        'email': isApplePay ? _payoutApplePayEmailCtrl.text.trim() : '',
        'phone': isApplePay ? _payoutApplePayPhoneCtrl.text.trim() : '',
      },
      'email': _payoutEmailCtrl.text.trim(),
    };
  }

  Widget promosAndNailTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promos & Nail Tips',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: Colors.black.withValues(alpha: 0.55),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Get 10% off your first custom set â€” use WELCOME10',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.75),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Create Account (kept behavior + extra validations for company fields)
  // -----------------------
  Map<String, dynamic> _buildCompanyFirestorePayload({
    required String uid,
    required CompanyBillingDraft billingDraft,
    required CompanyAddressesDraft addressesDraft,
    required String profilePhotoUrl,
  }) {
    final profilePhotoValue = profilePhotoUrl.trim();
    final safeProfilePhotoUrl =
        profilePhotoValue.toLowerCase().startsWith('data:image/')
        ? ''
        : profilePhotoValue;
    final companyPhoneLocal = RegistrationInputUtils.normalizePhone(
      _phoneCtrl.text,
    );
    final contactPhoneLocal = RegistrationInputUtils.normalizePhone(
      _contactPhoneCtrl.text,
    );
    final companyName = _companyNameCtrl.text.trim();
    final contactName = _contactNameCtrl.text.trim();
    final contactEmail = _contactEmailCtrl.text.trim().toLowerCase();
    final companyWebsite = _companyUrlCtrl.text.trim();
    final businessType = (_businessType ?? '').trim();
    final companyPhone = '$_normalizedCompanyAreaCode$companyPhoneLocal';
    final contactPhone = '$_normalizedContactAreaCode$contactPhoneLocal';
    final payout = _normalizedCompanyPayoutPayload();
    return {
      'uid': uid,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'panel_companyEmail': _emailCtrl.text.trim().toLowerCase(),
      'panel_company_email': _emailCtrl.text.trim().toLowerCase(),
      'accountType': 'company',
      'roles': {'client': false, 'artist': false, 'company': true},
      // Panel-friendly top-level columns
      'panel_companyName': companyName,
      'panel_company_name': companyName,
      'panel_contactName': contactName,
      'panel_contact_name': contactName,
      'panel_businessType': businessType,
      'panel_business_type': businessType,
      'panel_companyWebsite': companyWebsite,
      'panel_company_website': companyWebsite,
      'panel_companyBio': _bioCtrl.text.trim(),
      'panel_contactEmail': contactEmail,
      'panel_contact_email': contactEmail,
      'panel_companyPhone': companyPhone,
      'panel_company_phone': companyPhone,
      'panel_companyPhoneAreaCode': _normalizedCompanyAreaCode,
      'panel_companyPhoneLocal': companyPhoneLocal,
      'panel_contactPhone': contactPhone,
      'panel_contact_phone': contactPhone,
      'panel_contactPhoneAreaCode': _normalizedContactAreaCode,
      'panel_contactPhoneLocal': contactPhoneLocal,
      'panel_instagram': _instagramCtrl.text.trim(),
      'panel_tiktok': _tiktokCtrl.text.trim(),
      'panel_billingStreet': addressesDraft.billingStreet,
      'panel_billing_street': addressesDraft.billingStreet,
      'panel_billingCity': addressesDraft.billingCity,
      'panel_billing_city': addressesDraft.billingCity,
      'panel_billingState': addressesDraft.billingState,
      'panel_billing_state': addressesDraft.billingState,
      'panel_billingZip': addressesDraft.billingZip,
      'panel_billing_zip': addressesDraft.billingZip,
      'panel_billingCountry': addressesDraft.billingCountry,
      'panel_billing_country': addressesDraft.billingCountry,
      'panel_shippingSameAsBilling': addressesDraft.shippingSameAsBilling,
      'panel_shipping_same_as_billing': addressesDraft.shippingSameAsBilling,
      'panel_shippingStreet': addressesDraft.shippingStreet,
      'panel_shipping_street': addressesDraft.shippingStreet,
      'panel_shippingCity': addressesDraft.shippingCity,
      'panel_shipping_city': addressesDraft.shippingCity,
      'panel_shippingState': addressesDraft.shippingState,
      'panel_shipping_state': addressesDraft.shippingState,
      'panel_shippingZip': addressesDraft.shippingZip,
      'panel_shipping_zip': addressesDraft.shippingZip,
      'panel_shippingCountry': addressesDraft.shippingCountry,
      'panel_shipping_country': addressesDraft.shippingCountry,
      'panel_billingMethod': billingDraft.method,
      'panel_billing_method': billingDraft.method,
      'panel_billingSaveForFutureUse': billingDraft.saveForFutureUse,
      'panel_billing_save_for_future_use': billingDraft.saveForFutureUse,
      'panel_billingNameOnCard': billingDraft.nameOnCard,
      'panel_billing_name_on_card': billingDraft.nameOnCard,
      'panel_billingExpiry': billingDraft.expiry,
      'panel_billing_expiry': billingDraft.expiry,
      'panel_billing_apple_pay_email': billingDraft.applePayEmail,
      'panel_billing_google_pay_email': billingDraft.googlePayEmail,
      'panel_payout': payout,
      'panel_payoutMethod': _payoutMethod.name,
      'panel_payout_method': _payoutMethod.name,
      'panel_payoutLegalName': _payoutLegalNameCtrl.text.trim(),
      'panel_payout_legal_name': _payoutLegalNameCtrl.text.trim(),
      'panel_payoutEmail': _payoutEmailCtrl.text.trim(),
      'panel_payout_email': _payoutEmailCtrl.text.trim(),
      'panel_profileImageUrl': safeProfilePhotoUrl,
      'panel_profile_image_url': safeProfilePhotoUrl,
      'panel_logoUrl': safeProfilePhotoUrl,
      'panel_logo_url': safeProfilePhotoUrl,
      'companyLogoUrl': safeProfilePhotoUrl,
      'brandLogoUrl': safeProfilePhotoUrl,
      'profileImageUrl': safeProfilePhotoUrl,
      'logoUrl': safeProfilePhotoUrl,
      'photoUrl': safeProfilePhotoUrl,
      'avatarUrl': safeProfilePhotoUrl,
      'profile': {
        'logoUrl': safeProfilePhotoUrl,
        'profileImageUrl': safeProfilePhotoUrl,
        'photoUrl': safeProfilePhotoUrl,
        'avatarUrl': safeProfilePhotoUrl,
      },
      'basic': {
        'profileImageUrl': safeProfilePhotoUrl,
        'photoUrl': safeProfilePhotoUrl,
        'avatarUrl': safeProfilePhotoUrl,
      },
      'company': {
        'name': companyName,
        'contactName': contactName,
        'businessType': businessType,
        'business_type': businessType,
        'website': companyWebsite,
        'companyWebsite': companyWebsite,
        'company_website': companyWebsite,
        'bio': _bioCtrl.text.trim(),
        'contactEmail': contactEmail,
        'contact_email': contactEmail,
        'companyEmail': _emailCtrl.text.trim().toLowerCase(),
        'company_email': _emailCtrl.text.trim().toLowerCase(),
        'phone': companyPhone,
        'companyPhone': companyPhone,
        'company_phone': companyPhone,
        'phoneAreaCode': _normalizedCompanyAreaCode,
        'phoneLocal': companyPhoneLocal,
        'contactPhone': contactPhone,
        'contact_phone': contactPhone,
        'contactPhoneAreaCode': _normalizedContactAreaCode,
        'contactPhoneLocal': contactPhoneLocal,
        'instagram': _instagramCtrl.text.trim(),
        'tiktok': _tiktokCtrl.text.trim(),
        'logoUrl': safeProfilePhotoUrl,
        'profileImageUrl': safeProfilePhotoUrl,
        'photoUrl': safeProfilePhotoUrl,
        'avatarUrl': safeProfilePhotoUrl,
      },
      'addresses': {
        'billingStreet': addressesDraft.billingStreet,
        'billingCity': addressesDraft.billingCity,
        'billingState': addressesDraft.billingState,
        'billingZip': addressesDraft.billingZip,
        'billingCountry': addressesDraft.billingCountry,
        'shippingSameAsBilling': addressesDraft.shippingSameAsBilling,
        'shippingStreet': addressesDraft.shippingStreet,
        'shippingCity': addressesDraft.shippingCity,
        'shippingState': addressesDraft.shippingState,
        'shippingZip': addressesDraft.shippingZip,
        'shippingCountry': addressesDraft.shippingCountry,
      },
      'billing': {
        'method': billingDraft.method,
        'saveForFutureUse': billingDraft.saveForFutureUse,
        'nameOnCard': billingDraft.nameOnCard,
        'cardNumber': billingDraft.cardNumber,
        'expiry': billingDraft.expiry,
        'cvv': billingDraft.cvv,
        'achAccountName': billingDraft.achAccountName,
        'achRoutingNumber': billingDraft.achRoutingNumber,
        'achAccountNumber': billingDraft.achAccountNumber,
        'applePayEmail': billingDraft.applePayEmail,
        'googlePayEmail': billingDraft.googlePayEmail,
      },
      'payout': payout,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<String> _uploadCompanyLogoIfAny(String uid) async {
    Uint8List? bytes = _logoBytes;

    if (bytes == null && !kIsWeb && _logoPath != null) {
      try {
        bytes = await File(_logoPath!).readAsBytes();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BrandRegistrationPage] logo read failed: $e');
        }
      }
    }

    debugPrint('COMPANY LOGO BYTES NULL = ${bytes == null}');
    debugPrint('COMPANY LOGO BYTES LENGTH = ${bytes?.length ?? 0}');

    if (bytes == null || bytes.isEmpty) {
      return '';
    }

    Uint8List optimize(Uint8List source) {
      final decoded = img.decodeImage(source);
      if (decoded == null) return source;

      img.Image processed = decoded;
      final maxSide = processed.width > processed.height
          ? processed.width
          : processed.height;

      if (maxSide > 900) {
        final scale = 900 / maxSide;
        processed = img.copyResize(
          processed,
          width: (processed.width * scale).round(),
          height: (processed.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }

      return Uint8List.fromList(img.encodeJpg(processed, quality: 74));
    }

    final optimizedBytes = optimize(bytes);
    final unique =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final path = 'companies/$uid/logo/$unique.jpg';

    try {
      final storage = Supabase.instance.client.storage.from('company-logos');

      await storage
          .uploadBinary(
            path,
            optimizedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          )
          .timeout(_logoUploadTimeout);

      final publicUrl = storage.getPublicUrl(path).trim();

      debugPrint('COMPANY SUPABASE LOGO URL = $publicUrl');

      return publicUrl;
    } catch (e, st) {
      debugPrint('COMPANY SUPABASE LOGO UPLOAD FAILED: $e');
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return '';
    }
  }

  Future<void> _upsertBrandCompanyProfile({
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    final row = <String, dynamic>{
      'id': uid,
      'email': _emailCtrl.text.trim().toLowerCase(),
      'account_type': 'company',
      'panel_companyName': payload['panel_companyName'],
      'panel_company_name': payload['panel_company_name'],
      'panel_contactName': payload['panel_contactName'],
      'panel_contact_name': payload['panel_contact_name'],
      'panel_businessType': payload['panel_businessType'],
      'panel_business_type': payload['panel_business_type'],
      'panel_companyWebsite': payload['panel_companyWebsite'],
      'panel_company_website': payload['panel_company_website'],
      'panel_contactEmail': payload['panel_contactEmail'],
      'panel_contact_email': payload['panel_contact_email'],
      'panel_companyEmail': payload['panel_companyEmail'],
      'panel_company_email': payload['panel_company_email'],
      'panel_companyPhone': payload['panel_companyPhone'],
      'panel_company_phone': payload['panel_company_phone'],
      'panel_companyPhoneAreaCode': payload['panel_companyPhoneAreaCode'],
      'panel_companyPhoneLocal': payload['panel_companyPhoneLocal'],
      'panel_contactPhone': payload['panel_contactPhone'],
      'panel_contact_phone': payload['panel_contact_phone'],
      'panel_contactPhoneAreaCode': payload['panel_contactPhoneAreaCode'],
      'panel_contactPhoneLocal': payload['panel_contactPhoneLocal'],
      'panel_profileImageUrl': payload['panel_profileImageUrl'],
      'panel_profile_image_url': payload['panel_profile_image_url'],
      'panel_logoUrl': payload['panel_logoUrl'],
      'panel_logo_url': payload['panel_logo_url'],
      'panel_billingMethod': payload['panel_billingMethod'],
      'panel_billing_method': payload['panel_billing_method'],
      'panel_billingSaveForFutureUse': payload['panel_billingSaveForFutureUse'],
      'panel_billing_save_for_future_use':
          payload['panel_billing_save_for_future_use'],
      'panel_billingNameOnCard': payload['panel_billingNameOnCard'],
      'panel_billing_name_on_card': payload['panel_billing_name_on_card'],
      'panel_billingExpiry': payload['panel_billingExpiry'],
      'panel_billing_expiry': payload['panel_billing_expiry'],
      'panel_billing_apple_pay_email': payload['panel_billing_apple_pay_email'],
      'panel_billing_google_pay_email':
          payload['panel_billing_google_pay_email'],
      'panel_payout': payload['panel_payout'],
      'panel_payoutMethod': payload['panel_payoutMethod'],
      'panel_payout_method': payload['panel_payout_method'],
      'panel_payoutLegalName': payload['panel_payoutLegalName'],
      'panel_payout_legal_name': payload['panel_payout_legal_name'],
      'panel_payoutEmail': payload['panel_payoutEmail'],
      'panel_payout_email': payload['panel_payout_email'],
      'profile': payload['profile'],
      'basic': payload['basic'],
      'company': payload['company'],
      'addresses': payload['addresses'],
      'billing': payload['billing'],
      'payout': payload['payout'],
      'panel_billingStreet': payload['panel_billingStreet'],
      'panel_billing_street': payload['panel_billing_street'],
      'panel_billingCity': payload['panel_billingCity'],
      'panel_billing_city': payload['panel_billing_city'],
      'panel_billingState': payload['panel_billingState'],
      'panel_billing_state': payload['panel_billing_state'],
      'panel_billingZip': payload['panel_billingZip'],
      'panel_billing_zip': payload['panel_billing_zip'],
      'panel_billingCountry': payload['panel_billingCountry'],
      'panel_billing_country': payload['panel_billing_country'],
      'panel_shippingSameAsBilling': payload['panel_shippingSameAsBilling'],
      'panel_shipping_same_as_billing':
          payload['panel_shipping_same_as_billing'],
      'panel_shippingStreet': payload['panel_shippingStreet'],
      'panel_shipping_street': payload['panel_shipping_street'],
      'panel_shippingCity': payload['panel_shippingCity'],
      'panel_shipping_city': payload['panel_shipping_city'],
      'panel_shippingState': payload['panel_shippingState'],
      'panel_shipping_state': payload['panel_shipping_state'],
      'panel_shippingZip': payload['panel_shippingZip'],
      'panel_shipping_zip': payload['panel_shipping_zip'],
      'panel_shippingCountry': payload['panel_shippingCountry'],
      'panel_shipping_country': payload['panel_shipping_country'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _upsertCompanyRowWithSchemaFallback(row);
  }

  Future<void> _upsertCompanyRowWithSchemaFallback(
    Map<String, dynamic> originalRow,
  ) async {
    final row = Map<String, dynamic>.from(originalRow);

    for (var attempt = 0; attempt < 50; attempt++) {
      try {
        await Supabase.instance.client
            .from('company')
            .upsert(row)
            .timeout(_registrationStepTimeout);
        return;
      } on PostgrestException catch (e) {
        final missingColumn = _missingColumnFromPostgrest(e.message);
        final canRetry =
            e.code == 'PGRST204' &&
            missingColumn != null &&
            row.containsKey(missingColumn);

        if (!canRetry) rethrow;

        row.remove(missingColumn);
        if (kDebugMode) {
          debugPrint(
            '[BrandRegistrationPage] skipped missing company column: '
            '$missingColumn',
          );
        }
      }
    }

    throw const PostgrestException(
      message: 'Could not save company profile after schema fallback retries.',
      code: 'PGRST204',
    );
  }

  String? _missingColumnFromPostgrest(String message) {
    final match = RegExp(
      r"Could not find the '([^']+)' column",
    ).firstMatch(message);
    return match?.group(1);
  }

  Future<void> _finishBrandRegistrationForUser({
    required User user,
    required CompanyBillingDraft billingDraft,
    required CompanyAddressesDraft addressesDraft,
  }) async {
    final uid = user.id.trim();
    if (uid.isEmpty) {
      throw const AuthException(
        'Unable to create or recover the company account user.',
      );
    }

    final profilePhotoUrl = await _uploadCompanyLogoIfAny(uid);
    final payload = _buildCompanyFirestorePayload(
      uid: uid,
      billingDraft: billingDraft,
      addressesDraft: addressesDraft,
      profilePhotoUrl: profilePhotoUrl,
    );

    await _upsertBrandCompanyProfile(uid: uid, payload: payload);

    if (!mounted) return;

    if (kRequireEmailVerification) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPendingPage(
            email: _emailCtrl.text.trim().toLowerCase(),
            loginPageBuilder: (_) => const HomePage(),
          ),
        ),
        (route) => false,
      );
    } else {
      final companyName = _companyNameCtrl.text.trim().isEmpty
          ? 'Brand'
          : _companyNameCtrl.text.trim();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              BrandingCompanyShellPage(companyDisplayName: companyName),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _onCreateAccount() async {
    if (!_showValidationErrors) {
      setState(() => _showValidationErrors = true);
    }
    if (_formKey.currentState?.validate() != true) return;
    if (!_hasRequiredBillingMethod()) {
      _showBillingValidationMessage(
        'Please enter at least one payment method before continuing.',
      );
      return;
    }

    if (_isBillingUnitedStates) {
      final billingValidation =
          await AddressValidationService.validateUsAddress(
            street: _streetCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            state: _isBillingUnitedStates
                ? (_selectedState ?? '')
                : _manualStateCtrl.text.trim(),
            zip: _zipCtrl.text.trim(),
          );

      if (!billingValidation.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              billingValidation.message ?? 'Invalid U.S. billing address.',
            ),
          ),
        );
        return;
      }
    }

    if (!_shippingSameAsBilling && _isShippingUnitedStates) {
      final shippingValidation =
          await AddressValidationService.validateUsAddress(
            street: _shipStreetCtrl.text.trim(),
            city: _shipCityCtrl.text.trim(),
            state: _isShippingUnitedStates
                ? (_shipSelectedState ?? '')
                : _shipManualStateCtrl.text.trim(),
            zip: _shipZipCtrl.text.trim(),
          );

      if (!shippingValidation.isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shippingValidation.message ?? 'Invalid U.S. shipping address.',
            ),
          ),
        );
        return;
      }
    }

    if (_submitting) return;
    setState(() => _submitting = true);

    final billingDraft = CompanyBillingDraft(
      method: _billingMethod,
      saveForFutureUse: _saveBillingForFutureUse,
      nameOnCard: _cardNameCtrl.text.trim(),
      cardNumber: _cardNumberCtrl.text.trim(),
      expiry: _cardExpiryCtrl.text.trim(),
      cvv: _cardCvvCtrl.text.trim(),
      achAccountName: _achAccountNameCtrl.text.trim(),
      achRoutingNumber: _achRoutingCtrl.text.trim(),
      achAccountNumber: _achAccountCtrl.text.trim(),
      applePayEmail: _applePayEmailCtrl.text.trim(),
      googlePayEmail: _googlePayEmailCtrl.text.trim(),
    );

    final addressesDraft = CompanyAddressesDraft(
      billingStreet: _streetCtrl.text.trim(),
      billingCity: _cityCtrl.text.trim(),
      billingState: _isBillingUnitedStates
          ? (_selectedState ?? '')
          : _manualStateCtrl.text.trim(),
      billingZip: _zipCtrl.text.trim(),
      billingCountry: _selectedCountry,
      shippingSameAsBilling: _shippingSameAsBilling,
      shippingStreet: _shippingSameAsBilling
          ? _streetCtrl.text.trim()
          : _shipStreetCtrl.text.trim(),
      shippingCity: _shippingSameAsBilling
          ? _cityCtrl.text.trim()
          : _shipCityCtrl.text.trim(),
      shippingState: _shippingSameAsBilling
          ? (_isBillingUnitedStates
                ? (_selectedState ?? '')
                : _manualStateCtrl.text.trim())
          : (_isShippingUnitedStates
                ? (_shipSelectedState ?? '')
                : _shipManualStateCtrl.text.trim()),
      shippingZip: _shippingSameAsBilling
          ? _zipCtrl.text.trim()
          : _shipZipCtrl.text.trim(),
      shippingCountry: _shippingSameAsBilling
          ? _selectedCountry
          : _shipSelectedCountry,
    );

    try {
      await SupabaseAuthService.logout();

      final supabaseUser = await SupabaseAuthService.signup(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text.trim(),
      ).timeout(_registrationStepTimeout);

      if (supabaseUser == null) {
        throw const AuthException(
          'Unable to create user. Check Supabase email confirmation settings.',
        );
      }
      await _finishBrandRegistrationForUser(
        user: supabaseUser,
        billingDraft: billingDraft,
        addressesDraft: addressesDraft,
      );
    } on AuthException catch (e) {
      final isAlreadyRegistered = e.message.toLowerCase().contains('already');
      if (isAlreadyRegistered) {
        try {
          final existingUser = await SupabaseAuthService.login(
            email: _emailCtrl.text.trim().toLowerCase(),
            password: _passCtrl.text.trim(),
          ).timeout(_registrationStepTimeout);
          if (existingUser != null) {
            await _finishBrandRegistrationForUser(
              user: existingUser,
              billingDraft: billingDraft,
              addressesDraft: addressesDraft,
            );
            return;
          }
        } on AuthException {
          // Fall through to the user-facing sign-in message below.
        }
      }
      if (!mounted) return;
      final message = isAlreadyRegistered
          ? 'Email already registered. Please sign in.'
          : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration timed out. Please check your connection and try again.',
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('COMPANY_REGISTRATION_ERROR');
        debugPrint(e.toString());
        debugPrint(st.toString());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _autofillBillingAddressFromStreet() async {
    _billingStreetAutocompleteDebounce?.cancel();
    final query = _streetCtrl.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _billingStreetSuggestionsLoading = false;
        _billingStreetSuggestions = const [];
      });
      return;
    }
    setState(() => _billingStreetSuggestionsLoading = true);
    _billingStreetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _billingStreetSuggestionsLoading = false;
          _billingStreetSuggestions = results;
        });
      },
    );
  }

  void _applyBillingStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _streetCtrl.text = selected.street;
      _cityCtrl.text = selected.city;
      _zipCtrl.text = selected.zip;
      _selectedCountry = 'United States';
      final resolved =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      final matched = usStates.where((s) => s == resolved).toList();
      _selectedState = matched.isNotEmpty ? matched.first : null;
      _manualStateCtrl.clear();
      _billingStreetSuggestions = const [];
    });
  }

  Future<void> _autofillShippingAddressFromStreet() async {
    _shippingStreetAutocompleteDebounce?.cancel();
    final query = _shipStreetCtrl.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _shippingStreetSuggestionsLoading = false;
        _shippingStreetSuggestions = const [];
      });
      return;
    }
    setState(() => _shippingStreetSuggestionsLoading = true);
    _shippingStreetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _shippingStreetSuggestionsLoading = false;
          _shippingStreetSuggestions = results;
        });
      },
    );
  }

  void _applyShippingStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _shipStreetCtrl.text = selected.street;
      _shipCityCtrl.text = selected.city;
      _shipZipCtrl.text = selected.zip;
      _shipSelectedCountry = 'United States';
      final resolved =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      final matched = usStates.where((s) => s == resolved).toList();
      _shipSelectedState = matched.isNotEmpty ? matched.first : null;
      _shipManualStateCtrl.clear();
      _shippingStreetSuggestions = const [];
    });
  }

  Future<bool> _validateCurrentRegistrationStep() async {
    if (_validationTriggeredStep != _registrationStep) {
      setState(() => _validationTriggeredStep = _registrationStep);
    }
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid && mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Please correct the highlighted fields before continuing.',
        Directionality.of(context),
      );
      if (_registrationStep == 1) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Please enter at least one payment method before continuing.',
          Directionality.of(context),
        );
      }
      return false;
    }
    if (_registrationStep == 1 && !_hasRequiredBillingMethod()) {
      return _showBillingValidationMessage(
        'Please enter at least one payment method before continuing.',
      );
    }
    return valid;
  }

  void _announceStep(int index) {
    if (!mounted) return;
    final title = _registrationStepTitles[index].replaceAll('\n', ' ');
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Step ${index + 1} of ${_registrationStepTitles.length}: $title',
      Directionality.of(context),
    );
  }

  Future<void> _goToNextRegistrationStep() async {
    if (!await _validateCurrentRegistrationStep()) return;
    if (!mounted) return;
    setState(() {
      _registrationStep += 1;
      _validationTriggeredStep = null;
    });
    _announceStep(_registrationStep);
  }

  Widget _registrationProgressTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: List.generate(_registrationStepTitles.length, (index) {
          final selected = index == _registrationStep;
          final completed = index < _registrationStep;
          final showConnector = index < _registrationStepTitles.length - 1;
          final title = _registrationStepTitles[index].replaceAll('\n', ' ');
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  'Step ${index + 1} of ${_registrationStepTitles.length}: $title'
                  '${completed ? ', completed' : selected ? ', current step' : ''}',
              onTap: () {
                setState(() {
                  _registrationStep = index;
                  _validationTriggeredStep = null;
                });
                _announceStep(index);
              },
              child: ExcludeSemantics(
                child: InkWell(
              onTap: () {
                setState(() {
                  _registrationStep = index;
                  _validationTriggeredStep = null;
                });
                _announceStep(index);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
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
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 9,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.blackCat.withValues(
                          alpha: selected ? 1 : 0.65,
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
        }),
      ),
    );
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
                  backgroundColor: AppColors.deepPlum,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.blackCatBorderLight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _registrationStep -= 1;
                    _validationTriggeredStep = null;
                  });
                  _announceStep(_registrationStep);
                },
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
                  ? _onCreateAccount
                  : _goToNextRegistrationStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPlum,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      isLast ? 'Create account' : 'Next',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dropdownTextColor = AppColors.blackCat;
    const dropdownBackground = AppColors.snow;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Brand registration',
      child: Theme(
      data: Theme.of(context).copyWith(
        canvasColor: dropdownBackground,
        textTheme: Theme.of(context).textTheme.apply(
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
          closeTooltip: 'Close brand registration',
          closeIcon: const Icon(Icons.close),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              Form(
                key: _formKey,
                autovalidateMode: _validationTriggeredStep == _registrationStep
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    _registrationProgressTabs(),
                    if (_registrationStep == 0) ...[
                    // -----------------------
                    // âœ… COMPANY PROFILE & ACCOUNT CREATION (UPDATED)
                    // -----------------------
                    _SectionCard(
                      title: 'Company Profile & Account Creation',
                      subtitle:
                          'Create your company account and add company details',
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          _ProfileUpload(
                            label: 'Company Logo',
                            onTap: _pickCompanyLogo,
                            focusNode: _logoUploadFocusNode,
                            image: _logoBytes != null
                                ? MemoryImage(_logoBytes!)
                                : (_logoPath != null
                                      ? FileImage(File(_logoPath!))
                                      : null),
                          ),
                          const SizedBox(height: 18),

                          _FieldLabel.required('Company Name'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _companyNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec(
                                'Company Name',
                                'Enter Company Name',
                              ),
                              validator: (v) =>
                                  _requiredValidator(v, 'Company Name'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Business Type'),
                          const SizedBox(height: 6),
                          _dropdownSemantics(
                            label: 'Business Type',
                            value: _businessType,
                            required: true,
                            child: DropdownButtonFormField<String>(
                              initialValue: _businessType,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                color: AppColors.blackCat,
                              ),
                              menuMaxHeight: 280,
                              items: kCompanyBusinessTypes
                                  .map(
                                    (b) => DropdownMenuItem<String>(
                                      value: b,
                                      child: Text(
                                        b,
                                        style: const TextStyle(
                                          fontSize: _dropFs,
                                          color: AppColors.blackCat,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _businessType = v),
                              decoration: _dec(
                                'Business Type',
                                'Select Business Type',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Business Type is required'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Company Email'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller:
                                  _emailCtrl, // âœ… using your existing controller
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec(
                                'Company Email',
                                'Enter Company Email',
                              ),
                              validator: _emailValidator,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Company Phone#'),
                          const SizedBox(height: 6),
                          FormField<String>(
                            validator: (value) =>
                                _phoneValidator(_phoneCtrl.text),
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
                                            value: _companyPhoneAreaCode,
                                            embedded: true,
                                            onChanged: (code) => setState(
                                              () => _companyPhoneAreaCode =
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
                                          child: Semantics(
                                            label: 'Company phone number',
                                            isRequired: true,
                                            textField: true,
                                            child: TextFormField(
                                              controller: _phoneCtrl,
                                              style: const TextStyle(
                                                fontSize: _inputFs,
                                              ),
                                              keyboardType:
                                                  TextInputType.phone,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  10,
                                                ),
                                                UsPhoneTextInputFormatter(),
                                              ],
                                              onChanged: field.didChange,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Enter 10-digit phone',
                                                hintStyle: TextStyle(
                                                  fontSize: _hintFs,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.35),
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder:
                                                    InputBorder.none,
                                                focusedBorder:
                                                    InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical:
                                                          _fieldVerticalPadding,
                                                    ),
                                              ),
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
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Password'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller:
                                  _passCtrl, // âœ… using your existing controller
                              style: const TextStyle(fontSize: _inputFs),
                              obscureText: _obscure,
                              decoration: _dec(
                                'Password',
                                'Enter Password',
                                suffixIcon: IconButton(
                                  iconSize: 18,
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: _passwordValidator,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Password must include uppercase, lowercase, number, and symbol.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Confirm Password'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _confirmPassCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              obscureText: _obscureConfirm,
                              decoration: _dec(
                                'Confirm Password',
                                'Re-enter Password',
                                suffixIcon: IconButton(
                                  iconSize: 18,
                                  tooltip: _obscureConfirm
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: _confirmPasswordValidator,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.normal('Company URL'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _companyUrlCtrl,
                            style: const TextStyle(fontSize: _inputFs),
                            keyboardType: TextInputType.url,
                            decoration: _dec(
                              'Company URL',
                              'https://www.company.com',
                            ),
                            validator: _optionalUrlValidator,
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.normal('TikTok'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _tiktokCtrl,
                            style: const TextStyle(fontSize: _inputFs),
                            decoration: _dec(
                              'TikTok',
                              'Enter TikTok handle/link',
                            ),
                            validator: _socialRequiredValidator,
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.normal('Instagram'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _instagramCtrl,
                            style: const TextStyle(fontSize: _inputFs),
                            decoration: _dec(
                              'Instagram',
                              'Enter Instagram handle/link',
                            ),
                            validator: _socialRequiredValidator,
                          ),
                          const SizedBox(height: 16),


                          _FieldLabel.normal('Company Bio'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _bioCtrl,
                            style: const TextStyle(fontSize: _inputFs),
                            maxLines: 4,
                            decoration: _dec(
                              'Company Bio',
                              'Short brand overview',
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -----------------------
                    // âœ… PRIMARY CONTACT (NEW SECTION)
                    // -----------------------
                    _SectionCard(
                      title: 'Primary Contact',
                      subtitle:
                          'Enter your primary contact details (used for order notifications and communication)',
                      child: Column(
                        children: [
                          _FieldLabel.required('Contact Name'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _contactNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec(
                                'Contact Name',
                                'Enter Contact Name',
                              ),
                              validator: (v) =>
                                  _requiredValidator(v, 'Contact Name'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Contact Email'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _contactEmailCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec(
                                'Contact Email',
                                'Enter Contact Email',
                              ),
                              validator: _emailValidator,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Contact Phone'),
                          const SizedBox(height: 6),
                          FormField<String>(
                            validator: (value) =>
                                _phoneValidator(_contactPhoneCtrl.text),
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
                                            value: _contactPhoneAreaCode,
                                            embedded: true,
                                            onChanged: (code) => setState(
                                              () => _contactPhoneAreaCode =
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
                                          child: Semantics(
                                            label: 'Contact phone number',
                                            isRequired: true,
                                            textField: true,
                                            child: TextFormField(
                                              controller: _contactPhoneCtrl,
                                              style: const TextStyle(
                                                fontSize: _inputFs,
                                              ),
                                              keyboardType:
                                                  TextInputType.phone,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  10,
                                                ),
                                                UsPhoneTextInputFormatter(),
                                              ],
                                              onChanged: field.didChange,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Enter 10-digit phone',
                                                hintStyle: TextStyle(
                                                  fontSize: _hintFs,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.35),
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder:
                                                    InputBorder.none,
                                                focusedBorder:
                                                    InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical:
                                                          _fieldVerticalPadding,
                                                    ),
                                              ),
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
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    ] else ...[
                    const SizedBox(height: 16),

                    /*
                  // -----------------------
                  // âœ… BRAND DETAILS (supports request modal autofill)
                  // -----------------------
                  _SectionCard(
                    title: 'Brand Details',
                    subtitle: 'Used to auto-fill your nail requests (colors, vibe, logo)',
                    child: Column(
                      children: [
                        _FieldLabel.required('Brand Colors'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _brandColorsCtrl,
                          style: const TextStyle(fontSize: _inputFs),
                          decoration: _dec(
                            'Brand Colors',
                            'Ex: #F2A3AE, #3B2B5A (comma separated)',
                          ),
                          validator: _brandColorsValidator,
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.required('Brand Mood / Vibe'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _brandMood,
                          style: const TextStyle(fontSize: _inputFs),
                          menuMaxHeight: 280,
                          items: moods
                              .map((m) => DropdownMenuItem<String>(
                                    value: m,
                                    child: Text(m, style: const TextStyle(fontSize: _dropFs)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _brandMood = v),
                          decoration: _dec('Mood / Vibe', 'Select Mood / Vibe'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Brand Mood / Vibe is required' : null,
                        ),
                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Include Logo by Default?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              Switch(
                                value: _includeLogoByDefault,
                                activeColor: AppColors.deepPlum,
                                inactiveThumbColor: AppColors.blackCatLight,
                                inactiveTrackColor:
                                    AppColors.blackCatLight.withValues(alpha: 0.35),
                                onChanged: (v) => setState(() => _includeLogoByDefault = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  */

                    // -----------------------
                    // âœ… BILLING ADDRESS + SHIPPING TOGGLE
                    // -----------------------
                    _SectionCard(
                      title: 'Billing Address',
                      subtitle:
                          'Enter the billing address/shipping address for your company',
                      child: Column(
                        children: [
                          _FieldLabel.required('Street Address'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _streetCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec(
                                'Street Address',
                                'Enter Billing Street Address',
                              ),
                              onChanged: (_) =>
                                  _autofillBillingAddressFromStreet(),
                              validator: (v) =>
                                  _requiredValidator(v, 'Street Address'),
                            ),
                          ),
                          if (_billingStreetSuggestionsLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (_billingStreetSuggestions.isNotEmpty)
                            Builder(
                              builder: (context) {
                                final suggestionCount =
                                    _billingStreetSuggestions.length;
                                final menuHeight =
                                    AutocompleteDropdownSizing.menuHeight(
                                      itemCount: suggestionCount,
                                      itemExtent: 40,
                                    );
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(color: Colors.black12),
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
                                        _billingStreetSuggestions[i]
                                            .displayLabel,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onTap: () =>
                                          _applyBillingStreetSuggestion(
                                            _billingStreetSuggestions[i],
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('City'),
                          const SizedBox(height: 6),
                          _req(
                            true,
                            TextFormField(
                              controller: _cityCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('City', 'Enter Billing City'),
                              validator: (v) =>
                                  _requiredValidator(v, 'City'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _isBillingUnitedStates
                              ? _FieldLabel.required('State')
                              : _FieldLabel.normal('State / Region'),
                          const SizedBox(height: 6),
                          if (_isBillingUnitedStates)
                            _typeAheadPicker(
                              label: 'State',
                              hint: 'Type billing state',
                              options: usStates,
                              selectedValue: _selectedState,
                              required: true,
                              onChanged: (v) =>
                                  setState(() => _selectedState = v),
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
                                'Enter Billing State / Region',
                              ),
                              validator: (_) => null,
                            ),
                          const SizedBox(height: 16),

                          _isBillingUnitedStates
                              ? _FieldLabel.required('Zip Code')
                              : _FieldLabel.normal('Zip Code'),
                          const SizedBox(height: 6),
                          _req(
                            _isBillingUnitedStates,
                            TextFormField(
                              controller: _zipCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                'Zip Code',
                                'Enter Billing Zip Code',
                              ),
                              validator: (v) => _zipValidator(
                                v,
                                enforceUsPattern: _isBillingUnitedStates,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel.required('Country'),
                          const SizedBox(height: 6),
                          _typeAheadPicker(
                            label: 'Country',
                            hint: 'Type billing country',
                            options: countries,
                            selectedValue: _selectedCountry,
                            required: true,
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _selectedCountry = v;
                                if (_isBillingUnitedStates) {
                                  _manualStateCtrl.clear();
                                } else {
                                  _selectedState = null;
                                }
                              });
                            },
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Country is required'
                                : null,
                          ),
                          const SizedBox(height: 6),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Is Shipping Address same as Billing Address',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _shippingSameAsBilling,
                                  activeThumbColor: AppColors.deepPlum,
                                  inactiveThumbColor: AppColors.blackCatLight,
                                  inactiveTrackColor: AppColors.blackCatLight
                                      .withValues(alpha: 0.35),
                                  onChanged: (v) => setState(
                                    () => _shippingSameAsBilling = v,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (!_shippingSameAsBilling) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _FieldLabel.required('Street Address'),
                            const SizedBox(height: 6),
                            _req(
                              true,
                              TextFormField(
                                controller: _shipStreetCtrl,
                                style: const TextStyle(fontSize: _inputFs),
                                decoration: _dec(
                                  'Street Address',
                                  'Enter Shipping Street Address',
                                ),
                                onChanged: (_) =>
                                    _autofillShippingAddressFromStreet(),
                                validator: (v) => !_shippingSameAsBilling
                                    ? _requiredValidator(v, 'Street Address')
                                    : null,
                              ),
                            ),
                            if (_shippingStreetSuggestionsLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            if (_shippingStreetSuggestions.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  final suggestionCount =
                                      _shippingStreetSuggestions.length;
                                  final menuHeight =
                                      AutocompleteDropdownSizing.menuHeight(
                                        itemCount: suggestionCount,
                                        itemExtent: 40,
                                      );
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.zero,
                                      border: Border.all(color: Colors.black12),
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
                                          _shippingStreetSuggestions[i]
                                              .displayLabel,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onTap: () =>
                                            _applyShippingStreetSuggestion(
                                              _shippingStreetSuggestions[i],
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 16),
                            _FieldLabel.required('City'),
                            const SizedBox(height: 6),
                            _req(
                              true,
                              TextFormField(
                                controller: _shipCityCtrl,
                                style: const TextStyle(fontSize: _inputFs),
                                decoration: _dec('City', 'Enter Shipping City'),
                                validator: (v) => !_shippingSameAsBilling
                                    ? _requiredValidator(v, 'Shipping City')
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _isShippingUnitedStates
                                ? _FieldLabel.required('State')
                                : _FieldLabel.normal('State / Region'),
                            const SizedBox(height: 6),
                            if (_isShippingUnitedStates)
                              _typeAheadPicker(
                                label: 'State',
                                hint: 'Type shipping state',
                                options: usStates,
                                selectedValue: _shipSelectedState,
                                required: true,
                                onChanged: (v) =>
                                    setState(() => _shipSelectedState = v),
                                validator: (v) =>
                                    !_shippingSameAsBilling &&
                                        (v == null || v.trim().isEmpty)
                                    ? 'Shipping State is required'
                                    : null,
                              )
                            else
                              TextFormField(
                                controller: _shipManualStateCtrl,
                                style: const TextStyle(fontSize: _inputFs),
                                decoration: _dec(
                                  'State / Region',
                                  'Enter Shipping State / Region',
                                ),
                                validator: (_) => null,
                              ),
                            const SizedBox(height: 16),
                            _isShippingUnitedStates
                                ? _FieldLabel.required('Zip Code')
                                : _FieldLabel.normal('Zip Code'),
                            const SizedBox(height: 6),
                            _req(
                              _isShippingUnitedStates,
                              TextFormField(
                                controller: _shipZipCtrl,
                                style: const TextStyle(fontSize: _inputFs),
                                keyboardType: TextInputType.number,
                                decoration: _dec(
                                  'Zip Code',
                                  'Enter Shipping Zip Code',
                                ),
                                validator: (v) => !_shippingSameAsBilling
                                    ? _zipValidator(
                                        v,
                                        enforceUsPattern:
                                            _isShippingUnitedStates,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FieldLabel.required('Country'),
                            const SizedBox(height: 6),
                            _typeAheadPicker(
                              label: 'Country',
                              hint: 'Type shipping country',
                              options: countries,
                              selectedValue: _shipSelectedCountry,
                              required: true,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _shipSelectedCountry = v;
                                  if (_isShippingUnitedStates) {
                                    _shipManualStateCtrl.clear();
                                  } else {
                                    _shipSelectedState = null;
                                  }
                                });
                              },
                              validator: (v) =>
                                  !_shippingSameAsBilling &&
                                      (v == null || v.trim().isEmpty)
                                  ? 'Shipping Country is required'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    /*
                  // -----------------------
                  // âœ… REQUEST DEFAULTS (optional, helps modal autofill)
                  // -----------------------
                  _SectionCard(
                    title: 'Request Defaults',
                    subtitle: 'Optional defaults to speed up future company requests',
                    child: Column(
                      children: [
                        // quantity range
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel.normal('Typical Min Qty'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _quantityMinCtrl,
                                    style: const TextStyle(fontSize: _inputFs),
                                    keyboardType: TextInputType.number,
                                    decoration: _dec('Min', 'Ex: 10'),
                                    validator: (v) => _optionalIntValidator(v, 'Typical Min Qty'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel.normal('Typical Max Qty'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _quantityMaxCtrl,
                                    style: const TextStyle(fontSize: _inputFs),
                                    keyboardType: TextInputType.number,
                                    decoration: _dec('Max', 'Ex: 200'),
                                    validator: (v) => _optionalIntValidator(v, 'Typical Max Qty'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.normal('Default Nail Shape'),
                        const SizedBox(height: 6),
                        _dropdownSemantics(
                          label: 'Default Nail Shape',
                          value: _defaultShape,
                          child: DropdownButtonFormField<String>(
                            value: _defaultShape,
                            style: const TextStyle(fontSize: _inputFs),
                            menuMaxHeight: 260,
                            items: nailShapes
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _defaultShape = v),
                            decoration: _dec('Shape', 'Select Shape'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.normal('Default Nail Length'),
                        const SizedBox(height: 6),
                        _dropdownSemantics(
                          label: 'Default Nail Length',
                          value: _defaultLength,
                          child: DropdownButtonFormField<String>(
                            value: _defaultLength,
                            style: const TextStyle(fontSize: _inputFs),
                            menuMaxHeight: 260,
                            items: nailLengths
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _defaultLength = v),
                            decoration: _dec('Length', 'Select Length'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.normal('Default Finish'),
                        const SizedBox(height: 6),
                        _dropdownSemantics(
                          label: 'Default Finish',
                          value: _defaultFinish,
                          child: DropdownButtonFormField<String>(
                            value: _defaultFinish,
                            style: const TextStyle(fontSize: _inputFs),
                            menuMaxHeight: 260,
                            items: finishes
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _defaultFinish = v),
                            decoration: _dec('Finish', 'Select Finish'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.normal('Default Priority'),
                        const SizedBox(height: 6),
                        _dropdownSemantics(
                          label: 'Default Priority',
                          value: _defaultPriority,
                          child: DropdownButtonFormField<String>(
                            value: _defaultPriority,
                            style: const TextStyle(fontSize: _inputFs),
                            menuMaxHeight: 220,
                            items: priorities
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _defaultPriority = v),
                            decoration: _dec('Priority', 'Select Priority'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _FieldLabel.normal('Typical Budget Range'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${_budgetRange.start.toStringAsFixed(0)}  â€“  \$${_budgetRange.end.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              RangeSlider(
                                values: _budgetRange,
                                min: 0,
                                max: 2000,
                                divisions: 200,
                                activeColor: AppColors.deepPlum,
                                onChanged: (v) => setState(() => _budgetRange = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  // âœ… Nail Preferences (always shown in V2)
                  NailPreferencesInlineEditor(
                    initial: _nailPrefs,
                    onChanged: (updated) => setState(() => _nailPrefs = updated),
                  ),
                  const SizedBox(height: 6),

                  // âœ… Payment (always shown in V2)
                  PaymentMethodSection(
                    initial: _payment,
                    onChanged: (updated) => setState(() => _payment = updated),
                  ),


                  const SizedBox(height: 6),
                  promosAndNailTipsCard(),
                  const SizedBox(height: 6),

                  // âœ… Scenario 2: show kit purchase section only if checkbox NOT selected (kept)
                  /*if (!_hasSizingKitAlready) ...[
                    if (!_kitPurchased)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Purchase the Nail Sizing Kit to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    NailSizingKitSection(
                      purchased: _kitPurchased,
                      onAddToCart: _startCheckout,
                    ),
                  ],*/
                  */
                    _SectionCard(
                      title: 'Payment Method',
                      subtitle: 'Enter your preferred payment method.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          //_FieldLabel.required('Billing Method'),
                          const SizedBox(height: 6),
                          Column(
                            children: _billingMethods.map((method) {
                              final selected = _billingMethod == method;
                              return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.deepPlum
                                          : Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () => setState(
                                          () => _billingMethod = method,
                                        ),
                                        child: Row(
                                          children: [
                                            Radio<String>(
                                              value: method,
                                              groupValue: _billingMethod,
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(
                                                  () => _billingMethod = value,
                                                );
                                              },
                                              activeColor: AppColors.deepPlum,
                                            ),
                                            Expanded(
                                              child: Text(
                                                method,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(height: 6),
                                        if (method == 'Credit/Debit Card') ...[
                                          TextFormField(
                                            controller: _cardNameCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            decoration: _dec(
                                              'Name on Card',
                                              'Enter Name on Card',
                                            ),
                                            validator: (v) =>
                                                _billingRequiredIfSelected(
                                                  v,
                                                  method: method,
                                                  fieldName: 'Name on Card',
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _cardNumberCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                19,
                                              ),
                                              CardNumberTextInputFormatter(),
                                            ],
                                            decoration: _dec(
                                              'Card Number',
                                              'Enter Card Number',
                                            ),
                                            validator: (v) =>
                                                _billingRequiredIfSelected(
                                                  v,
                                                  method: method,
                                                  fieldName: 'Card Number',
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _cardExpiryCtrl,
                                                  style: const TextStyle(
                                                    fontSize: _inputFs,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                      4,
                                                    ),
                                                    ExpiryDateTextInputFormatter(),
                                                  ],
                                                  decoration: _dec(
                                                    'Expiration Date',
                                                    'MM/YY',
                                                  ),
                                                  validator: (v) =>
                                                      _billingRequiredIfSelected(
                                                        v,
                                                        method: method,
                                                        fieldName:
                                                            'Expiration Date',
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _cardCvvCtrl,
                                                  style: const TextStyle(
                                                    fontSize: _inputFs,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                      4,
                                                    ),
                                                  ],
                                                  decoration: _dec(
                                                    'CVV',
                                                    'CVV',
                                                  ),
                                                  validator: (v) =>
                                                      _billingRequiredIfSelected(
                                                        v,
                                                        method: method,
                                                        fieldName: 'CVV',
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (method == 'ACH Transfer') ...[
                                          TextFormField(
                                            controller: _achAccountNameCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            decoration: _dec(
                                              'Account Holder Name',
                                              'Enter Account Holder Name',
                                            ),
                                            validator: (v) =>
                                                _billingRequiredIfSelected(
                                                  v,
                                                  method: method,
                                                  fieldName:
                                                      'Account Holder Name',
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _achRoutingCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType: TextInputType.number,
                                            decoration: _dec(
                                              'Routing Number',
                                              'Enter Routing Number',
                                            ),
                                            validator: (v) =>
                                                _billingRequiredIfSelected(
                                                  v,
                                                  method: method,
                                                  fieldName: 'Routing Number',
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _achAccountCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType: TextInputType.number,
                                            decoration: _dec(
                                              'Account Number',
                                              'Enter Account Number',
                                            ),
                                            validator: (v) =>
                                                _billingRequiredIfSelected(
                                                  v,
                                                  method: method,
                                                  fieldName: 'Account Number',
                                                ),
                                          ),
                                        ],
                                        if (method == 'Apple Pay') ...[
                                          TextFormField(
                                            controller: _applePayEmailCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            decoration: _dec(
                                              'Apple Pay Email',
                                              'Enter Apple Pay Email',
                                            ),
                                            validator: (v) {
                                              final requiredErr =
                                                  _billingRequiredIfSelected(
                                                    v,
                                                    method: method,
                                                    fieldName:
                                                        'Apple Pay Email',
                                                  );
                                              if (requiredErr != null) {
                                                return requiredErr;
                                              }
                                              if (_billingMethod == method) {
                                                return _emailValidator(v);
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                        if (method == 'Google Pay') ...[
                                          TextFormField(
                                            controller: _googlePayEmailCtrl,
                                            style: const TextStyle(
                                              fontSize: _inputFs,
                                            ),
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            decoration: _dec(
                                              'Google Pay Email',
                                              'Enter Google Pay Email',
                                            ),
                                            validator: (v) {
                                              final requiredErr =
                                                  _billingRequiredIfSelected(
                                                    v,
                                                    method: method,
                                                    fieldName:
                                                        'Google Pay Email',
                                                  );
                                              if (requiredErr != null) {
                                                return requiredErr;
                                              }
                                              if (_billingMethod == method) {
                                                return _emailValidator(v);
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _saveBillingForFutureUse,
                            onChanged: (v) => setState(
                              () => _saveBillingForFutureUse = v ?? false,
                            ),
                            activeColor: AppColors.deepPlum,
                            title: const Text(
                              'Save for future use',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Payout',
                      subtitle:
                          'How your brand receives payouts or reimbursements.',
                      child: Column(
                        children: [
                          _dropdownSemantics(
                            label: 'Payout Method',
                            value: _payoutMethod.name,
                            required: true,
                            child: DropdownButtonFormField<CompanyPayoutMethod>(
                              initialValue: _payoutMethod,
                              style: const TextStyle(
                                fontSize: _inputFs,
                                color: AppColors.blackCat,
                              ),
                              decoration: _dec(
                                'Payout Method',
                                'Select payout method',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: CompanyPayoutMethod.paypal,
                                  child: Text('PayPal'),
                                ),
                                DropdownMenuItem(
                                  value: CompanyPayoutMethod.venmo,
                                  child: Text('Venmo'),
                                ),
                                DropdownMenuItem(
                                  value: CompanyPayoutMethod.bankTransfer,
                                  child: Text('Bank Transfer'),
                                ),
                                DropdownMenuItem(
                                  value: CompanyPayoutMethod.applePay,
                                  child: Text('Apple Pay'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _payoutMethod =
                                    value ?? CompanyPayoutMethod.paypal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_payoutMethod == CompanyPayoutMethod.paypal ||
                              _payoutMethod == CompanyPayoutMethod.venmo) ...[
                            TextFormField(
                              controller: _payoutLegalNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('Legal Name', 'Legal Name'),
                              validator: (v) =>
                                  _payoutRequiredValidator(v, 'Legal Name'),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutEmailCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec(
                                _payoutMethod == CompanyPayoutMethod.venmo
                                    ? 'Venmo Email'
                                    : 'PayPal Email',
                                'Email',
                              ),
                              validator: _emailValidator,
                            ),
                          ],
                          if (_payoutMethod ==
                              CompanyPayoutMethod.bankTransfer) ...[
                            TextFormField(
                              controller: _payoutLegalNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('Legal Name', 'Legal Name'),
                              validator: (v) =>
                                  _payoutRequiredValidator(v, 'Legal Name'),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutBankNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('Bank Name', 'Bank name'),
                              validator: (v) =>
                                  _payoutRequiredValidator(v, 'Bank Name'),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutRoutingCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                'Routing Number',
                                'Routing number',
                              ),
                              validator: (v) => _payoutRequiredValidator(
                                v,
                                'Routing Number',
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutAccountNumberCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.number,
                              decoration: _dec(
                                'Account Number',
                                'Account number',
                              ),
                              validator: (v) => _payoutRequiredValidator(
                                v,
                                'Account Number',
                              ),
                            ),
                          ],
                          if (_payoutMethod == CompanyPayoutMethod.applePay) ...[
                            TextFormField(
                              controller: _payoutApplePayNameCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('Full Name', 'Name on Apple Pay'),
                              validator: (v) =>
                                  _payoutRequiredValidator(v, 'Full Name'),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutApplePayPhoneCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                                UsPhoneTextInputFormatter(),
                              ],
                              decoration: _dec(
                                'Phone Number',
                                'Apple Pay phone',
                              ),
                              validator: _phoneValidator,
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _payoutApplePayEmailCtrl,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec(
                                'Apple ID Email',
                                'Email linked to Apple Pay',
                              ),
                              validator: _emailValidator,
                            ),
                          ],
                        ],
                      ),
                    ),

                    ],
                    const SizedBox(height: 18),
                    _wizardNavButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

/// ------------------------
/// UI Components (same as your style, minimal changes)
/// ------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              height: 1.25,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ProfileUpload extends StatelessWidget {
  const _ProfileUpload({
    required this.onTap,
    required this.label,
    this.image,
    this.focusNode,
  });
  final VoidCallback onTap;
  final String label;
  final ImageProvider? image;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return RegistrationProfileUpload(
      onTap: onTap,
      imageProvider: image,
      label: label,
      helperText: image == null ? 'Tap to upload company logo' : 'Tap to change company logo',
      focusNode: focusNode,
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
