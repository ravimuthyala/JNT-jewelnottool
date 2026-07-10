import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants/profile_table_columns.dart';
import '../theme/app_colors.dart';
import '../services/artist_directory_service.dart';
import '../services/notifications_service.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../widgets/nail_preferences_inline_editor.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';
import 'artist_reviews_page.dart';
import 'notifications_page.dart';
import '../models/client_profile_models.dart'
    show
        AddressInfo,
        BasicInfo,
        ClientProfileDraft,
        PaymentInfo,
        PaymentMethod,
        NailPreferences,
        NailDimensions,
        NailLength,
        nailShapes;

const Color _requestSnow = Color(0xFFFAF9F9);
const Color _focusRing = Color(0xFFFFBF47);
final BorderSide _requestBorder = BorderSide(
  color: AppColors.blackCat.withValues(alpha: 0.25),
);

class ClientCustomRequestPage extends StatefulWidget {
  const ClientCustomRequestPage({
    super.key,
    required this.profile,
    this.initialArtistName,
    this.onBackHome,
    this.showBottomNav = false,
    this.bottomNavIndex = 1,
    this.onNavTap,
    this.onOpenProfile,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.onLogout,
    this.showExtendedAvatarMenu = false,
    this.showProfileMenu = false,
    this.initialRequestData,
    this.isActiveTab = true,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final Future<void> Function()? onLogout;
  final bool showExtendedAvatarMenu;
  final bool showProfileMenu;
  final Map<String, dynamic>? initialRequestData;
  final bool isActiveTab;

  /// If passed, artist dropdown will be pre-selected.
  final String? initialArtistName;

  @override
  State<ClientCustomRequestPage> createState() =>
      _ClientCustomRequestPageState();
}

class _ClientCustomRequestPageState extends State<ClientCustomRequestPage> {
  static const int _maxImageSizeBytes = 2 * 1024 * 1024;
  static const int _maxInspirationPhotos = 10;
  // Request details
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'designNotifications',
  );
  final FocusNode _needByFocusNode = FocusNode(debugLabel: 'needByDateField');
  final FocusNode _descriptionFocusNode = FocusNode(
    debugLabel: 'descriptionField',
  );
  bool _didSetInitialA11yFocus = false;
  bool _focusRequestQueued = false;
  DateTime? _needBy;

  // Inspiration checkbox (default checked)
  bool _allowNonLicensed = true;
  final ImagePicker _picker = ImagePicker();
  final List<String> _inspirationPhotos = [];
  final Map<String, XFile> _pickedPhotoFiles = <String, XFile>{};
  final Map<String, Uint8List> _pickedPhotoBytes = <String, Uint8List>{};

  // Budget
  RangeValues _budget = const RangeValues(15, 500);
  RangeValues _sanitizeBudgetRange(RangeValues values) {
    final start = values.start.clamp(15.0, 5000.0).toDouble();
    final end = values.end.clamp(start, 5000.0).toDouble();
    return RangeValues(start, end);
  }

  int _nfcSelectedCount(NailDimensions dimensions) {
    return <bool>[
      dimensions.lThumbNfc,
      dimensions.lIndexNfc,
      dimensions.lMiddleNfc,
      dimensions.lRingNfc,
      dimensions.lPinkyNfc,
      dimensions.rThumbNfc,
      dimensions.rIndexNfc,
      dimensions.rMiddleNfc,
      dimensions.rRingNfc,
      dimensions.rPinkyNfc,
    ].where((selected) => selected).length;
  }

  bool _hasAnyNfcEligibleDimension(NailDimensions dimensions) {
    final values = <double?>[
      dimensions.lThumb,
      dimensions.lIndex,
      dimensions.lMiddle,
      dimensions.lRing,
      dimensions.lPinky,
      dimensions.rThumb,
      dimensions.rIndex,
      dimensions.rMiddle,
      dimensions.rRing,
      dimensions.rPinky,
    ];
    return values.any((v) => v != null && v.isFinite && v >= 8);
  }

  bool _hasAnyNfcSelected(NailDimensions dimensions) {
    return _nfcSelectedCount(dimensions) > 0;
  }

  int _totalSelectedNfcCount({required NailPreferences mainNails}) {
    var count = _nfcSelectedCount(mainNails.dimensions);
    for (final slot in _groupSelections) {
      final nails = slot.savedNails ?? slot.draftNails;
      if (nails == null) continue;
      count += _nfcSelectedCount(nails.dimensions);
    }
    return count;
  }

  bool _requestHasNfcEligibleNail({required NailPreferences mainNails}) {
    if (_hasAnyNfcEligibleDimension(mainNails.dimensions)) return true;
    for (final slot in _groupSelections) {
      final nails = slot.savedNails ?? slot.draftNails;
      if (nails == null) continue;
      if (_hasAnyNfcEligibleDimension(nails.dimensions)) return true;
    }
    return false;
  }

  bool _requestHasSelectedNfc({required NailPreferences mainNails}) {
    if (_hasAnyNfcSelected(mainNails.dimensions)) return true;
    for (final slot in _groupSelections) {
      final nails = slot.savedNails ?? slot.draftNails;
      if (nails == null) continue;
      if (_hasAnyNfcSelected(nails.dimensions)) return true;
    }
    return false;
  }

  void _applyNfcBudgetDelta({required int oldCount, required int newCount}) {
    final delta = (newCount - oldCount) * 7.0;
    if (delta == 0) return;
    final nextStart = (_budget.start + delta).clamp(15.0, 5000.0).toDouble();
    final nextEnd = _budget.end < nextStart ? nextStart : _budget.end;
    _budget = _sanitizeBudgetRange(RangeValues(nextStart, nextEnd));
  }

  // Order type
  OrderType _orderType = OrderType.single;

  // Specific Artist section
  String? _selectedArtist;
  bool _fallbackToPool = true;

  // Nail selections (prefilled from profile but always safe)
  late String _shape;
  late NailLength _length;
  late NailPreferences _singleNailPrefs;

  // Shipping
  bool _shippingDifferent = false;
  final TextEditingController _shipStreetCtrl = TextEditingController();
  final TextEditingController _shipCityCtrl = TextEditingController();
  final TextEditingController _shipZipCtrl = TextEditingController();
  final TextEditingController _shipStateCtrl = TextEditingController();
  String _shipState = '';
  String _shipCountry = 'United States';

  // Group order clients (loaded from DB only)
  List<CompletedClient> _completedClients = <CompletedClient>[];
  bool _loadingCompletedClients = false;

  final List<GroupClientSelection> _groupSelections = [];
  static const int _maxGroupClients = 15;
  bool _isSubmitting = false;

  final List<String> _artistNames = [];
  final Map<String, String> _fieldErrors = <String, String>{};

  bool get _isShipCountryUs =>
      _shipCountry.trim().toLowerCase() == 'united states';

  @override
  void initState() {
    super.initState();

    // Preselect artist if coming from artists page
    _selectedArtist = widget.initialArtistName?.trim();

    // Safe defaults for nail shape/length
    final profileShape = widget.profile.nail.shape;
    final profileLength = widget.profile.nail.length;

    _shape = (profileShape.isNotEmpty)
        ? profileShape
        : (nailShapes.isNotEmpty ? nailShapes.first : 'Square');

    // If profile length is none, force a valid default
    _length = (profileLength == NailLength.none)
        ? NailLength.medium
        : profileLength;
    _singleNailPrefs = NailPreferences(
      dimensions: widget.profile.nail.dimensions,
      shape: _shape,
      length: _length,
    );

    // Ensure default country is set
    _shipCountry = 'United States';
    _shipStateCtrl.text = _shipState;

    unawaited(_loadArtistNames());
    //unawaited(_loadCompletedClientsFromDb());
    _applyInitialRequestData();
    _scheduleInitialA11yFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialA11yFocus();
  }

  bool _shouldRunInitialA11yFocus() {
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.accessibleNavigation ?? false) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
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
      if (!_shouldRunInitialA11yFocus()) {
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
      if (!_shouldRunInitialA11yFocus()) {
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
  void didUpdateWidget(covariant ClientCustomRequestPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActiveTab && widget.isActiveTab) {
      _didSetInitialA11yFocus = false;
      _scheduleInitialA11yFocus();
    }
  }

  Future<void> _loadArtistNames() async {
    try {
      final entries = await ArtistDirectoryService.fetchAllArtists();
      if (!mounted) return;
      final names = entries
          .where((e) => e.acceptsDirectRequests)
          .map((e) => e.name.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() {
        _artistNames
          ..clear()
          ..addAll(
            _dedupeArtistNames(<String>[
              ...names,
              if ((_selectedArtist ?? '').trim().isNotEmpty) _selectedArtist!,
            ]),
          );
        final selected = (_selectedArtist ?? '').trim();
        if (selected.isNotEmpty &&
            !_artistNames.any(
              (n) => n.trim().toLowerCase() == selected.toLowerCase(),
            )) {
          _artistNames
            ..clear()
            ..addAll(_dedupeArtistNames(<String>[selected, ..._artistNames]));
        }
      });
    } catch (_) {}
  }

  List<String> _dedupeArtistNames(List<String> rawNames) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) {
        result.add(name);
      }
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<String> _resolveSelectedArtistEmail(String selectedArtist) async {
    final normalizedName = selectedArtist.trim().toLowerCase();
    if (normalizedName.isEmpty) return '';
    try {
      final artists = await ArtistDirectoryService.fetchAllArtists(
        hydrateMediaFallbacks: false,
      );
      for (final artist in artists) {
        if (!artist.acceptsDirectRequests) continue;
        if (artist.name.trim().toLowerCase() != normalizedName) continue;
        final email = artist.email.trim().toLowerCase();
        if (email.isNotEmpty) return email;
      }
    } catch (_) {}
    return '';
  }

  NailLength _parseNailLength(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'extra short':
      case 'extra_short':
      case 'extrashort':
      case 'xllong':
      case 'xl_long':
      case 'xl long':
        return NailLength.xlLong;
      case 'short':
        return NailLength.short;
      case 'medium':
        return NailLength.medium;
      case 'long':
        return NailLength.long;
      case 'extralong':
      case 'extra_long':
      case 'extra long':
        return NailLength.extraLong;
      default:
        return NailLength.none;
    }
  }

  double? _asDouble(Object? raw) {
    if (raw is num) {
      final v = raw.toDouble();
      return v.isFinite ? v : null;
    }
    if (raw is String) {
      final cleaned = raw.trim().replaceAll(
        RegExp(r'\s*mm$', caseSensitive: false),
        '',
      );
      final v = double.tryParse(cleaned);
      if (v == null || !v.isFinite) return null;
      return v;
    }
    return null;
  }

