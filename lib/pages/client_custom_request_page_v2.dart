import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../services/artist_directory_service.dart';
import '../services/notifications_service.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../widgets/client_profile_avatar_icon.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/nail_preferences_inline_editor.dart';
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

/// ---------------------------------------------------------------------------
/// Client Custom Request Page V2 (Trendy UI)
/// - DOES NOT replace your existing ClientCustomRequestPage
/// - Keep current navigation unchanged
/// - Use this page later if you decide to switch based on client feedback
/// ---------------------------------------------------------------------------
class ClientCustomRequestPageV2 extends StatefulWidget {
  const ClientCustomRequestPageV2({
    super.key,
    required this.profile,
    this.initialArtistName,
    this.onBackHome,
    this.showBottomNav = false,
    this.bottomNavIndex = 1,
    this.onNavTap,
    this.isActiveTab = true,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final bool isActiveTab;

  /// If passed, artist dropdown will be pre-selected.
  final String? initialArtistName;

  @override
  State<ClientCustomRequestPageV2> createState() =>
      _ClientCustomRequestPageV2State();
}

class _ClientCustomRequestPageV2State extends State<ClientCustomRequestPageV2> {
  static const Color _focusRing = Color(0xFFFFBF47);
  static const int _maxImageSizeBytes = 2 * 1024 * 1024;
  static const int _maxInspirationPhotos = 10;
  // -----------------------
  // Existing fields (kept)
  // -----------------------
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _notificationsFocusNode = FocusNode(
    debugLabel: 'designV2Notifications',
  );
  final FocusNode _needByFocusNode = FocusNode(debugLabel: 'needByDateField');
  final FocusNode _descriptionFocusNode = FocusNode(
    debugLabel: 'descriptionField',
  );
  final Map<String, String> _fieldErrors = <String, String>{};
  bool _didSetInitialA11yFocus = false;
  bool _focusRequestQueued = false;
  DateTime? _needBy;

  bool _allowNonLicensed = true;
  RangeValues _budget = const RangeValues(500, 5000);

  OrderType _orderType = OrderType.single;

  String? _selectedArtist;
  bool _fallbackToPool = true;

  late String _shape;
  late NailLength _length;

  bool _shippingDifferent = false;
  final TextEditingController _shipStreetCtrl = TextEditingController();
  final TextEditingController _shipCityCtrl = TextEditingController();
  final TextEditingController _shipZipCtrl = TextEditingController();
  String _shipState = '';
  String _shipCountry = 'United States';

  // Group order clients (DB only)
  List<CompletedClient> _completedClients = <CompletedClient>[];
  bool _loadingCompletedClients = false;
  final List<GroupClientSelection> _groupSelections = [];
  static const int _maxGroupClients = 5;

  final List<String> _artistNames = [];

  // -----------------------
  // ✅ NEW fields from the “Company Request UI” (adapted for Client)
  // -----------------------
  String? _requestType; // required
  final TextEditingController _requestTitleCtrl =
      TextEditingController(); // campaign name equivalent
  String? _moodVibe; // required
  bool _includeLogo =
      false; // optional (client can use as "include initials/logo-like element")

  final TextEditingController _setsNeededCtrl = TextEditingController(
    text: '1',
  ); // required in UI
  String? _finish; // optional
  String? _priority; // optional (standard/rush)

  // Uploads (UI only placeholder)
  final List<String> _uploaded = []; // filenames mock
  final ImagePicker _picker = ImagePicker();
  final Map<String, XFile> _pickedPhotoFiles = <String, XFile>{};
  final Map<String, Uint8List> _pickedPhotoBytes = <String, Uint8List>{};
  bool _isSubmitting = false;

  // -----------------------
  // Init / Dispose
  // -----------------------
  @override
  void initState() {
    super.initState();

    _selectedArtist = widget.initialArtistName;

    final profileShape = widget.profile.nail.shape;
    final profileLength = widget.profile.nail.length;

    _shape = (profileShape.isNotEmpty)
        ? profileShape
        : (nailShapes.isNotEmpty ? nailShapes.first : 'Square');

    _length = (profileLength == NailLength.none)
        ? NailLength.medium
        : profileLength;

    _shipCountry = 'United States';

    // sensible defaults for new fields
    _requestType = requestTypes.first;
    _moodVibe = moods.first;
    _finish = finishes.first;
    _priority = priorities.first;
    unawaited(_loadArtistNames());
    unawaited(_loadCompletedClientsFromDb());
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
  void didUpdateWidget(covariant ClientCustomRequestPageV2 oldWidget) {
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
      final names =
          entries
              .map((e) => e.name.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      setState(() {
        _artistNames
          ..clear()
          ..addAll(names);
        if (_selectedArtist != null &&
            _selectedArtist!.isNotEmpty &&
            !_artistNames.contains(_selectedArtist)) {
          _selectedArtist = null;
        }
      });
    } catch (_) {}
  }

  Future<String> _resolveSelectedArtistEmail(String selectedArtist) async {
    final normalizedName = selectedArtist.trim().toLowerCase();
    if (normalizedName.isEmpty) return '';
    try {
      final artists = await ArtistDirectoryService.fetchAllArtists(
        hydrateMediaFallbacks: false,
      );
      for (final artist in artists) {
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

    final typeName = value.runtimeType.toString();

    if (typeName.contains('Timestamp')) {
      try {
        final dynamic dynamicValue = value;
        final DateTime date = dynamicValue.toDate() as DateTime;
        return date.toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }

    if (typeName.contains('FieldValue')) {
      return DateTime.now().toIso8601String();
    }

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
      _firstNonEmpty([cleanSummary['clientEmail'], widget.profile.basic.email, user?.email]),
      _firstNonEmpty([cleanSummary['clientName'], widget.profile.basic.name]),
      _firstNonEmpty([cleanSummary['selectedArtist'], cleanDetails['selectedArtist'], _asMap(cleanDetails['order'])['selectedArtist']]),
      _firstNonEmpty([cleanSummary['needBy'], _asMap(cleanDetails['requestDetails'])['needBy']]),
      _firstNonEmpty([cleanSummary['budgetMin'], _asMap(cleanDetails['budget'])['min']]),
      _firstNonEmpty([cleanSummary['budgetMax'], _asMap(cleanDetails['budget'])['max']]),
      _firstNonEmpty([cleanSummary['nailShape'], _asMap(cleanDetails['nailPreferences'])['shape']]),
      _firstNonEmpty([cleanSummary['nailLength'], _asMap(cleanDetails['nailPreferences'])['length']]),
      _firstNonEmpty([cleanSummary['descriptionPreview'], _asMap(cleanDetails['requestDetails'])['description']]),
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

    final generatedOrderNumber =
        'CR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final row = <String, dynamic>{
      'client_id': (user?.id ?? '').trim().isEmpty ? null : (user?.id ?? '').trim(),
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
        _asMap(cleanDetails['order'])['selectedArtist'],
      ]),
      'selected_artist_email': _firstNonEmpty([
        cleanSummary['selectedArtistEmail'],
        _asMap(cleanDetails['order'])['selectedArtistEmail'],
      ]).toLowerCase(),
      'status': _firstNonEmpty([cleanSummary['status'], 'pending']),
      'client_status': _firstNonEmpty([cleanSummary['clientStatus'], 'pending']),
      'artist_status': _firstNonEmpty([cleanSummary['artistStatus'], 'review']),
      'order_number': _firstNonEmpty([cleanSummary['orderNumber'], generatedOrderNumber]),
      'summary': cleanSummary,
      'details': cleanDetails,
      'inspiration_photos': cleanSummary['inspirationPhotos'] ?? const <String>[],
      'photo_count': cleanSummary['photoCount'] ?? 0,
      'has_inspiration_photos': cleanSummary['hasInspirationPhotos'] ?? false,
      'photo_upload_status': cleanSummary['hasInspirationPhotos'] == true ? 'pending' : 'none',
      'photo_upload_attempt': 0,
      'created_at': nowIso,
      'updated_at': nowIso,
      'photo_upload_updated_at': nowIso,
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
    final supabase = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();

    final payload = <String, dynamic>{
      'updated_at': nowIso,
    };

    void putIfPresent(String key) {
      if (clean.containsKey(key)) {
        payload[key] = clean[key];
      }
    }

    for (final key in const <String>[
      'client_id',
      'client_email',
      'client_name',
      'selected_artist',
      'selected_artist_email',
      'status',
      'client_status',
      'artist_status',
      'order_number',
      'inspiration_photos',
      'photo_count',
      'has_inspiration_photos',
      'photo_upload_status',
      'photo_upload_error',
      'photo_upload_attempt',
      'photo_upload_updated_at',
      'cancel_reason',
      'cancelled_at',
      'accepted_by_artist_email',
      'accepted_by_artist_name',
      'artist_profile_image',
      'artist_final_amount',
      'payment_status',
      'payment_link',
      'paid_at',
      'design_approval_status',
      'design_approved_at',
      'design_submitted_at',
      'design_approval_due_at',
      'design_reminder_sent_at',
      'design_preview_photos',
      'artist_completed_photos',
      'shipped_by_courier',
      'tracking_number',
      'shipped_at',
      'delivered_at',
    ]) {
      putIfPresent(key);
    }

    if (clean.containsKey('summary') || clean.containsKey('details')) {
      final existing = await supabase
          .from('client_custom_requests')
          .select('summary, details')
          .eq('id', requestId)
          .maybeSingle();

      final existingMap = existing == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existing as Map);

      if (clean.containsKey('summary')) {
        payload['summary'] = {
          ..._asMap(existingMap['summary']),
          ..._asMap(clean['summary']),
        };
      }

      if (clean.containsKey('details')) {
        final existingDetails = _asMap(existingMap['details']);
        final incomingDetails = _asMap(clean['details']);
        final mergedDetails = <String, dynamic>{
          ...existingDetails,
          ...incomingDetails,
        };

        if (existingDetails['requestDetails'] is Map ||
            incomingDetails['requestDetails'] is Map) {
          mergedDetails['requestDetails'] = {
            ..._asMap(existingDetails['requestDetails']),
            ..._asMap(incomingDetails['requestDetails']),
          };
        }

        payload['details'] = mergedDetails;
      }
    }

    await supabase
        .from('client_custom_requests')
        .update(payload)
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
          final rows = await supabase.from(table).select().limit(200);
          if (rows is List) {
            allRows.addAll(
              rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(growable: false),
            );
          }
        } catch (e) {
          debugPrint('CLIENT CUSTOM REQUEST V2 client load failed [$table]: $e');
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
            : _asMap(data['nail_preferences']).isNotEmpty
            ? _asMap(data['nail_preferences'])
            : _asMap(client['nailPreferences']).isNotEmpty
            ? _asMap(client['nailPreferences'])
            : _asMap(client['nail_preferences']);
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
            slot.draftNails = null;
            slot.savedNails = null;
          }
        }
      });
    } catch (e) {
      debugPrint('CLIENT CUSTOM REQUEST V2 completed clients load failed: $e');
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
    _dateCtrl.dispose();
    _descCtrl.dispose();
    _shipStreetCtrl.dispose();
    _shipCityCtrl.dispose();
    _shipZipCtrl.dispose();
    _requestTitleCtrl.dispose();
    _setsNeededCtrl.dispose();
    _needByFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _notificationsFocusNode.dispose();
    super.dispose();
  }

  // -----------------------
  // Avatar menu
  // -----------------------
  void _onAvatarMenuSelected(String value) {
    if (value == 'logout') {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // -----------------------
  // Date picker (kept)
  // -----------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final initialDate = _needBy ?? now.add(const Duration(days: 3));
    await showDialog<void>(
      context: context,
      builder: (ctx) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Select need by date',
        child: Dialog(
          backgroundColor: AppColors.snow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330, maxHeight: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.blackCat,
                    onPrimary: Colors.white,
                    surface: AppColors.snow,
                    onSurface: Colors.black,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: initialDate.isBefore(firstDate)
                      ? firstDate
                      : initialDate,
                  firstDate: firstDate,
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
    );
  }

  Future<void> _saveBudgetToDb(RangeValues v) async {
    // TODO: Firestore integration if needed
  }

  // -----------------------
  // Group helpers (kept)
  // -----------------------
  CompletedClient? _findClient(String? id) {
    if (id == null) return null;
    try {
      return _completedClients.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
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
    setState(() => _groupSelections.removeAt(index));
  }

  Future<void> _onSelectClientForSlot(int index, String? clientId) async {
    if (clientId != null &&
        _isClientSavedInAnotherSlot(currentIndex: index, clientId: clientId)) {
      await _showDuplicateClientDialog();
      if (!mounted) return;
      setState(() {});
      return;
    }
    final client = _findClient(clientId);

    setState(() {
      _groupSelections[index].clientId = clientId;

      if (client != null) {
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
        _groupSelections[index].draftNails = null;
        _groupSelections[index].savedNails = null;
      }
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

  // -----------------------
  // ✅ NEW: Save Draft (UI placeholder)
  // -----------------------
  void _saveDraft() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft saved (mock).')));
  }

  Future<void> _pickFromGallery() async {
    final remainingSlots = _maxInspirationPhotos - _uploaded.length;
    if (remainingSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can upload up to 10 inspiration photos.'),
          ),
        );
      }
      return;
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 65,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked.isEmpty) return;
    final accepted = <XFile>[];
    var rejectedCount = 0;
    for (final file in picked) {
      final size = await file.length();
      if (size > _maxImageSizeBytes) {
        rejectedCount++;
        continue;
      }
      accepted.add(file);
    }
    if (accepted.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file is larger than 2 MB.')),
        );
      }
      return;
    }
    final acceptedToAdd = accepted.take(remainingSlots).toList(growable: false);
    setState(() {
      for (final file in acceptedToAdd) {
        _uploaded.add(file.path);
        _pickedPhotoFiles[file.path] = file;
      }
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
  }

  Future<void> _pickFromCamera() async {
    if (_uploaded.length >= _maxInspirationPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can upload up to 10 inspiration photos.'),
          ),
        );
      }
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 65,
      maxWidth: 1200,
      maxHeight: 1200,
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
      _uploaded.add(picked.path);
      _pickedPhotoFiles[picked.path] = picked;
    });
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

    for (final raw in _uploaded) {
      if (_isStableRemoteImage(raw)) {
        add(raw);
      }
    }

    for (final raw in _uploaded) {
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

  Future<void> _snapshotPickedPhotoBytes() async {
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

  Future<List<String>> _uploadInspirationPhotos({
    required List<String> uploaded,
    required Map<String, XFile> pickedPhotoFiles,
    required Map<String, Uint8List> pickedPhotoBytes,
  }) async {
    if (uploaded.isEmpty) return const <String>[];

    final supabase = Supabase.instance.client;
    final userKey = _safeRequestStorageKey(
      Supabase.instance.client.auth.currentUser?.id ??
          widget.profile.basic.email,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];

    for (var i = 0; i < uploaded.length && urls.length < 10; i++) {
      final raw = uploaded[i].trim();
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

    return urls.where((e) => e.trim().isNotEmpty).take(10).toList(growable: false);
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
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

  // -----------------------
  // Submit (extends existing validations)
  // -----------------------
  Future<void> _submitRequest() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final needByDate = _resolveNeedByDate();
    final needByOk = needByDate != null;
    final descOk = _descCtrl.text.trim().isNotEmpty;
    final inspoOk = _buildInitialInspirationPhotos().isNotEmpty;

    // NEW required: request type + mood/vibe + sets needed + request title
    final requestTypeOk = (_requestType ?? '').trim().isNotEmpty;
    final moodOk = (_moodVibe ?? '').trim().isNotEmpty;
    final titleOk = _requestTitleCtrl.text.trim().isNotEmpty;
    final setsOk =
        int.tryParse(_setsNeededCtrl.text.trim()) != null &&
        int.parse(_setsNeededCtrl.text.trim()) > 0;

    bool shipOk = true;
    if (_shippingDifferent) {
      shipOk =
          _shipStreetCtrl.text.trim().isNotEmpty &&
          _shipCityCtrl.text.trim().isNotEmpty &&
          _shipState.trim().isNotEmpty &&
          _shipZipCtrl.text.trim().isNotEmpty &&
          _shipCountry.trim().isNotEmpty;
    }

    if (!needByOk) {
      setState(() {
        _isSubmitting = false;
        _fieldErrors
          ..clear()
          ..['needBy'] = 'Need By Date is required';
      });
      _needByFocusNode.requestFocus();
      SemanticsService.announce(
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
      SemanticsService.announce(
        'Description is required',
        Directionality.of(context),
      );
      return;
    }
    if (!inspoOk ||
        !shipOk ||
        !requestTypeOk ||
        !moodOk ||
        !titleOk ||
        !setsOk) {
      final errors = <String, String>{};
      setState(() {
        _isSubmitting = false;
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      final missing = <String>[];
      if (!titleOk) missing.add('Request Title');
      if (!inspoOk) missing.add('Inspiration Photos');
      if (!requestTypeOk) missing.add('Request Type');
      if (!moodOk) missing.add('Mood/Vibe');
      if (!setsOk) missing.add('Sets Needed');
      if (_shippingDifferent) {
        if (_shipStreetCtrl.text.trim().isEmpty) missing.add('Shipping Street');
        if (_shipCityCtrl.text.trim().isEmpty) missing.add('Shipping City');
        if (_shipState.trim().isEmpty) missing.add('Shipping State');
        if (_shipZipCtrl.text.trim().isEmpty) missing.add('Shipping Zip');
        if (_shipCountry.trim().isEmpty) missing.add('Shipping Country');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing.isEmpty
                ? 'Please complete all required fields.'
                : 'Please complete: ${missing.join(', ')}',
          ),
        ),
      );
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
      dimensions: widget.profile.nail.dimensions,
      shape: _shape,
      length: _length,
    );
    final now = DateTime.now();
    final setsNeeded = int.parse(_setsNeededCtrl.text.trim());

    final needBy = needByDate.toIso8601String();
    final title = _requestTitleCtrl.text.trim();
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
    final requestSummary = <String, dynamic>{
      'requestType': 'clientCustomRequest',
      'status': 'pending',
      'clientStatus': 'pending',
      'artistStatus': 'review',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'clientSubmittedAtLocal': now.toIso8601String(),
      'needBy': needBy,
      'needByDisplay': _dateCtrl.text.trim(),
      'title': title,
      'descriptionPreview': description.length > 140
          ? '${description.substring(0, 140)}...'
          : description,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'orderType': _orderType.name,
      'selectedArtist': selectedArtist,
      'selectedArtistEmail': selectedArtistEmail,
      'isDirectRequest': isDirectRequest,
      'allowNonLicensed': _allowNonLicensed,
      'fallbackToPool': _fallbackToPool,
      'nailShape': _shape,
      'nailLength': _length.name,
      'isGroupOrder': isGroupOrder,
      'groupClientCount': groupClients.length,
      'photoCount': 0,
      'hasInspirationPhotos': false,
      'priority': _priority ?? '',
      'moodVibe': _moodVibe ?? '',
      'finish': _finish ?? '',
      'clientName': widget.profile.basic.name,
      'clientEmail': widget.profile.basic.email,
    };

    final requestDetails = <String, dynamic>{
      'requestDetails': {
        'needBy': needBy,
        'needByDisplay': _dateCtrl.text.trim(),
        'description': description,
        'title': title,
      },
      'budget': {'min': budgetMin, 'max': budgetMax},
      'order': {
        'type': _orderType.name,
        'allowNonLicensed': _allowNonLicensed,
        'selectedArtist': selectedArtist,
        'selectedArtistEmail': selectedArtistEmail,
        'isDirectRequest': isDirectRequest,
        'fallbackToPool': _fallbackToPool,
      },
      'roleStatuses': {'client': 'pending', 'artist': 'review'},
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
      'v2Fields': {
        'requestTypeLabel': _requestType ?? '',
        'moodVibe': _moodVibe ?? '',
        'includeLogo': _includeLogo,
        'setsNeeded': setsNeeded,
        'finish': _finish ?? '',
        'priority': _priority ?? '',
      },
      'inspirationPhotos': const <String>[],
      'clientProfileSnapshot': _profileSnapshotToMap(widget.profile),
    };

    try {
      await _snapshotPickedPhotoBytes();
      final initialPhotos = _buildInitialInspirationPhotos();
      requestSummary['photoCount'] = initialPhotos.length;
      requestSummary['hasInspirationPhotos'] = initialPhotos.isNotEmpty;
      requestDetails['inspirationPhotos'] = initialPhotos;
      final requestId = await _createSupabaseClientCustomRequest(
        summary: requestSummary,
        details: requestDetails,
      );
      try {
        await NotificationsService.notifyArtistsForNewClientRequest(
          clientName: widget.profile.basic.name,
          isDirectRequest: isDirectRequest,
          selectedArtistEmail: selectedArtistEmail,
          selectedArtistName: selectedArtist,
          orderId: requestId,
          sourceCollection: 'Client_Custom_Requests',
          allowNonLicensed: _allowNonLicensed,
        );
      } catch (e) {
        debugPrint('CLIENT CUSTOM REQUEST NOTIFICATION FAILED: $e');
      }

      if (_pickedPhotoFiles.isNotEmpty) {
        final uploadedSnapshot = List<String>.from(_uploaded);
        final pickedPhotoFilesSnapshot = Map<String, XFile>.from(
          _pickedPhotoFiles,
        );
        final pickedPhotoBytesSnapshot = Map<String, Uint8List>.from(
          _pickedPhotoBytes,
        );
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
              uploadedSnapshot: uploadedSnapshot,
              pickedPhotoFilesSnapshot: pickedPhotoFilesSnapshot,
              pickedPhotoBytesSnapshot: pickedPhotoBytesSnapshot,
            );
          }),
        );
      }

      if (!mounted) return;
      await _showSubmittedDialog();
      if (!mounted) return;
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
    required List<String> uploadedSnapshot,
    required Map<String, XFile> pickedPhotoFilesSnapshot,
    required Map<String, Uint8List> pickedPhotoBytesSnapshot,
  }) async {
    try {
      await _updateSupabaseClientCustomRequest(requestId, {
        'photo_upload_status': 'uploading',
        'photo_upload_worker_started_at': DateTime.now().toIso8601String(),
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
            uploadedSnapshot: uploadedSnapshot,
            pickedPhotoFilesSnapshot: pickedPhotoFilesSnapshot,
            pickedPhotoBytesSnapshot: pickedPhotoBytesSnapshot,
          );

          await _updateSupabaseClientCustomRequest(requestId, {
            'photo_upload_status': 'completed',
            'photo_upload_error': null,
            'photo_upload_completed_at': DateTime.now().toIso8601String(),
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
        'photo_upload_failed_at': DateTime.now().toIso8601String(),
        'photo_upload_updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabasePhotoUpload] worker fatal error: $e');
    }
  }

  Future<void> _uploadAndAttachPhotos(
    String requestId, {
    required List<String> uploadedSnapshot,
    required Map<String, XFile> pickedPhotoFilesSnapshot,
    required Map<String, Uint8List> pickedPhotoBytesSnapshot,
  }) async {
    final existingRemoteCount = uploadedSnapshot
        .where(_isStableRemoteImage)
        .length;
    final selectedLocalCount = uploadedSnapshot
        .where((p) => pickedPhotoFilesSnapshot.containsKey(p))
        .length;

    final photos = await _uploadInspirationPhotos(
      uploaded: uploadedSnapshot,
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
          backgroundColor: AppColors.alabaster,
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

  // -----------------------
  // UI helpers
  // -----------------------
  List<NailLength> get _lengthOptions => const <NailLength>[
    NailLength.xlLong,
    NailLength.short,
    NailLength.medium,
    NailLength.long,
    NailLength.extraLong,
  ];

  String _lengthTitle(NailLength l) {
    switch (l) {
      case NailLength.xlLong:
        return 'Extra Short';
      case NailLength.short:
        return 'Short';
      case NailLength.medium:
        return 'Medium';
      case NailLength.long:
        return 'Long';
      case NailLength.extraLong:
        return 'Extra Long';
      case NailLength.none:
        return 'Select';
    }
  }

  String _lengthImage(NailLength l) {
    switch (l) {
      case NailLength.short:
        return 'assets/images/length_short.png';
      case NailLength.medium:
        return 'assets/images/length_medium.png';
      case NailLength.long:
        return 'assets/images/length_long.png';
      case NailLength.extraLong:
        return 'assets/images/length_extra_long.png';
      case NailLength.xlLong:
        return 'assets/images/length_xl_long.png';
      case NailLength.none:
        return 'assets/images/length_short.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = widget.profile.nail.dimensions;
    final baseTheme = Theme.of(context);
    final pageTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.alabaster,
      canvasColor: AppColors.snow,
      colorScheme: baseTheme.colorScheme.copyWith(surface: AppColors.snow),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(AppColors.snow),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.snow),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.snow,
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
          backgroundColor: AppColors.snow,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          toolbarHeight: 76,
          automaticallyImplyLeading: false,
          leadingWidth: 58,
          leading: NotificationBellButton(
            onTap: () => NotificationsPage.showAsModal(context),
            focusNode: _notificationsFocusNode,
            iconSize: 22,
          ),
          centerTitle: true,
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: 50,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _AvatarMenu(
                onSelected: _onAvatarMenuSelected,
                avatarUrl: widget.profile.basic.profileImageUrl,
                displayName: widget.profile.basic.name,
              ),
            ),
          ],
        ),

        // Trendy "modal-like" container feel
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
          children: [
            _ModalShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Request Custom Nails',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.zero,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppColors.blackCat.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Tell artists what you're looking for. Your profile nail sizing stays synced.",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Request Type + Title (NEW)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Request Basics',
                    subtitle: 'Fast details to match you with the right artist',
                  ),
                  const SizedBox(height: 12),

                  _LabelReq('Request Type'),
                  const SizedBox(height: 8),
                  _DropdownField(
                    value: _requestType,
                    hint: 'Select Request Type',
                    items: requestTypes,
                    onChanged: (v) => setState(() => _requestType = v),
                  ),

                  const SizedBox(height: 14),
                  _LabelReq('Request Title'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _requestTitleCtrl,
                    hint: 'Ex: Birthday set, Wedding week, Vacation nails…',
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LabelReq('Mood / Vibe'),
                            const SizedBox(height: 8),
                            _DropdownField(
                              value: _moodVibe,
                              hint: 'Select vibe',
                              items: moods,
                              onChanged: (v) => setState(() => _moodVibe = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LabelReq('Sets Needed'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _setsNeededCtrl,
                              hint: '1',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _ToggleRow(
                    title: 'Include logo / initials?',
                    subtitle: 'Optional: add a logo-like element or initials',
                    value: _includeLogo,
                    onChanged: (v) => setState(() => _includeLogo = v),
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Request Details (Existing)
                  const SizedBox(height: 14),
                  Semantics(
                    header: true,
                    sortKey: const OrdinalSortKey(10),
                    child: _SectionTitle(
                      'Request Details',
                      subtitle: 'Timing + description',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _LabelReq('Need By Date'),
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
                        ),
                      ),
                    ),
                  ),
                  if ((_fieldErrors['needBy'] ?? '').trim().isNotEmpty)
                    ExcludeSemantics(
                      child: _InlineError(text: _fieldErrors['needBy']),
                    ),

                  const SizedBox(height: 14),
                  _LabelReq('Description'),
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
                  if ((_fieldErrors['description'] ?? '').trim().isNotEmpty)
                    ExcludeSemantics(
                      child: _InlineError(text: _fieldErrors['description']),
                    ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Uploads (Existing + NEW "brand files" feel)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Uploads',
                    subtitle: 'At least 1 inspiration photo is required',
                  ),
                  const SizedBox(height: 10),

                  _PillInfo(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Upload at least 1 inspiration photo. If you have reference files, attach them too.',
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _SoftButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          onTap: _pickFromGallery,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SoftButton(
                          icon: Icons.photo_camera_outlined,
                          label: 'Camera',
                          onTap: _pickFromCamera,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SoftButtonWide(
                    icon: Icons.file_present_rounded,
                    label: 'Upload Files (PDF/PNG)',
                    onTap: () {
                      setState(
                        () => _uploaded.add(
                          'brand_file_${_uploaded.length + 1}.pdf',
                        ),
                      );
                    },
                  ),

                  if (_uploaded.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _uploaded
                          .take(6)
                          .map(
                            (f) => Chip(
                              label: Text(
                                _fileNameFromPath(f),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: AppColors.blackCat.withOpacity(
                                0.08,
                              ),
                              side: BorderSide(
                                color: AppColors.blackCat.withOpacity(0.18),
                              ),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              onDeleted: () => setState(() {
                                _uploaded.remove(f);
                                _pickedPhotoFiles.remove(f);
                                _pickedPhotoBytes.remove(f);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 12),
                  _CardLite(
                    child: Row(
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
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Allow non-licensed nail technicians to work on your design?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.75),
                                height: 1.2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Budget + Priority (Existing + NEW priority)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Budget + Priority',
                    subtitle: 'Match to the right talent & timeline',
                  ),
                  const SizedBox(height: 10),

                  _BudgetCard(
                    values: _budget,
                    onChanged: (v) => setState(() => _budget = v),
                    onChangeEnd: _saveBudgetToDb,
                  ),

                  const SizedBox(height: 14),
                  _LabelOpt('Priority'),
                  const SizedBox(height: 8),
                  _DropdownField(
                    value: _priority,
                    hint: 'Select Priority',
                    items: priorities,
                    onChanged: (v) => setState(() => _priority = v),
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Order type (Existing)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Type of Order',
                    subtitle: 'Single or group request',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RadioPill(
                          selected: _orderType == OrderType.single,
                          label: 'Single Order',
                          onTap: () =>
                              setState(() => _orderType = OrderType.single),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RadioPill(
                          selected: _orderType == OrderType.group,
                          label: 'Group Order',
                          onTap: () =>
                              setState(() => _orderType = OrderType.group),
                        ),
                      ),
                    ],
                  ),

                  // Group order UI (kept - compact but same logic)
                  if (_orderType == OrderType.group) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Group Clients (up to 5)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.blackCat,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_loadingCompletedClients)
                      _CardLite(
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
                                color: Colors.black.withOpacity(0.65),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_completedClients.isEmpty)
                      _CardLite(
                        child: Text(
                          'No completed client profiles found in database.',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      )
                    else if (_groupSelections.isEmpty)
                      _CardLite(
                        child: Text(
                          'Add clients to the group order. Only clients with completed profiles appear here.',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    ...List.generate(_groupSelections.length, (i) {
                      final slot = _groupSelections[i];
                      final selectedClient = _findClient(slot.clientId);
                      final draft = slot.draftNails;
                      final saved = slot.savedNails != null;

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _CardLite(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Client ${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _removeClientSlot(i),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                initialValue: slot.clientId,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Colors.black.withOpacity(0.45),
                                ),
                                decoration: _ddDeco('Select Client'),
                                items: <DropdownMenuItem<String>>[
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(
                                      'Select one',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  ..._completedClients.map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => _onSelectClientForSlot(
                                  i,
                                  (v == null || v.isEmpty) ? null : v,
                                ),
                              ),

                              if (selectedClient == null || draft == null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Select a client to view nail dimensions and edit preferences.',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.60),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              if (selectedClient != null && draft != null) ...[
                                const SizedBox(height: 12),
                                NailPreferencesInlineEditor(
                                  initial: draft,
                                  showMeasurementTips: false,
                                  showDimensionImages: false,
                                  showNfcOptions: true,
                                  nailDimensionBorderColor: AppColors.blackCat
                                      .withOpacity(0.25),
                                  onChanged: (updated) {
                                    setState(() {
                                      slot.draftNails = updated;
                                      slot.savedNails = null;
                                    });
                                  },
                                ),

                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: saved
                                          ? Colors.green
                                          : AppColors.blackCat,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                    onPressed: () => _saveSlot(i),
                                    child: Text(
                                      saved
                                          ? 'Saved ✅'
                                          : 'Save Client Preferences',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
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

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Specific artist (Existing)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Artist Selection',
                    subtitle: 'Request a specific artist (optional)',
                  ),
                  const SizedBox(height: 12),

                  _LabelOpt('Artist'),
                  const SizedBox(height: 8),
                  _SearchableSelectField(
                    value: _selectedArtist ?? '',
                    hint: 'Select Artist',
                    items: _artistNames,
                    onChanged: (v) => setState(
                      () =>
                          _selectedArtist = v.trim().isEmpty ? null : v.trim(),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'If the artist cannot complete the request, do you want it to go into the request pool?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.75),
                      height: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Yes'),
                        selected: _fallbackToPool == true,
                        selectedColor: AppColors.blackCat,
                        onSelected: (_) =>
                            setState(() => _fallbackToPool = true),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _fallbackToPool == true
                              ? AppColors.snow
                              : AppColors.blackCat,
                        ),
                        side: BorderSide(color: Colors.black.withOpacity(0.08)),
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
                        onSelected: (_) =>
                            setState(() => _fallbackToPool = false),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _fallbackToPool == false
                              ? AppColors.snow
                              : AppColors.blackCat,
                        ),
                        side: BorderSide(color: Colors.black.withOpacity(0.08)),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Nail dims + choices (Existing + NEW Finish)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Nail Preferences',
                    subtitle: 'These guide the design + sizing',
                  ),
                  const SizedBox(height: 12),

                  _NailDimensionsReadOnlyCard(dimensions: dims),
                  const SizedBox(height: 12),

                  const Text(
                    'Nail Shape',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 122,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nailShapes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final s = nailShapes[i];
                        final selected = s == _shape;
                        return _ShapeCard(
                          label: s,
                          selected: selected,
                          onTap: () => setState(() => _shape = s),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Nail Length',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 138,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _lengthOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final len = _lengthOptions[i];
                        final selected = _length == len;
                        return _LengthImageCard(
                          title: _lengthTitle(len),
                          imageAsset: _lengthImage(len),
                          selected: selected,
                          onTap: () => setState(() => _length = len),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  _LabelOpt('Finish'),
                  const SizedBox(height: 8),
                  _DropdownField(
                    value: _finish,
                    hint: 'Select Finish',
                    items: finishes,
                    onChanged: (v) => setState(() => _finish = v),
                  ),

                  const SizedBox(height: 16),
                  _DividerLine(),

                  // Shipping (Existing)
                  const SizedBox(height: 14),
                  _SectionTitle(
                    'Shipping',
                    subtitle: 'Use profile address or override',
                  ),
                  const SizedBox(height: 10),

                  _CardLite(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.scale(
                          scale: 0.95,
                          child: Checkbox(
                            value: _shippingDifferent,
                            onChanged: (v) =>
                                setState(() => _shippingDifferent = v ?? false),
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
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.75),
                                height: 1.2,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_shippingDifferent) ...[
                    const SizedBox(height: 12),
                    _CardLite(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabelReq('Shipping Address'),
                          const SizedBox(height: 10),
                          _InputField(
                            controller: _shipStreetCtrl,
                            hint: 'Street',
                          ),
                          const SizedBox(height: 12),
                          _InputField(controller: _shipCityCtrl, hint: 'City'),
                          const SizedBox(height: 12),
                          _SearchableSelectField(
                            value: _shipState,
                            hint: 'State',
                            items: usStates,
                            onChanged: (v) => setState(() => _shipState = v),
                          ),
                          const SizedBox(height: 12),
                          _InputField(controller: _shipZipCtrl, hint: 'Zip'),
                          const SizedBox(height: 12),
                          _SearchableSelectField(
                            value: _shipCountry,
                            hint: 'Country',
                            items: countries,
                            onChanged: (v) => setState(
                              () => _shipCountry = v.trim().isEmpty
                                  ? 'United States'
                                  : v,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Footer actions like screenshot: Save Draft + Submit
                  Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.black.withOpacity(0.12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: _isSubmitting ? null : _saveDraft,
                            child: const Text(
                              'Save Draft',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: Colors.white,
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
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Submit Request',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),

        bottomNavigationBar: widget.showBottomNav
            ? BottomNavigationBar(
                currentIndex: widget.bottomNavIndex,
                selectedItemColor: AppColors.blackCat,
                unselectedItemColor: Colors.black.withOpacity(0.35),
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
                    icon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline),
                    label: 'Design',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inbox_outlined),
                    label: 'Requests',
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
}

/// ---------------------------------------------------------------------------
/// Models (same as existing)
/// ---------------------------------------------------------------------------
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
  GroupClientSelection({this.clientId, this.draftNails, this.savedNails});
}

/// ---------------------------------------------------------------------------
/// New dropdown options (from UI mock)
/// ---------------------------------------------------------------------------
const List<String> requestTypes = [
  'Birthday / Party',
  'Wedding / Bridal',
  'Vacation / Trip',
  'Everyday Set',
  'Event / Special',
  'Other',
];

const List<String> moods = [
  'Minimal / Clean',
  'Luxury',
  'Bold',
  'Cute',
  'Edgy',
  'Glam',
  'Neutral',
  'Seasonal',
];

const List<String> finishes = [
  'Glossy',
  'Matte',
  'Chrome',
  'Glitter',
  'Jelly',
  'Pearl',
];

const List<String> priorities = ['Standard (5–7 days)', 'Rush (2–3 days)'];

/// ---------------------------------------------------------------------------
/// UI Components (trendy + matches your theme)
/// ---------------------------------------------------------------------------

class _ModalShell extends StatelessWidget {
  const _ModalShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.black.withOpacity(0.06));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackCat.withOpacity(0.55),
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          height: 26,
          width: 26,
          decoration: BoxDecoration(
            color: AppColors.blackCat.withOpacity(0.10),
            borderRadius: BorderRadius.zero,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.blackCat.withOpacity(0.70),
          ),
        ),
      ],
    );
  }
}

class _LabelReq extends StatelessWidget {
  const _LabelReq(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        const Text(
          '*',
          style: TextStyle(
            color: Color(0xFFE05A5A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LabelOpt extends StatelessWidget {
  const _LabelOpt(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

class _PillInfo extends StatelessWidget {
  const _PillInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCat.withOpacity(0.06),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blackCat.withOpacity(0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.55),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.blackCat,
            inactiveThumbColor: AppColors.blackCatLight,
            inactiveTrackColor: AppColors.blackCatLight.withOpacity(0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

InputDecoration _ddDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 12.5,
      color: Colors.black.withOpacity(0.35),
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: AppColors.snow,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
      borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
    ),
  );
}

class _CardLite extends StatelessWidget {
  const _CardLite({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      itemHeight: kMinInteractiveDimension,
      menuMaxHeight: 280,
      dropdownColor: AppColors.snow,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 18,
        color: Colors.black.withOpacity(0.45),
      ),
      decoration: _ddDeco(hint),
      items: items
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(
                s,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SearchableSelectField extends StatelessWidget {
  const _SearchableSelectField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedItems = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value.trim()),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: Colors.black.withOpacity(0.35),
              fontWeight: FontWeight.w600,
            ),
            isDense: true,
            filled: true,
            fillColor: AppColors.snow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            constraints: const BoxConstraints(minHeight: 52),
            suffixIcon: Icon(
              Icons.search_rounded,
              size: 16,
              color: Colors.black.withOpacity(0.45),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(
                color: AppColors.blackCatBorderLight,
              ),
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
              color: AppColors.snow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(color: AppColors.blackCatBorderLight),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.onTap,
    this.focusNode,
    this.errorText,
  });
  final TextEditingController controller;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'MM/DD/YYYY',
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: Colors.black.withOpacity(0.35),
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.snow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        suffixIcon: Icon(
          Icons.calendar_month_rounded,
          size: 18,
          color: Colors.black.withOpacity(0.45),
        ),
        errorText: (errorText ?? '').trim().isEmpty ? null : errorText,
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
          borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: Colors.black.withOpacity(0.35),
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.snow,
        errorText: (errorText ?? '').trim().isEmpty ? null : errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: const BoxConstraints(minHeight: 52),
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
          borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
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

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: Colors.black.withOpacity(0.35),
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.snow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: const BoxConstraints(minHeight: 52),
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
          borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.blackCat.withOpacity(0.9)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftButtonWide extends StatelessWidget {
  const _SoftButtonWide({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.blackCat.withOpacity(0.08),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.blackCat.withOpacity(0.95)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.values,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues> onChangeEnd;

  String _fmtMoney(double v) => '\$${v.round()}';

  @override
  Widget build(BuildContext context) {
    final start = values.start;
    final end = values.end;
    final currentText =
        '${_fmtMoney(start)} - ${end >= 5000 ? '\$5000+' : _fmtMoney(end)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentText,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(
              sliderTheme: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.blackCat,
                inactiveTrackColor: Colors.black.withOpacity(0.10),
                thumbColor: AppColors.blackCat,
                overlayColor: AppColors.blackCat.withOpacity(0.10),
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 9,
                ),
                trackHeight: 3.2,
                showValueIndicator: ShowValueIndicator.never,
              ),
            ),
            child: RangeSlider(
              min: 500,
              max: 5000,
              divisions: 4500,
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
    final bg = selected ? AppColors.blackCat.withOpacity(0.10) : AppColors.snow;
    final border = selected
        ? AppColors.blackCat
        : Colors.black.withOpacity(0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 38,
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
              size: 18,
              color: selected
                  ? AppColors.blackCat
                  : Colors.black.withOpacity(0.35),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _NailDimensionsReadOnlyCard extends StatelessWidget {
  const _NailDimensionsReadOnlyCard({required this.dimensions});
  final NailDimensions dimensions;

  String _mm(double? v) {
    if (v == null || !v.isFinite) return '-';
    return '${v.toStringAsFixed(0)} mm';
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }

  Widget _nfcMark(bool selected) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 0.7,
            child: IgnorePointer(
              child: Checkbox(
                value: selected,
                onChanged: (_) {},
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.blackCat,
                checkColor: AppColors.snow,
              ),
            ),
          ),
          const Text(
            'NFC',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _handRow(
    String title,
    List<String> labels,
    List<double?> values,
    List<bool> nfcValues,
  ) {
    return Column(
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            return SizedBox(
              width: 62,
              child: Column(
                children: [
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 46,
                    width: 34,
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: AppColors.blackCat.withOpacity(0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (values[i] != null && values[i]! >= 8)
                    _nfcMark(nfcValues[i]),
                  _pill(_mm(values[i])),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CardLite(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nail Dimension (mm)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Measurement tips: use a soft tape or ruler; enter width in mm.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          _handRow(
            'Left Hand',
            const ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'],
            [
              dimensions.lThumb,
              dimensions.lIndex,
              dimensions.lMiddle,
              dimensions.lRing,
              dimensions.lPinky,
            ],
            [
              dimensions.lThumbNfc,
              dimensions.lIndexNfc,
              dimensions.lMiddleNfc,
              dimensions.lRingNfc,
              dimensions.lPinkyNfc,
            ],
          ),
          const SizedBox(height: 18),
          _handRow(
            'Right Hand',
            const ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'],
            [
              dimensions.rThumb,
              dimensions.rIndex,
              dimensions.rMiddle,
              dimensions.rRing,
              dimensions.rPinky,
            ],
            [
              dimensions.rThumbNfc,
              dimensions.rIndexNfc,
              dimensions.rMiddleNfc,
              dimensions.rRingNfc,
              dimensions.rPinkyNfc,
            ],
          ),
        ],
      ),
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.blackCat.withOpacity(0.10) : Colors.white;
    final border = selected
        ? AppColors.blackCat
        : Colors.black.withOpacity(0.10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.front_hand_outlined,
                size: 20,
                color: selected
                    ? AppColors.blackCat
                    : Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LengthImageCard extends StatelessWidget {
  const _LengthImageCard({
    required this.title,
    required this.imageAsset,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String imageAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.blackCat.withOpacity(0.10) : Colors.white;
    final border = selected
        ? AppColors.blackCat
        : Colors.black.withOpacity(0.10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: border, width: selected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                imageAsset,
                height: 58,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.zero,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Avatar dropdown (same pattern)
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.onSelected,
    this.avatarUrl = '',
    this.displayName = '',
  });
  final ValueChanged<String> onSelected;
  final String avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 55),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'logout',
          height: 38,
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.blackCat),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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

/// ---------------------------------------------------------------------------
/// Location lists (reuse from your current page to keep behavior identical)
/// ---------------------------------------------------------------------------
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
  'United States',
  'United Kingdom',
  'Canada',
  'Australia',
  'India',
  'Germany',
  'France',
  'Mexico',
  'Brazil',
  'Japan',
  'South Korea',
  // keep your full list here if you want exact parity; trimmed for brevity in V2
];
