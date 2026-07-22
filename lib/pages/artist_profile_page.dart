import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/artist_ascension.dart';
import '../theme/app_colors.dart';
import '../services/auth_email_alias_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_bootstrap.dart';
import 'jnt_ascension_page.dart';
import 'notifications_page.dart';
import 'artist_reviews_page.dart';
import '../widgets/artist_ascension_card.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/searchable_dropdown_field.dart';

String _storageBucketForReference(String raw) {
  final value = raw.trim();
  if (value.startsWith('gs://')) {
    final withoutScheme = value.substring(5);
    final slash = withoutScheme.indexOf('/');
    if (slash > 0) return withoutScheme.substring(0, slash);
  }
  if (value.startsWith('profile-pictures/')) return 'profile-pictures';
  if (value.startsWith('artists/')) return 'artists';
  if (value.startsWith('client_artists/')) return 'client_artists';
  return 'portfolio-images';
}

String _storageObjectPathForReference(String raw) {
  final value = raw.trim();
  if (value.startsWith('gs://')) {
    final withoutScheme = value.substring(5);
    final slash = withoutScheme.indexOf('/');
    if (slash > 0 && slash + 1 < withoutScheme.length) {
      return withoutScheme.substring(slash + 1);
    }
    return '';
  }
  if (value.startsWith('profile-pictures/')) {
    return value.replaceFirst('profile-pictures/', '');
  }
  if (value.startsWith('artists/') || value.startsWith('client_artists/')) {
    final parts = value.split('/');
    return parts.skip(1).join('/');
  }
  return value;
}

class ArtistProfilePage extends StatefulWidget {
  const ArtistProfilePage({
    super.key,
    this.showBottomNav = false,
    this.bottomNavIndex = 0,
    this.onNavTap,
  });

  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  State<ArtistProfilePage> createState() => _ArtistProfilePageState();
}

class _ArtistIdentity {
  const _ArtistIdentity({required this.uid, required this.email});

  final String uid;
  final String email;
}

class _ArtistProfilePageState extends State<ArtistProfilePage> {
  static const int _maxPortfolioUploadBytes = 2 * 1024 * 1024; // 2MB
  static const int _preferredPortfolioUploadBytes = 650 * 1024; // ~650KB
  static const int _portfolioMaxEdge = 1600;
  bool _loggingOutFromProfile = false;
  bool _directRequestsEnabled = true;
  bool _savingDirectRequestPref = false;
  bool _nfcRequestsEnabled = false;
  bool _savingNfcRequestPref = false;
  bool _allClientRequestNotificationsEnabled = true;
  bool _savingAllClientRequestNotifications = false;
  Map<String, dynamic> _artistData = const <String, dynamic>{};
  String _artistSupabaseTable = '';
  String _artistSupabaseId = '';
  bool _portfolioBackfillAttempted = false;

  Future<_ArtistIdentity> _resolveArtistIdentity() async {
    final supabaseUser = SupabaseAuthService.currentUser;
    final supabaseId = (supabaseUser?.id ?? '').trim();
    final supabaseEmail = (supabaseUser?.email ?? '').trim().toLowerCase();
    final aliasUid = supabaseEmail.isNotEmpty
        ? await AuthEmailAliasService.resolveUidForLogin(supabaseEmail)
        : null;
    return _ArtistIdentity(
      uid: supabaseId.isNotEmpty ? supabaseId : (aliasUid ?? ''),
      email: supabaseEmail,
    );
  }

  @override
  void initState() {
    super.initState();
    _bindArtistProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map)
      return value.map((key, value) => MapEntry(key.toString(), value));
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _readSupabaseArtistRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    final client = SupabaseBootstrap.client;

