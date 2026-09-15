import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/currency_options.dart';
import '../../services/address_validation_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/registration_input_utils.dart';
import '../../widgets/accessible_date_grid.dart';
import '../../widgets/autocomplete_dropdown_sizing.dart';
import '../../widgets/registration_date_of_birth_picker.dart';
import '../../widgets/registration_profile_upload.dart';
import '../../widgets/responsive_field_row.dart';
import '../register_page.dart' show showRegisterModal;
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

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _studioNameCtrl;
  late final TextEditingController _dateOfBirthCtrl;
  DateTime? _dateOfBirth;
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
  List<AddressSuggestion> _streetSuggestions = const [];
  bool _streetSuggestionsLoading = false;
  Timer? _streetAutocompleteDebounce;

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
    _fullNameCtrl = TextEditingController(text: draft.fullName);
    _studioNameCtrl = TextEditingController(text: draft.studioName);
    _dateOfBirth = draft.dateOfBirth;
    _dateOfBirthCtrl = TextEditingController(
      text: draft.dateOfBirth == null
          ? ''
          : RegistrationInputUtils.formatDateOfBirth(draft.dateOfBirth!),
    );
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
    _streetAutocompleteDebounce?.cancel();
    _fullNameCtrl.dispose();
    _studioNameCtrl.dispose();
    _dateOfBirthCtrl.dispose();
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
      _fullNameCtrl.text = 'Luna Rivera';
      _studioNameCtrl.text = 'Luna Nails Studio';
      _dateOfBirth = DateTime(1995, 6, 15);
      _dateOfBirthCtrl.text = RegistrationInputUtils.formatDateOfBirth(
        _dateOfBirth!,
      );
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

  Future<void> _showAgeIneligibleDialog() async {
    await showRegistrationAgeIneligibleDialog(context: context);
    if (!mounted) return;
    // Same "close registration, return to Home, reopen the role picker"
    // sequence as the wizard's own X button (see JntModalAppBar.onClose in
    // artist_registration_flow.dart) -- an ineligible DOB means this signup
    // attempt can't continue, so send them back to the start rather than
    // leaving them stuck on this step or bouncing to a login screen that
    // doesn't apply (they don't have an account).
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final currentRoute = ModalRoute.of(context);
    rootNavigator.pop();
    if (currentRoute != null) {
      await currentRoute.completed;
    }
    if (!rootNavigator.mounted) return;
    await showRegisterModal(rootNavigator.context);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selected = await showAccessibleDatePickerDialog(
      context: context,
      fieldLabel: 'Date of Birth',
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
      initialSelectedDate: _dateOfBirth ?? today,
    );
    if (selected == null || !mounted) return;

    setState(() {
      _dateOfBirth = selected;
      _dateOfBirthCtrl.text = RegistrationInputUtils.formatDateOfBirth(
        selected,
      );
    });

    if (!RegistrationInputUtils.isEligibleByDateOfBirth(selected) && mounted) {
      await _showAgeIneligibleDialog();
    }
  }

  // Lets a sighted or screen-reader user type the date directly instead of
  // requiring the calendar picker. Checks eligibility as soon as a complete,
  // parseable date is typed -- matches the picker path so the ineligibility
  // dialog fires right at the DOB field itself, not only later at submit.
  // tryParseMmDdYyyy returns null for an incomplete in-progress string, so
  // this doesn't fire on every keystroke, only once the date is complete.
  void _onDateOfBirthTyped(String value) {
    final parsed = tryParseMmDdYyyy(value);
    setState(() => _dateOfBirth = parsed);
    if (parsed != null &&
        !RegistrationInputUtils.isEligibleByDateOfBirth(parsed) &&
        mounted) {
      _showAgeIneligibleDialog();
    }
  }

  String? _dateOfBirthValidator(String? value) {
    if (_dateOfBirth == null) return 'Date of Birth is required';
    return null;
  }

  Future<void> _autofillAddressFromStreet() async {
    _streetAutocompleteDebounce?.cancel();
    final query = _addressLine1Ctrl.text.trim();
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
      _addressLine1Ctrl.text = selected.street;
      _addressCityCtrl.text = selected.city;
      _zipCtrl.text = selected.zip;
      _country = 'United States';
      final resolved =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      final matched = kUsStates.where((s) => s == resolved).toList();
      _state = matched.isNotEmpty ? matched.first : null;
      _manualStateCtrl.clear();
      _streetSuggestions = const [];
    });
  }

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields -- resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectStreetSuggestion(AddressSuggestion selected) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyStreetSuggestion(resolved);
        return;
      }
    }
    _applyStreetSuggestion(selected);
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

  Future<bool> validateAndSave(RegistrationDraft draft) async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    // Field-level checks in _pickDateOfBirth/_onDateOfBirthTyped already
    // show this dialog as soon as an ineligible date is entered -- this is
    // a safety net for whatever value ended up in _dateOfBirth by the time
    // "Next" is pressed (e.g. paste, or autofill).
    if (_dateOfBirth != null &&
        !RegistrationInputUtils.isEligibleByDateOfBirth(_dateOfBirth!)) {
      await _showAgeIneligibleDialog();
      return false;
    }
    draft.fullName = _fullNameCtrl.text.trim();
    draft.studioName = _studioNameCtrl.text.trim();
    draft.dateOfBirth = _dateOfBirth;
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
                ResponsiveFieldRow(
                  gap: kFieldGap,
                  fields: [
                    Semantics(
                      isRequired: true,
                      child: TextFormField(
                        controller: _fullNameCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Full Name is required'
                            : null,
                        decoration: regDec('Full Name', 'Full Name'),
                        style: fieldStyle,
                      ),
                    ),
                    Semantics(
                      isRequired: true,
                      child: TextFormField(
                        controller: _studioNameCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Studio Name is required'
                            : null,
                        decoration: regDec('Studio Name', 'Studio Name'),
                        style: fieldStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                    controller: _dateOfBirthCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [DateOfBirthTextInputFormatter()],
                    style: fieldStyle,
                    onChanged: _onDateOfBirthTyped,
                    decoration: regDec(
                      'Date of Birth',
                      'MM/DD/YYYY',
                      suffixIcon: IconButton(
                        tooltip: 'Pick date of birth',
                        onPressed: _pickDateOfBirth,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                    validator: _dateOfBirthValidator,
                  ),
                ),
                const SizedBox(height: kFieldGap),
                ResponsiveFieldRow(
                  gap: kFieldGap,
                  fields: [
                    Semantics(
                      isRequired: true,
                      child: TextFormField(
                        controller: _languageCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Language is required'
                            : null,
                        decoration: regDec(
                          'Language(s) Spoken',
                          'e.g. English, Spanish',
                        ),
                        style: fieldStyle,
                      ),
                    ),
                    RegTypeAheadField(
                      label: 'Currency *',
                      hint: 'Select currency',
                      options: currencyOptions,
                      selectedValue: _currency,
                      onChanged: (value) => setState(() => _currency = value),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Currency is required'
                          : null,
                    ),
                  ],
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
                  onChanged: (_) => _autofillAddressFromStreet(),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Street Address is required'
                      : null,
                  ),
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
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppColors.blackCat.withValues(alpha: 0.20),
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
                            onTap: () => _selectStreetSuggestion(
                              _streetSuggestions[i],
                            ),
                          ),
                        ),
                      );
                    },
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
                ResponsiveFieldRow(
                  gap: kFieldGap,
                  fields: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                              if (!RegExp(
                                r'^\d{5}(-\d{4})?$',
                              ).hasMatch(val)) {
                                return 'Enter a valid ZIP code';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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
