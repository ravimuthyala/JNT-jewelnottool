import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';

import '../theme/app_colors.dart';
import 'client_custom_request_with_artist_page.dart';
import 'notifications_page.dart';
import '../models/client_profile_models.dart';
import '../widgets/company_shell_chrome.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';

class ClientArtistsPage extends StatefulWidget {
  const ClientArtistsPage({
    super.key,
    required this.profile,
    this.onRequestArtist, // ✅ NEW
    this.onBackHome,
    this.showCompanyChrome = false,
    this.companyName,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onLogout,
    this.showProfileMenu = false,
    this.showHistoryMenu = false,
    this.showCalendarMenu = false,
    this.showArtistMenu = false,
    this.bottomNavIndex = 2,
    this.onNavTap,
    this.isActiveTab = true,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final bool showCompanyChrome;
  final String? companyName;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final Future<void> Function()? onLogout;
  final bool showProfileMenu;
  final bool showHistoryMenu;
  final bool showCalendarMenu;
  final bool showArtistMenu;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final bool isActiveTab;

  // ✅ Scenario 2: when inside ClientShellPage, use this so Shell can
  // enable all tabs + jump to Design (no push).
  final ValueChanged<String>? onRequestArtist; // ✅ NEW

  @override
  State<ClientArtistsPage> createState() => _ClientArtistsPageState();
}

class _ClientArtistsPageState extends State<ClientArtistsPage> {
  List<ArtistProfile> _artists = const [];
  bool _loadingArtists = true;
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'artistsNotificationsButton',
  );
  bool _didSetInitialA11yFocus = false;
  bool _focusRequestQueued = false;

  String? _selectedArtistId;

  @override
  void initState() {
    super.initState();
    _loadArtists();
    _scheduleInitialA11yFocus();
  }

  void _scheduleInitialA11yFocus() {
    if (_didSetInitialA11yFocus || _focusRequestQueued || !widget.isActiveTab) {
      return;
    }

    _focusRequestQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didSetInitialA11yFocus || !widget.isActiveTab) {
        _focusRequestQueued = false;
        return;
      }

      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) {
        _focusRequestQueued = false;
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted || _didSetInitialA11yFocus || !widget.isActiveTab) {
        _focusRequestQueued = false;
        return;
      }

      final currentRoute = ModalRoute.of(context);
      if (currentRoute?.isCurrent != true) {
        _focusRequestQueued = false;
        return;
      }