    Future<Map<String, dynamic>?> firstRow(
      PostgrestFilterBuilder<dynamic> query,
    ) async {
      try {
        final rows = await query.limit(1);
        if (rows is List && rows.isNotEmpty && rows.first is Map) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (e) {
        debugPrint('Supabase artist lookup failed for $table: $e');
      }
      return null;
    }

    if (uid.isNotEmpty) {
      final byId = await firstRow(client.from(table).select().eq('id', uid));
      if (byId != null) return byId;

      final byUid = await firstRow(client.from(table).select().eq('uid', uid));
      if (byUid != null) return byUid;
    }

    if (email.isNotEmpty) {
      final byEmail = await firstRow(
        client.from(table).select().eq('email', email),
      );
      if (byEmail != null) return byEmail;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadSupabaseArtistProfile(
    _ArtistIdentity identity,
  ) async {
    final uid = identity.uid.trim();
    final email = identity.email.trim().toLowerCase();

    for (final table in const <String>['artist', 'client_artist']) {
      final row = await _readSupabaseArtistRow(
        table: table,
        uid: uid,
        email: email,
      );
      if (row == null) continue;

      _artistSupabaseTable = table;
      _artistSupabaseId = _firstNonEmpty([row['id'], row['uid'], uid]);

      return row;
    }

    return null;
  }

  Future<void> _syncSupabaseArtistFields(Map<String, dynamic> fields) async {
    final table = _artistSupabaseTable.trim();
    final id = _artistSupabaseId.trim();
    if (table.isEmpty || id.isEmpty || fields.isEmpty) return;

    try {
      await SupabaseBootstrap.client.from(table).update(fields).eq('id', id);
    } catch (e) {
      debugPrint('Supabase artist update failed: $e');
    }
  }

  Map<String, dynamic> _firestoreCompatArtistData(Map<String, dynamic> row) {
    final profile = _asMap(row['profile']);
    final basic = _asMap(row['basic']);
    final name = _firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      profile['name'],
      row['displayName'],
      row['display_name'],
      row['studioName'],
      row['studio_name'],
      row['name'],
      basic['name'],
    ]);
    final avatar = _cleanAvatarValue(
      _firstNonEmpty([
        profile['profileImageUrl'],
        profile['profilePhotoUrl'],
        profile['profile_picture_url'],
        profile['profile_photo_url'],
        profile['photoUrl'],
        profile['photo_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profilePhotoUrl'],
        row['profile_photo_url'],
        row['profile_picture_url'],
        row['photoUrl'],
        row['photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        basic['profileImageUrl'],
        basic['profile_picture_url'],
        basic['profile_photo_url'],
        basic['photoUrl'],
        basic['photo_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        _asMap(row['artist'])['profileImageUrl'],
        _asMap(row['artist'])['profile_picture_url'],
        _asMap(row['artist'])['profile_photo_url'],
        _asMap(row['artist'])['photoUrl'],
        _asMap(row['artist'])['photo_url'],
        _asMap(row['artist'])['avatarUrl'],
        _asMap(row['artist'])['avatar_url'],
      ]),
    );

    return <String, dynamic>{
      ...row,
      'displayName': name,
      'name': name,
      'studioName': _firstNonEmpty([
        profile['studioName'],
        profile['studio_name'],
        row['studioName'],
        row['studio_name'],
      ]),
      'profileImageUrl': avatar,
      'photoUrl': avatar,
      'avatarUrl': avatar,
      'panel_displayName': name,
      'panel_studioName': _firstNonEmpty([
        profile['studioName'],
        profile['studio_name'],
        row['panel_studioName'],
        row['panel_studio_name'],
        row['studioName'],
        row['studio_name'],
      ]),
      'panel_directRequestsEnabled': row['panel_directRequestsEnabled'] ?? row['panel_direct_requests_enabled'],
      'panel_nfcRequestEnabled': row['panel_nfcRequestEnabled'] ?? row['panel_nfc_request_enabled'],
      'panel_allClientRequestNotificationsEnabled':
          row['panel_allClientRequestNotificationsEnabled'] ??
          row['panel_all_client_request_notifications_enabled'],
      'panel_profileImageUrl': avatar,
      'profile': <String, dynamic>{
        ...profile,
        if (!profile.containsKey('directRequestsEnabled') &&
            profile.containsKey('direct_requests_enabled'))
          'directRequestsEnabled': profile['direct_requests_enabled'],
        if (!profile.containsKey('nfcRequestEnabled') &&
            profile.containsKey('nfc_request_enabled'))
          'nfcRequestEnabled': profile['nfc_request_enabled'],
        if (!profile.containsKey('allClientRequestsEnabled') &&
            profile.containsKey('all_client_requests_enabled'))
          'allClientRequestsEnabled': profile['all_client_requests_enabled'],
        if (name.isNotEmpty) 'displayName': name,
        if (avatar.isNotEmpty) 'profileImageUrl': avatar,
        if (avatar.isNotEmpty) 'photoUrl': avatar,
        if (avatar.isNotEmpty) 'avatarUrl': avatar,
      },
      'availability': <String, dynamic>{
        ..._asMap(row['availability']),
        if (!_asMap(row['availability']).containsKey('directRequestsEnabled') &&
            _asMap(row['availability']).containsKey('direct_requests_enabled'))
          'directRequestsEnabled':
              _asMap(row['availability'])['direct_requests_enabled'],
        if (!_asMap(row['availability']).containsKey('nfcRequestEnabled') &&
            _asMap(row['availability']).containsKey('nfc_request_enabled'))
          'nfcRequestEnabled':
              _asMap(row['availability'])['nfc_request_enabled'],
      },
      'notifications': <String, dynamic>{
        ..._asMap(row['notifications']),
        if (!_asMap(row['notifications']).containsKey('allClientRequestsEnabled') &&
            _asMap(row['notifications']).containsKey('all_client_requests_enabled'))
          'allClientRequestsEnabled':
              _asMap(row['notifications'])['all_client_requests_enabled'],
      },
    };
  }

  Future<void> _bindArtistProfile() async {
    final identity = await _resolveArtistIdentity();
    if (identity.uid.trim().isEmpty && identity.email.trim().isEmpty) {
      return;
    }

    final supabaseRow = await _loadSupabaseArtistProfile(identity);
    if (supabaseRow == null) return;

    final compatData = _firestoreCompatArtistData(supabaseRow);
    final nextDirect = _readBool(
      compatData['panel_directRequestsEnabled'],
      (compatData['availability']
          as Map<String, dynamic>?)?['directRequestsEnabled'],
      (compatData['profile']
          as Map<String, dynamic>?)?['directRequestsEnabled'],
    );
    final nextNfc =
        _readMaybeBool(
          compatData['panel_nfcRequestEnabled'],
          (compatData['availability']
              as Map<String, dynamic>?)?['nfcRequestEnabled'],
          (compatData['profile']
              as Map<String, dynamic>?)?['nfcRequestEnabled'],
        ) ??
        false;
    final nextAllClientNotifications = _readBool(
      compatData['panel_allClientRequestNotificationsEnabled'],
      (compatData['notifications']
          as Map<String, dynamic>?)?['allClientRequestsEnabled'],
      (compatData['profile']
          as Map<String, dynamic>?)?['allClientRequestsEnabled'],
    );

    if (mounted) {
      setState(() {
        _artistData = compatData;
        _directRequestsEnabled = nextDirect;
        _nfcRequestsEnabled = nextNfc;
        _allClientRequestNotificationsEnabled = nextAllClientNotifications;
      });
    }
  }

  bool _readBool(Object? a, [Object? b, Object? c]) {
    for (final v in <Object?>[a, b, c]) {
      if (v is bool) return v;
      if (v is String) {
        final text = v.trim().toLowerCase();
        if (text == 'true') return true;
        if (text == 'false') return false;
      }
      if (v is num) return v != 0;
    }
    return true;
  }

  bool? _readMaybeBool(Object? a, [Object? b, Object? c]) {
    for (final v in <Object?>[a, b, c]) {
      if (v is bool) return v;
      if (v is String) {
        final text = v.trim().toLowerCase();
        if (text == 'true') return true;
        if (text == 'false') return false;
      }
      if (v is num) return v != 0;
    }
    return null;
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _cleanAvatarValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.startsWith('assets/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';
    return text;
  }

  String get _artistName {
    final profile =
        (_artistData['profile'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return _firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      _artistData['panel_displayName'],
      _artistData['panel_studioName'],
      _artistData['displayName'],
      _artistData['name'],
      'Artist',
    ]);
  }

  String get _avatarPath {
    final profile = _asMap(_artistData['profile']);
    final basic = _asMap(_artistData['basic']);
    final artist = _asMap(_artistData['artist']);
    return _cleanAvatarValue(
      _firstNonEmpty([
        profile['photoUrl'],
        profile['photo_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profilePhotoUrl'],
        profile['profile_photo_url'],
        profile['profile_picture_url'],
        profile['photoURL'],
        profile['avatarURL'],
        profile['profilePhoto'],
        _artistData['photoUrl'],
        _artistData['photo_url'],
        _artistData['avatarUrl'],
        _artistData['avatar_url'],
        _artistData['panel_profileImageUrl'],
        _artistData['profileImageUrl'],
        _artistData['profile_image_url'],
        _artistData['profilePhotoUrl'],
        _artistData['profile_photo_url'],
        _artistData['profile_picture_url'],
        _artistData['profilePhoto'],
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        basic['photoUrl'],
        basic['photo_url'],
        basic['profilePhotoUrl'],
        basic['profile_photo_url'],
        basic['profile_picture_url'],
        basic['profilePhoto'],
        artist['profileImageUrl'],
        artist['profile_image_url'],
        artist['avatarUrl'],
        artist['avatar_url'],
        artist['photoUrl'],
        artist['photo_url'],
        artist['profilePhotoUrl'],
        artist['profile_photo_url'],
        artist['profile_picture_url'],
      ]),
    );
  }

  ArtistAscensionState get _ascensionState =>
      artistAscensionFromDoc(_artistData);

  double? get _rating {
    final stats =
        (_artistData['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    for (final raw in <Object?>[
      stats['rating'],
      stats['averageRating'],
      _artistData['rating'],
      _artistData['averageRating'],
      _artistData['panel_rating'],
    ]) {
      if (raw is num && raw > 0) return raw.toDouble();
      if (raw is String) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  int get _reviews {
    final stats =
        (_artistData['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    for (final raw in <Object?>[
      stats['reviews'],
      stats['reviewCount'],
      _artistData['reviews'],
      _artistData['reviewCount'],
      _artistData['panel_reviews'],
    ]) {
      if (raw is num && raw >= 0) return raw.round();
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null && parsed >= 0) return parsed;
      }
    }
    return 0;
  }

  Future<void> _setDirectRequestsEnabled(bool value) async {
    setState(() {
      _directRequestsEnabled = value;
      _savingDirectRequestPref = true;
    });
    try {
      await _syncSupabaseArtistFields({
        'availability': {'directRequestsEnabled': value},
        'profile': {
          ..._asMap(_artistData['profile']),
          'directRequestsEnabled': value,
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
      if (mounted) {
        setState(() => _savingDirectRequestPref = false);
      }
    }
  }

  Future<void> _setNfcRequestsEnabled(bool value) async {
    setState(() {
      _nfcRequestsEnabled = value;
      _savingNfcRequestPref = true;
    });
    try {
      await _syncSupabaseArtistFields({
        'availability': {
          ..._asMap(_artistData['availability']),
          'nfcRequestEnabled': value,
        },
        'profile': {
          ..._asMap(_artistData['profile']),
          'nfcRequestEnabled': value,
        },
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update NFC request preference.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingNfcRequestPref = false);
      }
    }
  }

  Future<void> _setAllClientRequestNotificationsEnabled(bool value) async {
    setState(() {
      _allClientRequestNotificationsEnabled = value;
      _savingAllClientRequestNotifications = true;
    });
    try {
      await _syncSupabaseArtistFields({
        'notifications': {
          ..._asMap(_artistData['notifications']),
          'allClientRequestsEnabled': value,
          'directRequestNotificationsEnabled': true,
        },
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update notification preference.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAllClientRequestNotifications = false);
      }
    }
  }

  void _onNotifications() {
    NotificationsPage.showAsModal(context);
  }

  Future<void> _logoutFromProfile() async {
    if (_loggingOutFromProfile) return;
    setState(() => _loggingOutFromProfile = true);
    try {
      await SupabaseBootstrap.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loggingOutFromProfile = false);
    }
  }

  Future<void> _onEditProfile() async {
    if (_artistSupabaseId.isEmpty) await _bindArtistProfile();
    if (_artistSupabaseId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistEditProfilePage(
            supabaseTable: _artistSupabaseTable,
            supabaseId: _artistSupabaseId,
            initialData: _artistData,
          ),
        ),
      ),
    );
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
    final List<ArtistPortfolioItem> items = <ArtistPortfolioItem>[];

    void addFromAny(Object? raw, {String fallbackStyle = 'All'}) {
      if (raw == null) return;
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty || !_isPortfolioImageValue(s)) return;
        items.add(ArtistPortfolioItem(image: s, style: fallbackStyle));
        return;
      }
      if (raw is List) {
        for (final item in raw) {
          addFromAny(item, fallbackStyle: fallbackStyle);
        }
        return;
      }
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final image = _firstNonEmpty([
          map['imageUrl'],
          map['imageURL'],
          map['downloadUrl'],
          map['downloadURL'],
          map['photoUrl'],
          map['photoURL'],
          map['url'],
          map['image'],
        ]);
        if (image.isNotEmpty && _isPortfolioImageValue(image)) {
          final style = _firstNonEmpty([
            map['style'],
            map['category'],
            map['type'],
            fallbackStyle,
          ]);
          items.add(ArtistPortfolioItem(image: image, style: style));
        }
        for (final value in map.values) {
          if (value is List || value is Map) {
            addFromAny(value, fallbackStyle: fallbackStyle);
          }
        }
      }
    }

    addFromAny(portfolio['items']);
    addFromAny(portfolio['images']);
    addFromAny(data['portfolio_items']);
    addFromAny(data['portfolio_images']);
    addFromAny(data['panel_portfolio_images']);
    addFromAny(data['panel_artist_portfolio_images']);
    addFromAny(artistPortfolio['items']);
    addFromAny(artistPortfolio['images']);
    addFromAny(artist['portfolioItems']);
    addFromAny(artist['portfolio_items']);
    addFromAny(artist['portfolioImages']);
    addFromAny(artist['portfolio_images']);

    return items;
  }

