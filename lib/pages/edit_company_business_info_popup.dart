import 'package:flutter/material.dart';
import '../models/company_business_options.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';
import '../widgets/phone_country_code_field.dart';

/// Lightweight draft model (keep here until you create a real model file).
class CompanyBusinessInfoDraft {
  final String companyName;

  final String contactName;
  final String contactEmail;
  final String contactPhone;

  final String companyEmail;
  final String companyPhone;
  final String companyUrl;

  final String businessType;

  const CompanyBusinessInfoDraft({
    required this.companyName,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.companyEmail,
    required this.companyPhone,
    required this.companyUrl,
    required this.businessType,
  });

  CompanyBusinessInfoDraft copyWith({
    String? companyName,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? companyEmail,
    String? companyPhone,
    String? companyUrl,
    String? businessType,
  }) {
    return CompanyBusinessInfoDraft(
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPhone: companyPhone ?? this.companyPhone,
      companyUrl: companyUrl ?? this.companyUrl,
      businessType: businessType ?? this.businessType,
    );
  }

  static CompanyBusinessInfoDraft empty() {
    return const CompanyBusinessInfoDraft(
      companyName: '',
      contactName: '',
      contactEmail: '',
      contactPhone: '',
      companyEmail: '',
      companyPhone: '',
      companyUrl: '',
      businessType: '',
    );
  }
}

class EditCompanyBusinessInfoPopup extends StatefulWidget {
  const EditCompanyBusinessInfoPopup({super.key, required this.initial});

  final CompanyBusinessInfoDraft initial;

  @override
  State<EditCompanyBusinessInfoPopup> createState() =>
      _EditCompanyBusinessInfoPopupState();
}

