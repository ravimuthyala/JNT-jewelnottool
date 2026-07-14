import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants/profile_table_columns.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import 'client_shell_page.dart';
import 'notifications_page.dart';
import '../services/address_validation_service.dart';
import '../services/artist_directory_service.dart';
import '../services/notifications_service.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/nail_preferences_inline_editor.dart';
import 'artist_reviews_page.dart';
import 'client_artist_history_page.dart';
import 'client_artist_profile_page.dart';
import 'client_artists_page.dart';

const Color _requestSnow = Color(0xFFFAF9F9);
const Color _focusRing = Color(0xFFFFBF47);
final BorderSide _requestBorder = BorderSide(
  color: AppColors.blackCat.withValues(alpha: 0.25),
);

/// ✅ NEW PAGE: Same as ClientCustomRequestPage, but artist is preselected
class ClientCustomRequestWithArtistPage extends StatefulWidget {
  ClientCustomRequestWithArtistPage({
    super.key,
    ClientProfileDraft? profile,
    required this.artistNames,
    required this.artistName,
    this.onSubmitted,
    this.showClientBottomNav = true,
    this.onClientNavTap,
    this.isActiveTab = true,
    this.excludeCurrentUserFromArtistDropdown = false,
  }) : profile = profile ?? ClientProfileDraft.mock();

  final ClientProfileDraft profile;
  final String artistName;
  final List<String> artistNames; // ✅ NEW
  final Future<void> Function(BuildContext context)? onSubmitted;
  final bool showClientBottomNav;
  final Future<void> Function(BuildContext context, int index)? onClientNavTap;
  final bool isActiveTab;

  /// Only used by the Client-Artist role. A client-artist can submit a
  /// request as a client, but cannot select themself as the artist.
  /// Default is false so normal Client flow is unchanged.
  final bool excludeCurrentUserFromArtistDropdown;

  @override
  State<ClientCustomRequestWithArtistPage> createState() =>
      _ClientCustomRequestWithArtistPageState();
}