  Future<void> _appendPortfolioItemsToSupabase(
    List<ArtistPortfolioItem> newItems,
  ) async {
    final table = _artistSupabaseTable.trim();
    final id = _artistSupabaseId.trim();
    if (table.isEmpty || id.isEmpty || newItems.isEmpty) return;
    try {
      final client = SupabaseBootstrap.client;
      final rows = await client
          .from(table)
          .select('portfolio')
          .eq('id', id)
          .limit(1);
      final existing =
          (rows.isNotEmpty && rows.first['portfolio'] is Map)
          ? Map<String, dynamic>.from(rows.first['portfolio'] as Map)
          : <String, dynamic>{};
      final images = List<dynamic>.from(existing['images'] as List? ?? []);
      final items = List<dynamic>.from(existing['items'] as List? ?? []);
      for (final item in newItems) {
        images.insert(0, item.image);
        items.insert(0, <String, dynamic>{
          'imageUrl': item.image,
          'style': item.style,
          'storagePath': item.storagePath ?? '',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      existing['images'] = images;
      existing['items'] = items;
      await client
          .from(table)
          .update({
            'portfolio': existing,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('Portfolio save failed: $e');
    }
  }

  List<String> _collectCompletedPhotoRefs(Map<String, dynamic> row) {
    final out = <String>[];
    final seen = <String>{};

    void addRaw(Object? raw) {
      if (raw == null) return;
      if (raw is String) {
        final value = raw.trim();
        if (value.isEmpty || !_isPortfolioImageValue(value)) return;
        final key = _portfolioImageKey(value);
        if (seen.add(key)) out.add(value);
        return;
      }
      if (raw is List) {
        for (final value in raw) {
          addRaw(value);
        }
        return;
      }
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final image = _firstNonEmpty([
          map['imageUrl'],
          map['imageURL'],
          map['downloadUrl'],
          map['downloadURL'],
          map['photoUrl'],
          map['photoURL'],
          map['url'],
          map['image'],
        ]);
        if (image.isNotEmpty) {
          addRaw(image);
        }
        for (final value in map.values) {
          if (value is List || value is Map) addRaw(value);
        }
      }
    }

    final data = _asMap(row['data']);
    addRaw(row['artist_completed_photos']);
    addRaw(row['artistCompletedPhotos']);
    addRaw(data['artist_completed_photos']);
    addRaw(data['artistCompletedPhotos']);
    addRaw(_asMap(data['completedArt'])['imageUrls']);
    addRaw(_asMap(data['artistCompletion'])['artistPhotos']);
    return out;
  }

  bool _rowBelongsToArtist(
    Map<String, dynamic> row, {
    required String artistEmail,
  }) {
    final data = _asMap(row['data']);
    final acceptance = _asMap(data['acceptance']);
    final artistCompletion = _asMap(data['artistCompletion']);
    final candidates = <String>[
      _firstNonEmpty([
        row['accepted_by_artist_email'],
        row['acceptedByArtistEmail'],
        data['accepted_by_artist_email'],
        data['acceptedByArtistEmail'],
        acceptance['acceptedByArtistEmail'],
        artistCompletion['acceptedByArtistEmail'],
      ]).trim().toLowerCase(),
    ];
    return candidates.any((value) => value.isNotEmpty && value == artistEmail);
  }

  bool _rowLooksPostCompletion(Map<String, dynamic> row) {
    final status = _firstNonEmpty([row['status'], _asMap(row['data'])['status']])
        .trim()
        .toLowerCase();
    if (status == 'completed' || status == 'shipped' || status == 'delivered') {
      return true;
    }
    return _collectCompletedPhotoRefs(row).isNotEmpty;
  }

  Future<void> _backfillCompletedPortfolioForCurrentArtist() async {
    if (_portfolioBackfillAttempted) return;
    _portfolioBackfillAttempted = true;

    if (_artistSupabaseTable.trim().isEmpty || _artistSupabaseId.trim().isEmpty) {
      await _bindArtistProfile();
    }
    final table = _artistSupabaseTable.trim();
    final id = _artistSupabaseId.trim();
    if (table.isEmpty || id.isEmpty) return;

    final identity = await _resolveArtistIdentity();
    final artistEmail = identity.email.trim().toLowerCase();
    if (artistEmail.isEmpty) return;

    try {
      final client = SupabaseBootstrap.client;
      final currentRows = await client.from(table).select().eq('id', id).limit(1);
      if (currentRows.isEmpty) return;
      final currentRow = Map<String, dynamic>.from(currentRows.first as Map);
      final currentCompat = _firestoreCompatArtistData(currentRow);
      final existingItems = _portfolioItemsFromData(currentCompat);
      final existingKeys = existingItems
          .map((item) => _portfolioImageKey(item.image))
          .toSet();

      final collected = <String>[];
      for (final sourceTable in const <String>[
        'client_custom_requests',
        'company_custom_requests',
      ]) {
        final rows = await client
            .from(sourceTable)
            .select(
              'id,order_number,accepted_by_artist_email,artist_completed_photos,data,status,updated_at',
            )
            .order('updated_at', ascending: false)
            .limit(200);
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          if (!_rowBelongsToArtist(row, artistEmail: artistEmail)) continue;
          if (!_rowLooksPostCompletion(row)) continue;
          collected.addAll(_collectCompletedPhotoRefs(row));
        }
      }
      for (final detailsTable in const <String>[
        'client_custom_requests_details',
        'company_custom_requests_details',
      ]) {
        final rows = await client
            .from(detailsTable)
            .select('id,request_id,detail_key,data,updated_at')
            .eq('detail_key', 'payload')
            .order('updated_at', ascending: false)
            .limit(300);
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          if (!_rowBelongsToArtist(row, artistEmail: artistEmail)) continue;
          if (!_rowLooksPostCompletion(row)) continue;
          collected.addAll(_collectCompletedPhotoRefs(row));
        }
      }

      final nextItems = <ArtistPortfolioItem>[];
      final seenNew = <String>{};
      for (final url in collected) {
        final key = _portfolioImageKey(url);
        if (existingKeys.contains(key) || !seenNew.add(key)) continue;
        nextItems.add(
          ArtistPortfolioItem(
            image: url,
            style: 'All',
            storagePath: _storageObjectPathForReference(url),
          ),
        );
      }

      if (nextItems.isEmpty) return;
      await _appendPortfolioItemsToSupabase(nextItems);
      await _bindArtistProfile();
      debugPrint(
        'ARTIST PORTFOLIO BACKFILL success table=$table id=$id added=${nextItems.length}',
      );
    } catch (e, st) {
      debugPrint('ARTIST PORTFOLIO BACKFILL failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _openPortfolio() async {
    if (_artistSupabaseId.isEmpty) {
      await _bindArtistProfile();
    }
    if (_artistSupabaseId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artist profile not found.')),
        );
      }
      return;
    }
    await _backfillCompletedPortfolioForCurrentArtist();
    final supabaseId = _artistSupabaseId;
    final supabaseTable = _artistSupabaseTable;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistPortfolioModal(
            supabaseTable: supabaseTable,
            supabaseId: supabaseId,
            initialItems: _portfolioItemsFromData(_artistData),
            onUploadTap:
                ({
                  List<XFile>? selectedFiles,
                  void Function(int completed, int total)? onProgress,
                }) async {
                  final picker = ImagePicker();
                  final picked =
                      selectedFiles ??
                      await picker.pickMultiImage(
                        imageQuality: 78,
                        maxWidth: _portfolioMaxEdge.toDouble(),
                        maxHeight: _portfolioMaxEdge.toDouble(),
                      );
                  if (picked.isEmpty) return const <ArtistPortfolioItem>[];

                  final storage = SupabaseBootstrap.client.storage.from(
                    'portfolio-images',
                  );
                  final uploaded = <ArtistPortfolioItem>[];
                  final now = DateTime.now().millisecondsSinceEpoch;

                  Future<Uint8List> prepareBytes(Uint8List rawBytes) async {
                    if (rawBytes.lengthInBytes <=
                        _preferredPortfolioUploadBytes) {
                      return rawBytes;
                    }
                    final decoded = img.decodeImage(rawBytes);
                    if (decoded == null) return rawBytes;
                    final resized =
                        decoded.width > _portfolioMaxEdge ||
                            decoded.height > _portfolioMaxEdge
                        ? img.copyResize(
                            decoded,
                            width: decoded.width > decoded.height
                                ? _portfolioMaxEdge
                                : null,
                            height: decoded.height >= decoded.width
                                ? _portfolioMaxEdge
                                : null,
                          )
                        : decoded;
                    var quality = 82;
                    while (quality >= 55) {
                      final encoded = Uint8List.fromList(
                        img.encodeJpg(resized, quality: quality),
                      );
                      if (encoded.lengthInBytes <= _maxPortfolioUploadBytes) {
                        return encoded;
                      }
                      quality -= 8;
                    }
                    return Uint8List.fromList(
                      img.encodeJpg(resized, quality: 55),
                    );
                  }

                  for (var index = 0; index < picked.length; index++) {
                    final file = picked[index];
                    final rawBytes = await file.readAsBytes();
                    final bytes = await prepareBytes(rawBytes);
                    final path =
                        'artists/$supabaseId/portfolio/${now}_${index + 1}.jpg';
                    await storage.uploadBinary(
                      path,
                      bytes,
                      fileOptions: const FileOptions(
                        contentType: 'image/jpeg',
                        upsert: true,
                      ),
                    );
                    uploaded.add(
                      ArtistPortfolioItem(
                        image: storage.getPublicUrl(path),
                        style: 'All',
                        storagePath: path,
                      ),
                    );
                    onProgress?.call(index + 1, picked.length);
                  }

                  if (uploaded.isNotEmpty) {
                    await _appendPortfolioItemsToSupabase(uploaded);
                  }
                  return uploaded;
                },
          ),
        ),
      ),
    );
  }

  Future<void> _openPayoutSettings() async {
    if (_artistSupabaseId.isEmpty) await _bindArtistProfile();
    if (_artistSupabaseId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistPayoutSettingsPage(
            supabaseTable: _artistSupabaseTable,
            supabaseId: _artistSupabaseId,
            initialData: _artistData,
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>> _availabilityDayStates() async {
    final panel =
        (_artistData['panel_availability'] as Map<String, dynamic>?) ??
        (_artistData['availability'] as Map<String, dynamic>?) ??
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

  Future<void> _openAvailability() async {
    if (_artistSupabaseId.isEmpty) await _bindArtistProfile();
    if (_artistSupabaseId.isEmpty) return;
    final states = await _availabilityDayStates();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ArtistAvailabilityModal(
            supabaseTable: _artistSupabaseTable,
            supabaseId: _artistSupabaseId,
            initialDirectRequestsEnabled: _directRequestsEnabled,
            initialDayStates: states,
            onDirectRequestChanged: _setDirectRequestsEnabled,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: widget.showBottomNav ? kBottomNavigationBarHeight + 16 : 16,
          ),
          children: [
            // ✅ Separate top header strip
            _topHeaderStrip(),

            // ✅ Separate hero section (as its own section)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _profileHeroCard(),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Portfolio',
                    subtitle: 'Upload designs & showcase your work.',
                    onTap: _openPortfolio,
                  ),
                  _menuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payout Settings',
                    subtitle: 'Manage payout & banking details.',
                    onTap: _openPayoutSettings,
                  ),
                  _menuTile(
                    icon: Icons.access_time_rounded,
                    title: 'Availability',
                    subtitle: 'Update your schedule & turnaround.',
                    onTap: _openAvailability,
                  ),

                  // ✅ Direct Requests section (after Availability)
                  _directRequestsCard(),

                  _nfcRequestsCard(),

                  _requestNotificationsCard(),

                  _jntAscensionTile(context),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: 180,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _loggingOutFromProfile
                          ? null
                          : _logoutFromProfile,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        _loggingOutFromProfile ? 'Logging out...' : 'Logout',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.snow,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              backgroundColor: AppColors.balletSlippers,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.55),
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                if (widget.onNavTap != null) {
                  widget.onNavTap!(i);
                  return;
                }
                if (i != widget.bottomNavIndex) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  activeIcon: Icon(Icons.inbox),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money_outlined),
                  activeIcon: Icon(Icons.attach_money),
                  label: 'Earnings',
                ),
              ],
            )
          : null,
    );
  }

  // =========================
  // TOP STRIP (separate look)
  // =========================
  Widget _topHeaderStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        border: Border(bottom: const BorderSide(color: AppColors.alabaster)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              NotificationBellButton(
                onTap: _onNotifications,
                iconSize: JntHeaderMetrics.notificationIconSize,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/jnt_logo_black.png',
                    height: JntHeaderMetrics.logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // PROFILE HERO (separate)
  // =========================
  Widget _profileHeroCard() {
    final w = MediaQuery.of(context).size.width;
    final avatarSize = w < 380 ? 110.0 : 126.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: avatarSize,
                width: avatarSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _avatarImage(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _artistName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat.withValues(alpha: 0.90),
            ),
          ),

          const SizedBox(height: 10),
          TierBadge(tier: _ascensionState.tier),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_rating != null) ...[
                _stars(_rating!),
                const SizedBox(width: 10),
              ] else ...[
                Icon(
                  Icons.star_border_rounded,
                  size: 18,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _rating != null
                    ? '${_rating!.toStringAsFixed(1)} | $_reviews Reviews'
                    : 'N/A',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackCat.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArtistReviewsPage()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'View all reviews',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: _onEditProfile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      fontFamily: 'Arial',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icon(Icons.chevron_right_rounded, color: Colors.black.withValues(alpha: 0.55)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // MENU TILE
  // =========================
  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.blackCatBorderLight),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: AppColors.blackCat.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.blackCat),
          ],
        ),
      ),
    );
  }

  // =========================
  // DIRECT REQUESTS CARD
  // =========================
  Widget _directRequestsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 22,
            color: AppColors.blackCat.withValues(alpha: 0.75),
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
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _directRequestsEnabled
                      ? 'Accepting requests now 😊'
                      : 'Not accepting requests',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.60),
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _directRequestsEnabled,
            activeThumbColor: AppColors.blackCat,
            inactiveThumbColor: AppColors.blackCatLight,
            inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
            onChanged: _savingDirectRequestPref
                ? null
                : (v) => _setDirectRequestsEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _nfcRequestsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.nfc_rounded,
            size: 22,
            color: AppColors.blackCat.withValues(alpha: 0.75),
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
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nfcRequestsEnabled
                      ? 'Accepting NFC upgrade requests'
                      : 'Not accepting NFC upgrade requests',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.60),
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _nfcRequestsEnabled,
            activeThumbColor: AppColors.blackCat,
            inactiveThumbColor: AppColors.blackCatLight,
            inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
            onChanged: _savingNfcRequestPref
                ? null
                : (v) => _setNfcRequestsEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _requestNotificationsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.message_outlined,
                size: 22,
                color: AppColors.blackCat.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Client Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
              Switch(
                value: _allClientRequestNotificationsEnabled,
                activeThumbColor: AppColors.blackCat,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withValues(
                  alpha: 0.35,
                ),
                onChanged: _savingAllClientRequestNotifications
                    ? null
                    : (v) => _setAllClientRequestNotificationsEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.blackCat.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 22,
                color: AppColors.blackCat.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Direct Request Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
              IgnorePointer(
                child: Switch(
                  value: true,
                  activeThumbColor: AppColors.blackCat,
                  inactiveThumbColor: AppColors.blackCatLight,
                  inactiveTrackColor: AppColors.blackCatLight.withValues(
                    alpha: 0.35,
                  ),
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _openAscension() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const JntAscensionPage(),
        ),
      ),
    );
  }

  Widget _jntAscensionTile(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: _openAscension,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.blackCatBorderLight),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.blackCat, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'JNT Ascension',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: AppColors.blackCat,
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
    );
  }

  // =========================
  // STARS
  // =========================
  Widget _stars(double rating) {
    final r = rating.clamp(0, 5);
    final full = r.floor();
    final hasHalf = (r - full) >= 0.5;

    List<Widget> icons = [];
    for (int i = 0; i < 5; i++) {
      if (i < full) {
        icons.add(
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC107)),
        );
      } else if (i == full && hasHalf) {
        icons.add(
          const Icon(
            Icons.star_half_rounded,
            size: 18,
            color: Color(0xFFFFC107),
          ),
        );
      } else {
        icons.add(
          Icon(
            Icons.star_rounded,
            size: 18,
            color: AppColors.blackCat.withValues(alpha: 0.18),
          ),
        );
      }
    }
    return Row(children: icons);
  }

  Widget _avatarImage() {
    Widget fallback() {
      final name = _artistName.trim();
      final letter = name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
      return Container(
        decoration: BoxDecoration(
          color: AppColors.balletSlippers,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.alabaster),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      );
    }

    final src = _avatarPath.trim();
    if (src.isEmpty) {
      return FutureBuilder<String>(
        future: _resolveStorageAvatarFallback(),
        builder: (context, snapshot) {
          final resolved = (snapshot.data ?? '').trim();
          if (resolved.isEmpty) return fallback();
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }

    if (src.startsWith('data:image/')) {
      final comma = src.indexOf(',');
      if (comma > 0 && comma < src.length - 1) {
        try {
          final bytes = base64Decode(src.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        } catch (_) {
          return fallback();
        }
      }
      return fallback();
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => FutureBuilder<String>(
          future: _resolveStorageAvatarFallback(),
          builder: (context, snapshot) {
            final resolved = (snapshot.data ?? '').trim();
            if (resolved.isEmpty) return fallback();
            return Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            );
          },
        ),
      );
    }
    if (src.startsWith('gs://') ||
        src.startsWith('profile-pictures/') ||
        src.startsWith('artists/') ||
        src.startsWith('client_artists/')) {
      return FutureBuilder<String>(
        future: _resolveStorageAvatarUrl(src),
        builder: (context, snapshot) {
          final resolved = (snapshot.data ?? '').trim();
          if (resolved.isEmpty) return fallback();
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => FutureBuilder<String>(
              future: _resolveStorageAvatarFallback(),
              builder: (context, snapshot) {
                final fallbackSrc = (snapshot.data ?? '').trim();
                if (fallbackSrc.isEmpty) return fallback();
                return Image.network(
                  fallbackSrc,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback(),
                );
              },
            ),
          );
        },
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return fallback();
  }

  Future<String> _resolveStorageAvatarUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    try {
      if (value.startsWith('gs://') ||
          value.startsWith('profile-pictures/') ||
          value.startsWith('artists/') ||
          value.startsWith('client_artists/')) {
        return SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(value))
            .getPublicUrl(_storageObjectPathForReference(value))
            .trim();
      }
    } catch (_) {}
    return '';
  }

  Future<String> _resolveStorageAvatarFallback() async {
    final uid = (SupabaseAuthService.currentUserId ?? '').trim();
    if (uid.isEmpty) return '';
    final candidates = <String>[
      'profile-pictures/artists/$uid/profile/avatar.jpg',
      'profile-pictures/artists/$uid/profile/avatar.jpeg',
      'profile-pictures/artists/$uid/profile/avatar.png',
      'profile-pictures/artists/$uid/profile/avatar.webp',
      'profile-pictures/client_artists/$uid/profile/avatar.jpg',
      'profile-pictures/client_artists/$uid/profile/avatar.jpeg',
      'profile-pictures/client_artists/$uid/profile/avatar.png',
      'profile-pictures/client_artists/$uid/profile/avatar.webp',
      'artists/$uid/profile/avatar.jpg',
      'artists/$uid/profile/avatar.jpeg',
      'artists/$uid/profile/avatar.png',
      'artists/$uid/profile/avatar.webp',
      'client_artists/$uid/profile/avatar.jpg',
      'client_artists/$uid/profile/avatar.jpeg',
      'client_artists/$uid/profile/avatar.png',
      'client_artists/$uid/profile/avatar.webp',
    ];
    for (final path in candidates) {
      try {
        final url = await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(path))
            .getPublicUrl(_storageObjectPathForReference(path));
        if (url.trim().isNotEmpty) return url.trim();
      } catch (_) {}
    }
    final folders = <String>[
      'profile-pictures/artists/$uid/profile',
      'profile-pictures/client_artists/$uid/profile',
      'artists/$uid/profile',
      'client_artists/$uid/profile',
    ];
    for (final folder in folders) {
      try {
        final listed = await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(folder))
            .list(
              path: _storageObjectPathForReference(folder),
            )
            .timeout(const Duration(seconds: 4));
        for (final item in listed) {
          final name = item.name.toLowerCase();
          if (!(name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp'))) {
            continue;
          }
          final url = SupabaseBootstrap.client.storage
              .from(_storageBucketForReference(folder))
              .getPublicUrl(
                '${_storageObjectPathForReference(folder)}/${item.name}',
              )
              .trim();
          if (url.trim().isNotEmpty) return url.trim();
        }
      } catch (_) {}
    }
    return '';
  }

  String _storageBucketForReference(String raw) {
    final value = raw.trim();
    if (value.startsWith('gs://')) {
      final withoutScheme = value.substring(5);
      final slash = withoutScheme.indexOf('/');
      if (slash > 0) return withoutScheme.substring(0, slash);
    }
    if (value.startsWith('profile-pictures/')) return 'profile-pictures';
    if (value.startsWith('artists/')) return 'artists';
    if (value.startsWith('client_artists/')) return 'client_artists';
    return 'portfolio-images';
  }

  String _storageObjectPathForReference(String raw) {
    final value = raw.trim();
    if (value.startsWith('gs://')) {
      final withoutScheme = value.substring(5);
      final slash = withoutScheme.indexOf('/');
      if (slash > 0 && slash + 1 < withoutScheme.length) {
        return withoutScheme.substring(slash + 1);
      }
      return '';
    }
    if (value.startsWith('profile-pictures/')) {
      return value.replaceFirst('profile-pictures/', '');
    }
    if (value.startsWith('artists/') || value.startsWith('client_artists/')) {
      final parts = value.split('/');
      return parts.skip(1).join('/');
    }
    return value;
  }
}

