// lib/pages/client_home_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/profile_table_columns.dart';
import '../theme/app_colors.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';

String _artistLocationText(String city, String state, String zip) {
  final left = <String>[
    city.trim(),
    state.trim(),
  ].where((value) => value.isNotEmpty).join(', ');
  final postal = zip.trim();
  if (left.isEmpty) return postal;
  if (postal.isEmpty) return left;
  return '$left, $postal';
}

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({
    super.key,
    required this.clientName,
    required this.profileComplete,
    required this.onLogout,
    this.profileImageUrl = '',
    this.headerBottom,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenEarnings,
    this.onOpenReviews,
    this.onRequestArtist,
    this.showExtendedAvatarMenu = false,
    this.tapArtistTileOpensImageOnly = false,
  });

  final String clientName;
  final bool profileComplete;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenReviews;
  final Future<void> Function() onLogout;
  final String profileImageUrl;
  final Widget? headerBottom;
  final ValueChanged<String>? onRequestArtist;
  final bool showExtendedAvatarMenu;
  final bool tapArtistTileOpensImageOnly;

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  static const Color _focusRing = Color(0xFFFFBF47);

  bool _loadingProducts = true;
  List<_Product> _products = const <_Product>[];
  String _resolvedHeaderAvatarUrl = '';
  int _unreadCount = 0;
  bool _allowAvatarFocus = false;

  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'notificationsButton',
  );
  final FocusNode _profileMenuFocusNode = FocusNode(
    debugLabel: 'profileMenuButton',
  );

  String get _unreadAnnouncementText {
    if (_unreadCount == 1) return '1 unread notification';
    return '$_unreadCount unread notifications';
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _resolvedHeaderAvatarUrl = widget.profileImageUrl.trim();
    unawaited(_loadHeaderAvatarUrl());
    unawaited(_loadTrendingProducts());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      unawaited(_focusNotificationsForAda());
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() => _allowAvatarFocus = true);
    });
  }

  @override
  void didUpdateWidget(covariant ClientHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextAvatar = widget.profileImageUrl.trim();
    final prevAvatar = oldWidget.profileImageUrl.trim();

    if (nextAvatar != prevAvatar && nextAvatar.isNotEmpty) {
      if (_resolvedHeaderAvatarUrl != nextAvatar) {
        setState(() => _resolvedHeaderAvatarUrl = nextAvatar);
      }
      return;
    }

    if (nextAvatar.isEmpty && prevAvatar.isNotEmpty) {
      unawaited(_loadHeaderAvatarUrl());
    }
  }

  @override
  void dispose() {
    _notificationsFocusNode.dispose();
    _profileMenuFocusNode.dispose();
    super.dispose();
  }

  Future<void> _focusNotificationsForAda() async {
    if (!mounted || !widget.profileComplete) return;
    final direction = Directionality.of(context);
    _notificationsFocusNode.requestFocus();
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Notifications, $_unreadAnnouncementText',
      direction,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || !widget.profileComplete) return;
    _notificationsFocusNode.requestFocus();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted || !widget.profileComplete) return;
    _notificationsFocusNode.requestFocus();
  }

  Future<void> _loadHeaderAvatarUrl() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();

    if (uid.isEmpty && email.isEmpty) return;

    for (final table in const <String>['client', 'client_artist']) {
      final data = await _readProfileRow(table: table, uid: uid, email: email);
      if (data == null) continue;

      final profile = _asMap(data['profile']);
      final basic = _asMap(data['basic']);

      final avatar = _firstNonEmpty([
        data['profileImageUrl'],
        data['avatarUrl'],
        data['photoUrl'],
        profile['profileImageUrl'],
        profile['avatarUrl'],
        profile['photoUrl'],
        basic['profileImageUrl'],
        basic['avatarUrl'],
        basic['photoUrl'],
      ]);

      if (avatar.isEmpty) continue;
      if (!mounted) return;

      setState(() => _resolvedHeaderAvatarUrl = avatar);
      return;
    }
  }

  Future<Map<String, dynamic>?> _readProfileRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    final supabase = Supabase.instance.client;
    final columns = columnsForProfileTable(table) ?? '*';

    try {
      if (uid.isNotEmpty) {
        final rows = await supabase.from(table).select(columns).eq('id', uid).limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      }

      if (email.isNotEmpty) {
        final rows = await supabase
            .from(table)
            .select(columns)
            .eq('email', email)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      }
    } catch (e) {
      debugPrint('CLIENT HOME PROFILE LOAD FAILED [$table]: $e');
    }

    return null;
  }

  Future<void> _loadTrendingProducts() async {
    try {
      final products = <_Product>[];

      final artistRows = await _readArtistRows('artist');
      final clientArtistRows = await _readArtistRows('client_artist');

      for (final row in artistRows) {
        _collectProductsFromArtistRow(row, products);
      }

      for (final row in clientArtistRows) {
        _collectProductsFromArtistRow(row, products);
      }

      final unique = _dedupeProducts(products);

      if (!mounted) return;
      setState(() {
        _products = unique;
        _loadingProducts = false;
      });
    } catch (e, st) {
      debugPrint('CLIENT HOME ARTIST LOAD FAILED: $e');
      debugPrint(st.toString());

      if (!mounted) return;
      setState(() {
        _products = const <_Product>[];
        _loadingProducts = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _readArtistRows(String table) async {
    try {
      final columns = columnsForProfileTable(table) ?? '*';
      final rows = await Supabase.instance.client
          .from(table)
          .select(columns)
          .limit(300);

      return rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      debugPrint('CLIENT HOME ARTIST TABLE LOAD FAILED [$table]: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  void _collectProductsFromArtistRow(
    Map<String, dynamic> data,
    List<_Product> out,
  ) {
    final profile = _asMap(data['profile']);
    final artist = _asMap(data['artist']);
    final artistProfile = _asMap(data['artist_profile']);
    final address = _asMap(data['address']);
    final portfolio = _asMap(data['portfolio']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final pricing = _asMap(data['pricing']);
    final artistPricing = _asMap(
      data['pricing'].toString().isEmpty ? null : data['pricing'],
    );
    final credentials = _asMap(data['credentials']);
    final artistCredentials = _asMap(artist['credentials']);
    final availability = _asMap(data['availability']);
    final artistAvailability = _asMap(artist['availability']);

    final rawArtistName = _firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      profile['nameOrStudio'],
      profile['name'],
      artistProfile['displayName'],
      artistProfile['studioName'],
      data['panel_displayName'],
      data['panel_nameOrStudio'],
      data['displayName'],
      data['name'],
      data['email'],
    ]);
    final artistEmail = _firstNonEmpty([
      profile['email'],
      artistProfile['email'],
      data['panel_email'],
      data['email'],
      artist['email'],
    ]);
    final artistName = _normalizeArtistName(rawArtistName, artistEmail);
    if (artistName.isEmpty) return;

    final urls = <String>[];
    _collectUrls(data['portfolioImages'], urls);
    _collectUrls(data['panel_artist_portfolioImages'], urls);
    _collectUrls(data['panel_portfolioImages'], urls);
    _collectUrls(data['portfolioItems'], urls);
    _collectUrls(portfolio['images'], urls);
    _collectUrls(portfolio['items'], urls);
    _collectUrls(artist['portfolioImages'], urls);
    _collectUrls(artist['portfolioItems'], urls);
    _collectUrls(artistPortfolio['images'], urls);
    _collectUrls(artistPortfolio['items'], urls);

    final imageUrls = _dedupeUrls(
      urls,
    ).where(_isDisplayableImageUrl).take(16).toList(growable: false);

    if (imageUrls.isEmpty) return;

    final avatarUrl = _firstNonEmpty([
      profile['profileImageUrl'],
      profile['profilePhotoUrl'],
      profile['photoUrl'],
      profile['avatarUrl'],
      artistProfile['profileImageUrl'],
      artistProfile['profilePhotoUrl'],
      artistProfile['photoUrl'],
      artistProfile['avatarUrl'],
      data['panel_profileImageUrl'],
      data['profileImageUrl'],
      data['profilePhotoUrl'],
      data['photoUrl'],
      data['avatarUrl'],
      artist['profileImageUrl'],
      artist['profilePhotoUrl'],
      artist['photoUrl'],
      artist['avatarUrl'],
    ]);

    final city = _firstNonEmpty([
      address['city'],
      profile['city'],
      artistProfile['city'],
      artist['city'],
      data['panel_city'],
      data['city'],
    ]);

    final state = _firstNonEmpty([
      address['state'],
      profile['state'],
      artistProfile['state'],
      artist['state'],
      data['panel_state'],
      data['state'],
    ]);

    final zip = _firstNonEmpty([
      address['zip'],
      address['postal_code'],
      profile['zip'],
      profile['postal_code'],
      artistProfile['zip'],
      artistProfile['postal_code'],
      artist['zip'],
      artist['postal_code'],
      data['panel_zip'],
      data['zip'],
      data['postal_code'],
    ]);

    final credential =
        _firstNonEmpty([
              credentials['nailTechType'],
              artistCredentials['nailTechType'],
              data['panel_nailTechType'],
              profile['nailTechType'],
            ]).toLowerCase() ==
            'student'
        ? 'Student/Unlicensed'
        : 'Professional';

    final tierLabel = _tierLabelFrom(data, profile);
    final rating = _asDouble(_asMap(data['stats'])['rating'] ?? data['rating']);

    final budgetMin = _asInt(
      pricing['minPrice'] ??
          artistPricing['minPrice'] ??
          data['panel_minPrice'] ??
          artist['minPrice'],
      50,
    );

    final budgetMax = _asInt(
      pricing['maxPrice'] ??
          artistPricing['maxPrice'] ??
          data['panel_maxPrice'] ??
          artist['maxPrice'],
      200,
    );

    final acceptsNfcRequests = _asBool(
      data['panel_nfcRequestEnabled'] ??
          availability['nfcRequestEnabled'] ??
          profile['nfcRequestEnabled'] ??
          artist['nfcRequestEnabled'] ??
          artistAvailability['nfcRequestEnabled'],
      fallback: false,
    );

    final bio = _firstNonEmpty([
      profile['bio'],
      artistProfile['bio'],
      data['bio'],
    ]);

    final projectNotes = _firstNonEmpty([
      portfolio['projectNotes'],
      artistPortfolio['projectNotes'],
      data['projectNotes'],
    ]);

    for (final image in imageUrls) {
      out.add(
        _Product(
          imageAsset: '',
          imageUrl: image,
          avatarUrl: avatarUrl,
          tierLabel: tierLabel,
          artistName: artistName,
          rating: rating,
          city: city,
          state: state,
          zip: zip,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          credential: credential,
          bio: bio,
          projectNotes: projectNotes,
          previousProjects: imageUrls,
          acceptsNfcRequests: acceptsNfcRequests,
        ),
      );
    }
  }

  String _normalizeArtistName(String rawName, String rawEmail) {
    final name = rawName.trim();
    if (name.isNotEmpty && !name.contains('@')) return name;

    final email = rawEmail.trim();
    if (email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }

    if (name.isNotEmpty) {
      return name.replaceAll('@', '').trim();
    }

    return 'Artist';
  }

  List<_Product> _dedupeProducts(List<_Product> input) {
    final seen = <String>{};
    final output = <_Product>[];

    for (final product in input) {
      final key =
          '${product.artistName.trim().toLowerCase()}|${product.imageUrl.trim().split('?').first}';
      if (seen.add(key)) {
        output.add(product);
      }
      if (output.length >= 60) break;
    }

    return output;
  }

  List<String> _dedupeUrls(List<String> urls) {
    final seen = <String>{};
    final output = <String>[];

    for (final raw in urls) {
      final value = raw.trim();
      if (value.isEmpty) continue;

      final key = value.split('?').first;
      if (seen.add(key)) {
        output.add(value);
      }
    }

    return output;
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
      return;
    }
  }

  bool _isDisplayableImageUrl(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (value.startsWith('data:image/')) return true;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return true;
    }

    // Do not render old storage paths directly.
    // Only public URLs or data URLs are displayable on this Supabase-only page.
    return false;
  }

  String _tierLabelFrom(
    Map<String, dynamic> data,
    Map<String, dynamic> profile,
  ) {
    final ascension = _asMap(data['ascension']);
    final sponsorshipRequest = _asMap(data['sponsorshipRequest']);

    for (final raw in <Object?>[
      data['sponsorshipTier'],
      data['ascensionTier'],
      ascension['tier'],
      ascension['levelName'],
      sponsorshipRequest['tier'],
      profile['ascensionTier'],
    ]) {
      final normalized = (raw ?? '').toString().trim().toLowerCase();
      if (normalized == 'goldsmith') return 'Goldsmith';
      if (normalized == 'crowned') return 'Crowned';
    }

    return 'Maker';
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
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

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  void _openNotifications(BuildContext context) {
    NotificationsPage.showAsModal(context);
  }

  Future<void> _openProfileMenu(
    BuildContext context,
    GlobalKey anchorKey,
  ) async {
    if (anchorKey.currentContext == null) return;

    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? box =
        anchorKey.currentContext!.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;
    final Offset bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final menuAnchorRect = Rect.fromLTWH(
      bottomRight.dx - 2,
      bottomRight.dy + 8,
      2,
      2,
    );

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        menuAnchorRect,
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      color: Colors.white,
      items: <PopupMenuEntry<String>>[
        if (widget.showExtendedAvatarMenu)
          const PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: <Widget>[
                Icon(Icons.person_outline, size: 20),
                SizedBox(width: 10),
                Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu && widget.onOpenEarnings != null)
          const PopupMenuItem<String>(
            value: 'earnings',
            child: Row(
              children: <Widget>[
                Icon(Icons.attach_money_outlined, size: 20),
                SizedBox(width: 10),
                Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu)
          const PopupMenuItem<String>(
            value: 'history',
            child: Row(
              children: <Widget>[
                Icon(Icons.history, size: 20),
                SizedBox(width: 10),
                Text('History', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu)
          const PopupMenuItem<String>(
            value: 'calendar',
            child: Row(
              children: <Widget>[
                Icon(Icons.calendar_month_outlined, size: 20),
                SizedBox(width: 10),
                Text('Calendar', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu)
          const PopupMenuItem<String>(
            value: 'artist',
            child: Row(
              children: <Widget>[
                Icon(Icons.brush_outlined, size: 20),
                SizedBox(width: 10),
                Text('Artist', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu)
          const PopupMenuItem<String>(
            value: 'reviews',
            child: Row(
              children: <Widget>[
                Icon(Icons.star_border, size: 20),
                SizedBox(width: 10),
                Text('Reviews', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (widget.showExtendedAvatarMenu) const PopupMenuDivider(),
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
      ],
    );

    if (choice == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (choice == 'earnings') {
      widget.onOpenEarnings?.call();
      return;
    }
    if (choice == 'history') {
      widget.onOpenHistory?.call();
      return;
    }
    if (choice == 'calendar') {
      widget.onOpenCalendar?.call();
      return;
    }
    if (choice == 'artist') {
      widget.onOpenArtist?.call();
      return;
    }
    if (choice == 'reviews') {
      if (widget.onOpenReviews != null) {
        widget.onOpenReviews?.call();
      } else {
        if (!mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ArtistReviewsPage()));
      }
      return;
    }
    if (choice == 'logout') {
      await widget.onLogout();
    }
  }

  void _openProductImagePreview(String imageSrc) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Artist photo preview',
          explicitChildNodes: true,
          child: Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: _buildAnyImage(
                        imageSrc,
                        fit: BoxFit.contain,
                        fallback: Container(
                          color: AppColors.snow,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: 'Close photo preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.blackCat,
                    ),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey profileKey = GlobalKey();

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Client home',
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: JntStandardAppBar(
          onNotifications: () => _openNotifications(context),
          leading: _CustomSemanticAction(
            label: 'Notifications',
            value: _unreadAnnouncementText,
            onTap: () => _openNotifications(context),
            focusNode: _notificationsFocusNode,
            focusRingColor: _focusRing,
            autofocus: true,
            sortKey: const OrdinalSortKey(0),
            child: NotificationBellButton(
              onTap: () => _openNotifications(context),
              iconSize: JntHeaderMetrics.notificationIconSize,
            ),
          ),
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          trailing: _CustomSemanticAction(
            label: 'Open profile menu',
            onTap: () => _openProfileMenu(context, profileKey),
            focusRingColor: _focusRing,
            focusNode: _profileMenuFocusNode,
            sortKey: const OrdinalSortKey(20),
            child: ExcludeSemantics(
              excluding: !_allowAvatarFocus,
              child: InkWell(
                key: profileKey,
                borderRadius: BorderRadius.zero,
                onTap: () => _openProfileMenu(context, profileKey),
                child: SizedBox.square(
                  dimension: JntHeaderMetrics.avatarSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: ClientProfileAvatarIcon(
                      imageUrl: _resolvedHeaderAvatarUrl,
                      displayName: widget.clientName,
                      size: JntHeaderMetrics.avatarSize,
                      resolveCurrentUserFallback: true,
                    ),
                  ),
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
                onRefresh: _loadTrendingProducts,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: <Widget>[
                    const SizedBox(height: 14),
                    const SizedBox(height: 6),
                    if (_loadingProducts)
                      Semantics(
                        label: 'Loading featured artists',
                        child: Padding(
                          padding: EdgeInsets.only(top: 28, bottom: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_products.isEmpty)
                      Semantics(
                        label: 'No artists available right now',
                        child: Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 20),
                          child: ExcludeSemantics(
                            child: Text(
                              'No artists available right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          return _ProductTile(
                            product: p,
                            onTap: () => widget.tapArtistTileOpensImageOnly
                                ? _openProductImagePreview(p.imageUrl)
                                : _openArtistDetails(p),
                            focusRingColor: _focusRing,
                          );
                        },
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

  Future<void> _openArtistDetails(_Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ArtistDetailsSheet(
        product: product,
        onRequest: () {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onRequestArtist?.call(product.artistName);
          });
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.focusRingColor,
  });

  final _Product product;
  final VoidCallback onTap;
  final Color focusRingColor;

  @override
  Widget build(BuildContext context) {
    final ratingLabel = product.rating > 0
        ? product.rating.toStringAsFixed(1)
        : 'N/A';
    final locationLabel = _artistLocationText(
      product.city,
      product.state,
      product.zip,
    );

    return _CustomSemanticAction(
      label:
          'View artist details for ${product.artistName}. Tier ${product.tierLabel}. Rating $ratingLabel. Location $locationLabel.',
      onTap: onTap,
      focusRingColor: focusRingColor,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: product.imageUrl.isNotEmpty
                      ? _buildAnyImage(
                          product.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          fallback: _fallbackImage(),
                        )
                      : _fallbackImage(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: _TileAvatar(
                        name: product.artistName,
                        avatarUrl: product.avatarUrl,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        product.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
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
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.04),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}

class _TileAvatar extends StatelessWidget {
  const _TileAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  bool _isValidAvatar(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('assets/')) return false;
    if (v.contains('profile_placeholder')) return false;
    if (v.contains('avatar_placeholder')) return false;
    return v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:image/');
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl.trim();

    if (_isValidAvatar(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: _buildAnyImage(
          url,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          fallback: _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    final letter = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class _Product {
  const _Product({
    required this.imageAsset,
    required this.imageUrl,
    required this.avatarUrl,
    required this.tierLabel,
    required this.artistName,
    required this.rating,
    required this.city,
    required this.state,
    required this.zip,
    required this.budgetMin,
    required this.budgetMax,
    required this.credential,
    required this.bio,
    required this.projectNotes,
    required this.previousProjects,
    required this.acceptsNfcRequests,
  });

  final String imageAsset;
  final String imageUrl;
  final String avatarUrl;
  final String tierLabel;
  final String artistName;
  final double rating;
  final String city;
  final String state;
  final String zip;
  final int budgetMin;
  final int budgetMax;
  final String credential;
  final String bio;
  final String projectNotes;
  final List<String> previousProjects;
  final bool acceptsNfcRequests;
}

class _NfcTag extends StatelessWidget {
  const _NfcTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'Accepts NFC',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ArtistDetailsSheet extends StatelessWidget {
  const _ArtistDetailsSheet({required this.product, required this.onRequest});

  final _Product product;
  final VoidCallback onRequest;

  bool _isValidAvatar(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('assets/')) return false;
    if (v.contains('profile_placeholder')) return false;
    if (v.contains('avatar_placeholder')) return false;
    return v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:image/');
  }

  void _openPhotoPreview(BuildContext context, String imageSrc) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Artist photo preview',
          explicitChildNodes: true,
          child: Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: _buildAnyImage(
                        imageSrc,
                        fit: BoxFit.contain,
                        fallback: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white70,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: 'Close photo preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Artist details for ${product.artistName}',
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: AppColors.alabaster,
            borderRadius: BorderRadius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SizedBox(width: 40),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: _isValidAvatar(product.avatarUrl)
                                  ? _buildAnyImage(
                                      product.avatarUrl,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      fallback: _fallbackAvatar(
                                        product.artistName,
                                      ),
                                    )
                                  : _fallbackAvatar(product.artistName),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    product.artistName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        product.rating > 0
                                            ? product.rating.toStringAsFixed(1)
                                            : 'N/A',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.city.trim().isEmpty &&
                                            product.state.trim().isEmpty &&
                                            product.zip.trim().isEmpty
                                        ? ''
                                        : _artistLocationText(
                                            product.city,
                                            product.state,
                                            product.zip,
                                          ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Budget: \$${product.budgetMin} - \$${product.budgetMax}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.balletSlippers,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(color: AppColors.alabaster),
                          ),
                          child: Text(
                            product.credential,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (product.bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Artist Bio',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.bio.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.75),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (product.projectNotes.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Project Notes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.projectNotes.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.75),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Previous Art',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: product.previousProjects.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No previous art uploaded yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: product.previousProjects.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (_, i) => ClipRRect(
                                    borderRadius: BorderRadius.zero,
                                    child: _CustomSemanticAction(
                                      label:
                                          'Open previous art image ${i + 1} for ${product.artistName}',
                                      onTap: () => _openPhotoPreview(
                                        context,
                                        product.previousProjects[i],
                                      ),
                                      focusRingColor: const Color(0xFFFFBF47),
                                      child: _buildAnyImage(
                                        product.previousProjects[i],
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        fallback: Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
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
                const SizedBox(height: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: Semantics(
                        label: 'Request artist ${product.artistName}',
                        child: ElevatedButton(
                          onPressed: onRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text(
                            'Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (product.acceptsNfcRequests) ...[
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _NfcTag(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String artistName) {
    final letter = artistName.trim().isEmpty
        ? 'A'
        : artistName.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 84,
      height: 84,
      color: AppColors.balletSlippers,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class _CustomSemanticAction extends StatefulWidget {
  const _CustomSemanticAction({
    required this.label,
    this.value,
    required this.onTap,
    required this.child,
    required this.focusRingColor,
    this.focusNode,
    this.autofocus = false,
    this.sortKey,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final Widget child;
  final Color focusRingColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final SemanticsSortKey? sortKey;

  @override
  State<_CustomSemanticAction> createState() => _CustomSemanticActionState();
}

class _CustomSemanticActionState extends State<_CustomSemanticAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final showAdaFocusRing =
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
    return Semantics(
      container: true,
      button: true,
      sortKey: widget.sortKey,
      label: widget.label,
      value: widget.value,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (v) => setState(() => _focused = v),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            decoration: BoxDecoration(
              border: (showAdaFocusRing && _focused)
                  ? Border.all(color: widget.focusRingColor, width: 2)
                  : null,
            ),
            child: ExcludeSemantics(child: widget.child),
          ),
        ),
      ),
    );
  }
}

Widget _buildAnyImage(
  String src, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  final value = _normalizeImageRef(src);
  if (value.isEmpty) return fallback;

  // Cap decode resolution to roughly what's actually displayed instead of
  // decoding at full native camera resolution (often 40+MB per image as an
  // uncompressed bitmap regardless of how small it's drawn) — this is what
  // was driving an EXC_RESOURCE memory crash when a list of several artist
  // avatars/portfolio thumbnails rendered at once. The *3 accounts for
  // high-density (3x) screens without needing a BuildContext here.
  final cacheWidth = (width != null && width.isFinite)
      ? (width * 3).round()
      : null;
  final cacheHeight = (height != null && height.isFinite)
      ? (height * 3).round()
      : null;

  if (value.startsWith('data:image/')) {
    final comma = value.indexOf(',');
    if (comma > 0 && comma < value.length - 1) {
      try {
        final bytes = base64Decode(value.substring(comma + 1));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    return fallback;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  return fallback;
}

String _normalizeImageRef(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  if (value.startsWith('assets/')) {
    final rest = value.substring('assets/'.length);
    final decodedRest = Uri.decodeFull(rest);
    if (decodedRest.startsWith('data:') ||
        decodedRest.startsWith('blob:') ||
        decodedRest.startsWith('http://') ||
        decodedRest.startsWith('https://')) {
      value = decodedRest;
    }
  }

  for (var i = 0; i < 3; i++) {
    final decoded = Uri.decodeFull(value);
    if (decoded == value) break;
    value = decoded;
  }

  return value.trim();
}
