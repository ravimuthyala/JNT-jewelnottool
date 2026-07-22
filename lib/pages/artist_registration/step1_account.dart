import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/currency_options.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/registration_input_utils.dart';
import '../../widgets/registration_profile_upload.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class Step1Account extends StatefulWidget {
  const Step1Account({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<Step1Account> createState() => Step1AccountState();
}

class Step1AccountState extends State<Step1Account> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _studioNameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  Timer? _emailAvailabilityDebounce;
  bool _checkingEmailAvailability = false;
  String? _lastCheckedEmail;
  String? _emailTakenRole;
  late final TextEditingController _addressLine1Ctrl;
  late final TextEditingController _addressCityCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _manualStateCtrl;

  String? _currency;
  String _phoneAreaCode = '+1';
  Uint8List? _profileBytes;
  final ImagePicker _picker = ImagePicker();

  String _country = 'United States';
  String? _state;

  bool get _isUS => _country == 'United States';

  Widget _countryCodeDropdown({
    required String value,
    required ValueChanged<CountryCode> onChanged,
    bool embedded = false,
  }) {
    return Localizations.override(
      context: context,
      locale: const Locale('en'),
      child: Container(
        height: 46,
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
                    fontSize: kInputFs,
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

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _studioNameCtrl = TextEditingController(text: draft.studioName);
    _displayNameCtrl = TextEditingController(text: draft.displayName);
    _languageCtrl = TextEditingController(text: draft.languageSpoken);
    _bioCtrl = TextEditingController(text: draft.bio);
    _phoneCtrl = TextEditingController(text: draft.phone);
    _emailCtrl = TextEditingController(text: draft.email);
    _addressLine1Ctrl = TextEditingController(text: draft.addressLine1);
    _addressCityCtrl = TextEditingController(text: draft.addressCity);
    _zipCtrl = TextEditingController(text: draft.zip);
    _manualStateCtrl = TextEditingController(text: draft.manualState);
    _phoneAreaCode = draft.phoneAreaCode.isEmpty ? '+1' : draft.phoneAreaCode;
    _profileBytes = draft.profileBytes;
    _currency = draft.currency.isEmpty ? 'US Dollar (USD)' : draft.currency;
    _country = draft.country.isEmpty ? 'United States' : draft.country;
    _state = draft.state;
  }

  @override
  void dispose() {
    _emailAvailabilityDebounce?.cancel();
    _studioNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _languageCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressCityCtrl.dispose();
    _zipCtrl.dispose();
    _manualStateCtrl.dispose();
    super.dispose();
  }

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

  void autofill() {
    setState(() {
      _studioNameCtrl.text = 'Luna Nails Studio';
      _displayNameCtrl.text = 'Luna Nails';
      _languageCtrl.text = 'English';
      _currency = 'US Dollar (USD)';
      _bioCtrl.text =
          'Professional nail artist with 5+ years of experience. Specializing in intricate nail art, gel designs, and 3D nail sculptures.';
      _phoneCtrl.text = '5551234567';
      _phoneAreaCode = '+1';
      _addressLine1Ctrl.text = '123 Sunset Blvd';
      _addressCityCtrl.text = 'Los Angeles';
      _state = 'California';
      _manualStateCtrl.clear();
      _zipCtrl.text = '90028';
      _country = 'United States';
      _emailCtrl.text = 'luna.nails@test.com';
    });
  }

  void _onEmailChanged(String value) {
    _emailAvailabilityDebounce?.cancel();
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty || !normalized.contains('@')) {
      if (_emailTakenRole != null || _checkingEmailAvailability) {
        setState(() {
          _emailTakenRole = null;
          _checkingEmailAvailability = false;
        });
      }
      return;
    }

    setState(() => _checkingEmailAvailability = true);
    _emailAvailabilityDebounce = Timer(const Duration(milliseconds: 500), () async {
      final role = await SupabaseAuthService.findExistingRoleForEmail(
        normalized,
      );
      if (!mounted) return;
      if (_emailCtrl.text.trim().toLowerCase() != normalized) return;
      setState(() {
        _checkingEmailAvailability = false;
        _lastCheckedEmail = normalized;
        _emailTakenRole = role;
      });
    });
  }

  Widget _buildEmailAvailabilityStatus() {
    final normalized = _emailCtrl.text.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return const SizedBox.shrink();
    }
    if (_checkingEmailAvailability) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          'Checking email availability…',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    if (_emailTakenRole != null && normalized == _lastCheckedEmail) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          SupabaseAuthService.emailAlreadyRegisteredMessage,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB3261E),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    draft.studioName = _studioNameCtrl.text.trim();
    draft.displayName = _displayNameCtrl.text.trim();
    draft.languageSpoken = _languageCtrl.text.trim();
    draft.currency = _currency ?? 'US Dollar (USD)';
    draft.bio = _bioCtrl.text.trim();
    draft.phone = _phoneCtrl.text.trim();
    draft.phoneAreaCode = _phoneAreaCode;
    draft.email = _emailCtrl.text.trim();
    draft.profileBytes = _profileBytes;
    draft.addressLine1 = _addressLine1Ctrl.text.trim();
    draft.addressLine2 = '';
    draft.addressCity = _addressCityCtrl.text.trim();
    draft.zip = _zipCtrl.text.trim();
    draft.country = _country;
    draft.state = _state;
    draft.manualState = _manualStateCtrl.text.trim();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(
      color: Color(0xFF292222),
      fontSize: 14,
      fontFamily: 'Arial',
    );

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          regSectionCard(
            title: 'Artist Profile',
            child: Column(
              children: [
                Center(
                  child: RegistrationProfileUpload(
                    onTap: _pickProfilePic,
                    imageBytes: _profileBytes,
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _studioNameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Full Name / Studio Name is required'
                      : null,
                  decoration: regDec(
                    'Full Name / Studio Name',
                    'Full Name / Studio Name',
                  ),
                  style: fieldStyle,
                  ),
                ),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _displayNameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Display Name is required'
                      : null,
                  decoration: regDec('Display Name', 'Display Name'),
                  style: fieldStyle,
                  ),
                ),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _languageCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Language is required'
                      : null,
                  decoration: regDec(
                    'Language(s) Spoken',
                    'e.g. English, Spanish',
                  ),
                  style: fieldStyle,
                  ),
                ),
                const SizedBox(height: kFieldGap),
                RegTypeAheadField(
                  label: 'Currency *',
                  hint: 'Select currency',
                  options: currencyOptions,
                  selectedValue: _currency,
                  onChanged: (value) => setState(() => _currency = value),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Currency is required'
                      : null,
                ),
                const SizedBox(height: kFieldGap),
                FormField<String>(
                  validator: (value) =>
                      (RegistrationInputUtils.normalizePhone(
                            _phoneCtrl.text,
                          ).length <
                          10)
                      ? 'Enter a valid phone number'
                      : null,
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 46,
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
                                    () =>
                                        _phoneAreaCode = code.dialCode ?? '+1',
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
                                  isRequired: true,
                                  child: TextFormField(
                                  controller: _phoneCtrl,
                                  style: const TextStyle(fontSize: kInputFs),
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
                                      fontSize: kHintFs - 0.5,
                                      color: AppColors.blackCat.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontFamily: 'Arial',
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: kFieldVertPad,
                                    ),
                                    isDense: false,
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
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: _onEmailChanged,
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) return 'Email is required';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    final normalized = email.toLowerCase();
                    if (_emailTakenRole != null &&
                        normalized == _lastCheckedEmail) {
                      return SupabaseAuthService.emailAlreadyRegisteredMessage;
                    }
                    return null;
                  },
                  decoration: regDec('Email', 'you@example.com'),
                  style: fieldStyle,
                  ),
                ),
                _buildEmailAvailabilityStatus(),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _bioCtrl,
                  textInputAction: TextInputAction.done,
                  maxLines: 4,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Bio is required'
                      : null,
                  decoration: regDec('Bio / About', 'Tell clients about you'),
                  style: fieldStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Address Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                regRequiredLabel('Street Address'),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _addressLine1Ctrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('Street Address', 'Enter Street Address'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Street Address is required'
                      : null,
                  ),
                ),
                const SizedBox(height: 12),
                regRequiredLabel('City'),
                const SizedBox(height: 6),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _addressCityCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('City', 'Enter City'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'City is required' : null,
                  ),
                ),
                const SizedBox(height: kFieldGap),
                if (_isUS)
                  regRequiredLabel('State')
                else
                  const Text(
                    'State / Region',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat,
                    ),
                  ),
                const SizedBox(height: 6),
                if (_isUS)
                  RegTypeAheadField(
                    label: 'State',
                    hint: 'Select State',
                    options: kUsStates,
                    selectedValue: _state,
                    onChanged: (v) => setState(() => _state = v),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'State is required'
                        : null,
                  )
                else
                  Semantics(
                    isRequired: true,
                    child: TextFormField(
                    controller: _manualStateCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec(
                      'State / Region',
                      'Enter State / Region',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'State / Region is required'
                        : null,
                    ),
                  ),
                const SizedBox(height: kFieldGap),
                if (_isUS)
                  regRequiredLabel('Zip Code')
                else
                  const Text(
                    'Zip Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat,
                    ),
                  ),
                const SizedBox(height: 6),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _zipCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  keyboardType: TextInputType.text,
                  decoration: regDec('Zip Code', 'Enter Zip Code'),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return 'Zip Code is required';
                    if (!_isUS) return null;
                    if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(val)) {
                      return 'Enter a valid ZIP code';
                    }
                    return null;
                  },
                  ),
                ),
                const SizedBox(height: kFieldGap),
                regRequiredLabel('Country'),
                const SizedBox(height: 6),
                RegTypeAheadField(
                  label: 'Country',
                  hint: 'Select Country',
                  options: kCountries,
                  selectedValue: _country,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _country = v;
                      if (_country != 'United States') {
                        _state = null;
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