class ArtistPayoutSettingsPage extends StatefulWidget {
  const ArtistPayoutSettingsPage({
    super.key,
    required this.supabaseTable,
    required this.supabaseId,
    required this.initialData,
  });

  final String supabaseTable;
  final String supabaseId;
  final Map<String, dynamic> initialData;

  @override
  State<ArtistPayoutSettingsPage> createState() =>
      _ArtistPayoutSettingsPageState();
}

class _ArtistPayoutSettingsPageState extends State<ArtistPayoutSettingsPage> {
  bool _saving = false;

  bool _openApple = false;
  bool _openPaypal = false;
  bool _openAch = false;
  bool _openVenmo = false;

  final _appleNameCtrl = TextEditingController();
  final _appleEmailCtrl = TextEditingController();
  final _applePhoneCtrl = TextEditingController();

  final _paypalEmailCtrl = TextEditingController();
  final _paypalMerchantCtrl = TextEditingController();

  final _achHolderCtrl = TextEditingController();
  final _achBankCtrl = TextEditingController();
  final _achRoutingCtrl = TextEditingController();
  final _achAccountCtrl = TextEditingController();
  String _achType = 'Checking';

  final _venmoUserCtrl = TextEditingController();
  final _venmoPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final panel = _asMap(widget.initialData['panel_payout']);
    final payout = _asMap(widget.initialData['payout']);
    final paymentDetails = _asMap(widget.initialData['paymentDetails']);