      _didSetInitialA11yFocus = true;
      _focusRequestQueued = false;
      _notificationsFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant ClientArtistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActiveTab && widget.isActiveTab) {
      _didSetInitialA11yFocus = false;
      _scheduleInitialA11yFocus();
    }
  }

  @override
  void dispose() {
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadArtists() async {
    try {
      final rows = <Map<String, dynamic>>[];
      rows.addAll(await _readArtistRows('artist'));
      rows.addAll(await _readArtistRows('client_artist'));

      debugPrint('CLIENT ARTISTS PAGE SUPABASE TOTAL ROWS = ${rows.length}');
      if (rows.isNotEmpty) {
        debugPrint('CLIENT ARTISTS PAGE FIRST ROW = ${rows.first}');
      }

      final profiles = rows
          .map(_artistProfileFromSupabaseRow)
          .whereType<ArtistProfile>()
          .toList(growable: false);

      final dedup = <String, ArtistProfile>{};
      for (final p in profiles) {
        final key = p.id.trim().isNotEmpty
            ? p.id.trim()
            : p.email.trim().toLowerCase();
        if (key.isEmpty) continue;
        final existing = dedup[key];
        dedup[key] = existing == null
            ? p
            : (p.projects.length > existing.projects.length ? p : existing);
      }

      final resolvedProfiles = dedup.values.toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      debugPrint(
        'CLIENT ARTISTS PAGE DISPLAY PROFILES = ${resolvedProfiles.length}',
      );

      if (!mounted) return;
      setState(() {
        _artists = resolvedProfiles;
        if (_selectedArtistId != null &&
            !_artists.any((a) => a.id == _selectedArtistId)) {
          _selectedArtistId = null;
        }
        _loadingArtists = false;
      });
    } catch (e, st) {
      debugPrint('ClientArtistsPage Supabase _loadArtists error: $e');
      debugPrint(st.toString());
      if (!mounted) return;
      setState(() {
        _artists = const <ArtistProfile>[];
        _selectedArtistId = null;
        _loadingArtists = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _readArtistRows(String table) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select()
          .limit(500);

      debugPrint('ClientArtistsPage Supabase rows [$table] = ${rows.length}');

      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (e) {
      debugPrint('ClientArtistsPage Supabase table load failed [$table]: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<String> _asStringList(Object? raw) {
    if (raw is Iterable) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return <String>[raw.trim()];
    }
    return const <String>[];
  }

  int _asInt(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse((raw ?? '').toString().trim()) ?? fallback;
  }

  double _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  bool _asBool(Object? raw, {bool fallback = false}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'true' || value == 'yes' || value == '1') return true;
    if (value == 'false' || value == 'no' || value == '0') return false;
    return fallback;
  }

  ArtistProfile? _artistProfileFromSupabaseRow(Map<String, dynamic> data) {
    final profile = _asMap(data['profile']);
    final portfolio = _asMap(data['portfolio']);
    final artist = _asMap(data['artist']);
    final artistProfile = _asMap(artist['profile']);
    final artistPortfolio = _asMap(artist['portfolio']);
    final address = _asMap(data['address']);
    final artistAddress = _asMap(artist['address']);
    final pricing = _asMap(data['pricing']);
    final artistPricing = _asMap(artist['pricing']);
    final credentials = _asMap(data['credentials']);
    final artistCredentials = _asMap(artist['credentials']);
    final availability = _asMap(data['availability']);
    final artistAvailability = _asMap(artist['availability']);
    final ascension = _asMap(data['ascension']);
    final sponsorshipRequest = _asMap(data['sponsorshipRequest']);
    final stats = _asMap(data['stats']);

    final name = _firstNonEmpty([
      profile['displayName'],
      profile['studioName'],
      profile['nameOrStudio'],
      profile['name'],
      artistProfile['displayName'],
      artistProfile['studioName'],
      data['panel_displayName'],
      data['panel_nameOrStudio'],
      data['displayName'],
      data['studioName'],
      data['name'],
    ]);

    if (name.isEmpty) {
      debugPrint('ClientArtistsPage skipped row because name is empty: $data');
      return null;
    }

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
      profile['profilePhotoUrl'],
      profile['photoUrl'],
      profile['avatarUrl'],
      artistProfile['profileImageUrl'],
      artistProfile['profilePhotoUrl'],
      artistProfile['photoUrl'],
      artistProfile['avatarUrl'],
      data['panel_profileImageUrl'],
      data['panel_avatarUrl'],
      data['profileImageUrl'],
      data['profilePhotoUrl'],
      data['photoUrl'],
      data['avatarUrl'],
      artist['profileImageUrl'],
      artist['profilePhotoUrl'],
      artist['photoUrl'],
      artist['avatarUrl'],
    ]);

    final bio = _firstNonEmpty([
      data['panel_bio'],
      profile['bio'],
      data['bio'],
      artist['bio'],
    ]);

    final language = _firstNonEmpty([
      data['panel_languageSpoken'],
      profile['languageSpoken'],
      data['languageSpoken'],
      artist['languageSpoken'],
    ]);

    final currency = _firstNonEmpty([
      data['panel_currency'],
      profile['currency'],
      data['currency'],
      artist['currency'],
    ]);

    final yearsExperience = _firstNonEmpty([
      data['panel_proYearsExperience'],
      profile['proYearsExperience'],
      data['proYearsExperience'],
      artist['proYearsExperience'],
      data['panel_yearsExperience'],
      profile['yearsExperience'],
      data['yearsExperience'],
      artist['yearsExperience'],
      data['panel_experienceYears'],
      profile['experienceYears'],
      data['experienceYears'],
      artist['experienceYears'],
      data['panel_practiceDuration'],
      profile['practiceDuration'],
      data['practiceDuration'],
      artist['practiceDuration'],
    ]);

    final services = [
      ..._asStringList(data['panel_services']),
      ..._asStringList(data['services']),
      ..._asStringList(artist['services']),
    ].toSet().toList(growable: false);

    final urls = <String>[];
    _collectImageUrls(portfolio['items'], urls);
    _collectImageUrls(portfolio['images'], urls);
    _collectImageUrls(portfolio['urls'], urls);
    _collectImageUrls(portfolio['photos'], urls);
    _collectImageUrls(data['portfolioImages'], urls);
    _collectImageUrls(data['portfolioItems'], urls);
    _collectImageUrls(data['previousArt'], urls);
    _collectImageUrls(data['previousArtImages'], urls);
    _collectImageUrls(profile['portfolioImages'], urls);
    _collectImageUrls(profile['previousArtImages'], urls);
    _collectImageUrls(artistPortfolio['items'], urls);
    _collectImageUrls(artistPortfolio['images'], urls);
    _collectImageUrls(artist['portfolioImages'], urls);
    _collectImageUrls(artist['portfolioItems'], urls);

    final uniqueUrls = _dedupeImageUrls(
      urls,
    ).where((url) => _isDisplayableImageUrl(url)).toList(growable: false);

    return ArtistProfile(
      id: _firstNonEmpty([data['id'], data['uid'], data['email']]),
      name: name,
      tierLabel: tierLabel,
      email: _firstNonEmpty([data['email'], profile['email'], artist['email']]),
      rating: _asDouble(stats['rating'] ?? data['rating']),
      city: _firstNonEmpty([
        address['city'],
        artistAddress['city'],
        profile['city'],
        data['panel_city'],
        data['city'],
      ]),
      state: _firstNonEmpty([
        address['state'],
        artistAddress['state'],
        profile['state'],
        data['panel_state'],
        data['state'],
      ]),
      budgetMin: _asInt(
        pricing['minPrice'] ??
            artistPricing['minPrice'] ??
            data['panel_minPrice'] ??
            artist['minPrice'],
        50,
      ),
      budgetMax: _asInt(
        pricing['maxPrice'] ??
            artistPricing['maxPrice'] ??
            data['panel_maxPrice'] ??
            artist['maxPrice'],
        200,
      ),
      credential:
          _firstNonEmpty([
                credentials['nailTechType'],
                artistCredentials['nailTechType'],
                data['panel_nailTechType'],
                profile['nailTechType'],
              ]).toLowerCase() ==
              'student'
          ? 'Student/Unlicensed'
          : 'Professional',
      avatarUrl: avatar,
      bio: bio,
      language: language,
      currency: currency,
      services: services,
      yearsExperience: yearsExperience,
      acceptsNfcRequests: _asBool(
        data['panel_nfcRequestEnabled'] ??
            availability['nfcRequestEnabled'] ??
            profile['nfcRequestEnabled'] ??
            artist['nfcRequestEnabled'] ??
            artistAvailability['nfcRequestEnabled'],
        fallback: false,
      ),
      acceptsDirectRequests: _asBool(
        data['panel_directRequestsEnabled'] ??
            data['panel_artist_directRequestsEnabled'] ??
            availability['directRequestsEnabled'] ??
            profile['directRequestsEnabled'] ??
            artist['directRequestsEnabled'] ??
            artistAvailability['directRequestsEnabled'],
        fallback: true,
      ),
      projects: uniqueUrls
          .map((url) => ArtistProject(imageUrl: url, title: 'Project'))
          .toList(growable: false),
    );
  }

  void _collectImageUrls(Object? raw, List<String> out) {
    if (raw == null) return;

    if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) out.add(value);
      return;
    }

    if (raw is List) {
      for (final item in raw) {
        _collectImageUrls(item, out);
      }
      return;
    }

    if (raw is Map) {
      for (final key in const <String>[
        'imageUrl',
        'imageURL',
        'url',
        'downloadUrl',
        'downloadURL',
        'photoUrl',
        'photoURL',
        'image',
        'src',
        'path',
        'storagePath',
        'fullPath',
        'filePath',
      ]) {
        _collectImageUrls(raw[key], out);
      }
    }
  }

  List<String> _dedupeImageUrls(List<String> urls) {
    final seen = <String>{};
    final output = <String>[];

    for (final raw in urls) {
      final value = _toDisplayableImageUrl(raw);
      if (value.isEmpty) continue;

      final key = value.split('?').first;
      if (seen.add(key)) output.add(value);
    }

    return output;
  }

  String _toDisplayableImageUrl(String raw) {
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
    final lower = raw.trim().toLowerCase();
    return lower.startsWith('data:image/') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://');
  }

  List<ArtistProfile> get _filtered {
    if (_selectedArtistId == null) return _artists;
    return _artists.where((a) => a.id == _selectedArtistId).toList();
  }

  bool _isAccessibilityNavigationEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
  }

  String _selectedArtistName() {
    final selectedId = _selectedArtistId;
    if (selectedId == null) return '';
    for (final artist in _artists) {
      if (artist.id == selectedId) return artist.name.trim();
    }
    return '';
  }

  void _selectArtistByName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      setState(() => _selectedArtistId = null);
      return;
    }
    for (final artist in _artists) {
      if (artist.name.trim().toLowerCase() == normalized) {
        setState(() => _selectedArtistId = artist.id);
        return;
      }
    }
  }

  Future<void> _openAccessibleArtistPicker() async {
    final selectedId = _selectedArtistId;
    final options = _artists
        .where((artist) => artist.name.trim().isNotEmpty)
        .toList(growable: false);

    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.snow,
      builder: (sheetContext) {
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Select artist',
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: ExcludeSemantics(
                            child: Text(
                              'Select Artist',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat,
                                fontFamily: 'ArialBold',
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close artist selection',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(
                            child: Text('No registered artists found.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.blackCatBorderLight,
                            ),
                            itemBuilder: (context, index) {
                              final artist = options[index];
                              final selected = artist.id == selectedId;
                              final rating = artist.rating <= 0
                                  ? 'rating not available'
                                  : '${artist.rating.toStringAsFixed(1)} rating';
                              final location = [
                                artist.city,
                                artist.state,
                              ].where((v) => v.trim().isNotEmpty).join(', ');
                              final labelParts = <String>[
                                artist.name,
                                '${index + 1} of ${options.length}',
                                if (selected) 'selected',
                                rating,
                                if (location.isNotEmpty) location,
                              ];

                              return Semantics(
                                button: true,
                                selected: selected,
                                label: labelParts.join(', '),
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(artist.id),
                                child: ExcludeSemantics(
                                  child: ListTile(
                                    title: Text(
                                      artist.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.blackCat,
                                      ),
                                    ),
                                    subtitle: Text(
                                      location.isEmpty
                                          ? rating
                                          : '$location • $rating',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.blackCat.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                    trailing: selected
                                        ? const Icon(
                                            Icons.check,
                                            color: AppColors.blackCat,
                                          )
                                        : null,
                                    onTap: () => Navigator.of(
                                      sheetContext,
                                    ).pop(artist.id),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (selectedId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.blackCat,
                            side: const BorderSide(
                              color: AppColors.blackCatBorderLight,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(''),
                          child: const Text('Clear artist selection'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (picked == null) return;
    if (picked.trim().isEmpty) {
      setState(() => _selectedArtistId = null);
      return;
    }
    setState(() => _selectedArtistId = picked);
  }

  Widget _buildAccessibleArtistPickerField() {
    final selectedName = _selectedArtistName();
    final valueText = selectedName.isEmpty
        ? 'No artist selected'
        : selectedName;

    return Semantics(
      button: true,
      label: 'Search for Artist, $valueText',
      onTap: _openAccessibleArtistPicker,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _openAccessibleArtistPicker,
          borderRadius: BorderRadius.zero,
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Select Artist',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: AppColors.blackCat.withValues(alpha: 0.35),
                fontFamily: 'Arial',
                fontWeight: FontWeight.w400,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.snow,
              constraints: const BoxConstraints(minHeight: 46),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: const Icon(
                Icons.arrow_drop_down_rounded,
                size: 24,
                color: AppColors.blackCat,
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
                borderSide: BorderSide(color: AppColors.blackCat, width: 1.4),
              ),
            ),
            child: Text(
              selectedName.isEmpty ? 'Select Artist' : selectedName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                fontFamily: 'Arial',
                color: selectedName.isEmpty
                    ? AppColors.blackCat.withValues(alpha: 0.35)
                    : AppColors.blackCat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onAvatarMenuSelected(String value) {
    if (value == 'profile') {
      widget.onOpenProfile?.call();
      return;
    }
    if (value == 'history') {
      widget.onOpenHistory?.call();
      return;
    }
    if (value == 'calendar') {
      widget.onOpenCalendar?.call();
      return;
    }
    if (value == 'artist') {
      widget.onOpenArtist?.call();
      return;
    }
    if (value == 'logout') {
      _logout();
    }
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      await widget.onLogout!.call();
      return;
    }
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Artists',
      child: Scaffold(
        backgroundColor: AppColors.snow,

        // ✅ Header: Logo + Center Title + Notification + Avatar dropdown
        appBar: widget.showCompanyChrome && widget.companyName != null
            ? CompanyHeader(
                companyName: widget.companyName!,
                onOpenProfile: widget.onOpenProfile,
                onLogout: widget.onLogout,
              )
            : AppBar(
                backgroundColor: AppColors.alabaster,
                surfaceTintColor: AppColors.alabaster,
                elevation: 0,
                toolbarHeight: 64,
                automaticallyImplyLeading: false,
                centerTitle: true,
                titleSpacing: 0,
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: NotificationBellButton(
                    onTap: () {
                      NotificationsPage.showAsModal(context);
                    },
                    focusNode: _notificationsFocusNode,
                    iconSize: 22,
                  ),
                ),
                title: Image.asset(
                  'assets/images/jnt_logo_black.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),

                // Right side: avatar menu only.
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _AvatarMenu(
                      onSelected: _onAvatarMenuSelected,
                      avatarUrl: widget.profile.basic.profileImageUrl,
                      displayName: widget.profile.basic.name,
                      showProfile: widget.showProfileMenu,
                      showHistory: widget.showHistoryMenu,
                      showCalendar: widget.showCalendarMenu,
                      showArtist: widget.showArtistMenu,
                    ),
                  ),
                ],
              ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            Center(
              child: Text(
                'Browse artists, view their past work, and start a custom request.',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  fontFamily: 'ArialBold',
                ),
              ),
            ),
            const SizedBox(height: 14),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Text(
                    'Search for Artist',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'ArialBold',
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Builder(
                  builder: (context) {
                    if (_isAccessibilityNavigationEnabled(context)) {
                      return _buildAccessibleArtistPickerField();
                    }

                    String? selectedName;
                    for (final artist in _artists) {
                      if (artist.id == _selectedArtistId &&
                          artist.name.trim().isNotEmpty) {
                        selectedName = artist.name.trim();
                        break;
                      }
                    }
                    final options = _artists
                        .map((a) => a.name.trim())
                        .where((n) => n.isNotEmpty)
                        .toSet()
                        .toList(growable: false);
                    return Autocomplete<String>(
                      initialValue: TextEditingValue(text: selectedName ?? ''),
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text
                            .trim()
                            .toLowerCase();
                        if (query.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return options.where(
                          (item) => item.toLowerCase().contains(query),
                        );
                      },
                      onSelected: _selectArtistByName,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (value) {
                                if (value.trim().isEmpty &&
                                    _selectedArtistId != null) {
                                  setState(() => _selectedArtistId = null);
                                }
                              },
                              onSubmitted: (_) => onSubmitted(),
                              onTapOutside: (_) => focusNode.unfocus(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackCat,
                                fontFamily: 'Arial',
                              ),
                              decoration: InputDecoration(
                                hintText: 'Select Artist',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.35,
                                  ),
                                  fontFamily: 'Arial',
                                  fontWeight: FontWeight.w400,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.snow,
                                constraints: const BoxConstraints(
                                  minHeight: 46,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                suffixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 22,
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.55,
                                  ),
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
                                  borderSide: BorderSide(
                                    color: AppColors.blackCat,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, optionsList) {
                        final list = optionsList.toList(growable: false);
                        final menuHeight =
                            AutocompleteDropdownSizing.menuHeight(
                              itemCount: list.length,
                              itemExtent: 40,
                            );
                        return TextFieldTapRegion(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 6,
                              color: AppColors.snow,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                                side: BorderSide(
                                  color: AppColors.blackCatBorderLight,
                                ),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: menuHeight,
                                  minWidth: 220,
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shrinkWrap:
                                      AutocompleteDropdownSizing.shrinkWrap(
                                        list.length,
                                      ),
                                  physics:
                                      AutocompleteDropdownSizing.scrollPhysics(
                                        list.length,
                                      ),
                                  itemCount: list.length,
                                  itemBuilder: (context, index) {
                                    final item = list[index];
                                    return InkWell(
                                      onTap: () => onSelected(item),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Text(
                                          item,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: 'Arial',
                                            color: AppColors.blackCat,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            if (_loadingArtists)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              _Card(
                child: Text(
                  'No registered artists found.',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ..._filtered.map((artist) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArtistCard(
                    artist: artist,
                    canRequest: artist.acceptsDirectRequests,
                    onTap: () {
                      unawaited(_openArtistDetails(artist));
                    },
                    onOpenProjectImage: (imageUrl) {
                      _openImagePreview(imageUrl);
                    },
                    onDesign: () async {
                      if (!artist.acceptsDirectRequests) return;
                      if (widget.onRequestArtist != null) {
                        widget.onRequestArtist!.call(artist.name);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientCustomRequestWithArtistPage(
                            profile: widget.profile,
                            artistName: artist.name,
                            artistNames: _artists.map((a) => a.name).toList(),
                            showClientBottomNav: !widget.showCompanyChrome,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
        bottomNavigationBar: widget.showCompanyChrome
            ? CompanyBottomNav(
                currentIndex: widget.bottomNavIndex,
                onTap: (i) => widget.onNavTap?.call(i),
              )
            : null,
      ),
    );
  }

  Future<void> _openArtistDetails(ArtistProfile artist) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCat,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _SupabaseArtistDetailsSheet(
          artist: artist,
          onProjectTap: (imageUrl) => _openImagePreview(imageUrl),
        ),
      ),
    );
  }

  Future<void> _openImagePreview(String imageUrl) async {
    final src = imageUrl.trim();
    if (src.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Image preview',
        child: Dialog(
          backgroundColor: AppColors.blackCat,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Semantics(
                  image: true,
                  label: 'Previous art image preview. Pinch to zoom.',
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: _buildAnyImage(
                          src,
                          fit: BoxFit.contain,
                          fallback: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.snow,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Semantics(
                  button: true,
                  label: 'Close image preview',
                  child: IconButton(
                    tooltip: 'Close image preview',
                    autofocus: MediaQuery.of(
                      dialogContext,
                    ).accessibleNavigation,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.snow,
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
}

/// ✅ Avatar menu popup (Logout)
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
    this.showProfile = true,
    this.showHistory = true,
    this.showCalendar = true,
    this.showArtist = true,
  });
  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;
  final bool showProfile;
  final bool showHistory;
  final bool showCalendar;
  final bool showArtist;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (showProfile)
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: const [
                Icon(Icons.person_outline, size: 22),
                SizedBox(width: 14),
                Text(
                  'Profile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showHistory)
          PopupMenuItem<String>(
            value: 'history',
            child: Row(
              children: const [
                Icon(Icons.history, size: 22),
                SizedBox(width: 14),
                Text(
                  'History',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showCalendar)
          PopupMenuItem<String>(
            value: 'calendar',
            child: Row(
              children: const [
                Icon(Icons.calendar_month_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Calendar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showArtist)
          PopupMenuItem<String>(
            value: 'artist',
            child: Row(
              children: const [
                Icon(Icons.brush_outlined, size: 22),
                SizedBox(width: 14),
                Text(
                  'Artist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showProfile || showHistory || showCalendar || showArtist)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 22, color: AppColors.blackCat),
              SizedBox(width: 14),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox(
        height: 36,
        width: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Artist card
/// ---------------------------
class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.canRequest,
    required this.onTap,
    required this.onDesign,
    required this.onOpenProjectImage,
  });

  final ArtistProfile artist;
  final bool canRequest;
  final VoidCallback onTap;
  final VoidCallback onDesign;
  final ValueChanged<String> onOpenProjectImage;

  String _shortCredential(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.contains('student') || text.contains('unlicensed')) {
      return 'Student/Unlicensed';
    }
    return 'Professional';
  }

  Color _ratingStarColor(double rating) {
    final clamped = rating.clamp(1.0, 5.0);
    final t = ((clamped - 1.0) / 4.0).clamp(0.0, 1.0);
    final opacity = 0.35 + (0.65 * t);
    return AppColors.balletSlippers.withValues(alpha: opacity);
  }

  String _artistSummaryLabel() {
    final ratingLabel = artist.rating <= 0
        ? 'rating not available'
        : '${artist.rating.toStringAsFixed(1)} star rating';
    final location = [
      artist.city.trim(),
      artist.state.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    final locationLabel = location.isEmpty
        ? 'location not available'
        : location;
    final directRequestLabel = canRequest
        ? 'accepts direct requests'
        : 'does not accept direct requests';
    final nfcLabel = artist.acceptsNfcRequests ? ', accepts NFC requests' : '';

    return 'Artist ${artist.name}, $ratingLabel, $locationLabel, '
        'budget ${artist.budgetMin} to ${artist.budgetMax} dollars, '
        '${_shortCredential(artist.credential)}, $directRequestLabel$nfcLabel. '
        'Double tap for artist details';
  }

  Widget _artistSummary(BuildContext context) {
    return Semantics(
      button: true,
      label: _artistSummaryLabel(),
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _ArtistAvatar(artist: artist),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'ArialBold',
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: _ratingStarColor(
                            artist.rating <= 0 ? 1.0 : artist.rating,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          artist.rating <= 0
                              ? 'N/A'
                              : artist.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${artist.city}, ${artist.state}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Budget: \$${artist.budgetMin} - \$${artist.budgetMax}',
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: AppColors.blackCat,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _shortCredential(artist.credential),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.blackCat,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (artist.acceptsNfcRequests) ...[
                      const SizedBox(height: 6),
                      const _NfcTag(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestButton() {
    final label = canRequest
        ? 'Request ${artist.name}'
        : 'Request ${artist.name}, unavailable';

    return Semantics(
      button: true,
      enabled: canRequest,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canRequest
                  ? AppColors.blackCat
                  : AppColors.blackCat.withValues(alpha: 0.28),
              foregroundColor: AppColors.snow,
              disabledBackgroundColor: AppColors.blackCat.withValues(
                alpha: 0.28,
              ),
              disabledForegroundColor: AppColors.snow.withValues(alpha: 0.78),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: canRequest ? onDesign : null,
            child: const Text(
              'Request',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                fontFamily: 'Arial',
                color: AppColors.snow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _artistSummary(context)),
              const SizedBox(width: 10),
              _requestButton(),
            ],
          ),
          const SizedBox(height: 14),
          const ExcludeSemantics(
            child: Text(
              'Previous Art',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: 'ArialBold',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (artist.projects.isEmpty)
            Semantics(
              label: 'No previous art uploaded for ${artist.name}',
              child: ExcludeSemantics(
                child: Text(
                  'No projects uploaded yet.',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final tileWidth = (constraints.maxWidth - (spacing * 2)) / 3;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: artist.projects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: spacing),
                    itemBuilder: (context, i) => _ProjectTile(
                      project: artist.projects[i],
                      width: tileWidth > 90 ? tileWidth : 90,
                      semanticLabel:
                          'Previous art image ${i + 1} of ${artist.projects.length} for ${artist.name}',
                      onTap: () =>
                          onOpenProjectImage(artist.projects[i].imageUrl),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.artist});
  final ArtistProfile artist;

  bool _isValidAvatar(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('assets/')) return false;
    if (v.contains('profile_placeholder')) return false;
    if (v.contains('avatar_placeholder')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final url = artist.avatarUrl.trim();
    if (_isValidAvatar(url)) {
      return _buildAnyImage(
        url,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        fallback: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final letter = artist.name.trim().isEmpty
        ? 'A'
        : artist.name.trim()[0].toUpperCase();
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.width,
    required this.semanticLabel,
    required this.onTap,
  });

  final ArtistProject project;
  final double width;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = project.imageUrl.trim().isNotEmpty;

    return Semantics(
      button: hasImage,
      image: true,
      enabled: hasImage,
      label: hasImage ? semanticLabel : '$semanticLabel, unavailable',
      onTap: hasImage ? onTap : null,
      child: ExcludeSemantics(
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatBorderLight),
            color: AppColors.snow,
          ),
          child: InkWell(
            onTap: hasImage ? onTap : null,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: hasImage
                  ? _buildAnyImage(
                      project.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: AppColors.blackCat.withValues(alpha: 0.05),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 18,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.blackCat.withValues(alpha: 0.05),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 18,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Shared card style
/// ---------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  final Color backgroundColor = AppColors.snow;
  final Color? borderColor = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: borderColor ?? AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ---------------------------
/// Models
/// ---------------------------
class ArtistProfile {
  final String id;
  final String name;
  final String tierLabel;
  final String email;
  final double rating;
  final String city;
  final String state;
  final int budgetMin;
  final int budgetMax;
  final String credential;
  final String avatarUrl;
  final String bio;
  final String language;
  final String currency;
  final List<String> services;
  final String? yearsExperience;
  final bool acceptsNfcRequests;
  final bool acceptsDirectRequests;
  final List<ArtistProject> projects;

  const ArtistProfile({
    required this.id,
    required this.name,
    required this.tierLabel,
    required this.email,
    required this.rating,
    required this.city,
    required this.state,
    required this.budgetMin,
    required this.budgetMax,
    required this.credential,
    required this.avatarUrl,
    required this.bio,
    required this.language,
    required this.currency,
    required this.services,
    this.yearsExperience,
    required this.acceptsNfcRequests,
    required this.acceptsDirectRequests,
    required this.projects,
  });
}

class ArtistProject {
  final String imageUrl;
  final String title;

  const ArtistProject({required this.imageUrl, required this.title});
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

Widget _buildAnyImage(
  String src, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  final value = _normalizeImageRef(src);
  if (value.isEmpty) return fallback;

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
      errorBuilder: (_, _, _) => fallback,
    );
  }

  return fallback;
}

String _normalizeImageRef(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  if (value.startsWith('assets/')) return '';

  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeFull(value);
      if (decoded == value) break;
      value = decoded;
    } catch (_) {
      break;
    }
  }

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

class _SupabaseArtistDetailsSheet extends StatelessWidget {
  const _SupabaseArtistDetailsSheet({
    required this.artist,
    required this.onProjectTap,
  });

  final ArtistProfile artist;
  final ValueChanged<String> onProjectTap;

  String _safeText(Object? raw, {String fallback = ''}) {
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  bool _isValidAvatar(Object? raw) {
    final value = _safeText(raw).toLowerCase();
    if (value.isEmpty) return false;
    if (value.startsWith('assets/')) return false;
    if (value.contains('profile_placeholder')) return false;
    if (value.contains('avatar_placeholder')) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:image/');
  }

  String _initialLetter(Object? raw) {
    final value = _safeText(raw);
    if (value.isEmpty) return 'A';
    return value.substring(0, 1).toUpperCase();
  }

  IconData _specializationIcon(Object? label) {
    final value = _safeText(label).toLowerCase();
    if (value.contains('3d')) return Icons.interests_outlined;
    if (value.contains('airbrush')) return Icons.blur_on_outlined;
    if (value.contains('stamping')) return Icons.blur_on_outlined;
    if (value.contains('french')) return Icons.auto_fix_high_outlined;
    if (value.contains('chrome')) return Icons.brush_outlined;
    if (value.contains('sculpt')) return Icons.brush_outlined;
    if (value.contains('encapsulation')) return Icons.brush_outlined;
    if (value.contains('gel') || value.contains('acrylic')) {
      return Icons.brush_outlined;
    }
    if (value.contains('intricate')) return Icons.brush_outlined;
    if (value.contains('minimal')) return Icons.hexagon_outlined;
    if (value.contains('abstract')) return Icons.gesture_outlined;
    return Icons.brush_outlined;
  }

  String _yearsExperienceSemantic(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*[â€“-]\s*'), ' to ')
        .replaceAll(RegExp(r'\byr\b', caseSensitive: false), 'year')
        .replaceAll(RegExp(r'\byrs\b', caseSensitive: false), 'years');
  }

  Widget _avatarFallback(String name) {
    return Container(
      width: 92,
      height: 92,
      color: AppColors.balletSlippers,
      alignment: Alignment.center,
      child: Text(
        _initialLetter(name),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 30,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  void _openPhotoPreview(BuildContext context, String imageSrc) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: AppColors.blackCat,
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
                        color: AppColors.snow,
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
                  icon: const Icon(Icons.close_rounded, color: AppColors.snow),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final artistName = _safeText(artist.name, fallback: 'Artist');
    final avatarUrl = _safeText(artist.avatarUrl);
    final location = [
      _safeText(artist.city),
      _safeText(artist.state),
    ].where((value) => value.isNotEmpty).join(', ');
    final tier = _safeText(
      artist.credential,
      fallback: 'Professional Nail Technician',
    );
    final language = _safeText(artist.language, fallback: 'English');
    final currency = _safeText(artist.currency, fallback: 'US Dollar (USD)');
    final directRequestLabel = artist.acceptsDirectRequests
        ? 'Direct Request'
        : 'Standard Request';
    final bio = _safeText(artist.bio);
    final specializations = artist.services.isNotEmpty
        ? artist.services
              .where((item) => _safeText(item).isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final yearsExperience = _safeText(artist.yearsExperience);
    final projects = artist.projects
        .where((project) => _safeText(project.imageUrl).isNotEmpty)
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.snow,
        child: Column(
          children: [
            Container(
              color: AppColors.alabaster,
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: ExcludeSemantics(
                        child: Image(
                          image: AssetImage('assets/images/jnt_logo_black.png'),
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                children: [
                  const SizedBox(height: 2),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: _isValidAvatar(avatarUrl)
                          ? _buildAnyImage(
                              avatarUrl,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              fallback: _avatarFallback(artistName),
                            )
                          : _avatarFallback(artistName),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          artistName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blackCat,
                            fontFamily: 'ArialBold',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: AppColors.balletSlippers,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          artist.rating > 0
                              ? artist.rating.toStringAsFixed(1)
                              : 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        if (tier.isNotEmpty)
                          Text(
                            tier,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.blackCat,
                              fontFamily: 'Arial',
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (yearsExperience.isNotEmpty)
                          Semantics(
                            container: true,
                            label:
                                'Experience, ${_yearsExperienceSemantic(yearsExperience)}',
                            child: ExcludeSemantics(
                              child: Text(
                                yearsExperience,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.blackCat,
                                  fontFamily: 'Arial',
                                ),
                              ),
                            ),
                          ),
                        Text(
                          'Budget: \$${artist.budgetMin} - \$${artist.budgetMax}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            location,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.blackCat,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MetaBand(
                    language: language,
                    currency: currency,
                    requestType: directRequestLabel,
                  ),
                  const SizedBox(height: 8),
                  _SectionHeading(title: 'Artist Bio'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      bio.isNotEmpty ? bio : 'No artist bio added yet.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.blackCat,
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionDivider(),
                  _SectionHeading(title: 'Specialization'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: specializations.isEmpty
                        ? Text(
                            'No specialization selected yet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.blackCat.withValues(alpha: 0.75),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const spacing = 12.0;
                              final tileWidth =
                                  (constraints.maxWidth - spacing) / 2;
                              return Wrap(
                                spacing: spacing,
                                runSpacing: 8,
                                children: List.generate(
                                  specializations.length,
                                  (index) {
                                    final item = specializations[index];
                                    return SizedBox(
                                      width: tileWidth,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            _specializationIcon(item),
                                            size: 22,
                                            color: AppColors.blackCat,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.blackCat,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionDivider(),
                  _SectionHeading(title: 'Previous Art'),
                  const SizedBox(height: 10),
                  _PreviousArtStrip(
                    images: projects.map((p) => p.imageUrl).toList(),
                    onImageTap: (imageUrl) =>
                        _openPhotoPreview(context, imageUrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBand extends StatelessWidget {
  const _MetaBand({
    required this.language,
    required this.currency,
    required this.requestType,
  });

  final String language;
  final String currency;
  final String requestType;

  @override
  Widget build(BuildContext context) {
    final languageText = language.trim().isEmpty ? 'N/A' : language.trim();
    final currencyText = currency.trim().isEmpty ? 'N/A' : currency.trim();
    final requestText = requestType.trim().isEmpty
        ? 'Standard Request'
        : requestType.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _MetaItem(
                  icon: Icons.language_rounded,
                  text: languageText,
                ),
              ),
              _MetaDivider(),
              Expanded(
                child: _MetaItem(
                  icon: Icons.currency_exchange_rounded,
                  text: currencyText,
                ),
              ),
              _MetaDivider(),
              Expanded(
                child: _MetaItem(
                  icon: requestText == 'Direct Request'
                      ? Icons.arrow_outward_rounded
                      : Icons.arrow_forward_rounded,
                  text: requestText,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.blackCatBorderLight,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.blackCat),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.blackCatBorderLight);
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class _PreviousArtStrip extends StatelessWidget {
  const _PreviousArtStrip({required this.images, required this.onImageTap});

  final List<String> images;
  final ValueChanged<String> onImageTap;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No previous art uploaded yet.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.blackCat.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    final visible = images.take(3).toList(growable: false);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final tileSize = (constraints.maxWidth - (spacing * 2)) / 3;
            return Row(
              children: List.generate(3, (index) {
                final src = index < visible.length ? visible[index] : '';
                return Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : spacing),
                  child: SizedBox(
                    width: tileSize,
                    height: tileSize,
                    child: src.isEmpty
                        ? const SizedBox.shrink()
                        : InkWell(
                            onTap: () => onImageTap(src),
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: _buildAnyImage(
                                src,
                                width: tileSize,
                                height: tileSize,
                                fit: BoxFit.cover,
                                fallback: Container(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.05,
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
                );
              }),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length > 3 ? 4 : 3,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: index == 0
                      ? AppColors.blackCat.withValues(alpha: 0.32)
                      : AppColors.blackCat.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
