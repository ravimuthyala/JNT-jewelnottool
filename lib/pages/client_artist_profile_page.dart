// lib/pages/client_artist_profile_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ambassador_role_service.dart';
import '../services/auth_email_alias_service.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_modal_app_bar.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';

import 'notifications_page.dart';
import 'edit_personal_info_popup.dart';
import 'edit_payment_info_popup.dart';
import 'edit_shipping_address_page.dart';
import 'edit_measurements_page.dart';
import 'client_artist_home_page.dart';
import 'artist_profile_page.dart';
import 'jnt_ascension_page.dart';
import 'client_artist_communication_preferences_page.dart';

class ClientArtistProfilePage extends StatefulWidget {
  const ClientArtistProfilePage({super.key, this.initialProfile});
  final ClientProfileDraft? initialProfile;

  @override
  State<ClientArtistProfilePage> createState() =>
      _ClientArtistProfilePageState();
}

class _ClientArtistProfilePageState extends State<ClientArtistProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _directRequestsOn = true;
  bool _savingDirectRequestPref = false;
  bool _nfcRequestsOn = false;
  bool _savingNfcRequestPref = false;
  bool _showClientTab = true;
  ClientArtistCommunicationPreferences _communicationPreferences =
      ClientArtistCommunicationPreferences.defaults();

  late ClientProfileDraft _profile;
  Map<String, dynamic> _profileData = const <String, dynamic>{};
  final int _index = 0;
  bool _showCampaignsTab = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile ?? ClientProfileDraft.mock();
    unawaited(_loadCampaignVisibility());
    _loadProfileFromSupabase();
    _loadCommunicationPreferences();
  }

  Future<void> _loadCampaignVisibility() async {
    final show = await AmbassadorRoleService.currentUserIsAmbassador(
      fallbackEmail: _profile.basic.email,
    );
    if (!mounted) return;
    setState(() => _showCampaignsTab = show);
  }

  User? get _currentUser => _supabase.auth.currentUser;

  Future<({String uid, String email, String aliasUid})>
  _resolveIdentity() async {
    final user = _currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    final aliasUid = email.isNotEmpty
        ? await AuthEmailAliasService.resolveUidForLogin(email)
        : null;
    return (
      uid: (user?.id ?? '').trim(),
      email: email,
      aliasUid: (aliasUid ?? '').trim(),
    );
  }

  Future<Map<String, dynamic>?> _readProfileRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    Future<Map<String, dynamic>?> firstRow(
      PostgrestTransformBuilder<PostgrestList> query,
    ) async {
      try {
        final rows = await query.limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {}
      return null;
    }

    if (uid.isNotEmpty) {
      final byId = await firstRow(_supabase.from(table).select().eq('id', uid));
      if (byId != null) return byId;
      final byUid = await firstRow(
        _supabase.from(table).select().eq('uid', uid),
      );
      if (byUid != null) return byUid;
    }

    if (email.isNotEmpty) {
      final byEmail = await firstRow(
        _supabase.from(table).select().eq('email', email),
      );
      if (byEmail != null) return byEmail;
    }

    return null;
  }

  Map<String, dynamic> _normalizeArtistProfileData(Map<String, dynamic> row) {
    final profile = _asMap(row['profile']);
    final address = _asMap(row['address']);
    final artist = _asMap(row['artist']);
    final artistProfile = _asMap(row['artist_profile']);
    final artistAvailability = _asMap(artist['availability']);
    final artistPricing = _asMap(artist['pricing']);
    final artistCredentials = _asMap(artist['credentials']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final rowCredentials = _asMap(row['credentials']);
    final artistProfileCredentials = _asMap(artistProfile['credentials']);

    final mergedCredentials = <String, dynamic>{
      ...rowCredentials,
      ...artistProfileCredentials,
      ...artistCredentials,
    };

    final yearsExperience = _normalizeArtistYearsExperienceForModal(
      _firstNonEmpty([
        row['panel_proYearsExperience'],
        row['panel_pro_years_experience'],
        row['panel_yearsExperience'],
        row['panel_years_experience'],
        row['proYearsExperience'],
        row['pro_years_experience'],
        row['yearsExperience'],
        row['years_experience'],
        row['experience'],
        profile['proYearsExperience'],
        profile['pro_years_experience'],
        profile['yearsExperience'],
        profile['years_experience'],
        artistProfile['proYearsExperience'],
        artistProfile['pro_years_experience'],
        artistProfile['yearsExperience'],
        artistProfile['years_experience'],
        artistProfile['experience'],
        mergedCredentials['proYearsExperience'],
        mergedCredentials['pro_years_experience'],
        mergedCredentials['yearsExperience'],
        mergedCredentials['years_experience'],
        mergedCredentials['experience'],
        artist['proYearsExperience'],
        artist['pro_years_experience'],
        artist['yearsExperience'],
        artist['years_experience'],
        artist['experience'],
      ]),
    );

    final practiceDuration = _normalizeArtistPracticeDurationForModal(
      _firstNonEmpty([
        row['panel_practiceDuration'],
        row['panel_practice_duration'],
        row['practiceDuration'],
        row['practice_duration'],
        profile['practiceDuration'],
        profile['practice_duration'],
        artistProfile['practiceDuration'],
        artistProfile['practice_duration'],
        mergedCredentials['practiceDuration'],
        mergedCredentials['practice_duration'],
        artist['practiceDuration'],
        artist['practice_duration'],
      ]),
    );

    final nailTechType = _firstNonEmpty([
      row['panel_nailTechType'],
      row['panel_artist_nailTechType'],
      row['panel_nail_tech_type'],
      row['panel_artist_nail_tech_type'],
      row['nailTechType'],
      row['nail_tech_type'],
      profile['nailTechType'],
      profile['nail_tech_type'],
      artistProfile['nailTechType'],
      artistProfile['nail_tech_type'],
      mergedCredentials['nailTechType'],
      mergedCredentials['nail_tech_type'],
      artist['nailTechType'],
      artist['nail_tech_type'],
    ]);

    final licenseNumber = _firstNonEmpty([
      row['panel_licenseNumber'],
      row['panel_license_number'],
      row['licenseNumber'],
      row['license_number'],
      profile['licenseNumber'],
      profile['license_number'],
      artistProfile['licenseNumber'],
      artistProfile['license_number'],
      mergedCredentials['licenseNumber'],
      mergedCredentials['license_number'],
      artist['licenseNumber'],
      artist['license_number'],
    ]);

    final jurisdiction = _firstNonEmpty([
      row['panel_jurisdiction'],
      row['jurisdiction'],
      profile['jurisdiction'],
      artistProfile['jurisdiction'],
      mergedCredentials['jurisdiction'],
      artist['jurisdiction'],
    ]);

    final school = _firstNonEmpty([
      row['panel_school'],
      row['school'],
      profile['school'],
      artistProfile['school'],
      mergedCredentials['school'],
      artist['school'],
    ]);

    return <String, dynamic>{
      ...row,
      if (yearsExperience.isNotEmpty) ...{
        'panel_proYearsExperience': yearsExperience,
        'panel_pro_years_experience': yearsExperience,
        'proYearsExperience': yearsExperience,
        'pro_years_experience': yearsExperience,
        'yearsExperience': yearsExperience,
        'years_experience': yearsExperience,
      },
      if (practiceDuration.isNotEmpty) ...{
        'panel_practiceDuration': practiceDuration,
        'panel_practice_duration': practiceDuration,
        'practiceDuration': practiceDuration,
        'practice_duration': practiceDuration,
      },
      if (nailTechType.isNotEmpty) ...{
        'panel_nailTechType': nailTechType,
        'panel_artist_nailTechType': nailTechType,
        'panel_nail_tech_type': nailTechType,
        'panel_artist_nail_tech_type': nailTechType,
        'nailTechType': nailTechType,
        'nail_tech_type': nailTechType,
      },
      if (licenseNumber.isNotEmpty) ...{
        'panel_licenseNumber': licenseNumber,
        'panel_license_number': licenseNumber,
        'licenseNumber': licenseNumber,
        'license_number': licenseNumber,
      },
      if (jurisdiction.isNotEmpty) ...{
        'panel_jurisdiction': jurisdiction,
        'jurisdiction': jurisdiction,
      },
      if (school.isNotEmpty) ...{'panel_school': school, 'school': school},
      'artist': {
        ...artistProfile,
        ...artist,
        'availability': {
          ..._asMap(artistProfile['availability']),
          ...artistAvailability,
        },
        'pricing': {..._asMap(artistProfile['pricing']), ...artistPricing},
        'credentials': {
          ..._asMap(artistProfile['credentials']),
          ...artistCredentials,
        },
        'portfolio': {
          ..._asMap(artistProfile['portfolio']),
          ...artistPortfolio,
        },
      },
      'artist_profile': {...artist, ...artistProfile},
      'availability': {
        ..._asMap(row['availability']),
        ..._asMap(artistProfile['availability']),
        ...artistAvailability,
      },
      'pricing': {
        ..._asMap(row['pricing']),
        ..._asMap(artistProfile['pricing']),
        ...artistPricing,
      },
      'credentials': {
        ...mergedCredentials,
        if (yearsExperience.isNotEmpty) ...{
          'proYearsExperience': yearsExperience,
          'pro_years_experience': yearsExperience,
          'yearsExperience': yearsExperience,
          'years_experience': yearsExperience,
        },
        if (practiceDuration.isNotEmpty) ...{
          'practiceDuration': practiceDuration,
          'practice_duration': practiceDuration,
        },
        if (nailTechType.isNotEmpty) ...{
          'nailTechType': nailTechType,
          'nail_tech_type': nailTechType,
        },
        if (licenseNumber.isNotEmpty) ...{
          'licenseNumber': licenseNumber,
          'license_number': licenseNumber,
        },
        if (jurisdiction.isNotEmpty) 'jurisdiction': jurisdiction,
        if (school.isNotEmpty) 'school': school,
      },
      'portfolio': {
        ..._asMap(row['portfolio']),
        ..._asMap(artistProfile['portfolio']),
        ...artistPortfolio,
      },
      'services': [
        ..._asStringList(row['services']),
        ..._asStringList(artistProfile['services']),
        ..._asStringList(artist['services']),
      ].toSet().toList(growable: false),
      'city': _firstNonEmpty([
        row['city'],
        address['city'],
        profile['city'],
        artistProfile['city'],
        artist['city'],
      ]),
      'state': _firstNonEmpty([
        row['state'],
        address['state'],
        profile['state'],
        artistProfile['state'],
        artist['state'],
      ]),
      'country': _firstNonEmpty([
        row['country'],
        address['country'],
        profile['country'],
        artistProfile['country'],
        artist['country'],
      ]),
    };
  }

  Future<({String table, String id, Map<String, dynamic> data})?>
  _resolveArtistRow() async {
    final identity = await _resolveIdentity();
    final candidateUids = <String>{identity.uid, identity.aliasUid}
      ..removeWhere((value) => value.trim().isEmpty);
    for (final table in const <String>['client_artist', 'artist']) {
      for (final uid in candidateUids) {
        final row = await _readProfileRow(
          table: table,
          uid: uid,
          email: identity.email,
        );
        if (row == null) continue;
        final id = _firstNonEmpty([row['id'], row['uid'], uid]);
        if (id.isEmpty) continue;
        return (table: table, id: id, data: _normalizeArtistProfileData(row));
      }

      final byEmail = await _readProfileRow(
        table: table,
        uid: '',
        email: identity.email,
      );
      if (byEmail == null) continue;
      final id = _firstNonEmpty([
        byEmail['id'],
        byEmail['uid'],
        identity.uid,
        identity.aliasUid,
      ]);
      if (id.isEmpty) continue;
      return (table: table, id: id, data: _normalizeArtistProfileData(byEmail));
    }
    return null;
  }

  Future<({String table, String id, Map<String, dynamic> data})?>
  _ensureArtistRow() async {
    final existing = await _resolveArtistRow();
    if (existing != null) return existing;

    final identity = await _resolveIdentity();
    final id = _firstNonEmpty([identity.uid, identity.aliasUid]);
    final email = _firstNonEmpty([
      identity.email,
      _profile.basic.email,
    ]).toLowerCase();
    if (id.isEmpty && email.isEmpty) return null;

    final currentProfile = _asMap(_profileData['profile']);
    final currentAddress = _asMap(_profileData['address']);
    final currentArtist = _asMap(_profileData['artist']);
    final currentArtistProfile = _asMap(_profileData['artist_profile']);
    final currentAvailability = _asMap(_profileData['availability']);
    final currentPricing = _asMap(_profileData['pricing']);
    final currentCredentials = _asMap(_profileData['credentials']);
    final resolvedId = id.isNotEmpty ? id : email;

    try {
      await _upsertArtistRow('client_artist', resolvedId, {
        'account_type': 'client_artist',
        'displayName': _profile.basic.name.trim(),
        'name': _profile.basic.name.trim(),
        'profileImageUrl': _profile.basic.profileImageUrl.trim(),
        'photoUrl': _profile.basic.profileImageUrl.trim(),
        'avatarUrl': _profile.basic.profileImageUrl.trim(),
        'profile': {
          ...currentProfile,
          'displayName': _profile.basic.name.trim(),
          'name': _profile.basic.name.trim(),
          'photoUrl': _profile.basic.profileImageUrl.trim(),
          'avatarUrl': _profile.basic.profileImageUrl.trim(),
          'profileImageUrl': _profile.basic.profileImageUrl.trim(),
        },
        'address': {
          ...currentAddress,
          'street': _profile.address.street.trim(),
          'city': _profile.address.city.trim(),
          'state': _profile.address.state.trim(),
          'zip': _profile.address.zip.trim(),
          'country': _profile.address.country.trim(),
        },
        'artist': {...currentArtist, ...currentArtistProfile},
        'artist_profile': {...currentArtistProfile, ...currentArtist},
        'availability': currentAvailability,
        'pricing': currentPricing,
        'credentials': currentCredentials,
      }, email: email);
    } catch (e) {
      debugPrint('ClientArtistProfilePage: failed to create artist row: $e');
    }

    return _resolveArtistRow();
  }

  Future<({String table, String id, Map<String, dynamic> data})?>
  _artistModalRef() async {
    final ensured = await _ensureArtistRow();
    if (ensured != null) return ensured;

    final identity = await _resolveIdentity();
    final fallbackId = _firstNonEmpty([
      identity.uid,
      identity.aliasUid,
      _profileData['id'],
      _profileData['uid'],
    ]);
    final fallbackEmail = _firstNonEmpty([
      identity.email,
      _profile.basic.email,
      _profileData['email'],
    ]).toLowerCase();

    if (fallbackId.isEmpty && fallbackEmail.isEmpty) return null;

    final data = <String, dynamic>{
      ..._normalizeArtistProfileData(_profileData),
      if (fallbackId.isNotEmpty) 'id': fallbackId,
      if (fallbackEmail.isNotEmpty) 'email': fallbackEmail,
      'profile': {
        ..._asMap(_profileData['profile']),
        'displayName': _profile.basic.name.trim(),
        'name': _profile.basic.name.trim(),
        'email': fallbackEmail,
        'photoUrl': _profile.basic.profileImageUrl.trim(),
        'avatarUrl': _profile.basic.profileImageUrl.trim(),
        'profileImageUrl': _profile.basic.profileImageUrl.trim(),
        'city': _profile.address.city.trim(),
        'state': _profile.address.state.trim(),
        'country': _profile.address.country.trim(),
      },
      'address': {
        ..._asMap(_profileData['address']),
        'street': _profile.address.street.trim(),
        'city': _profile.address.city.trim(),
        'state': _profile.address.state.trim(),
        'zip': _profile.address.zip.trim(),
        'country': _profile.address.country.trim(),
      },
    };

    return (
      table: 'client_artist',
      id: fallbackId.isNotEmpty ? fallbackId : fallbackEmail,
      data: data,
    );
  }

  Future<void> _upsertArtistRow(
    String table,
    String id,
    Map<String, dynamic> payload, {
    String? email,
  }) async {
    final row = <String, dynamic>{
      'id': id,
      ...payload,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final normalizedEmail = (email ?? _currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (normalizedEmail.isNotEmpty && !row.containsKey('email')) {
      row['email'] = normalizedEmail;
    }
    await _supabase.from(table).upsert(row);
  }

  Future<void> _updateRequestDetails(
    String table,
    String requestId,
    Map<String, dynamic> payload,
  ) async {
    await _supabase.from(table).upsert({
      'request_id': requestId,
      ...payload,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  PaymentMethod _parsePaymentMethod(String? value) {
    switch ((value ?? '').trim()) {
      case 'venmo':
        return PaymentMethod.venmo;
      case 'paypal':
        return PaymentMethod.paypal;
      case 'card':
        return PaymentMethod.card;
      case 'applePay':
      default:
        return PaymentMethod.applePay;
    }
  }

  NailLength _parseNailLength(String? value) {
    switch ((value ?? '').trim()) {
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

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
      (value ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), ''),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _firstMap(List<dynamic> values) {
    for (final value in values) {
      final map = _asMap(value);
      if (map.isNotEmpty) return map;
    }
    return const <String, dynamic>{};
  }

  String _normalizeString(Object? raw) {
    return (raw ?? '').toString().trim().toLowerCase();
  }

  bool _hasAmbassadorTag(Map<String, dynamic> data) {
    String normalize(Object? raw) => _normalizeString(raw).replaceAll('_', ' ');

    bool matchStatus(Object? raw) {
      final value = normalize(raw);
      return value == 'ambassador' || value.contains('ambassador');
    }

    bool matchList(Object? raw) {
      if (raw is! List) return false;
      for (final item in raw) {
        if (matchStatus(item)) return true;
      }
      return false;
    }

    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final profileAscension =
        (profile['ascension'] as Map<String, dynamic>?) ?? const {};
    final basicAscension =
        (basic['ascension'] as Map<String, dynamic>?) ?? const {};
    final clientAscension =
        (client['ascension'] as Map<String, dynamic>?) ?? const {};

    for (final raw in <Object?>[
      data['status'],
      data['partnerStatus'],
      data['tier'],
      profile['status'],
      profile['partnerStatus'],
      profile['tier'],
      basic['status'],
      basic['partnerStatus'],
      basic['tier'],
      client['status'],
      client['partnerStatus'],
      client['tier'],
      ascension['status'],
      ascension['partnerStatus'],
      ascension['tier'],
      profileAscension['status'],
      profileAscension['partnerStatus'],
      profileAscension['tier'],
      basicAscension['status'],
      basicAscension['partnerStatus'],
      basicAscension['tier'],
    ]) {
      if (matchStatus(raw)) return true;
    }

    for (final raw in <Object?>[
      data['tags'],
      profile['tags'],
      basic['tags'],
      client['tags'],
      ascension['tags'],
      profileAscension['tags'],
      basicAscension['tags'],
      clientAscension['tags'],
    ]) {
      if (matchList(raw)) return true;
    }

    return false;
  }

  bool? _readMaybeBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = (raw ?? '').toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  String _resolveArtistTierLabel(Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final profileFromClient =
        (client['profile'] as Map<String, dynamic>?) ?? const {};
    final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
    final sponsorshipRequest =
        (data['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};

    String? labelOf(Object? raw) {
      final tier = _normalizeString(raw);
      if (tier.contains('goldsmith')) return 'Goldsmith';
      if (tier.contains('crowned')) return 'Crowned';
      if (tier.contains('maker')) return 'Maker';
      return null;
    }

    for (final candidate in <Object?>[
      data['sponsorshipTier'],
      data['panel_ascensionLevel'],
      data['panel_tier'],
      data['tier'],
      data['status'],
      profile['ascensionTier'],
      profile['tier'],
      profile['status'],
      profileFromClient['ascensionTier'],
      profileFromClient['tier'],
      profileFromClient['status'],
      ascension['tier'],
      ascension['levelName'],
      ascension['status'],
      sponsorshipRequest['tier'],
      sponsorshipRequest['status'],
    ]) {
      final label = labelOf(candidate);
      if (label != null) return label;
    }

    return 'Maker';
  }

  Widget _buildProfileTag(String label) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  ClientProfileDraft _draftFromFirestore(Map<String, dynamic> data) {
    final client = _asMap(data['client']);
    final profile = _asMap(data['profile']);
    final profileFromClient = _asMap(client['profile']);
    final address = _asMap(data['address']);
    final addressFromClient = _asMap(client['address']);
    final artist = _asMap(data['artist']);
    final artistProfile = _asMap(data['artist_profile']);
    final payment = _firstMap([data['payment'], client['payment']]);
    final nail = _firstMap([
      data['nailPreferences'],
      data['nail_preferences'],
      data['measurements'],
      client['nailPreferences'],
      client['nail_preferences'],
      client['measurements'],
    ]);
    final dimensions = _firstMap([
      nail['dimensions'],
      nail['nail_dimensions'],
      data['dimensions'],
      data['nail_dimensions'],
      data['measurements'],
      client['dimensions'],
      client['nail_dimensions'],
    ]);

    final name = (profile['name'] ?? '').toString().trim().isNotEmpty
        ? (profile['name'] ?? '').toString().trim()
        : (profile['displayName'] ?? '').toString().trim().isNotEmpty
        ? (profile['displayName'] ?? '').toString().trim()
        : (profile['nameOrStudio'] ?? '').toString().trim().isNotEmpty
        ? (profile['nameOrStudio'] ?? '').toString().trim()
        : (profileFromClient['name'] ?? '').toString().trim().isNotEmpty
        ? (profileFromClient['name'] ?? '').toString().trim()
        : (profileFromClient['displayName'] ?? '').toString().trim().isNotEmpty
        ? (profileFromClient['displayName'] ?? '').toString().trim()
        : (profileFromClient['nameOrStudio'] ?? '').toString().trim().isNotEmpty
        ? (profileFromClient['nameOrStudio'] ?? '').toString().trim()
        : (data['panel_displayName'] ?? '').toString().trim().isNotEmpty
        ? (data['panel_displayName'] ?? '').toString().trim()
        : (data['panel_nameOrStudio'] ?? '').toString().trim();

    return ClientProfileDraft(
      basic: BasicInfo(
        name: name,
        email: (data['email'] ?? '').toString(),
        phone:
            ((profile['phone'] ?? '').toString().trim().isNotEmpty
                    ? profile['phone']
                    : profileFromClient['phone'] ?? data['panel_phone'] ?? '')
                .toString(),
        profileImageUrl: _firstNonEmpty([
          profile['profileImageUrl'],
          profile['profile_image_url'],
          profile['profilePhotoUrl'],
          profile['profile_photo_url'],
          profile['photoUrl'],
          profile['photo_url'],
          profile['avatarUrl'],
          profile['avatar_url'],
          profileFromClient['profileImageUrl'],
          profileFromClient['profile_image_url'],
          profileFromClient['photoUrl'],
          profileFromClient['photo_url'],
          profileFromClient['avatarUrl'],
          profileFromClient['avatar_url'],
          artistProfile['profileImageUrl'],
          artistProfile['profile_image_url'],
          artistProfile['profilePhotoUrl'],
          artistProfile['profile_photo_url'],
          artistProfile['photoUrl'],
          artistProfile['photo_url'],
          artistProfile['avatarUrl'],
          artistProfile['avatar_url'],
          artist['profileImageUrl'],
          artist['profile_image_url'],
          artist['profilePhotoUrl'],
          artist['profile_photo_url'],
          artist['photoUrl'],
          artist['photo_url'],
          artist['avatarUrl'],
          artist['avatar_url'],
          data['panel_profileImageUrl'],
          data['panel_profile_image_url'],
          data['profileImageUrl'],
          data['profile_image_url'],
          data['profilePhotoUrl'],
          data['profile_photo_url'],
          data['photoUrl'],
          data['photo_url'],
          data['avatarUrl'],
          data['avatar_url'],
        ]),
      ),
      address: AddressInfo(
        street:
            ((address['street'] ?? '').toString().trim().isNotEmpty
                    ? address['street']
                    : addressFromClient['street'] ?? data['panel_street'] ?? '')
                .toString(),
        city:
            ((address['city'] ?? '').toString().trim().isNotEmpty
                    ? address['city']
                    : addressFromClient['city'] ?? data['panel_city'] ?? '')
                .toString(),
        state:
            ((address['state'] ?? '').toString().trim().isNotEmpty
                    ? address['state']
                    : addressFromClient['state'] ?? data['panel_state'] ?? '')
                .toString(),
        zip:
            ((address['zip'] ?? '').toString().trim().isNotEmpty
                    ? address['zip']
                    : addressFromClient['zip'] ?? data['panel_zip'] ?? '')
                .toString(),
        country:
            ((address['country'] ?? '').toString().trim().isNotEmpty
                    ? address['country']
                    : addressFromClient['country'] ??
                          data['panel_country'] ??
                          '')
                .toString(),
      ),
      payment: PaymentInfo(
        method: _parsePaymentMethod(payment['method']?.toString()),
        saveForFuture: payment['saveForFuture'] == true,
        cardNumber: (payment['cardNumber'] ?? '').toString(),
        nameOnCard: (payment['nameOnCard'] ?? '').toString(),
        expiryMMYY: (payment['expiryMMYY'] ?? '').toString(),
        cvv: (payment['cvv'] ?? '').toString(),
        zip: (payment['zip'] ?? '').toString(),
        venmoHandle: (payment['venmoHandle'] ?? '').toString(),
        paypalEmail: (payment['paypalEmail'] ?? '').toString(),
      ),
      nail: NailPreferences(
        shape: (nail['shape'] ?? '').toString(),
        length: _parseNailLength(nail['length']?.toString()),
        dimensions: NailDimensions(
          lThumb: _asDouble(dimensions['lThumb']),
          lIndex: _asDouble(dimensions['lIndex']),
          lMiddle: _asDouble(dimensions['lMiddle']),
          lRing: _asDouble(dimensions['lRing']),
          lPinky: _asDouble(dimensions['lPinky']),
          rThumb: _asDouble(dimensions['rThumb']),
          rIndex: _asDouble(dimensions['rIndex']),
          rMiddle: _asDouble(dimensions['rMiddle']),
          rRing: _asDouble(dimensions['rRing']),
          rPinky: _asDouble(dimensions['rPinky']),
        ),
      ),
    );
  }

  Future<void> _loadProfileFromSupabase() async {
    try {
      final resolved = await _ensureArtistRow();
      final data = resolved?.data;
      if (!mounted || data == null) return;
      final availability =
          (data['availability'] as Map<String, dynamic>?) ?? const {};
      final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
      setState(() {
        _profileData = data;
        _profile = _draftFromFirestore(data);
        _directRequestsOn =
            _readMaybeBool(data['panel_directRequestsEnabled']) ??
            _readMaybeBool(availability['directRequestsEnabled']) ??
            _readMaybeBool(profile['directRequestsEnabled']) ??
            _directRequestsOn;
        _nfcRequestsOn =
            _readMaybeBool(data['panel_nfcRequestEnabled']) ??
            _readMaybeBool(availability['nfcRequestEnabled']) ??
            _readMaybeBool(profile['nfcRequestEnabled']) ??
            _nfcRequestsOn;
      });
    } catch (_) {}
  }

  Future<void> _setDirectRequestsEnabled(bool value) async {
    setState(() {
      _directRequestsOn = value;
      _savingDirectRequestPref = true;
    });
    final ref = await _ensureArtistRow();
    if (!mounted) return;
    if (ref == null) {
      setState(() => _savingDirectRequestPref = false);
      return;
    }
    try {
      await _upsertArtistRow(ref.table, ref.id, {
        'panel_directRequestsEnabled': value,
        'availability': {'directRequestsEnabled': value},
        'profile': {'directRequestsEnabled': value},
        'communicationPreferences': _communicationPreferences.toMap(),
        'client': {
          'communicationPreferences': _communicationPreferences.toMap(),
        },
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update direct request preference.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingDirectRequestPref = false);
    }
  }

  Future<void> _setNfcRequestsEnabled(bool value) async {
    setState(() {
      _nfcRequestsOn = value;
      _savingNfcRequestPref = true;
    });
    final ref = await _ensureArtistRow();
    if (!mounted) return;
    if (ref == null) {
      setState(() => _savingNfcRequestPref = false);
      return;
    }
    try {
      await _upsertArtistRow(ref.table, ref.id, {
        'panel_nfcRequestEnabled': value,
        'availability': {'nfcRequestEnabled': value},
        'profile': {'nfcRequestEnabled': value},
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update NFC request preference.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingNfcRequestPref = false);
    }
  }

  void _openNotifications() {
    NotificationsPage.showAsModal(context);
  }

  Future<void> _editBasic() async {
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
        await _persistBasicInfo(previous: _profile.basic, next: updated.basic);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save personal information: $e')),
        );
        return;
      }
      if (!mounted) return;
      var localUpdated = updated;
      if (selectedPhotoBytes != null && selectedPhotoBytes.isNotEmpty) {
        final previewUrl =
            'data:image/jpeg;base64,${base64Encode(selectedPhotoBytes)}';
        localUpdated = updated.copyWith(
          basic: updated.basic.copyWith(profileImageUrl: previewUrl),
        );
      }
      setState(() => _profile = localUpdated);
      if (selectedPhotoBytes != null && selectedPhotoBytes.isNotEmpty) {
        unawaited(_saveProfilePhotoInBackground(selectedPhotoBytes));
      }
    }
  }

  Future<void> _editArtistProfile() async {
    final ref = await _artistModalRef();
    if (!mounted || ref == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load artist profile.')),
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistEditProfilePage(
            supabaseTable: ref.table,
            supabaseId: ref.id,
            initialData: ref.data,
          ),
        ),
      ),
    );
    if (mounted) await _loadProfileFromSupabase();
  }

  Future<void> _saveProfilePhotoInBackground(Uint8List bytes) async {
    try {
      final photoUrl = await EditPersonalInfoPopup.uploadProfilePhoto(bytes);
      final next = _profile.basic.copyWith(profileImageUrl: photoUrl);
      await _persistBasicInfo(previous: _profile.basic, next: next);
      if (mounted) {
        setState(() => _profile = _profile.copyWith(basic: next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo upload failed: $e')),
      );
    }
  }

  Future<void> _persistBasicInfo({
    required BasicInfo previous,
    required BasicInfo next,
  }) async {
    final identity = await _resolveIdentity();
    final uid = identity.uid;
    if (uid.isEmpty) {
      throw Exception('Missing signed-in user.');
    }
    final profileImage = next.profileImageUrl.trim();

    await _upsertArtistRow('client_artist', uid, {
      'email': next.email.trim(),
      'profile': {
        'name': next.name.trim(),
        'phone': next.phone.trim(),
        'profileImageUrl': profileImage,
        'photoUrl': profileImage,
        'avatarUrl': profileImage,
      },
      'basic': {
        'name': next.name.trim(),
        'email': next.email.trim(),
        'phone': next.phone.trim(),
        'profileImageUrl': profileImage,
        'photoUrl': profileImage,
        'avatarUrl': profileImage,
      },
      'client': {
        'email': next.email.trim(),
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
    }, email: next.email.trim());

    final profileChanged =
        previous.name.trim() != next.name.trim() ||
        previous.email.trim() != next.email.trim() ||
        previous.phone.trim() != next.phone.trim() ||
        previous.profileImageUrl.trim() != next.profileImageUrl.trim();
    if (!profileChanged) return;

    unawaited(_syncBasicInfoToRequests(previous: previous, next: next));
  }

  Future<void> _syncBasicInfoToRequests({
    required BasicInfo previous,
    required BasicInfo next,
  }) async {
    final profileImage = next.profileImageUrl.trim();
    final previousEmail = previous.email.trim().toLowerCase();
    if (previousEmail.isEmpty) return;

    try {
      final requests = await _supabase
          .from('client_custom_requests')
          .select()
          .eq('client_email', previousEmail);

      for (final raw in requests) {
        final doc = Map<String, dynamic>.from(raw as Map);
        final requestId = (doc['id'] ?? '').toString().trim();
        if (requestId.isEmpty) continue;
        await _supabase
            .from('client_custom_requests')
            .update({
              'clientName': next.name.trim(),
              'clientEmail': next.email.trim(),
              'clientProfileImage': profileImage,
              'clientProfilePic': profileImage,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', requestId);

        await _updateRequestDetails(
          'client_custom_requests_details',
          requestId,
          {
            'clientProfileSnapshot': {
              'basic': {
                'name': next.name.trim(),
                'email': next.email.trim(),
                'phone': next.phone.trim(),
                'profileImageUrl': profileImage,
                'photoUrl': profileImage,
                'avatarUrl': profileImage,
              },
            },
          },
        );
      }
    } catch (e) {
      debugPrint(
        'ClientArtistProfilePage: failed to sync basic info to requests: $e',
      );
    }
  }

  Future<void> _editPayment() async {
    final result = await showModalBottomSheet<PaymentInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPaymentInfoPage(initial: _profile.payment),
    );
    if (result != null) {
      try {
        await _persistPaymentInfo(result);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment details: $e')),
        );
        return;
      }
      setState(() => _profile = _profile.copyWith(payment: result));
    }
  }

  Future<void> _persistPaymentInfo(PaymentInfo payment) async {
    final identity = await _resolveIdentity();
    final uid = identity.uid;
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

    await _upsertArtistRow('client_artist', uid, {
      'payment': payload,
      'client': {'payment': payload},
    }, email: identity.email);
  }

  Future<void> _editShipping() async {
    final result = await showModalBottomSheet<AddressInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditShippingAddressPopup(initial: _profile.address),
    );
    if (result != null) {
      setState(() => _profile = _profile.copyWith(address: result));
    }
  }

  Future<void> _editMeasurements() async {
    final result = await showModalBottomSheet<NailPreferences>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditMeasurementsPopup(initial: _profile.nail),
    );
    if (result != null) {
      try {
        await _persistNailPreferences(result);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save nail measurements: $e')),
        );
        return;
      }
      setState(() => _profile = _profile.copyWith(nail: result));
    }
  }

  Future<void> _persistNailPreferences(NailPreferences nail) async {
    final identity = await _resolveIdentity();
    final uid = identity.uid;
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

    await _upsertArtistRow('client_artist', uid, {
      'nailPreferences': payload,
      'client': {'nailPreferences': payload},
    }, email: identity.email);
  }

  Future<void> _loadCommunicationPreferences() async {
    try {
      final data = (await _ensureArtistRow())?.data;
      if (!mounted || data == null) return;

      final topPrefs =
          (data['communicationPreferences'] as Map<String, dynamic>?) ??
          const {};
      final nestedPrefs =
          ((data['client']
                  as Map<String, dynamic>?)?['communicationPreferences']
              as Map<String, dynamic>?) ??
          const {};
      final source = topPrefs.isNotEmpty ? topPrefs : nestedPrefs;

      setState(() {
        _communicationPreferences = source.isEmpty
            ? ClientArtistCommunicationPreferences.defaults(
                pushNotifications: _directRequestsOn,
              )
            : ClientArtistCommunicationPreferences.fromMap(
                source,
                fallbackPushNotifications: _directRequestsOn,
              );
      });
    } catch (_) {}
  }

  Future<void> _saveCommunicationPreferences(
    ClientArtistCommunicationPreferences preferences,
  ) async {
    final identity = await _resolveIdentity();
    final uid = identity.uid;
    if (uid.isEmpty) return;

    await _upsertArtistRow('client_artist', uid, {
      'communicationPreferences': preferences.toMap(),
      'client': {'communicationPreferences': preferences.toMap()},
    }, email: identity.email);
  }

  Future<void> _editCommunicationPreference() async {
    final updatedPreference =
        await showModalBottomSheet<ClientArtistCommunicationPreferences>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ClientArtistCommunicationPreferencePopup(
            initialValue: _communicationPreferences,
          ),
        );

    if (updatedPreference != null) {
      try {
        await _saveCommunicationPreferences(updatedPreference);
      } catch (e) {
        debugPrint(
          'ClientArtistProfilePage: failed to save communication preferences: $e',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save communication preferences.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _communicationPreferences = updatedPreference);
    }
  }

  void _openPortfolio() {
    unawaited(_openPortfolioModal());
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _normalizeArtistYearsExperienceForModal(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase().replaceAll('–', '-').replaceAll('—', '-');
    if (lower.contains('10+') ||
        lower.contains('10 +') ||
        lower.contains('expert')) {
      return '10+ years (Expert)';
    }
    if (lower.contains('5-10') ||
        lower.contains('5 to 10') ||
        lower.contains('advanced')) {
      return '5–10 years (Advanced)';
    }
    if (lower.contains('3-5') ||
        lower.contains('3 to 5') ||
        lower.contains('skilled')) {
      return '3–5 years (Skilled)';
    }
    if (lower.contains('1-3') ||
        lower.contains('1 to 3') ||
        lower.contains('intermediate')) {
      return '1–3 years (Intermediate)';
    }
    if (lower.contains('0-1') ||
        lower.contains('0 to 1') ||
        lower.contains('beginner')) {
      return '0–1 years (Beginner)';
    }
    final number = int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), ''));
    if (number != null) {
      if (number <= 1) return '0–1 years (Beginner)';
      if (number <= 3) return '1–3 years (Intermediate)';
      if (number <= 5) return '3–5 years (Skilled)';
      if (number <= 10) return '5–10 years (Advanced)';
      return '10+ years (Expert)';
    }
    return value;
  }

  String _normalizeArtistPracticeDurationForModal(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase().replaceAll('–', '-').replaceAll('—', '-');
    if (lower.contains('2+') || lower.contains('2 +')) return '2+ years';
    if (lower.contains('1-2') || lower.contains('1 to 2')) return '1-2 years';
    if (lower.contains('6-12') || lower.contains('6 to 12'))
      return '6-12 months';
    if (lower.contains('3-6') || lower.contains('3 to 6')) return '3-6 months';
    if (lower.contains('< 3') || lower.contains('less than 3'))
      return '< 3 months';
    return value;
  }

  List<String> _asStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _asMapList(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(
          (value) => value.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList(growable: false);
  }

  List<ArtistPortfolioItem> _portfolioItemsFromData(Map<String, dynamic> data) {
    final portfolio =
        (data['portfolio'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final artist =
        (data['artist'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final artistPortfolio =
        (artist['portfolio'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final items = <ArtistPortfolioItem>[];
    final seen = <String>{};

    void add(String image, {String style = 'All'}) {
      final url = image.trim();
      if (url.isEmpty) return;
      final key = '$url|${style.trim().toLowerCase()}';
      if (!seen.add(key)) return;
      items.add(
        ArtistPortfolioItem(
          image: url,
          style: style.trim().isEmpty ? 'All' : style.trim(),
        ),
      );
    }

    void walk(dynamic raw, {String fallbackStyle = 'All'}) {
      if (raw == null) return;
      if (raw is String) {
        add(raw, style: fallbackStyle);
        return;
      }
      if (raw is List) {
        for (final item in raw) {
          walk(item, fallbackStyle: fallbackStyle);
        }
        return;
      }
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final image = _firstNonEmpty([
          map['imageUrl'],
          map['downloadUrl'],
          map['url'],
          map['image'],
          map['storagePath'],
          map['path'],
          map['fullPath'],
        ]);
        final style = _firstNonEmpty([
          map['style'],
          map['category'],
          map['type'],
          fallbackStyle,
        ]);
        if (image.isNotEmpty) {
          add(image, style: style);
        }
      }
    }

    for (final candidate in <dynamic>[
      data['portfolioImages'],
      data['portfolioItems'],
      data['panel_portfolioImages'],
      data['panel_artist_portfolioImages'],
      portfolio['images'],
      portfolio['items'],
      artist['portfolioImages'],
      artist['portfolioItems'],
      artistPortfolio['images'],
      artistPortfolio['items'],
    ]) {
      walk(candidate);
    }

    return items;
  }

  Future<void> _openPortfolioModal() async {
    final ref = await _artistModalRef();
    if (!mounted) return;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist portfolio not found.')),
      );
      return;
    }

    await _backfillCompletedRequestPhotosToPortfolio(ref);

    var initialItems = await _loadPortfolioInitialItems(ref);
    if (initialItems.isEmpty) {
      final recovered = await _recoverPortfolioFromStorageAndPersist(ref);
      if (recovered.isNotEmpty) {
        initialItems = recovered;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistPortfolioModal(
            supabaseTable: ref.table,
            supabaseId: ref.id,
            initialData: ref.data,
            initialItems: initialItems,
            onUploadTap:
                ({
                  List<XFile>? selectedFiles,
                  void Function(int completed, int total)? onProgress,
                }) async {
                  return _uploadPortfolioDesigns(
                    selectedFiles: selectedFiles,
                    onProgress: onProgress,
                  );
                },
          ),
        ),
      ),
    );
    await _loadProfileFromSupabase();
  }

  Future<void> _openSpecializationServiceArea() async {
    final ref = await _artistModalRef();
    if (!mounted) return;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specialization settings not found.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistSpecializationServiceAreaModal(
            supabaseTable: ref.table,
            supabaseId: ref.id,
            initialData: ref.data,
          ),
        ),
      ),
    );
    await _loadProfileFromSupabase();
  }

  Future<void> _backfillCompletedRequestPhotosToPortfolio(
    ({String table, String id, Map<String, dynamic> data}) ref,
  ) async {
    final email = (_currentUser?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return;
    final urls = <String>{};

    List<String> readPhotos(Map<String, dynamic> data) {
      final values = <String>{};
      void take(dynamic raw) {
        if (raw is List) {
          for (final v in raw) {
            final s = v.toString().trim();
            if (s.isNotEmpty) values.add(s);
          }
        }
      }

      take(data['artistCompletedPhotos']);
      take(data['artistUploadedPhotos']);
      take(data['artistImages']);
      return values.toList(growable: false);
    }

    Future<void> collectFromCollection(
      String collection, {
      required String ownerField,
    }) async {
      try {
        final snap = await _supabase
            .from(
              collection == 'Client_Custom_Requests'
                  ? 'client_custom_requests'
                  : 'company_custom_requests',
            )
            .select()
            .eq(
              ownerField == 'acceptedByArtistEmail'
                  ? 'accepted_by_artist_email'
                  : 'artist_email',
              email,
            )
            .limit(200);
        for (final raw in snap) {
          final data = Map<String, dynamic>.from(raw as Map);
          final status = (data['status'] ?? '').toString().trim().toLowerCase();
          final fromRoot = readPhotos(data);
          final hasCompletedStatus =
              status == 'completed' ||
              status == 'shipped' ||
              status == 'delivered';
          if (hasCompletedStatus || fromRoot.isNotEmpty) {
            urls.addAll(fromRoot);
          }

          try {
            final requestId = (data['id'] ?? '').toString().trim();
            if (requestId.isEmpty) continue;
            final detailRows = await _supabase
                .from(
                  collection == 'Client_Custom_Requests'
                      ? 'client_custom_requests_details'
                      : 'company_custom_requests_details',
                )
                .select()
                .eq('request_id', requestId)
                .limit(1);
            if (detailRows.isNotEmpty) {
              final payloadMap = Map<String, dynamic>.from(
                detailRows.first as Map,
              );
              final fromPayload = readPhotos(payloadMap);
              if (hasCompletedStatus || fromPayload.isNotEmpty) {
                urls.addAll(fromPayload);
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    Future<void> collectWithFallbackScan(String collection) async {
      try {
        final snap = await _supabase
            .from(
              collection == 'Client_Custom_Requests'
                  ? 'client_custom_requests'
                  : 'company_custom_requests',
            )
            .select()
            .order('updated_at', ascending: false)
            .limit(200);
        for (final raw in snap) {
          final data = Map<String, dynamic>.from(raw as Map);
          final owners = <String>{
            (data['acceptedByArtistEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase(),
            (data['artistEmail'] ?? '').toString().trim().toLowerCase(),
          };
          final acceptance =
              (data['acceptance'] as Map<String, dynamic>?) ?? const {};
          owners.add(
            (acceptance['acceptedByArtistEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase(),
          );
          owners.removeWhere((e) => e.isEmpty);
          if (!owners.contains(email)) {
            continue;
          }
          urls.addAll(readPhotos(data));
        }
      } catch (_) {}
    }

    await collectFromCollection(
      'Client_Custom_Requests',
      ownerField: 'acceptedByArtistEmail',
    );
    await collectFromCollection(
      'Client_Custom_Requests',
      ownerField: 'artistEmail',
    );
    await collectFromCollection(
      'Company_Custom_Requests',
      ownerField: 'acceptedByArtistEmail',
    );
    await collectFromCollection(
      'Company_Custom_Requests',
      ownerField: 'artistEmail',
    );

    if (urls.isEmpty) {
      await collectWithFallbackScan('Client_Custom_Requests');
      await collectWithFallbackScan('Company_Custom_Requests');
    }

    if (urls.isEmpty) return;

    final list = urls.toList(growable: false);
    final now = DateTime.now().toIso8601String();
    final itemMaps = list
        .map(
          (u) => <String, dynamic>{
            'imageUrl': u,
            'url': u,
            'image': u,
            'style': 'All',
            'source': 'artist_completed_set',
            'createdAt': now,
          },
        )
        .toList(growable: false);

    try {
      final existingImages = <String>{
        ..._asStringList(ref.data['portfolioImages']),
        ..._asStringList(ref.data['panel_portfolioImages']),
        ..._asStringList(ref.data['panel_artist_portfolioImages']),
      }..addAll(list);
      final existingItems = <Map<String, dynamic>>[
        ..._asMapList(ref.data['portfolioItems']),
        ...itemMaps,
      ];
      await _upsertArtistRow(ref.table, ref.id, {
        'portfolioImages': existingImages.toList(growable: false),
        'panel_portfolioImages': existingImages.toList(growable: false),
        'panel_artist_portfolioImages': existingImages.toList(growable: false),
        'portfolioItems': existingItems,
        'portfolio': {
          'images': existingImages.toList(growable: false),
          'items': existingItems,
        },
        'artist': {
          'portfolioImages': existingImages.toList(growable: false),
          'portfolioItems': existingItems,
          'portfolio': {
            'images': existingImages.toList(growable: false),
            'items': existingItems,
          },
        },
      });
    } catch (_) {}
  }

  Future<List<ArtistPortfolioItem>> _loadPortfolioInitialItems(
    ({String table, String id, Map<String, dynamic> data}) ref,
  ) async {
    final merged = <ArtistPortfolioItem>[];
    final seen = <String>{};

    void addItem(ArtistPortfolioItem item) {
      final url = item.image.trim();
      if (url.isEmpty) return;
      final key = '$url|${item.style.trim().toLowerCase()}';
      if (!seen.add(key)) return;
      merged.add(item);
    }

    try {
      final row =
          await _readProfileRow(
            table: ref.table,
            uid: ref.id,
            email: '',
          ).timeout(const Duration(seconds: 4)) ??
          ref.data;
      final data = row;
      for (final item in _portfolioItemsFromData(data)) {
        addItem(item);
      }
    } catch (_) {}

    if (merged.isNotEmpty) return merged;

    try {
      // Portfolio now reads from root row arrays only.
    } catch (_) {}

    return merged;
  }

  Future<List<ArtistPortfolioItem>> _recoverPortfolioFromStorageAndPersist(
    ({String table, String id, Map<String, dynamic> data}) ref,
  ) async {
    final ownerIds = <String>{ref.id.trim(), (_currentUser?.id ?? '').trim()}
      ..removeWhere((e) => e.isEmpty);

    final urls = <String>[];
    final seen = <String>{};

    bool isImageName(String name) {
      final n = name.toLowerCase();
      return n.endsWith('.jpg') ||
          n.endsWith('.jpeg') ||
          n.endsWith('.png') ||
          n.endsWith('.webp');
    }

    for (final owner in ownerIds) {
      for (final base in const <String>['client_artists', 'artists']) {
        try {
          final listed = await _supabase.storage
              .from(base)
              .list(path: '$owner/portfolio')
              .timeout(const Duration(seconds: 4));
          for (final item in listed) {
            final itemName = (item.name).trim();
            if (!isImageName(itemName)) continue;
            String resolved = '';
            try {
              resolved = _supabase.storage
                  .from(base)
                  .getPublicUrl('$owner/portfolio/$itemName')
                  .trim();
            } catch (_) {
              resolved = '$base/$owner/portfolio/$itemName';
            }
            final value = resolved.trim();
            if (value.isEmpty || !seen.add(value)) continue;
            urls.add(value);
            if (urls.length >= 36) break;
          }
        } catch (_) {}
        if (urls.length >= 36) break;
      }
      if (urls.length >= 36) break;
    }

    if (urls.isEmpty) return const <ArtistPortfolioItem>[];

    final itemMaps = urls
        .map((u) => <String, dynamic>{'imageUrl': u, 'style': 'All'})
        .toList(growable: false);

    try {
      await _upsertArtistRow(ref.table, ref.id, {
        'portfolioImages': urls,
        'panel_portfolioImages': urls,
        'panel_artist_portfolioImages': urls,
        'portfolioItems': itemMaps,
        'portfolio': {'images': urls, 'items': itemMaps},
        'artist': {
          'portfolioImages': urls,
          'portfolioItems': itemMaps,
          'portfolio': {'images': urls, 'items': itemMaps},
        },
      });
    } catch (_) {}

    return urls
        .map((u) => ArtistPortfolioItem(image: u, style: 'All'))
        .toList(growable: false);
  }

  Uint8List? _optimizePortfolioUploadBytes(
    Uint8List source, {
    int maxEdge = 1600,
    int maxBytes = 2 * 1024 * 1024,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
    img.Image processed = decoded;
    final maxSide = processed.width > processed.height
        ? processed.width
        : processed.height;
    if (maxSide > maxEdge) {
      final scale = maxEdge / maxSide;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }

    for (var quality = 88; quality >= 56; quality -= 8) {
      final encoded = img.encodeJpg(processed, quality: quality);
      final bytes = Uint8List.fromList(encoded);
      if (bytes.lengthInBytes <= maxBytes) return bytes;
    }
    final fallback = img.encodeJpg(processed, quality: 50);
    return Uint8List.fromList(fallback);
  }

  Future<List<ArtistPortfolioItem>> _uploadPortfolioDesigns({
    List<XFile>? selectedFiles,
    void Function(int completed, int total)? onProgress,
  }) async {
    final ref = await _artistModalRef();
    if (ref == null) return const <ArtistPortfolioItem>[];

    final picked =
        selectedFiles ??
        await ImagePicker().pickMultiImage(
          imageQuality: 78,
          maxWidth: 1600,
          maxHeight: 1600,
        );
    if (picked.isEmpty) return const <ArtistPortfolioItem>[];

    final isClientArtistDoc = ref.table == 'client_artist';
    final storageBases = isClientArtistDoc
        ? const <String>['client_artists', 'artists']
        : const <String>['artists', 'client_artists'];
    final ownerId = (_currentUser?.id ?? ref.id).trim();
    final now = DateTime.now().millisecondsSinceEpoch;

    final uploaded = <String>[];
    onProgress?.call(0, picked.length);

    Future<Map<String, String>?> uploadToBase({
      required String base,
      required Uint8List bytes,
      required int index,
      required int attempt,
    }) async {
      try {
        final objectPath =
            '$ownerId/portfolio/${now}_${index + 1}_a$attempt.jpg';
        await _supabase.storage
            .from(base)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        final url = _supabase.storage
            .from(base)
            .getPublicUrl(objectPath)
            .trim();
        final trimmed = url.trim();
        if (trimmed.isEmpty) return null;
        return <String, String>{'url': trimmed, 'path': '$base/$objectPath'};
      } catch (_) {
        return null;
      }
    }

    var completed = 0;
    for (var i = 0; i < picked.length; i++) {
      try {
        final raw = await picked[i].readAsBytes();
        if (raw.isEmpty) continue;

        Uint8List bytes = raw;
        final optimized = _optimizePortfolioUploadBytes(bytes);
        if (optimized != null && optimized.isNotEmpty) {
          bytes = optimized;
        }

        Map<String, String>? uploadedData;
        for (final base in storageBases) {
          uploadedData = await uploadToBase(
            base: base,
            bytes: bytes,
            index: i,
            attempt: 1,
          );
          if (uploadedData != null) break;
        }

        if (uploadedData == null) {
          final tiny =
              _optimizePortfolioUploadBytes(
                bytes,
                maxEdge: 800,
                maxBytes: 220 * 1024,
              ) ??
              bytes;
          uploadedData = <String, String>{
            'url': 'data:image/jpeg;base64,${base64Encode(tiny)}',
            'path': '',
          };
        }

        final url = (uploadedData['url'] ?? '').trim();
        if (url.isEmpty) continue;
        uploaded.add(url);
      } catch (_) {
      } finally {
        completed += 1;
        onProgress?.call(completed, picked.length);
      }
    }

    if (uploaded.isEmpty) return const <ArtistPortfolioItem>[];

    final itemMaps = uploaded
        .map((url) => <String, dynamic>{'imageUrl': url, 'style': 'All'})
        .toList(growable: false);

    try {
      final existingImages = <String>{
        ..._asStringList(ref.data['portfolioImages']),
        ..._asStringList(ref.data['panel_portfolioImages']),
        ..._asStringList(ref.data['panel_artist_portfolioImages']),
        ...uploaded,
      }.toList(growable: false);
      final existingItems = <Map<String, dynamic>>[
        ..._asMapList(ref.data['portfolioItems']),
        ...itemMaps,
      ];
      await _upsertArtistRow(ref.table, ref.id, {
        'portfolioImages': existingImages,
        'panel_portfolioImages': existingImages,
        'panel_artist_portfolioImages': existingImages,
        'portfolioItems': existingItems,
        'portfolio': {'images': existingImages, 'items': existingItems},
        'artist': {
          'portfolioImages': existingImages,
          'portfolioItems': existingItems,
          'portfolio': {'images': existingImages, 'items': existingItems},
        },
      });
    } catch (_) {}

    return uploaded
        .map((url) => ArtistPortfolioItem(image: url, style: 'All'))
        .toList(growable: false);
  }

  Future<void> _openPayoutSettings() async {
    final ref = await _artistModalRef();
    if (!mounted) return;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout settings not found.')),
      );
      return;
    }

    Map<String, dynamic> initialData = const <String, dynamic>{};
    try {
      initialData = ref.data;
    } catch (_) {}

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistPayoutSettingsPage(
            supabaseTable: ref.table,
            supabaseId: ref.id,
            initialData: initialData,
          ),
        ),
      ),
    );
  }

  Map<String, String> _availabilityDayStatesFromData(
    Map<String, dynamic> data,
  ) {
    final panel =
        (data['panel_availability'] as Map<String, dynamic>?) ??
        (data['availability'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final raw = panel['dayStates'];
    if (raw is! Map) return const <String, String>{};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final k = key.toString().trim();
      final v = value.toString().trim().toLowerCase();
      if (k.isEmpty || v.isEmpty) return;
      if (v == 'direct' || v == 'blocked' || v == 'unavailable') {
        out[k] = v;
      }
    });
    return out;
  }

  bool _readDirectRequestsValue(Map<String, dynamic> data) {
    bool? asBool(Object? v) {
      if (v is bool) return v;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true') return true;
        if (t == 'false') return false;
      }
      if (v is num) return v != 0;
      return null;
    }

    final availability =
        (data['availability'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final profile =
        (data['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return asBool(data['panel_directRequestsEnabled']) ??
        asBool(availability['directRequestsEnabled']) ??
        asBool(profile['directRequestsEnabled']) ??
        _directRequestsOn;
  }

  Future<void> _openAvailability() async {
    final ref = await _artistModalRef();
    if (!mounted) return;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability settings not found.')),
      );
      return;
    }

    Map<String, dynamic> initialData = const <String, dynamic>{};
    try {
      initialData = ref.data;
    } catch (_) {}

    final states = _availabilityDayStatesFromData(initialData);
    final initialDirect = _readDirectRequestsValue(initialData);

    if (mounted) {
      setState(() => _directRequestsOn = initialDirect);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistAvailabilityModal(
            supabaseTable: ref.table,
            supabaseId: ref.id,
            initialDirectRequestsEnabled: initialDirect,
            initialDayStates: states,
            onDirectRequestChanged: (value) async {
              try {
                await _upsertArtistRow(ref.table, ref.id, {
                  'panel_directRequestsEnabled': value,
                  'availability': {'directRequestsEnabled': value},
                });
              } catch (e) {
                debugPrint(
                  'ClientArtistProfilePage: failed to update direct requests: $e',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to update direct request preference.',
                      ),
                    ),
                  );
                }
                return;
              }
              if (mounted) {
                setState(() => _directRequestsOn = value);
              }
            },
          ),
        ),
      ),
    );
  }

  void _openAscension() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JntAscensionPage()),
    );
  }

  void _closeProfilePage() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _onBottomNavTap(0);
  }

  void _onBottomNavTap(int i) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistHomePage(
          showContinueProfileCard: !_profile.isComplete,
          enableAllTabs: _profile.isComplete,
          profile: _profile,
          initialTabIndex: i,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Client artist profile',
      child: Scaffold(
        backgroundColor: AppColors.snow,

        // ✅ Your custom header
        appBar: JntModalAppBar(
          onClose: _closeProfilePage,
          closeTooltip: 'Close profile',
          leading: NotificationBellButton(
            onTap: _openNotifications,
            iconSize: JntHeaderMetrics.notificationIconSize,
          ),
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntModalHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),

        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              _headerGradientCard(
                child: Column(
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: SizedBox(
                            height: 92,
                            width: 92,
                            child: ClientProfileAvatarIcon(
                              imageUrl: _profile.basic.profileImageUrl,
                              displayName: _profile.basic.name,
                              size: 92,
                              resolveCurrentUserFallback: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _profile.basic.name.trim().isEmpty
                              ? 'Client Artist'
                              : _profile.basic.name.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.blackCat,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile.basic.email.trim().isEmpty
                              ? '—'
                              : _profile.basic.email.trim(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w400,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_profile.address.city.trim()}, ${_profile.address.state.trim()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.60),
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                        if (_showClientTab && _hasAmbassadorTag(_profileData))
                          _buildProfileTag('Ambassador')
                        else if (!_showClientTab)
                          _buildProfileTag(
                            _resolveArtistTierLabel(_profileData),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const SizedBox(height: 8),
                    _profileTabs(),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (_showClientTab) ...[
                _menuTile(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  onTap: _editBasic,
                ),
                _menuTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Payment Methods',
                  onTap: _editPayment,
                ),
                _menuTile(
                  icon: Icons.location_on_outlined,
                  title: 'Shipping Address',
                  onTap: _editShipping,
                ),
                _menuTile(
                  icon: Icons.straighten_outlined,
                  title: 'Measurements',
                  onTap: _editMeasurements,
                ),
                _menuTile(
                  icon: Icons.notifications_outlined,
                  title: 'Communication Preference',
                  onTap: _editCommunicationPreference,
                ),
              ] else ...[
                _menuTile(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: () {
                    unawaited(_editArtistProfile());
                  },
                ),
                _menuTile(
                  icon: Icons.image_outlined,
                  title: 'Portfolio',
                  onTap: _openPortfolio,
                ),
                _menuTile(
                  icon: Icons.tune_rounded,
                  title: 'Specialization & Service Area',
                  onTap: () {
                    unawaited(_openSpecializationServiceArea());
                  },
                ),
                _menuTile(
                  icon: Icons.payments_outlined,
                  title: 'Payout Settings',
                  onTap: () {
                    unawaited(_openPayoutSettings());
                  },
                ),
                _menuTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Availability',
                  onTap: () {
                    unawaited(_openAvailability());
                  },
                ),
                // Direct Requests toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.blackCatBorderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.blackCat,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Direct Requests',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _directRequestsOn
                                  ? 'Accepting requests now 😊'
                                  : 'Not accepting requests',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.55,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _directRequestsOn,
                        activeThumbColor: AppColors.blackCat,
                        inactiveThumbColor: AppColors.blackCatLight,
                        inactiveTrackColor: AppColors.blackCatLight.withValues(
                          alpha: 0.35,
                        ),
                        onChanged: _savingDirectRequestPref
                            ? null
                            : (v) => _setDirectRequestsEnabled(v),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.blackCatBorderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.nfc_rounded,
                        color: AppColors.blackCat,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NFC Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _nfcRequestsOn
                                  ? 'Accepting NFC upgrade requests'
                                  : 'Not accepting NFC upgrade requests',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.55,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _nfcRequestsOn,
                        activeThumbColor: AppColors.blackCat,
                        inactiveThumbColor: AppColors.blackCatLight,
                        inactiveTrackColor: AppColors.blackCatLight.withValues(
                          alpha: 0.35,
                        ),
                        onChanged: _savingNfcRequestPref
                            ? null
                            : (v) => _setNfcRequestsEnabled(v),
                      ),
                    ],
                  ),
                ),
                _menuTile(
                  icon: Icons.star_outline_rounded,
                  title: 'JNT Ascension',
                  onTap: _openAscension,
                ),
              ],

              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 180,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false),
                    child: const Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.snow,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          backgroundColor: AppColors.balletSlippers,
          selectedItemColor: AppColors.blackCat,
          unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
          type: BottomNavigationBarType.fixed,
          onTap: _onBottomNavTap,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Design',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inbox_outlined),
              activeIcon: Icon(Icons.inbox),
              label: 'Requests',
            ),
            if (_showCampaignsTab)
              const BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                activeIcon: Icon(Icons.campaign),
                label: 'Campaigns',
              ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            if (!_showCampaignsTab)
              const BottomNavigationBarItem(
                icon: Icon(Icons.attach_money_outlined),
                activeIcon: Icon(Icons.attach_money),
                label: 'Earnings',
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // Widgets
  // -----------------------

  Widget _headerGradientCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );
  }

  Widget _profileTabs() {
    return Container(
      color: AppColors.snow,
      child: Row(
        children: [
          Expanded(
            child: _segPill(
              text: 'Client Profile',
              selected: _showClientTab,
              onTap: () => setState(() => _showClientTab = true),
            ),
          ),
          Expanded(
            child: _segPill(
              text: 'Artist Profile',
              selected: !_showClientTab,
              onTap: () => setState(() => _showClientTab = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segPill({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.snow,
              border: Border(
                bottom: BorderSide(
                  color: selected
                      ? AppColors.balletSlippers
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.blackCat
                    : AppColors.blackCat.withValues(alpha: 0.60),
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.blackCatBorderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.blackCat, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PreferredContactMethod { email, push, sms }

class _CommunicationPreferences {
  const _CommunicationPreferences({
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

class _CommunicationPreferencePopup extends StatefulWidget {
  const _CommunicationPreferencePopup({required this.initialValue});
  final _CommunicationPreferences initialValue;

  @override
  State<_CommunicationPreferencePopup> createState() =>
      _CommunicationPreferencePopupState();
}

class _CommunicationPreferencePopupState
    extends State<_CommunicationPreferencePopup> {
  late bool _emailNotifications;
  late bool _smsNotifications;
  late bool _pushNotifications;
  late bool _accountActivity;
  late bool _securityAlerts;
  late bool _promotionsOffers;
  late bool _reminders;
  late bool _newsUpdates;
  late _PreferredContactMethod _preferredContact;
  late bool _marketingConsent;

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
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: AppColors.alabaster,
          borderRadius: BorderRadius.zero,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blackCat.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.blackCat.withValues(alpha: 0.90),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.blackCat.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _switchTile(
                        title: 'Email Notifications',
                        value: _emailNotifications,
                        onChanged: (v) =>
                            setState(() => _emailNotifications = v),
                      ),
                      _switchTile(
                        title: 'SMS Notifications',
                        value: _smsNotifications,
                        onChanged: (v) => setState(() => _smsNotifications = v),
                      ),
                      _switchTile(
                        title: 'Push Notifications',
                        value: _pushNotifications,
                        onChanged: (v) =>
                            setState(() => _pushNotifications = v),
                      ),
                      const SizedBox(height: 10),
                      _checkboxTile(
                        'Account Activity',
                        _accountActivity,
                        (v) => setState(() => _accountActivity = v),
                      ),
                      _checkboxTile(
                        'Security Alerts',
                        _securityAlerts,
                        (v) => setState(() => _securityAlerts = v),
                      ),
                      _checkboxTile(
                        'Promotions & Offers',
                        _promotionsOffers,
                        (v) => setState(() => _promotionsOffers = v),
                      ),
                      _checkboxTile(
                        'Reminders',
                        _reminders,
                        (v) => setState(() => _reminders = v),
                      ),
                      _checkboxTile(
                        'News & Updates',
                        _newsUpdates,
                        (v) => setState(() => _newsUpdates = v),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _methodChip('Email', _PreferredContactMethod.email),
                          _methodChip('Push', _PreferredContactMethod.push),
                          _methodChip('SMS', _PreferredContactMethod.sms),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _checkboxTile(
                        'I agree to receive marketing communications.',
                        _marketingConsent,
                        (v) => setState(() => _marketingConsent = v),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: () =>
                              Navigator.pop(context, _currentPreferences),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Arial',
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
    );
  }

  _CommunicationPreferences get _currentPreferences =>
      _CommunicationPreferences(
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

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              activeThumbColor: AppColors.blackCat,
              inactiveThumbColor: AppColors.blackCatLight,
              inactiveTrackColor: AppColors.blackCatLight.withValues(
                alpha: 0.35,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkboxTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Semantics(
      button: true,
      checked: value,
      label: title,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              Checkbox(
                value: value,
                activeColor: AppColors.blackCat,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodChip(String label, _PreferredContactMethod method) {
    final selected = _preferredContact == method;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      selectedColor: AppColors.balletSlippers,
      side: BorderSide(
        color: selected ? AppColors.alabaster : AppColors.alabaster,
      ),
      onSelected: (_) => setState(() => _preferredContact = method),
    );
  }
}