    final apple = _methodData(panel, payout, 'applePay');
    final paypal = _methodData(panel, payout, 'paypal');
    final ach = _methodData(panel, payout, 'ach');
    final venmo = _methodData(panel, payout, 'venmo');

    final method = _normalizedMethodKey(
      _firstNonEmpty([
        panel['method'],
        payout['method'],
        widget.initialData['panel_payoutMethod'],
        widget.initialData['panel_artist_payoutMethod'],
      ]),
    );

    _appleNameCtrl.text = _firstNonEmpty([
      apple['fullName'],
      payout['applePayName'],
      panel['applePayName'],
      paymentDetails['applePayName'],
    ]);
    _appleEmailCtrl.text = _firstNonEmpty([
      apple['email'],
      payout['applePayEmail'],
      panel['applePayEmail'],
      paymentDetails['applePayEmail'],
    ]);
    _applePhoneCtrl.text = _firstNonEmpty([
      apple['phone'],
      payout['applePayPhone'],
      panel['applePayPhone'],
      paymentDetails['applePayPhone'],
    ]);

    _paypalEmailCtrl.text = _firstNonEmpty([
      paypal['email'],
      payout['email'],
      panel['email'],
      widget.initialData['panel_payoutEmail'],
      widget.initialData['panel_artist_payoutEmail'],
      widget.initialData['panel_bundlePaypalEmail'],
      paymentDetails['paypalEmail'],
      widget.initialData['paypalEmail'],
    ]);
    _paypalMerchantCtrl.text = _firstNonEmpty([
      paypal['merchantId'],
      payout['merchantId'],
      panel['merchantId'],
    ]);

    _achHolderCtrl.text = _firstNonEmpty([
      ach['accountHolder'],
      ach['accountHolderName'],
      payout['accountHolder'],
      payout['accountHolderName'],
      panel['accountHolder'],
      panel['accountHolderName'],
      widget.initialData['panel_payoutLegalName'],
      widget.initialData['panel_artist_payoutLegalName'],
    ]);
    _achBankCtrl.text = _firstNonEmpty([
      ach['bankName'],
      payout['bankName'],
      panel['bankName'],
    ]);
    _achRoutingCtrl.text = _firstNonEmpty([
      ach['routingNumber'],
      payout['routingNumber'],
      payout['routing'],
      panel['routingNumber'],
      panel['routing'],
    ]);
    _achAccountCtrl.text = _firstNonEmpty([
      ach['accountNumber'],
      payout['accountNumber'],
      panel['accountNumber'],
    ]);
    final type = _firstNonEmpty([ach['accountType']]);
    if (type.toLowerCase() == 'savings') _achType = 'Savings';

    _venmoUserCtrl.text = _firstNonEmpty([
      venmo['username'],
      payout['email'],
      panel['email'],
      widget.initialData['panel_payoutEmail'],
      widget.initialData['panel_artist_payoutEmail'],
      widget.initialData['panel_bundleVenmoHandle'],
      paymentDetails['venmoHandle'],
      widget.initialData['venmoHandle'],
    ]);
    _venmoPhoneCtrl.text = _firstNonEmpty([venmo['phone']]);

