import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/notification_bell_button.dart';
import 'notifications_page.dart';

class ClientHomeArtistPortfolioPage extends StatefulWidget {
  const ClientHomeArtistPortfolioPage({
    super.key,
    required this.clientName,
    required this.profileComplete,
    required this.onLogout,
    this.profileImageUrl = '',
    this.headerBottom,
    this.onOpenProfile,
    this.onRequestArtist,
    this.showProfileMenuInAvatar = true,
  });

  final String clientName;
  final bool profileComplete;
  final VoidCallback? onOpenProfile;
  final Future<void> Function() onLogout;
  final String profileImageUrl;
  final Widget? headerBottom;
  final ValueChanged<String>? onRequestArtist;
  final bool showProfileMenuInAvatar;

  @override
  State<ClientHomeArtistPortfolioPage> createState() =>
      _ClientHomeArtistPortfolioPageState();
}

class _ClientHomeArtistPortfolioPageState
    extends State<ClientHomeArtistPortfolioPage> {
  bool _loading = true;
  List<_PortfolioTileData> _tiles = const <_PortfolioTileData>[];
  String _clientAvatarUrl = '';

  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'clientHomeNotifications',
  );

  @override
  void initState() {
    super.initState();
    _clientAvatarUrl = widget.profileImageUrl.trim();
    unawaited(_loadClientAvatarFromSupabase());
    unawaited(_loadPortfolioFeed());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _notificationsFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant ClientHomeArtistPortfolioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.profileImageUrl.trim();
    if (next.isNotEmpty && next != oldWidget.profileImageUrl.trim()) {
      setState(() => _clientAvatarUrl = next);
    }
  }

  @override
  void dispose() {
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values, {String fallback = ''}) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(value.trim().toLowerCase());
  }

  String _safeArtistLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Artist';
    if (_looksLikeUuid(value)) return 'Artist';
    if (RegExp(r'^[0-9]+$').hasMatch(value)) return 'Artist';
    return value;
  }

  String _resolveStorageUrl(String raw, {String bucket = 'portfolio-images'}) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }
    if (lower.startsWith('data:image/')) return value;
    if (lower.startsWith('profile-pictures/')) {
      return Supabase.instance.client.storage
          .from('profile-pictures')
          .getPublicUrl(value)
          .trim();
    }
    if (lower.startsWith('artists/') || lower.startsWith('client_artists/')) {
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(value).trim();
    }
    if (lower.startsWith('portfolio-images/')) {
      return Supabase.instance.client.storage
          .from('portfolio-images')
          .getPublicUrl(value.substring('portfolio-images/'.length))
          .trim();
    }
    return value;
  }

  String _resolveArtistAvatarUrl(String ownerId, {String fallback = ''}) {
    final storageBase = 'https://mjvypuwrwcjylhizuhfw.supabase.co/storage/v1/object/public/profile-pictures';
    final candidates = <String>[
      _resolveStorageUrl(fallback, bucket: 'profile-pictures'),
      '$storageBase/$ownerId/profile/avatar.jpg',
      '$storageBase/artists/$ownerId/profile/avatar.jpg',
      '$storageBase/client_artists/$ownerId/profile/avatar.jpg',
    ];

    for (final candidate in candidates) {
      final value = candidate.trim();
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  Future<void> _loadClientAvatarFromSupabase() async {
    if (_clientAvatarUrl.trim().isNotEmpty) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isEmpty && email.isEmpty) return;

    for (final table in const <String>['client', 'client_artist']) {
      try {
        Map<String, dynamic>? data;

        if (uid.isNotEmpty) {
          final rows = await supabase.from(table).select().eq('id', uid).limit(1);
          if (rows.isNotEmpty) {
            data = Map<String, dynamic>.from(rows.first as Map);
          }
        }

        if (data == null && email.isNotEmpty) {
          final rows = await supabase
              .from(table)
              .select()
              .eq('email', email)
              .limit(1);
          if (rows.isNotEmpty) {
            data = Map<String, dynamic>.from(rows.first as Map);
          }
        }

        if (data == null) continue;

        final profile = _asMap(data['profile']);
        final basic = _asMap(data['basic']);
        final avatar = _firstNonEmpty([
          basic['profileImageUrl'],
          basic['photoUrl'],
          basic['avatarUrl'],
          profile['profileImageUrl'],
          profile['photoUrl'],
          profile['avatarUrl'],
          data['profileImageUrl'],
          data['photoUrl'],
          data['avatarUrl'],
        ]);

        if (avatar.isEmpty) continue;
        if (!mounted) return;
        setState(() => _clientAvatarUrl = avatar);
        return;
      } catch (e) {
        debugPrint('CLIENT HOME AVATAR LOAD FAILED [$table]: $e');
      }
    }
  }

  Future<void> _loadPortfolioFeed() async {
    try {
      final rows = <Map<String, dynamic>>[];

      final artistRows = await _readArtistRows('artist');
      final clientArtistRows = await _readArtistRows('client_artist');

      debugPrint('CLIENT HOME SUPABASE artist rows = ${artistRows.length}');
      debugPrint('CLIENT HOME SUPABASE client_artist rows = ${clientArtistRows.length}');

      rows.addAll(artistRows);
      rows.addAll(clientArtistRows);

      final tiles = <_PortfolioTileData>[];

      for (final row in rows) {
        _collectTilesFromArtistRow(row, tiles);
      }

      var unique = _dedupeTiles(tiles);

      if (unique.isEmpty) {
        final recovered = await _recoverTilesFromStorage(rows);
        unique = _dedupeTiles(<_PortfolioTileData>[
          ...tiles,
          ...recovered,
        ]);
      }

      debugPrint('CLIENT HOME PORTFOLIO TILES = ${unique.length}');
      if (!mounted) return;
      setState(() {
        _tiles = unique;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('CLIENT HOME PORTFOLIO LOAD FAILED: $e');
      debugPrint(st.toString());

      if (!mounted) return;
      setState(() {
        _tiles = const <_PortfolioTileData>[];
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _readArtistRows(String table) async {
    try {
      final rows = await Supabase.instance.client.from(table).select().limit(500);

      debugPrint('CLIENT HOME RAW ROWS [$table] = ${rows.length}');
      if (rows.isNotEmpty) {
        debugPrint('CLIENT HOME FIRST ROW [$table] = ${rows.first}');
      }

      return rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      debugPrint('CLIENT HOME ARTIST TABLE LOAD FAILED [$table]: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  void _collectTilesFromArtistRow(
    Map<String, dynamic> data,
    List<_PortfolioTileData> out,
  ) {
    final profile = _asMap(data['profile']);
    final basic = _asMap(data['basic']);
    final artist = _asMap(data['artist']);
    final artistProfile = _asMap(data['artist_profile']);
    final portfolio = _asMap(data['portfolio']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final ascension = _asMap(data['ascension']);
    final sponsorshipRequest = _asMap(data['sponsorshipRequest']);

    final name = _safeArtistLabel(_firstNonEmpty([
      profile['displayName'],
      profile['display_name'],
      profile['studioName'],
      profile['studio_name'],
      profile['name'],
      profile['nameOrStudio'],
      profile['name_or_studio'],
      artistProfile['displayName'],
      artistProfile['display_name'],
      artistProfile['studioName'],
      artistProfile['studio_name'],
      artistProfile['nameOrStudio'],
      artistProfile['name_or_studio'],
      basic['displayName'],
      basic['display_name'],
      basic['name'],
      basic['nameOrStudio'],
      basic['name_or_studio'],
      basic['studioName'],
      basic['studio_name'],
      data['panel_displayName'],
      data['panel_display_name'],
      data['panel_nameOrStudio'],
      data['panel_name_or_studio'],
      data['panel_studioName'],
      data['panel_studio_name'],
      data['displayName'],
      data['display_name'],
      data['studioName'],
      data['studio_name'],
      data['name'],
      data['fullName'],
    ], fallback: 'Artist'));

    var tierLabel = 'Maker';
    for (final raw in <Object?>[
      data['sponsorshipTier'],
      data['panel_ascensionLevel'],
      profile['ascensionTier'],
      ascension['tier'],
      ascension['levelName'],
      sponsorshipRequest['tier'],
    ]) {
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value == 'goldsmith') {
        tierLabel = 'Goldsmith';
        break;
      }
      if (value == 'crowned') {
        tierLabel = 'Crowned';
        break;
      }
      if (value == 'maker') {
        tierLabel = 'Maker';
        break;
      }
    }

    final avatar = _firstNonEmpty([
      profile['profileImageUrl'],
      profile['profile_image_url'],
      profile['profilePhotoUrl'],
      profile['profile_photo_url'],
      profile['photoUrl'],
      profile['photo_url'],
      profile['avatarUrl'],
      profile['avatar_url'],
      artistProfile['profileImageUrl'],
      artistProfile['profile_image_url'],
      artistProfile['profilePhotoUrl'],
      artistProfile['profile_photo_url'],
      artistProfile['photoUrl'],
      artistProfile['photo_url'],
      artistProfile['avatarUrl'],
      artistProfile['avatar_url'],
      basic['profileImageUrl'],
      basic['profile_image_url'],
      basic['profilePhotoUrl'],
      basic['profile_photo_url'],
      basic['photoUrl'],
      basic['photo_url'],
      basic['avatarUrl'],
      basic['avatar_url'],
      data['panel_profileImageUrl'],
      data['panel_profile_image_url'],
      data['panel_avatarUrl'],
      data['panel_avatar_url'],
      data['profileImageUrl'],
      data['profile_image_url'],
      data['profilePhotoUrl'],
      data['profile_photo_url'],
      data['photoUrl'],
      data['photo_url'],
      data['avatarUrl'],
      data['avatar_url'],
      artist['profileImageUrl'],
      artist['profile_image_url'],
      artist['profilePhotoUrl'],
      artist['profile_photo_url'],
      artist['photoUrl'],
      artist['photo_url'],
      artist['avatarUrl'],
      artist['avatar_url'],
    ]);

    final urls = <String>[];
    // Supabase DB shape confirmed:
    // portfolio = {
    //   items: [{ style: 'All', imageUrl: 'https://...' }],
    //   images: ['https://...', ...]
    // }
    _collectUrls(portfolio['items'], urls);
    _collectUrls(portfolio['images'], urls);

    // Keep these as fallbacks for older rows.
    _collectUrls(data['portfolioImages'], urls);
    _collectUrls(data['previousArt'], urls);
    _collectUrls(data['previousArtImages'], urls);
    _collectUrls(data['previousArtUrls'], urls);
    _collectUrls(data['previousWork'], urls);
    _collectUrls(data['previousWorkImages'], urls);
    _collectUrls(data['portfolioItems'], urls);
    _collectUrls(profile['portfolioImages'], urls);
    _collectUrls(profile['previousArt'], urls);
    _collectUrls(profile['previousArtImages'], urls);
    _collectUrls(artist['portfolioImages'], urls);
    _collectUrls(artist['portfolioItems'], urls);
    _collectUrls(artist['previousArt'], urls);
    _collectUrls(artist['previousArtImages'], urls);
    _collectUrls(artistPortfolio['images'], urls);
    _collectUrls(artistPortfolio['items'], urls);

    final dedup = _dedupeUrls(urls)
        .where(_isDisplayableImageUrl)
        .toList(growable: false);

    debugPrint('CLIENT HOME ARTIST "$name" portfolio urls = ${dedup.length}');
    if (dedup.isNotEmpty) {
      debugPrint('CLIENT HOME ARTIST "$name" first url = ${dedup.first}');
    }

    for (final image in dedup) {
      out.add(
        _PortfolioTileData(
          artistName: name,
          tierLabel: tierLabel,
          artistAvatarUrl: avatar,
          imagePath: image,
        ),
      );
    }
  }

  String _tierLabelFrom(Map<String, dynamic> data, Map<String, dynamic> profile) {
    final ascension = _asMap(data['ascension']);
    final sponsorshipRequest = _asMap(data['sponsorshipRequest']);

    for (final raw in <Object?>[
      data['sponsorshipTier'],
      data['panel_ascensionLevel'],
      data['ascensionTier'],
      profile['ascensionTier'],
      ascension['tier'],
      ascension['levelName'],
      sponsorshipRequest['tier'],
    ]) {
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value == 'goldsmith') return 'Goldsmith';
      if (value == 'crowned') return 'Crowned';
      if (value == 'maker') return 'Maker';
    }

    return 'Maker';
  }

  Future<List<_PortfolioTileData>> _recoverTilesFromStorage(
    List<Map<String, dynamic>> rows,
  ) async {
    final storage = Supabase.instance.client.storage.from('portfolio-images');
    final recovered = <_PortfolioTileData>[];
    final seen = <String>{};
    final nameById = <String, String>{};
    final avatarById = <String, String>{};
    final tierById = <String, String>{};

    for (final row in rows) {
      final profile = _asMap(row['profile']);
      final basic = _asMap(row['basic']);
      final artist = _asMap(row['artist']);
      final artistProfile = _asMap(row['artist_profile']);

      final artistName = _safeArtistLabel(_firstNonEmpty([
        profile['displayName'],
        profile['display_name'],
        profile['studioName'],
        profile['studio_name'],
        profile['nameOrStudio'],
        profile['name_or_studio'],
        profile['name'],
        artistProfile['displayName'],
        artistProfile['display_name'],
        artistProfile['studioName'],
        artistProfile['studio_name'],
        artistProfile['nameOrStudio'],
        artistProfile['name_or_studio'],
        basic['displayName'],
        basic['display_name'],
        basic['nameOrStudio'],
        basic['name_or_studio'],
        basic['studioName'],
        basic['studio_name'],
        row['panel_displayName'],
        row['panel_display_name'],
        row['panel_nameOrStudio'],
        row['panel_name_or_studio'],
        row['panel_studioName'],
        row['panel_studio_name'],
        row['displayName'],
        row['display_name'],
        row['studioName'],
        row['studio_name'],
        row['name'],
        row['fullName'],
        row['email'],
      ], fallback: 'Artist'));

      final rowId = _firstNonEmpty([
        row['id'],
        row['uid'],
        row['userId'],
      ]);

      final avatarUrl = _resolveArtistAvatarUrl(
        rowId,
        fallback: _firstNonEmpty([
          profile['profileImageUrl'],
          profile['profile_image_url'],
          profile['profilePhotoUrl'],
          profile['profile_photo_url'],
          profile['photoUrl'],
          profile['photo_url'],
          profile['avatarUrl'],
          profile['avatar_url'],
          artistProfile['profileImageUrl'],
          artistProfile['profile_image_url'],
          artistProfile['profilePhotoUrl'],
          artistProfile['profile_photo_url'],
          artistProfile['photoUrl'],
          artistProfile['photo_url'],
          artistProfile['avatarUrl'],
          artistProfile['avatar_url'],
          basic['profileImageUrl'],
          basic['profile_image_url'],
          basic['profilePhotoUrl'],
          basic['profile_photo_url'],
          basic['photoUrl'],
          basic['photo_url'],
          basic['avatarUrl'],
          basic['avatar_url'],
          row['panel_profileImageUrl'],
          row['panel_profile_image_url'],
          row['panel_avatarUrl'],
          row['panel_avatar_url'],
          row['profileImageUrl'],
          row['profile_image_url'],
          row['profilePhotoUrl'],
          row['profile_photo_url'],
          row['photoUrl'],
          row['photo_url'],
          row['avatarUrl'],
          row['avatar_url'],
          artist['profileImageUrl'],
          artist['profile_image_url'],
          artist['profilePhotoUrl'],
          artist['profile_photo_url'],
          artist['photoUrl'],
          artist['photo_url'],
          artist['avatarUrl'],
          artist['avatar_url'],
        ]),
      );

      final tierLabel = _tierLabelFrom(row, profile);
      for (final id in <String>{
        rowId.trim(),
        (row['id'] ?? '').toString().trim(),
        (row['uid'] ?? '').toString().trim(),
        (row['userId'] ?? '').toString().trim(),
      }) {
        if (id.isEmpty) continue;
        nameById[id] = artistName;
        avatarById[id] = avatarUrl;
        tierById[id] = tierLabel;
      }
    }

    Future<List<Map<String, dynamic>>> listStorageObjects(String prefix) async {
      try {
        final listing = await storage.list(path: prefix);
        return listing
            .map(
              (item) => <String, dynamic>{
                'name': item.name,
                'id': item.id,
                'metadata': item.metadata,
              },
            )
            .toList(growable: false);
      } catch (e) {
        debugPrint('CLIENT HOME STORAGE LIST ERROR [$prefix]: $e');
        return const <Map<String, dynamic>>[];
      }
    }

    Future<void> addFromFolder({
      required String ownerId,
      required String artistName,
      required String tierLabel,
      required String avatarUrl,
      required String folderPrefix,
    }) async {
      if (ownerId.trim().isEmpty) return;

      final folderCandidates = <String>[
        '$folderPrefix/$ownerId/portfolio',
        '$folderPrefix/$ownerId/portfolio/',
      ];

      for (final folder in folderCandidates) {
        try {
          final listing = await listStorageObjects(folder);
          for (final file in listing) {
            final fileName = (file['name'] ?? '').toString().trim();
            if (fileName.isEmpty) continue;
            final lower = fileName.toLowerCase();
            if (!(lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png') ||
                lower.endsWith('.webp') ||
                lower.endsWith('.gif'))) {
              continue;
            }

            final path = '$folderPrefix/$ownerId/portfolio/$fileName';
            final url = Supabase.instance.client.storage
                .from('portfolio-images')
                .getPublicUrl(path)
                .trim();
            if (url.isEmpty) continue;

            final key = url.split('?').first;
            if (!seen.add(key)) continue;

            recovered.add(
              _PortfolioTileData(
                artistName: artistName,
                tierLabel: tierLabel,
                artistAvatarUrl: avatarUrl,
                imagePath: url,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            'CLIENT HOME PORTFOLIO STORAGE RECOVERY FAILED '
            '[$folderPrefix/$ownerId]: $e',
          );
        }
      }
    }

    Future<void> crawlBase(String folderPrefix) async {
      for (final prefix in <String>[folderPrefix, '$folderPrefix/']) {
        try {
          final roots = await listStorageObjects(prefix);
          for (final root in roots) {
            final ownerId = (root['name'] ?? '').toString().trim();
            if (ownerId.isEmpty || ownerId.contains('.')) continue;
            final artistName = _safeArtistLabel(nameById[ownerId] ?? '');
            final avatarUrl = _resolveArtistAvatarUrl(
              ownerId,
              fallback: avatarById[ownerId] ?? '',
            );
            final tierLabel = tierById[ownerId] ?? 'Maker';
            await addFromFolder(
              ownerId: ownerId,
              artistName: artistName,
              tierLabel: tierLabel,
              avatarUrl: avatarUrl,
              folderPrefix: folderPrefix,
            );
          }
        } catch (e) {
          debugPrint('CLIENT HOME STORAGE ROOT LIST FAILED [$prefix]: $e');
        }
      }
    }

    await crawlBase('artists');
    await crawlBase('client_artists');

    return recovered;
  }

  void _collectUrls(dynamic raw, List<String> out) {
    if (raw == null) return;

    if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) out.add(value);
      return;
    }

    if (raw is List) {
      for (final item in raw) {
        _collectUrls(item, out);
      }
      return;
    }

    if (raw is Map) {
      _collectUrls(raw['imageUrl'], out);
      _collectUrls(raw['imageURL'], out);
      _collectUrls(raw['downloadUrl'], out);
      _collectUrls(raw['downloadURL'], out);
      _collectUrls(raw['photoUrl'], out);
      _collectUrls(raw['photoURL'], out);
      _collectUrls(raw['url'], out);
      _collectUrls(raw['image'], out);
      _collectUrls(raw['path'], out);
      _collectUrls(raw['storagePath'], out);
      _collectUrls(raw['fullPath'], out);
      _collectUrls(raw['src'], out);
      _collectUrls(raw['value'], out);
      return;
    }
  }

  List<String> _dedupeUrls(List<String> urls) {
    final seen = <String>{};
    final out = <String>[];

    for (final raw in urls) {
      final value = _toDisplayableImage(raw.trim());
      if (value.isEmpty) continue;

      final key = value.split('?').first;
      if (seen.add(key)) out.add(value);
    }

    return out;
  }

  List<_PortfolioTileData> _dedupeTiles(List<_PortfolioTileData> tiles) {
    final seen = <String>{};
    final out = <_PortfolioTileData>[];

    for (final tile in tiles) {
      final key =
          '${tile.artistName.trim().toLowerCase()}|${tile.imagePath.trim().split('?').first}';
      if (seen.add(key)) {
        out.add(tile);
      }
      if (out.length >= 100) break;
    }

    return out;
  }

  String _toDisplayableImage(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final lower = value.toLowerCase();

    if (lower.startsWith('data:image/') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return value;
    }

    if (lower.startsWith('portfolio-images/')) {
      final path = value.substring('portfolio-images/'.length);
      return Supabase.instance.client.storage
          .from('portfolio-images')
          .getPublicUrl(path)
          .trim();
    }

    if (lower.startsWith('artists/') ||
        lower.startsWith('client_artists/') ||
        lower.startsWith('portfolio/')) {
      return Supabase.instance.client.storage
          .from('portfolio-images')
          .getPublicUrl(value)
          .trim();
    }

    return '';
  }

  bool _isDisplayableImageUrl(String raw) {
    final value = _toDisplayableImage(raw).trim().toLowerCase();
    if (value.isEmpty) return false;
    if (value.startsWith('data:image/')) return true;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }
    return false;
  }

  void _openNotifications(BuildContext context) {
    NotificationsPage.showAsModal(context);
  }

  Future<void> _openProfileMenu(
    BuildContext context,
    GlobalKey anchorKey,
  ) async {
    if (anchorKey.currentContext == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final menuAnchorRect = Rect.fromLTWH(
      bottomRight.dx - 2,
      bottomRight.dy + 8,
      2,
      2,
    );

    final items = <PopupMenuEntry<String>>[
      if (widget.showProfileMenuInAvatar)
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: <Widget>[
              Icon(Icons.person_outline, size: 20, color: AppColors.blackCat),
              SizedBox(width: 10),
              Text(
                'Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackCat,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      if (widget.showProfileMenuInAvatar) const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: <Widget>[
            Icon(Icons.logout_rounded, size: 20, color: AppColors.blackCat),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ];

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        menuAnchorRect,
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      color: Colors.white,
      items: items,
    );

    if (!context.mounted) return;

    if (choice == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }

    if (choice == 'logout') {
      await widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileKey = GlobalKey();

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: Container(
          color: AppColors.alabaster,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Stack(
                children: <Widget>[
                  Center(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        'assets/images/jnt_logo_black.png',
                        height: 50,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: NotificationBellButton(
                        onTap: () => _openNotifications(context),
                        focusNode: _notificationsFocusNode,
                        unreadCount: 0,
                        iconSize: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Open profile menu',
                        child: InkWell(
                          key: profileKey,
                          borderRadius: BorderRadius.zero,
                          onTap: () => _openProfileMenu(context, profileKey),
                          child: SizedBox(
                            height: 36,
                            width: 36,
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: _SafeSquareAvatar(
                                imageUrl: _clientAvatarUrl,
                                displayName: widget.clientName,
                                size: 36,
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
      ),
      body: Column(
        children: <Widget>[
          if (widget.headerBottom != null) widget.headerBottom!,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPortfolioFeed,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: <Widget>[
                  const SizedBox(height: 4),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 28, bottom: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_tiles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Text(
                        'No portfolio images available right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tiles.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                      itemBuilder: (context, index) {
                        final tile = _tiles[index];
                        return _PortfolioTile(
                          data: tile,
                          onTap: () => _openImagePreview(tile.imagePath),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openImagePreview(String path) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ImagePreviewDialog(path: path),
    );
  }
}


class _SafeSquareAvatar extends StatelessWidget {
  const _SafeSquareAvatar({
    required this.imageUrl,
    required this.displayName,
    required this.size,
  });

  final Object? imageUrl;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final src = _cleanImageValue(imageUrl);

    if (src.startsWith('data:image/')) {
      final bytes = _decodeDataImageBytes(src);
      if (bytes != null) {
        return SizedBox.square(
          dimension: size,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      }
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return SizedBox.square(
        dimension: size,
        child: Image.network(
          src,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    final name = displayName.trim();
    final letter = name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase();

    return SizedBox.square(
      dimension: size,
      child: Container(
        color: AppColors.balletSlippers,
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      ),
    );
  }

  String _cleanImageValue(Object? raw) {
    if (raw == null) return '';
    if (raw is Map) {
      for (final key in const [
        'profileImageUrl',
        'profilePhotoUrl',
        'photoUrl',
        'avatarUrl',
        'logoUrl',
        'url',
        'imageUrl',
        'downloadUrl',
      ]) {
        final value = (raw[key] ?? '').toString().trim();
        if (value.isNotEmpty) return _cleanImageValue(value);
      }
      return '';
    }

    final value = raw.toString().trim();
    if (value.isEmpty) return '';

    final lower = value.toLowerCase();
    if (lower.startsWith('assets/')) return '';
    if (lower.startsWith('gs://')) return '';
    if (lower.startsWith('clients/')) return '';
    if (lower.startsWith('artists/')) return '';
    if (lower.startsWith('client_artists/')) return '';
    if (lower.startsWith('company/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';

    return value;
  }
}

class _PortfolioTileData {
  const _PortfolioTileData({
    required this.artistName,
    required this.tierLabel,
    required this.artistAvatarUrl,
    required this.imagePath,
  });

  final String artistName;
  final String tierLabel;
  final String artistAvatarUrl;
  final String imagePath;
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({required this.data, required this.onTap});

  final _PortfolioTileData data;
  final VoidCallback onTap;

  Widget _smallRoundedAvatar() {
    return _SafeSquareAvatar(
      imageUrl: data.artistAvatarUrl.trim(),
      displayName: data.artistName,
      size: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: _ResolvedPortfolioImage(path: data.imagePath),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                decoration: const BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.10),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _smallRoundedAvatar(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedPortfolioImage extends StatelessWidget {
  const _ResolvedPortfolioImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeImagePath(path);
    final dataBytes = _decodeDataImageBytes(normalized);

    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: Colors.black.withValues(alpha: 0.04),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _ResolvedPortfolioImage(path: path),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeImagePath(String raw) {
  var p = raw.trim();
  if (p.isEmpty) return '';

  if (p.startsWith('assets/')) {
    final rest = p.substring('assets/'.length);
    final decodedRest = _decodeRepeatedUri(rest).trim();
    final lower = decodedRest.toLowerCase();
    if (lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return decodedRest;
    }
  }

  p = _decodeRepeatedUri(p).trim();

  if (p.startsWith('assets/')) {
    final rest = p.substring('assets/'.length);
    final decodedRest = _decodeRepeatedUri(rest).trim();
    final lower = decodedRest.toLowerCase();
    if (lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return decodedRest;
    }
  }

  return p;
}

String _decodeRepeatedUri(String value) {
  var out = value;
  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeFull(out);
      if (decoded == out) break;
      out = decoded;
    } catch (_) {
      break;
    }
  }
  return out;
}

Uint8List? _decodeDataImageBytes(String value) {
  final src = value.trim();
  if (!src.startsWith('data:image/')) return null;
  final comma = src.indexOf(',');
  if (comma <= 0 || comma >= src.length - 1) return null;

  try {
    return base64Decode(src.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
