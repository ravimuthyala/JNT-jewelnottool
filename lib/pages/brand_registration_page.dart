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
import '../services/address_validation_service.dart';
import '../services/supabase_auth_service.dart';
import '../utils/registration_input_utils.dart';
import '../widgets/registration_profile_upload.dart';
import '../widgets/communication_preference_section.dart';

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

class _BrandRegistrationPageState extends State<BrandRegistrationPage> {
  static const Duration _registrationStepTimeout = Duration(seconds: 20);
  static const Duration _logoUploadTimeout = Duration(seconds: 20);
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _logoUploadFocusNode = FocusNode(
    debugLabel: 'companyLogoUpload',
  );
  final FocusNode _billingAddressTopFocusNode = FocusNode(
    debugLabel: 'billingAddressTop',
  );

  // Persistent accessibility targets. These keep TalkBack on the actual
  // field/control through step changes, validation, and OS pickers.
  final GlobalKey _logoUploadSemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationLogoUploadA11y',
  );
  final GlobalKey _companyNameSemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationCompanyNameA11y',
  );
  final GlobalKey _billingStateSemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationBillingStateA11y',
  );
  final GlobalKey _billingCountrySemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationBillingCountryA11y',
  );
  final GlobalKey _shippingStateSemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationShippingStateA11y',
  );
  final GlobalKey _shippingCountrySemanticsKey = GlobalKey(
    debugLabel: 'brandRegistrationShippingCountryA11y',
  );
  final Map<String, GlobalKey> _billingMethodSemanticsKeys =
      <String, GlobalKey>{
        'Credit/Debit Card': GlobalKey(
          debugLabel: 'brandRegistrationCreditCardMethodA11y',
        ),
        'ACH Transfer': GlobalKey(
          debugLabel: 'brandRegistrationAchMethodA11y',
        ),
        'Apple Pay': GlobalKey(
          debugLabel: 'brandRegistrationApplePayMethodA11y',
        ),
        'Google Pay': GlobalKey(
          debugLabel: 'brandRegistrationGooglePayMethodA11y',
        ),
      };

  final FocusNode _companyNameFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCompanyName',
  );
  final FocusNode _companyEmailFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCompanyEmail',
  );
  final FocusNode _companyPhoneFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCompanyPhone',
  );
  final FocusNode _passwordFocusNode = FocusNode(
    debugLabel: 'brandRegistrationPassword',
  );
  final FocusNode _confirmPasswordFocusNode = FocusNode(
    debugLabel: 'brandRegistrationConfirmPassword',
  );
  final FocusNode _companyUrlFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCompanyUrl',
  );
  final FocusNode _tiktokFocusNode = FocusNode(
    debugLabel: 'brandRegistrationTikTok',
  );
  final FocusNode _instagramFocusNode = FocusNode(
    debugLabel: 'brandRegistrationInstagram',
  );
  final FocusNode _contactNameFocusNode = FocusNode(
    debugLabel: 'brandRegistrationContactName',
  );
  final FocusNode _contactEmailFocusNode = FocusNode(
    debugLabel: 'brandRegistrationContactEmail',
  );
  final FocusNode _contactPhoneFocusNode = FocusNode(
    debugLabel: 'brandRegistrationContactPhone',
  );
  final FocusNode _billingCityFocusNode = FocusNode(
    debugLabel: 'brandRegistrationBillingCity',
  );
  final FocusNode _billingManualStateFocusNode = FocusNode(
    debugLabel: 'brandRegistrationBillingManualState',
  );
  final FocusNode _billingZipFocusNode = FocusNode(
    debugLabel: 'brandRegistrationBillingZip',
  );
  final FocusNode _shippingStreetFocusNode = FocusNode(
    debugLabel: 'brandRegistrationShippingStreet',
  );
  final FocusNode _shippingCityFocusNode = FocusNode(
    debugLabel: 'brandRegistrationShippingCity',
  );
  final FocusNode _shippingManualStateFocusNode = FocusNode(
    debugLabel: 'brandRegistrationShippingManualState',
  );
  final FocusNode _shippingZipFocusNode = FocusNode(
    debugLabel: 'brandRegistrationShippingZip',
  );
  final FocusNode _cardNameFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCardName',
  );
  final FocusNode _cardNumberFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCardNumber',
  );
  final FocusNode _cardExpiryFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCardExpiry',
  );
  final FocusNode _cardCvvFocusNode = FocusNode(
    debugLabel: 'brandRegistrationCardCvv',
  );
  final FocusNode _achAccountNameFocusNode = FocusNode(
    debugLabel: 'brandRegistrationAchAccountName',
  );
  final FocusNode _achRoutingFocusNode = FocusNode(
    debugLabel: 'brandRegistrationAchRouting',
  );
  final FocusNode _achAccountFocusNode = FocusNode(
    debugLabel: 'brandRegistrationAchAccount',
  );
  final FocusNode _applePayEmailFocusNode = FocusNode(
    debugLabel: 'brandRegistrationApplePayEmail',
  );
  final FocusNode _googlePayEmailFocusNode = FocusNode(
    debugLabel: 'brandRegistrationGooglePayEmail',
  );
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
  final ScrollController _registrationScrollController = ScrollController();

  static const List<String> _registrationStepTitles = <String>[
    'Company Profile\n& Primary Contact',
    'Address\n& Payment',
  ];

  // -----------------------
  // EXISTING (kept)
  // -----------------------
  final _nameCtrl = TextEditingController(); // (kept) original "Name"
  final _emailCtrl = TextEditingController();
  Timer? _emailAvailabilityDebounce;
  bool _checkingEmailAvailability = false;
  String? _lastCheckedEmail;
  String? _emailTakenRole;
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  // âœ… NEW: for the updated Company Profile + Account Creation section
  final _confirmPassCtrl = TextEditingController();

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
  String? _passwordError;
  String? _confirmPasswordError;
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
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  final _achAccountNameCtrl = TextEditingController();
  final _achRoutingCtrl = TextEditingController();
  final _achAccountCtrl = TextEditingController();

  final _applePayEmailCtrl = TextEditingController();
  final _googlePayEmailCtrl = TextEditingController();

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
    _emailAvailabilityDebounce?.cancel();
    _registrationScrollController.dispose();
    _logoUploadFocusNode.dispose();
    _billingAddressTopFocusNode.dispose();
    _companyNameFocusNode.dispose();
    _companyEmailFocusNode.dispose();
    _companyPhoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _companyUrlFocusNode.dispose();
    _tiktokFocusNode.dispose();
    _instagramFocusNode.dispose();
    _contactNameFocusNode.dispose();
    _contactEmailFocusNode.dispose();
    _contactPhoneFocusNode.dispose();
    _billingCityFocusNode.dispose();
    _billingManualStateFocusNode.dispose();
    _billingZipFocusNode.dispose();
    _shippingStreetFocusNode.dispose();
    _shippingCityFocusNode.dispose();
    _shippingManualStateFocusNode.dispose();
    _shippingZipFocusNode.dispose();
    _cardNameFocusNode.dispose();
    _cardNumberFocusNode.dispose();
    _cardExpiryFocusNode.dispose();
    _cardCvvFocusNode.dispose();
    _achAccountNameFocusNode.dispose();
    _achRoutingFocusNode.dispose();
    _achAccountFocusNode.dispose();
    _applePayEmailFocusNode.dispose();
    _googlePayEmailFocusNode.dispose();
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
      _moveFocusAfterLogoUpload();
      return;
    }

    setState(() {
      _logoPath = img.path;
      _logoBytes = null;
    });
    _moveFocusAfterLogoUpload();
  }

  void _announce(String message) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  void _showSnackAndAnnounce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _announce(message);
  }

  Future<void> _moveAccessibilityFocus({
    FocusNode? focusNode,
    GlobalKey? semanticKey,
    bool scrollIntoView = true,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    BuildContext? targetContext = semanticKey?.currentContext ?? focusNode?.context;
    if (targetContext == null) return;

    if (scrollIntoView) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.18,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
    }

    if (focusNode != null) {
      FocusScope.of(context).requestFocus(focusNode);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    targetContext = semanticKey?.currentContext ?? focusNode?.context;
    targetContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );

    // Android can occasionally drop the first accessibility-focus event
    // while a route, keyboard, or scroll animation is settling.
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    targetContext = semanticKey?.currentContext ?? focusNode?.context;
    targetContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  // If the user cancels the OS image picker, keep them on the Company Logo
  // control because no registration value changed.
  void _restoreLogoUploadFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _moveAccessibilityFocus(
          focusNode: _logoUploadFocusNode,
          semanticKey: _logoUploadSemanticsKey,
        ),
      );
    });
  }

  // After a logo is successfully selected, continue the form instead of
  // returning TalkBack to the app-bar Close button or back to the upload
  // control. Company Name is the next real field for ADA and non-ADA users.
  void _moveFocusAfterLogoUpload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _moveAccessibilityFocus(
          focusNode: _companyNameFocusNode,
          semanticKey: _companyNameSemanticsKey,
        ),
      );
    });
  }

  // -----------------------
  // Font sizes (kept)
  // -----------------------
  static const double _labelFs = 14;
  static const double _inputFs = 14;
  static const double _hintFs = 13.5;
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

  Widget _countryCodeDropdown({
    required String value,
    required String semanticLabel,
    required ValueChanged<CountryCode> onChanged,
    bool embedded = false,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        value: value,
        child: Localizations.override(
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
        ),
      ),
    );
  }

  Future<String?> _showAccessibleChoicePicker({
    required String title,
    required List<String> options,
    required String currentValue,
  }) async {
    // The sheet owns its own TextEditingController and FocusNode. Do not
    // allocate/dispose them here: showModalBottomSheet's Future can complete
    // before its reverse animation has fully unmounted the sheet. Disposing
    // controller/focus objects from this parent method during that interval
    // can leave mounted TextField/Focus widgets referring to disposed state
    // and can trigger Flutter framework teardown assertions.
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RegistrationAccessibleChoiceSheet(
        title: title,
        options: options,
        currentValue: currentValue,
      ),
    );
  }

  Widget _typeAheadPicker({
    required String id,
    required String label,
    required String hint,
    required List<String> options,
    required String? selectedValue,
    required GlobalKey semanticKey,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return FormField<String>(
      // Keep the FormField identity stable when a value is selected.
      // Keying this widget with selectedValue caused Flutter to tear down
      // the old FormField and create a new one while the same Semantics
      // GlobalKey was being reused. On Android this could trip
      // InheritedElement's `_dependents.isEmpty` assertion after selecting
      // a state/country from the modal picker.
      key: ValueKey<String>('accessible-picker-$id'),
      initialValue: selectedValue,
      // selectedValue is the parent/source-of-truth value. This also keeps
      // validation correct when an address suggestion fills State for us
      // programmatically rather than through field.didChange().
      validator: (_) => validator?.call(selectedValue),
      builder: (field) {
        final current = (selectedValue ?? field.value ?? '').trim();

        Future<void> openPicker() async {
          final selected = await _showAccessibleChoicePicker(
            title: label,
            options: options,
            currentValue: current,
          );
          if (selected == null || !mounted) {
            await _moveAccessibilityFocus(
              semanticKey: semanticKey,
              scrollIntoView: false,
            );
            return;
          }

          // showModalBottomSheet completes its result Future before the
          // route necessarily finishes its reverse transition. Let that
          // teardown (including the Search TextField/keyboard) settle before
          // rebuilding this FormField with the newly selected value.
          await Future<void>.delayed(const Duration(milliseconds: 320));
          if (!mounted) return;

          field.didChange(selected);
          onChanged(selected);

          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          await _moveAccessibilityFocus(
            semanticKey: semanticKey,
            scrollIntoView: false,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              key: semanticKey,
              button: true,
              isRequired: required,
              label: label,
              value: current.isEmpty ? 'Not selected' : current,
              hint: 'Double tap to search and select $label',
              onTap: () => unawaited(openPicker()),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => unawaited(openPicker()),
                  // Do not use InputDecorator for these accessible modal
                  // selectors. The page already renders the visible field label
                  // immediately above this control, and InputDecorator can
                  // independently paint label/hint/value layers. On some
                  // Android/Flutter combinations those layers were appearing
                  // on top of one another for Billing/Shipping State.
                  //
                  // A plain bordered row guarantees exactly one visible text
                  // widget inside the selector while the outer Semantics node
                  // still provides the accessible label, value, required state
                  // and activation action.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: _fieldHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: field.hasError
                                ? Theme.of(context).colorScheme.error
                                : AppColors.blackCatBorderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                current.isEmpty ? hint : current,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _inputFs,
                                  color: current.isEmpty
                                      ? Colors.black.withValues(alpha: 0.35)
                                      : AppColors.blackCat,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.search_rounded, size: 18),
                          ],
                        ),
                      ),
                      if (field.hasError) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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

  /// Validates the account signup email (_emailCtrl) specifically, adding
  /// the cross-role "already registered" check on top of the shared format
  /// validation used by [_emailValidator] elsewhere (contact/payout emails).
  String? _accountEmailValidator(String? v) {
    final formatError = _emailValidator(v);
    if (formatError != null) return formatError;
    final normalized = (v ?? '').trim().toLowerCase();
    if (_emailTakenRole != null && normalized == _lastCheckedEmail) {
      return SupabaseAuthService.emailAlreadyRegisteredMessage;
    }
    return null;
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
    _emailAvailabilityDebounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        final role = await SupabaseAuthService.findExistingRoleForEmail(
          normalized,
        );
        if (!mounted) return;
        if (_emailCtrl.text.trim().toLowerCase() != normalized) {
          return;
        }
        setState(() {
          _checkingEmailAvailability = false;
          _lastCheckedEmail = normalized;
          _emailTakenRole = role;
        });
      },
    );
  }

  Widget _buildEmailAvailabilityStatus() {
    if (_showValidationErrors) return const SizedBox.shrink();

    final normalized = _emailCtrl.text.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return const SizedBox.shrink();
    }

    if (_checkingEmailAvailability) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Semantics(
          liveRegion: true,
          child: Text(
          'Checking email availability…',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          ),
        ),
      );
    }

    if (_emailTakenRole != null && normalized == _lastCheckedEmail) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Semantics(
          liveRegion: true,
          child: Text(
          SupabaseAuthService.emailAlreadyRegisteredMessage,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordError = _passwordValidator(value);
      if (_confirmPassCtrl.text.isNotEmpty) {
        _confirmPasswordError = _confirmPasswordValidator(
          _confirmPassCtrl.text,
        );
      }
    });
  }

  void _onConfirmPasswordChanged(String value) {
    setState(() {
      _confirmPasswordError = _confirmPasswordValidator(value);
    });
  }

  Widget _buildPasswordStatus() {
    final hasError = _passCtrl.text.isNotEmpty && _passwordError != null;
    final message = hasError
        ? _passwordError!
        : 'Password must include uppercase, lowercase, number, and symbol.';

    return Semantics(
      container: true,
      liveRegion: hasError,
      label: hasError ? 'Password error. $message' : 'Password rules. $message',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            message,
            style: hasError
                ? const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  )
                : TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordStatus() {
    if (_confirmPassCtrl.text.isEmpty || _confirmPasswordError == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        _confirmPasswordError!,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
    );
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
    const businessType = '';
    final companyPhone = '$_normalizedCompanyAreaCode$companyPhoneLocal';
    final contactPhone = '$_normalizedContactAreaCode$contactPhoneLocal';
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
        'communicationPreferences': {
          'emailNotifications': _emailNotifications,
          'smsNotifications': _smsNotifications,
        },
      },
      'basic': {
        'profileImageUrl': safeProfilePhotoUrl,
        'photoUrl': safeProfilePhotoUrl,
        'avatarUrl': safeProfilePhotoUrl,
        'communicationPreferences': {
          'emailNotifications': _emailNotifications,
          'smsNotifications': _smsNotifications,
        },
      },
      'company': {
        'name': companyName,
        'contactName': contactName,
        'businessType': businessType,
        'communicationPreferences': {
          'emailNotifications': _emailNotifications,
          'smsNotifications': _smsNotifications,
        },
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
      'profile': payload['profile'],
      'basic': payload['basic'],
      'company': payload['company'],
      'addresses': payload['addresses'],
      'billing': payload['billing'],
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
    if (_formKey.currentState?.validate() != true) {
      await _focusFirstRegistrationError();
      return;
    }
    if (!_hasRequiredBillingMethod()) {
      await _focusFirstRegistrationError();
      _showBillingValidationMessage(
        'Please complete the selected payment method before continuing.',
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
        final message =
            billingValidation.message ?? 'Invalid U.S. billing address.';
        _showSnackAndAnnounce(message);
        await _moveAccessibilityFocus(
          focusNode: _billingAddressTopFocusNode,
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
        final message =
            shippingValidation.message ?? 'Invalid U.S. shipping address.';
        _showSnackAndAnnounce(message);
        await _moveAccessibilityFocus(
          focusNode: _shippingStreetFocusNode,
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
        final existingRole = await SupabaseAuthService.findExistingRoleForEmail(
          _emailCtrl.text,
        );

        // An email maps to exactly one account. Block cross-role reuse
        // instead of silently attaching a second role to it. Same-role (or
        // no role data yet — a prior signup that never finished writing its
        // row) is a safe repair/resubmit case.
        if (existingRole != null && existingRole != 'company') {
          if (!mounted) return;
          _showSnackAndAnnounce(
            SupabaseAuthService.emailAlreadyRegisteredMessage,
          );
          await _moveAccessibilityFocus(
            focusNode: _companyEmailFocusNode,
          );
          return;
        }

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
      _showSnackAndAnnounce(message);
    } on TimeoutException {
      if (!mounted) return;
      _showSnackAndAnnounce(
        'Registration timed out. Please check your connection and try again.',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('COMPANY_REGISTRATION_ERROR');
        debugPrint(e.toString());
        debugPrint(st.toString());
      }
      if (!mounted) return;
      _showSnackAndAnnounce('Registration failed: $e');
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

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields — resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectBillingStreetSuggestion(
    AddressSuggestion selected,
  ) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyBillingStreetSuggestion(resolved);
        _announce('Billing address selected: ${resolved.displayLabel}.');
        await _moveAccessibilityFocus(
          focusNode: _billingAddressTopFocusNode,
          scrollIntoView: false,
        );
        return;
      }
    }
    _applyBillingStreetSuggestion(selected);
    _announce('Billing address selected: ${selected.displayLabel}.');
    await _moveAccessibilityFocus(
      focusNode: _billingAddressTopFocusNode,
      scrollIntoView: false,
    );
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

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields — resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectShippingStreetSuggestion(
    AddressSuggestion selected,
  ) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyShippingStreetSuggestion(resolved);
        _announce('Shipping address selected: ${resolved.displayLabel}.');
        await _moveAccessibilityFocus(
          focusNode: _shippingStreetFocusNode,
          scrollIntoView: false,
        );
        return;
      }
    }
    _applyShippingStreetSuggestion(selected);
    _announce('Shipping address selected: ${selected.displayLabel}.');
    await _moveAccessibilityFocus(
      focusNode: _shippingStreetFocusNode,
      scrollIntoView: false,
    );
  }

  Future<bool> _announceAndFocusError(
    String message, {
    FocusNode? focusNode,
    GlobalKey? semanticKey,
  }) async {
    _announce(message);
    await _moveAccessibilityFocus(
      focusNode: focusNode,
      semanticKey: semanticKey,
    );
    return false;
  }

  void _selectBillingMethod(String method) {
    if (_billingMethod == method) {
      _announce('$method already selected.');
      return;
    }

    setState(() => _billingMethod = method);
    _announce('$method selected.');

    // The selected payment method reveals a different group of fields.
    // Return TalkBack to the method itself after the rebuild so the next
    // forward swipe enters the newly revealed first field instead of jumping
    // past the payment card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final semanticKey = _billingMethodSemanticsKeys[method];
      if (semanticKey == null) return;
      unawaited(
        _moveAccessibilityFocus(
          semanticKey: semanticKey,
          scrollIntoView: false,
        ),
      );
    });
  }

  Future<bool> _focusFirstRegistrationError() async {
    if (_registrationStep == 0) {
      if (_companyNameCtrl.text.trim().isEmpty) {
        return _announceAndFocusError(
          'Company Name is required.',
          focusNode: _companyNameFocusNode,
        );
      }
      final emailError = _accountEmailValidator(_emailCtrl.text);
      if (emailError != null) {
        return _announceAndFocusError(
          emailError,
          focusNode: _companyEmailFocusNode,
        );
      }
      final companyPhoneError = _phoneValidator(_phoneCtrl.text);
      if (companyPhoneError != null) {
        return _announceAndFocusError(
          'Company Phone: $companyPhoneError.',
          focusNode: _companyPhoneFocusNode,
        );
      }
      final passwordError = _passwordValidator(_passCtrl.text);
      if (passwordError != null) {
        return _announceAndFocusError(
          passwordError,
          focusNode: _passwordFocusNode,
        );
      }
      final confirmError = _confirmPasswordValidator(_confirmPassCtrl.text);
      if (confirmError != null) {
        return _announceAndFocusError(
          confirmError,
          focusNode: _confirmPasswordFocusNode,
        );
      }
      final companyUrlError = _optionalUrlValidator(_companyUrlCtrl.text);
      if (companyUrlError != null) {
        return _announceAndFocusError(
          companyUrlError,
          focusNode: _companyUrlFocusNode,
        );
      }
      if (_tiktokCtrl.text.trim().isEmpty &&
          _instagramCtrl.text.trim().isEmpty) {
        return _announceAndFocusError(
          'Provide Instagram or TikTok.',
          focusNode: _tiktokFocusNode,
        );
      }
      if (_contactNameCtrl.text.trim().isEmpty) {
        return _announceAndFocusError(
          'Contact Name is required.',
          focusNode: _contactNameFocusNode,
        );
      }
      final contactEmailError = _emailValidator(_contactEmailCtrl.text);
      if (contactEmailError != null) {
        return _announceAndFocusError(
          'Contact Email: $contactEmailError.',
          focusNode: _contactEmailFocusNode,
        );
      }
      final contactPhoneError = _phoneValidator(_contactPhoneCtrl.text);
      if (contactPhoneError != null) {
        return _announceAndFocusError(
          'Contact Phone: $contactPhoneError.',
          focusNode: _contactPhoneFocusNode,
        );
      }
      return false;
    }

    if (_streetCtrl.text.trim().isEmpty) {
      return _announceAndFocusError(
        'Billing Street Address is required.',
        focusNode: _billingAddressTopFocusNode,
      );
    }
    if (_cityCtrl.text.trim().isEmpty) {
      return _announceAndFocusError(
        'Billing City is required.',
        focusNode: _billingCityFocusNode,
      );
    }
    if (_isBillingUnitedStates && (_selectedState ?? '').trim().isEmpty) {
      return _announceAndFocusError(
        'Billing State is required.',
        semanticKey: _billingStateSemanticsKey,
      );
    }
    if (_isBillingUnitedStates && _zipValidator(_zipCtrl.text) != null) {
      return _announceAndFocusError(
        _zipValidator(_zipCtrl.text)!,
        focusNode: _billingZipFocusNode,
      );
    }
    if (_selectedCountry.trim().isEmpty) {
      return _announceAndFocusError(
        'Billing Country is required.',
        semanticKey: _billingCountrySemanticsKey,
      );
    }

    if (!_shippingSameAsBilling) {
      if (_shipStreetCtrl.text.trim().isEmpty) {
        return _announceAndFocusError(
          'Shipping Street Address is required.',
          focusNode: _shippingStreetFocusNode,
        );
      }
      if (_shipCityCtrl.text.trim().isEmpty) {
        return _announceAndFocusError(
          'Shipping City is required.',
          focusNode: _shippingCityFocusNode,
        );
      }
      if (_isShippingUnitedStates &&
          (_shipSelectedState ?? '').trim().isEmpty) {
        return _announceAndFocusError(
          'Shipping State is required.',
          semanticKey: _shippingStateSemanticsKey,
        );
      }
      if (_isShippingUnitedStates) {
        final shippingZipError = _zipValidator(_shipZipCtrl.text);
        if (shippingZipError != null) {
          return _announceAndFocusError(
            shippingZipError == 'Zip Code is required'
                ? 'Shipping Zip Code is required.'
                : 'Enter a valid Shipping ZIP code.',
            focusNode: _shippingZipFocusNode,
          );
        }
      }
      if (_shipSelectedCountry.trim().isEmpty) {
        return _announceAndFocusError(
          'Shipping Country is required.',
          semanticKey: _shippingCountrySemanticsKey,
        );
      }
    }

    switch (_billingMethod) {
      case 'Credit/Debit Card':
        if (_cardNameCtrl.text.trim().isEmpty) {
          return _announceAndFocusError(
            'Name on Card is required.',
            focusNode: _cardNameFocusNode,
          );
        }
        final cardDigits = _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
        if (cardDigits.length < 13 || cardDigits.length > 19) {
          return _announceAndFocusError(
            'Enter a valid Card Number.',
            focusNode: _cardNumberFocusNode,
          );
        }
        if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim())) {
          return _announceAndFocusError(
            'Enter Expiry as month slash year.',
            focusNode: _cardExpiryFocusNode,
          );
        }
        final cvv = _cardCvvCtrl.text.trim();
        if (cvv.length != 3 && cvv.length != 4) {
          return _announceAndFocusError(
            'CVV must be 3 or 4 digits.',
            focusNode: _cardCvvFocusNode,
          );
        }
        break;
      case 'ACH Transfer':
        if (_achAccountNameCtrl.text.trim().isEmpty) {
          return _announceAndFocusError(
            'Account Holder Name is required.',
            focusNode: _achAccountNameFocusNode,
          );
        }
        if (_achRoutingCtrl.text.trim().isEmpty) {
          return _announceAndFocusError(
            'Routing Number is required.',
            focusNode: _achRoutingFocusNode,
          );
        }
        if (_achAccountCtrl.text.trim().isEmpty) {
          return _announceAndFocusError(
            'Account Number is required.',
            focusNode: _achAccountFocusNode,
          );
        }
        break;
      case 'Apple Pay':
        if (_emailValidator(_applePayEmailCtrl.text) != null) {
          return _announceAndFocusError(
            'Enter a valid Apple Pay Email.',
            focusNode: _applePayEmailFocusNode,
          );
        }
        break;
      case 'Google Pay':
        if (_emailValidator(_googlePayEmailCtrl.text) != null) {
          return _announceAndFocusError(
            'Enter a valid Google Pay Email.',
            focusNode: _googlePayEmailFocusNode,
          );
        }
        break;
    }

    return false;
  }

  Future<bool> _validateCurrentRegistrationStep() async {
    if (_validationTriggeredStep != _registrationStep) {
      setState(() => _validationTriggeredStep = _registrationStep);
    }
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid && mounted) {
      await _focusFirstRegistrationError();
      return false;
    }
    if (_registrationStep == 1 && !_hasRequiredBillingMethod()) {
      await _focusFirstRegistrationError();
      return _showBillingValidationMessage(
        'Please complete the selected payment method before continuing.',
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
    _scrollRegistrationToTop();
    _focusTopOfStep(_registrationStep);
  }

  /// Advancing/going back a step swaps which fields render within the same
  /// single scrollable, so without this the new step opens at whatever
  /// scroll offset the Next/Back button happened to be at (often the
  /// bottom), instead of showing the step from its top.
  void _scrollRegistrationToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_registrationScrollController.hasClients) return;
      _registrationScrollController.jumpTo(0);
    });
  }

  /// The step announcement alone doesn't move screen-reader focus -- without
  /// this, TalkBack/VoiceOver stay wherever focus already was (typically the
  /// Next/Back button, or wherever it last landed), so it can silently skip
  /// past the new step's first field. Moves focus to that field explicitly.
  void _focusTopOfStep(int step) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _moveAccessibilityFocus(
          focusNode: step == 0
              ? _logoUploadFocusNode
              : _billingAddressTopFocusNode,
          semanticKey: step == 0 ? _logoUploadSemanticsKey : null,
        ),
      );
    });
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
                  '${completed
                      ? ', completed'
                      : selected
                      ? ', current step'
                      : ''}',
              onTap: () {
                setState(() {
                  _registrationStep = index;
                  _validationTriggeredStep = null;
                });
                _announceStep(index);
                _scrollRegistrationToTop();
                _focusTopOfStep(index);
              },
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _registrationStep = index;
                      _validationTriggeredStep = null;
                    });
                    _announceStep(index);
                    _scrollRegistrationToTop();
                    _focusTopOfStep(index);
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
                                      ? AppColors.blackCat.withValues(
                                          alpha: 0.55,
                                        )
                                      : AppColors.blackCat.withValues(
                                          alpha: 0.18,
                                        ),
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
                                    : AppColors.blackCat.withValues(
                                        alpha: 0.10,
                                      ),
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
                                      ? AppColors.blackCat.withValues(
                                          alpha: 0.55,
                                        )
                                      : AppColors.blackCat.withValues(
                                          alpha: 0.18,
                                        ),
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
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
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
                  _scrollRegistrationToTop();
                  _focusTopOfStep(_registrationStep);
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      explicitChildNodes: true,
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
              controller: _registrationScrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                Form(
                  key: _formKey,
                  autovalidateMode:
                      _validationTriggeredStep == _registrationStep
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
                                semanticKey: _logoUploadSemanticsKey,
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
                              Semantics(
                                key: _companyNameSemanticsKey,
                                isRequired: true,
                                child: TextFormField(
                                  controller: _companyNameCtrl,
                                  focusNode: _companyNameFocusNode,
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

                              _FieldLabel.required('Company Email'),
                              const SizedBox(height: 6),
                              _req(
                                true,
                                TextFormField(
                                  controller:
                                      _emailCtrl, // âœ… using your existing controller
                                  focusNode: _companyEmailFocusNode,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _dec(
                                    'Company Email',
                                    'Enter Company Email',
                                  ),
                                  validator: _accountEmailValidator,
                                  onChanged: _onEmailChanged,
                                ),
                              ),
                              _buildEmailAvailabilityStatus(),
                              const SizedBox(height: 16),

                              _FieldLabel.required('Company Phone#'),
                              const SizedBox(height: 6),
                              FormField<String>(
                                validator: (value) =>
                                    _phoneValidator(_phoneCtrl.text),
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: _fieldHeight,
                                        decoration: BoxDecoration(
                                          color: AppColors.snow,
                                          borderRadius: BorderRadius.zero,
                                          border: Border.all(
                                            color:
                                                AppColors.blackCatBorderLight,
                                          ),
                                        ),
                                        child: Semantics(
                                          container: true,
                                          explicitChildNodes: true,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 132,
                                                child: Semantics(
                                                  sortKey: OrdinalSortKey(0),
                                                  child: _countryCodeDropdown(
                                                    value: _companyPhoneAreaCode,
                                                    semanticLabel:
                                                        'Company phone country code',
                                                    embedded: true,
                                                    onChanged: (code) => setState(
                                                      () => _companyPhoneAreaCode =
                                                          code.dialCode ?? '+1',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              width: 1,
                                              color:
                                                  AppColors.blackCatBorderLight,
                                            ),
                                            const SizedBox(width: 10),
                                              Expanded(
                                                child: Semantics(
                                                  sortKey: OrdinalSortKey(1),
                                                  label:
                                                      'Company phone number, 10 digits',
                                                  isRequired: true,
                                                  child: TextFormField(
                                                  controller: _phoneCtrl,
                                                  focusNode: _companyPhoneFocusNode,
                                                  style: const TextStyle(
                                                    fontSize: _inputFs,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.phone,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  onFieldSubmitted: (_) {
                                                    FocusScope.of(context)
                                                        .requestFocus(
                                                          _passwordFocusNode,
                                                        );
                                                  },
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
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
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
                              Semantics(
                                isRequired: true,
                                hint: _passwordError != null
                                    ? 'Password error. ${_passwordError!}'
                                    : 'Password rules. Must include uppercase, lowercase, number, and symbol.',
                                child: TextFormField(
                                  controller:
                                      _passCtrl, // âœ… using your existing controller
                                  focusNode: _passwordFocusNode,
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
                                  onChanged: _onPasswordChanged,
                                ),
                              ),
                              ExcludeSemantics(child: _buildPasswordStatus()),
                              const SizedBox(height: 16),

                              _FieldLabel.required('Confirm Password'),
                              const SizedBox(height: 6),
                              _req(
                                true,
                                TextFormField(
                                  controller: _confirmPassCtrl,
                                  focusNode: _confirmPasswordFocusNode,
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
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      ),
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                  validator: _confirmPasswordValidator,
                                  onChanged: _onConfirmPasswordChanged,
                                ),
                              ),
                              _buildConfirmPasswordStatus(),
                              const SizedBox(height: 16),

                              _FieldLabel.normal('Company URL'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _companyUrlCtrl,
                                focusNode: _companyUrlFocusNode,
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
                                focusNode: _tiktokFocusNode,
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
                                focusNode: _instagramFocusNode,
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
                                  focusNode: _contactNameFocusNode,
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
                                  focusNode: _contactEmailFocusNode,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: _fieldHeight,
                                        decoration: BoxDecoration(
                                          color: AppColors.snow,
                                          borderRadius: BorderRadius.zero,
                                          border: Border.all(
                                            color:
                                                AppColors.blackCatBorderLight,
                                          ),
                                        ),
                                        child: Semantics(
                                          container: true,
                                          explicitChildNodes: true,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 132,
                                                child: Semantics(
                                                  sortKey: OrdinalSortKey(0),
                                                  child: _countryCodeDropdown(
                                                    value: _contactPhoneAreaCode,
                                                    semanticLabel:
                                                        'Contact phone country code',
                                                    embedded: true,
                                                    onChanged: (code) => setState(
                                                      () => _contactPhoneAreaCode =
                                                          code.dialCode ?? '+1',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              width: 1,
                                              color:
                                                  AppColors.blackCatBorderLight,
                                            ),
                                            const SizedBox(width: 10),
                                              Expanded(
                                                child: Semantics(
                                                  sortKey: OrdinalSortKey(1),
                                                  label:
                                                      'Contact phone number, 10 digits',
                                                  isRequired: true,
                                                  child: TextFormField(
                                                  controller: _contactPhoneCtrl,
                                                  focusNode: _contactPhoneFocusNode,
                                                  style: const TextStyle(
                                                    fontSize: _inputFs,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.phone,
                                                  textInputAction:
                                                      TextInputAction.done,
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
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
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
                                  focusNode: _billingAddressTopFocusNode,
                                  controller: _streetCtrl,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec(
                                    'Billing Street Address',
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
                                        border: Border.all(
                                          color: Colors.black12,
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
                                        itemBuilder: (_, i) {
                                          final suggestion =
                                              _billingStreetSuggestions[i];
                                          return Semantics(
                                            button: true,
                                            label:
                                                '${suggestion.displayLabel}, address suggestion ${i + 1} of $suggestionCount',
                                            hint: 'Double tap to use this address',
                                            onTap: () => unawaited(
                                              _selectBillingStreetSuggestion(
                                                suggestion,
                                              ),
                                            ),
                                            child: ExcludeSemantics(
                                              child: ListTile(
                                                dense: true,
                                                title: Text(
                                                  suggestion.displayLabel,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onTap: () => unawaited(
                                                  _selectBillingStreetSuggestion(
                                                    suggestion,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                                  focusNode: _billingCityFocusNode,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec(
                                    'City',
                                    'Enter Billing City',
                                  ),
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
                                  id: 'billing-state',
                                  label: 'Billing State',
                                  hint: 'Select billing state',
                                  options: usStates,
                                  selectedValue: _selectedState,
                                  semanticKey: _billingStateSemanticsKey,
                                  required: true,
                                  onChanged: (v) =>
                                      setState(() => _selectedState = v),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'State is required'
                                      : null,
                                )
                              else
                                TextFormField(
                                  controller: _manualStateCtrl,
                                  focusNode: _billingManualStateFocusNode,
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
                                  focusNode: _billingZipFocusNode,
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
                                id: 'billing-country',
                                label: 'Billing Country',
                                hint: 'Select billing country',
                                options: countries,
                                selectedValue: _selectedCountry,
                                semanticKey: _billingCountrySemanticsKey,
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
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
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
                                child: Builder(
                                  builder: (context) {
                                    const title =
                                        'Is Shipping Address same as Billing Address';
                                    void handleChanged(bool next) {
                                      setState(
                                        () => _shippingSameAsBilling = next,
                                      );
                                      SemanticsService.sendAnnouncement(
                                        View.of(context),
                                        '$title toggle ${next ? 'on' : 'off'}',
                                        Directionality.of(context),
                                      );
                                    }

                                    return MergeSemantics(
                                      child: Semantics(
                                        button: true,
                                        label:
                                            '$title toggle ${_shippingSameAsBilling ? 'on' : 'off'}',
                                        child: InkWell(
                                          onTap: () => handleChanged(
                                            !_shippingSameAsBilling,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ExcludeSemantics(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              ExcludeSemantics(
                                                child: Switch(
                                                  value:
                                                      _shippingSameAsBilling,
                                                  activeThumbColor:
                                                      AppColors.deepPlum,
                                                  inactiveThumbColor:
                                                      AppColors.blackCatLight,
                                                  inactiveTrackColor: AppColors
                                                      .blackCatLight
                                                      .withValues(alpha: 0.35),
                                                  onChanged: handleChanged,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              if (!_shippingSameAsBilling) ...[
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Semantics(
                                  header: true,
                                  label: 'Shipping Address',
                                  child: const ExcludeSemantics(
                                    child: Text(
                                      'Shipping Address',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FieldLabel.required('Street Address'),
                                const SizedBox(height: 6),
                                _req(
                                  true,
                                  TextFormField(
                                    controller: _shipStreetCtrl,
                                    focusNode: _shippingStreetFocusNode,
                                    style: const TextStyle(fontSize: _inputFs),
                                    decoration: _dec(
                                      'Shipping Street Address',
                                      'Enter Shipping Street Address',
                                    ),
                                    onChanged: (_) =>
                                        _autofillShippingAddressFromStreet(),
                                    validator: (v) => !_shippingSameAsBilling
                                        ? _requiredValidator(
                                            v,
                                            'Street Address',
                                          )
                                        : null,
                                  ),
                                ),
                                if (_shippingStreetSuggestionsLoading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
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
                                          border: Border.all(
                                            color: Colors.black12,
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
                                          itemBuilder: (_, i) {
                                            final suggestion =
                                                _shippingStreetSuggestions[i];
                                            return Semantics(
                                              button: true,
                                              label:
                                                  '${suggestion.displayLabel}, address suggestion ${i + 1} of $suggestionCount',
                                              hint:
                                                  'Double tap to use this address',
                                              onTap: () => unawaited(
                                                _selectShippingStreetSuggestion(
                                                  suggestion,
                                                ),
                                              ),
                                              child: ExcludeSemantics(
                                                child: ListTile(
                                                  dense: true,
                                                  title: Text(
                                                    suggestion.displayLabel,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onTap: () => unawaited(
                                                    _selectShippingStreetSuggestion(
                                                      suggestion,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
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
                                    focusNode: _shippingCityFocusNode,
                                    style: const TextStyle(fontSize: _inputFs),
                                    decoration: _dec(
                                      'City',
                                      'Enter Shipping City',
                                    ),
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
                                    id: 'shipping-state',
                                    label: 'Shipping State',
                                    hint: 'Select shipping state',
                                    options: usStates,
                                    selectedValue: _shipSelectedState,
                                    semanticKey: _shippingStateSemanticsKey,
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
                                    focusNode: _shippingManualStateFocusNode,
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
                                    focusNode: _shippingZipFocusNode,
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
                                  id: 'shipping-country',
                                  label: 'Shipping Country',
                                  hint: 'Select shipping country',
                                  options: countries,
                                  selectedValue: _shipSelectedCountry,
                                  semanticKey: _shippingCountrySemanticsKey,
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
                                        Semantics(
                                          key: _billingMethodSemanticsKeys[method],
                                          button: true,
                                          selected: selected,
                                          label: method,
                                          hint: selected
                                              ? 'Selected payment method'
                                              : 'Double tap to select payment method',
                                          onTap: () => _selectBillingMethod(method),
                                          child: ExcludeSemantics(
                                            child: InkWell(
                                              onTap: () =>
                                                  _selectBillingMethod(method),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _billingMethod == method
                                                        ? Icons
                                                              .radio_button_checked
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    color: AppColors.deepPlum,
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      method,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (selected) ...[
                                          const SizedBox(height: 6),
                                          if (method ==
                                              'Credit/Debit Card') ...[
                                            TextFormField(
                                              controller: _cardNameCtrl,
                                              focusNode: _cardNameFocusNode,
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
                                              focusNode: _cardNumberFocusNode,
                                              style: const TextStyle(
                                                fontSize: _inputFs,
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
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
                                                    focusNode: _cardExpiryFocusNode,
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
                                                    focusNode: _cardCvvFocusNode,
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
                                              focusNode: _achAccountNameFocusNode,
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
                                              focusNode: _achRoutingFocusNode,
                                              style: const TextStyle(
                                                fontSize: _inputFs,
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
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
                                              focusNode: _achAccountFocusNode,
                                              style: const TextStyle(
                                                fontSize: _inputFs,
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
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
                                              focusNode: _applePayEmailFocusNode,
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
                                              focusNode: _googlePayEmailFocusNode,
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
                              Semantics(
                                button: true,
                                label:
                                    'Save for future use toggle, ${_saveBillingForFutureUse ? 'on' : 'off'}',
                                hint: 'Double tap to toggle',
                                onTap: () {
                                  setState(
                                    () => _saveBillingForFutureUse =
                                        !_saveBillingForFutureUse,
                                  );
                                  _announce(
                                    'Save for future use ${_saveBillingForFutureUse ? 'on' : 'off'}.',
                                  );
                                },
                                child: ExcludeSemantics(
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: _saveBillingForFutureUse,
                                    onChanged: (v) {
                                      final next = v ?? false;
                                      setState(
                                        () => _saveBillingForFutureUse = next,
                                      );
                                      _announce(
                                        'Save for future use ${next ? 'on' : 'off'}.',
                                      );
                                    },
                                    activeColor: AppColors.deepPlum,
                                    title: const Text(
                                      'Save for future use',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      CommunicationPreferenceSection(
                        emailNotifications: _emailNotifications,
                        smsNotifications: _smsNotifications,
                        onEmailChanged: (value) =>
                            setState(() => _emailNotifications = value),
                        onSmsChanged: (value) =>
                            setState(() => _smsNotifications = value),
                      ),
                      const SizedBox(height: 18),
                      _wizardNavButtons(),
                    ],
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


/// Searchable modal selector used by Billing/Shipping State and Country.
///
/// Important lifecycle detail:
/// This widget owns the Search TextEditingController and Close FocusNode.
/// They are disposed only when Flutter actually disposes the bottom-sheet
/// subtree, not when Navigator.pop returns a result to the parent page.
class _RegistrationAccessibleChoiceSheet extends StatefulWidget {
  const _RegistrationAccessibleChoiceSheet({
    required this.title,
    required this.options,
    required this.currentValue,
  });

  final String title;
  final List<String> options;
  final String currentValue;

  @override
  State<_RegistrationAccessibleChoiceSheet> createState() =>
      _RegistrationAccessibleChoiceSheetState();
}

class _RegistrationAccessibleChoiceSheetState
    extends State<_RegistrationAccessibleChoiceSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _closeFocusNode;
  String _query = '';
  bool _returningSelection = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _closeFocusNode = FocusNode(
      debugLabel: '${widget.title}PickerClose',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _returningSelection) return;

      FocusScope.of(context).requestFocus(_closeFocusNode);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      _closeFocusNode.context
          ?.findRenderObject()
          ?.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _closeFocusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredOptions {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<void> _closeWithoutSelection() async {
    if (_returningSelection) return;
    _returningSelection = true;

    // Close any active Search keyboard before beginning the sheet pop.
    FocusScope.of(context).unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _selectOption(String option) async {
    if (_returningSelection) return;
    _returningSelection = true;

    // The crash reported on Android occurred specifically when an option was
    // selected after typing in Search. Detach the Search TextField from the
    // IME first, let one frame settle, then return the result. The controller
    // remains alive until this sheet's real dispose() runs after route teardown.
    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: '${widget.title} selector',
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.snow,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            sortKey: OrdinalSortKey(1),
                            label: widget.title,
                            child: ExcludeSemantics(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          sortKey: OrdinalSortKey(0),
                          button: true,
                          label: 'Close ${widget.title} selector',
                          hint: 'Double tap to close',
                          onTap: () => unawaited(_closeWithoutSelection()),
                          child: ExcludeSemantics(
                            child: IconButton(
                              focusNode: _closeFocusNode,
                              tooltip: 'Close ${widget.title} selector',
                              onPressed: _returningSelection
                                  ? null
                                  : () => unawaited(_closeWithoutSelection()),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Semantics(
                      sortKey: OrdinalSortKey(2),
                      label: 'Search ${widget.title}',
                      textField: true,
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Type to filter ${widget.title}',
                          filled: true,
                          fillColor: AppColors.snow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: AppColors.blackCatBorderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: AppColors.blackCatBorderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: AppColors.blackCat,
                              width: 1.4,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (!mounted || _returningSelection) return;
                          setState(() => _query = value);
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      sortKey: OrdinalSortKey(3),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No results'),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding:
                                  const EdgeInsets.fromLTRB(8, 0, 8, 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final selected =
                                    option.trim().toLowerCase() ==
                                    widget.currentValue
                                        .trim()
                                        .toLowerCase();

                                return Semantics(
                                  button: true,
                                  selected: selected,
                                  label:
                                      '$option, option ${index + 1} of ${filtered.length}',
                                  hint: 'Double tap to select',
                                  onTap: _returningSelection
                                      ? null
                                      : () => unawaited(
                                            _selectOption(option),
                                          ),
                                  child: ExcludeSemantics(
                                    child: ListTile(
                                      dense: true,
                                      title: Text(option),
                                      trailing: selected
                                          ? const Icon(Icons.check_rounded)
                                          : null,
                                      onTap: _returningSelection
                                          ? null
                                          : () => unawaited(
                                                _selectOption(option),
                                              ),
                                    ),
                                  ),
                                );
                              },
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
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
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
            Semantics(
              header: true,
              label: title,
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
      ),
    );
  }
}

class _ProfileUpload extends StatelessWidget {
  const _ProfileUpload({
    required this.onTap,
    required this.label,
    required this.semanticKey,
    this.image,
    this.focusNode,
  });
  final VoidCallback onTap;
  final String label;
  final GlobalKey semanticKey;
  final ImageProvider? image;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticKey,
      button: true,
      label: image == null ? 'Upload $label' : 'Change $label',
      hint: 'Double tap to choose an image',
      onTap: onTap,
      child: ExcludeSemantics(
        child: RegistrationProfileUpload(
          onTap: onTap,
          imageProvider: image,
          label: label,
          helperText: image == null
              ? 'Tap to upload company logo'
              : 'Tap to change company logo',
          focusNode: focusNode,
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