    _applyDefaultExpandedMethod(method);
  }

  @override
  void dispose() {
    _appleNameCtrl.dispose();
    _appleEmailCtrl.dispose();
    _applePhoneCtrl.dispose();
    _paypalEmailCtrl.dispose();
    _paypalMerchantCtrl.dispose();
    _achHolderCtrl.dispose();
    _achBankCtrl.dispose();
    _achRoutingCtrl.dispose();
    _achAccountCtrl.dispose();
    _venmoUserCtrl.dispose();
    _venmoPhoneCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _methodData(
    Map<String, dynamic> primary,
    Map<String, dynamic> fallback,
    String key,
  ) {
    final first = _asMap(primary[key]);
    if (first.isNotEmpty) return first;
    return _asMap(fallback[key]);
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _normalizedMethodKey(String raw) {
    final key = raw.trim().toLowerCase();
    if (key == 'paypal') return 'paypal';
    if (key == 'venmo') return 'venmo';
    if (key == 'applepay' || key == 'apple pay') return 'apple';
    if (key == 'banktransfer' ||
        key == 'bank transfer' ||
        key == 'ach' ||
        key == 'bank') {
      return 'ach';
    }
    return '';
  }

  void _applyDefaultExpandedMethod(String method) {
    _openApple = false;
    _openPaypal = false;
    _openAch = false;
    _openVenmo = false;

    if (method == 'paypal') {
      _openPaypal = true;
      return;
    }
    if (method == 'venmo') {
      _openVenmo = true;
      return;
    }
    if (method == 'apple') {
      _openApple = true;
      return;
    }
    if (method == 'ach') {
      _openAch = true;
      return;
    }

    // Fallback by first section with data; else keep PayPal open by default.
    if (_paypalEmailCtrl.text.trim().isNotEmpty) {
      _openPaypal = true;
    } else if (_venmoUserCtrl.text.trim().isNotEmpty ||
        _venmoPhoneCtrl.text.trim().isNotEmpty) {
      _openVenmo = true;
    } else if (_appleNameCtrl.text.trim().isNotEmpty ||
        _appleEmailCtrl.text.trim().isNotEmpty ||
        _applePhoneCtrl.text.trim().isNotEmpty) {
      _openApple = true;
    } else if (_achHolderCtrl.text.trim().isNotEmpty ||
        _achBankCtrl.text.trim().isNotEmpty ||
        _achRoutingCtrl.text.trim().isNotEmpty ||
        _achAccountCtrl.text.trim().isNotEmpty) {
      _openAch = true;
    } else {
      _openPaypal = true;
    }
  }

  void _toggleMethod(String key) {
    setState(() {
      final nextOpen = switch (key) {
        'apple' => !_openApple,
        'paypal' => !_openPaypal,
        'ach' => !_openAch,
        'venmo' => !_openVenmo,
        _ => false,
      };
      _openApple = key == 'apple' ? nextOpen : false;
      _openPaypal = key == 'paypal' ? nextOpen : false;
      _openAch = key == 'ach' ? nextOpen : false;
      _openVenmo = key == 'venmo' ? nextOpen : false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final appleEnabled =
          _appleNameCtrl.text.trim().isNotEmpty ||
          _appleEmailCtrl.text.trim().isNotEmpty ||
          _applePhoneCtrl.text.trim().isNotEmpty;
      final paypalEnabled = _paypalEmailCtrl.text.trim().isNotEmpty;
      final achEnabled =
          _achHolderCtrl.text.trim().isNotEmpty ||
          _achBankCtrl.text.trim().isNotEmpty ||
          _achRoutingCtrl.text.trim().isNotEmpty ||
          _achAccountCtrl.text.trim().isNotEmpty;
      final venmoEnabled =
          _venmoUserCtrl.text.trim().isNotEmpty ||
          _venmoPhoneCtrl.text.trim().isNotEmpty;

      final payout = <String, dynamic>{
        'applePay': {
          'enabled': appleEnabled,
          'fullName': _appleNameCtrl.text.trim(),
          'email': _appleEmailCtrl.text.trim(),
          'phone': _applePhoneCtrl.text.trim(),
        },
        'paypal': {
          'enabled': paypalEnabled,
          'email': _paypalEmailCtrl.text.trim(),
        },
        'ach': {
          'enabled': achEnabled,
          'accountHolder': _achHolderCtrl.text.trim(),
          'bankName': _achBankCtrl.text.trim(),
          'routingNumber': _achRoutingCtrl.text.trim(),
          'accountNumber': _achAccountCtrl.text.trim(),
          'accountType': _achType,
        },
        'venmo': {
          'enabled': venmoEnabled,
          'username': _venmoUserCtrl.text.trim(),
          'phone': _venmoPhoneCtrl.text.trim(),
        },
      };

      await SupabaseBootstrap.client
          .from(widget.supabaseTable)
          .update({
            'payout': payout,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.supabaseId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payout settings updated.')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save payout settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Payout Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your payout and banking details.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            _methodCard(
              title: 'Apple Pay',
              open: _openApple,
              onTap: () => _toggleMethod('apple'),
              leading: const FaIcon(
                FontAwesomeIcons.applePay,
                size: 24,
                color: AppColors.blackCat,
              ),
              children: [
                _field('Full Name', _appleNameCtrl),
                _field('Apple Pay Email', _appleEmailCtrl),
                _field('Phone', _applePhoneCtrl),
              ],
            ),
            const SizedBox(height: 12),
            _methodCard(
              title: 'PayPal',
              open: _openPaypal,
              onTap: () => _toggleMethod('paypal'),
              leading: const Icon(
                Icons.paypal_rounded,
                size: 26,
                color: AppColors.blackCat,
              ),
              children: [
                _field('PayPal Email', _paypalEmailCtrl),
              ],
            ),
            const SizedBox(height: 12),
            _methodCard(
              title: 'ACH Direct Deposit',
              open: _openAch,
              onTap: () => _toggleMethod('ach'),
              leading: const Icon(
                Icons.account_balance_rounded,
                size: 26,
                color: AppColors.blackCat,
              ),
              children: [
                _field('Account Holder Name', _achHolderCtrl),
                _field('Bank Name', _achBankCtrl),
                _field('Routing Number', _achRoutingCtrl),
                _field('Account Number', _achAccountCtrl),
                _accountType(),
              ],
            ),
            const SizedBox(height: 12),
            _methodCard(
              title: 'Venmo',
              open: _openVenmo,
              onTap: () => _toggleMethod('venmo'),
              leading: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 24,
                color: AppColors.blackCat,
              ),
              children: [
                _field('Venmo Username', _venmoUserCtrl),
                _field('Phone', _venmoPhoneCtrl),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saving...' : 'Save',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard({
    required String title,
    required bool open,
    required VoidCallback onTap,
    required Widget leading,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.zero,
            child: Row(
              children: [
                SizedBox(height: 34, width: 56, child: Center(child: leading)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.chevron_right_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
          if (open) ...[const SizedBox(height: 6), ...children],
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.blackCat.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: c,
            style: const TextStyle(fontSize: 12, color: AppColors.blackCat),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.snow,
              hintStyle: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.45),
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountType() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Type',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.blackCat.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            initialValue: _achType,
            dropdownColor: AppColors.snow,
            iconEnabledColor: AppColors.blackCat,
            style: const TextStyle(fontSize: 12, color: AppColors.blackCat),
            decoration: InputDecoration(
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Checking', child: Text('Checking')),
              DropdownMenuItem(value: 'Savings', child: Text('Savings')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _achType = value);
            },
          ),
        ],
      ),
    );
  }
}

class ArtistPortfolioItem {
  const ArtistPortfolioItem({
    required this.image,
    required this.style,
    this.docId,
    this.storagePath,
  });

  final String image;
  final String style;
  final String? docId;
  final String? storagePath;
}

bool _isPortfolioImageValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;
  final lower = value.toLowerCase();
  if (lower.startsWith('data:image/')) return true;
  if (lower.startsWith('http://') || lower.startsWith('https://')) return true;
  if (lower.startsWith('gs://')) return true;
  if (lower.startsWith('assets/')) return true;
  if (lower.startsWith('file://')) return true;
  return RegExp(
    r'\.(jpg|jpeg|png|webp|gif|bmp|avif|heic|heif)(?:$|[?#])',
    caseSensitive: false,
  ).hasMatch(value);
}

String _portfolioImageKey(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final lower = value.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final uri = Uri.tryParse(value);
    if (uri != null) {
      return uri.replace(queryParameters: const {}, fragment: '').toString();
    }
  }
  return value;
}

class ArtistPortfolioModal extends StatefulWidget {
  const ArtistPortfolioModal({
    super.key,
    required this.supabaseTable,
    required this.supabaseId,
    required this.initialItems,
    required this.onUploadTap,
  });

  final String supabaseTable;
  final String supabaseId;
  final List<ArtistPortfolioItem> initialItems;
  final Future<List<ArtistPortfolioItem>> Function({
    List<XFile>? selectedFiles,
    void Function(int completed, int total)? onProgress,
  })
  onUploadTap;

  @override
  State<ArtistPortfolioModal> createState() => _ArtistPortfolioModalState();
}

class _ArtistPortfolioModalState extends State<ArtistPortfolioModal> {
  bool _uploading = false;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _uploadTotal = 0;
  int _uploadCompleted = 0;
  String? _loadError;
  final Set<String> _deletingImages = <String>{};
  final ScrollController _scrollController = ScrollController();
  List<ArtistPortfolioItem> _seedItems = const <ArtistPortfolioItem>[];
  List<ArtistPortfolioItem> _pagedItems = const <ArtistPortfolioItem>[];

  @override
  void initState() {
    super.initState();
    _seedItems = List<ArtistPortfolioItem>.from(widget.initialItems);
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitialPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(_loadMorePage());
    }
  }

  void _appendUnique(List<ArtistPortfolioItem> source) {
    final seen = <String>{
      for (final item in _pagedItems) _portfolioImageKey(item.image),
    };
    final next = List<ArtistPortfolioItem>.from(_pagedItems);
    for (final item in source) {
      final key = _portfolioImageKey(item.image);
      if (seen.add(key)) next.add(item);
    }
    _pagedItems = next;
  }

  Future<void> _loadMorePage() async {
    if (!_hasMore || _loadingMore || _initialLoading) return;
  }

  Future<void> _loadInitialPage() async {
    if (!mounted) return;
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _hasMore = false;
      _loadError = null;
      _pagedItems = const <ArtistPortfolioItem>[];
    });
    try {
      final rows = await SupabaseBootstrap.client
          .from(widget.supabaseTable)
          .select(
            'portfolio,'
            'portfolio_items,portfolio_images,'
            'panel_portfolio_images,'
            'panel_artist_portfolio_images,'
            'artist',
          )
          .eq('id', widget.supabaseId)
          .limit(1)
          .timeout(const Duration(seconds: 6));
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first as Map);
        final items = _portfolioItemsFromRow(row);
        _appendUnique(items);
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  List<ArtistPortfolioItem> _portfolioItemsFromRow(Map<String, dynamic> row) {
    final items = <ArtistPortfolioItem>[];
    final seen = <String>{};

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return const <String, dynamic>{};
    }

    void addItem(String image, String style, String storagePath) {
      final url = image.trim();
      if (url.isEmpty || !_isPortfolioImageValue(url)) return;
      if (!seen.add(_portfolioImageKey(url))) return;
      items.add(
        ArtistPortfolioItem(image: url, style: style, storagePath: storagePath),
      );
    }

    void addFromAny(Object? raw, {String fallbackStyle = 'All'}) {
      if (raw == null) return;
      if (raw is String) {
        final value = raw.trim();
        if (value.isEmpty || !_isPortfolioImageValue(value)) return;
        addItem(value, fallbackStyle, '');
        return;
      }
      if (raw is List) {
        for (final value in raw.reversed) {
          addFromAny(value, fallbackStyle: fallbackStyle);
        }
        return;
      }
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final image = _firstNonEmpty([
          map['imageUrl'],
          map['imageURL'],
          map['downloadUrl'],
          map['downloadURL'],
          map['photoUrl'],
          map['photoURL'],
          map['url'],
          map['image'],
        ]);
        final style = _firstNonEmpty([
          map['style'],
          map['category'],
          map['type'],
          fallbackStyle,
        ]);
        final storagePath = _firstNonEmpty([
          map['storagePath'],
          map['path'],
          '',
        ]);
        if (image.isNotEmpty) {
          addItem(image, style, storagePath);
        }
        for (final nested in map.values) {
          if (nested is List || nested is Map) {
            addFromAny(nested, fallbackStyle: fallbackStyle);
          }
        }
      }
    }

    final portfolio = asMap(row['portfolio']);
    final artist = asMap(row['artist']);
    final artistPortfolio = asMap(artist['portfolio']);

    addFromAny(portfolio['items']);
    addFromAny(portfolio['images']);
    addFromAny(row['portfolio_items']);
    addFromAny(row['portfolio_images']);
    addFromAny(row['panel_portfolio_images']);
    addFromAny(row['panel_artist_portfolio_images']);
    addFromAny(artist['portfolioItems']);
    addFromAny(artist['portfolio_items']);
    addFromAny(artist['portfolioImages']);
    addFromAny(artist['portfolio_images']);
    addFromAny(artistPortfolio['items']);
    addFromAny(artistPortfolio['images']);

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Portfolio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showcase your nail art designs.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.blackCat.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _uploading
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickMultiImage(
                                imageQuality: 78,
                                maxWidth: 1600,
                                maxHeight: 1600,
                              );
                              if (picked.isEmpty) return;
                              setState(() => _uploading = true);
                              try {
                                setState(() {
                                  _uploadCompleted = 0;
                                  _uploadTotal = picked.length;
                                });
                                final uploaded = await widget.onUploadTap(
                                  selectedFiles: picked,
                                  onProgress: (completed, total) {
                                    if (!mounted) return;
                                    setState(() {
                                      _uploadCompleted = completed;
                                      _uploadTotal = total;
                                    });
                                  },
                                );
                                if (!mounted) return;
                                if (uploaded.isNotEmpty) {
                                  setState(() {
                                    _seedItems = <ArtistPortfolioItem>[
                                      ...uploaded,
                                      ..._seedItems,
                                    ];
                                  });
                                  await _loadInitialPage();
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _uploading = false;
                                    _uploadCompleted = 0;
                                    _uploadTotal = 0;
                                  });
                                }
                              }
                            },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        _uploading
                            ? (_uploadTotal > 0
                                  ? 'Uploading $_uploadCompleted/$_uploadTotal'
                                  : 'Uploading...')
                            : 'Upload Design',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _initialLoading && _pagedItems.isEmpty && _seedItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        if (_loadError != null &&
                            _pagedItems.isEmpty &&
                            _seedItems.isEmpty) {
                          return Center(
                            child: Text(
                              'Unable to load portfolio. $_loadError',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.6,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        }

                        final displayItems =
                            _pagedItems.isNotEmpty ? _pagedItems : _seedItems;
                        if (displayItems.isEmpty) {
                          return Center(
                            child: Text(
                              'No portfolio designs available.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.6,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        }
                        return _buildPortfolioGrid(displayItems);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<ArtistPortfolioItem> _distinctPortfolioItems(
    Iterable<ArtistPortfolioItem> items,
  ) {
    final seen = <String>{};
    final distinct = <ArtistPortfolioItem>[];
    for (final item in items) {
      final key = _portfolioImageKey(item.image);
      if (key.isEmpty || !seen.add(key)) continue;
      distinct.add(item);
    }
    return distinct;
  }

  Widget _buildPortfolioGrid(List<ArtistPortfolioItem> displayItems) {
    final items = _distinctPortfolioItems(displayItems);
    final showTailLoader = _loadingMore;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: showTailLoader ? items.length + 1 : items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (_, i) {
        if (showTailLoader && i == items.length) {
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: AppColors.blackCat.withValues(alpha: 0.03),
            ),
            child: _loadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SizedBox.shrink(),
          );
        }
        final item = items[i];
        final deleting = _deletingImages.contains(item.image.trim());
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _portfolioImage(item.image),
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: deleting ? null : () => _deletePortfolioItem(item),
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.blackCat.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: deleting
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.snow,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.snow,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePortfolioItem(ArtistPortfolioItem item) async {
    final image = item.image.trim();
    if (image.isEmpty) return;

    setState(() => _deletingImages.add(image));

    try {
      // Remove from Supabase portfolio JSONB
      final client = SupabaseBootstrap.client;
      final rows = await client
          .from(widget.supabaseTable)
          .select('portfolio')
          .eq('id', widget.supabaseId)
          .limit(1);
      if (rows.isNotEmpty) {
        final portfolio =
            (rows.first['portfolio'] is Map)
            ? Map<String, dynamic>.from(rows.first['portfolio'] as Map)
            : <String, dynamic>{};
        final images = List<dynamic>.from(portfolio['images'] as List? ?? []);
        final items = List<dynamic>.from(portfolio['items'] as List? ?? []);
        images.removeWhere((e) => e.toString().trim() == image);
        items.removeWhere((e) {
          if (e is Map) return (e['imageUrl'] ?? '').toString().trim() == image;
          return e.toString().trim() == image;
        });
        portfolio['images'] = images;
        portfolio['items'] = items;
        await client
            .from(widget.supabaseTable)
            .update({
              'portfolio': portfolio,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.supabaseId);
      }

      // Delete from storage
      final path = (item.storagePath ?? '').trim();
      if (image.contains('supabase.co') && path.isNotEmpty) {
        try {
          await SupabaseBootstrap.client.storage
              .from('portfolio-images')
              .remove([path]);
        } catch (_) {}
      } else if (path.isNotEmpty) {
        try {
          await SupabaseBootstrap.client.storage
              .from(_storageBucketForReference(path))
              .remove([_storageObjectPathForReference(path)]);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _seedItems = _seedItems
              .where((e) => e.image.trim() != image)
              .toList();
          _pagedItems = _pagedItems
              .where((e) => e.image.trim() != image)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingImages.remove(image));
    }
  }

  Widget _portfolioImage(String src) {
    final value = src.trim();
    Widget fallback() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.4),
      ),
    );

    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0 && comma < value.length - 1) {
        try {
          final b64 = value.substring(comma + 1);
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        } catch (_) {
          return fallback();
        }
      }
      return fallback();
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (value.startsWith('gs://') || value.contains('/')) {
      return FutureBuilder<String>(
        future: _resolveStorageUrl(value),
        builder: (context, snapshot) {
          final resolved = (snapshot.data ?? '').trim();
          if (resolved.isEmpty) {
            return FutureBuilder<Uint8List?>(
              future: _resolveStorageBytes(value),
              builder: (context, bytesSnap) {
                final bytes = bytesSnap.data;
                if (bytes == null || bytes.isEmpty) return fallback();
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback(),
                );
              },
            );
          }
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return fallback();
  }

  Future<String> _resolveStorageUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    try {
      if (value.startsWith('gs://')) {
        return await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(value))
            .getPublicUrl(_storageObjectPathForReference(value));
      }
      if (value.contains('/')) {
        return await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(value))
            .getPublicUrl(_storageObjectPathForReference(value));
      }
    } catch (_) {}
    return '';
  }

  Future<Uint8List?> _resolveStorageBytes(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      if (value.startsWith('gs://')) {
        final bytes = await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(value))
            .download(_storageObjectPathForReference(value))
            .timeout(const Duration(seconds: 8));
        return Uint8List.fromList(bytes);
      }
      if (value.contains('/')) {
        final bytes = await SupabaseBootstrap.client.storage
            .from(_storageBucketForReference(value))
            .download(_storageObjectPathForReference(value))
            .timeout(const Duration(seconds: 8));
        return Uint8List.fromList(bytes);
      }
    } catch (_) {}
    return null;
  }
}

