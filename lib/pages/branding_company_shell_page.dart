import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_profile_models.dart';
import '../services/artist_directory_service.dart';
import '../widgets/company_shell_chrome.dart';
import 'branding_company_home_page.dart';
import 'client_artists_page.dart';
import 'brand_order_page_v2.dart';
import 'company_custom_request_page.dart';
import 'company_custom_request_with_artist_page.dart';
import 'company_profile_page.dart';
import 'edit_company_business_info_popup.dart';
import 'notifications_page.dart';

class BrandingCompanyShellPage extends StatefulWidget {
  const BrandingCompanyShellPage({
    super.key,
    this.companyDisplayName = 'Brand',
    this.initialIndex = 0,
    this.profile,
    this.initialBusinessInfo,
    this.initialBillingInfo,
    this.initialAddressesInfo,
  });

  final String companyDisplayName;
  final int initialIndex;
  final ClientProfileDraft? profile;
  final CompanyBusinessInfoDraft? initialBusinessInfo;
  final CompanyBillingDraft? initialBillingInfo;
  final CompanyAddressesDraft? initialAddressesInfo;

  @override
  State<BrandingCompanyShellPage> createState() =>
      _BrandingCompanyShellPageState();
}

class _BrandingCompanyShellPageState extends State<BrandingCompanyShellPage> {
  late int _index;
  bool _loadingEnrolledArtists = true;
  List<CompanyTrendingArtist> _enrolledArtists =
      const <CompanyTrendingArtist>[];
  String _loadedUid = '';
  Future<Map<String, dynamic>>? _companyFuture;
  Future<List<Map<String, dynamic>>>? _requestsFuture;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadEnrolledArtists();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadEnrolledArtists() async {
    try {
      final entries = await ArtistDirectoryService.fetchHomeArtistsRandomized(
        limit: 12,
        hydrateMediaFallbacks: true,
      );
      if (!mounted) return;
      final mapped = entries
          .map(
            (e) => CompanyTrendingArtist(
              name: e.name.trim().contains('@') ? '' : e.name.trim(),
              tierLabel: e.tierLabel.trim().isEmpty ? 'Maker' : e.tierLabel.trim(),
              imageUrl: e.portfolioImages.isNotEmpty
                  ? e.portfolioImages.first.trim()
                  : '',
              avatarUrl: e.avatarUrl.trim(),
              acceptsDirectRequests: e.acceptsDirectRequests,
              rating: e.rating,
              city: e.city.trim(),
              state: e.state.trim(),
              budgetMin: e.budgetMin,
              budgetMax: e.budgetMax,
              credential: e.credential.trim(),
              bio: e.bio.trim(),
              projectNotes: e.projectNotes.trim(),
              previousProjects: _dedupeUrls(e.portfolioImages),
            ),
          )
          .where((e) => e.name.isNotEmpty)
          .toList(growable: false);
      setState(() {
        _enrolledArtists = mapped;
        _loadingEnrolledArtists = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enrolledArtists = const <CompanyTrendingArtist>[];
        _loadingEnrolledArtists = false;
      });
    }
  }

  List<String> _dedupeUrls(List<String> urls) {
    final seen = <String>{};
    final out = <String>[];

    for (final raw in urls) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = value.split('?').first;
      if (seen.add(key)) out.add(value);
    }

