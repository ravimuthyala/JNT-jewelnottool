import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _closeButtonFocusNode = FocusNode(
    debugLabel: 'popupCloseButton',
  );
  final GlobalKey _closeButtonKey = GlobalKey(
    debugLabel: 'popupCloseButtonA11yKey',
  );

  final FocusNode _companyNameFocusNode = FocusNode(
    debugLabel: 'businessInfoCompanyName',
  );
  final FocusNode _companyEmailFocusNode = FocusNode(
    debugLabel: 'businessInfoCompanyEmail',
  );
  final FocusNode _contactNameFocusNode = FocusNode(
    debugLabel: 'businessInfoContactName',
  );
  final FocusNode _contactEmailFocusNode = FocusNode(
    debugLabel: 'businessInfoContactEmail',
  );

  final GlobalKey _companyNameSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoCompanyNameA11y',
  );
  final GlobalKey _businessTypeSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoBusinessTypeA11y',
  );
  final GlobalKey _companyEmailSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoCompanyEmailA11y',
  );
  final GlobalKey _companyPhoneSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoCompanyPhoneA11y',
  );
  final GlobalKey _contactNameSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoContactNameA11y',
  );
  final GlobalKey _contactEmailSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoContactEmailA11y',
  );
  final GlobalKey _contactPhoneSemanticsKey = GlobalKey(
    debugLabel: 'businessInfoContactPhoneA11y',
  );

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for the bottom-sheet entrance animation and semantics tree to
      // settle before moving TalkBack accessibility focus.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _moveAccessibilityFocusToClose(scrollToTop: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _closeButtonFocusNode.dispose();
    _companyNameFocusNode.dispose();
    _companyEmailFocusNode.dispose();
    _contactNameFocusNode.dispose();
    _contactEmailFocusNode.dispose();
    _companyNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _moveAccessibilityFocusToClose({
    bool scrollToTop = false,
  }) async {
    if (!mounted) return;

    if (scrollToTop && _scrollController.hasClients) {
      final top = _scrollController.position.minScrollExtent;
      await _scrollController.animateTo(
        top,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      // Finish exactly at the top even if the animation was interrupted by
      // TalkBack/keyboard scrolling.
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.minScrollExtent,
        );
      }
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final closeContext = _closeButtonKey.currentContext;
    if (closeContext == null) return;

    await Scrollable.ensureVisible(
      closeContext,
      alignment: 0,
      duration: Duration.zero,
    );
    if (!mounted) return;

    FocusScope.of(context).requestFocus(_closeButtonFocusNode);
    closeContext.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );

    // Android TalkBack can drop a focus event while a sheet/scroll is still
    // settling. A short retry keeps the cursor on the real visible X.
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _closeButtonKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  void _closePopup() {
    Navigator.pop(context);
  }

  bool _isEmail(String s) {
    final v = s.trim();
    // simple check (good enough for UI)
    return v.contains('@') && v.contains('.');
  }

  Future<void> _announceValidationError(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _focusValidationTarget({
    required GlobalKey semanticsKey,
    FocusNode? focusNode,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final targetContext = semanticsKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.35,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    if (!mounted) return;

    if (focusNode != null) {
      FocusScope.of(context).requestFocus(focusNode);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    targetContext.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );

    // A short retry helps TalkBack retain the field after the scroll/keyboard
    // and semantics tree settle.
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;

    semanticsKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  Future<bool> _validationFailure({
    required String message,
    required GlobalKey semanticsKey,
    FocusNode? focusNode,
  }) async {
    await _announceValidationError(message);
    await _focusValidationTarget(
      semanticsKey: semanticsKey,
      focusNode: focusNode,
    );
    return false;
  }

  Future<bool> _validate() async {
    final companyName = _companyNameCtrl.text.trim();
    final contactName = _contactNameCtrl.text.trim();
    final contactEmail = _contactEmailCtrl.text.trim();
    final contactPhone = _contactPhoneCtrl.text.trim();
    final companyEmail = _companyEmailCtrl.text.trim();
    final companyPhone = _companyPhoneCtrl.text.trim();

    // Follow the same order the user encounters the fields in the modal.
    if (companyName.isEmpty) {
      return _validationFailure(
        message: 'Company Name is required.',
        semanticsKey: _companyNameSemanticsKey,
        focusNode: _companyNameFocusNode,
      );
    }

    if (_businessType == null || _businessType!.trim().isEmpty) {
      return _validationFailure(
        message: 'Business Type is required.',
        semanticsKey: _businessTypeSemanticsKey,
      );
    }

    if (companyEmail.isEmpty) {
      return _validationFailure(
        message: 'Company Email ID is required.',
        semanticsKey: _companyEmailSemanticsKey,
        focusNode: _companyEmailFocusNode,
      );
    }

    if (!_isEmail(companyEmail)) {
      return _validationFailure(
        message: 'Company Email ID must be a valid email address.',
        semanticsKey: _companyEmailSemanticsKey,
        focusNode: _companyEmailFocusNode,
      );
    }

    if (companyPhone.isEmpty) {
      return _validationFailure(
        message: 'Company Phone number is required.',
        semanticsKey: _companyPhoneSemanticsKey,
      );
    }

    if (contactName.isEmpty) {
      return _validationFailure(
        message: 'Contact Name is required.',
        semanticsKey: _contactNameSemanticsKey,
        focusNode: _contactNameFocusNode,
      );
    }

    if (contactEmail.isEmpty) {
      return _validationFailure(
        message: 'Contact Email is required.',
        semanticsKey: _contactEmailSemanticsKey,
        focusNode: _contactEmailFocusNode,
      );
    }

    if (!_isEmail(contactEmail)) {
      return _validationFailure(
        message: 'Contact Email must be a valid email address.',
        semanticsKey: _contactEmailSemanticsKey,
        focusNode: _contactEmailFocusNode,
      );
    }

    if (contactPhone.isEmpty) {
      return _validationFailure(
        message: 'Contact Phone number is required.',
        semanticsKey: _contactPhoneSemanticsKey,
      );
    }

    return true;
  }

  String _combinedPhone(String areaCode, String localPhone) {
    final normalizedLocal = RegistrationInputUtils.normalizePhone(localPhone);
    if (normalizedLocal.isEmpty) return '';
    return '${RegistrationInputUtils.normalizeAreaCode(areaCode)}$normalizedLocal';
  }

  Future<void> _save() async {
    if (!await _validate()) return;

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
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Business Info',
      child: GestureDetector(
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
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The real visible X is first in semantic traversal.
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              sortKey: OrdinalSortKey(1),
                              label: 'Business Info',
                              child: const ExcludeSemantics(
                                child: Text(
                                  'Business Info',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            key: _closeButtonKey,
                            sortKey: OrdinalSortKey(0),
                            button: true,
                            label: 'Close Business Info',
                            hint: 'Double tap to close',
                            onTap: _closePopup,
                            child: ExcludeSemantics(
                              child: IconButton(
                                focusNode: _closeButtonFocusNode,
                                tooltip: 'Close Business Info',
                                onPressed: _closePopup,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Content follows the real X and title. The container
                      // itself has no label/action, so TalkBack does not stop
                      // on the entire Business Info section.
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        sortKey: OrdinalSortKey(2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update your company + primary contact details.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 8),

                            const _SectionLabel(
                              'BUSINESS',
                              semanticLabel: 'Business',
                            ),
                            const SizedBox(height: 8),

                            _SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _labeledField(
                                    'Company Name *',
                                    _InputField(
                                      controller: _companyNameCtrl,
                                      focusNode: _companyNameFocusNode,
                                      hint: 'Enter company name',
                                    ),
                                    semanticsKey: _companyNameSemanticsKey,
                                  ),

                                  const SizedBox(height: 8),
                                  _labeledField(
                                    'Business Type *',
                                    _DropdownField(
                                      value: _businessType,
                                      hint: 'Select business type',
                                      items: kCompanyBusinessTypes,
                                      onChanged: (v) =>
                                          setState(() => _businessType = v),
                                    ),
                                    semanticsKey: _businessTypeSemanticsKey,
                                  ),

                                  const SizedBox(height: 8),
                                  _labeledField(
                                    'Company Email ID *',
                                    _InputField(
                                      controller: _companyEmailCtrl,
                                      focusNode: _companyEmailFocusNode,
                                      hint: 'company@email.com',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    semanticsKey: _companyEmailSemanticsKey,
                                  ),

                                  const SizedBox(height: 8),
                                  // PhoneCountryCodeField owns two interactive
                                  // controls (country code + local number), so
                                  // do not merge the whole row into one node.
                                  ExcludeSemantics(
                                    child: _fieldLabel('Company Phone # *'),
                                  ),
                                  const SizedBox(height: 8),
                                  Semantics(
                                    key: _companyPhoneSemanticsKey,
                                    container: true,
                                    explicitChildNodes: true,
                                    child: PhoneCountryCodeField(
                                      areaCode: _companyPhoneAreaCode,
                                    onAreaCodeChanged: (code) => setState(
                                      () => _companyPhoneAreaCode = code,
                                    ),
                                    controller: _companyPhoneCtrl,
                                    height: 52,
                                    fontSize: 11.5,
                                    semanticLabel:
                                        'Company phone number, required',
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  _labeledField(
                                    'Company URL',
                                    _InputField(
                                      controller: _companyUrlCtrl,
                                      hint: 'https://yourcompany.com',
                                      keyboardType: TextInputType.url,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            const _SectionLabel(
                              'PRIMARY CONTACT',
                              semanticLabel: 'Primary Contact',
                            ),
                            const SizedBox(height: 8),

                            _SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _labeledField(
                                    'Contact Name *',
                                    _InputField(
                                      controller: _contactNameCtrl,
                                      focusNode: _contactNameFocusNode,
                                      hint: 'Enter contact name',
                                    ),
                                    semanticsKey: _contactNameSemanticsKey,
                                  ),

                                  const SizedBox(height: 8),
                                  _labeledField(
                                    'Contact Email *',
                                    _InputField(
                                      controller: _contactEmailCtrl,
                                      focusNode: _contactEmailFocusNode,
                                      hint: 'contact@email.com',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    semanticsKey: _contactEmailSemanticsKey,
                                  ),

                                  const SizedBox(height: 8),
                                  ExcludeSemantics(
                                    child: _fieldLabel('Contact Phone # *'),
                                  ),
                                  const SizedBox(height: 8),
                                  Semantics(
                                    key: _contactPhoneSemanticsKey,
                                    container: true,
                                    explicitChildNodes: true,
                                    child: PhoneCountryCodeField(
                                      areaCode: _contactPhoneAreaCode,
                                    onAreaCodeChanged: (code) => setState(
                                      () => _contactPhoneAreaCode = code,
                                    ),
                                    controller: _contactPhoneCtrl,
                                    height: 52,
                                    fontSize: 11.5,
                                    semanticLabel:
                                        'Contact phone number, required',
                                    ),
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

                      // End-of-modal accessibility loop. This is the semantic
                      // stop immediately after Save. As soon as TalkBack
                      // reaches it, the sheet scrolls to the top and focus is
                      // transferred to the real visible Close X.
                      Semantics(
                        sortKey: OrdinalSortKey(3),
                        button: true,
                        label: 'Close Business Info',
                        onTap: _closePopup,
                        onDidGainAccessibilityFocus: () {
                          _moveAccessibilityFocusToClose(scrollToTop: true);
                        },
                        child: const SizedBox(
                          height: 1,
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ),
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

  // One accessibility stop per field: visible label + TextField/Dropdown
  // semantics are merged, so TalkBack announces the field name, required
  // state, current value, and the control's native actions together.
  Widget _labeledField(
    String labelText,
    Widget field, {
    GlobalKey? semanticsKey,
  }) {
    final isRequired = labelText.trim().endsWith('*');
    final cleanLabel = labelText.replaceAll('*', '').trim();
    return MergeSemantics(
      child: Semantics(
        key: semanticsKey,
        label: cleanLabel,
        isRequired: isRequired,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: _fieldLabel(labelText)),
            const SizedBox(height: 8),
            field,
          ],
        ),
      ),
    );
  }
}

/// ---------- UI bits (same family as your app) ----------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
    this.text, {
    required this.semanticLabel,
  });

  final String text;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Text(
          text,
          style: TextStyle(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ),
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

    // Do not ExcludeSemantics here. The native DropdownButtonFormField
    // provides the correct tap/menu actions; _labeledField merges the
    // visible field name into this native control.
    return DropdownButtonFormField<String>(
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
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
          borderSide: const BorderSide(
            color: AppColors.blackCatLight,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