class ArtistAvailabilityModal extends StatefulWidget {
  const ArtistAvailabilityModal({
    super.key,
    required this.supabaseTable,
    required this.supabaseId,
    required this.initialDirectRequestsEnabled,
    required this.initialDayStates,
    required this.onDirectRequestChanged,
  });

  final String supabaseTable;
  final String supabaseId;
  final bool initialDirectRequestsEnabled;
  final Map<String, String> initialDayStates;
  final Future<void> Function(bool value) onDirectRequestChanged;

  @override
  State<ArtistAvailabilityModal> createState() =>
      _ArtistAvailabilityModalState();
}

class _ArtistAvailabilityModalState extends State<ArtistAvailabilityModal> {
  late DateTime _visibleMonth;
  late Map<String, String> _dayStates;
  late bool _directRequestsEnabled;
  bool _savingDirect = false;
  bool _savingDays = false;
  String? _dragStateToApply;
  final Set<String> _dragVisitedKeys = <String>{};
  bool _dragChanged = false;

  static const List<String> _weekdays = <String>[
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _dayStates = Map<String, String>.from(widget.initialDayStates);
    _directRequestsEnabled = widget.initialDirectRequestsEnabled;
  }

  String _dateKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _monthLabel(DateTime d) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  List<DateTime> _monthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leadDays = first.weekday % 7;
    final start = first.subtract(Duration(days: leadDays));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  Future<void> _onDirectToggle(bool value) async {
    if (_savingDirect) return;
    setState(() {
      _directRequestsEnabled = value;
      _savingDirect = true;
    });
    await widget.onDirectRequestChanged(value);
    if (!mounted) return;
    setState(() => _savingDirect = false);
  }

  Future<void> _saveDayStates() async {
    setState(() => _savingDays = true);
    try {
      final client = SupabaseBootstrap.client;
      final rows = await client
          .from(widget.supabaseTable)
          .select('availability')
          .eq('id', widget.supabaseId)
          .limit(1);
      final avail =
          (rows.isNotEmpty && rows.first['availability'] is Map)
          ? Map<String, dynamic>.from(rows.first['availability'] as Map)
          : <String, dynamic>{};
      avail['dayStates'] = _dayStates;
      await client
          .from(widget.supabaseTable)
          .update({
            'availability': avail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.supabaseId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update availability.')),
      );
    } finally {
      if (mounted) setState(() => _savingDays = false);
    }
  }

  String? _nextDayState(String? current) {
    if (current == null) return 'direct';
    if (current == 'direct') return 'blocked';
    if (current == 'blocked') return 'unavailable';
    return null;
  }

  void _setDayStateForKey(String key, String? state) {
    if (state == null) {
      _dayStates.remove(key);
      return;
    }
    _dayStates[key] = state;
  }

  Future<void> _onDayTap(DateTime day) async {
    if (day.month != _visibleMonth.month || day.year != _visibleMonth.year) {
      return;
    }
    final key = _dateKey(day);
    final next = _nextDayState(_dayStates[key]);
    setState(() {
      _setDayStateForKey(key, next);
    });
    await _saveDayStates();
  }

  int? _dayIndexFromLocalOffset(Offset localPosition, Size gridSize) {
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > gridSize.width ||
        localPosition.dy > gridSize.height) {
      return null;
    }
    final col = (localPosition.dx / (gridSize.width / 7)).floor();
    final row = (localPosition.dy / (gridSize.height / 6)).floor();
    if (col < 0 || col > 6 || row < 0 || row > 5) return null;
    return (row * 7) + col;
  }

  void _startDrag(Offset localPosition, List<DateTime> days, Size gridSize) {
    final index = _dayIndexFromLocalOffset(localPosition, gridSize);
    if (index == null) return;
    final day = days[index];
    if (day.month != _visibleMonth.month || day.year != _visibleMonth.year) {
      return;
    }
    final key = _dateKey(day);
    final next = _nextDayState(_dayStates[key]);
    setState(() {
      _dragStateToApply = next;
      _dragVisitedKeys
        ..clear()
        ..add(key);
      _setDayStateForKey(key, next);
      _dragChanged = true;
    });
  }

  void _updateDrag(Offset localPosition, List<DateTime> days, Size gridSize) {
    final index = _dayIndexFromLocalOffset(localPosition, gridSize);
    if (index == null || _dragStateToApply == null) return;
    final day = days[index];
    if (day.month != _visibleMonth.month || day.year != _visibleMonth.year) {
      return;
    }
    final key = _dateKey(day);
    if (_dragVisitedKeys.contains(key)) return;
    setState(() {
      _dragVisitedKeys.add(key);
      _setDayStateForKey(key, _dragStateToApply);
      _dragChanged = true;
    });
  }