    return out;
  }

  Future<void> _logoutToHomePage() async {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openDesign({
    required ClientProfileDraft profile,
    required String companyName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyCustomRequestPage(
          profile: profile,
          onBackHome: () => Navigator.pop(context),
          companyName: companyName,
          onOpenProfile: () => _onNavTap(4),
          onLogout: _logoutToHomePage,
          showBottomNav: true,
          bottomNavIndex: 1,
          onNavTap: (i) async {
            if (i == 1) return;
            Navigator.pop(context);
            await _onNavTap(i, profile: profile, companyName: companyName);
          },
        ),
      ),
    );
  }

  Future<void> _openArtists({
    required ClientProfileDraft profile,
    required String companyName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientArtistsPage(
          profile: profile,
          showCompanyChrome: true,
          companyName: companyName,
          onOpenProfile: () => _onNavTap(4),
          onLogout: _logoutToHomePage,
          onRequestArtist: (artistName) {
            _openCustomRequestWithArtist(
              profile: profile,
              companyName: companyName,
              artistName: artistName,
            );
          },
          bottomNavIndex: 2,
          onNavTap: (i) async {
            if (i == 2) return;
            Navigator.pop(context);
            await _onNavTap(i, profile: profile, companyName: companyName);
          },
        ),
      ),
    );
  }

  Future<void> _openOrders({
    required ClientProfileDraft profile,
    required String companyName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrandOrderPageV2(
          profile: profile,
          companyName: companyName,
          onOpenProfile: () => _onNavTap(4),
          onLogout: _logoutToHomePage,
          bottomNavIndex: 3,
          onNavTap: (i) async {
            if (i == 3) return;
            Navigator.pop(context);
            await _onNavTap(i, profile: profile, companyName: companyName);
          },
        ),
      ),
    );
  }

  Future<void> _openCustomRequestWithArtist({
    required ClientProfileDraft profile,
    required String companyName,
    required String artistName,
  }) async {
    final artistNames = _enrolledArtists
        .map((a) => a.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyCustomRequestWithArtistPage(
          profile: profile,
          companyName: companyName,
          onBackHome: () => Navigator.pop(context),
          onOpenProfile: () => _onNavTap(4),
          onLogout: _logoutToHomePage,
          showBottomNav: true,
          bottomNavIndex: 1,
          onNavTap: (i) async {
            if (i == 1) return;
            Navigator.pop(context);
            await _onNavTap(i, profile: profile, companyName: companyName);
          },
          artistName: artistName,
          artistNames: artistNames,
        ),
      ),
    );
  }

  Future<void> _onNavTap(
    int i, {
    ClientProfileDraft? profile,
    String? companyName,
  }) async {
    final navProfile = profile ?? widget.profile ?? ClientProfileDraft.mock();
    final navCompanyName = companyName ?? widget.companyDisplayName;
    if (i == 1) {
      await _openDesign(profile: navProfile, companyName: navCompanyName);
      return;
    }
    if (i == 2) {
      await _openArtists(profile: navProfile, companyName: navCompanyName);
      return;
    }
    if (i == 3) {
      await _openOrders(profile: navProfile, companyName: navCompanyName);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();

    if (uid.isEmpty) {
      return _buildShell(
        data: _CompanyUiData.fallback(widget.companyDisplayName),
        requests: const <Map<String, dynamic>>[],
      );
    }

    if (_loadedUid != uid || _companyFuture == null) {
      _loadedUid = uid;
      _companyFuture = _loadCompanyDataFromSupabase(uid);
      _requestsFuture = null;
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _companyFuture,
      builder: (context, companySnap) {
        final data = _CompanyUiData.fromFirestore(
          uid: uid,
          data: companySnap.data,
          fallbackCompanyName: widget.companyDisplayName,
          fallbackBusiness: widget.initialBusinessInfo,
          fallbackBilling: widget.initialBillingInfo,
          fallbackAddresses: widget.initialAddressesInfo,
        );

        _requestsFuture ??= _loadCompanyRequestsFromSupabase(data);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _requestsFuture,
          builder: (context, requestsSnap) {
            final requests =
                requestsSnap.data ?? const <Map<String, dynamic>>[];
            return _buildShell(data: data, requests: requests);
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadCompanyDataFromSupabase(String uid) async {
    try {
      final rows = await Supabase.instance.client
          .from('company')
          .select()
          .eq('id', uid)
          .limit(1);

      if (rows.isNotEmpty) {
        final data = Map<String, dynamic>.from(rows.first as Map);
        debugPrint('COMPANY SHELL SUPABASE DATA = $data');
        return data;
      }
    } catch (e) {
      debugPrint('COMPANY SHELL SUPABASE LOAD FAILED: $e');
    }

    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _loadCompanyRequestsFromSupabase(
    _CompanyUiData data,
  ) async {
    final companyUid = data.uid.trim();
    final companyEmail = data.email.trim().toLowerCase();
    final companyName = data.companyName.trim().toLowerCase();

    if (companyUid.isEmpty && companyEmail.isEmpty && companyName.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final rows = await Supabase.instance.client
          .from('client_custom_requests')
          .select()
          .order('updated_at', ascending: false);

      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(_flattenCompanyRequestRow)
          .where(_isCompanyRequestRow)
          .where((row) => _matchesCompanyRequest(row, data))
          .toList(growable: false);
    } catch (e) {
      debugPrint('COMPANY SHELL REQUEST LOAD FAILED: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  Widget _buildShell({
    required _CompanyUiData data,
    required List<Map<String, dynamic>> requests,
  }) {
    final statuses = requests
        .map((r) => (r['status'] ?? '').toString().trim().toLowerCase())
        .toList(growable: false);

    final inProgressCount = statuses
        .where(
          (s) =>
              s == 'pending' ||
              s == 'submitted' ||
              s == 'in_review' ||
              s == 'in review' ||
              s == 'inreview' ||
              s == 'accepted' ||
              s == 'completed' ||
              s == 'shipped',
        )
        .length;
    final deliveredCount = statuses.where((s) => s == 'delivered').length;
    final cancelledCount = statuses.where((s) => s == 'cancelled').length;

    final campaignCount = requests
        .map(
          (r) => _firstNonEmptyString(
            r['campaignName'],
            r['title'],
            r['requestTitle'],
          ),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;

    final trendingArtists = _enrolledArtists;

    final profileForDesign = widget.profile ?? data.asClientProfileDraft();

    final pages = <Widget>[
      BrandingCompanyHomePage(
        companyName: data.companyName,
        campaignCount: campaignCount,
        cancelledCount: cancelledCount,
        inProgressCount: inProgressCount,
        deliveredCount: deliveredCount,
        loadingTrendingLooks: _loadingEnrolledArtists,
        trendingArtists: trendingArtists,
        onLogout: _logoutToHomePage,
        onOpenProfile: () => _onNavTap(
          4,
          profile: profileForDesign,
          companyName: data.companyName,
        ),
        onRequestTrendingArtist: (artist) {
          _openCustomRequestWithArtist(
            profile: profileForDesign,
            companyName: data.companyName,
            artistName: artist.name,
          );
        },
      ),
      const SizedBox.shrink(),
      _ComingSoonPage(
        title: 'Company Requests',
        companyName: data.companyName,
        onOpenProfile: () => _onNavTap(
          4,
          profile: profileForDesign,
          companyName: data.companyName,
        ),
        onLogout: _logoutToHomePage,
      ),
      _ComingSoonPage(
        title: 'Company Calendar',
        companyName: data.companyName,
        onOpenProfile: () => _onNavTap(
          4,
          profile: profileForDesign,
          companyName: data.companyName,
        ),
        onLogout: _logoutToHomePage,
      ),
      CompanyProfilePage(
        companyName: data.companyName,
        contactName: data.contactName,
        email: data.email,
        locationText: data.locationText,
        profileImageUrl: data.avatarUrl,
        onLogout: _logoutToHomePage,
        onClose: () => _onNavTap(
          0,
          profile: profileForDesign,
          companyName: data.companyName,
        ),
        initialBusinessInfo: data.businessInfo,
        initialBillingInfo: data.billingInfo,
        initialAddressesInfo: data.addressesInfo,
        onOpenNewDesignRequest: () => _onNavTap(
          1,
          profile: profileForDesign,
          companyName: data.companyName,
        ),
        onOpenNotifications: () {
          NotificationsPage.showAsModal(context);
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: _index,
        onTap: (i) {
          _onNavTap(
            i,
            profile: profileForDesign,
            companyName: data.companyName,
          );
        },
      ),
    );
  }

  bool _matchesCompanyRequest(
    Map<String, dynamic> request,
    _CompanyUiData data,
  ) {
    final requestUid = _firstNonEmptyString(
      request['companyUid'],
      request['requesterUid'],
      request['createdByUid'],
      request['uid'],
    );
    if (requestUid.isNotEmpty && requestUid == data.uid) return true;

    final requestEmail = _firstNonEmptyString(
      request['companyEmail'],
      request['clientEmail'],
      request['requesterEmail'],
      request['email'],
    ).toLowerCase();
    if (requestEmail.isNotEmpty &&
        data.email.isNotEmpty &&
        requestEmail == data.email.toLowerCase()) {
      return true;
    }

    final requestName = _firstNonEmptyString(
      request['companyName'],
      request['brandName'],
      request['clientName'],
      request['requesterName'],
    ).toLowerCase();
    if (requestName.isNotEmpty &&
        data.companyName.isNotEmpty &&
        requestName == data.companyName.toLowerCase()) {
      return true;
    }

    return false;
  }

  bool _isCompanyRequestRow(Map<String, dynamic> request) {
    final sourceCollection = _firstNonEmptyString(
      request['sourceCollection'],
      request['source_collection'],
    ).trim();
    if (sourceCollection == 'Company_Custom_Requests') return true;
    if (sourceCollection.isNotEmpty &&
        sourceCollection != 'Company_Custom_Requests') {
      return false;
    }

    final requestType = _firstNonEmptyString(
      request['requestType'],
      request['request_type'],
    ).trim().toLowerCase();
    if (requestType.isEmpty) return true;

    return <String>{
      'companycustomrequest',
      'company_custom_request',
      'brandcustomrequest',
      'brandrequest',
      'direct',
      'direct to client',
      'direct to artist',
      'standard',
      'customrequest',
    }.contains(requestType);
  }

  Map<String, dynamic> _flattenCompanyRequestRow(Map<String, dynamic> row) {
    final out = <String, dynamic>{...row};

    void mergeMap(String key) {
      final value = row[key];
      if (value is! Map) return;
      final map = value.map((k, v) => MapEntry(k.toString(), v));
      for (final entry in map.entries) {
        out.putIfAbsent(entry.key, () => entry.value);
      }
    }

    mergeMap('summary');
    mergeMap('details');
    mergeMap('requestDetails');
    mergeMap('request_details');
    mergeMap('order');
    mergeMap('groupOrder');
    return out;
  }

  String _firstNonEmptyString(Object? a, [Object? b, Object? c, Object? d]) {
    for (final candidate in <Object?>[a, b, c, d]) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class _CompanyUiData {
  const _CompanyUiData({
    required this.uid,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.locationText,
    required this.avatarUrl,
    required this.businessInfo,
    required this.billingInfo,
    required this.addressesInfo,
  });

  final String uid;
  final String companyName;
  final String contactName;
  final String email;
  final String locationText;
  final String avatarUrl;
  final CompanyBusinessInfoDraft businessInfo;
  final CompanyBillingDraft billingInfo;
  final CompanyAddressesDraft addressesInfo;

  factory _CompanyUiData.fallback(String fallbackName) {
    return _CompanyUiData(
      uid: '',
      companyName: fallbackName,
      contactName: '',
      email: '',
      locationText: '',
      avatarUrl: '',
      businessInfo: CompanyBusinessInfoDraft.empty(),
      billingInfo: CompanyBillingDraft.empty(),
      addressesInfo: CompanyAddressesDraft.empty(),
    );
  }

  factory _CompanyUiData.fromFirestore({
    required String uid,
    required Map<String, dynamic>? data,
    required String fallbackCompanyName,
    CompanyBusinessInfoDraft? fallbackBusiness,
    CompanyBillingDraft? fallbackBilling,
    CompanyAddressesDraft? fallbackAddresses,
  }) {
    final source = data ?? const <String, dynamic>{};

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    final company = asMap(source['company']);
    final addresses = asMap(source['addresses']);
    final billing = asMap(source['billing']);

    String first(
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
      Object? p,
      Object? q,
      Object? r,
      Object? s,
      Object? t,
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
        p,
        q,
        r,
        s,
        t,
      ]) {
        final value = (candidate ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    String firstOf(Iterable<Object?> candidates) {
      for (final candidate in candidates) {
        final value = (candidate ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final companyName = first(
      source['panel_companyName'],
      source['panel_company_name'],
      company['name'],
      source['companyName'],
      source['company_name'],
      fallbackCompanyName,
    );
    final contactName = first(
      source['panel_contactName'],
      source['panel_contact_name'],
      company['contactName'],
      source['contactName'],
      source['contact_name'],
      source['displayName'],
    );
    final email = first(
      source['panel_contactEmail'],
      source['panel_contact_email'],
      company['contactEmail'],
      source['email'],
      source['contact_email'],
    );

    final companyAddress = asMap(company['address']);
    final profile = asMap(source['profile']);
    final basic = asMap(source['basic']);

    final city = first(
      source['panel_billingCity'],
      source['panel_billing_city'],
      addresses['billingCity'],
      source['panel_city'],
      companyAddress['city'],
    );
    final state = first(
      source['panel_billingState'],
      source['panel_billing_state'],
      addresses['billingState'],
      source['panel_state'],
      companyAddress['state'],
    );

    final location = city.isEmpty && state.isEmpty
        ? ''
        : (city.isEmpty ? state : (state.isEmpty ? city : '$city, $state'));
    final avatarUrlRaw = firstOf([
      source['panel_logoUrl'],
      source['panel_logo_url'],
      source['companyLogoUrl'],
      source['brandLogoUrl'],
      source['company_logo_url'],
      source['brand_logo_url'],
      source['logoUrl'],
      source['logo_url'],
      source['panel_profileImageUrl'],
      source['panel_profile_image_url'],
      source['profileImageUrl'],
      source['profile_image_url'],
      source['photoUrl'],
      source['photo_url'],
      source['avatarUrl'],
      source['avatar_url'],
      profile['logoUrl'],
      profile['logo_url'],
      profile['profileImageUrl'],
      profile['profile_image_url'],
      profile['photoUrl'],
      profile['photo_url'],
      profile['avatarUrl'],
      profile['avatar_url'],
      basic['profileImageUrl'],
      basic['profile_image_url'],
      basic['photoUrl'],
      basic['photo_url'],
      basic['avatarUrl'],
      basic['avatar_url'],
      company['logoUrl'],
      company['logo_url'],
      company['profileImageUrl'],
      company['profile_image_url'],
      company['photoUrl'],
      company['photo_url'],
      company['avatarUrl'],
      company['avatar_url'],
    ]);
    final avatarUrl = avatarUrlRaw.isNotEmpty
        ? avatarUrlRaw
        : 'company/$uid/profile/avatar.jpg';

    final businessInfo = CompanyBusinessInfoDraft(
      companyName: first(companyName, fallbackBusiness?.companyName),
      contactName: first(contactName, fallbackBusiness?.contactName),
      contactEmail: first(email, fallbackBusiness?.contactEmail),
      contactPhone: first(
        source['panel_contactPhone'],
        source['panel_contact_phone'],
        source['panel_contactPhoneAreaCode'] != null &&
                source['panel_contactPhoneLocal'] != null
            ? '${source['panel_contactPhoneAreaCode']}${source['panel_contactPhoneLocal']}'
            : null,
        source['panel_contact_phone_area_code'] != null &&
                source['panel_contact_phone_local'] != null
            ? '${source['panel_contact_phone_area_code']}${source['panel_contact_phone_local']}'
            : null,
        company['contactPhone'],
        source['panel_phone'],
        company['phone'],
        fallbackBusiness?.contactPhone,
      ),
      companyEmail: first(
        source['email'],
        source['panel_contactEmail'],
        source['panel_contact_email'],
        company['contactEmail'],
        fallbackBusiness?.companyEmail,
      ),
      companyPhone: first(
        source['panel_companyPhone'],
        source['panel_company_phone'],
        source['panel_companyPhoneAreaCode'] != null &&
                source['panel_companyPhoneLocal'] != null
            ? '${source['panel_companyPhoneAreaCode']}${source['panel_companyPhoneLocal']}'
            : null,
        source['panel_company_phone_area_code'] != null &&
                source['panel_company_phone_local'] != null
            ? '${source['panel_company_phone_area_code']}${source['panel_company_phone_local']}'
            : null,
        company['phone'],
        source['panel_phone'],
        fallbackBusiness?.companyPhone,
      ),
      companyUrl: first(
        source['panel_companyWebsite'],
        source['panel_company_website'],
        source['panel_website'],
        company['website'],
        fallbackBusiness?.companyUrl,
      ),
      businessType: first(
        source['panel_businessType'],
        source['panel_business_type'],
        company['businessType'],
        source['panel_industry'],
        company['industry'],
        fallbackBusiness?.businessType,
      ),
    );

    final billingInfo = CompanyBillingDraft(
      method: first(
        billing['method'],
        source['panel_billingMethod'],
        source['panel_billing_method'],
        fallbackBilling?.method,
        'Credit/Debit Card',
      ),
      saveForFutureUse:
          billing['saveForFutureUse'] == true ||
          source['panel_billingSaveForFutureUse'] == true ||
          source['panel_billing_save_for_future_use'] == true ||
          (fallbackBilling?.saveForFutureUse ?? false),
      nameOnCard: first(
        billing['nameOnCard'],
        source['panel_billingNameOnCard'],
        source['panel_billing_name_on_card'],
        fallbackBilling?.nameOnCard,
      ),
      cardNumber: first(billing['cardNumber'], fallbackBilling?.cardNumber),
      expiry: first(
        billing['expiry'],
        source['panel_billingExpiry'],
        source['panel_billing_expiry'],
        fallbackBilling?.expiry,
      ),
      cvv: first(billing['cvv'], fallbackBilling?.cvv),
      achAccountName: first(
        billing['achAccountName'],
        fallbackBilling?.achAccountName,
      ),
      achRoutingNumber: first(
        billing['achRoutingNumber'],
        fallbackBilling?.achRoutingNumber,
      ),
      achAccountNumber: first(
        billing['achAccountNumber'],
        fallbackBilling?.achAccountNumber,
      ),
      applePayEmail: first(
        billing['applePayEmail'],
        source['panel_billingApplePayEmail'],
        source['panel_billing_apple_pay_email'],
        fallbackBilling?.applePayEmail,
      ),
      googlePayEmail: first(
        billing['googlePayEmail'],
        source['panel_billingGooglePayEmail'],
        source['panel_billing_google_pay_email'],
        fallbackBilling?.googlePayEmail,
      ),
    );

    final addressesInfo = CompanyAddressesDraft(
      billingStreet: first(
        addresses['billingStreet'],
        source['panel_billingStreet'],
        source['panel_billing_street'],
        source['panel_street'],
        fallbackAddresses?.billingStreet,
      ),
      billingCity: first(
        addresses['billingCity'],
        source['panel_billingCity'],
        source['panel_billing_city'],
        source['panel_city'],
        fallbackAddresses?.billingCity,
      ),
      billingState: first(
        addresses['billingState'],
        source['panel_billingState'],
        source['panel_billing_state'],
        source['panel_state'],
        fallbackAddresses?.billingState,
      ),
      billingZip: first(
        addresses['billingZip'],
        source['panel_billingZip'],
        source['panel_billing_zip'],
        source['panel_zip'],
        fallbackAddresses?.billingZip,
      ),
      billingCountry: first(
        addresses['billingCountry'],
        source['panel_billingCountry'],
        source['panel_billing_country'],
        source['panel_country'],
        fallbackAddresses?.billingCountry,
      ),
      shippingSameAsBilling:
          addresses['shippingSameAsBilling'] == true ||
          source['panel_shippingSameAsBilling'] == true ||
          source['panel_shipping_same_as_billing'] == true ||
          (fallbackAddresses?.shippingSameAsBilling ?? false),
      shippingStreet: first(
        addresses['shippingStreet'],
        source['panel_shippingStreet'],
        source['panel_shipping_street'],
        fallbackAddresses?.shippingStreet,
      ),
      shippingCity: first(
        addresses['shippingCity'],
        source['panel_shippingCity'],
        source['panel_shipping_city'],
        fallbackAddresses?.shippingCity,
      ),
      shippingState: first(
        addresses['shippingState'],
        source['panel_shippingState'],
        source['panel_shipping_state'],
        fallbackAddresses?.shippingState,
      ),
      shippingZip: first(
        addresses['shippingZip'],
        source['panel_shippingZip'],
        source['panel_shipping_zip'],
        fallbackAddresses?.shippingZip,
      ),
      shippingCountry: first(
        addresses['shippingCountry'],
        source['panel_shippingCountry'],
        source['panel_shipping_country'],
        fallbackAddresses?.shippingCountry,
      ),
    );

    return _CompanyUiData(
      uid: uid,
      companyName: companyName.isNotEmpty ? companyName : fallbackCompanyName,
      contactName: contactName,
      email: email,
      locationText: location,
      avatarUrl: avatarUrl,
      businessInfo: businessInfo,
      billingInfo: billingInfo,
      addressesInfo: addressesInfo,
    );
  }

  ClientProfileDraft asClientProfileDraft() {
    final name = contactName.isNotEmpty ? contactName : companyName;
    return ClientProfileDraft(
      basic: BasicInfo(
        name: name,
        email: email,
        phone: businessInfo.contactPhone,
        profileImageUrl: avatarUrl,
      ),
      address: AddressInfo(
        street: addressesInfo.billingStreet,
        city: addressesInfo.billingCity,
        state: addressesInfo.billingState,
        zip: addressesInfo.billingZip,
        country: addressesInfo.billingCountry,
      ),
      payment: const PaymentInfo(
        method: PaymentMethod.applePay,
        saveForFuture: true,
      ),
      nail: NailPreferences.empty(),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.title,
    required this.companyName,
    this.onOpenProfile,
    required this.onLogout,
  });

  final String title;
  final String companyName;
  final VoidCallback? onOpenProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: CompanyHeader(
        companyName: companyName,
        onOpenProfile: onOpenProfile,
        onLogout: onLogout,
      ),
      body: Center(
        child: Text(
          '$title (Coming soon)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
