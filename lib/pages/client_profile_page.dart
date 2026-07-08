// lib/pages/client_profile_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_modal_app_bar.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';

import 'notifications_page.dart';

// Pages
import 'edit_shipping_address_page.dart';
import 'client_custom_request_page.dart';
import 'track_order_page.dart';
import 'edit_personal_info_popup.dart';
import 'edit_payment_info_popup.dart';
import 'edit_measurements_page.dart';
import 'nfc_smart_nail_profile_page.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({
    super.key,
    required this.profile,
    this.onBackHome,
    this.onOpenDesignRequest,
    this.onOpenTrackOrder,
    this.onProfileUpdated,
    this.isActiveTab = true,
    required this.onLogout,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final VoidCallback? onOpenDesignRequest;
  final VoidCallback? onOpenTrackOrder;
  final ValueChanged<ClientProfileDraft>? onProfileUpdated;
  final bool isActiveTab;
  final Future<void> Function() onLogout;

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  late ClientProfileDraft _profile;
  CommunicationPreferences _communicationPreferences =
      CommunicationPreferences.defaults();
  bool _isAmbassador = false;
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'profileNotificationsButton',
  );


  // Match ClientRegistrationPage sizing (same family you used there)

  static const double _smallFs = 13.5;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    unawaited(_loadProfileFromSupabase());
    _loadCommunicationPreferences();
    _listenAmbassadorStatus();
    if (widget.isActiveTab) {
      _requestNotificationFocus();
    }
  }

  void _requestNotificationFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted || !widget.isActiveTab) return;

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted || !widget.isActiveTab) return;

      _notificationsFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant ClientProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = widget.profile;
    }

    if (!oldWidget.isActiveTab && widget.isActiveTab) {
      _requestNotificationFocus();
    }
  }

  @override
  void dispose() {
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  void _applyProfile(ClientProfileDraft updated) {
    setState(() => _profile = updated);
    widget.onProfileUpdated?.call(updated);
  }

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

  NailLength _parseNailLength(Object? raw) {
    final value = (raw ?? '').toString().trim();
    switch (value) {
      case 'short':
        return NailLength.short;
      case 'medium':
        return NailLength.medium;
      case 'long':
        return NailLength.long;
      case 'extraLong':
        return NailLength.extraLong;
      case 'xlLong':
        return NailLength.xlLong;
      default:
        return NailLength.none;
    }
  }

  NailDimensions _parseNailDimensions(Map<String, dynamic> map) {
    double? read(String key) {
      final raw = map[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.trim());
      return null;
    }

    bool readBool(String key) {
      final raw = map[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final value = (raw ?? '').toString().trim().toLowerCase();
      return value == 'true' || value == 'yes' || value == '1';
    }

    return NailDimensions(
      lThumb: read('lThumb'),
      lIndex: read('lIndex'),
      lMiddle: read('lMiddle'),
      lRing: read('lRing'),
      lPinky: read('lPinky'),
      rThumb: read('rThumb'),
      rIndex: read('rIndex'),
      rMiddle: read('rMiddle'),
      rRing: read('rRing'),
      rPinky: read('rPinky'),
      lThumbNfc: readBool('lThumbNfc'),
      lIndexNfc: readBool('lIndexNfc'),
      lMiddleNfc: readBool('lMiddleNfc'),
      lRingNfc: readBool('lRingNfc'),
      lPinkyNfc: readBool('lPinkyNfc'),
      rThumbNfc: readBool('rThumbNfc'),
      rIndexNfc: readBool('rIndexNfc'),
      rMiddleNfc: readBool('rMiddleNfc'),
      rRingNfc: readBool('rRingNfc'),
      rPinkyNfc: readBool('rPinkyNfc'),
    );
  }

  Future<String> _targetTable() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    for (final table in const <String>['client', 'client_artist']) {
      try {
        if (uid.isNotEmpty) {
          final rows = await supabase.from(table).select('id').eq('id', uid).limit(1);
          if (rows.isNotEmpty) return table;
        }

        if (email.isNotEmpty) {
          final rows = await supabase.from(table).select('id').eq('email', email).limit(1);
          if (rows.isNotEmpty) return table;
        }
      } catch (_) {}
    }

    return 'client';
  }

  Future<Map<String, dynamic>?> _readClientRowFromSupabase() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isEmpty && email.isEmpty) return null;

    for (final table in const <String>['client', 'client_artist']) {
      try {
        if (uid.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('id', uid).limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }

        if (email.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('email', email).limit(1);
          if (rows.isNotEmpty) {
            return Map<String, dynamic>.from(rows.first as Map);
          }
        }
      } catch (e) {
        debugPrint('CLIENT PROFILE LOAD FAILED [$table]: $e');
      }
    }

    return null;
  }

  Future<void> _loadProfileFromSupabase() async {
    final data = await _readClientRowFromSupabase();
    if (data == null || !mounted) return;

    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final client = _asMap(data['client']);
    final clientProfile = _asMap(client['profile']);
    final address = _asMap(data['address']);
    final clientAddress = _asMap(client['address']);
    final nailMap = _asMap(data['nailPreferences']).isNotEmpty
        ? _asMap(data['nailPreferences'])
        : _asMap(data['nail_preferences']).isNotEmpty
        ? _asMap(data['nail_preferences'])
        : _asMap(client['nailPreferences']).isNotEmpty
        ? _asMap(client['nailPreferences'])
        : _asMap(client['nail_preferences']);
    final nextNail = nailMap.isNotEmpty
        ? NailPreferences(
            dimensions: _parseNailDimensions(_asMap(nailMap['dimensions'])),
            shape: _firstNonEmpty([nailMap['shape']]),
            length: _parseNailLength(nailMap['length']),
          )
        : _profile.nail;

    final nextBasic = _profile.basic.copyWith(
      name: _firstNonEmpty([
        basic['name'],
        profile['name'],
        clientProfile['name'],
        data['panel_displayName'],
        data['name'],
        _profile.basic.name,
      ]),
      email: _firstNonEmpty([
        basic['email'],
        data['email'],
        client['email'],
        _profile.basic.email,
      ]),
      phone: _firstNonEmpty([
        basic['phone'],
        profile['phone'],
        clientProfile['phone'],
        data['panel_phone'],
        data['phone'],
        _profile.basic.phone,
      ]),
      profileImageUrl: _firstNonEmpty([
        basic['profileImageUrl'],
        basic['photoUrl'],
        basic['avatarUrl'],
        profile['profileImageUrl'],
        profile['photoUrl'],
        profile['avatarUrl'],
        clientProfile['profileImageUrl'],
        clientProfile['photoUrl'],
        clientProfile['avatarUrl'],
        data['panel_profileImageUrl'],
        data['profileImageUrl'],
        data['photoUrl'],
        data['avatarUrl'],
        _profile.basic.profileImageUrl,
      ]),
    );

    final nextAddress = AddressInfo(
      street: _firstNonEmpty([
        address['street'],
        address['addressLine1'],
        clientAddress['street'],
        clientAddress['addressLine1'],
        data['panel_street'],
        _profile.address.street,
      ]),
      city: _firstNonEmpty([
        address['city'],
        clientAddress['city'],
        data['panel_city'],
        _profile.address.city,
      ]),
      state: _firstNonEmpty([
        address['state'],
        clientAddress['state'],
        data['panel_state'],
        _profile.address.state,
      ]),
      zip: _firstNonEmpty([
        address['zip'],
        clientAddress['zip'],
        data['panel_zip'],
        _profile.address.zip,
      ]),
      country: _firstNonEmpty([
        address['country'],
        clientAddress['country'],
        data['panel_country'],
        _profile.address.country,
      ]),
    );

    _applyProfile(
      _profile.copyWith(basic: nextBasic, address: nextAddress, nail: nextNail),
    );
  }


  Future<void> _loadCommunicationPreferences() async {
    final data = await _readClientRowFromSupabase();
    if (!mounted || data == null) return;

    final rootPrefs = _asMap(data['communicationPreferences']);
    final nestedPrefs = _asMap(_asMap(data['client'])['communicationPreferences']);
    final source = rootPrefs.isNotEmpty ? rootPrefs : nestedPrefs;
    if (source.isEmpty) return;

    setState(() {
      _communicationPreferences = CommunicationPreferences.fromMap(source);
    });
  }

  bool _docIsAmbassador(Map<String, dynamic> data) {
    String normalized(Object? value) => value.toString().trim().toLowerCase();
    bool isAmbassadorStatus(Object? raw) {
      final status = normalized(raw).replaceAll('_', ' ').replaceAll('-', ' ');
      return status == 'ambassador';
    }

    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final profileAscension =
        (profile['ascension'] as Map<String, dynamic>?) ?? const {};
    final basicAscension =
        (basic['ascension'] as Map<String, dynamic>?) ?? const {};
    final clientAscension =
        (client['ascension'] as Map<String, dynamic>?) ?? const {};

    final statusCandidates = <Object?>[
      data['status'],
      data['partnerStatus'],
      profile['status'],
      profile['partnerStatus'],
      basic['status'],
      basic['partnerStatus'],
      client['status'],
      client['partnerStatus'],
      ascension['status'],
      ascension['partnerStatus'],
      profileAscension['status'],
      profileAscension['partnerStatus'],
      basicAscension['status'],
      basicAscension['partnerStatus'],
      clientAscension['status'],
      clientAscension['partnerStatus'],
    ];

    return statusCandidates.any(isAmbassadorStatus);
  }

  Future<void> _listenAmbassadorStatus() async {
    final data = await _readClientRowFromSupabase();
    if (!mounted || data == null) return;
    setState(() => _isAmbassador = _docIsAmbassador(data));
  }

  Future<void> _saveCommunicationPreferences(
    CommunicationPreferences preferences,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    if (uid.isEmpty) return;

    final table = await _targetTable();

    await Supabase.instance.client.from(table).upsert({
      'id': uid,
      'email': (user?.email ?? _profile.basic.email).trim().toLowerCase(),
      'communicationPreferences': preferences.toMap(),
      'client': {
        'communicationPreferences': preferences.toMap(),
      },
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _editPersonalInfo() async {
    final result = await showModalBottomSheet<PersonalInfoEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPersonalInfoPopup(profile: _profile),
    );

    if (result != null) {
      final updated = result.profile;
      final selectedPhotoBytes = result.selectedPhotoBytes;
      try {
        await _persistPersonalInfo(
          previous: _profile.basic,
          next: updated.basic,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save personal information: $e')),
        );
        return;
      }
      var localUpdated = updated;
      if (selectedPhotoBytes != null && selectedPhotoBytes.isNotEmpty) {
        final previewUrl =
            'data:image/jpeg;base64,${base64Encode(selectedPhotoBytes)}';
        localUpdated = updated.copyWith(
          basic: updated.basic.copyWith(profileImageUrl: previewUrl),
        );
      }
      _applyProfile(localUpdated);
      if (selectedPhotoBytes != null && selectedPhotoBytes.isNotEmpty) {
        unawaited(_saveProfilePhotoInBackground(selectedPhotoBytes));
      }
    }
  }

  Future<void> _saveProfilePhotoInBackground(Uint8List bytes) async {
    try {
      final photoUrl = await EditPersonalInfoPopup.uploadProfilePhoto(bytes);
      final next = _profile.basic.copyWith(profileImageUrl: photoUrl);
      await _persistPersonalInfo(previous: _profile.basic, next: next);
      if (mounted) {
        _applyProfile(_profile.copyWith(basic: next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo upload failed: $e')),
      );
    }
  }

  Future<void> _persistPersonalInfo({
    required BasicInfo previous,
    required BasicInfo next,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    if (uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }

    final table = await _targetTable();
    final profileImage = next.profileImageUrl.trim();

    await Supabase.instance.client.from(table).upsert({
      'id': uid,
      'email': next.email.trim().toLowerCase(),
      'profile': {
        'name': next.name.trim(),
        'phone': next.phone.trim(),
        'profileImageUrl': profileImage,
        'photoUrl': profileImage,
        'avatarUrl': profileImage,
      },
      'basic': {
        'name': next.name.trim(),
        'email': next.email.trim().toLowerCase(),
        'phone': next.phone.trim(),
        'profileImageUrl': profileImage,
        'photoUrl': profileImage,
        'avatarUrl': profileImage,
      },
      'client': {
        'email': next.email.trim().toLowerCase(),
        'profile': {
          'name': next.name.trim(),
          'phone': next.phone.trim(),
          'profileImageUrl': profileImage,
          'photoUrl': profileImage,
          'avatarUrl': profileImage,
        },
      },
      'panel_displayName': next.name.trim(),
      'panel_phone': next.phone.trim(),
      'panel_profileImageUrl': profileImage,
      'profileImageUrl': profileImage,
      'photoUrl': profileImage,
      'avatarUrl': profileImage,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final profileChanged =
        previous.name.trim() != next.name.trim() ||
        previous.email.trim() != next.email.trim() ||
        previous.phone.trim() != next.phone.trim() ||
        previous.profileImageUrl.trim() != next.profileImageUrl.trim();
    if (!profileChanged) return;
  }

  Future<void> _editAddress() async {
    final updatedAddress = await showModalBottomSheet<AddressInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCat,
      builder: (_) => EditShippingAddressPopup(initial: _profile.address),
    );

    if (updatedAddress != null) {
      _applyProfile(_profile.copyWith(address: updatedAddress));
    }
  }

  Future<void> _editPayment() async {
    final updatedPayment = await showModalBottomSheet<PaymentInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCat,
      builder: (_) => EditPaymentInfoPage(initial: _profile.payment),
    );

    if (updatedPayment != null) {
      try {
        await _persistPaymentInfo(updatedPayment);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment details: $e')),
        );
        return;
      }
      _applyProfile(_profile.copyWith(payment: updatedPayment));
    }
  }

  Future<void> _persistPaymentInfo(PaymentInfo payment) async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    if (uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }

    final payload = <String, dynamic>{
      'method': payment.method.name,
      'saveForFuture': payment.saveForFuture,
      'cardNumber': payment.cardNumber.trim(),
      'nameOnCard': payment.nameOnCard.trim(),
      'expiryMMYY': payment.expiryMMYY.trim(),
      'cvv': payment.cvv.trim(),
      'zip': payment.zip.trim(),
      'venmoHandle': payment.venmoHandle.trim(),
      'paypalEmail': payment.paypalEmail.trim(),
    };

    final table = await _targetTable();

    await Supabase.instance.client.from(table).upsert({
      'id': uid,
      'email': (user?.email ?? _profile.basic.email).trim().toLowerCase(),
      'payment': payload,
      'client': {'payment': payload},
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _editMeasurements() async {
    final updatedNails = await showModalBottomSheet<NailPreferences>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.blackCat,
      builder: (_) => EditMeasurementsPopup(initial: _profile.nail),
    );

    if (updatedNails != null) {
      try {
        await _persistNailPreferences(updatedNails);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save nail measurements: $e')),
        );
        return;
      }
      _applyProfile(_profile.copyWith(nail: updatedNails));
    }
  }

  Future<void> _persistNailPreferences(NailPreferences nail) async {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    if (uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }

    final dimensions = nail.dimensions;
    final payload = <String, dynamic>{
      'shape': nail.shape.trim(),
      'length': nail.length.name,
      'dimensions': <String, dynamic>{
        'lThumb': dimensions.lThumb,
        'lIndex': dimensions.lIndex,
        'lMiddle': dimensions.lMiddle,
        'lRing': dimensions.lRing,
        'lPinky': dimensions.lPinky,
        'rThumb': dimensions.rThumb,
        'rIndex': dimensions.rIndex,
        'rMiddle': dimensions.rMiddle,
        'rRing': dimensions.rRing,
        'rPinky': dimensions.rPinky,
      },
    };

    final table = await _targetTable();

    await Supabase.instance.client.from(table).upsert({
      'id': uid,
      'email': (user?.email ?? _profile.basic.email).trim().toLowerCase(),
      'nailPreferences': payload,
      'client': {'nailPreferences': payload},
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _editCommunicationPreference() async {
    final updatedPreference =
        await showModalBottomSheet<CommunicationPreferences>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.blackCat,
          builder: (_) => _CommunicationPreferencePopup(
            initialValue: _communicationPreferences,
          ),
        );

    if (updatedPreference != null) {
      await _saveCommunicationPreferences(updatedPreference);
      if (!mounted) return;
      setState(() => _communicationPreferences = updatedPreference);
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Communication preferences saved',
        Directionality.of(context),
        assertiveness: Assertiveness.polite,
      );
    }
  }

  void _goTrackOrder() {
    if (widget.onOpenTrackOrder != null) {
      widget.onOpenTrackOrder!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrackOrderPage()),
    );
  }

  void _newDesignRequest() {
    if (widget.onOpenDesignRequest != null) {
      widget.onOpenDesignRequest!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCustomRequestPage(
          profile: _profile,
          onBackHome: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openNotifications() {
    NotificationsPage.showAsModal(context);
  }

  void _openNfcNailActivation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NfcSmartNailProfilePage()),
    );
  }

  void _closeProfilePage() {
    if (widget.onBackHome != null) {
      widget.onBackHome!.call();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile.basic.name.trim();
    final email = _profile.basic.email.trim();
    final city = _profile.address.city.trim();
    final state = _profile.address.state.trim();

    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : '';
    final avatarUrl = _profile.basic.profileImageUrl.trim();
    final locationText = (city.isEmpty && state.isEmpty)
        ? '—'
        : '${city.isEmpty ? '' : city}${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}${state.isEmpty ? '' : state}';

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Client profile',
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: JntModalAppBar(
          onClose: _closeProfilePage,
          closeTooltip: 'Close profile',
          leading: NotificationBellButton(
            onTap: _openNotifications,
            focusNode: _notificationsFocusNode,
            iconSize: JntHeaderMetrics.notificationIconSize,
          ),
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntModalHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: SizedBox(
                        height: 72,
                        width: 72,
                        child: _buildAvatarContent(avatarUrl, avatarLetter),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label:
                          'Name ${name.isEmpty ? 'Alex' : name}, email ${email.isEmpty ? 'alex@mail.com' : email}, location $locationText',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              name.isEmpty ? 'Alex' : name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Arialbold',
                                color: AppColors.blackCat,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email.isEmpty ? 'alex@mail.com' : email,
                              style: TextStyle(
                                fontSize: _smallFs,
                                fontWeight: FontWeight.w600,
                                color: AppColors.blackCat.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationText,
                              style: TextStyle(
                                fontSize: _smallFs,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackCat.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Instead of "Edit Profile" button: chevron row -> Personal Info page
                    _ProfileTopRow(
                      title: 'Personal Information',
                      onTap: _editPersonalInfo,
                    ),
                  ],
                ),
                if (_isAmbassador)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      label: 'Ambassador',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.handshake_outlined,
                              size: 14,
                              color: AppColors.blackCat,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ambassador',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            _RowChevronTile(
              icon: Icons.credit_card_outlined,
              title: 'Payment Methods',
              onTap: _editPayment,
            ),

            _RowChevronTile(
              icon: Icons.location_on_outlined,
              title: 'Shipping Address',
              onTap: _editAddress,
            ),

            _RowChevronTile(
              icon: Icons.straighten_outlined,
              title: 'Measurements',
              onTap: _editMeasurements,
            ),

            _RowChevronTile(
              icon: Icons.notifications_outlined,
              title: 'Communication Preference',
              onTap: _editCommunicationPreference,
            ),

            _RowChevronTile(
              icon: Icons.nfc,
              title: 'Nail Activation',
              onTap: _openNfcNailActivation,
            ),

            Offstage(
              offstage: true,
              child: Column(
                children: [
                  _RowChevronTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Track Order',
                    onTap: _goTrackOrder,
                  ),
                  _RowChevronTile(
                    icon: Icons.add,
                    title: 'New Design Request',
                    onTap: _newDesignRequest,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Semantics(
              button: true,
              label: 'Log out',
              onTap: () {
                widget.onLogout();
              },
              child: ExcludeSemantics(
                child: _TextDangerButton(
                  text: 'Log out',
                  onTap: widget.onLogout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String src, String fallbackLetter) {
    final trimmed = src.trim();
    if (trimmed.startsWith('gs://') || trimmed.startsWith('clients/')) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: SizedBox(
          width: 68,
          height: 68,
          child: ClientProfileAvatarIcon(
            imageUrl: trimmed,
            displayName: _profile.basic.name,
            size: 24,
          ),
        ),
      );
    }
    if (src.startsWith('data:image/')) {
      final comma = src.indexOf(',');
      if (comma > 0 && comma < src.length - 1) {
        try {
          final bytes = base64Decode(src.substring(comma + 1));
          return ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.memory(
              bytes,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _avatarLetter(fallbackLetter),
            ),
          );
        } catch (_) {
          return _avatarLetter(fallbackLetter);
        }
      }
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Image.network(
          src,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarLetter(fallbackLetter),
        ),
      );
    }
    return _avatarLetter(fallbackLetter);
  }

  Widget _avatarLetter(String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.balletSlippers),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

/// ---------------- UI components ----------------

class _ProfileTopRow extends StatelessWidget {
  const _ProfileTopRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
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
                Icon(Icons.person_outline, color: AppColors.blackCat, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextDangerButton extends StatelessWidget {
  const _TextDangerButton({required this.text, required this.onTap});

  final String text;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blackCat,
            foregroundColor: AppColors.snow,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: () async => onTap(),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.snow,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              fontFamily: 'Arial',
            ),
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
    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
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
                Icon(icon, color: AppColors.blackCat, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      fontFamily: 'Arial',
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.35),
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

class _CommunicationPreferencePopup extends StatefulWidget {
  const _CommunicationPreferencePopup({required this.initialValue});

  final CommunicationPreferences initialValue;

  @override
  State<_CommunicationPreferencePopup> createState() =>
      _CommunicationPreferencePopupState();
}

class _CommunicationPreferencePopupState
    extends State<_CommunicationPreferencePopup> {
  static const double _sectionTitleFs = 14.5;

  late bool _emailNotifications;
  bool _smsNotifications = false;
  late bool _pushNotifications;
  bool _accountActivity = true;
  bool _securityAlerts = true;
  bool _promotionsOffers = false;
  bool _reminders = true;
  bool _newsUpdates = true;
  _PreferredContactMethod _preferredContact = _PreferredContactMethod.sms;
  bool _marketingConsent = true;
  final FocusNode _emailNotificationFocusNode = FocusNode(
    debugLabel: 'emailNotificationsSwitch',
  );

  @override
  void initState() {
    super.initState();
    _emailNotifications = widget.initialValue.emailNotifications;
    _smsNotifications = widget.initialValue.smsNotifications;
    _pushNotifications = widget.initialValue.pushNotifications;
    _accountActivity = widget.initialValue.accountActivity;
    _securityAlerts = widget.initialValue.securityAlerts;
    _promotionsOffers = widget.initialValue.promotionsOffers;
    _reminders = widget.initialValue.reminders;
    _newsUpdates = widget.initialValue.newsUpdates;
    _preferredContact = widget.initialValue.preferredContact;
    _marketingConsent = widget.initialValue.marketingConsent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emailNotificationFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailNotificationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Communication Preferences',
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  Container(
                    //color: AppColors.alabaster,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            height: 4,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.blackCat,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 48),
                            Expanded(
                              child: Text(
                                'Communication Preferences',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.blackCat,
                                  fontFamily: 'Arialbold',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close communication preferences',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: AppColors.blackCat.withValues(alpha: 0.75),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        _sectionCard(
                          title: 'Communication Channels',
                          child: Column(
                            children: [
                              _channelTile(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email Notifications',
                                value: _emailNotifications,
                                focusNode: _emailNotificationFocusNode,
                                onChanged: (value) =>
                                    setState(() => _emailNotifications = value),
                              ),
                              _divider(),
                              _channelTile(
                                icon: Icons.sms_outlined,
                                title: 'SMS Notifications',
                                value: _smsNotifications,
                                onChanged: (value) =>
                                    setState(() => _smsNotifications = value),
                              ),
                              _divider(),
                              _channelTile(
                                icon: Icons.notifications_none_rounded,
                                title: 'Push Notifications',
                                value: _pushNotifications,
                                onChanged: (value) =>
                                    setState(() => _pushNotifications = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Notification Types',
                          child: Column(
                            children: [
                              _checkboxTile(
                                icon: Icons.person_outline_rounded,
                                title: 'Account Activity',
                                value: _accountActivity,
                                onChanged: (value) =>
                                    setState(() => _accountActivity = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.shield_outlined,
                                title: 'Security Alerts',
                                value: _securityAlerts,
                                onChanged: (value) =>
                                    setState(() => _securityAlerts = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.local_offer_outlined,
                                title: 'Promotions & Offers',
                                value: _promotionsOffers,
                                onChanged: (value) =>
                                    setState(() => _promotionsOffers = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.calendar_today_outlined,
                                title: 'Reminders',
                                value: _reminders,
                                onChanged: (value) =>
                                    setState(() => _reminders = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.campaign_outlined,
                                title: 'News & Updates',
                                value: _newsUpdates,
                                onChanged: (value) =>
                                    setState(() => _newsUpdates = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Preferred Contact Method',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _radioOption(
                                      label: 'Email',
                                      value: _PreferredContactMethod.email,
                                    ),
                                  ),
                                  Expanded(
                                    child: _radioOption(
                                      label: 'Push',
                                      value: _PreferredContactMethod.push,
                                    ),
                                  ),
                                  Expanded(
                                    child: _radioOption(
                                      label: 'SMS',
                                      value: _PreferredContactMethod.sms,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _divider(),
                              const SizedBox(height: 10),
                              MergeSemantics(
                                child: Semantics(
                                  label:
                                      'I agree to receive marketing communications.',
                                  checked: _marketingConsent,
                                  child: InkWell(
                                    onTap: () => setState(
                                      () => _marketingConsent =
                                          !_marketingConsent,
                                    ),
                                    borderRadius: BorderRadius.zero,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: _marketingConsent,
                                          activeColor: AppColors.blackCat,
                                          onChanged: (value) => setState(
                                            () => _marketingConsent =
                                                value ?? false,
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const ExcludeSemantics(
                                                  child: Text(
                                                    'I agree to receive marketing communications.',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.blackCat,
                                                      fontFamily: 'Arialbold',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                /*Text(
                                            'You can unsubscribe anytime.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.blackCat,
                                              fontFamily: 'Arialbold',
                                            ),
                                          ),*/
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blackCat,
                                foregroundColor: AppColors.snow,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.pop(context, _currentPreferences),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  CommunicationPreferences get _currentPreferences => CommunicationPreferences(
    emailNotifications: _emailNotifications,
    smsNotifications: _smsNotifications,
    pushNotifications: _pushNotifications,
    accountActivity: _accountActivity,
    securityAlerts: _securityAlerts,
    promotionsOffers: _promotionsOffers,
    reminders: _reminders,
    newsUpdates: _newsUpdates,
    preferredContact: _preferredContact,
    marketingConsent: _marketingConsent,
  );

  Widget _sectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: _sectionTitleFs,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _channelTile({
    required IconData icon,
    required String title,
    required bool value,
    FocusNode? focusNode,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: title,
        toggled: value,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 22, color: AppColors.blackCat),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                    fontFamily: 'Arialbold',
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                focusNode: focusNode,
                value: value,
                activeThumbColor: AppColors.blackCat,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkboxTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: title,
        checked: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.zero,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 22, color: AppColors.blackCat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blackCat,
                      fontFamily: 'Arialbold',
                    ),
                  ),
                ),
              ),
              Checkbox(
                value: value,
                activeColor: AppColors.blackCat,
                onChanged: (next) => onChanged(next ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioOption({
    required String label,
    required _PreferredContactMethod value,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: '$label contact method',
        checked: _preferredContact == value,
        inMutuallyExclusiveGroup: true,
        child: RadioGroup<_PreferredContactMethod>(
          groupValue: _preferredContact,
          onChanged: (next) {
            if (next != null) {
              setState(() => _preferredContact = next);
            }
          },
          child: InkWell(
            onTap: () => setState(() => _preferredContact = value),
            borderRadius: BorderRadius.zero,
            child: Row(
              children: [
                Radio<_PreferredContactMethod>(
                  value: value,
                  activeColor: AppColors.blackCat,
                ),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.blackCat,
                        fontFamily: 'Arialbold',
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
  }

  Widget _divider() => ExcludeSemantics(
        child: Divider(
          height: 18,
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      );
}

enum _PreferredContactMethod { email, push, sms }

class CommunicationPreferences {
  const CommunicationPreferences({
    required this.emailNotifications,
    required this.smsNotifications,
    required this.pushNotifications,
    required this.accountActivity,
    required this.securityAlerts,
    required this.promotionsOffers,
    required this.reminders,
    required this.newsUpdates,
    required this.preferredContact,
    required this.marketingConsent,
  });

  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
  final bool accountActivity;
  final bool securityAlerts;
  final bool promotionsOffers;
  final bool reminders;
  final bool newsUpdates;
  final _PreferredContactMethod preferredContact;
  final bool marketingConsent;

  factory CommunicationPreferences.defaults() {
    return const CommunicationPreferences(
      emailNotifications: true,
      smsNotifications: false,
      pushNotifications: true,
      accountActivity: true,
      securityAlerts: true,
      promotionsOffers: false,
      reminders: true,
      newsUpdates: true,
      preferredContact: _PreferredContactMethod.sms,
      marketingConsent: true,
    );
  }

  factory CommunicationPreferences.fromMap(Map<String, dynamic> map) {
    _PreferredContactMethod parsePreferred(dynamic raw) {
      switch ((raw ?? '').toString().trim()) {
        case 'email':
          return _PreferredContactMethod.email;
        case 'push':
          return _PreferredContactMethod.push;
        case 'sms':
        default:
          return _PreferredContactMethod.sms;
      }
    }

    bool asBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
      return fallback;
    }

    final defaults = CommunicationPreferences.defaults();
    return CommunicationPreferences(
      emailNotifications: asBool(
        map['emailNotifications'],
        defaults.emailNotifications,
      ),
      smsNotifications: asBool(
        map['smsNotifications'],
        defaults.smsNotifications,
      ),
      pushNotifications: asBool(
        map['pushNotifications'],
        defaults.pushNotifications,
      ),
      accountActivity: asBool(map['accountActivity'], defaults.accountActivity),
      securityAlerts: asBool(map['securityAlerts'], defaults.securityAlerts),
      promotionsOffers: asBool(
        map['promotionsOffers'],
        defaults.promotionsOffers,
      ),
      reminders: asBool(map['reminders'], defaults.reminders),
      newsUpdates: asBool(map['newsUpdates'], defaults.newsUpdates),
      preferredContact: parsePreferred(map['preferredContact']),
      marketingConsent: asBool(
        map['marketingConsent'],
        defaults.marketingConsent,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'pushNotifications': pushNotifications,
      'accountActivity': accountActivity,
      'securityAlerts': securityAlerts,
      'promotionsOffers': promotionsOffers,
      'reminders': reminders,
      'newsUpdates': newsUpdates,
      'preferredContact': preferredContact.name,
      'marketingConsent': marketingConsent,
    };
  }
}
