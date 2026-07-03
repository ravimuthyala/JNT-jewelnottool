import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/currency_options.dart';
import '../../theme/app_colors.dart';
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

  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _confirmCtrl;
  late final TextEditingController _studioNameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _phoneCtrl;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _emailTouched = false;
  String? _currency;
  String _phoneAreaCode = '+1';
  Uint8List? _profileBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _emailCtrl = TextEditingController(text: draft.email);
    _passCtrl = TextEditingController(text: draft.password);
    _confirmCtrl = TextEditingController();
    _studioNameCtrl = TextEditingController(text: draft.studioName);
    _displayNameCtrl = TextEditingController(text: draft.displayName);
    _languageCtrl = TextEditingController(text: draft.languageSpoken);
    _bioCtrl = TextEditingController(text: draft.bio);
    _phoneCtrl = TextEditingController(text: draft.phone);
    _phoneAreaCode = draft.phoneAreaCode.isEmpty ? '+1' : draft.phoneAreaCode;
    _profileBytes = draft.profileBytes;
    _currency = draft.currency.isEmpty ? 'US Dollar (USD)' : draft.currency;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _studioNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _languageCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
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

  bool get _isEmailValid =>
      _emailCtrl.text.contains('@') && _emailCtrl.text.contains('.');

  void autofill() {
    setState(() {
      _emailCtrl.text = 'luna.nails@test.com';
      _passCtrl.text = 'Test1234!';
      _confirmCtrl.text = 'Test1234!';
      _studioNameCtrl.text = 'Luna Nails Studio';
      _displayNameCtrl.text = 'Luna Nails';
      _languageCtrl.text = 'English';
      _currency = 'US Dollar (USD)';
      _bioCtrl.text =
          'Professional nail artist with 5+ years of experience. Specializing in intricate nail art, gel designs, and 3D nail sculptures. Based in LA.';
      _phoneCtrl.text = '5551234567';
      _phoneAreaCode = '+1';
      _emailTouched = true;
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    setState(() => _emailTouched = true);
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    draft.email = _emailCtrl.text.trim();
    draft.password = _passCtrl.text;
    draft.studioName = _studioNameCtrl.text.trim();
    draft.displayName = _displayNameCtrl.text.trim();
    draft.languageSpoken = _languageCtrl.text.trim();
    draft.currency = _currency ?? 'US Dollar (USD)';
    draft.bio = _bioCtrl.text.trim();
    draft.phone = _phoneCtrl.text.trim();
    draft.phoneAreaCode = _phoneAreaCode;
    draft.profileBytes = _profileBytes;
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          regSectionCard(
            title: 'Account Credentials',
            subtitle: "You'll use these to log in to JewelNotTool.",
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_emailTouched) setState(() {});
                  },
                  onEditingComplete: () {
                    setState(() => _emailTouched = true);
                    FocusScope.of(context).nextFocus();
                  },
                  validator: (_) {
                    if (!_emailTouched) return null;
                    if (_emailCtrl.text.trim().isEmpty)
                      return 'Email is required';
                    if (!_isEmailValid) return 'Enter a valid email address';
                    return null;
                  },
                  decoration: regDec('Email', 'you@example.com'),
                  style: fieldStyle,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8)
                      return 'Must be at least 8 characters';
                    return null;
                  },
                  decoration: regDec(
                    'Password',
                    'At least 8 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.blackCatLight,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  style: fieldStyle,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passCtrl.text)
                      return 'Passwords do not match';
                    return null;
                  },
                  decoration: regDec(
                    'Confirm password',
                    '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.blackCatLight,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  style: fieldStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Artist Profile',
            subtitle: 'This is how clients will see you.',
            child: Column(
              children: [
                Center(
                  child: RegistrationProfileUpload(
                    onTap: _pickProfilePic,
                    imageBytes: _profileBytes,
                  ),
                ),
                const SizedBox(height: 6),
                Localizations.override(
                  context: context,
                  locale: const Locale('en'),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      border: Border.all(color: AppColors.blackCatBorderLight),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: CountryCodePicker(
                            onChanged: (code) => setState(
                              () => _phoneAreaCode = code.dialCode ?? '+1',
                            ),
                            initialSelection: _phoneAreaCode,
                            favorite: const ['+1', '+44', '+91'],
                            showFlag: false,
                            showFlagMain: false,
                            hideMainText: false,
                            alignLeft: true,
                            padding: EdgeInsets.zero,
                            textStyle: fieldStyle,
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
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (value) =>
                                (value == null || value.trim().length < 7)
                                ? 'Enter a valid phone number'
                                : null,
                            decoration: const InputDecoration(
                              hintText: 'Phone number',
                              border: InputBorder.none,
                            ),
                            style: fieldStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
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
                const SizedBox(height: 6),
                TextFormField(
                  controller: _displayNameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Display Name is required'
                      : null,
                  decoration: regDec('Display Name', 'Display Name'),
                  style: fieldStyle,
                ),
                const SizedBox(height: 6),
                TextFormField(
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
                const SizedBox(height: 6),
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
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioCtrl,
                  textInputAction: TextInputAction.done,
                  maxLines: 4,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Bio is required'
                      : null,
                  decoration: regDec('Bio / About', 'Tell clients about you'),
                  style: fieldStyle,
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