class _EditCompanyBusinessInfoPopupState
    extends State<EditCompanyBusinessInfoPopup> {
  // Controllers
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _contactPhoneCtrl;

  late final TextEditingController _companyEmailCtrl;
  late final TextEditingController _companyPhoneCtrl;
  late final TextEditingController _companyUrlCtrl;
  late String _contactPhoneAreaCode;
  late String _companyPhoneAreaCode;

  String? _businessType;

  @override
  void initState() {
    super.initState();

    _companyNameCtrl = TextEditingController(text: widget.initial.companyName);

    _contactNameCtrl = TextEditingController(text: widget.initial.contactName);
    _contactEmailCtrl = TextEditingController(
      text: widget.initial.contactEmail,
    );
    final splitContactPhone = RegistrationInputUtils.splitStoredPhone(
      widget.initial.contactPhone,
    );
    _contactPhoneAreaCode = splitContactPhone.areaCode;
    _contactPhoneCtrl = TextEditingController(
      text: splitContactPhone.localNumber,
    );

    _companyEmailCtrl = TextEditingController(
      text: widget.initial.companyEmail,
    );
    final splitCompanyPhone = RegistrationInputUtils.splitStoredPhone(
      widget.initial.companyPhone,
    );
    _companyPhoneAreaCode = splitCompanyPhone.areaCode;
    _companyPhoneCtrl = TextEditingController(
      text: splitCompanyPhone.localNumber,
    );
    _companyUrlCtrl = TextEditingController(text: widget.initial.companyUrl);

    _businessType = widget.initial.businessType.isNotEmpty
        ? widget.initial.businessType
        : kCompanyBusinessTypes.first;
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyUrlCtrl.dispose();
    super.dispose();
  }

  bool _isEmail(String s) {
    final v = s.trim();
    // simple check (good enough for UI)
    return v.contains('@') && v.contains('.');
  }

  bool _validate() {
    final companyName = _companyNameCtrl.text.trim();
    final contactName = _contactNameCtrl.text.trim();
    final contactEmail = _contactEmailCtrl.text.trim();
    final contactPhone = _contactPhoneCtrl.text.trim();
    final companyEmail = _companyEmailCtrl.text.trim();
    final companyPhone = _companyPhoneCtrl.text.trim();

    if (companyName.isEmpty ||
        contactName.isEmpty ||
        contactEmail.isEmpty ||
        contactPhone.isEmpty ||
        companyEmail.isEmpty ||
        companyPhone.isEmpty ||
        (_businessType == null || _businessType!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return false;
    }

    if (!_isEmail(contactEmail) || !_isEmail(companyEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid email addresses.')),
      );
      return false;
    }

    return true;
  }

  String _combinedPhone(String areaCode, String localPhone) {
    final normalizedLocal = RegistrationInputUtils.normalizePhone(localPhone);
    if (normalizedLocal.isEmpty) return '';
    return '${RegistrationInputUtils.normalizeAreaCode(areaCode)}$normalizedLocal';
  }

  Future<void> _save() async {
    if (!_validate()) return;

    final updated = widget.initial.copyWith(
      companyName: _companyNameCtrl.text.trim(),
      contactName: _contactNameCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim(),
      contactPhone: _combinedPhone(
        _contactPhoneAreaCode,
        _contactPhoneCtrl.text,
      ),
      companyEmail: _companyEmailCtrl.text.trim(),
      companyPhone: _combinedPhone(
        _companyPhoneAreaCode,
        _companyPhoneCtrl.text,
      ),
      companyUrl: _companyUrlCtrl.text.trim(),
      businessType: _businessType?.trim() ?? '',
    );

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Business Info',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      'Update your company + primary contact details.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),

                    const _SectionLabel('BUSINESS'),
                    const SizedBox(height: 8),

                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Company Name *'),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _companyNameCtrl,
                            hint: 'Enter company name',
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Business Type *'),
                          const SizedBox(height: 8),
                          _DropdownField(
                            value: _businessType,
                            hint: 'Select business type',
                            items: kCompanyBusinessTypes,
                            onChanged: (v) => setState(() => _businessType = v),
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Company Email ID *'),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _companyEmailCtrl,
                            hint: 'company@email.com',
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Company Phone # *'),
                          const SizedBox(height: 8),
                          PhoneCountryCodeField(
                            areaCode: _companyPhoneAreaCode,
                            onAreaCodeChanged: (code) =>
                                setState(() => _companyPhoneAreaCode = code),
                            controller: _companyPhoneCtrl,
                            height: 52,
                            fontSize: 11.5,
                            semanticLabel: 'Company phone number',
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Company URL'),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _companyUrlCtrl,
                            hint: 'https://yourcompany.com',
                            keyboardType: TextInputType.url,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const _SectionLabel('PRIMARY CONTACT'),
                    const SizedBox(height: 8),

                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Contact Name *'),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _contactNameCtrl,
                            hint: 'Enter contact name',
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Contact Email *'),
                          const SizedBox(height: 8),
                          _InputField(
                            controller: _contactEmailCtrl,
                            hint: 'contact@email.com',
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 8),
                          _fieldLabel('Contact Phone # *'),
                          const SizedBox(height: 8),
                          PhoneCountryCodeField(
                            areaCode: _contactPhoneAreaCode,
                            onAreaCodeChanged: (code) =>
                                setState(() => _contactPhoneAreaCode = code),
                            controller: _contactPhoneCtrl,
                            height: 52,
                            fontSize: 11.5,
                            semanticLabel: 'Contact phone number',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 52,
                          width: 180,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _save,
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return Text(
      t,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.blackCat,
        fontSize: 12,
      ),
    );
  }
}

/// ---------- UI bits (same family as your app) ----------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        color: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return Semantics(
      label: hint,
      value: safeValue ?? 'Not selected',
      hint: 'Dropdown. Double tap to open.',
      child: ExcludeSemantics(
        child: DropdownButtonFormField<String>(
      initialValue: safeValue,
      menuMaxHeight: 280,
      isExpanded: true,
      dropdownColor: AppColors.snow,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 16,
        color: Colors.black.withValues(alpha: 0.45),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 10,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.snow,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(
            color: AppColors.blackCatLight,
            width: 1.2,
          ),
        ),
      ),
      items: items
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(
                s,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 10,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.snow,
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
          borderSide: const BorderSide(
            color: AppColors.blackCatLight,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