class _ClientCustomRequestWithArtistPageState
    extends State<ClientCustomRequestWithArtistPage> {
  static const int _maxImageSizeBytes = 2 * 1024 * 1024;
  static const int _maxInspirationPhotos = 10;
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'designWithArtistNotifications',
  );
  final FocusNode _needByFocusNode = FocusNode(debugLabel: 'needByDateField');
  final FocusNode _descriptionFocusNode = FocusNode(
    debugLabel: 'descriptionField',
  );
  bool _didSetInitialA11yFocus = false;
  bool _focusRequestQueued = false;

  DateTime? _needBy;

  bool _allowNonLicensed = true; // default checked
  bool _fallbackToPool = true; // default yes
  final ImagePicker _picker = ImagePicker();
  final List<String> _inspirationPhotos = [];
  final Map<String, XFile> _pickedPhotoFiles = <String, XFile>{};
  final Map<String, Uint8List> _pickedPhotoBytes = <String, Uint8List>{};

  // ✅ artist is fixed / pre-filled
  String? _selectedArtist;
  RangeValues _clientBudget = const RangeValues(15, 5000);
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
    final nextStart = (_clientBudget.start + delta)
        .clamp(15.0, 5000.0)
        .toDouble();
    final nextEnd = _clientBudget.end < nextStart
        ? nextStart
        : _clientBudget.end;
    _clientBudget = _sanitizeBudgetRange(RangeValues(nextStart, nextEnd));
  }

  OrderType _orderType = OrderType.single;

  // nail selections (prefilled from profile)
  late String _shape;
  late NailLength _length;
  late NailPreferences _singleNailPrefs;

  // shipping
  bool _shippingDifferent = false;
  final _shipStreetCtrl = TextEditingController();
  final _shipCityCtrl = TextEditingController();
  final _shipZipCtrl = TextEditingController();
  final _shipStateCtrl = TextEditingController();
  String _shipState = '';
  String _shipCountry = 'United States';
  Timer? _shipStreetAutocompleteDebounce;
  List<AddressSuggestion> _shipStreetSuggestions = const [];
  bool _shipStreetSuggestionsLoading = false;

  // -----------------------------
  // GROUP ORDER
  // -----------------------------
  List<CompletedClient> _completedClients = <CompletedClient>[];
  bool _loadingCompletedClients = false;

  final List<GroupClientSelection> _groupSelections = [];
  static const int _maxGroupClients = 15;
  bool _isSubmitting = false;
  final List<String> _artistNames = [];
  final Map<String, bool> _artistAcceptsNfcByNameLower = <String, bool>{};
  final Map<String, bool> _artistIsProfessionalByNameLower = <String, bool>{};
  final Map<String, String> _fieldErrors = <String, String>{};

  bool get _isShipCountryUs =>
      _shipCountry.trim().toLowerCase() == 'united states';

  Future<void> _autofillShippingAddressFromStreet() async {
    _shipStreetAutocompleteDebounce?.cancel();
    final query = _shipStreetCtrl.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _shipStreetSuggestionsLoading = false;
        _shipStreetSuggestions = const [];
      });
      return;
    }

    setState(() => _shipStreetSuggestionsLoading = true);
    _shipStreetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _shipStreetSuggestionsLoading = false;
          _shipStreetSuggestions = results;
        });
      },
    );
  }

  void _applyShippingStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _shipStreetCtrl.text = selected.street;
      _shipCityCtrl.text = selected.city;
      _shipZipCtrl.text = selected.zip;
      _shipCountry = 'United States';
      _shipState =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      _shipStateCtrl.text = _shipState;
      _shipStreetSuggestions = const [];
      _fieldErrors.remove('shipStreet');
      _fieldErrors.remove('shipCity');
      _fieldErrors.remove('shipState');
      _fieldErrors.remove('shipZip');
      _fieldErrors.remove('shipCountry');
    });
  }

  @override
  void initState() {
    super.initState();

    // ✅ Safe defaults for nail shape/length
    final profileShape = widget.profile.nail.shape;
    final profileLength = widget.profile.nail.length;

    final normalizedShape = _normalizeShapeValue(profileShape);
    _shape = normalizedShape.isNotEmpty
        ? normalizedShape
        : (nailShapes.isNotEmpty ? nailShapes.first : 'Square');
    _length = _normalizeLengthValue(
      profileLength.name,
      fallback: NailLength.medium,
    );
    _singleNailPrefs = NailPreferences(
      dimensions: widget.profile.nail.dimensions,
      shape: _shape,
      length: _length,
    );
    _shipStateCtrl.text = _shipState;

    // ✅ prefill artist from Artists page (trim for safety)
    _selectedArtist = _isSelfArtistName(widget.artistName)
        ? null
        : widget.artistName.trim();
    _artistNames.addAll(
      _filterSelfArtistNames(
        _dedupeArtistNames(<String>[...widget.artistNames, widget.artistName]),
      ),
    );
    unawaited(_loadArtistNames());
    //unawaited(_loadCompletedClientsFromDb());
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

  Future<void> _loadArtistNames() async {
    try {
      final entries = await ArtistDirectoryService.fetchAllArtists();
      if (!mounted) return;
      final currentEmail = _currentUserEmailLower();
      final names = entries
          .where((e) => e.acceptsDirectRequests)
          .where((e) {
            if (!widget.excludeCurrentUserFromArtistDropdown) return true;
            final artistEmail = e.email.trim().toLowerCase();
            if (currentEmail.isNotEmpty && artistEmail == currentEmail) {
              return false;
            }
            return !_isSelfArtistName(e.name);
          })
          .map((e) => e.name.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() {
        _artistAcceptsNfcByNameLower
          ..clear()
          ..addEntries(
            entries
                .where((e) => e.acceptsDirectRequests)
                .where((e) => e.name.trim().isNotEmpty)
                .map(
                  (e) => MapEntry(
                    e.name.trim().toLowerCase(),
                    e.acceptsNfcRequests,
                  ),
                ),
          );
        _artistIsProfessionalByNameLower
          ..clear()
          ..addEntries(
            entries
                .where((e) => e.acceptsDirectRequests)
                .where((e) => e.name.trim().isNotEmpty)
                .map(
                  (e) => MapEntry(
                    e.name.trim().toLowerCase(),
                    _artistEntryIsProfessional(e),
                  ),
                ),
          );
        _artistNames
          ..clear()
          ..addAll(
            _filterSelfArtistNames(
              _dedupeArtistNames(<String>[
                ...widget.artistNames,
                widget.artistName,
                ...names,
              ]),
            ),
          );
        final selected = (_selectedArtist ?? '').trim();
        final hasSelected =
            selected.isNotEmpty &&
            _artistNames.any(
              (n) => n.trim().toLowerCase() == selected.toLowerCase(),
            );
        if (widget.excludeCurrentUserFromArtistDropdown &&
            selected.isNotEmpty &&
            _isSelfArtistName(selected)) {
          _selectedArtist = null;
        } else if (selected.isNotEmpty && !hasSelected) {
          _artistNames
            ..clear()
            ..addAll(
              _filterSelfArtistNames(
                _dedupeArtistNames(<String>[selected, ..._artistNames]),
              ),
            );
        }
        _syncSelectedArtistForFilters();
      });
    } catch (_) {}
  }

  bool _artistEntryIsProfessional(ArtistDirectoryEntry entry) {
    final credential = entry.credential.trim().toLowerCase();
    return !(credential.contains('student') ||
        credential.contains('unlicensed') ||
        credential.contains('non-licensed'));
  }

  bool _requestNeedsNfcAcceptedArtist() {
    final selectedNails = NailPreferences(
      dimensions: _singleNailPrefs.dimensions,
      shape: _shape,
      length: _length,
    );
    return _requestHasSelectedNfc(mainNails: selectedNails);
  }

  List<String> _filteredArtistOptions() {
    final needsNfc = _requestNeedsNfcAcceptedArtist();
    final names = _artistNames
        .where((name) {
          if (!_allowNonLicensed &&
              _artistIsProfessionalByNameLower[name.trim().toLowerCase()] !=
                  true) {
            return false;
          }
          if (!needsNfc) return true;
          return _artistAcceptsNfcByNameLower[name.trim().toLowerCase()] ==
              true;
        })
        .toList(growable: false);
    return _filterSelfArtistNames(_dedupeArtistNames(names));
  }

  void _syncSelectedArtistForFilters() {
    final selected = (_selectedArtist ?? '').trim();
    if (selected.isEmpty) return;
    final key = selected.toLowerCase();
    if (!_allowNonLicensed && _artistIsProfessionalByNameLower[key] != true) {
      _selectedArtist = null;
      return;
    }
    if (_requestNeedsNfcAcceptedArtist() &&
        _artistAcceptsNfcByNameLower[key] != true) {
      _selectedArtist = null;
    }
  }

  String _currentUserEmailLower() {
    return (Supabase.instance.client.auth.currentUser?.email ?? '')
        .trim()
        .toLowerCase();
  }

  Set<String> _selfArtistNameKeys() {
    if (!widget.excludeCurrentUserFromArtistDropdown) return const <String>{};

    String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();

    final keys = <String>{
      norm(widget.profile.basic.name),
      norm(Supabase.instance.client.auth.currentUser?.userMetadata?['name']),
      norm(
        Supabase.instance.client.auth.currentUser?.userMetadata?['displayName'],
      ),
      norm(
        Supabase
            .instance
            .client
            .auth
            .currentUser
            ?.userMetadata?['display_name'],
      ),
      norm(
        Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'],
      ),
    }..removeWhere((e) => e.isEmpty);

    final email = _currentUserEmailLower();
    if (email.contains('@'))
      keys.add(email.split('@').first.trim().toLowerCase());

    return keys;
  }

  bool _isSelfArtistName(String name) {
    if (!widget.excludeCurrentUserFromArtistDropdown) return false;
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return false;
    return _selfArtistNameKeys().contains(key);
  }

  List<String> _filterSelfArtistNames(List<String> names) {
    if (!widget.excludeCurrentUserFromArtistDropdown) return names;
    return names
        .where((name) => !_isSelfArtistName(name))
        .toList(growable: false);
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
        if (_requestNeedsNfcAcceptedArtist() && !artist.acceptsNfcRequests) {
          continue;
        }
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
      final parsed = double.tryParse(cleaned);
      if (parsed == null || !parsed.isFinite) return null;
      return parsed;
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
        cleanDetails['selectedArtist'],
      ]),
      _firstNonEmpty([
        cleanSummary['needBy'],
        _asMap(cleanDetails['requestDetails'])['needBy'],
      ]),
      _firstNonEmpty([
        cleanSummary['budgetMin'],
        _asMap(cleanDetails['budget'])['min'],
      ]),
      _firstNonEmpty([
        cleanSummary['budgetMax'],
        _asMap(cleanDetails['budget'])['max'],
      ]),
      _firstNonEmpty([
        cleanSummary['nailShape'],
        _asMap(cleanDetails['nailPreferences'])['shape'],
      ]),
      _firstNonEmpty([
        cleanSummary['nailLength'],
        _asMap(cleanDetails['nailPreferences'])['length'],
      ]),
      _firstNonEmpty([
        cleanSummary['descriptionPreview'],
        _asMap(cleanDetails['requestDetails'])['description'],
      ]),
    ].map((value) => value.trim().toLowerCase()).join('|');

    cleanSummary['submissionFingerprint'] = submissionFingerprint;
    cleanDetails['submissionFingerprint'] = submissionFingerprint;

    final existing = await supabase
        .from('client_custom_requests')
        .select('id')
        .contains('summary', {'submissionFingerprint': submissionFingerprint})
        .maybeSingle();
    final existingMap = existing is Map ? existing : null;
    if (existingMap != null && existingMap['id'] != null) {
      return existingMap['id'].toString().trim();
    }

    final row = <String, dynamic>{
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
        cleanDetails['selectedArtist'],
      ]),
      'selected_artist_email': _firstNonEmpty([
        cleanSummary['selectedArtistEmail'],
      ]).toLowerCase(),
      'is_direct_request': _asBool(cleanSummary['isDirectRequest']),
      'fallback_to_pool': _asBool(cleanSummary['fallbackToPool']),
      'open_to_artist_pool': !_asBool(cleanSummary['isDirectRequest']),
      'direct_artist_status': _asBool(cleanSummary['isDirectRequest'])
          ? 'in_review'
          : '',
      'artist_pool_status': _asBool(cleanSummary['isDirectRequest'])
          ? 'locked'
          : 'in_review',
      'status': _firstNonEmpty([cleanSummary['status'], 'pending']),
      'summary': cleanSummary,
      'details': cleanDetails,
      'inspiration_photos':
          cleanSummary['inspirationPhotos'] ?? const <String>[],
      'photo_count': cleanSummary['photoCount'] ?? 0,
      'has_inspiration_photos': cleanSummary['hasInspirationPhotos'] ?? false,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    final inserted = await supabase
        .from('client_custom_requests')
        .insert(row)
        .select('id')
        .single();

    final requestId = (inserted['id'] ?? '').toString().trim();
    if (requestId.isEmpty) {
      throw Exception('Supabase did not return a request id.');
    }

    return requestId;
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

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  Future<void> _loadCompletedClientsFromDb() async {
    setState(() => _loadingCompletedClients = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUid = (supabase.auth.currentUser?.id ?? '').trim();
      final currentEmail = (supabase.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();

      final allRows = <Map<String, dynamic>>[];

      for (final table in const <String>['client', 'client_artist']) {
        try {
          final columns = columnsForProfileTable(table) ?? '*';
          final rows = await supabase.from(table).select(columns).limit(200);
          allRows.addAll(
            rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false),
          );
        } catch (e) {
          debugPrint(
            'CLIENT CUSTOM REQUEST WITH ARTIST client load failed [$table]: $e',
          );
        }
      }

      final byId = <String, CompletedClient>{};

      for (final data in allRows) {
        final id = _firstNonEmpty([data['id'], data['uid']]);
        final profile = _asMap(data['profile']);
        final basic = _asMap(data['basic']);
        final address = _asMap(data['address']);
        final client = _asMap(data['client']);
        final clientProfile = _asMap(client['profile']);
        final clientAddress = _asMap(client['address']);

        final nail = _asMap(data['nailPreferences']).isNotEmpty
            ? _asMap(data['nailPreferences'])
            : _asMap(client['nailPreferences']);
        final dims = _asMap(nail['dimensions']);

        final email = _firstNonEmpty([
          data['email'],
          basic['email'],
          profile['email'],
          client['email'],
        ]).toLowerCase();

        if (id.isNotEmpty && id == currentUid) continue;
        if (currentEmail.isNotEmpty && email == currentEmail) continue;

        final name = _firstNonEmpty([
          basic['name'],
          profile['name'],
          profile['displayName'],
          clientProfile['name'],
          clientProfile['displayName'],
          data['displayName'],
          data['name'],
          email.contains('@') ? email.split('@').first : '',
        ]);

        if (name.isEmpty) continue;

        final clientProfileDraft = ClientProfileDraft(
          basic: BasicInfo(
            name: name,
            email: email,
            phone: _firstNonEmpty([
              basic['phone'],
              profile['phone'],
              clientProfile['phone'],
              data['phone'],
            ]),
          ),
          address: AddressInfo(
            street: _firstNonEmpty([
              address['street'],
              address['addressLine1'],
              clientAddress['street'],
              clientAddress['addressLine1'],
              data['street'],
            ]),
            city: _firstNonEmpty([
              address['city'],
              clientAddress['city'],
              data['city'],
            ]),
            state: _firstNonEmpty([
              address['state'],
              clientAddress['state'],
              data['state'],
            ]),
            zip: _firstNonEmpty([
              address['zip'],
              clientAddress['zip'],
              data['zip'],
            ]),
            country: _firstNonEmpty([
              address['country'],
              clientAddress['country'],
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
            shape: _firstNonEmpty([nail['shape']]),
            length: _parseNailLength(nail['length']),
          ),
        );

        if (!clientProfileDraft.isComplete) continue;
        if (!_hasAllValidMeasurements(clientProfileDraft.nail.dimensions)) {
          continue;
        }

        byId[id.isEmpty ? email : id] = CompletedClient(
          id: id.isEmpty ? email : id,
          name: name,
          profile: clientProfileDraft,
        );
      }

      final loaded = byId.values.toList()
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
      debugPrint(
        'CLIENT CUSTOM REQUEST WITH ARTIST completed clients load failed: $e',
      );
      if (!mounted) return;
      setState(() => _completedClients = <CompletedClient>[]);
    } finally {
      if (mounted) {
        setState(() => _loadingCompletedClients = false);
      }
    }
  }

  @override
  void dispose() {
    _shipStreetAutocompleteDebounce?.cancel();
    _dateCtrl.dispose();
    _descCtrl.dispose();
    _shipStreetCtrl.dispose();
    _shipCityCtrl.dispose();
    _shipZipCtrl.dispose();
    _shipStateCtrl.dispose();
    for (final slot in _groupSelections) {
      slot.dispose();
    }
    _needByFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  void _onAvatarMenuSelected(String value) {
    if (value == 'profile') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ClientArtistProfilePage(initialProfile: widget.profile),
        ),
      );
      return;
    }
    if (value == 'history') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientArtistHistoryPage(
            profile: widget.profile,
            showContinueProfileCard: !widget.profile.isComplete,
            enableAllTabs: widget.profile.isComplete,
          ),
        ),
      );
      return;
    }
    if (value == 'calendar') {
      widget.onClientNavTap?.call(context, 1);
      return;
    }
    if (value == 'artist') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientArtistsPage(profile: widget.profile),
        ),
      );
      return;
    }
    if (value == 'reviews') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ArtistReviewsPage()));
      return;
    }
    if (value == 'logout') {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
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
    final currentUid = (Supabase.instance.client.auth.currentUser?.id ?? '')
        .trim();
    final currentEmail =
        (Supabase.instance.client.auth.currentUser?.email ?? '')
            .trim()
            .toLowerCase();
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

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  bool _isUrl(String p) => p.startsWith('http://') || p.startsWith('https://');

  ImageProvider _imageProviderFor(String path) {
    final p = path.trim();

    if (_isUrl(p)) return NetworkImage(p);
    if (p.startsWith('data:')) return NetworkImage(p);
    if (p.startsWith('assets/')) return AssetImage(p);
    if (kIsWeb) return NetworkImage(p);

    // Mobile-safe thumbnail preview.
    return ResizeImage(FileImage(File(p)), width: 300, height: 300);
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

  void _resetFormAfterSubmit() {
    _dateCtrl.clear();
    _descCtrl.clear();
    _needBy = null;
    _inspirationPhotos.clear();
    _pickedPhotoFiles.clear();
    _pickedPhotoBytes.clear();
    _allowNonLicensed = true;
    _clientBudget = const RangeValues(15, 5000);
    _orderType = OrderType.single;
    _selectedArtist = _isSelfArtistName(widget.artistName)
        ? null
        : widget.artistName.trim();
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

    final selectedNails = NailPreferences(
      dimensions: _singleNailPrefs.dimensions,
      shape: _shape,
      length: _length,
    );
    final now = DateTime.now();

    final needBy = needByDate.toIso8601String();
    final description = _descCtrl.text.trim();
    final clientBudgetMin = _clientBudget.start.round();
    final clientBudgetMax = _clientBudget.end.round();
    // Client custom request (from artist page) uses a single budget range.
    // Keep artist budget fields in sync for backward compatibility.
    final artistBudgetMin = clientBudgetMin;
    final artistBudgetMax = clientBudgetMax;
    final selectedArtist = (_selectedArtist ?? '').trim();
    final selectedArtistRequiresNfc =
        _requestNeedsNfcAcceptedArtist() && selectedArtist.isNotEmpty;
    if (selectedArtistRequiresNfc &&
        _artistAcceptsNfcByNameLower[selectedArtist.toLowerCase()] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select an artist who accepts NFC for this request.',
            ),
          ),
        );
      }
      setState(() {
        _selectedArtist = null;
        _isSubmitting = false;
      });
      return;
    }
    final selectedArtistEmail = await _resolveSelectedArtistEmail(
      selectedArtist,
    );
    final isDirectRequest = selectedArtist.isNotEmpty;
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
      'budgetMin': artistBudgetMin,
      'budgetMax': artistBudgetMax,
      'nfcEligible': nfcEligible,
      'eligibleForNfc': nfcEligible,
      'nfcRequested': nfcRequested,
      'nfcSelected': nfcRequested,
      'hasNfc': nfcRequested,
      'nfcCount': nfcCount,
      'clientBudgetMin': clientBudgetMin,
      'clientBudgetMax': clientBudgetMax,
      'artistBudgetMin': artistBudgetMin,
      'artistBudgetMax': artistBudgetMax,
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
      'clientName': widget.profile.basic.name,
      'clientEmail': widget.profile.basic.email,
    };

    final requestDetails = <String, dynamic>{
      'requestDetails': {
        'needBy': needBy,
        'needByDisplay': _dateCtrl.text.trim(),
        'description': description,
      },
      'budget': {'min': artistBudgetMin, 'max': artistBudgetMax},
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
      'clientBudget': {'min': clientBudgetMin, 'max': clientBudgetMax},
      'artistBudget': {'min': artistBudgetMin, 'max': artistBudgetMax},
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
      'clientProfileSnapshot': _profileSnapshotToMap(widget.profile),
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
        final excludeArtistEmails = widget.excludeCurrentUserFromArtistDropdown
            ? <String>[widget.profile.basic.email]
            : const <String>[];
        await NotificationsService.notifyArtistsForNewClientRequest(
          clientName: widget.profile.basic.name,
          isDirectRequest: isDirectRequest,
          selectedArtistEmail: selectedArtistEmail,
          selectedArtistName: selectedArtist,
          orderId: requestId,
          orderNumber: _firstNonEmpty([requestSummary['orderNumber']]),
          sourceCollection: 'Client_Custom_Requests',
          allowNonLicensed: _allowNonLicensed,
          nfcRequested: nfcRequested,
          excludeArtistEmails: excludeArtistEmails,
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
      if (widget.onSubmitted != null) {
        await widget.onSubmitted!(context);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ClientShellPage(
            profile: widget.profile,
            initialIndex: 0,
            forceEnableAllTabs: true,
          ),
        ),
        (route) => false,
      );
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
      throw Exception(
        'Only $uploadedNewCount of $selectedLocalCount photos uploaded.',
      );
    }

    await _updateSupabaseClientCustomRequest(requestId, {
      'photo_count': photos.length,
      'has_inspiration_photos': photos.isNotEmpty,
      'inspiration_photos': photos,
      'summary': {
        'photoCount': photos.length,
        'hasInspirationPhotos': photos.isNotEmpty,
        'inspirationPhotos': photos,
      },
      'details': {
        'inspirationPhotos': photos,
        'requestDetails': {'inspirationPhotos': photos},
      },
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
  void didUpdateWidget(covariant ClientCustomRequestWithArtistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActiveTab && widget.isActiveTab) {
      _didSetInitialA11yFocus = false;
      _scheduleInitialA11yFocus();
    }
    if (oldWidget.artistName != widget.artistName) {
      setState(() {
        _selectedArtist = _isSelfArtistName(widget.artistName)
            ? null
            : widget.artistName.trim();
      });
      unawaited(_loadArtistNames());
    }
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
          leadingWidth: JntHeaderMetrics.leadingWidth,
          leading: NotificationBellButton(
            onTap: () {
              NotificationsPage.showAsModal(context);
            },
            focusNode: _notificationsFocusNode,
            iconSize: JntHeaderMetrics.notificationIconSize,
          ),

          // ✅ Center logo
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

          // ✅ Avatar
          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: JntHeaderMetrics.rightPadding,
              ),
              child: _AvatarMenu(
                onSelected: _onAvatarMenuSelected,
                avatarUrl: widget.profile.basic.profileImageUrl,
                displayName: widget.profile.basic.name,
                showProfile: true,
                showHistory: true,
                showCalendar: true,
                showArtist: true,
                showReviews: true,
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
                                    Image(
                                      image: _imageProviderFor(photos[i]),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              _fileNameFromPath(photos[i]),
                                              textAlign: TextAlign.center,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
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
                    onChanged: (v) => setState(() {
                      _allowNonLicensed = (v ?? true);
                      _syncSelectedArtistForFilters();
                    }),
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

            // ✅ group order section
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
                                _syncSelectedArtistForFilters();
                              });
                            },
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: saved
                                    ? AppColors.blackCat.withValues(alpha: 0.15)
                                    : AppColors.blackCat,
                                foregroundColor: _requestSnow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: () => _saveSlot(i),
                              child: Text(
                                saved ? 'Saved ✅' : 'Save Client Preferences',
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

            // ✅ Request a Specific Artist (optional with clear selection)
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
                      final options = _filteredArtistOptions();
                      return _SearchableSelectField(
                        value: selected,
                        hint: 'Select Artist',
                        items: options,
                        onChanged: (v) => setState(() {
                          final next = v.trim();
                          _selectedArtist =
                              next.isEmpty || _isSelfArtistName(next)
                              ? null
                              : next;
                        }),
                      );
                    },
                  ),

                  if ((_selectedArtist ?? '').trim().isNotEmpty) ...[
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
                          label: const Text(
                            'Yes',
                            style: TextStyle(fontSize: 12),
                          ),
                          selected: _fallbackToPool == true,
                          selectedColor: AppColors.blackCat,
                          backgroundColor: _requestSnow,
                          checkmarkColor: AppColors.snow,
                          onSelected: (_) =>
                              setState(() => _fallbackToPool = true),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: _fallbackToPool == true
                                ? AppColors.snow
                                : AppColors.blackCat,
                          ),
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.08),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text(
                            'No',
                            style: TextStyle(fontSize: 12),
                          ),
                          selected: _fallbackToPool == false,
                          selectedColor: AppColors.blackCat,
                          backgroundColor: _requestSnow,
                          checkmarkColor: AppColors.snow,
                          onSelected: (_) =>
                              setState(() => _fallbackToPool = false),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: _fallbackToPool == false
                                ? AppColors.snow
                                : AppColors.blackCat,
                          ),
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  _syncSelectedArtistForFilters();
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
              'Set your budget range for the request.',
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),

            const SizedBox(height: 10),
            _BudgetCard(
              minLabel: '\$15',
              maxLabel: '\$5000',
              values: _sanitizeBudgetRange(_clientBudget),
              onChanged: (v) =>
                  setState(() => _clientBudget = _sanitizeBudgetRange(v)),
              onChangeEnd: (v) => _saveBudgetToDb(_sanitizeBudgetRange(v)),
            ),

            const SizedBox(height: 18),

            const SizedBox(height: 14),

            // shipping checkbox BEFORE submit
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _shippingDifferent,
                        onChanged: (v) =>
                            setState(() => _shippingDifferent = v ?? false),
                        activeColor: AppColors.blackCat,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
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
                      minHeight: 56,
                      verticalPadding: 8,
                      onChanged: (_) => setState(() {
                        _fieldErrors.remove('shipStreet');
                        _autofillShippingAddressFromStreet();
                      }),
                    ),
                    if (_shipStreetSuggestionsLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_shipStreetSuggestions.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final suggestionCount = _shipStreetSuggestions.length;
                          final menuHeight =
                              AutocompleteDropdownSizing.menuHeight(
                                itemCount: suggestionCount,
                                itemExtent: 40,
                              );
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: _requestSnow,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.20,
                                ),
                              ),
                            ),
                            constraints: BoxConstraints(maxHeight: menuHeight),
                            child: ListView.separated(
                              shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                                suggestionCount,
                              ),
                              physics: AutocompleteDropdownSizing.scrollPhysics(
                                suggestionCount,
                              ),
                              itemCount: suggestionCount,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                dense: true,
                                title: Text(
                                  _shipStreetSuggestions[i].displayLabel,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _applyShippingStreetSuggestion(
                                  _shipStreetSuggestions[i],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    _InlineError(text: _fieldErrors['shipStreet']),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipCityCtrl,
                      hint: 'City',
                      minHeight: 56,
                      verticalPadding: 8,
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
                        minHeight: 56,
                        verticalPadding: 8,
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
                        minHeight: 56,
                        verticalPadding: 8,
                        onChanged: (v) => _shipState = v,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipZipCtrl,
                      minHeight: 56,
                      verticalPadding: 8,
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
                      minHeight: 56,
                      verticalPadding: 8,
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
        bottomNavigationBar: widget.showClientBottomNav
            ? ClientBottomNavBar(
                currentIndex: 1, // ✅ Design selected on this page
                onTap: (i) async {
                  if (widget.onClientNavTap != null) {
                    await widget.onClientNavTap!(context, i);
                    return;
                  }
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => ClientShellPage(
                        profile: widget.profile,
                        initialIndex: i,
                        forceEnableAllTabs: true,
                        // keep artist preselected if going back to Design
                        initialArtistName:
                            null, // ✅ you said NO preselect in ClientCustomRequestPage
                      ),
                    ),
                    (route) => false,
                  );
                },
              )
            : null,
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

  //get _artists => null;
}

// ✅ Save budget to DB on slider release (implement your Firestore code here)
Future<void> _saveBudgetToDb(RangeValues v) async {}

enum OrderType { single, group }

/// -----------------
/// MODELS (local)
/// -----------------
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
            resolveCurrentUserFallback: true,
          ),
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
          onChanged: (text) {
            final normalizedText = text.trim();
            final matchesExisting = normalizedItems.any(
              (item) => item.toLowerCase() == normalizedText.toLowerCase(),
            );
            if (normalizedText.isEmpty || !matchesExisting) {
              onChanged('');
            }
          },
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

          // ✅ Single range text (no duplicates)
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

                // ✅ This removes the duplicate bubble/tooltip values
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
              size: 22, // ✅ smaller icon
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
  "Côte d'Ivoire",
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

/// Nail dimensions read-only card

class ClientBottomNavBar extends StatelessWidget {
  const ClientBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: AppColors.balletSlippers,
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.deepPlum,
      unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.55),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Design',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.brush_outlined),
          activeIcon: Icon(Icons.brush),
          label: 'Artists',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