  bool _asBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      return value == 'true' || value == 'yes' || value == '1';
    }
    return false;
  }

  Object? _nfcValue(Map<String, dynamic> raw, String key) {
    final nfc = raw['nfc'];
    if (nfc is Map) {
      return raw['${key}Nfc'] ?? nfc[key];
    }
    return raw['${key}Nfc'];
  }

  NailDimensions _parseNailDimensions(Map<String, dynamic> raw) {
    return NailDimensions(
      lThumb: _asDouble(raw['lThumb']),
      lIndex: _asDouble(raw['lIndex']),
      lMiddle: _asDouble(raw['lMiddle']),
      lRing: _asDouble(raw['lRing']),
      lPinky: _asDouble(raw['lPinky']),
      rThumb: _asDouble(raw['rThumb']),
      rIndex: _asDouble(raw['rIndex']),
      rMiddle: _asDouble(raw['rMiddle']),
      rRing: _asDouble(raw['rRing']),
      rPinky: _asDouble(raw['rPinky']),
      lThumbNfc: _asBool(_nfcValue(raw, 'lThumb')),
      lIndexNfc: _asBool(_nfcValue(raw, 'lIndex')),
      lMiddleNfc: _asBool(_nfcValue(raw, 'lMiddle')),
      lRingNfc: _asBool(_nfcValue(raw, 'lRing')),
      lPinkyNfc: _asBool(_nfcValue(raw, 'lPinky')),
      rThumbNfc: _asBool(_nfcValue(raw, 'rThumb')),
      rIndexNfc: _asBool(_nfcValue(raw, 'rIndex')),
      rMiddleNfc: _asBool(_nfcValue(raw, 'rMiddle')),
      rRingNfc: _asBool(_nfcValue(raw, 'rRing')),
      rPinkyNfc: _asBool(_nfcValue(raw, 'rPinky')),
    );
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Object? _supabaseJsonValue(Object? value) {
    if (value == null) return null;

    if (value is DateTime) return value.toIso8601String();

    if (value is List) {
      return value.map(_supabaseJsonValue).toList(growable: false);
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _supabaseJsonValue(item)),
      );
    }

    try {
      final maybeDate = (value as dynamic).toDate();
      if (maybeDate is DateTime) {
        return maybeDate.toIso8601String();
      }
    } catch (_) {}

    return value;
  }

  Map<String, dynamic> _supabaseJsonMap(Map<String, dynamic> source) {
    final converted = _supabaseJsonValue(source);
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) {
      return converted.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _asStringMap(Object? raw) {
    if (raw == null) return <String, dynamic>{};

    if (raw is Map<String, dynamic>) return raw;

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }

    return <String, dynamic>{};
  }

  String _safeRequestStorageKey(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'anonymous';
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<String> _createSupabaseClientCustomRequest({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> details,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final nowIso = DateTime.now().toIso8601String();

    final cleanSummary = _supabaseJsonMap(summary);
    final cleanDetails = _supabaseJsonMap(details);
    final submissionFingerprint = <String>[
      _firstNonEmpty([
        cleanSummary['clientEmail'],
        widget.profile.basic.email,
        user?.email,
      ]),
      _firstNonEmpty([cleanSummary['clientName'], widget.profile.basic.name]),
      _firstNonEmpty([
        cleanSummary['selectedArtist'],
        _asStringMap(cleanDetails['order'])['selectedArtist'],
      ]),
      _firstNonEmpty([
        cleanSummary['needBy'],
        _asStringMap(cleanDetails['requestDetails'])['needBy'],
      ]),
      _firstNonEmpty([
        cleanSummary['budgetMin'],
        _asStringMap(cleanDetails['budget'])['min'],
      ]),
      _firstNonEmpty([
        cleanSummary['budgetMax'],
        _asStringMap(cleanDetails['budget'])['max'],
      ]),
      _firstNonEmpty([
        cleanSummary['nailShape'],
        _asStringMap(cleanDetails['nailPreferences'])['shape'],
      ]),
      _firstNonEmpty([
        cleanSummary['nailLength'],
        _asStringMap(cleanDetails['nailPreferences'])['length'],
      ]),
      _firstNonEmpty([
        cleanSummary['descriptionPreview'],
        _asStringMap(cleanDetails['requestDetails'])['description'],
      ]),
    ].map((value) => value.trim().toLowerCase()).join('|');

    cleanSummary['submissionFingerprint'] = submissionFingerprint;
    cleanDetails['submissionFingerprint'] = submissionFingerprint;

    final orderNumber =
        _firstNonEmpty([cleanSummary['orderNumber']]).isNotEmpty
        ? _firstNonEmpty([cleanSummary['orderNumber']])
        : 'CR-${DateTime.now().microsecondsSinceEpoch.toString().substring(
            DateTime.now().microsecondsSinceEpoch.toString().length - 5,
          )}';
    cleanSummary['orderNumber'] = orderNumber;
    cleanDetails['orderNumber'] = orderNumber;

    final compactSummary = <String, dynamic>{
      'orderNumber': orderNumber,
      'requestType': _firstNonEmpty([
        cleanSummary['requestType'],
        'clientCustomRequest',
      ]),
      'status': _firstNonEmpty([cleanSummary['status'], 'pending']),
      'clientStatus': _firstNonEmpty([cleanSummary['clientStatus'], 'pending']),
      'artistStatus': _firstNonEmpty([
        cleanSummary['artistStatus'],
        'in_review',
      ]),
      'clientName': _firstNonEmpty([
        cleanSummary['clientName'],
        widget.profile.basic.name,
      ]),
      'clientEmail': _firstNonEmpty([
        cleanSummary['clientEmail'],
        widget.profile.basic.email,
        user?.email,
      ]).toLowerCase(),
      'selectedArtist': _firstNonEmpty([
        cleanSummary['selectedArtist'],
        _asStringMap(cleanDetails['order'])['selectedArtist'],
      ]),
      'selectedArtistEmail': _firstNonEmpty([
        cleanSummary['selectedArtistEmail'],
        _asStringMap(cleanDetails['order'])['selectedArtistEmail'],
      ]).toLowerCase(),
      'orderType': _firstNonEmpty([
        cleanSummary['orderType'],
        _asStringMap(cleanDetails['order'])['type'],
        'single',
      ]),
      'needBy': _firstNonEmpty([
        cleanSummary['needBy'],
        _asStringMap(cleanDetails['requestDetails'])['needBy'],
      ]),
      'needByDisplay': _firstNonEmpty([
        cleanSummary['needByDisplay'],
        _asStringMap(cleanDetails['requestDetails'])['needByDisplay'],
      ]),
      'budgetMin': int.tryParse(
        _firstNonEmpty([
          cleanSummary['budgetMin'],
          _asStringMap(cleanDetails['budget'])['min'],
        ]),
      ),
      'budgetMax': int.tryParse(
        _firstNonEmpty([
          cleanSummary['budgetMax'],
          _asStringMap(cleanDetails['budget'])['max'],
        ]),
      ),
      'nailShape': _firstNonEmpty([
        cleanSummary['nailShape'],
        _asStringMap(cleanDetails['nailPreferences'])['shape'],
      ]),
      'nailLength': _firstNonEmpty([
        cleanSummary['nailLength'],
        _asStringMap(cleanDetails['nailPreferences'])['length'],
      ]),
      'descriptionPreview': _firstNonEmpty([
        cleanSummary['descriptionPreview'],
      ]),
      'photoCount': cleanSummary['photoCount'] ?? 0,
      'hasInspirationPhotos': cleanSummary['hasInspirationPhotos'] ?? false,
      'inspirationPhotos': cleanSummary['inspirationPhotos'] ?? const <String>[],
      'submissionFingerprint': submissionFingerprint,
      'createdAt': cleanSummary['createdAt'] ?? nowIso,
      'updatedAt': cleanSummary['updatedAt'] ?? nowIso,
    };

    final compactDetails = <String, dynamic>{
      'requestDetails': _asStringMap(cleanDetails['requestDetails']),
      'budget': _asStringMap(cleanDetails['budget']),
      'nfc': _asStringMap(cleanDetails['nfc']),
      'nailPreferences': _asStringMap(cleanDetails['nailPreferences']),
      'shipping': _asStringMap(cleanDetails['shipping']),
      'order': _asStringMap(cleanDetails['order']),
      'groupOrder': _asStringMap(cleanDetails['groupOrder']),
      'inspirationPhotos': cleanDetails['inspirationPhotos'] ?? const <String>[],
      'submissionFingerprint': submissionFingerprint,
      'orderNumber': orderNumber,
    };

    final row = <String, dynamic>{
      'order_number': orderNumber,
      'request_number': orderNumber,
      'client_request_number': orderNumber,
      'source_collection': 'Client_Custom_Requests',
      'client_id': (user?.id ?? '').trim(),
      'client_email': _firstNonEmpty([
        cleanSummary['clientEmail'],
        widget.profile.basic.email,
        user?.email,
      ]).toLowerCase(),
      'client_name': _firstNonEmpty([
        cleanSummary['clientName'],
        widget.profile.basic.name,
      ]),
      'selected_artist': _firstNonEmpty([
        cleanSummary['selectedArtist'],
        _asStringMap(cleanDetails['order'])['selectedArtist'],
      ]),
      'selected_artist_email': _firstNonEmpty([
        cleanSummary['selectedArtistEmail'],
        _asStringMap(cleanDetails['order'])['selectedArtistEmail'],
      ]).toLowerCase(),
      'request_type': _firstNonEmpty([
        cleanSummary['requestType'],
        'clientCustomRequest',
      ]),
      'order_type': _firstNonEmpty([
        cleanSummary['orderType'],
        _asStringMap(cleanDetails['order'])['type'],
        'single',
      ]),
      'status': _firstNonEmpty([cleanSummary['status'], 'pending']),
      'client_status': _firstNonEmpty([
        cleanSummary['clientStatus'],
        'pending',
      ]),
      'artist_status': _firstNonEmpty([
        cleanSummary['artistStatus'],
        'in_review',
      ]),
      'need_by': _firstNonEmpty([
        cleanSummary['needBy'],
        _asStringMap(cleanDetails['requestDetails'])['needBy'],
      ]),
      'need_by_display': _firstNonEmpty([
        cleanSummary['needByDisplay'],
        _asStringMap(cleanDetails['requestDetails'])['needByDisplay'],
      ]),
      'description': _firstNonEmpty([
        _asStringMap(cleanDetails['requestDetails'])['description'],
        cleanSummary['description'],
      ]),
      'description_preview': _firstNonEmpty([
        cleanSummary['descriptionPreview'],
      ]),
      'budget_min': int.tryParse(
        _firstNonEmpty([
          cleanSummary['budgetMin'],
          _asStringMap(cleanDetails['budget'])['min'],
        ]),
      ),
      'budget_max': int.tryParse(
        _firstNonEmpty([
          cleanSummary['budgetMax'],
          _asStringMap(cleanDetails['budget'])['max'],
        ]),
      ),
      'is_direct_request': _asBool(cleanSummary['isDirectRequest']),
      'fallback_to_pool': _asBool(cleanSummary['fallbackToPool']),
      'open_to_artist_pool': !_asBool(cleanSummary['isDirectRequest']),
      'direct_artist_status': _asBool(cleanSummary['isDirectRequest']) ? 'in_review' : '',
      'artist_pool_status': _asBool(cleanSummary['isDirectRequest']) ? 'locked' : 'in_review',
      'allow_non_licensed': _asBool(cleanSummary['allowNonLicensed']),
      'is_group_order': _asBool(cleanSummary['isGroupOrder']),
      'group_client_count':
          int.tryParse(_firstNonEmpty([cleanSummary['groupClientCount']])) ?? 0,
      'nfc_eligible': _asBool(cleanSummary['nfcEligible']),
      'eligible_for_nfc': _asBool(cleanSummary['eligibleForNfc']),
      'nfc_requested': _asBool(cleanSummary['nfcRequested']),
      'nfc_selected': _asBool(cleanSummary['nfcSelected']),
      'nfc_count':
          int.tryParse(_firstNonEmpty([cleanSummary['nfcCount']])) ?? 0,
      'summary': compactSummary,
      'details': compactDetails,
      'request_details': _asStringMap(cleanDetails['requestDetails']),
      'inspiration_photos':
          cleanSummary['inspirationPhotos'] ?? const <String>[],
      'photo_count': cleanSummary['photoCount'] ?? 0,
      'has_inspiration_photos': cleanSummary['hasInspirationPhotos'] ?? false,
      'photo_upload_status': 'pending',
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    final insertedRows = await supabase
        .from('client_custom_requests')
        .insert(row)
        .select('id')
        .limit(1);

    final inserted = insertedRows.isNotEmpty
        ? Map<String, dynamic>.from(insertedRows.first)
        : <String, dynamic>{};

    final requestId = (inserted['id'] ?? '').toString().trim();
    if (requestId.isEmpty) {
      throw Exception('Supabase did not return a request id.');
    }

    await supabase.from('client_custom_requests_details').insert({
      'request_id': requestId,
      'detail_key': 'payload',
      'data': {
        'summary': compactSummary,
        'details': cleanDetails,
        'payload': cleanDetails,
        'requestDetails': _asStringMap(cleanDetails['requestDetails']),
      },
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    return requestId;
  }

  Future<Map<String, dynamic>> _readSupabaseClientCustomRequest(
    String requestId,
  ) async {
    final rows = await Supabase.instance.client
        .from('client_custom_requests')
        .select()
        .eq('id', requestId)
        .limit(1);

    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first);
    }

    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _readSupabaseClientCustomRequestPayload(
    String requestId,
  ) async {
    final rows = await Supabase.instance.client
        .from('client_custom_requests_details')
        .select('data, updated_at, id')
        .eq('request_id', requestId)
        .eq('detail_key', 'payload')
        .order('updated_at', ascending: false)
        .limit(1);

    final row = rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;

    if (row is Map<String, dynamic>) {
      final data = row['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    return const <String, dynamic>{};
  }

  Future<void> _upsertSupabaseClientCustomRequestPayload(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final nowIso = DateTime.now().toIso8601String();
    final existingRows = await Supabase.instance.client
        .from('client_custom_requests_details')
        .select('id, updated_at')
        .eq('request_id', requestId)
        .eq('detail_key', 'payload')
        .order('updated_at', ascending: false)
        .limit(1);

    final existing = existingRows.isNotEmpty
        ? Map<String, dynamic>.from(existingRows.first)
        : null;

    final cleanData = _supabaseJsonMap(data);

    if (existing is Map<String, dynamic> && existing['id'] != null) {
      await Supabase.instance.client
          .from('client_custom_requests_details')
          .update({'data': cleanData, 'updated_at': nowIso})
          .eq('id', existing['id']);
      return;
    }

    await Supabase.instance.client.from('client_custom_requests_details').insert({
      'request_id': requestId,
      'detail_key': 'payload',
      'data': cleanData,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
  }

  Future<void> _updateSupabaseClientCustomRequest(
    String requestId,
    Map<String, dynamic> values,
  ) async {
    final clean = _supabaseJsonMap(values);
    clean.remove('photo_upload_worker_started_at');
    clean.remove('photo_upload_completed_at');
    clean.remove('photo_upload_failed_at');
    clean['updated_at'] = DateTime.now().toIso8601String();

    await Supabase.instance.client
        .from('client_custom_requests')
        .update(clean)
        .eq('id', requestId);
  }

  bool _hasAllValidMeasurements(NailDimensions dims) {
    final values = <double?>[
      dims.lThumb,
      dims.lIndex,
      dims.lMiddle,
      dims.lRing,
      dims.lPinky,
      dims.rThumb,
      dims.rIndex,
      dims.rMiddle,
      dims.rRing,
      dims.rPinky,
    ];
    return values.every((v) => v != null && v > 0);
  }

  Future<void> _loadCompletedClientsFromDb() async {
    setState(() => _loadingCompletedClients = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      final currentUid = currentUser?.id ?? '';
      final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();

      Future<List<dynamic>> loadAllRows(String table) async {
        const pageSize = 300;
        final allRows = <dynamic>[];
        var from = 0;

        final columns = columnsForProfileTable(table) ?? '*';
        while (true) {
          try {
            final rows = await supabase
                .from(table)
                .select(columns)
                .range(from, from + pageSize - 1);

            if (rows.isEmpty) break;
            allRows.addAll(rows);
            if (rows.length < pageSize) break;
            from += pageSize;
          } catch (e) {
            debugPrint(
              '[ClientCustomRequestPage] failed loading group clients from $table: $e',
            );
            break;
          }
        }

        return allRows;
      }

      // Load every possible client source. Some projects have both singular
      // and legacy plural tables after migration, so merge all of them.
      final results = await Future.wait<List<dynamic>>([
        loadAllRows('client'),
        loadAllRows('clients'),
        loadAllRows('client_artist'),
      ]);

      final byKey = <String, CompletedClient>{};

      for (final rows in results) {
        for (final rawRow in rows) {
          if (rawRow is! Map) continue;

          final data = rawRow.map(
            (key, value) => MapEntry(key.toString(), value),
          );

          final docId = (data['id'] ?? '').toString().trim();
          if (docId.isEmpty) continue;

          final profile = _asStringMap(data['profile']);
          final basic = _asStringMap(data['basic']);
          final client = _asStringMap(data['client']);
          final clientProfile = _asStringMap(client['profile']);

          final address = _firstMap([
            data['address'],
            data['addresses'],
            profile['address'],
            basic['address'],
            client['address'],
            clientProfile['address'],
          ]);

          final nail = _firstMap([
            data['nail_preferences'],
            data['nailPreferences'],
            profile['nailPreferences'],
            basic['nailPreferences'],
            client['nailPreferences'],
            clientProfile['nailPreferences'],
          ]);

          final dims = _firstMap([
            nail['dimensions'],
            data['measurements'],
            data['dimensions'],
            profile['dimensions'],
            basic['dimensions'],
            client['dimensions'],
          ]);

          final email = _firstNonEmpty([
            data['email'],
            data['panel_email'],
            data['client_email'],
            data['contact_email'],
            profile['email'],
            basic['email'],
            client['email'],
            clientProfile['email'],
          ]).trim().toLowerCase();

          // Do not show the submitting client as an extra group participant.
          if (docId == currentUid) continue;
          if (currentEmail.isNotEmpty && email == currentEmail) continue;

          final name = _firstNonEmpty([
            data['panel_display_name'],
            data['panel_name'],
            data['display_name'],
            data['displayName'],
            data['full_name'],
            data['name'],
            profile['name'],
            profile['displayName'],
            basic['name'],
            basic['displayName'],
            client['name'],
            client['displayName'],
            clientProfile['name'],
            email.contains('@') ? email.split('@').first : '',
          ]).trim();

          if (name.isEmpty && email.isEmpty) continue;

          final displayName = name.isNotEmpty ? name : email;

          final draft = ClientProfileDraft(
            basic: BasicInfo(
              name: displayName,
              email: email,
              phone: _firstNonEmpty([
                data['panel_phone'],
                data['phone_number'],
                data['phone'],
                profile['phone'],
                basic['phone'],
                client['phone'],
              ]),
            ),
            address: AddressInfo(
              street: _firstNonEmpty([
                address['street'],
                address['billingStreet'],
                address['shippingStreet'],
                data['street'],
              ]),
              city: _firstNonEmpty([
                address['city'],
                address['billingCity'],
                address['shippingCity'],
                data['city'],
              ]),
              state: _firstNonEmpty([
                address['state'],
                address['billingState'],
                address['shippingState'],
                data['state'],
              ]),
              zip: _firstNonEmpty([
                address['zip'],
                address['postal_code'],
                address['billingZip'],
                address['shippingZip'],
                data['zip'],
              ]),
              country: _firstNonEmpty([
                address['country'],
                address['billingCountry'],
                address['shippingCountry'],
                data['country'],
                'United States',
              ]),
            ),
            payment: const PaymentInfo(
              method: PaymentMethod.applePay,
              saveForFuture: false,
            ),
            nail: NailPreferences(
              dimensions: _parseNailDimensions(dims),
              shape: _firstNonEmpty([
                nail['shape'],
                nail['nailShape'],
                data['nail_shape'],
                data['nailShape'],
              ]),
              length: _parseNailLength(
                _firstNonEmpty([
                  nail['length'],
                  nail['nailLength'],
                  data['nail_length'],
                  data['nailLength'],
                ]),
              ),
            ),
          );

          // Deduplicate by email first, then id. This prevents duplicates when
          // the same person exists in both client and clients.
          final key = email.isNotEmpty ? email : docId;
          byKey[key] = CompletedClient(
            id: docId,
            name: displayName,
            profile: draft,
          );
        }
      }

      final loaded = byKey.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;

      setState(() {
        _completedClients = loaded;

        for (final slot in _groupSelections) {
          if (slot.clientId == null) continue;

          final exists = _completedClients.any((c) => c.id == slot.clientId);

          if (!exists) {
            slot.clientId = null;
            slot.searchController.text = '';
            slot.draftNails = null;
            slot.savedNails = null;
          } else {
            final matched = _findClient(slot.clientId);
            if (matched != null) {
              slot.searchController.text = matched.name;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('[ClientCustomRequestPage] load completed clients failed: $e');
      if (!mounted) return;
      setState(() => _completedClients = <CompletedClient>[]);
    } finally {
      if (mounted) setState(() => _loadingCompletedClients = false);
    }
  }

  Map<String, dynamic> _firstMap(List<Object?> values) {
    for (final value in values) {
      final map = _asStringMap(value);
      if (map.isNotEmpty) return map;
    }
    return const <String, dynamic>{};
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _descCtrl.dispose();
    _shipStreetCtrl.dispose();
    _shipCityCtrl.dispose();
    _shipZipCtrl.dispose();
    _shipStateCtrl.dispose();
    _needByFocusNode.dispose();
    _descriptionFocusNode.dispose();
    for (final slot in _groupSelections) {
      slot.dispose();
    }
    _notificationsFocusNode.dispose();
    super.dispose();
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
    if (value == 'reviews') {
      if (widget.onOpenReviews != null) {
        widget.onOpenReviews?.call();
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ArtistReviewsPage()));
      }
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final minDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 4));
    final initialDate = _needBy != null && !_needBy!.isBefore(minDate)
        ? _needBy!
        : minDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Select need by date',
        child: Dialog(
          backgroundColor: _requestSnow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Container(
            color: _requestSnow,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330, maxHeight: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.blackCat,
                      onPrimary: _requestSnow,
                      surface: _requestSnow,
                      onSurface: AppColors.blackCat,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: minDate,
                    lastDate: now.add(const Duration(days: 365)),
                    onDateChanged: (picked) {
                      setState(() {
                        _needBy = picked;
                        _dateCtrl.text =
                            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                        _fieldErrors.remove('needBy');
                      });
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ? Save budget to DB on slider release (implement your Firestore code here)
  Future<void> _saveBudgetToDb(RangeValues v) async {}

  CompletedClient? _findClient(String? id) {
    if (id == null) return null;
    try {
      return _completedClients.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<CompletedClient> _searchCompletedClients(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _completedClients.where((c) => !_isSubmittingClient(c)).toList();
    }
    return _completedClients
        .where((c) => !_isSubmittingClient(c))
        .where((c) => c.name.toLowerCase().contains(normalized))
        .toList();
  }

  bool _isSubmittingClient(CompletedClient client) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUid = (currentUser?.id ?? '').trim();
    final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
    final profileEmail = widget.profile.basic.email.trim().toLowerCase();
    final profileName = widget.profile.basic.name.trim().toLowerCase();
    final candidateEmail = client.profile.basic.email.trim().toLowerCase();
    final candidateName = client.name.trim().toLowerCase();

    if (currentUid.isNotEmpty && client.id.trim() == currentUid) return true;
    if (profileName.isNotEmpty && candidateName == profileName) return true;
    if (candidateEmail.isEmpty) return false;
    if (currentEmail.isNotEmpty && candidateEmail == currentEmail) return true;
    if (profileEmail.isNotEmpty && candidateEmail == profileEmail) return true;
    return false;
  }

  Future<void> _showSubmittingClientSelectionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selection not allowed'),
          content: const Text(
            'The main client submitting this request cannot be added to the group order list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _isClientSavedInAnotherSlot({
    required int currentIndex,
    required String clientId,
  }) {
    final normalized = clientId.trim();
    if (normalized.isEmpty) return false;
    for (var i = 0; i < _groupSelections.length; i++) {
      if (i == currentIndex) continue;
      final other = _groupSelections[i];
      if ((other.clientId ?? '').trim() == normalized &&
          other.savedNails != null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showDuplicateClientDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.snow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'Client already added',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This client is already saved in the group order. Please select a different client.',
            style: TextStyle(fontSize: 11.5, height: 1.35),
          ),
          actions: [
            SizedBox(
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addClientSlot() {
    if (_groupSelections.length >= _maxGroupClients) return;
    setState(() => _groupSelections.add(GroupClientSelection()));
  }

  void _removeClientSlot(int index) {
    final removed = _groupSelections.removeAt(index);
    final removedNfcCount = removed.draftNails == null
        ? 0
        : _nfcSelectedCount(removed.draftNails!.dimensions);
    removed.dispose();
    setState(() {
      _applyNfcBudgetDelta(oldCount: removedNfcCount, newCount: 0);
    });
  }

  Future<void> _onSelectClientForSlot(int index, String? clientId) async {
    final client = _findClient(clientId);
    if (client != null && _isSubmittingClient(client)) {
      await _showSubmittingClientSelectionDialog();
      if (!mounted) return;
      setState(() {
        _groupSelections[index].clientId = null;
        _groupSelections[index].showSuggestions = false;
        _groupSelections[index].searchController.text = '';
        _groupSelections[index].draftNails = null;
        _groupSelections[index].savedNails = null;
      });
      return;
    }
    if (clientId != null &&
        _isClientSavedInAnotherSlot(currentIndex: index, clientId: clientId)) {
      await _showDuplicateClientDialog();
      if (!mounted) return;
      setState(() {
        final existing = _findClient(_groupSelections[index].clientId);
        _groupSelections[index].searchController.text = existing?.name ?? '';
        _groupSelections[index].showSuggestions = false;
      });
      return;
    }

    setState(() {
      _groupSelections[index].clientId = clientId;
      _groupSelections[index].showSuggestions = false;

      final oldNfcCount = _groupSelections[index].draftNails == null
          ? 0
          : _nfcSelectedCount(_groupSelections[index].draftNails!.dimensions);

      if (client != null) {
        _groupSelections[index].searchController.text = client.name;
        final p = client.profile.nail;

        final shape = (p.shape.isNotEmpty)
            ? p.shape
            : (nailShapes.isNotEmpty ? nailShapes.first : 'Square');
        final length = (p.length == NailLength.none)
            ? NailLength.medium
            : p.length;

        _groupSelections[index].draftNails = NailPreferences(
          dimensions: p.dimensions,
          shape: shape,
          length: length,
        );
        _groupSelections[index].savedNails = null;
      } else {
        _groupSelections[index].searchController.text = '';
        _groupSelections[index].draftNails = null;
        _groupSelections[index].savedNails = null;
      }

      final newNfcCount = _groupSelections[index].draftNails == null
          ? 0
          : _nfcSelectedCount(_groupSelections[index].draftNails!.dimensions);
      _applyNfcBudgetDelta(oldCount: oldNfcCount, newCount: newNfcCount);
    });
  }

  Future<void> _saveSlot(int index) async {
    final slot = _groupSelections[index];
    final draft = slot.draftNails;

    if (draft == null || !draft.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Nail Dimensions, Shape, and Length for this client.',
          ),
        ),
      );
      return;
    }

    final selectedId = (slot.clientId ?? '').trim();
    if (selectedId.isNotEmpty &&
        _isClientSavedInAnotherSlot(
          currentIndex: index,
          clientId: selectedId,
        )) {
      await _showDuplicateClientDialog();
      return;
    }

    setState(() => slot.savedNails = draft);
  }

  Map<String, dynamic> _nailDimensionsToMap(NailDimensions d) {
    return {
      'lThumb': d.lThumb,
      'lIndex': d.lIndex,
      'lMiddle': d.lMiddle,
      'lRing': d.lRing,
      'lPinky': d.lPinky,
      'rThumb': d.rThumb,
      'rIndex': d.rIndex,
      'rMiddle': d.rMiddle,
      'rRing': d.rRing,
      'rPinky': d.rPinky,
      'lThumbNfc': d.lThumbNfc,
      'lIndexNfc': d.lIndexNfc,
      'lMiddleNfc': d.lMiddleNfc,
      'lRingNfc': d.lRingNfc,
      'lPinkyNfc': d.lPinkyNfc,
      'rThumbNfc': d.rThumbNfc,
      'rIndexNfc': d.rIndexNfc,
      'rMiddleNfc': d.rMiddleNfc,
      'rRingNfc': d.rRingNfc,
      'rPinkyNfc': d.rPinkyNfc,
      'nfc': <String, bool>{
        'lThumb': d.lThumbNfc,
        'lIndex': d.lIndexNfc,
        'lMiddle': d.lMiddleNfc,
        'lRing': d.lRingNfc,
        'lPinky': d.lPinkyNfc,
        'rThumb': d.rThumbNfc,
        'rIndex': d.rIndexNfc,
        'rMiddle': d.rMiddleNfc,
        'rRing': d.rRingNfc,
        'rPinky': d.rPinkyNfc,
      },
    };
  }

  Future<void> _pickFromGallery() async {
    try {
      final remainingSlots = _maxInspirationPhotos - _inspirationPhotos.length;
      if (remainingSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can upload up to 10 inspiration photos.'),
          ),
        );
        return;
      }
      final picked = await _picker.pickMultiImage(
        imageQuality: 35,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (!mounted) return;
      if (picked.isEmpty) return;

      final accepted = <XFile>[];
      final acceptedBytes = <String, Uint8List>{};
      var rejectedCount = 0;
      for (final file in picked) {
        final size = await file.length();
        if (size > _maxImageSizeBytes) {
          rejectedCount++;
          continue;
        }
        try {
          final bytes = await file.readAsBytes();
          acceptedBytes[file.path] = _normalizeImageBytes(bytes);
        } catch (_) {}
        accepted.add(file);
      }
      if (!mounted) return;
      if (accepted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file is larger than 2 MB.')),
        );
        return;
      }
      final acceptedToAdd = accepted
          .take(remainingSlots)
          .toList(growable: false);
      setState(() {
        for (final file in acceptedToAdd) {
          _inspirationPhotos.add(file.path);
          _pickedPhotoFiles[file.path] = file;
          final bytes = acceptedBytes[file.path];
          if (bytes != null && bytes.isNotEmpty) {
            _pickedPhotoBytes[file.path] = bytes;
          }
        }
        _fieldErrors.remove('inspirationPhotos');
      });
      if ((rejectedCount > 0 || accepted.length > acceptedToAdd.length) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some files were skipped (over 2 MB or more than 10 photos).',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add image from gallery on this device.'),
        ),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      if (_inspirationPhotos.length >= _maxInspirationPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can upload up to 10 inspiration photos.'),
          ),
        );
        return;
      }
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 35,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;
      final size = await picked.length();
      if (size > _maxImageSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File is larger than 2 MB. Please choose a smaller image.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _inspirationPhotos.add(picked.path);
        _pickedPhotoFiles[picked.path] = picked;
        // Capture immediate preview bytes so the submitted request can carry
        // a temporary renderable fallback while uploads complete.
        _pickedPhotoBytes.remove(picked.path);
        _fieldErrors.remove('inspirationPhotos');
      });
      final bytes = await picked.readAsBytes().timeout(
        const Duration(seconds: 30),
      );
      if (!mounted) return;
      final normalized = _normalizeImageBytes(bytes);
      if (normalized.isNotEmpty && mounted) {
        setState(() {
          _pickedPhotoBytes[picked.path] = normalized;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to capture photo on this device.'),
        ),
      );
    }
  }

  void _removeInspirationPhoto(String path) {
    setState(() {
      _inspirationPhotos.remove(path);
      _pickedPhotoFiles.remove(path);
      _pickedPhotoBytes.remove(path);
    });
  }

  Uint8List _normalizeImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final width = decoded.width;
      final height = decoded.height;
      const maxSide = 1024;

      img.Image output = decoded;
      if (width > maxSide || height > maxSide) {
        if (width >= height) {
          output = img.copyResize(
            decoded,
            width: maxSide,
            maintainAspect: true,
            interpolation: img.Interpolation.linear,
          );
        } else {
          output = img.copyResize(
            decoded,
            height: maxSide,
            maintainAspect: true,
            interpolation: img.Interpolation.linear,
          );
        }
      }
      final encoded = img.encodeJpg(output, quality: 68);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  /*Future<void> _snapshotPickedPhotoBytes() async {
    for (final entry in _pickedPhotoFiles.entries) {
      if (_pickedPhotoBytes.containsKey(entry.key)) continue;
      try {
        final bytes = await entry.value.readAsBytes().timeout(
          const Duration(seconds: 30),
        );
        _pickedPhotoBytes[entry.key] = _normalizeImageBytes(bytes);
      } catch (e) {
        debugPrint(
          '[PhotoUpload] snapshot bytes failed for ${entry.value.name}: $e',
        );
      }
    }
  }*/

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  bool _isUrl(String p) => p.startsWith('http://') || p.startsWith('https://');
  bool _isStoragePath(String p) =>
      p.startsWith('gs://') ||
      p.startsWith('client_custom_requests/') ||
      p.startsWith('brand_custom_requests/') ||
      p.startsWith('artist_custom_requests/');

  ImageProvider _imageProviderFor(String path) {
    final p = path.trim();
    final cachedBytes = _pickedPhotoBytes[p];
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return MemoryImage(cachedBytes);
    }

    if (_isUrl(p)) return NetworkImage(p);
    if (p.startsWith('data:')) return NetworkImage(p);
    if (p.startsWith('assets/')) return AssetImage(p);
    if (kIsWeb) return NetworkImage(p);

    // Mobile-safe thumbnail preview.
    return ResizeImage(FileImage(File(p)), width: 300, height: 300);
  }

  Widget _previewImage(String path) {
    final p = path.trim();
    if (p.isEmpty) return _photoFallback(path);
    if (_isStoragePath(p)) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) => v ?? ''),
        builder: (context, snapshot) {
          final resolved = snapshot.data?.trim() ?? '';
          if (resolved.isEmpty) return _photoFallback(path);
          return Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _photoFallback(path),
          );
        },
      );
    }
    return Image(
      image: _imageProviderFor(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _photoFallback(path),
    );
  }

  bool _isStableRemoteImage(String path) {
    return path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:');
  }

  List<String> _buildInitialInspirationPhotos() {
    final photos = <String>[];
    final seen = <String>{};
    var dataUriBudget = 650000;

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) return;
      photos.add(trimmed);
    }

    for (final raw in _inspirationPhotos) {
      if (_isStableRemoteImage(raw)) {
        add(raw);
      }
    }

    for (final raw in _inspirationPhotos) {
      if (_isStableRemoteImage(raw)) continue;
      final bytes = _pickedPhotoBytes[raw];
      if (bytes == null || bytes.isEmpty) continue;
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (dataUri.length > dataUriBudget) continue;
      add(dataUri);
      dataUriBudget -= dataUri.length;
    }

    return photos;
  }

  Future<List<String>> _uploadInspirationPhotos({
    required List<String> inspirationPhotos,
    required Map<String, XFile> pickedPhotoFiles,
    required Map<String, Uint8List> pickedPhotoBytes,
  }) async {
    if (inspirationPhotos.isEmpty) return const <String>[];

    final supabase = Supabase.instance.client;
    final userKey = _safeRequestStorageKey(
      Supabase.instance.client.auth.currentUser?.id ??
          widget.profile.basic.email,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];

    for (var i = 0; i < inspirationPhotos.length && urls.length < 10; i++) {
      final raw = inspirationPhotos[i].trim();
      if (raw.isEmpty) continue;

      if (_isStableRemoteImage(raw)) {
        urls.add(raw);
        continue;
      }

      final file = pickedPhotoFiles[raw];
      if (file == null) continue;

      try {
        final bytes =
            pickedPhotoBytes[raw] ??
            _normalizeImageBytes(
              await file.readAsBytes().timeout(const Duration(seconds: 30)),
            );

        if (bytes.isEmpty) {
          throw Exception('Image bytes are empty for ${file.name}');
        }

        final path = 'clients/$userKey/requests/$now/inspiration_$i.jpg';

        await supabase.storage
            .from('request-inspiration-photos')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            )
            .timeout(const Duration(seconds: 60));

        final uploadedUrl = supabase.storage
            .from('request-inspiration-photos')
            .getPublicUrl(path)
            .trim();

        debugPrint('SUPABASE REQUEST INSPIRATION URL = $uploadedUrl');

        if (uploadedUrl.isNotEmpty) {
          urls.add(uploadedUrl);
        }
      } catch (e) {
        debugPrint('[SupabasePhotoUpload] failed for ${file.name}: $e');
      }
    }

    return urls
        .where((e) => e.trim().isNotEmpty)
        .take(10)
        .toList(growable: false);
  }

  Map<String, dynamic> _nailPreferencesToMap(NailPreferences p) {
    return {
      'shape': p.shape,
      'length': p.length.name,
      'dimensions': _nailDimensionsToMap(p.dimensions),
      'isComplete': p.isComplete,
    };
  }

  Map<String, dynamic> _profileSnapshotToMap(ClientProfileDraft p) {
    return {
      'basic': {
        'name': p.basic.name,
        'email': p.basic.email,
        'phone': p.basic.phone,
        'profileImageUrl': p.basic.profileImageUrl,
      },
      'address': {
        'street': p.address.street,
        'city': p.address.city,
        'state': p.address.state,
        'zip': p.address.zip,
        'country': p.address.country,
      },
      'nailPreferences': _nailPreferencesToMap(p.nail),
      'isProfileComplete': p.isComplete,
    };
  }

  List<Map<String, dynamic>> _groupSelectionsToMap() {
    return _groupSelections.asMap().entries.map((entry) {
      final index = entry.key;
      final slot = entry.value;
      final selectedClient = _findClient(slot.clientId);
      return {
        'slotIndex': index + 1,
        'clientId': slot.clientId ?? '',
        'clientName': selectedClient?.name ?? '',
        'draftNails': slot.draftNails == null
            ? null
            : _nailPreferencesToMap(slot.draftNails!),
        'savedNails': slot.savedNails == null
            ? null
            : _nailPreferencesToMap(slot.savedNails!),
      };
    }).toList();
  }

  void _goHomeAfterSubmit() {
    if (widget.onNavTap != null) {
      widget.onNavTap!(0);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _resetFormAfterSubmit() {
    _dateCtrl.clear();
    _descCtrl.clear();
    _needBy = null;
    _inspirationPhotos.clear();
    _pickedPhotoFiles.clear();
    _pickedPhotoBytes.clear();
    _allowNonLicensed = true;
    _budget = const RangeValues(15, 500);
    _orderType = OrderType.single;
    _selectedArtist = widget.initialArtistName?.trim();
    _fallbackToPool = true;
    _shippingDifferent = false;
    _shipStreetCtrl.clear();
    _shipCityCtrl.clear();
    _shipZipCtrl.clear();
    _shipState = '';
    _shipStateCtrl.clear();
    _shipCountry = 'United States';
    _fieldErrors.clear();
    _groupSelections.clear();
  }

  void _applyInitialRequestData() {
    final data = widget.initialRequestData;
    if (data == null || data.isEmpty) return;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return const <String, dynamic>{};
    }

    final requestDetails = asMap(data['requestDetails']);
    final budget = asMap(data['budget']);
    final order = asMap(data['order']);
    final shipping = asMap(data['shipping']);
    final groupOrder = asMap(data['groupOrder']);
    final nailPreferences = asMap(data['nailPreferences']);

    final needByDisplay =
        ((requestDetails['needByDisplay'] ?? data['needByDisplay']) as String?)
            ?.trim() ??
        '';
    if (needByDisplay.isNotEmpty) {
      _dateCtrl.text = needByDisplay;
    }

    final needByTs = requestDetails['needBy'] ?? data['needBy'];
    if (needByTs is DateTime) {
      _needBy = needByTs;
    } else if (needByTs is String) {
      _needBy = DateTime.tryParse(needByTs);
    } else {
      try {
        final maybeDate = (needByTs as dynamic).toDate();
        if (maybeDate is DateTime) {
          _needBy = maybeDate;
        }
      } catch (_) {}
    }

    final description =
        ((requestDetails['description'] ??
                    data['description'] ??
                    data['descriptionPreview'])
                as String?)
            ?.trim() ??
        '';
    if (description.isNotEmpty) {
      _descCtrl.text = description;
    }

    final min = ((budget['min'] ?? data['budgetMin']) as num?)?.toDouble();
    final max = ((budget['max'] ?? data['budgetMax']) as num?)?.toDouble();
    if (min != null && max != null) {
      _budget = _sanitizeBudgetRange(RangeValues(min, max));
    }

    final orderTypeRaw = ((order['type'] ?? data['orderType']) as String?)
        ?.trim()
        .toLowerCase();
    _orderType = orderTypeRaw == 'group' ? OrderType.group : OrderType.single;
    _allowNonLicensed =
        (order['allowNonLicensed'] as bool?) ??
        (data['allowNonLicensed'] as bool?) ??
        _allowNonLicensed;
    final selectedArtistRaw =
        (order['selectedArtist'] ?? data['selectedArtist'])?.toString().trim();
    _selectedArtist =
        (selectedArtistRaw != null && selectedArtistRaw.isNotEmpty)
        ? selectedArtistRaw
        : _selectedArtist;
    _fallbackToPool =
        (order['fallbackToPool'] as bool?) ??
        (data['fallbackToPool'] as bool?) ??
        _fallbackToPool;

    final photos = (data['inspirationPhotos'] as List<dynamic>?) ?? const [];
    _inspirationPhotos
      ..clear()
      ..addAll(photos.whereType<String>().where((p) => p.trim().isNotEmpty));

    final shape = _normalizeShapeValue(nailPreferences['shape']);
    if (shape.isNotEmpty) _shape = shape;
    _length = _normalizeLengthValue(
      nailPreferences['length'],
      fallback: _length,
    );
    final dimsFromRequest = _nailDimensionsFromMap(
      nailPreferences['dimensions'] as Map<String, dynamic>?,
    );
    final apiNail = asMap(data['apiNailMeasurements']);
    final apiDims = _nailDimensionsFromMap(
      asMap(apiNail['dimensions']).isEmpty
          ? null
          : asMap(apiNail['dimensions']),
    );
    final resolvedDims = _pickBestDimensions(<NailDimensions?>[
      dimsFromRequest,
      apiDims,
      _singleNailPrefs.dimensions,
      widget.profile.nail.dimensions,
    ]);
    _singleNailPrefs = NailPreferences(
      dimensions: resolvedDims,
      shape: _shape,
      length: _length,
    );

    _shippingDifferent =
        (shipping['isDifferentFromProfile'] as bool?) ?? _shippingDifferent;
    _shipStreetCtrl.text = (shipping['street'] as String?)?.trim() ?? '';
    _shipCityCtrl.text = (shipping['city'] as String?)?.trim() ?? '';
    _shipState = (shipping['state'] as String?)?.trim() ?? '';
    _shipStateCtrl.text = _shipState;
    _shipZipCtrl.text = (shipping['zip'] as String?)?.trim() ?? '';
    final shippingCountryRaw = shipping['country']?.toString().trim();
    _shipCountry = (shippingCountryRaw != null && shippingCountryRaw.isNotEmpty)
        ? shippingCountryRaw
        : _shipCountry;

    _groupSelections.clear();
    if (_orderType == OrderType.group) {
      final clients =
          (groupOrder['clients'] as List<dynamic>?) ??
          (order['clients'] as List<dynamic>?) ??
          (data['groupClients'] as List<dynamic>?) ??
          const [];
      for (final item in clients) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final rawClientId = (map['clientId'] as String?)?.trim();
        final clientId = rawClientId?.isEmpty == true ? null : rawClientId;
        final savedNails = _nailPreferencesFromMap(asMap(map['savedNails']));
        final draftNails = _nailPreferencesFromMap(asMap(map['draftNails']));
        final slot = GroupClientSelection(
          clientId: clientId,
          draftNails: draftNails ?? savedNails,
          savedNails: savedNails,
        );
        final clientName = (map['clientName'] as String?)?.trim() ?? '';
        if (clientName.isNotEmpty) {
          slot.searchController.text = clientName;
        }
        _groupSelections.add(slot);
      }
    }
  }

  NailPreferences? _nailPreferencesFromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final shape = _normalizeShapeValue(map['shape']);
    final dims = _nailDimensionsFromMap(
      map['dimensions'] as Map<String, dynamic>?,
    );
    if (shape.isEmpty || dims == null) return null;
    final length = _normalizeLengthValue(
      map['length'],
      fallback: NailLength.none,
    );
    return NailPreferences(dimensions: dims, shape: shape, length: length);
  }

  NailDimensions? _nailDimensionsFromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    double? d(dynamic v) {
      if (v is num) {
        final n = v.toDouble();
        return n.isFinite ? n : null;
      }
      if (v is String) {
        final cleaned = v.trim().replaceAll(
          RegExp(r'\s*mm$', caseSensitive: false),
          '',
        );
        final n = double.tryParse(cleaned);
        if (n == null || !n.isFinite) return null;
        return n;
      }
      return null;
    }

    final parsed = NailDimensions(
      lThumb: d(map['lThumb']),
      lIndex: d(map['lIndex']),
      lMiddle: d(map['lMiddle']),
      lRing: d(map['lRing']),
      lPinky: d(map['lPinky']),
      rThumb: d(map['rThumb']),
      rIndex: d(map['rIndex']),
      rMiddle: d(map['rMiddle']),
      rRing: d(map['rRing']),
      rPinky: d(map['rPinky']),
      lThumbNfc: _asBool(_nfcValue(map, 'lThumb')),
      lIndexNfc: _asBool(_nfcValue(map, 'lIndex')),
      lMiddleNfc: _asBool(_nfcValue(map, 'lMiddle')),
      lRingNfc: _asBool(_nfcValue(map, 'lRing')),
      lPinkyNfc: _asBool(_nfcValue(map, 'lPinky')),
      rThumbNfc: _asBool(_nfcValue(map, 'rThumb')),
      rIndexNfc: _asBool(_nfcValue(map, 'rIndex')),
      rMiddleNfc: _asBool(_nfcValue(map, 'rMiddle')),
      rRingNfc: _asBool(_nfcValue(map, 'rRing')),
      rPinkyNfc: _asBool(_nfcValue(map, 'rPinky')),
    );
    if (!_hasAnyMeasurement(parsed)) return null;
    return parsed;
  }

  bool _hasAnyMeasurement(NailDimensions dims) {
    final values = <double?>[
      dims.lThumb,
      dims.lIndex,
      dims.lMiddle,
      dims.lRing,
      dims.lPinky,
      dims.rThumb,
      dims.rIndex,
      dims.rMiddle,
      dims.rRing,
      dims.rPinky,
    ];
    return values.any((v) => v != null && v > 0);
  }

  String _normalizeShapeValue(Object? raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '';
    for (final shape in nailShapes) {
      if (shape.toLowerCase() == text.toLowerCase()) return shape;
    }
    return text;
  }

  NailLength _normalizeLengthValue(
    Object? raw, {
    required NailLength fallback,
  }) {
    final text = (raw ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    for (final length in NailLength.values) {
      if (length.name.toLowerCase() == text) return length;
    }
    if (text == 'extra short' || text == 'xllong' || text == 'xl long') {
      return NailLength.xlLong;
    }
    if (text == 'extra long' || text == 'extralong') {
      return NailLength.extraLong;
    }
    return fallback;
  }

  NailDimensions _pickBestDimensions(List<NailDimensions?> candidates) {
    for (final dims in candidates) {
      if (dims != null && _hasAllValidMeasurements(dims)) return dims;
    }
    for (final dims in candidates) {
      if (dims != null && _hasAnyMeasurement(dims)) return dims;
    }
    return widget.profile.nail.dimensions;
  }

  DateTime? _resolveNeedByDate() {
    if (_needBy != null) return _needBy;
    final raw = _dateCtrl.text.trim();
    if (raw.isEmpty) return null;
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _formatNeedByForA11y(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day} ${date.year}';
  }

  String _needBySemanticLabel() {
    final trimmed = _dateCtrl.text.trim();
    if (trimmed.isEmpty) {
      return 'Need By Date, required, MM slash DD slash YYYY';
    }
    final resolved = _resolveNeedByDate();
    if (resolved == null) {
      return 'Need By Date, required, selected $trimmed';
    }
    return 'Need By Date, required, selected ${_formatNeedByForA11y(resolved)}';
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final needByDate = _resolveNeedByDate();
    final needByOk = needByDate != null;
    final descOk = _descCtrl.text.trim().isNotEmpty;
    final inspoOk = _inspirationPhotos.any((p) => p.trim().isNotEmpty);
    final shapeOk = _shape.trim().isNotEmpty;
    final lengthOk = _length != NailLength.none;

    bool shipOk = true;
    if (_shippingDifferent) {
      final shipCountry = _shipCountry.trim();
      final isUs = shipCountry.toLowerCase() == 'united states';
      shipOk =
          _shipStreetCtrl.text.trim().isNotEmpty &&
          _shipCityCtrl.text.trim().isNotEmpty &&
          shipCountry.isNotEmpty &&
          (!isUs || _shipState.trim().isNotEmpty) &&
          (!isUs || _shipZipCtrl.text.trim().isNotEmpty);
    }

    if (!needByOk) {
      setState(() {
        _isSubmitting = false;
        _fieldErrors
          ..clear()
          ..['needBy'] = 'Need By Date is required';
      });
      _needByFocusNode.requestFocus();
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Need By Date is required',
        Directionality.of(context),
      );
      return;
    }
    if (!descOk) {
      setState(() {
        _isSubmitting = false;
        _fieldErrors
          ..clear()
          ..['description'] = 'Description is required';
      });
      _descriptionFocusNode.requestFocus();
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Description is required',
        Directionality.of(context),
      );
      return;
    }
    if (!shipOk || !inspoOk || !shapeOk || !lengthOk) {
      final errors = <String, String>{};
      if (!inspoOk) {
        errors['inspirationPhotos'] = 'Inspiration Photos is required';
      }
      if (!shapeOk) errors['shape'] = 'Nail Shape is required';
      if (!lengthOk) errors['length'] = 'Nail Length is required';
      if (_shippingDifferent) {
        final shipCountry = _shipCountry.trim();
        final isUs = shipCountry.toLowerCase() == 'united states';
        if (_shipStreetCtrl.text.trim().isEmpty) {
          errors['shipStreet'] = 'Shipping Street is required';
        }
        if (_shipCityCtrl.text.trim().isEmpty) {
          errors['shipCity'] = 'Shipping City is required';
        }
        if (shipCountry.isEmpty) {
          errors['shipCountry'] = 'Shipping Country is required';
        }
        if (isUs && _shipState.trim().isEmpty) {
          errors['shipState'] = 'Shipping State is required';
        }
        if (isUs && _shipZipCtrl.text.trim().isEmpty) {
          errors['shipZip'] = 'Shipping Zip is required';
        }
      }
      setState(() {
        _isSubmitting = false;
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    setState(() => _fieldErrors.clear());

    if (_orderType == OrderType.group) {
      if (_groupSelections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least 1 client for a group order.'),
          ),
        );
        return;
      }

      for (final slot in _groupSelections) {
        if (slot.clientId == null || slot.savedNails == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please select and save nail preferences for all clients.',
              ),
            ),
          );
          return;
        }
      }
    }

    final profile = widget.profile;
    final selectedNails = NailPreferences(
      dimensions: _singleNailPrefs.dimensions,
      shape: _shape,
      length: _length,
    );
    final now = DateTime.now();

    final needBy = needByDate.toIso8601String();
    final description = _descCtrl.text.trim();
    final budgetMin = _budget.start.round();
    final budgetMax = _budget.end.round();
    final selectedArtist = _selectedArtist ?? '';
    final selectedArtistEmail = await _resolveSelectedArtistEmail(
      selectedArtist,
    );
    final isDirectRequest = selectedArtist.trim().isNotEmpty;
    final groupClients = _groupSelectionsToMap();
    final isGroupOrder = _orderType == OrderType.group;
    final nfcEligible = _requestHasNfcEligibleNail(mainNails: selectedNails);
    final nfcSelected = _requestHasSelectedNfc(mainNails: selectedNails);
    final nfcRequested = nfcEligible && nfcSelected;
    final nfcCount = nfcRequested
        ? _totalSelectedNfcCount(mainNails: selectedNails)
        : 0;
    final requestSummary = <String, dynamic>{
      'requestType': 'clientCustomRequest',
      'status': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'in_review',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'clientSubmittedAtLocal': now.toIso8601String(),
      'needBy': needBy,
      'needByDisplay': _dateCtrl.text.trim(),
      'descriptionPreview': description.length > 140
          ? '${description.substring(0, 140)}...'
          : description,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'nfcEligible': nfcEligible,
      'eligibleForNfc': nfcEligible,
      'nfcRequested': nfcRequested,
      'nfcSelected': nfcRequested,
      'hasNfc': nfcRequested,
      'nfcCount': nfcCount,
      'orderType': _orderType.name,
      'selectedArtist': selectedArtist,
      'selectedArtistEmail': selectedArtistEmail,
      'isDirectRequest': isDirectRequest,
      'allowNonLicensed': _allowNonLicensed,
      'fallbackToPool': _fallbackToPool,
      'openToArtistPool': !isDirectRequest,
      'directArtistStatus': isDirectRequest ? 'in_review' : '',
      'artistPoolStatus': isDirectRequest ? 'locked' : 'in_review',
      'nailShape': _shape,
      'nailLength': _length.name,
      'isGroupOrder': isGroupOrder,
      'groupClientCount': groupClients.length,
      'photoCount': 0,
      'hasInspirationPhotos': false,
      'clientName': profile.basic.name,
      'clientEmail': profile.basic.email,
    };

    final requestDetails = <String, dynamic>{
      'requestDetails': {
        'needBy': needBy,
        'needByDisplay': _dateCtrl.text.trim(),
        'description': description,
      },
      'budget': {'min': budgetMin, 'max': budgetMax},
      'nfc': {
        'eligible': nfcEligible,
        'requested': nfcRequested,
        'count': nfcCount,
      },
      'nfcEligible': nfcEligible,
      'eligibleForNfc': nfcEligible,
      'nfcRequested': nfcRequested,
      'nfcSelected': nfcRequested,
      'hasNfc': nfcRequested,
      'nfcCount': nfcCount,
      'order': {
        'type': _orderType.name,
        'allowNonLicensed': _allowNonLicensed,
        'selectedArtist': selectedArtist,
        'selectedArtistEmail': selectedArtistEmail,
        'isDirectRequest': isDirectRequest,
        'fallbackToPool': _fallbackToPool,
        'openToArtistPool': !isDirectRequest,
        'directArtistStatus': isDirectRequest ? 'in_review' : '',
        'artistPoolStatus': isDirectRequest ? 'locked' : 'in_review',
      },
      'routing': {
        'openToArtistPool': !isDirectRequest,
        'directArtistStatus': isDirectRequest ? 'in_review' : '',
        'artistPoolStatus': isDirectRequest ? 'locked' : 'in_review',
      },
      'roleStatuses': {'client': 'pending', 'artist': 'in_review'},
      'nailPreferences': _nailPreferencesToMap(selectedNails),
      'shipping': {
        'isDifferentFromProfile': _shippingDifferent,
        'street': _shippingDifferent ? _shipStreetCtrl.text.trim() : '',
        'city': _shippingDifferent ? _shipCityCtrl.text.trim() : '',
        'state': _shippingDifferent ? _shipState.trim() : '',
        'zip': _shippingDifferent ? _shipZipCtrl.text.trim() : '',
        'country': _shippingDifferent ? _shipCountry.trim() : '',
      },
      'groupOrder': {
        'isGroupOrder': isGroupOrder,
        'maxClients': _maxGroupClients,
        'clients': groupClients,
      },
      'inspirationPhotos': const <String>[],
      'clientProfileSnapshot': _profileSnapshotToMap(profile),
    };

    try {
      final initialPhotos = _buildInitialInspirationPhotos();

      requestSummary['photoCount'] = initialPhotos.length;
      requestSummary['hasInspirationPhotos'] = initialPhotos.isNotEmpty;
      requestSummary['inspirationPhotos'] = initialPhotos;
      requestDetails['inspirationPhotos'] = initialPhotos;
      final requestId = await _createSupabaseClientCustomRequest(
        summary: requestSummary,
        details: requestDetails,
      );
      try {
        await NotificationsService.notifyArtistsForNewClientRequest(
          clientName: profile.basic.name,
          isDirectRequest: isDirectRequest,
          selectedArtistEmail: selectedArtistEmail,
          selectedArtistName: selectedArtist,
          orderId: requestId,
          orderNumber: _firstNonEmpty([requestSummary['orderNumber']]),
          sourceCollection: 'Client_Custom_Requests',
          allowNonLicensed: _allowNonLicensed,
        );
      } catch (e) {
        debugPrint('CLIENT CUSTOM REQUEST NOTIFICATION FAILED: $e');
      }

      if (_pickedPhotoFiles.isNotEmpty) {
        final inspirationPhotosSnapshot = List<String>.from(_inspirationPhotos);
        final pickedPhotoFilesSnapshot = Map<String, XFile>.from(
          _pickedPhotoFiles,
        );
        final pickedPhotoBytesSnapshot = <String, Uint8List>{};
        await _updateSupabaseClientCustomRequest(requestId, {
          'photo_upload_status': 'uploading',
          'photo_upload_error': null,
          'photo_upload_attempt': 0,
          'photo_upload_updated_at': DateTime.now().toIso8601String(),
        });
        unawaited(
          Future<void>(() async {
            await _uploadAndAttachPhotosWithRetry(
              requestId,
              inspirationPhotosSnapshot: inspirationPhotosSnapshot,
              pickedPhotoFilesSnapshot: pickedPhotoFilesSnapshot,
              pickedPhotoBytesSnapshot: pickedPhotoBytesSnapshot,
            );
          }),
        );
      }

      if (!mounted) return;
      await _showSubmittedDialog();
      if (!mounted) return;
      setState(_resetFormAfterSubmit);
      _goHomeAfterSubmit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit request: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _uploadAndAttachPhotosWithRetry(
    String requestId, {
    required List<String> inspirationPhotosSnapshot,
    required Map<String, XFile> pickedPhotoFilesSnapshot,
    required Map<String, Uint8List> pickedPhotoBytesSnapshot,
  }) async {
    try {
      await _updateSupabaseClientCustomRequest(requestId, {
        'photo_upload_status': 'uploading',
        'photo_upload_updated_at': DateTime.now().toIso8601String(),
      });

      Object? lastError;

      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          await _updateSupabaseClientCustomRequest(requestId, {
            'photo_upload_attempt': attempt,
            'photo_upload_status': 'uploading',
            'photo_upload_updated_at': DateTime.now().toIso8601String(),
          });

          await _uploadAndAttachPhotos(
            requestId,
            inspirationPhotosSnapshot: inspirationPhotosSnapshot,
            pickedPhotoFilesSnapshot: pickedPhotoFilesSnapshot,
            pickedPhotoBytesSnapshot: pickedPhotoBytesSnapshot,
          );

          await _updateSupabaseClientCustomRequest(requestId, {
            'photo_upload_status': 'completed',
            'photo_upload_error': null,
            'photo_upload_updated_at': DateTime.now().toIso8601String(),
          });
          return;
        } catch (e) {
          lastError = e;
          debugPrint('[SupabasePhotoUpload] attach retry $attempt failed: $e');
          if (attempt < 2) {
            await Future<void>.delayed(const Duration(seconds: 3));
          }
        }
      }

      await _updateSupabaseClientCustomRequest(requestId, {
        'photo_upload_status': 'failed',
        'photo_upload_error':
            'Photo upload failed after retries: ${lastError ?? 'unknown error'}',
        'photo_upload_updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabasePhotoUpload] worker fatal error: $e');
    }
  }

  Future<void> _uploadAndAttachPhotos(
    String requestId, {
    required List<String> inspirationPhotosSnapshot,
    required Map<String, XFile> pickedPhotoFilesSnapshot,
    required Map<String, Uint8List> pickedPhotoBytesSnapshot,
  }) async {
    final existingRemoteCount = inspirationPhotosSnapshot
        .where(_isStableRemoteImage)
        .length;
    final selectedLocalCount = inspirationPhotosSnapshot
        .where((p) => pickedPhotoFilesSnapshot.containsKey(p))
        .length;

    final photos = await _uploadInspirationPhotos(
      inspirationPhotos: inspirationPhotosSnapshot,
      pickedPhotoFiles: pickedPhotoFilesSnapshot,
      pickedPhotoBytes: pickedPhotoBytesSnapshot,
    );

    final uploadedNewCount = (photos.length - existingRemoteCount).clamp(
      0,
      photos.length,
    );

    if (selectedLocalCount > 0 && uploadedNewCount < selectedLocalCount) {
      debugPrint(
        '[SupabasePhotoUpload] partial success: uploaded=$uploadedNewCount, '
        'selected=$selectedLocalCount',
      );
      throw Exception(
        'Only $uploadedNewCount of $selectedLocalCount photos uploaded.',
      );
    }

    final existing = await _readSupabaseClientCustomRequest(requestId);
    final payload = await _readSupabaseClientCustomRequestPayload(requestId);
    final summary = _asStringMap(existing['summary']);
    final details = _asStringMap(payload['details']);
    final requestDetails = _asStringMap(payload['requestDetails']);

    final nextSummary = <String, dynamic>{
      ...summary,
      'photoCount': photos.length,
      'hasInspirationPhotos': photos.isNotEmpty,
      'inspirationPhotos': photos,
    };

    final nextRequestDetails = <String, dynamic>{
      ...requestDetails,
      'inspirationPhotos': photos,
    };

    final nextDetails = <String, dynamic>{
      ...details,
      'inspirationPhotos': photos,
      'requestDetails': nextRequestDetails,
    };

    await _updateSupabaseClientCustomRequest(requestId, {
      'photo_count': photos.length,
      'has_inspiration_photos': photos.isNotEmpty,
      'inspiration_photos': photos,
      'summary': nextSummary,
      'details': nextDetails,
    });

    await _upsertSupabaseClientCustomRequestPayload(requestId, {
      'summary': nextSummary,
      'details': nextDetails,
      'payload': nextDetails,
      'requestDetails': nextRequestDetails,
    });
  }

  Future<void> _showSubmittedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _requestSnow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'Request Submitted',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Thank you for submitting the custom nail request. We will notify you once an artist accepts it.',
            style: TextStyle(fontSize: 11.5, height: 1.35),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.snow,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTheme = Theme.of(context).copyWith(
      canvasColor: _requestSnow,
      colorScheme: Theme.of(
        context,
      ).colorScheme.copyWith(surface: _requestSnow),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(_requestSnow),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: _requestSnow),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _requestSnow,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(minHeight: 52),
      ),
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          toolbarHeight: JntHeaderMetrics.toolbarHeight,
          automaticallyImplyLeading: false,

          leadingWidth: widget.onBackHome != null ? 108 : JntHeaderMetrics.leadingWidth,
          leading: Row(
            children: [
              if (widget.onBackHome != null)
                SizedBox(
                  width: 50,
                  child: IconButton(
                    onPressed: widget.onBackHome,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 22,
                      color: AppColors.blackCat.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              NotificationBellButton(
                onTap: () {
                  NotificationsPage.showAsModal(context);
                },
                focusNode: _notificationsFocusNode,
                iconSize: JntHeaderMetrics.notificationIconSize,
              ),
            ],
          ),

          centerTitle: true,
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.only(right: JntHeaderMetrics.rightPadding),
              child: _AvatarMenu(
                onSelected: _onAvatarMenuSelected,
                avatarUrl: widget.profile.basic.profileImageUrl,
                displayName: widget.profile.basic.name,
                showProfile: widget.showProfileMenu,
                showHistory: widget.showExtendedAvatarMenu,
                showCalendar: widget.showExtendedAvatarMenu,
                showArtist: widget.showExtendedAvatarMenu,
                showReviews: widget.showExtendedAvatarMenu,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Request Custom Design',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'times-new-roman',
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                "Tell artists exactly what you're looking for and get custom proposals.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'Arial',
                ),
              ),
            ),

            const SizedBox(height: 18),

            Semantics(
              header: true,
              sortKey: const OrdinalSortKey(10),
              child: Text(
                'Request Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Arialbold',
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Need By Date *'),
                  const SizedBox(height: 8),
                  Semantics(
                    sortKey: const OrdinalSortKey(11),
                    button: true,
                    label: _needBySemanticLabel(),
                    onTap: _pickDate,
                    child: ExcludeSemantics(
                      child: _FocusRingWrapper(
                        focusNode: _needByFocusNode,
                        ringColor: _focusRing,
                        child: _DateField(
                          controller: _dateCtrl,
                          focusNode: _needByFocusNode,
                          onTap: _pickDate,
                          errorText: _fieldErrors['needBy'],
                          onChanged: (_) => setState(() {
                            _fieldErrors.remove('needBy');
                          }),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: _InlineError(text: _fieldErrors['needBy']),
                  ),

                  const SizedBox(height: 14),
                  _fieldLabel('Description *'),
                  const SizedBox(height: 8),
                  Semantics(
                    textField: true,
                    multiline: true,
                    label: 'Description, required',
                    child: ExcludeSemantics(
                      child: _FocusRingWrapper(
                        focusNode: _descriptionFocusNode,
                        ringColor: _focusRing,
                        child: _TextArea(
                          controller: _descCtrl,
                          focusNode: _descriptionFocusNode,
                          hint: 'Describe your ideal design in detail...',
                          errorText: _fieldErrors['description'],
                          onChanged: (_) => setState(() {
                            _fieldErrors.remove('description');
                          }),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: _InlineError(text: _fieldErrors['description']),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Inspiration Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload photos that inspire your vision.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Arial',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SoftButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    backgroundColor: AppColors.blackCatLight,
                    iconColor: AppColors.snow,
                    textColor: AppColors.snow,
                    onTap: _pickFromGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SoftButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    backgroundColor: AppColors.blackCat,
                    iconColor: AppColors.snow,
                    textColor: AppColors.snow,
                    onTap: _pickFromCamera,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Allowed files: JPG, JPEG, PNG. Recommended size: up to 2 MB per photo.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                fontFamily: 'Arial',
              ),
            ),
            _InlineError(text: _fieldErrors['inspirationPhotos']),

            if (_inspirationPhotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Card(
                child: SizedBox(
                  height: 110,
                  child: Builder(
                    builder: (context) {
                      final photos = List<String>.from(_inspirationPhotos);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < photos.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _previewImage(photos[i]),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _removeInspirationPhoto(photos[i]),
                                        child: Container(
                                          height: 20,
                                          width: 20,
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 0.95,
                  child: Checkbox(
                    value: _allowNonLicensed,
                    onChanged: (v) =>
                        setState(() => _allowNonLicensed = (v ?? true)),
                    activeColor: AppColors.blackCat,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Are you willing to allow non-licensed nail technicians to work on your design?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.blackCat,
                        height: 1.2,
                        fontSize: 14,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Type of Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RadioPill(
                    selected: _orderType == OrderType.single,
                    label: 'Single Order',
                    onTap: () => setState(() => _orderType = OrderType.single),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RadioPill(
                    selected: _orderType == OrderType.group,
                    label: 'Group Order',
                    onTap: () {
                      setState(() => _orderType = OrderType.group);
                      if (_completedClients.isEmpty &&
                          !_loadingCompletedClients) {
                        unawaited(_loadCompletedClientsFromDb());
                      }
                    },
                  ),
                ),
              ],
            ),

            if (_orderType == OrderType.group) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Group Clients (up to 15)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Arialbold',
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.blackCat,
                    ),
                    onPressed:
                        _loadingCompletedClients ||
                            _completedClients.isEmpty ||
                            _groupSelections.length >= _maxGroupClients
                        ? null
                        : _addClientSlot,
                    child: const Text(
                      'Add Client +',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                        fontSize: 14,
                        fontFamily: 'Arialbold',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_loadingCompletedClients)
                _Card(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading clients from database...',
                        style: TextStyle(
                          color: AppColors.blackCat.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ],
                  ),
                )
              else if (_completedClients.isEmpty)
                _Card(
                  child: Text(
                    'No completed client profiles found in database.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      fontFamily: 'Arial',
                    ),
                  ),
                )
              else if (_groupSelections.isEmpty)
                Text(
                  'Add clients to the group order. Only clients with completed profiles appear here.',
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Arial',
                  ),
                ),

              ...List.generate(_groupSelections.length, (i) {
                final slot = _groupSelections[i];
                final selectedClient = _findClient(slot.clientId);
                final draft = slot.draftNails;
                final saved = slot.savedNails != null;
                final suggestions = _searchCompletedClients(
                  slot.searchController.text,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Client ${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: 'Arialbold',
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _removeClientSlot(i),
                              icon: const Icon(Icons.delete_outline, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: slot.searchController,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                          onTap: () {
                            setState(() => slot.showSuggestions = true);
                          },
                          onChanged: (_) {
                            setState(() {
                              slot.showSuggestions = true;
                              final selected = _findClient(slot.clientId);
                              final typed = slot.searchController.text
                                  .trim()
                                  .toLowerCase();
                              if (selected == null ||
                                  typed != selected.name.trim().toLowerCase()) {
                                final oldNfcCount = slot.draftNails == null
                                    ? 0
                                    : _nfcSelectedCount(
                                        slot.draftNails!.dimensions,
                                      );
                                slot.clientId = null;
                                slot.draftNails = null;
                                slot.savedNails = null;
                                _applyNfcBudgetDelta(
                                  oldCount: oldNfcCount,
                                  newCount: 0,
                                );
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Type client name',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Arial',
                              color: AppColors.blackCat.withValues(alpha: 0.35),
                            ),
                            filled: true,
                            fillColor: _requestSnow,
                            focusColor: _requestSnow,
                            hoverColor: _requestSnow,
                            suffixIcon: Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.04,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.04,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.04,
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (slot.showSuggestions) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: _requestSnow,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: AppColors.blackCatBorderLight,
                              ),
                            ),
                            child: suggestions.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      'No matching clients found.',
                                      style: TextStyle(
                                        color: AppColors.blackCat.withValues(
                                          alpha: 0.60,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: suggestions.length,
                                    itemBuilder: (context, idx) {
                                      final c = suggestions[idx];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        onTap: () =>
                                            _onSelectClientForSlot(i, c.id),
                                      );
                                    },
                                  ),
                          ),
                        ],

                        if (selectedClient == null || draft == null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Select a client to view nail dimensions and edit preferences.',
                            style: TextStyle(
                              color: AppColors.blackCat.withValues(alpha: 0.60),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'Arial',
                            ),
                          ),
                        ],

                        if (selectedClient != null && draft != null) ...[
                          const SizedBox(height: 14),
                          NailPreferencesInlineEditor(
                            initial: draft,
                            showMeasurementTips: false,
                            showDimensionImages: false,
                            showNfcOptions: true,
                            nailDimensionBorderColor: AppColors.blackCat
                                .withValues(alpha: 0.25),
                            onChanged: (updated) {
                              setState(() {
                                final oldNfcCount = slot.draftNails == null
                                    ? 0
                                    : _nfcSelectedCount(
                                        slot.draftNails!.dimensions,
                                      );
                                final newNfcCount = _nfcSelectedCount(
                                  updated.dimensions,
                                );
                                slot.draftNails = updated;
                                slot.savedNails = null;
                                _applyNfcBudgetDelta(
                                  oldCount: oldNfcCount,
                                  newCount: newNfcCount,
                                );
                              });
                            },
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: saved
                                    ? AppColors.balletSlippers
                                    : AppColors.blackCat,
                                foregroundColor: saved
                                    ? AppColors.blackCat
                                    : _requestSnow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: () => _saveSlot(i),
                              child: Text(
                                saved ? 'Saved' : 'Save',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 18),

            const Text(
              'Request a Specific Artist',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Artist'),
                  const SizedBox(height: 8),

                  Builder(
                    builder: (context) {
                      final selected = (_selectedArtist ?? '').trim();
                      final options = _dedupeArtistNames(<String>[
                        if (selected.isNotEmpty) selected,
                        ..._artistNames,
                      ]);
                      return _SearchableSelectField(
                        value: selected,
                        hint: 'Select Artist',
                        items: options,
                        onChanged: (v) => setState(
                          () => _selectedArtist = v.trim().isEmpty
                              ? null
                              : v.trim(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'If the artist cannot complete the request, do you want the request to go into the request pool for other artists?',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.blackCat.withValues(alpha: 0.75),
                      height: 1.2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Yes'),
                        selected: _fallbackToPool == true,
                        selectedColor: AppColors.blackCat,
                        backgroundColor: _requestSnow,
                        checkmarkColor: AppColors.snow,
                        onSelected: (_) =>
                            setState(() => _fallbackToPool = true),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: _fallbackToPool == true
                              ? AppColors.snow
                              : AppColors.blackCat,
                        ),
                        side: BorderSide(
                          color: AppColors.blackCat.withValues(alpha: 0.08),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('No'),
                        selected: _fallbackToPool == false,
                        selectedColor: AppColors.blackCat,
                        backgroundColor: _requestSnow,
                        checkmarkColor: AppColors.snow,
                        onSelected: (_) =>
                            setState(() => _fallbackToPool = false),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: _fallbackToPool == false
                              ? AppColors.snow
                              : AppColors.blackCat,
                        ),
                        side: BorderSide(
                          color: AppColors.blackCat.withValues(alpha: 0.08),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            NailPreferencesInlineEditor(
              initial: _singleNailPrefs,
              showMeasurementTips: false,
              showDimensionImages: false,
              showNfcOptions: true,
              nailDimensionBorderColor: AppColors.blackCat.withValues(
                alpha: 0.25,
              ),
              onChanged: (updated) {
                setState(() {
                  final oldNfcCount = _nfcSelectedCount(
                    _singleNailPrefs.dimensions,
                  );
                  final newNfcCount = _nfcSelectedCount(updated.dimensions);
                  _singleNailPrefs = updated;
                  _shape = updated.shape;
                  _length = updated.length;
                  _applyNfcBudgetDelta(
                    oldCount: oldNfcCount,
                    newCount: newNfcCount,
                  );
                  _fieldErrors.remove('shape');
                  _fieldErrors.remove('length');
                });
              },
            ),
            _InlineError(text: _fieldErrors['shape']),
            _InlineError(text: _fieldErrors['length']),

            const Text(
              'Budget Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arial',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set your preferred budget range for nail designs.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _BudgetCard(
              minLabel: '\$15',
              maxLabel: '\$5000',
              values: _sanitizeBudgetRange(_budget),
              onChanged: (v) =>
                  setState(() => _budget = _sanitizeBudgetRange(v)),
              onChangeEnd: (v) => _saveBudgetToDb(_sanitizeBudgetRange(v)),
            ),

            const SizedBox(height: 18),

            const SizedBox(height: 14),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.scale(
                        scale: 0.95,
                        child: Checkbox(
                          value: _shippingDifferent,
                          onChanged: (v) => setState(() {
                            _shippingDifferent = v ?? false;
                          }),
                          activeColor: AppColors.blackCat,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Shipping address different from profile address?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.blackCat.withValues(alpha: 0.75),
                              height: 1.2,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_shippingDifferent) ...[
                    const SizedBox(height: 10),
                    _fieldLabel('Shipping Address *'),
                    const SizedBox(height: 10),
                    _InputField(
                      controller: _shipStreetCtrl,
                      hint: 'Street',
                      minHeight: 52,
                      verticalPadding: 14,
                      onChanged: (_) => setState(() {
                        _fieldErrors.remove('shipStreet');
                      }),
                    ),
                    _InlineError(text: _fieldErrors['shipStreet']),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipCityCtrl,
                      hint: 'City',
                      minHeight: 52,
                      verticalPadding: 14,
                      onChanged: (_) => setState(() {
                        _fieldErrors.remove('shipCity');
                      }),
                    ),
                    _InlineError(text: _fieldErrors['shipCity']),
                    const SizedBox(height: 4),
                    if (_isShipCountryUs) ...[
                      _SearchableSelectField(
                        value: _shipState,
                        hint: 'State',
                        minHeight: 52,
                        verticalPadding: 14,
                        items: usStates,
                        onChanged: (v) => setState(() {
                          _shipState = v;
                          _shipStateCtrl.text = v;
                          _fieldErrors.remove('shipState');
                        }),
                      ),
                      _InlineError(text: _fieldErrors['shipState']),
                    ] else ...[
                      _InputField(
                        controller: _shipStateCtrl,
                        hint: 'State/Region (Optional)',
                        minHeight: 52,
                        verticalPadding: 14,
                        onChanged: (v) => _shipState = v,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipZipCtrl,
                      minHeight: 52,
                      verticalPadding: 14,
                      hint: _isShipCountryUs ? 'Zip' : 'Zip (Optional)',
                      onChanged: (_) => setState(() {
                        _fieldErrors.remove('shipZip');
                      }),
                    ),
                    _InlineError(text: _fieldErrors['shipZip']),
                    const SizedBox(height: 4),
                    _SearchableSelectField(
                      value: _shipCountry,
                      hint: 'Country',
                      minHeight: 52,
                      verticalPadding: 14,
                      items: countries,
                      onChanged: (v) => setState(() {
                        _shipCountry = v.trim().isEmpty ? 'United States' : v;
                        _fieldErrors.remove('shipCountry');
                        if (!_isShipCountryUs) {
                          _fieldErrors.remove('shipState');
                          _fieldErrors.remove('shipZip');
                        }
                      }),
                    ),
                    _InlineError(text: _fieldErrors['shipCountry']),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: _requestSnow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitRequest,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _requestSnow,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.showBottomNav
            ? BottomNavigationBar(
                currentIndex: widget.bottomNavIndex,
                selectedItemColor: AppColors.blackCat,
                unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
                type: BottomNavigationBarType.fixed,
                onTap: (i) {
                  if (widget.onNavTap != null) {
                    widget.onNavTap!(i);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    return;
                  }
                  if (i != widget.bottomNavIndex) {
                    Navigator.pop(context);
                  }
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline),
                    label: 'Design',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inbox_outlined),
                    label: 'Campaigns',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: 'Calendar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: 'History',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _photoFallback(String p) {
    return Container(
      width: 110,
      height: 110,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: AppColors.blackCat.withValues(alpha: 0.04),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 28),
          const SizedBox(height: 6),
          Text(
            _fileNameFromPath(p),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.blackCat.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return ExcludeSemantics(
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.blackCat.withValues(alpha: 0.75),
          fontSize: 14,
          fontFamily: 'Arialbold',
        ),
      ),
    );
  }
}

enum OrderType { single, group }

class CompletedClient {
  final String id;
  final String name;
  final ClientProfileDraft profile;

  const CompletedClient({
    required this.id,
    required this.name,
    required this.profile,
  });
}

class GroupClientSelection {
  String? clientId;
  NailPreferences? draftNails;
  NailPreferences? savedNails;
  final TextEditingController searchController = TextEditingController();
  bool showSuggestions = false;

  GroupClientSelection({this.clientId, this.draftNails, this.savedNails});

  void dispose() {
    searchController.dispose();
  }
}

/// ? Avatar dropdown (Logout)
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
    this.showProfile = true,
    this.showHistory = true,
    this.showCalendar = true,
    this.showArtist = true,
    this.showReviews = true,
  });
  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;
  final bool showProfile;
  final bool showHistory;
  final bool showCalendar;
  final bool showArtist;
  final bool showReviews;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: _requestSnow,
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
        if (showReviews)
          PopupMenuItem<String>(
            value: 'reviews',
            child: Row(
              children: const [
                Icon(Icons.star_border, size: 22),
                SizedBox(width: 14),
                Text(
                  'Reviews',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (showProfile ||
            showHistory ||
            showCalendar ||
            showArtist ||
            showReviews)
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
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: ClientProfileAvatarIcon(
            imageUrl: avatarUrl,
            displayName: displayName,
            size: JntHeaderMetrics.avatarSize,
          ),
        ),
      ),
    );
  }
}

/// -----------------
/// UI Pieces
/// -----------------

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _requestSnow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.onTap,
    this.focusNode,
    this.errorText,
    this.onChanged,
  });
  final TextEditingController controller;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      onTap: onTap,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: 'MM/DD/YYYY',
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: AppColors.blackCat.withValues(alpha: 0.35),
          fontWeight: FontWeight.w400,
          fontFamily: 'Arial',
        ),
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
        focusColor: _requestSnow,
        hoverColor: _requestSnow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minHeight: 52),
        suffixIcon: Icon(
          Icons.calendar_month_rounded,
          size: 16,
          color: AppColors.blackCat.withValues(alpha: 0.45),
        ),
        errorText: (errorText ?? '').trim().isEmpty ? null : errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.errorText,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: 5,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Arialbold',
        color: AppColors.blackCat,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: AppColors.blackCat.withValues(alpha: 0.35),
          fontFamily: 'Arial',
        ),
        errorText: (errorText ?? '').trim().isEmpty ? null : errorText,
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
        focusColor: _requestSnow,
        hoverColor: _requestSnow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minHeight: 52),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.minHeight = 52,
    this.verticalPadding = 6,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final double minHeight;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: AppColors.blackCat.withValues(alpha: 0.35),
          fontWeight: FontWeight.w400,
          fontFamily: 'Arial',
        ),
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
        focusColor: _requestSnow,
        hoverColor: _requestSnow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: verticalPadding,
        ),
        constraints: BoxConstraints(minHeight: minHeight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: _requestBorder,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Arial',
        ),
      ),
    );
  }
}

class _FocusRingWrapper extends StatelessWidget {
  const _FocusRingWrapper({
    required this.focusNode,
    required this.ringColor,
    required this.child,
  });

  final FocusNode focusNode;
  final Color ringColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final showAdaFocusRing =
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        return Container(
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: (showAdaFocusRing && focusNode.hasFocus)
                  ? ringColor
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: child,
        );
      },
    );
  }
}

class _SearchableSelectField extends StatelessWidget {
  const _SearchableSelectField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.minHeight = 52,
    this.verticalPadding = 6,
  });

  final String value;
  final String hint;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final double minHeight;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final normalizedItems = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final initialValue = value.trim();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return normalizedItems;
        return normalizedItems.where(
          (item) => item.toLowerCase().contains(query),
        );
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textAlignVertical: TextAlignVertical.center,
          onTap: () {
            if (controller.text.trim().isEmpty && normalizedItems.isNotEmpty) {
              controller.value = const TextEditingValue(text: ' ');
              controller.selection = const TextSelection.collapsed(offset: 1);
              controller.value = const TextEditingValue(text: '');
            }
          },
          onSubmitted: (_) => onSubmit(),
          onTapOutside: (_) => focusNode.unfocus(),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: AppColors.blackCat,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: AppColors.blackCat.withValues(alpha: 0.35),
              fontWeight: FontWeight.w400,
              fontFamily: 'Arial',
            ),
            isDense: true,
            filled: true,
            fillColor: _requestSnow,
            focusColor: _requestSnow,
            hoverColor: _requestSnow,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: verticalPadding,
            ),
            constraints: BoxConstraints(minHeight: minHeight),
            suffixIcon: Icon(
              Icons.search_rounded,
              size: 16,
              color: AppColors.blackCat.withValues(alpha: 0.45),
            ),
            suffixIconConstraints: const BoxConstraints(
              minHeight: 32,
              minWidth: 32,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: _requestBorder,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: _requestBorder,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: _requestBorder,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList(growable: false);
        final menuHeight = AutocompleteDropdownSizing.menuHeight(
          itemCount: list.length,
          itemExtent: 40,
        );
        return TextFieldTapRegion(
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              color: _requestSnow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: _requestBorder,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: menuHeight,
                  minWidth: 220,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                    list.length,
                  ),
                  physics: AutocompleteDropdownSizing.scrollPhysics(
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
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
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = _requestSnow,
    this.iconColor,
    this.textColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor ?? AppColors.blackCat.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                fontFamily: 'Arial',
                color: textColor ?? AppColors.blackCat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (rest of your file continues unchanged...)

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.minLabel,
    required this.maxLabel,
    required this.values,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String minLabel;
  final String maxLabel;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues> onChangeEnd;

  Null get center => null;

  String _fmtMoney(double v) => '\$${v.round()}';

  @override
  Widget build(BuildContext context) {
    final start = values.start;
    final end = values.end;

    final currentText = '${_fmtMoney(start)} - ${_fmtMoney(end)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: _requestSnow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /*Row(
            children: [
              Text(minLabel, style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11.5)),
              const Spacer(),
              Text(maxLabel, style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11.5)),
            ],
          ),*/
          const SizedBox(height: 8),

          // ? Single range text (no duplicates)
          Text(
            currentText,
            //textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),

          const SizedBox(height: 6),

          Theme(
            data: Theme.of(context).copyWith(
              sliderTheme: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.blackCat,
                inactiveTrackColor: AppColors.blackCat.withValues(alpha: 0.10),
                thumbColor: AppColors.blackCat,
                overlayColor: AppColors.blackCat.withValues(alpha: 0.10),
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 9,
                ),
                trackHeight: 3.2,

                // ? This removes the duplicate bubble/tooltip values
                showValueIndicator: ShowValueIndicator.never,
              ),
            ),
            child: RangeSlider(
              min: 15,
              max: 5000,
              divisions: 485,
              values: values,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioPill extends StatelessWidget {
  const _RadioPill({
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = _requestSnow;
    final border = selected
        ? AppColors.blackCat
        : AppColors.blackCat.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22, // ? smaller icon
              color: selected
                  ? AppColors.blackCat
                  : AppColors.blackCat.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Arial',
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> usStates = [
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
];
const List<String> countries = [
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
  'Congo (Congo-Brazzaville)',
  'Costa Rica',
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czechia (Czech Republic)',
  "C\u00F4te d'Ivoire",
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
  'Eswatini (fmr. "Swaziland")',
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
  'Holy See',
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
  'Myanmar (formerly Burma)',
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
  'Palestine State',
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
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe',
];
