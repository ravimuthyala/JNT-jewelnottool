import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
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
  String _profileImageUrl = '';
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _businessInfo =
        widget.initialBusinessInfo ?? CompanyBusinessInfoDraft.empty();
    _billingInfo = widget.initialBillingInfo ?? CompanyBillingDraft.empty();
    _addressInfo = widget.initialAddressesInfo ?? CompanyAddressesDraft.empty();
    _profileImageUrl = widget.profileImageUrl.trim();
    unawaited(_hydrateProfileImageUrl());
  }

  @override
  void didUpdateWidget(covariant CompanyProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBusinessInfo != oldWidget.initialBusinessInfo &&
        widget.initialBusinessInfo != null) {
      _businessInfo = widget.initialBusinessInfo!;
    }
    if (widget.initialBillingInfo != oldWidget.initialBillingInfo &&
        widget.initialBillingInfo != null) {
      _billingInfo = widget.initialBillingInfo!;
    }
    if (widget.initialAddressesInfo != oldWidget.initialAddressesInfo &&
        widget.initialAddressesInfo != null) {
      _addressInfo = widget.initialAddressesInfo!;
    }
    if (widget.profileImageUrl.trim() != oldWidget.profileImageUrl.trim()) {
      _profileImageUrl = widget.profileImageUrl.trim();
    }
  }

  Future<void> _editBusinessInfo() async {
    final updated = await showModalBottomSheet<CompanyBusinessInfoDraft>(
      context: context,
      isScrollControlled: true,
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
      setState(() => _businessInfo = updated);
    }
  }

  Future<void> _editBilling() async {
    final updated = await showModalBottomSheet<CompanyBillingDraft>(
      context: context,
      isScrollControlled: true,
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
      setState(() => _billingInfo = updated);
    }
  }

  Future<void> _persistBillingInfo(CompanyBillingDraft billing) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Missing signed-in user.');
    }

    await FirebaseFirestore.instance.collection('company').doc(uid).set({
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
      'panel_billingMethod': billing.method,
      'panel_billingSaveForFutureUse': billing.saveForFutureUse,
      'panel_billingNameOnCard': billing.nameOnCard,
      'panel_billingExpiry': billing.expiry,
      'panel_billingApplePayEmail': billing.applePayEmail,
      'panel_billingGooglePayEmail': billing.googlePayEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _persistBusinessInfo(CompanyBusinessInfoDraft business) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Missing signed-in user.');
    }
    await FirebaseFirestore.instance.collection('company').doc(uid).set({
      'panel_companyName': business.companyName,
      'panel_contactName': business.contactName,
      'panel_contactEmail': business.contactEmail,
      'panel_companyPhone': business.companyPhone,
      'panel_contactPhone': business.contactPhone,
      'panel_companyWebsite': business.companyUrl,
      'panel_businessType': business.businessType,
      'company': {
        'name': business.companyName,
        'contactName': business.contactName,
        'contactEmail': business.contactEmail,
        'phone': business.companyPhone,
        'contactPhone': business.contactPhone,
        'website': business.companyUrl,
        'businessType': business.businessType,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _editAddresses() async {
    final updated = await showModalBottomSheet<CompanyAddressesDraft>(
      context: context,
      isScrollControlled: true,
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
      setState(() => _addressInfo = updated);
    }
  }

  Future<void> _persistAddressesInfo(CompanyAddressesDraft addresses) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Missing signed-in user.');
    }
    await FirebaseFirestore.instance.collection('company').doc(uid).set({
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
      'panel_billingCity': addresses.billingCity,
      'panel_billingState': addresses.billingState,
      'panel_billingZip': addresses.billingZip,
      'panel_billingCountry': addresses.billingCountry,
      'panel_shippingSameAsBilling': addresses.shippingSameAsBilling,
      'panel_shippingStreet': addresses.shippingStreet,
      'panel_shippingCity': addresses.shippingCity,
      'panel_shippingState': addresses.shippingState,
      'panel_shippingZip': addresses.shippingZip,
      'panel_shippingCountry': addresses.shippingCountry,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_uploadingPhoto) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final nextUrl = await _uploadCompanyProfilePhoto(uid, bytes);
      await _persistProfilePhoto(nextUrl);
      if (!mounted) return;
      setState(() => _profileImageUrl = nextUrl);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (e) {
      if (!mounted) return;
      final msg = e is TimeoutException
          ? 'Upload timed out. Please retry with a stable connection.'
          : 'Failed to upload photo: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<String> _resolveCompanyStorageAvatar(String uid) async {
    final candidates = <String>[
      'company/$uid/profile/avatar.jpg',
      'company/$uid/profile/avatar.jpeg',
      'company/$uid/profile/avatar.png',
      'company/$uid/profile/avatar.webp',
      'company/$uid/profile/logo.jpg',
      'company/$uid/profile/logo.jpeg',
      'company/$uid/profile/logo.png',
      'company/$uid/profile/logo.webp',
    ];
    for (final path in candidates) {
      try {
        await FirebaseStorage.instance.ref(path).getMetadata();
        return path;
      } catch (_) {}
    }
    return '';
  }

  Future<void> _hydrateProfileImageUrl() async {
    if (_profileImageUrl.trim().isNotEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company')
          .doc(uid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
      final company = (data['company'] as Map<String, dynamic>?) ?? const {};
      String firstNonEmpty(List<Object?> values) {
        for (final raw in values) {
          final value = (raw ?? '').toString().trim();
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      var resolved = firstNonEmpty(<Object?>[
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
      ]);
      if (resolved.isEmpty) {
        resolved = await _resolveCompanyStorageAvatar(uid);
      }
      if (!mounted || resolved.isEmpty) return;
      setState(() => _profileImageUrl = resolved);
    } catch (_) {}
  }

  Future<String> _uploadCompanyProfilePhoto(String uid, Uint8List bytes) async {
    final ref = FirebaseStorage.instance.ref('company/$uid/profile/avatar.jpg');
    await ref
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
        .timeout(_photoUploadTimeout);
    try {
      return await ref.getDownloadURL().timeout(_photoUploadTimeout);
    } catch (_) {
      return ref.fullPath;
    }
  }

  Future<void> _persistProfilePhoto(String photoUrl) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Missing signed-in user.');
    }
    await _cleanupLegacyInlineAvatarFields(uid);
    await FirebaseFirestore.instance
        .collection('company')
        .doc(uid)
        .set({
          'panel_profileImageUrl': photoUrl,
          'panel_logoUrl': photoUrl,
          'companyLogoUrl': photoUrl,
          'brandLogoUrl': photoUrl,
          'profileImageUrl': photoUrl,
          'logoUrl': photoUrl,
          'photoUrl': photoUrl,
          'avatarUrl': photoUrl,
          'profile': {
            'profileImageUrl': photoUrl,
            'photoUrl': photoUrl,
            'avatarUrl': photoUrl,
          },
          'basic': {
            'profileImageUrl': photoUrl,
            'photoUrl': photoUrl,
            'avatarUrl': photoUrl,
          },
          'company': {
            'logoUrl': photoUrl,
            'profileImageUrl': photoUrl,
            'photoUrl': photoUrl,
            'avatarUrl': photoUrl,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(_profileSaveTimeout);
  }

  Future<void> _cleanupLegacyInlineAvatarFields(String uid) async {
    final ref = FirebaseFirestore.instance.collection('company').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final company = (data['company'] as Map<String, dynamic>?) ?? const {};

    bool inlineOrHuge(Object? value) {
      final text = (value ?? '').toString().trim();
      if (text.isEmpty) return false;
      if (text.startsWith('data:image/')) return true;
      return text.length > 180000;
    }

    final cleanup = <String, dynamic>{};
    if (inlineOrHuge(data['panel_profileImageUrl'])) {
      cleanup['panel_profileImageUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['panel_logoUrl'])) {
      cleanup['panel_logoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['companyLogoUrl'])) {
      cleanup['companyLogoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['brandLogoUrl'])) {
      cleanup['brandLogoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['profileImageUrl'])) {
      cleanup['profileImageUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['logoUrl'])) {
      cleanup['logoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['photoUrl'])) {
      cleanup['photoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(data['avatarUrl'])) {
      cleanup['avatarUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(company['profileImageUrl'])) {
      cleanup['company.profileImageUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(company['logoUrl'])) {
      cleanup['company.logoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(company['photoUrl'])) {
      cleanup['company.photoUrl'] = FieldValue.delete();
    }
    if (inlineOrHuge(company['avatarUrl'])) {
      cleanup['company.avatarUrl'] = FieldValue.delete();
    }

    if (cleanup.isNotEmpty) {
      cleanup['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(cleanup, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = _businessInfo.companyName.trim().isNotEmpty
        ? _businessInfo.companyName.trim()
        : widget.companyName;
    final contactName = _businessInfo.contactName.trim().isNotEmpty
        ? _businessInfo.contactName.trim()
        : widget.contactName;
    final email = _businessInfo.companyEmail.trim().isNotEmpty
        ? _businessInfo.companyEmail.trim()
        : (_businessInfo.contactEmail.trim().isNotEmpty
              ? _businessInfo.contactEmail.trim()
              : widget.email);
    final city = _addressInfo.billingCity.trim();
    final state = _addressInfo.billingState.trim();
    final locationText = city.isEmpty && state.isEmpty
        ? widget.locationText
        : (city.isEmpty ? state : (state.isEmpty ? city : '$city, $state'));

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: CompanyHeader(
        companyName: companyName.isEmpty ? 'Company' : companyName,
        trailing: IconButton(
          onPressed: () => widget.onClose?.call(),
          icon: const Icon(
            Icons.close_rounded,
            size: 26,
            color: AppColors.blackCat,
          ),
          splashRadius: 20,
          tooltip: 'Close',
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
                      child: _safeProfileAvatar(
                        imageUrl: _profileImageUrl,
                        displayName: companyName,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                        child: InkWell(
                          onTap: _uploadingPhoto
                              ? null
                              : _pickAndUploadProfilePhoto,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
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
          const SizedBox(height: 3),
          Center(
            child: Text(
              '${contactName.isEmpty ? 'No contact name' : contactName} • ${email.isEmpty ? 'No email on file' : email}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              locationText.isEmpty ? 'No location on file' : locationText,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(0.55),
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

          const SizedBox(height: 22),

          _TextDangerButton(text: 'Log out', onTap: widget.onLogout),
        ],
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
        size: 24,
      );
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            ClientProfileAvatarIcon(displayName: displayName, size: 24),
      );
    }
    return ClientProfileAvatarIcon(
      imageUrl: src,
      displayName: displayName,
      size: 24,
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
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
              color: Colors.black.withOpacity(0.35),
              size: 18,
            ),
          ],
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
        color: AppColors.alabaster,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
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

  static const List<String> _methods = [
    'Credit/Debit Card',
    'ACH Transfer',
    'Apple Pay',
    'Google Pay',
  ];

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method;
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
    _nameOnCardCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _achAccountNameCtrl.dispose();
    _achRoutingCtrl.dispose();
    _achAccountCtrl.dispose();
    _applePayEmailCtrl.dispose();
    _googlePayEmailCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.35)),
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

  bool _validate() {
    if (_method == 'Credit/Debit Card') {
      if (_nameOnCardCtrl.text.trim().isEmpty ||
          _cardNumberCtrl.text.trim().isEmpty ||
          _expiryCtrl.text.trim().isEmpty ||
          _cvvCtrl.text.trim().isEmpty) {
        return false;
      }
    } else if (_method == 'ACH Transfer') {
      if (_achAccountNameCtrl.text.trim().isEmpty ||
          _achRoutingCtrl.text.trim().isEmpty ||
          _achAccountCtrl.text.trim().isEmpty) {
        return false;
      }
    } else if (_method == 'Apple Pay') {
      if (_applePayEmailCtrl.text.trim().isEmpty) return false;
    } else if (_method == 'Google Pay') {
      if (_googlePayEmailCtrl.text.trim().isEmpty) return false;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._methods.map((m) {
            final selected = _method == m;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _method = m),
                    borderRadius: BorderRadius.zero,
                    child: Row(
                      children: [
                        Radio<String>(
                          value: m,
                          groupValue: _method,
                          onChanged: (v) =>
                              setState(() => _method = v ?? _method),
                          activeColor: AppColors.blackCat,
                        ),
                        Expanded(
                          child: Text(
                            m,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.black.withOpacity(0.12)),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    if (m == 'Credit/Debit Card') ...[
                      TextField(
                        controller: _nameOnCardCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Name on Card'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cardNumberCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Card Number'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _expiryCtrl,
                              style: const TextStyle(fontSize: 11),
                              decoration: _dec('Expiry MM/YY'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _cvvCtrl,
                              style: const TextStyle(fontSize: 11),
                              decoration: _dec('CVV'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (m == 'ACH Transfer') ...[
                      TextField(
                        controller: _achAccountNameCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Account Holder Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _achRoutingCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Routing Number'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _achAccountCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Account Number'),
                      ),
                    ],
                    if (m == 'Apple Pay')
                      TextField(
                        controller: _applePayEmailCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Apple Pay Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    if (m == 'Google Pay')
                      TextField(
                        controller: _googlePayEmailCtrl,
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('Google Pay Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          }),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _saveForFutureUse,
            onChanged: (v) => setState(() => _saveForFutureUse = v ?? false),
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
    super.dispose();
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.35)),
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

  bool _validate() {
    if (_billingStreetCtrl.text.trim().isEmpty ||
        _billingCityCtrl.text.trim().isEmpty ||
        _billingStateCtrl.text.trim().isEmpty ||
        _billingZipCtrl.text.trim().isEmpty ||
        _billingCountryCtrl.text.trim().isEmpty) {
      return false;
    }
    if (!_shippingSameAsBilling &&
        (_shippingStreetCtrl.text.trim().isEmpty ||
            _shippingCityCtrl.text.trim().isEmpty ||
            _shippingStateCtrl.text.trim().isEmpty ||
            _shippingZipCtrl.text.trim().isEmpty ||
            _shippingCountryCtrl.text.trim().isEmpty)) {
      return false;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Billing Address',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              TextField(
                controller: _billingStreetCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: _dec('Billing Street Address'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _billingCityCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: _dec('Billing City'),
              ),
              const SizedBox(height: 8),
              SearchableDropdownField(
                label: 'Billing State',
                value: _billingStateCtrl.text.trim().isEmpty
                    ? null
                    : _billingStateCtrl.text.trim(),
                items: usStates,
                fillColor: AppColors.snow,
                borderColor: AppColors.blackCatBorderLight,
                onChanged: (value) =>
                    setState(() => _billingStateCtrl.text = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _billingZipCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: _dec('Billing Zip'),
              ),
              const SizedBox(height: 8),
              SearchableDropdownField(
                label: 'Billing Country',
                value: _billingCountryCtrl.text.trim().isEmpty
                    ? null
                    : _billingCountryCtrl.text.trim(),
                items: countries,
                fillColor: AppColors.snow,
                borderColor: AppColors.blackCatBorderLight,
                onChanged: (value) =>
                    setState(() => _billingCountryCtrl.text = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Is shipping address same as billing address',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.75),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: _shippingSameAsBilling,
                  activeThumbColor: AppColors.blackCat,
                  inactiveThumbColor: AppColors.blackCatLight,
                  inactiveTrackColor: AppColors.blackCatLight.withOpacity(0.35),
                  onChanged: (v) => setState(() => _shippingSameAsBilling = v),
                ),
              ),
            ],
          ),
          if (!_shippingSameAsBilling) ...[
            const SizedBox(height: 10),
            const Text(
              'Shipping Address',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                TextField(
                  controller: _shippingStreetCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: _dec('Shipping Street Address'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _shippingCityCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: _dec('Shipping City'),
                ),
                const SizedBox(height: 8),
                SearchableDropdownField(
                  label: 'Shipping State',
                  value: _shippingStateCtrl.text.trim().isEmpty
                      ? null
                      : _shippingStateCtrl.text.trim(),
                  items: usStates,
                  fillColor: AppColors.snow,
                  borderColor: AppColors.blackCatBorderLight,
                  onChanged: (value) =>
                      setState(() => _shippingStateCtrl.text = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _shippingZipCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: _dec('Shipping Zip'),
                ),
                const SizedBox(height: 8),
                SearchableDropdownField(
                  label: 'Shipping Country',
                  value: _shippingCountryCtrl.text.trim().isEmpty
                      ? null
                      : _shippingCountryCtrl.text.trim(),
                  items: countries,
                  fillColor: AppColors.snow,
                  borderColor: AppColors.blackCatBorderLight,
                  onChanged: (value) =>
                      setState(() => _shippingCountryCtrl.text = value),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _PopupActions(onSave: _save),
        ],
      ),
    );
  }
}

class _CompanyPopupScaffold extends StatelessWidget {
  const _CompanyPopupScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.black.withOpacity(0.25),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.blackCat,
                      ),
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
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