  Future<void> _endDrag() async {
    final changed = _dragChanged;
    setState(() {
      _dragStateToApply = null;
      _dragVisitedKeys.clear();
      _dragChanged = false;
    });
    if (changed) {
      await _saveDayStates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _monthGrid(_visibleMonth);
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Availability',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage your schedule and turnaround time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Direct Request',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: _directRequestsEnabled,
                  activeThumbColor: AppColors.blackCat,
                  inactiveThumbColor: AppColors.blackCatLight,
                  inactiveTrackColor: AppColors.blackCatLight.withValues(
                    alpha: 0.35,
                  ),
                  onChanged: _savingDirect ? null : _onDirectToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.blackCatLight),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                            );
                          }),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.snow,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: AppColors.blackCatLight,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _monthLabel(_visibleMonth),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            );
                          }),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: AppColors.blackCat.withValues(alpha: 0.05),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    child: Row(
                      children: _weekdays
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    height: 280,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gridSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (details) =>
                              _startDrag(details.localPosition, days, gridSize),
                          onPanUpdate: (details) => _updateDrag(
                            details.localPosition,
                            days,
                            gridSize,
                          ),
                          onPanEnd: (_) {
                            unawaited(_endDrag());
                          },
                          child: Column(
                            children: List<Widget>.generate(6, (week) {
                              return Expanded(
                                child: Row(
                                  children: List<Widget>.generate(7, (
                                    dayIndex,
                                  ) {
                                    final day = days[(week * 7) + dayIndex];
                                    return Expanded(child: _dayCell(day));
                                  }),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.blackCatLight),
              ),
              child: Row(
                children: const [
                  _AvailabilityLegend(
                    color: AppColors.balletSlippers,
                    label: 'Direct Request',
                  ),
                  SizedBox(width: 14),
                  _AvailabilityLegend(
                    color: Color(0xFFD17A7A),
                    label: 'Blocked',
                  ),
                  SizedBox(width: 14),
                  _AvailabilityLegend(
                    color: AppColors.alabaster,
                    label: 'Not Available',
                    slashed: true,
                  ),
                ],
              ),
            ),
            if (_savingDays)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Saving availability...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.blackCat.withValues(alpha: 0.5),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Tap or drag across dates to apply a range: Direct Request -> Blocked -> Not Available -> Clear.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.blackCat.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day) {
    final isCurrentMonth =
        day.month == _visibleMonth.month && day.year == _visibleMonth.year;
    final state = _dayStates[_dateKey(day)];
    Color bg = Colors.transparent;
    Color text = AppColors.blackCat.withValues(alpha: 0.78);
    final isUnavailable = state == 'unavailable';
    if (!isCurrentMonth) {
      bg = const Color(0xFFF0F0F6);
      text = AppColors.blackCat.withValues(alpha: 0.35);
    } else if (state == 'direct') {
      bg = AppColors.balletSlippers;
      text = AppColors.blackCat;
    } else if (state == 'blocked') {
      bg = const Color(0xFFD17A7A);
      text = AppColors.snow;
    } else if (isUnavailable) {
      bg = AppColors.alabaster;
      text = AppColors.blackCat.withValues(alpha: 0.55);
    }

    return InkWell(
      onTap: () => _onDayTap(day),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: isUnavailable
              ? Border.all(color: AppColors.blackCatLight)
              : null,
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isUnavailable && isCurrentMonth)
              Transform.rotate(
                angle: -0.75,
                child: Container(
                  width: 20,
                  height: 1.6,
                  color: AppColors.blackCatLight,
                ),
              ),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityLegend extends StatelessWidget {
  const _AvailabilityLegend({
    required this.color,
    required this.label,
    this.slashed = false,
  });

  final Color color;
  final String label;
  final bool slashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: slashed
              ? Transform.rotate(
                  angle: -0.75,
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 1.4,
                      color: AppColors.blackCatLight,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.blackCat.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class ArtistEditProfilePage extends StatefulWidget {
  const ArtistEditProfilePage({
    super.key,
    required this.supabaseTable,
    required this.supabaseId,
    required this.initialData,
  });

  final String supabaseTable;
  final String supabaseId;
  final Map<String, dynamic> initialData;

  @override
  State<ArtistEditProfilePage> createState() => _ArtistEditProfilePageState();
}

class _ArtistEditProfilePageState extends State<ArtistEditProfilePage> {
  final _displayNameCtrl = TextEditingController();
  final _studioNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  bool _saving = false;
  bool _pickingPhoto = false;
  String _selectedCountry = 'United States';
  String? _selectedUsState;
  String _profilePhotoUrl = '';
  Uint8List? _profilePhotoBytes;

  static const String _usCountry = 'United States';
  static const List<String> _usStates = <String>[
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
    'District of Columbia',
  ];

  static const List<String> _countries = <String>[
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
    'Cabo Verde',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Colombia',
    'Comoros',
    'Congo',
    'Costa Rica',
    "Cote d'Ivoire",
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czech Republic',
    'Democratic Republic of the Congo',
    'Denmark',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Fiji',
    'Finland',
    'France',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Grenada',
    'Guatemala',
    'Guinea',
    'Guinea-Bissau',
    'Guyana',
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
    'Kiribati',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Liechtenstein',
    'Lithuania',
    'Luxembourg',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Marshall Islands',
    'Mauritania',
    'Mauritius',
    'Mexico',
    'Micronesia',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Montenegro',
    'Morocco',
    'Mozambique',
    'Myanmar',
    'Namibia',
    'Nauru',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'North Korea',
    'North Macedonia',
    'Norway',
    'Oman',
    'Pakistan',
    'Palau',
    'Palestine',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Rwanda',
    'Saint Kitts and Nevis',
    'Saint Lucia',
    'Saint Vincent and the Grenadines',
    'Samoa',
    'San Marino',
    'Sao Tome and Principe',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Seychelles',
    'Sierra Leone',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'Solomon Islands',
    'Somalia',
    'South Africa',
    'South Korea',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Timor-Leste',
    'Togo',
    'Tonga',
    'Trinidad and Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Tuvalu',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Vanuatu',
    'Vatican City',
    'Venezuela',
    'Vietnam',
    'Yemen',
    'Zambia',
    'Zimbabwe',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    final profile =
        (data['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    _displayNameCtrl.text = firstNonEmpty([
      profile['displayName'],
      data['panel_displayName'],
      data['displayName'],
      data['name'],
    ]);
    _studioNameCtrl.text = firstNonEmpty([
      profile['studioName'],
      profile['studio_name'],
      data['panel_studioName'],
      data['panel_studio_name'],
      data['studioName'],
      data['studio_name'],
    ]);
    _bioCtrl.text = firstNonEmpty([profile['bio'], data['panel_bio']]);
    _cityCtrl.text = firstNonEmpty([profile['city'], data['panel_city']]);
    _stateCtrl.text = firstNonEmpty([profile['state'], data['panel_state']]);
    final savedCountry = firstNonEmpty([
      profile['country'],
      data['panel_country'],
    ]);
    _selectedCountry = _matchCountry(savedCountry) ?? _usCountry;
    if (_selectedCountry == _usCountry) {
      _selectedUsState = _matchUsState(_stateCtrl.text);
      if (_selectedUsState != null) {
        _stateCtrl.text = _selectedUsState!;
      }
    }
    _instagramCtrl.text = firstNonEmpty([
      profile['instagram'],
      data['panel_instagram'],
    ]);
    _tiktokCtrl.text = firstNonEmpty([profile['tiktok'], data['panel_tiktok']]);
    _profilePhotoUrl = firstNonEmpty([
      profile['photoUrl'],
      profile['avatarUrl'],
      profile['profileImageUrl'],
      data['panel_profileImageUrl'],
      data['profileImageUrl'],
      data['photoUrl'],
      data['avatarUrl'],
    ]);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _studioNameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final displayName = _displayNameCtrl.text.trim();
      final studioName = _studioNameCtrl.text.trim();
      final bio = _bioCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final instagram = _instagramCtrl.text.trim();
      final tiktok = _tiktokCtrl.text.trim();
      final stateToSave = _selectedCountry == _usCountry
          ? (_selectedUsState ?? _stateCtrl.text.trim())
          : _stateCtrl.text.trim();
      final uid = (SupabaseAuthService.currentUserId ?? widget.supabaseId)
          .trim();
      var profilePhotoUrlToSave = _profilePhotoUrl.trim();
      if (_profilePhotoBytes != null && _profilePhotoBytes!.isNotEmpty) {
        profilePhotoUrlToSave = await _uploadEditProfilePhoto(
          uid,
          _profilePhotoBytes!,
        );
      }
      await SupabaseBootstrap.client
          .from(widget.supabaseTable)
          .update({
            'displayName': displayName,
            'name': displayName,
            'studioName': studioName,
            'bio': bio,
            'city': city,
            'state': stateToSave,
            'country': _selectedCountry,
            'instagram': instagram,
            'tiktok': tiktok,
            'profileImageUrl': profilePhotoUrlToSave,
            'photoUrl': profilePhotoUrlToSave,
            'avatarUrl': profilePhotoUrlToSave,
            'profile': {
              ...((widget.initialData['profile'] as Map?) ??
                  const <String, dynamic>{}),
              'displayName': displayName,
              'studioName': studioName,
              'bio': bio,
              'city': city,
              'state': stateToSave,
              'country': _selectedCountry,
              'instagram': instagram,
              'tiktok': tiktok,
              'photoUrl': profilePhotoUrlToSave,
              'avatarUrl': profilePhotoUrlToSave,
              'profileImageUrl': profilePhotoUrlToSave,
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.supabaseId);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save profile changes.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final optimized = _optimizeEditProfilePhotoBytes(bytes) ?? bytes;
      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = optimized;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick profile photo.')),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Edit Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: AppColors.blackCat,
                          fontFamily: 'ArialBold',
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.zero,
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _profileUploadPicker(),
              const SizedBox(height: 6),
              _field('Display Name', _displayNameCtrl),
              _field('Studio Name', _studioNameCtrl),
              _field('Bio', _bioCtrl, maxLines: 3),
              _field('City', _cityCtrl),
              _countryDropdown(),
              _selectedCountry == _usCountry
                  ? _usStateDropdown()
                  : _field('State', _stateCtrl),
              _field('Instagram', _instagramCtrl),
              _field('TikTok', _tiktokCtrl),
              const SizedBox(height: 14),
              Center(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving...' : 'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List? _optimizeEditProfilePhotoBytes(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
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
    final encoded = img.encodeJpg(processed, quality: 74);
    return Uint8List.fromList(encoded);
  }

  Future<String> _uploadEditProfilePhoto(String uid, Uint8List bytes) async {
    try {
      final safeUid = uid.trim().isEmpty
          ? (SupabaseAuthService.currentUser?.id ?? 'unknown')
          : uid.trim();
      final path = 'artists/$safeUid/profile/avatar.jpg';
      final storage = SupabaseBootstrap.client.storage.from('profile-pictures');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final url = storage.getPublicUrl(path).trim();
      if (url.isNotEmpty) return url;
    } catch (e) {
      debugPrint('Artist edit profile photo upload failed: $e');
    }

    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  ImageProvider? _imageProviderFromUrl(String src) {
    if (src.startsWith('data:image/')) {
      final comma = src.indexOf(',');
      if (comma > 0 && comma < src.length - 1) {
        try {
          return MemoryImage(base64Decode(src.substring(comma + 1)));
        } catch (_) {}
      }
      return null;
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    return null;
  }

  Widget _profileUploadPicker() {
    final imageProvider = _imageProviderFromUrl(_profilePhotoUrl.trim());
    final hasImage = _profilePhotoBytes != null || imageProvider != null;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: (_saving || _pickingPhoto) ? null : _pickProfilePhoto,
            child: Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: _profilePhotoBytes != null
                  ? Image.memory(
                      _profilePhotoBytes!,
                      fit: BoxFit.cover,
                      width: 88,
                      height: 88,
                    )
                  : imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      width: 88,
                      height: 88,
                    )
                  : Icon(
                      Icons.camera_alt_outlined,
                      size: 26,
                      color: AppColors.blackCat,
                    ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: GestureDetector(
              onTap: (_saving || _pickingPhoto) ? null : _pickProfilePhoto,
              child: Container(
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: AppColors.blackCatBorderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blackCat.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  hasImage
                      ? Icons.file_upload_outlined
                      : Icons.photo_camera_outlined,
                  color: AppColors.blackCat,
                  size: 16,
                ),
              ),
            ),
          ),
          if (_pickingPhoto)
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.blackCat.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SearchableDropdownField(
        label: 'Country',
        value: _selectedCountry,
        items: _countries,
        fillColor: AppColors.snow,
        borderColor: AppColors.blackCatBorderLight,
        onChanged: (value) {
          setState(() {
            _selectedCountry = value;
            if (_selectedCountry == _usCountry) {
              _selectedUsState = _matchUsState(_stateCtrl.text);
              if (_selectedUsState != null) {
                _stateCtrl.text = _selectedUsState!;
              }
            } else {
              if (_selectedUsState != null && _stateCtrl.text.trim().isEmpty) {
                _stateCtrl.text = _selectedUsState!;
              }
              _selectedUsState = null;
            }
          });
        },
      ),
    );
  }

  Widget _usStateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SearchableDropdownField(
        label: 'State',
        value: _selectedUsState,
        items: _usStates,
        hint: 'Select state',
        fillColor: AppColors.snow,
        borderColor: AppColors.blackCatBorderLight,
        onChanged: (value) {
          setState(() {
            _selectedUsState = value;
            _stateCtrl.text = value;
          });
        },
      ),
    );
  }

  String? _matchCountry(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower == 'usa' ||
        lower == 'us' ||
        lower == 'u.s.' ||
        lower == 'u.s.a.') {
      return _usCountry;
    }
    for (final country in _countries) {
      if (country.toLowerCase() == lower) {
        return country;
      }
    }
    return null;
  }

  String? _matchUsState(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();
    for (final state in _usStates) {
      if (state.toLowerCase() == lower) {
        return state;
      }
    }
    return null;
  }
}
