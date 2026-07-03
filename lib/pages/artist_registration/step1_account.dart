import 'package:flutter/material.dart';

import '../../constants/currency_options.dart';
import '../../theme/app_colors.dart';
import '../../widgets/registration_profile_upload.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class Step1Account extends StatefulWidget {
  const Step1Account({
    super.key,
    required this.draft,
  });

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

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _emailTouched = false;
  String? _currency;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _emailCtrl = TextEditingController(text: d.email);
    _passCtrl = TextEditingController(text: d.password);
    _confirmCtrl = TextEditingController();
    _studioNameCtrl = TextEditingController(text: d.studioName);
    _displayNameCtrl = TextEditingController(text: d.displayName);
    _languageCtrl = TextEditingController(text: d.languageSpoken);
    _bioCtrl = TextEditingController(text: d.bio);
    _currency = d.currency.isEmpty ? 'US Dollar (USD)' : d.currency;
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
    super.dispose();
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
                    if (_emailCtrl.text.trim().isEmpty) return 'Email is required';
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Must be at least 8 characters';
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
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                  decoration: regDec(
                    'Confirm password',
                    '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.blackCatLight,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
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
                    onTap: () async {},
                    imageBytes: widget.draft.profileBytes,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _studioNameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Display Name is required'
                      : null,
                  decoration: regDec('Display Name', 'Display Name'),
                  style: fieldStyle,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _languageCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
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
                  onChanged: (v) => setState(() => _currency = v),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Currency is required'
                      : null,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioCtrl,
                  textInputAction: TextInputAction.done,
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bio is required' : null,
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
