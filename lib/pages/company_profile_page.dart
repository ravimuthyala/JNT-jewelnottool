import 'dart:typed_data';
import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'edit_company_business_info_popup.dart';
import '../widgets/company_shell_chrome.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'edit_shipping_address_page.dart' show usStates, countries;

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({
    super.key,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.locationText,
    required this.onLogout,
    this.profileImageUrl = '',
    this.onOpenBilling,
    this.onOpenNewDesignRequest,
    this.onOpenNotifications,
    this.onOpenShippingAddresses,
    this.onClose,
    this.initialBusinessInfo,
    this.initialBillingInfo,
    this.initialAddressesInfo,
    this.autoFocusNotifications = false,
    this.notificationFocusRequestKey = 0,
  });

  final String companyName;
  final String contactName;
  final String email;
  final String locationText;
  final String profileImageUrl;

  final Future<void> Function() onLogout;

  // Optional taps (wire later)
  final VoidCallback? onOpenBilling;
  final VoidCallback? onOpenNewDesignRequest;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenShippingAddresses;
  final VoidCallback? onClose;
  final bool autoFocusNotifications;
  final int notificationFocusRequestKey;

  /// Optional seed data
  final CompanyBusinessInfoDraft? initialBusinessInfo;
  final CompanyBillingDraft? initialBillingInfo;
  final CompanyAddressesDraft? initialAddressesInfo;

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  static const Duration _photoUploadTimeout = Duration(seconds: 90);
  static const Duration _profileSaveTimeout = Duration(seconds: 30);
  late CompanyBusinessInfoDraft _businessInfo;
  late CompanyBillingDraft _billingInfo;
  late CompanyAddressesDraft _addressInfo;
  CompanyCommunicationPreferences _communicationPreferences =
      CompanyCommunicationPreferences.defaults();
  Map<String, dynamic> _companyRowData = const <String, dynamic>{};
  String _profileImageUrl = '';
  bool _uploadingPhoto = false;
  final FocusNode _logoUploadFocusNode = FocusNode(
    debugLabel: 'companyProfileLogoUpload',
  );
  final GlobalKey _logoUploadSemanticsKey = GlobalKey(
    debugLabel: 'companyProfileLogoUploadA11yKey',
  );
  final FocusNode _communicationPreferenceFocusNode = FocusNode(
    debugLabel: 'companyCommunicationPreferenceTile',
  );
  final GlobalKey _communicationPreferenceSemanticsKey = GlobalKey(
    debugLabel: 'companyCommunicationPreferenceTileA11yKey',
  );

  @override
  void initState() {
    super.initState();
    _businessInfo =
        widget.initialBusinessInfo ?? CompanyBusinessInfoDraft.empty();
    _billingInfo = widget.initialBillingInfo ?? CompanyBillingDraft.empty();
    _addressInfo = widget.initialAddressesInfo ?? CompanyAddressesDraft.empty();
    _profileImageUrl = widget.profileImageUrl.trim();
    unawaited(_hydrateProfileImageUrl());
    unawaited(_hydrateDraftsFromCompanyRow());
  }

  @override
  void dispose() {
    _logoUploadFocusNode.dispose();
    _communicationPreferenceFocusNode.dispose();
    super.dispose();
  }

  // The OS image picker steals both Flutter input focus and Android
  // accessibility focus. Restore both so TalkBack returns to the same
  // Change company logo control instead of jumping elsewhere on the page.
  void _restoreLogoUploadFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_logoUploadFocusNode);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _logoUploadSemanticsKey.currentContext
          ?.findRenderObject()
          ?.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  Future<void> _restoreCommunicationPreferenceFocus() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final targetContext = _communicationPreferenceSemanticsKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (!mounted) return;

    FocusScope.of(context).requestFocus(_communicationPreferenceFocusNode);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    targetContext.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _communicationPreferenceSemanticsKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  @override
  void didUpdateWidget(covariant CompanyProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAcceptSeedUpdates = _companyRowData.isEmpty;
    if (shouldAcceptSeedUpdates &&
        widget.initialBusinessInfo != oldWidget.initialBusinessInfo &&
        widget.initialBusinessInfo != null) {
      _businessInfo = widget.initialBusinessInfo!;
    }
    if (shouldAcceptSeedUpdates &&
        widget.initialBillingInfo != oldWidget.initialBillingInfo &&
        widget.initialBillingInfo != null) {
      _billingInfo = widget.initialBillingInfo!;
    }
    if (shouldAcceptSeedUpdates &&
        widget.initialAddressesInfo != oldWidget.initialAddressesInfo &&
        widget.initialAddressesInfo != null) {
      _addressInfo = widget.initialAddressesInfo!;
    }
    if (widget.profileImageUrl.trim() != oldWidget.profileImageUrl.trim()) {
      _profileImageUrl = widget.profileImageUrl.trim();
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  String get _uid => (_client.auth.currentUser?.id ?? '').trim();

  String get _email =>
      (_client.auth.currentUser?.email ?? '').trim().toLowerCase();

  dynamic get _companyStorage => _client.storage.from('company-logos');

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  CompanyCommunicationPreferences _communicationPreferencesFromRow(
    Map<String, dynamic> row,
  ) {
    final profile = _asMap(row['profile']);
    final basic = _asMap(row['basic']);
    final company = _asMap(row['company']);
    final source = _asMap(profile['communicationPreferences']).isNotEmpty
        ? _asMap(profile['communicationPreferences'])
        : _asMap(profile['communication_preferences']).isNotEmpty
        ? _asMap(profile['communication_preferences'])
        : _asMap(basic['communicationPreferences']).isNotEmpty
        ? _asMap(basic['communicationPreferences'])
        : _asMap(basic['communication_preferences']).isNotEmpty
        ? _asMap(basic['communication_preferences'])
        : _asMap(company['communicationPreferences']).isNotEmpty
        ? _asMap(company['communicationPreferences'])
        : _asMap(company['communication_preferences']);
    if (source.isEmpty) return CompanyCommunicationPreferences.defaults();
    return CompanyCommunicationPreferences.fromMap(source);
  }

  String _normalizeStorageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('data:image/')) return value;
    if (value.startsWith('company-logos/')) {
      return _companyStorage
          .getPublicUrl(value.substring('company-logos/'.length))
          .trim();
    }
    if (value.startsWith('companies/')) {
      return _companyStorage.getPublicUrl(value).trim();
    }
    if (value.startsWith('company/')) {
      return _companyStorage.getPublicUrl(value).trim();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _readCompanyRow() async {
    if (_uid.isEmpty && _email.isEmpty) return null;

    for (final predicate in <Future<List<dynamic>> Function()>[
      () async {
        if (_uid.isEmpty) return const <dynamic>[];
        return _client.from('company').select().eq('id', _uid).limit(1);
      },
      () async {
        if (_email.isEmpty) return const <dynamic>[];
        return _client.from('company').select().eq('email', _email).limit(1);
      },
    ]) {
      try {
        final rows = await predicate();
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (e) {
        debugPrint('COMPANY PROFILE LOAD FAILED: $e');
      }
    }

    return null;
  }

  String? _missingColumnFromPostgrest(String message) {
    for (final pattern in <RegExp>[
      RegExp(r"Could not find the '([^']+)' column"),
      RegExp(r'column [^ ]+\.([a-zA-Z0-9_]+) does not exist'),
    ]) {
      final match = pattern.firstMatch(message);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<void> _upsertCompanyRow(Map<String, dynamic> values) async {
    final existing = await _readCompanyRow();
    final resolvedId = _firstNonEmpty([
      existing?['id'],
      existing?['uid'],
      _companyRowData['id'],
      _companyRowData['uid'],
      _uid,
    ]);
    final resolvedEmail = _firstNonEmpty([
      existing?['email'],
      _companyRowData['email'],
      _email,
    ]);
    final row = <String, dynamic>{
      'id': resolvedId,
      'email': resolvedEmail,
      'account_type': 'company',
      'updated_at': DateTime.now().toIso8601String(),
      ...values,
    };
    if (existing != null) {
      for (final section in const <String>[
        'profile',
        'basic',
        'company',
        'addresses',
        'billing',
      ]) {
        final nextSection = row[section];
        if (nextSection is Map) {
          final currentSection = _asMap(existing[section]);
          row[section] = <String, dynamic>{
            ...currentSection,
            ..._asMap(nextSection),
          };
        }
      }
      for (final entry in existing.entries) {
        row.putIfAbsent(entry.key, () => entry.value);
      }
      row.addAll(values);
      row['id'] = resolvedId;
      row['email'] = resolvedEmail;
      row['account_type'] = 'company';
      row['updated_at'] = DateTime.now().toIso8601String();
    }

    for (var attempt = 0; attempt < 50; attempt++) {
      try {
        await _client.from('company').upsert(row).timeout(_profileSaveTimeout);
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _missingColumnFromPostgrest(error.message);
        final canRetry =
            missingColumn != null && row.containsKey(missingColumn);
        if (!canRetry) rethrow;
        row.remove(missingColumn);
      }
    }

    throw const PostgrestException(
      message: 'Could not save company profile after schema fallback retries.',
      code: 'PGRST204',
    );
  }

  String _first(
    Object? a, [
    Object? b,
    Object? c,
    Object? d,
    Object? e,
    Object? f,
    Object? g,
    Object? h,
    Object? i,
    Object? j,
    Object? k,
    Object? l,
    Object? m,
    Object? n,
    Object? o,
  ]) {
    for (final candidate in <Object?>[
      a,
      b,
      c,
      d,
      e,
      f,
      g,
      h,
      i,
      j,
      k,
      l,
      m,
      n,
      o,
    ]) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  CompanyBusinessInfoDraft _businessInfoFromRow(Map<String, dynamic> row) {
    final company = _asMap(row['company']);
    final profile = _asMap(row['profile']);
    final basic = _asMap(row['basic']);
    return CompanyBusinessInfoDraft(
      companyName: _first(
        row['panel_companyName'],
        row['panel_company_name'],
        company['name'],
        company['companyName'],
        company['company_name'],
        profile['companyName'],
        profile['company_name'],
        basic['companyName'],
        basic['company_name'],
        widget.initialBusinessInfo?.companyName,
        widget.companyName,
      ),
      contactName: _first(
        row['panel_contactName'],
        row['panel_contact_name'],
        company['contactName'],
        company['contact_name'],
        profile['contactName'],
        profile['contact_name'],
        basic['contactName'],
        basic['contact_name'],
        widget.initialBusinessInfo?.contactName,
      ),
      contactEmail: _first(
        row['panel_contactEmail'],
        row['panel_contact_email'],
        row['contact_email'],
        company['contactEmail'],
        company['contact_email'],
        profile['contactEmail'],
        profile['contact_email'],
        basic['contactEmail'],
        basic['contact_email'],
        widget.initialBusinessInfo?.contactEmail,
      ),
      contactPhone: _first(
        row['panel_contactPhone'],
        row['panel_contact_phone'],
        row['panel_contactPhoneAreaCode'] != null &&
                row['panel_contactPhoneLocal'] != null
            ? '${row['panel_contactPhoneAreaCode']}${row['panel_contactPhoneLocal']}'
            : null,
        company['contactPhone'],
        company['contact_phone'],
        profile['contactPhone'],
        profile['contact_phone'],
        basic['contactPhone'],
        basic['contact_phone'],
        widget.initialBusinessInfo?.contactPhone,
      ),
      companyEmail: _first(
        row['panel_companyEmail'],
        row['panel_company_email'],
        row['email'],
        row['company_email'],
        company['companyEmail'],
        company['company_email'],
        profile['companyEmail'],
        profile['company_email'],
        basic['companyEmail'],
        basic['company_email'],
        widget.initialBusinessInfo?.companyEmail,
        widget.email,
      ),
      companyPhone: _first(
        row['panel_companyPhone'],
        row['panel_company_phone'],
        row['panel_companyPhoneAreaCode'] != null &&
                row['panel_companyPhoneLocal'] != null
            ? '${row['panel_companyPhoneAreaCode']}${row['panel_companyPhoneLocal']}'
            : null,
        company['companyPhone'],
        company['company_phone'],
        company['phone'],
        profile['companyPhone'],
        profile['company_phone'],
        basic['companyPhone'],
        basic['company_phone'],
        widget.initialBusinessInfo?.companyPhone,
      ),
      companyUrl: _first(
        row['panel_companyWebsite'],
        row['panel_company_website'],
        row['panel_website'],
        company['companyWebsite'],
        company['company_website'],
        company['website'],
        profile['companyUrl'],
        profile['companyWebsite'],
        profile['company_website'],
        basic['companyUrl'],
        basic['companyWebsite'],
        basic['company_website'],
        widget.initialBusinessInfo?.companyUrl,
      ),
      businessType: _first(
        row['panel_businessType'],
        row['panel_business_type'],
        company['businessType'],
        company['business_type'],
        profile['businessType'],
        profile['business_type'],
        basic['businessType'],
        basic['business_type'],
        widget.initialBusinessInfo?.businessType,
      ),
    );
  }

  CompanyBillingDraft _billingInfoFromRow(Map<String, dynamic> row) {
    final billing = _asMap(row['billing']);
    return CompanyBillingDraft(
      method: _first(
        billing['method'],
        row['panel_billingMethod'],
        row['panel_billing_method'],
        widget.initialBillingInfo?.method,
        'Credit/Debit Card',
      ),
      saveForFutureUse:
          billing['saveForFutureUse'] == true ||
          billing['save_for_future_use'] == true ||
          row['panel_billingSaveForFutureUse'] == true ||
          row['panel_billing_save_for_future_use'] == true ||
          (widget.initialBillingInfo?.saveForFutureUse ?? false),
      nameOnCard: _first(
        billing['nameOnCard'],
        row['panel_billingNameOnCard'],
        row['panel_billing_name_on_card'],
        widget.initialBillingInfo?.nameOnCard,
      ),
      cardNumber: _first(
        billing['cardNumber'],
        billing['card_number'],
        row['panel_billingCardNumber'],
        row['panel_billing_card_number'],
        widget.initialBillingInfo?.cardNumber,
      ),
      expiry: _first(
        billing['expiry'],
        row['panel_billingExpiry'],
        row['panel_billing_expiry'],
        widget.initialBillingInfo?.expiry,
      ),
      cvv: _first(
        billing['cvv'],
        row['panel_billingCvv'],
        row['panel_billing_cvv'],
        widget.initialBillingInfo?.cvv,
      ),
      achAccountName: _first(
        billing['achAccountName'],
        billing['ach_account_name'],
        row['panel_billingAchAccountName'],
        row['panel_billing_ach_account_name'],
        widget.initialBillingInfo?.achAccountName,
      ),
      achRoutingNumber: _first(
        billing['achRoutingNumber'],
        billing['ach_routing_number'],
        row['panel_billingAchRoutingNumber'],
        row['panel_billing_ach_routing_number'],
        widget.initialBillingInfo?.achRoutingNumber,
      ),
      achAccountNumber: _first(
        billing['achAccountNumber'],
        billing['ach_account_number'],
        row['panel_billingAchAccountNumber'],
        row['panel_billing_ach_account_number'],
        widget.initialBillingInfo?.achAccountNumber,
      ),
      applePayEmail: _first(
        billing['applePayEmail'],
        row['panel_billingApplePayEmail'],
        row['panel_billing_apple_pay_email'],
        widget.initialBillingInfo?.applePayEmail,
      ),
      googlePayEmail: _first(
        billing['googlePayEmail'],
        row['panel_billingGooglePayEmail'],
        row['panel_billing_google_pay_email'],
        widget.initialBillingInfo?.googlePayEmail,
      ),
    );
  }

  CompanyAddressesDraft _addressesInfoFromRow(Map<String, dynamic> row) {
    final addresses = _asMap(row['addresses']);
    return CompanyAddressesDraft(
      billingStreet: _first(
        addresses['billingStreet'],
        row['panel_billingStreet'],
        row['panel_billing_street'],
        widget.initialAddressesInfo?.billingStreet,
      ),
      billingCity: _first(
        addresses['billingCity'],
        row['panel_billingCity'],
        row['panel_billing_city'],
        widget.initialAddressesInfo?.billingCity,
      ),
      billingState: _first(
        addresses['billingState'],
        row['panel_billingState'],
        row['panel_billing_state'],
        widget.initialAddressesInfo?.billingState,
      ),
      billingZip: _first(
        addresses['billingZip'],
        row['panel_billingZip'],
        row['panel_billing_zip'],
        widget.initialAddressesInfo?.billingZip,
      ),
      billingCountry: _first(
        addresses['billingCountry'],
        row['panel_billingCountry'],
        row['panel_billing_country'],
        widget.initialAddressesInfo?.billingCountry,
      ),
      shippingSameAsBilling:
          addresses['shippingSameAsBilling'] == true ||
          row['panel_shippingSameAsBilling'] == true ||
          row['panel_shipping_same_as_billing'] == true ||
          (widget.initialAddressesInfo?.shippingSameAsBilling ?? false),
      shippingStreet: _first(
        addresses['shippingStreet'],
        row['panel_shippingStreet'],
        row['panel_shipping_street'],
        widget.initialAddressesInfo?.shippingStreet,
      ),
      shippingCity: _first(
        addresses['shippingCity'],
        row['panel_shippingCity'],
        row['panel_shipping_city'],
        widget.initialAddressesInfo?.shippingCity,
      ),
      shippingState: _first(
        addresses['shippingState'],
        row['panel_shippingState'],
        row['panel_shipping_state'],
        widget.initialAddressesInfo?.shippingState,
      ),
      shippingZip: _first(
        addresses['shippingZip'],
        row['panel_shippingZip'],
        row['panel_shipping_zip'],
        widget.initialAddressesInfo?.shippingZip,
      ),
      shippingCountry: _first(
        addresses['shippingCountry'],
        row['panel_shippingCountry'],
        row['panel_shipping_country'],
        widget.initialAddressesInfo?.shippingCountry,
      ),
    );
  }

  Future<void> _hydrateDraftsFromCompanyRow() async {
    final row = await _readCompanyRow();
    if (!mounted || row == null) return;
    setState(() {
      _companyRowData = row;
      _businessInfo = _businessInfoFromRow(row);
      _billingInfo = _billingInfoFromRow(row);
      _addressInfo = _addressesInfoFromRow(row);
      _communicationPreferences = _communicationPreferencesFromRow(row);
    });
  }

  Future<void> _editBusinessInfo() async {
    final updated = await showModalBottomSheet<CompanyBusinessInfoDraft>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCompanyBusinessInfoPopup(initial: _businessInfo),
    );

    if (updated != null) {
      try {
        await _persistBusinessInfo(updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save business info: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _businessInfo = updated);
      await _hydrateDraftsFromCompanyRow();
    }
  }

  Future<void> _editBilling() async {
    final updated = await showModalBottomSheet<CompanyBillingDraft>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCompanyBillingPopup(initial: _billingInfo),
    );

    if (updated != null) {
      try {
        await _persistBillingInfo(updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save billing details: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _billingInfo = updated);
      await _hydrateDraftsFromCompanyRow();
    }
  }

  Future<void> _persistBillingInfo(CompanyBillingDraft billing) async {
    if (_uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }

    await _upsertCompanyRow({
      'panel_billingMethod': billing.method,
      'panel_billing_method': billing.method,
      'panel_billingSaveForFutureUse': billing.saveForFutureUse,
      'panel_billing_save_for_future_use': billing.saveForFutureUse,
      'panel_billingNameOnCard': billing.nameOnCard,
      'panel_billing_name_on_card': billing.nameOnCard,
      'panel_billingExpiry': billing.expiry,
      'panel_billing_expiry': billing.expiry,
      'panel_billingApplePayEmail': billing.applePayEmail,
      'panel_billing_apple_pay_email': billing.applePayEmail,
      'panel_billingGooglePayEmail': billing.googlePayEmail,
      'panel_billing_google_pay_email': billing.googlePayEmail,
      'billing': {
        'method': billing.method,
        'saveForFutureUse': billing.saveForFutureUse,
        'nameOnCard': billing.nameOnCard,
        'cardNumber': billing.cardNumber,
        'expiry': billing.expiry,
        'cvv': billing.cvv,
        'achAccountName': billing.achAccountName,
        'achRoutingNumber': billing.achRoutingNumber,
        'achAccountNumber': billing.achAccountNumber,
        'applePayEmail': billing.applePayEmail,
        'googlePayEmail': billing.googlePayEmail,
      },
    });
    await _hydrateDraftsFromCompanyRow();
  }

  Future<void> _persistBusinessInfo(CompanyBusinessInfoDraft business) async {
    if (_uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }
    await _upsertCompanyRow({
      'panel_companyName': business.companyName,
      'panel_company_name': business.companyName,
      'panel_contactName': business.contactName,
      'panel_contact_name': business.contactName,
      'panel_contactEmail': business.contactEmail,
      'panel_contact_email': business.contactEmail,
      'panel_companyEmail': business.companyEmail,
      'panel_company_email': business.companyEmail,
      'panel_companyPhone': business.companyPhone,
      'panel_company_phone': business.companyPhone,
      'panel_contactPhone': business.contactPhone,
      'panel_contact_phone': business.contactPhone,
      'panel_companyWebsite': business.companyUrl,
      'panel_company_website': business.companyUrl,
      'panel_businessType': business.businessType,
      'panel_business_type': business.businessType,
      'profile': {
        'companyName': business.companyName,
        'company_name': business.companyName,
        'displayName': business.companyName,
        'contactName': business.contactName,
        'contact_name': business.contactName,
        'contactEmail': business.contactEmail,
        'contact_email': business.contactEmail,
        'contactPhone': business.contactPhone,
        'contact_phone': business.contactPhone,
        'companyEmail': business.companyEmail,
        'company_email': business.companyEmail,
        'companyPhone': business.companyPhone,
        'company_phone': business.companyPhone,
        'companyUrl': business.companyUrl,
        'company_website': business.companyUrl,
        'companyWebsite': business.companyUrl,
        'businessType': business.businessType,
        'business_type': business.businessType,
      },
      'basic': {
        'companyName': business.companyName,
        'company_name': business.companyName,
        'displayName': business.companyName,
        'contactName': business.contactName,
        'contact_name': business.contactName,
        'contactEmail': business.contactEmail,
        'contact_email': business.contactEmail,
        'contactPhone': business.contactPhone,
        'contact_phone': business.contactPhone,
        'companyEmail': business.companyEmail,
        'company_email': business.companyEmail,
        'companyPhone': business.companyPhone,
        'company_phone': business.companyPhone,
        'companyUrl': business.companyUrl,
        'company_website': business.companyUrl,
        'companyWebsite': business.companyUrl,
        'businessType': business.businessType,
        'business_type': business.businessType,
      },
      'company': {
        'name': business.companyName,
        'companyName': business.companyName,
        'contactName': business.contactName,
        'contactEmail': business.contactEmail,
        'companyEmail': business.companyEmail,
        'phone': business.companyPhone,
        'companyPhone': business.companyPhone,
        'contactPhone': business.contactPhone,
        'website': business.companyUrl,
        'companyWebsite': business.companyUrl,
        'businessType': business.businessType,
        'company_name': business.companyName,
        'contact_name': business.contactName,
        'contact_email': business.contactEmail,
        'company_email': business.companyEmail,
        'contact_phone': business.contactPhone,
        'company_phone': business.companyPhone,
        'company_website': business.companyUrl,
        'business_type': business.businessType,
      },
    });
    await _hydrateDraftsFromCompanyRow();
  }

  Future<void> _editAddresses() async {
    final updated = await showModalBottomSheet<CompanyAddressesDraft>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCompanyAddressesPopup(initial: _addressInfo),
    );

    if (updated != null) {
      try {
        await _persistAddressesInfo(updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address info: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _addressInfo = updated);
      await _hydrateDraftsFromCompanyRow();
    }
  }

  Future<void> _persistAddressesInfo(CompanyAddressesDraft addresses) async {
    if (_uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }
    await _upsertCompanyRow({
      'addresses': {
        'billingStreet': addresses.billingStreet,
        'billingCity': addresses.billingCity,
        'billingState': addresses.billingState,
        'billingZip': addresses.billingZip,
        'billingCountry': addresses.billingCountry,
        'shippingSameAsBilling': addresses.shippingSameAsBilling,
        'shippingStreet': addresses.shippingStreet,
        'shippingCity': addresses.shippingCity,
        'shippingState': addresses.shippingState,
        'shippingZip': addresses.shippingZip,
        'shippingCountry': addresses.shippingCountry,
      },
      'panel_billingStreet': addresses.billingStreet,
      'panel_billing_street': addresses.billingStreet,
      'panel_billingCity': addresses.billingCity,
      'panel_billing_city': addresses.billingCity,
      'panel_billingState': addresses.billingState,
      'panel_billing_state': addresses.billingState,
      'panel_billingZip': addresses.billingZip,
      'panel_billing_zip': addresses.billingZip,
      'panel_billingCountry': addresses.billingCountry,
      'panel_billing_country': addresses.billingCountry,
      'panel_shippingSameAsBilling': addresses.shippingSameAsBilling,
      'panel_shipping_same_as_billing': addresses.shippingSameAsBilling,
      'panel_shippingStreet': addresses.shippingStreet,
      'panel_shipping_street': addresses.shippingStreet,
      'panel_shippingCity': addresses.shippingCity,
      'panel_shipping_city': addresses.shippingCity,
      'panel_shippingState': addresses.shippingState,
      'panel_shipping_state': addresses.shippingState,
      'panel_shippingZip': addresses.shippingZip,
      'panel_shipping_zip': addresses.shippingZip,
      'panel_shippingCountry': addresses.shippingCountry,
      'panel_shipping_country': addresses.shippingCountry,
    });
    await _hydrateDraftsFromCompanyRow();
  }

  Future<void> _editCommunicationPreferences() async {
    final updated = await showModalBottomSheet<CompanyCommunicationPreferences>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanyCommunicationPreferencesPopup(
        initial: _communicationPreferences,
      ),
    );

    if (updated == null) {
      await _restoreCommunicationPreferenceFocus();
      return;
    }

    final payload = updated.toMap();
    final currentProfile = _asMap(_companyRowData['profile']);
    final currentBasic = _asMap(_companyRowData['basic']);
    final currentCompany = _asMap(_companyRowData['company']);
    try {
      await _upsertCompanyRow({
        'profile': {
          ...currentProfile,
          'communicationPreferences': payload,
          'communication_preferences': payload,
        },
        'basic': {
          ...currentBasic,
          'communicationPreferences': payload,
          'communication_preferences': payload,
        },
        'company': {
          ...currentCompany,
          'communicationPreferences': payload,
          'communication_preferences': payload,
        },
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save communication preferences: $e')),
      );
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Failed to save communication preferences.',
        Directionality.of(context),
      );
      await _restoreCommunicationPreferenceFocus();
      return;
    }
    if (!mounted) return;
    setState(() => _communicationPreferences = updated);
    await _hydrateDraftsFromCompanyRow();
    if (!mounted) return;

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Communication preferences saved.',
      Directionality.of(context),
    );
    await _restoreCommunicationPreferenceFocus();
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_uploadingPhoto) return;
    if (_uid.isEmpty) return;

    setState(() => _uploadingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (picked == null) {
        _restoreLogoUploadFocus();
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _restoreLogoUploadFocus();
        return;
      }
      final nextUrl = await _uploadCompanyProfilePhoto(_uid, bytes);
      await _persistProfilePhoto(nextUrl);
      if (!mounted) return;
      setState(() => _profileImageUrl = nextUrl);
      _restoreLogoUploadFocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (e) {
      if (!mounted) return;
      final msg = e is TimeoutException
          ? 'Upload timed out. Please retry with a stable connection.'
          : 'Failed to upload photo: $e';
      _restoreLogoUploadFocus();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<String> _resolveCompanyStorageAvatar(String uid) async {
    try {
      final entries = await _companyStorage.list(path: 'companies/$uid/logo');
      for (final file in entries) {
        final name = (file.name ?? '').toString().trim();
        final lower = name.toLowerCase();
        if (name.isEmpty) continue;
        if (!lower.endsWith('.jpg') &&
            !lower.endsWith('.jpeg') &&
            !lower.endsWith('.png') &&
            !lower.endsWith('.webp')) {
          continue;
        }
        return _companyStorage.getPublicUrl('companies/$uid/logo/$name').trim();
      }
    } catch (_) {}
    return '';
  }

  Future<void> _hydrateProfileImageUrl() async {
    if (_profileImageUrl.trim().isNotEmpty) return;
    if (_uid.isEmpty && _email.isEmpty) return;

    try {
      final row = await _readCompanyRow();
      final data = row ?? const <String, dynamic>{};
      final profile = _asMap(data['profile']);
      final basic = _asMap(data['basic']);
      final company = _asMap(data['company']);

      final resolved = _normalizeStorageUrl(
        _firstNonEmpty([
          data['panel_logoUrl'],
          data['companyLogoUrl'],
          data['brandLogoUrl'],
          data['logoUrl'],
          data['panel_profileImageUrl'],
          data['profileImageUrl'],
          data['photoUrl'],
          data['avatarUrl'],
          profile['logoUrl'],
          profile['profileImageUrl'],
          profile['photoUrl'],
          profile['avatarUrl'],
          basic['profileImageUrl'],
          basic['photoUrl'],
          basic['avatarUrl'],
          company['logoUrl'],
          company['profileImageUrl'],
          company['photoUrl'],
          company['avatarUrl'],
        ]),
      );

      final fallbackResolved = resolved.isNotEmpty || _uid.isEmpty
          ? resolved
          : await _resolveCompanyStorageAvatar(_uid);

      if (!mounted || fallbackResolved.isEmpty) return;
      setState(() => _profileImageUrl = fallbackResolved);
    } catch (_) {}
  }

  Future<String> _uploadCompanyProfilePhoto(String uid, Uint8List bytes) async {
    final path =
        'companies/$uid/logo/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _companyStorage
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        )
        .timeout(_photoUploadTimeout);
    return _companyStorage.getPublicUrl(path).trim();
  }

  Future<void> _persistProfilePhoto(String photoUrl) async {
    if (_uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }
    final value = _normalizeStorageUrl(photoUrl);
    await _upsertCompanyRow({
      'panel_profileImageUrl': value,
      'panel_profile_image_url': value,
      'panel_logoUrl': value,
      'panel_logo_url': value,
      'companyLogoUrl': value,
      'brandLogoUrl': value,
      'profileImageUrl': value,
      'logoUrl': value,
      'photoUrl': value,
      'avatarUrl': value,
      'profile': {
        'profileImageUrl': value,
        'photoUrl': value,
        'avatarUrl': value,
        'logoUrl': value,
      },
      'basic': {
        'profileImageUrl': value,
        'photoUrl': value,
        'avatarUrl': value,
      },
      'company': {
        'logoUrl': value,
        'profileImageUrl': value,
        'photoUrl': value,
        'avatarUrl': value,
        'logo_url': value,
        'profile_image_url': value,
        'photo_url': value,
        'avatar_url': value,
      },
    }).timeout(_profileSaveTimeout);
  }

  @override
  Widget build(BuildContext context) {
    final companyName = _businessInfo.companyName.trim().isNotEmpty
        ? _businessInfo.companyName.trim()
        : widget.companyName;
    final city = _addressInfo.billingCity.trim();
    final state = _addressInfo.billingState.trim();
    final locationText = city.isEmpty && state.isEmpty
        ? widget.locationText
        : (city.isEmpty ? state : (state.isEmpty ? city : '$city, $state'));

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Company profile',
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: CompanyHeader(
          companyName: companyName.isEmpty ? 'Company' : companyName,
          imageUrl: _profileImageUrl,
          autoFocusNotifications: widget.autoFocusNotifications,
          notificationFocusRequestKey: widget.notificationFocusRequestKey,
          trailing: IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 26,
              color: AppColors.blackCat,
            ),
            splashRadius: 24,
            tooltip: 'Close company profile',
          ),
          onLogout: widget.onLogout,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            const SizedBox(height: 6),

            // Avatar moved into body (not header)
            Center(
              child: SizedBox(
                height: 72,
                width: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: _safeProfileAvatar(
                            imageUrl: _profileImageUrl,
                            displayName: companyName,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: Semantics(
                            key: _logoUploadSemanticsKey,
                            button: true,
                            enabled: !_uploadingPhoto,
                            label: _uploadingPhoto
                                ? 'Changing company logo'
                                : 'Change company logo',
                            hint: _uploadingPhoto
                                ? null
                                : 'Double tap to choose a company logo',
                            onTap: _uploadingPhoto
                                ? null
                                : _pickAndUploadProfilePhoto,
                            child: ExcludeSemantics(
                              child: InkWell(
                                focusNode: _logoUploadFocusNode,
                                onTap: _uploadingPhoto
                                    ? null
                                    : _pickAndUploadProfilePhoto,
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.snow,
                                        border: Border.all(
                                          color: AppColors.blackCatBorderLight,
                                        ),
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      child: _uploadingPhoto
                                          ? const Padding(
                                              padding: EdgeInsets.all(5),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                              ),
                                            )
                                          : const Icon(Icons.edit, size: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: Text(
                companyName.isEmpty ? 'Company' : companyName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                locationText.isEmpty ? 'No location on file' : locationText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // BUSINESS
            _RowChevronTile(
              icon: Icons.business_outlined,
              title: 'Business Info',
              onTap: _editBusinessInfo,
            ),

            // ACCOUNT
            _RowChevronTile(
              icon: Icons.credit_card_outlined,
              title: 'Billing',
              onTap: widget.onOpenBilling ?? _editBilling,
            ),
            _RowChevronTile(
              icon: Icons.location_on_outlined,
              title: 'Addresses',
              onTap: widget.onOpenShippingAddresses ?? _editAddresses,
            ),
            _RowChevronTile(
              icon: Icons.notifications_active_outlined,
              title: 'Communication Preference',
              onTap: _editCommunicationPreferences,
              focusNode: _communicationPreferenceFocusNode,
              semanticsKey: _communicationPreferenceSemanticsKey,
            ),

            const SizedBox(height: 22),

            _TextDangerButton(text: 'Log out', onTap: widget.onLogout),
          ],
        ),
      ),
    );
  }

  Widget _safeProfileAvatar({
    required String imageUrl,
    required String displayName,
  }) {
    final src = imageUrl.trim();
    if (src.startsWith('data:image/')) {
      return ClientProfileAvatarIcon(
        imageUrl: src,
        displayName: displayName,
        size: 72,
      );
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return SizedBox.expand(
        child: Image.network(
          src,
          fit: BoxFit.cover,
          cacheWidth: 216,
          cacheHeight: 216,
          errorBuilder: (_, _, _) =>
              ClientProfileAvatarIcon(displayName: displayName, size: 72),
        ),
      );
    }
    return ClientProfileAvatarIcon(
      imageUrl: src,
      displayName: displayName,
      size: 72,
    );
  }
}

/// ---------------- UI components ----------------

class _TextDangerButton extends StatelessWidget {
  const _TextDangerButton({required this.text, required this.onTap});

  final String text;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 44,
        width: 180,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blackCat,
            foregroundColor: AppColors.snow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: () async => onTap(),
          child: const Text(
            'Log out',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _RowChevronTile extends StatelessWidget {
  const _RowChevronTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.focusNode,
    this.semanticsKey,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final GlobalKey? semanticsKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      button: true,
      label: title,
      hint: 'Double tap to open $title',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.blackCatBorderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.deepPlum, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black.withValues(alpha: 0.35),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompanyCommunicationPreferences {
  const CompanyCommunicationPreferences({
    required this.emailNotifications,
    required this.smsNotifications,
  });

  final bool emailNotifications;
  final bool smsNotifications;

  factory CompanyCommunicationPreferences.defaults() {
    return const CompanyCommunicationPreferences(
      emailNotifications: true,
      smsNotifications: true,
    );
  }

  factory CompanyCommunicationPreferences.fromMap(Map<String, dynamic> map) {
    bool asBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
      return fallback;
    }

    final defaults = CompanyCommunicationPreferences.defaults();
    return CompanyCommunicationPreferences(
      emailNotifications: asBool(
        map['emailNotifications'] ?? map['email_notifications'],
        defaults.emailNotifications,
      ),
      smsNotifications: asBool(
        map['smsNotifications'] ?? map['sms_notifications'],
        defaults.smsNotifications,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
    };
  }
}

class CompanyCommunicationPreferencesPopup extends StatefulWidget {
  const CompanyCommunicationPreferencesPopup({
    super.key,
    required this.initial,
  });

  final CompanyCommunicationPreferences initial;

  @override
  State<CompanyCommunicationPreferencesPopup> createState() =>
      _CompanyCommunicationPreferencesPopupState();
}

class _CompanyCommunicationPreferencesPopupState
    extends State<CompanyCommunicationPreferencesPopup> {
  late bool _emailNotifications;
  late bool _smsNotifications;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _closeButtonFocusNode = FocusNode(
    debugLabel: 'companyCommunicationPreferencesClose',
  );
  final GlobalKey _closeButtonKey = GlobalKey(
    debugLabel: 'companyCommunicationPreferencesCloseA11yKey',
  );

  @override
  void initState() {
    super.initState();
    _emailNotifications = widget.initial.emailNotifications;
    _smsNotifications = widget.initial.smsNotifications;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    super.dispose();
  }

  Future<void> _moveAccessibilityFocusToClose({
    bool scrollToTop = false,
  }) async {
    if (!mounted) return;

    if (scrollToTop && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
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

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _closeButtonKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(const FocusSemanticEvent());
  }

  void _close() => Navigator.pop(context);

  void _save() {
    Navigator.pop(
      context,
      CompanyCommunicationPreferences(
        emailNotifications: _emailNotifications,
        smsNotifications: _smsNotifications,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Communication preferences',
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(color: AppColors.snow),
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  sortKey: OrdinalSortKey(0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          sortKey: OrdinalSortKey(1),
                          header: true,
                          label: 'Communication Preferences',
                          child: const ExcludeSemantics(
                            child: Center(
                              child: Text(
                                'Communication Preferences',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blackCat,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        key: _closeButtonKey,
                        sortKey: OrdinalSortKey(0),
                        button: true,
                        label: 'Close communication preferences',
                        hint: 'Double tap to close without saving',
                        onTap: _close,
                        child: ExcludeSemantics(
                          child: IconButton(
                            focusNode: _closeButtonFocusNode,
                            tooltip: 'Close communication preferences',
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  sortKey: OrdinalSortKey(1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _toggleTile(
                        title: 'Email Notifications',
                        value: _emailNotifications,
                        onChanged: (value) =>
                            setState(() => _emailNotifications = value),
                      ),
                      _toggleTile(
                        title: 'SMS Notifications',
                        value: _smsNotifications,
                        onChanged: (value) =>
                            setState(() => _smsNotifications = value),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        button: true,
                        label: 'Save communication preferences',
                        hint: 'Double tap to save',
                        onTap: _save,
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blackCat,
                                foregroundColor: AppColors.snow,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: _save,
                              child: const Text('Save'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  sortKey: OrdinalSortKey(2),
                  button: true,
                  label: 'Close communication preferences',
                  onTap: _close,
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
    );
  }

  Widget _toggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    void handleChanged(bool next) {
      onChanged(next);
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$title ${next ? 'on' : 'off'}',
        Directionality.of(context),
      );
    }

    return Semantics(
      button: true,
      label: title,
      value: value ? 'On' : 'Off',
      hint: 'Double tap to turn ${value ? 'off' : 'on'}',
      onTap: () => handleChanged(!value),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => handleChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: handleChanged,
                    activeThumbColor: AppColors.blackCat,
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

class CompanyBillingDraft {
  final String method;
  final bool saveForFutureUse;
  final String nameOnCard;
  final String cardNumber;
  final String expiry;
  final String cvv;
  final String achAccountName;
  final String achRoutingNumber;
  final String achAccountNumber;
  final String applePayEmail;
  final String googlePayEmail;

  const CompanyBillingDraft({
    required this.method,
    required this.saveForFutureUse,
    this.nameOnCard = '',
    this.cardNumber = '',
    this.expiry = '',
    this.cvv = '',
    this.achAccountName = '',
    this.achRoutingNumber = '',
    this.achAccountNumber = '',
    this.applePayEmail = '',
    this.googlePayEmail = '',
  });

  CompanyBillingDraft copyWith({
    String? method,
    bool? saveForFutureUse,
    String? nameOnCard,
    String? cardNumber,
    String? expiry,
    String? cvv,
    String? achAccountName,
    String? achRoutingNumber,
    String? achAccountNumber,
    String? applePayEmail,
    String? googlePayEmail,
  }) {
    return CompanyBillingDraft(
      method: method ?? this.method,
      saveForFutureUse: saveForFutureUse ?? this.saveForFutureUse,
      nameOnCard: nameOnCard ?? this.nameOnCard,
      cardNumber: cardNumber ?? this.cardNumber,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      achAccountName: achAccountName ?? this.achAccountName,
      achRoutingNumber: achRoutingNumber ?? this.achRoutingNumber,
      achAccountNumber: achAccountNumber ?? this.achAccountNumber,
      applePayEmail: applePayEmail ?? this.applePayEmail,
      googlePayEmail: googlePayEmail ?? this.googlePayEmail,
    );
  }

  static CompanyBillingDraft empty() {
    return const CompanyBillingDraft(
      method: 'Credit/Debit Card',
      saveForFutureUse: false,
    );
  }
}

class CompanyAddressesDraft {
  final String billingStreet;
  final String billingCity;
  final String billingState;
  final String billingZip;
  final String billingCountry;
  final bool shippingSameAsBilling;
  final String shippingStreet;
  final String shippingCity;
  final String shippingState;
  final String shippingZip;
  final String shippingCountry;

  const CompanyAddressesDraft({
    required this.billingStreet,
    required this.billingCity,
    required this.billingState,
    required this.billingZip,
    required this.billingCountry,
    required this.shippingSameAsBilling,
    this.shippingStreet = '',
    this.shippingCity = '',
    this.shippingState = '',
    this.shippingZip = '',
    this.shippingCountry = '',
  });

  CompanyAddressesDraft copyWith({
    String? billingStreet,
    String? billingCity,
    String? billingState,
    String? billingZip,
    String? billingCountry,
    bool? shippingSameAsBilling,
    String? shippingStreet,
    String? shippingCity,
    String? shippingState,
    String? shippingZip,
    String? shippingCountry,
  }) {
    return CompanyAddressesDraft(
      billingStreet: billingStreet ?? this.billingStreet,
      billingCity: billingCity ?? this.billingCity,
      billingState: billingState ?? this.billingState,
      billingZip: billingZip ?? this.billingZip,
      billingCountry: billingCountry ?? this.billingCountry,
      shippingSameAsBilling:
          shippingSameAsBilling ?? this.shippingSameAsBilling,
      shippingStreet: shippingStreet ?? this.shippingStreet,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingState: shippingState ?? this.shippingState,
      shippingZip: shippingZip ?? this.shippingZip,
      shippingCountry: shippingCountry ?? this.shippingCountry,
    );
  }

  static CompanyAddressesDraft empty() {
    return const CompanyAddressesDraft(
      billingStreet: '',
      billingCity: '',
      billingState: '',
      billingZip: '',
      billingCountry: '',
      shippingSameAsBilling: true,
    );
  }
}

class EditCompanyBillingPopup extends StatefulWidget {
  const EditCompanyBillingPopup({super.key, required this.initial});
  final CompanyBillingDraft initial;

  @override
  State<EditCompanyBillingPopup> createState() =>
      _EditCompanyBillingPopupState();
}

class _EditCompanyBillingPopupState extends State<EditCompanyBillingPopup> {
  final ScrollController _scrollController = ScrollController();

  late String _method;
  late bool _saveForFutureUse;

  late final TextEditingController _nameOnCardCtrl;
  late final TextEditingController _cardNumberCtrl;
  late final TextEditingController _expiryCtrl;
  late final TextEditingController _cvvCtrl;
  late final TextEditingController _achAccountNameCtrl;
  late final TextEditingController _achRoutingCtrl;
  late final TextEditingController _achAccountCtrl;
  late final TextEditingController _applePayEmailCtrl;
  late final TextEditingController _googlePayEmailCtrl;

  final FocusNode _nameOnCardFocusNode = FocusNode(
    debugLabel: 'billingNameOnCard',
  );
  final FocusNode _cardNumberFocusNode = FocusNode(
    debugLabel: 'billingCardNumber',
  );
  final FocusNode _expiryFocusNode = FocusNode(debugLabel: 'billingExpiry');
  final FocusNode _cvvFocusNode = FocusNode(debugLabel: 'billingCvv');
  final FocusNode _achAccountNameFocusNode = FocusNode(
    debugLabel: 'billingAchAccountHolderName',
  );
  final FocusNode _achRoutingFocusNode = FocusNode(
    debugLabel: 'billingAchRoutingNumber',
  );
  final FocusNode _achAccountFocusNode = FocusNode(
    debugLabel: 'billingAchAccountNumber',
  );
  final FocusNode _applePayEmailFocusNode = FocusNode(
    debugLabel: 'billingApplePayEmail',
  );
  final FocusNode _googlePayEmailFocusNode = FocusNode(
    debugLabel: 'billingGooglePayEmail',
  );

  final GlobalKey _nameOnCardKey = GlobalKey(
    debugLabel: 'billingNameOnCardA11y',
  );
  final GlobalKey _cardNumberKey = GlobalKey(
    debugLabel: 'billingCardNumberA11y',
  );
  final GlobalKey _expiryKey = GlobalKey(debugLabel: 'billingExpiryA11y');
  final GlobalKey _cvvKey = GlobalKey(debugLabel: 'billingCvvA11y');
  final GlobalKey _achAccountNameKey = GlobalKey(
    debugLabel: 'billingAchAccountHolderNameA11y',
  );
  final GlobalKey _achRoutingKey = GlobalKey(
    debugLabel: 'billingAchRoutingNumberA11y',
  );
  final GlobalKey _achAccountKey = GlobalKey(
    debugLabel: 'billingAchAccountNumberA11y',
  );
  final GlobalKey _applePayEmailKey = GlobalKey(
    debugLabel: 'billingApplePayEmailA11y',
  );
  final GlobalKey _googlePayEmailKey = GlobalKey(
    debugLabel: 'billingGooglePayEmailA11y',
  );

  static const List<String> _methods = [
    'Credit/Debit Card',
    'ACH Transfer',
    'Apple Pay',
    'Google Pay',
  ];

  @override
  void initState() {
    super.initState();
    _method = _methods.contains(widget.initial.method)
        ? widget.initial.method
        : _methods.first;
    _saveForFutureUse = widget.initial.saveForFutureUse;
    _nameOnCardCtrl = TextEditingController(text: widget.initial.nameOnCard);
    _cardNumberCtrl = TextEditingController(text: widget.initial.cardNumber);
    _expiryCtrl = TextEditingController(text: widget.initial.expiry);
    _cvvCtrl = TextEditingController(text: widget.initial.cvv);
    _achAccountNameCtrl = TextEditingController(
      text: widget.initial.achAccountName,
    );
    _achRoutingCtrl = TextEditingController(
      text: widget.initial.achRoutingNumber,
    );
    _achAccountCtrl = TextEditingController(
      text: widget.initial.achAccountNumber,
    );
    _applePayEmailCtrl = TextEditingController(
      text: widget.initial.applePayEmail,
    );
    _googlePayEmailCtrl = TextEditingController(
      text: widget.initial.googlePayEmail,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameOnCardCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _achAccountNameCtrl.dispose();
    _achRoutingCtrl.dispose();
    _achAccountCtrl.dispose();
    _applePayEmailCtrl.dispose();
    _googlePayEmailCtrl.dispose();

    _nameOnCardFocusNode.dispose();
    _cardNumberFocusNode.dispose();
    _expiryFocusNode.dispose();
    _cvvFocusNode.dispose();
    _achAccountNameFocusNode.dispose();
    _achRoutingFocusNode.dispose();
    _achAccountFocusNode.dispose();
    _applePayEmailFocusNode.dispose();
    _googlePayEmailFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12,
        color: Colors.black.withValues(alpha: 0.35),
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.snow,
      constraints: const BoxConstraints(minHeight: 52),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }

  String _digitsForSpeech(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return raw.trim();
    return digits.split('').join(' ');
  }

  String _expiryForSpeech(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(ch);
      } else if (ch == '/') {
        buffer.write(' slash');
      } else if (ch.trim().isNotEmpty) {
        buffer.write(' $ch');
      }
    }
    return buffer.toString().trim();
  }

  Widget _billingField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required GlobalKey semanticKey,
    TextInputType? keyboardType,
    bool speakDigits = false,
    bool speakExpiry = false,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final raw = value.text.trim();
        final spokenValue = raw.isEmpty
            ? 'Not entered'
            : speakDigits
            ? _digitsForSpeech(raw)
            : speakExpiry
            ? _expiryForSpeech(raw)
            : raw;

        return Semantics(
          key: semanticKey,
          container: true,
          textField: true,
          isRequired: true,
          label: label,
          value: spokenValue,
          hint: 'Double tap to edit.',
          onTap: () => FocusScope.of(context).requestFocus(focusNode),
          child: ExcludeSemantics(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 11),
              decoration: _dec(label),
            ),
          ),
        );
      },
    );
  }

  void _selectMethod(String method) {
    if (_method == method) return;
    setState(() => _method = method);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '$method selected',
      Directionality.of(context),
    );
  }

  Future<void> _focusInvalidField({
    required GlobalKey semanticKey,
    required FocusNode focusNode,
    required String announcement,
  }) async {
    FocusScope.of(context).requestFocus(focusNode);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    semanticKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement,
      Directionality.of(context),
    );
  }

  bool _validate() {
    if (_method == 'Credit/Debit Card') {
      if (_nameOnCardCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _nameOnCardKey,
            focusNode: _nameOnCardFocusNode,
            announcement: 'Name on Card is required.',
          ),
        );
        return false;
      }
      if (_cardNumberCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _cardNumberKey,
            focusNode: _cardNumberFocusNode,
            announcement: 'Card Number is required.',
          ),
        );
        return false;
      }
      if (_expiryCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _expiryKey,
            focusNode: _expiryFocusNode,
            announcement: 'Expiry date is required.',
          ),
        );
        return false;
      }
      if (_cvvCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _cvvKey,
            focusNode: _cvvFocusNode,
            announcement: 'CVV is required.',
          ),
        );
        return false;
      }
    } else if (_method == 'ACH Transfer') {
      if (_achAccountNameCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _achAccountNameKey,
            focusNode: _achAccountNameFocusNode,
            announcement: 'Account Holder Name is required.',
          ),
        );
        return false;
      }
      if (_achRoutingCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _achRoutingKey,
            focusNode: _achRoutingFocusNode,
            announcement: 'Routing Number is required.',
          ),
        );
        return false;
      }
      if (_achAccountCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _achAccountKey,
            focusNode: _achAccountFocusNode,
            announcement: 'Account Number is required.',
          ),
        );
        return false;
      }
    } else if (_method == 'Apple Pay') {
      if (_applePayEmailCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _applePayEmailKey,
            focusNode: _applePayEmailFocusNode,
            announcement: 'Apple Pay Email is required.',
          ),
        );
        return false;
      }
    } else if (_method == 'Google Pay') {
      if (_googlePayEmailCtrl.text.trim().isEmpty) {
        unawaited(
          _focusInvalidField(
            semanticKey: _googlePayEmailKey,
            focusNode: _googlePayEmailFocusNode,
            announcement: 'Google Pay Email is required.',
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _save() {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete required billing fields.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      widget.initial.copyWith(
        method: _method,
        saveForFutureUse: _saveForFutureUse,
        nameOnCard: _nameOnCardCtrl.text.trim(),
        cardNumber: _cardNumberCtrl.text.trim(),
        expiry: _expiryCtrl.text.trim(),
        cvv: _cvvCtrl.text.trim(),
        achAccountName: _achAccountNameCtrl.text.trim(),
        achRoutingNumber: _achRoutingCtrl.text.trim(),
        achAccountNumber: _achAccountCtrl.text.trim(),
        applePayEmail: _applePayEmailCtrl.text.trim(),
        googlePayEmail: _googlePayEmailCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CompanyPopupScaffold(
      title: 'Billing',
      subtitle: 'Select payment method and update details.',
      scrollController: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 6),
          RadioGroup<String>(
            groupValue: _method,
            onChanged: (value) {
              if (value == null) return;
              _selectMethod(value);
            },
            child: Column(
              children: _methods.map((method) {
                final selected = _method == method;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        button: true,
                        selected: selected,
                        label: '$method payment method',
                        hint: selected
                            ? 'Selected.'
                            : 'Double tap to select $method.',
                        onTap: () => _selectMethod(method),
                        child: ExcludeSemantics(
                          child: InkWell(
                            onTap: () => _selectMethod(method),
                            borderRadius: BorderRadius.zero,
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: method,
                                  activeColor: AppColors.blackCat,
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
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 8),
                        if (method == 'Credit/Debit Card') ...[
                          _billingField(
                            label: 'Name on Card',
                            controller: _nameOnCardCtrl,
                            focusNode: _nameOnCardFocusNode,
                            semanticKey: _nameOnCardKey,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 8),
                          _billingField(
                            label: 'Card Number',
                            controller: _cardNumberCtrl,
                            focusNode: _cardNumberFocusNode,
                            semanticKey: _cardNumberKey,
                            keyboardType: TextInputType.number,
                            speakDigits: true,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _billingField(
                                  label: 'Expiry MM slash YY',
                                  controller: _expiryCtrl,
                                  focusNode: _expiryFocusNode,
                                  semanticKey: _expiryKey,
                                  keyboardType: TextInputType.number,
                                  speakExpiry: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _billingField(
                                  label: 'CVV',
                                  controller: _cvvCtrl,
                                  focusNode: _cvvFocusNode,
                                  semanticKey: _cvvKey,
                                  keyboardType: TextInputType.number,
                                  speakDigits: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (method == 'ACH Transfer') ...[
                          _billingField(
                            label: 'Account Holder Name',
                            controller: _achAccountNameCtrl,
                            focusNode: _achAccountNameFocusNode,
                            semanticKey: _achAccountNameKey,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 8),
                          _billingField(
                            label: 'Routing Number',
                            controller: _achRoutingCtrl,
                            focusNode: _achRoutingFocusNode,
                            semanticKey: _achRoutingKey,
                            keyboardType: TextInputType.number,
                            speakDigits: true,
                          ),
                          const SizedBox(height: 8),
                          _billingField(
                            label: 'Account Number',
                            controller: _achAccountCtrl,
                            focusNode: _achAccountFocusNode,
                            semanticKey: _achAccountKey,
                            keyboardType: TextInputType.number,
                            speakDigits: true,
                          ),
                        ],
                        if (method == 'Apple Pay')
                          _billingField(
                            label: 'Apple Pay Email',
                            controller: _applePayEmailCtrl,
                            focusNode: _applePayEmailFocusNode,
                            semanticKey: _applePayEmailKey,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        if (method == 'Google Pay')
                          _billingField(
                            label: 'Google Pay Email',
                            controller: _googlePayEmailCtrl,
                            focusNode: _googlePayEmailFocusNode,
                            semanticKey: _googlePayEmailKey,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Semantics(
            button: true,
            label:
                'Save for future use toggle, ${_saveForFutureUse ? 'on' : 'off'}',
            hint: 'Double tap to toggle.',
            onTap: () {
              setState(() => _saveForFutureUse = !_saveForFutureUse);
              SemanticsService.sendAnnouncement(
                View.of(context),
                'Save for future use toggle ${_saveForFutureUse ? 'on' : 'off'}',
                Directionality.of(context),
              );
            },
            child: ExcludeSemantics(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _saveForFutureUse,
                onChanged: (value) {
                  final next = value ?? false;
                  setState(() => _saveForFutureUse = next);
                  SemanticsService.sendAnnouncement(
                    View.of(context),
                    'Save for future use toggle ${next ? 'on' : 'off'}',
                    Directionality.of(context),
                  );
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.blackCat,
                title: const Text(
                  'Save for future use',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PopupActions(onSave: _save),
        ],
      ),
    );
  }
}
class EditCompanyAddressesPopup extends StatefulWidget {
  const EditCompanyAddressesPopup({super.key, required this.initial});
  final CompanyAddressesDraft initial;

  @override
  State<EditCompanyAddressesPopup> createState() =>
      _EditCompanyAddressesPopupState();
}

class _EditCompanyAddressesPopupState extends State<EditCompanyAddressesPopup> {
  final ScrollController _scrollController = ScrollController();

  late final TextEditingController _billingStreetCtrl;
  late final TextEditingController _billingCityCtrl;
  late final TextEditingController _billingStateCtrl;
  late final TextEditingController _billingZipCtrl;
  late final TextEditingController _billingCountryCtrl;
  late bool _shippingSameAsBilling;
  late final TextEditingController _shippingStreetCtrl;
  late final TextEditingController _shippingCityCtrl;
  late final TextEditingController _shippingStateCtrl;
  late final TextEditingController _shippingZipCtrl;
  late final TextEditingController _shippingCountryCtrl;

  final FocusNode _billingStreetFocusNode = FocusNode(
    debugLabel: 'billingStreetAddress',
  );
  final FocusNode _billingCityFocusNode = FocusNode(
    debugLabel: 'billingCity',
  );
  final FocusNode _billingZipFocusNode = FocusNode(
    debugLabel: 'billingZip',
  );
  final FocusNode _shippingStreetFocusNode = FocusNode(
    debugLabel: 'shippingStreetAddress',
  );
  final FocusNode _shippingCityFocusNode = FocusNode(
    debugLabel: 'shippingCity',
  );
  final FocusNode _shippingZipFocusNode = FocusNode(
    debugLabel: 'shippingZip',
  );

  final GlobalKey _billingStreetKey = GlobalKey(
    debugLabel: 'billingStreetAddressA11y',
  );
  final GlobalKey _billingCityKey = GlobalKey(
    debugLabel: 'billingCityA11y',
  );
  final GlobalKey _billingStateKey = GlobalKey(
    debugLabel: 'billingStateA11y',
  );
  final GlobalKey _billingZipKey = GlobalKey(
    debugLabel: 'billingZipA11y',
  );
  final GlobalKey _billingCountryKey = GlobalKey(
    debugLabel: 'billingCountryA11y',
  );
  final GlobalKey _shippingStreetKey = GlobalKey(
    debugLabel: 'shippingStreetAddressA11y',
  );
  final GlobalKey _shippingCityKey = GlobalKey(
    debugLabel: 'shippingCityA11y',
  );
  final GlobalKey _shippingStateKey = GlobalKey(
    debugLabel: 'shippingStateA11y',
  );
  final GlobalKey _shippingZipKey = GlobalKey(
    debugLabel: 'shippingZipA11y',
  );
  final GlobalKey _shippingCountryKey = GlobalKey(
    debugLabel: 'shippingCountryA11y',
  );

  @override
  void initState() {
    super.initState();
    _billingStreetCtrl = TextEditingController(
      text: widget.initial.billingStreet,
    );
    _billingCityCtrl = TextEditingController(text: widget.initial.billingCity);
    _billingStateCtrl = TextEditingController(
      text: widget.initial.billingState,
    );
    _billingZipCtrl = TextEditingController(text: widget.initial.billingZip);
    _billingCountryCtrl = TextEditingController(
      text: widget.initial.billingCountry,
    );
    _shippingSameAsBilling = widget.initial.shippingSameAsBilling;
    _shippingStreetCtrl = TextEditingController(
      text: widget.initial.shippingStreet,
    );
    _shippingCityCtrl = TextEditingController(
      text: widget.initial.shippingCity,
    );
    _shippingStateCtrl = TextEditingController(
      text: widget.initial.shippingState,
    );
    _shippingZipCtrl = TextEditingController(text: widget.initial.shippingZip);
    _shippingCountryCtrl = TextEditingController(
      text: widget.initial.shippingCountry,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _billingStreetCtrl.dispose();
    _billingCityCtrl.dispose();
    _billingStateCtrl.dispose();
    _billingZipCtrl.dispose();
    _billingCountryCtrl.dispose();
    _shippingStreetCtrl.dispose();
    _shippingCityCtrl.dispose();
    _shippingStateCtrl.dispose();
    _shippingZipCtrl.dispose();
    _shippingCountryCtrl.dispose();

    _billingStreetFocusNode.dispose();
    _billingCityFocusNode.dispose();
    _billingZipFocusNode.dispose();
    _shippingStreetFocusNode.dispose();
    _shippingCityFocusNode.dispose();
    _shippingZipFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _addressDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.snow,
      constraints: const BoxConstraints(minHeight: 52),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }

  Widget _addressTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required GlobalKey semanticKey,
    TextInputType? keyboardType,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final currentValue = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              key: semanticKey,
              container: true,
              textField: true,
              isRequired: true,
              label: label,
              value: currentValue.isEmpty ? 'Not entered' : currentValue,
              hint: 'Double tap to edit.',
              onTap: () => FocusScope.of(context).requestFocus(focusNode),
              child: ExcludeSemantics(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(fontSize: 11),
                  keyboardType: keyboardType,
                  decoration: _addressDecoration(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreAccessibilityFocus(GlobalKey semanticKey) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    semanticKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  Future<void> _showAccessibleChoicePicker({
    required String title,
    required List<String> items,
    required String currentValue,
    required GlobalKey returnFocusKey,
    required ValueChanged<String> onSelected,
  }) async {
    final searchController = TextEditingController();
    final closeFocusNode = FocusNode(debugLabel: '${title}PickerClose');
    final closeKey = GlobalKey(debugLabel: '${title}PickerCloseA11y');
    var query = '';
    var initialFocusSent = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? items
                : items
                      .where(
                        (item) => item.toLowerCase().contains(normalizedQuery),
                      )
                      .toList();

            if (!initialFocusSent) {
              initialFocusSent = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!sheetContext.mounted) return;
                FocusScope.of(sheetContext).requestFocus(closeFocusNode);
                await WidgetsBinding.instance.endOfFrame;
                if (!sheetContext.mounted) return;
                closeKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
                  const FocusSemanticEvent(),
                );
              });
            }

            return Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Select $title',
              child: SafeArea(
                child: Container(
                  height: MediaQuery.of(sheetContext).size.height * 0.72,
                  decoration: const BoxDecoration(
                    color: AppColors.snow,
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Select $title',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blackCat,
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            key: closeKey,
                            button: true,
                            label: 'Close $title selector',
                            hint: 'Double tap to close.',
                            onTap: () => Navigator.pop(sheetContext),
                            child: ExcludeSemantics(
                              child: IconButton(
                                focusNode: closeFocusNode,
                                tooltip: 'Close $title selector',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        textField: true,
                        label: 'Search $title',
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search $title',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onChanged: (value) {
                            setSheetState(() => query = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Semantics(
                                label: 'No matching $title options',
                                child: Center(
                                  child: Text('No matching $title options'),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final selected = item == currentValue;
                                  return Semantics(
                                    button: true,
                                    selected: selected,
                                    label: item,
                                    hint: selected
                                        ? 'Currently selected. Double tap to keep this selection.'
                                        : 'Double tap to select.',
                                    onTap: () {
                                      onSelected(item);
                                      Navigator.pop(sheetContext);
                                    },
                                    child: ExcludeSemantics(
                                      child: ListTile(
                                        title: Text(item),
                                        trailing: selected
                                            ? const Icon(Icons.check_rounded)
                                            : null,
                                        onTap: () {
                                          onSelected(item);
                                          Navigator.pop(sheetContext);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    closeFocusNode.dispose();
    await _restoreAccessibilityFocus(returnFocusKey);
  }

  Widget _accessibleDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required GlobalKey semanticKey,
  }) {
    final value = controller.text.trim();

    void updateValue(String selected) {
      if (!mounted) return;
      setState(() => controller.text = selected);
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$label selected $selected',
        Directionality.of(context),
      );
    }

    return Semantics(
      key: semanticKey,
      container: true,
      button: true,
      isRequired: true,
      label: label,
      value: value.isEmpty ? 'Not selected' : value,
      hint: 'Double tap to select $label.',
      onTap: () => _showAccessibleChoicePicker(
        title: label,
        items: items,
        currentValue: value,
        returnFocusKey: semanticKey,
        onSelected: updateValue,
      ),
      child: ExcludeSemantics(
        child: SearchableDropdownField(
          label: label,
          value: value.isEmpty ? null : value,
          items: items,
          fillColor: AppColors.snow,
          borderColor: AppColors.blackCatBorderLight,
          onChanged: updateValue,
        ),
      ),
    );
  }

  void _setShippingSameAsBilling(bool value) {
    setState(() => _shippingSameAsBilling = value);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Shipping address same as billing address toggle ${value ? 'on' : 'off'}',
      Directionality.of(context),
    );
  }

  Widget _shippingSameAsBillingToggle() {
    return Semantics(
      container: true,
      button: true,
      label:
          'Shipping address same as billing address toggle, ${_shippingSameAsBilling ? 'on' : 'off'}',
      hint: _shippingSameAsBilling
          ? 'Double tap to enter a different shipping address.'
          : 'Double tap to use the billing address for shipping.',
      onTap: () => _setShippingSameAsBilling(!_shippingSameAsBilling),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Is shipping address same as billing address',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: _shippingSameAsBilling,
                activeThumbColor: AppColors.blackCat,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withValues(
                  alpha: 0.35,
                ),
                onChanged: _setShippingSameAsBilling,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _focusTextField({
    required GlobalKey semanticKey,
    required FocusNode focusNode,
    required String announcement,
  }) async {
    final fieldContext = semanticKey.currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.25,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    FocusScope.of(context).requestFocus(focusNode);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    semanticKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement,
      Directionality.of(context),
    );
  }

  Future<void> _focusSemanticControl({
    required GlobalKey semanticKey,
    required String announcement,
  }) async {
    final fieldContext = semanticKey.currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.25,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    semanticKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement,
      Directionality.of(context),
    );
  }

  bool _validate() {
    if (_billingStreetCtrl.text.trim().isEmpty) {
      unawaited(
        _focusTextField(
          semanticKey: _billingStreetKey,
          focusNode: _billingStreetFocusNode,
          announcement: 'Billing Street Address is required.',
        ),
      );
      return false;
    }
    if (_billingCityCtrl.text.trim().isEmpty) {
      unawaited(
        _focusTextField(
          semanticKey: _billingCityKey,
          focusNode: _billingCityFocusNode,
          announcement: 'Billing City is required.',
        ),
      );
      return false;
    }
    if (_billingStateCtrl.text.trim().isEmpty) {
      unawaited(
        _focusSemanticControl(
          semanticKey: _billingStateKey,
          announcement: 'Billing State is required.',
        ),
      );
      return false;
    }
    if (_billingZipCtrl.text.trim().isEmpty) {
      unawaited(
        _focusTextField(
          semanticKey: _billingZipKey,
          focusNode: _billingZipFocusNode,
          announcement: 'Billing Zip is required.',
        ),
      );
      return false;
    }
    if (_billingCountryCtrl.text.trim().isEmpty) {
      unawaited(
        _focusSemanticControl(
          semanticKey: _billingCountryKey,
          announcement: 'Billing Country is required.',
        ),
      );
      return false;
    }

    if (!_shippingSameAsBilling) {
      if (_shippingStreetCtrl.text.trim().isEmpty) {
        unawaited(
          _focusTextField(
            semanticKey: _shippingStreetKey,
            focusNode: _shippingStreetFocusNode,
            announcement: 'Shipping Street Address is required.',
          ),
        );
        return false;
      }
      if (_shippingCityCtrl.text.trim().isEmpty) {
        unawaited(
          _focusTextField(
            semanticKey: _shippingCityKey,
            focusNode: _shippingCityFocusNode,
            announcement: 'Shipping City is required.',
          ),
        );
        return false;
      }
      if (_shippingStateCtrl.text.trim().isEmpty) {
        unawaited(
          _focusSemanticControl(
            semanticKey: _shippingStateKey,
            announcement: 'Shipping State is required.',
          ),
        );
        return false;
      }
      if (_shippingZipCtrl.text.trim().isEmpty) {
        unawaited(
          _focusTextField(
            semanticKey: _shippingZipKey,
            focusNode: _shippingZipFocusNode,
            announcement: 'Shipping Zip is required.',
          ),
        );
        return false;
      }
      if (_shippingCountryCtrl.text.trim().isEmpty) {
        unawaited(
          _focusSemanticControl(
            semanticKey: _shippingCountryKey,
            announcement: 'Shipping Country is required.',
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _save() {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete address fields.')),
      );
      return;
    }

    Navigator.pop(
      context,
      widget.initial.copyWith(
        billingStreet: _billingStreetCtrl.text.trim(),
        billingCity: _billingCityCtrl.text.trim(),
        billingState: _billingStateCtrl.text.trim(),
        billingZip: _billingZipCtrl.text.trim(),
        billingCountry: _billingCountryCtrl.text.trim(),
        shippingSameAsBilling: _shippingSameAsBilling,
        shippingStreet: _shippingStreetCtrl.text.trim(),
        shippingCity: _shippingCityCtrl.text.trim(),
        shippingState: _shippingStateCtrl.text.trim(),
        shippingZip: _shippingZipCtrl.text.trim(),
        shippingCountry: _shippingCountryCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CompanyPopupScaffold(
      title: 'Addresses',
      subtitle: 'Update billing and shipping addresses.',
      scrollController: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Billing Address',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _addressTextField(
            label: 'Billing Street Address',
            controller: _billingStreetCtrl,
            focusNode: _billingStreetFocusNode,
            semanticKey: _billingStreetKey,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: 8),
          _addressTextField(
            label: 'Billing City',
            controller: _billingCityCtrl,
            focusNode: _billingCityFocusNode,
            semanticKey: _billingCityKey,
          ),
          const SizedBox(height: 8),
          _accessibleDropdown(
            label: 'Billing State',
            controller: _billingStateCtrl,
            items: usStates,
            semanticKey: _billingStateKey,
          ),
          const SizedBox(height: 8),
          _addressTextField(
            label: 'Billing Zip',
            controller: _billingZipCtrl,
            focusNode: _billingZipFocusNode,
            semanticKey: _billingZipKey,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          _accessibleDropdown(
            label: 'Billing Country',
            controller: _billingCountryCtrl,
            items: countries,
            semanticKey: _billingCountryKey,
          ),
          const SizedBox(height: 12),
          _shippingSameAsBillingToggle(),
          if (!_shippingSameAsBilling) ...[
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: const Text(
                'Shipping Address',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            _addressTextField(
              label: 'Shipping Street Address',
              controller: _shippingStreetCtrl,
              focusNode: _shippingStreetFocusNode,
              semanticKey: _shippingStreetKey,
              keyboardType: TextInputType.streetAddress,
            ),
            const SizedBox(height: 8),
            _addressTextField(
              label: 'Shipping City',
              controller: _shippingCityCtrl,
              focusNode: _shippingCityFocusNode,
              semanticKey: _shippingCityKey,
            ),
            const SizedBox(height: 8),
            _accessibleDropdown(
              label: 'Shipping State',
              controller: _shippingStateCtrl,
              items: usStates,
              semanticKey: _shippingStateKey,
            ),
            const SizedBox(height: 8),
            _addressTextField(
              label: 'Shipping Zip',
              controller: _shippingZipCtrl,
              focusNode: _shippingZipFocusNode,
              semanticKey: _shippingZipKey,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            _accessibleDropdown(
              label: 'Shipping Country',
              controller: _shippingCountryCtrl,
              items: countries,
              semanticKey: _shippingCountryKey,
            ),
          ],
          const SizedBox(height: 12),
          _PopupActions(onSave: _save),
        ],
      ),
    );
  }
}


class _CompanyPopupScaffold extends StatefulWidget {
  const _CompanyPopupScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.scrollController,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final ScrollController scrollController;

  @override
  State<_CompanyPopupScaffold> createState() => _CompanyPopupScaffoldState();
}

class _CompanyPopupScaffoldState extends State<_CompanyPopupScaffold> {
  final FocusNode _closeButtonFocusNode = FocusNode(
    debugLabel: 'popupCloseButton',
  );
  final GlobalKey _closeButtonKey = GlobalKey(
    debugLabel: 'popupCloseButtonA11yKey',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.scrollController.hasClients) {
        widget.scrollController.jumpTo(
          widget.scrollController.position.minScrollExtent,
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _focusRealClose();
    });
  }

  @override
  void dispose() {
    _closeButtonFocusNode.dispose();
    super.dispose();
  }

  void _focusRealClose() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_closeButtonFocusNode);
    _closeButtonKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  Future<void> _returnToRealClose() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (widget.scrollController.hasClients) {
      final position = widget.scrollController.position;
      final top = position.minScrollExtent;
      await widget.scrollController.animateTo(
        top,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      if (widget.scrollController.hasClients) {
        widget.scrollController.jumpTo(
          widget.scrollController.position.minScrollExtent,
        );
      }
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final closeContext = _closeButtonKey.currentContext;
    if (closeContext != null) {
      await Scrollable.ensureVisible(
        closeContext,
        alignment: 0,
        duration: Duration.zero,
      );
    }
    if (!mounted) return;
    _focusRealClose();

    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _focusRealClose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final subtitle = widget.subtitle;
    final child = widget.child;
    final scrollController = widget.scrollController;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: title,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.25),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.snow,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: keyboardInset > 0 ? 12 : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ),
                            ),
                            Semantics(
                              key: _closeButtonKey,
                              sortKey: OrdinalSortKey(0),
                              button: true,
                              label: 'Close $title',
                              hint: 'Double tap to close.',
                              onTap: () => Navigator.pop(context),
                              child: ExcludeSemantics(
                                child: IconButton(
                                  focusNode: _closeButtonFocusNode,
                                  tooltip: 'Close $title',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Semantics(
                          container: true,
                          explicitChildNodes: true,
                          sortKey: OrdinalSortKey(1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                label: '$title. $subtitle',
                                child: ExcludeSemantics(
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.blackCat,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              child,
                            ],
                          ),
                        ),
                        Semantics(
                          sortKey: OrdinalSortKey(2),
                          container: true,
                          button: true,
                          label: 'Close $title',
                          hint: 'Returns to the Close button at the top.',
                          onTap: () => Navigator.pop(context),
                          onDidGainAccessibilityFocus: () {
                            unawaited(_returnToRealClose());
                          },
                          child: const SizedBox(height: 1, width: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _PopupActions extends StatelessWidget {
  const _PopupActions({required this.onSave});
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 52,
          width: 180,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blackCat,
              foregroundColor: AppColors.snow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: onSave,
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
