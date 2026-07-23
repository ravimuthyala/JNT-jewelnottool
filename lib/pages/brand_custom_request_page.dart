// lib/pages/brand_custom_request_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/profile_table_columns.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart'
    show ClientProfileDraft, NailLength, nailShapes;
import '../widgets/autocomplete_dropdown_sizing.dart';
import '../widgets/company_shell_chrome.dart';
import '../services/address_validation_service.dart';
import '../services/artist_directory_service.dart';
import '../services/notifications_service.dart';
import '../utils/scenario_4_1.dart';

const Color _requestSnow = Color(0xFFFAF9F9);
final BorderSide _requestBorder = BorderSide(
  color: AppColors.blackCat.withValues(alpha: 0.35),
);

const int _maxInspirationPhotos = 10;
const int _nfcBudgetSurcharge = 7;

enum _ClientRecipientMode { pool, specificClient, groupClients }

enum _DesignCreatorMode { pool, specificArtist }

String scenario21ClientReceiveOnSubmit({
  required String orderRef,
  required String brandCompany,
  required String campaignName,
}) {
  return scenario41ClientReceiveOnSubmit(
    orderRef: orderRef,
    brandCompany: brandCompany,
    campaignName: campaignName,
  );
}

String scenario31BrandReceiveOnClientAcceptance({
  required String clientName,
  required String campaignName,
  required String orderRef,
}) {
  return scenario41BrandReceiveOnClientAcceptance(
    clientName: clientName,
    campaignName: campaignName,
    orderRef: orderRef,
  );
}

String scenario31ArtistPoolReceiveOnClientAcceptance({
  required String orderRef,
  required String clientName,
  required String brandName,
  required String campaignName,
}) {
  return '${scenario41DirectArtistReceiveOnClientAcceptance(orderRef: orderRef, clientName: clientName, brandName: brandName, campaignName: campaignName)}.';
}

String scenario31BrandReceiveOnArtistAcceptance({
  required String artistName,
  required String campaignName,
  required String orderRef,
  required String clientName,
}) {
  return '${scenario41BrandReceiveOnArtistAcceptance(artistName: artistName, campaignName: campaignName, orderRef: orderRef, clientName: clientName)}.';
}

String scenario31DirectClientReceiveOnArtistAcceptance({
  required String campaignName,
  required String orderRef,
  required String artistName,
}) {
  return '${scenario41DirectClientReceiveOnArtistAcceptance(campaignName: campaignName, orderRef: orderRef, artistName: artistName)}.';
}

bool hasReachedSponsorshipRequestStatus(Map<String, dynamic> data) {
  String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
  bool isRequested(String value) =>
      value == 'sponsorship request' ||
      value == 'sponsorship_request' ||
      value == 'requested';

  final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
  final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
  final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
  final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
  final sponsorshipRequest =
      (data['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};
  final profileSponsorship =
      (profile['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};
  final artistSponsorship =
      (artist['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};
  final basicSponsorship =
      (basic['sponsorshipRequest'] as Map<String, dynamic>?) ?? const {};

  final statuses = <String>[
    norm(data['sponsorshipStatus']),
    norm(data['panel_sponsorshipStatus']),
    norm(data['status']),
    norm(ascension['status']),
    norm(sponsorshipRequest['status']),
    norm(profileSponsorship['status']),
    norm(artistSponsorship['status']),
    norm(basicSponsorship['status']),
  ];
  for (final status in statuses) {
    if (isRequested(status)) return true;
  }
  return false;
}

bool isEligibleBrandRequestArtist(Map<String, dynamic> data) {
  String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
  String normalizedTier(Object? value) =>
      norm(value).replaceAll('_', ' ').replaceAll('-', ' ');
  bool eligibleTier(Object? value) {
    final tier = normalizedTier(value);
    return tier == 'goldsmith' || tier == 'crowned';
  }

  final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
  final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
  final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
  final ascension = (data['ascension'] as Map<String, dynamic>?) ?? const {};
  final stats = (data['stats'] as Map<String, dynamic>?) ?? const {};
  final profileAscension =
      (profile['ascension'] as Map<String, dynamic>?) ?? const {};
  final artistAscension =
      (artist['ascension'] as Map<String, dynamic>?) ?? const {};
  final basicAscension =
      (basic['ascension'] as Map<String, dynamic>?) ?? const {};

  final values = <Object?>[
    data['ascensionLevel'],
    data['ascension_level'],
    data['ascensionTier'],
    data['ascension_tier'],
    data['tier'],
    data['panel_ascensionLevel'],
    data['panel_ascensionTier'],
    data['overrideTier'],
    data['override_tier'],
    ascension['level'],
    ascension['tier'],
    ascension['currentTier'],
    ascension['current_tier'],
    ascension['overrideTier'],
    ascension['override_tier'],
    profileAscension['level'],
    profileAscension['tier'],
    artistAscension['level'],
    artistAscension['tier'],
    basicAscension['level'],
    basicAscension['tier'],
    profile['tier'],
    artist['tier'],
    basic['tier'],
    stats['tier'],
  ];

  return values.any(eligibleTier);
}

bool isBrandPartnerClient(Map<String, dynamic> data) {
  String norm(Object? value) => (value ?? '').toString().trim().toLowerCase();
  String normalizedStatus(Object? value) =>
      norm(value).replaceAll('_', ' ').replaceAll('-', ' ');
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

  final statuses = <String>[
    norm(ascension['status']),
    norm(ascension['partnerStatus']),
    norm(profileAscension['status']),
    norm(profileAscension['partnerStatus']),
    norm(basicAscension['status']),
    norm(basicAscension['partnerStatus']),
    norm(clientAscension['status']),
    norm(clientAscension['partnerStatus']),
    norm(data['status']),
    norm(data['partnerStatus']),
    norm(data['tier']),
    norm(profile['status']),
    norm(profile['partnerStatus']),
    norm(profile['tier']),
    norm(basic['status']),
    norm(basic['partnerStatus']),
    norm(basic['tier']),
    norm(client['status']),
    norm(client['partnerStatus']),
    norm(client['tier']),
  ];
  for (final status in statuses) {
    final normalized = normalizedStatus(status);
    if (normalized == 'ambassador') {
      return true;
    }
  }
  return false;
}

class _UploadedReferenceImage {
  const _UploadedReferenceImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class BrandCustomRequestPage extends StatefulWidget {
  const BrandCustomRequestPage({
    super.key,
    required this.profile,
    this.onBackHome,
    this.companyName,
    this.initialRequestedArtist,
    this.defaultSpecificArtistSelection = false,
    this.artistOptions,
    this.onOpenProfile,
    this.onLogout,
    this.showBottomNav = false,
    this.bottomNavIndex = 1,
    this.onNavTap,
  });

  final ClientProfileDraft profile;
  final VoidCallback? onBackHome;
  final String? companyName;
  final String? initialRequestedArtist;
  final bool defaultSpecificArtistSelection;
  final List<String>? artistOptions;
  final VoidCallback? onOpenProfile;
  final Future<void> Function()? onLogout;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;

  @override
  State<BrandCustomRequestPage> createState() => _BrandCustomRequestPageState();
}

class _BrandCustomRequestPageState extends State<BrandCustomRequestPage> {
  // -----------------------------
  // Request details
  // -----------------------------
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _revealDateCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  DateTime? _needBy;
  DateTime? _jntRevealDate;

  // -----------------------------
  // Company fields
  // -----------------------------
  final TextEditingController _campaignNameCtrl = TextEditingController();
  final TextEditingController _setsNeededCtrl = TextEditingController();
  String? _requestedClient;
  String? _requestedArtist;
  bool _fallbackToPool = true;
  int _quantity = 1;
  bool _shippingAddressDifferentFromProfile = false;
  _ClientRecipientMode _clientRecipientMode = _ClientRecipientMode.pool;
  _DesignCreatorMode _designCreatorMode = _DesignCreatorMode.pool;
  List<String> _brandPartnerClients = <String>[];
  List<String> _directRequestArtists = <String>[];
  final Map<String, String> _clientEmailByNameLower = <String, String>{};
  final Map<String, bool> _clientNfcEligibleByNameLower = <String, bool>{};
  bool _nfcRequest = false;
  String _groupClientToAdd = '';
  // Bumped whenever _groupClientToAdd is cleared programmatically (add,
  // duplicate-add, or eligibility invalidation) so the "Select clients"
  // field's key can reset just that field's text -- without also keying on
  // the in-progress query text itself, which would tear the field down on
  // every keystroke.
  int _groupClientFieldResetTick = 0;
  final List<String> _groupSelectedClients = <String>[];
  final TextEditingController _shipStreetCtrl = TextEditingController();
  final TextEditingController _shipCityCtrl = TextEditingController();
  final TextEditingController _shipStateCtrl = TextEditingController();
  final TextEditingController _shipZipCtrl = TextEditingController();
  final TextEditingController _shipCountryCtrl = TextEditingController(
    text: 'United States',
  );
  final FocusNode _campaignNameFocusNode = FocusNode(
    debugLabel: 'campaignNameField',
  );
  final FocusNode _requestedClientFocusNode = FocusNode(
    debugLabel: 'requestedClientField',
  );
  final FocusNode _groupClientFocusNode = FocusNode(
    debugLabel: 'groupClientField',
  );
  final FocusNode _requestedArtistFocusNode = FocusNode(
    debugLabel: 'requestedArtistField',
  );
  Timer? _shipStreetAutocompleteDebounce;
  List<AddressSuggestion> _shipStreetSuggestions = const [];
  bool _shipStreetSuggestionsLoading = false;

  // Uploads
  final ImagePicker _picker = ImagePicker();
  final List<_UploadedReferenceImage> _uploadedFiles = [];
  bool _isSubmitting = false;
  String? _pendingRequestDocId;

  // -----------------------------
  // Budget
  // -----------------------------
  RangeValues _clientBudget = const RangeValues(15, 5000);
  RangeValues _artistBudget = const RangeValues(15, 5000);

  // -----------------------------
  // Nail selections (prefilled)
  // -----------------------------
  late String _shape;
  late NailLength _length;

  late final ClientProfileDraft _profile;

  @override
  void initState() {
    super.initState();

    // âœ… Correct: pull from widget.profile
    _profile = widget.profile;

    final profileShape = _profile.nail.shape;
    final profileLength = _profile.nail.length;

    _shape = (profileShape.isNotEmpty)
        ? profileShape
        : (nailShapes.isNotEmpty ? nailShapes.first : 'Square');

    _length = (profileLength == NailLength.none)
        ? NailLength.medium
        : profileLength;

    // _finish = _finishes.first;
    final initialArtist = widget.initialRequestedArtist?.trim() ?? '';
    _requestedArtist = initialArtist.isEmpty ? null : initialArtist;
    if (widget.defaultSpecificArtistSelection &&
        (_requestedArtist ?? '').trim().isNotEmpty) {
      _designCreatorMode = _DesignCreatorMode.specificArtist;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_campaignNameFocusNode);
    });
    unawaited(_loadSelectionSources());
  }

  @override
  void dispose() {
    _shipStreetAutocompleteDebounce?.cancel();
    _dateCtrl.dispose();
    _revealDateCtrl.dispose();
    _descCtrl.dispose();
    _campaignNameCtrl.dispose();
    _setsNeededCtrl.dispose();
    _shipStreetCtrl.dispose();
    _shipCityCtrl.dispose();
    _shipStateCtrl.dispose();
    _shipZipCtrl.dispose();
    _shipCountryCtrl.dispose();
    _campaignNameFocusNode.dispose();
    _requestedClientFocusNode.dispose();
    _groupClientFocusNode.dispose();
    _requestedArtistFocusNode.dispose();
    super.dispose();
  }

  void _focusAfterBuild(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(node);
    });
  }

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
      _shipCountryCtrl.text = 'United States';
      _shipStateCtrl.text =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      _shipStreetSuggestions = const [];
    });
  }

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields — resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectShippingStreetSuggestion(AddressSuggestion selected) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyShippingStreetSuggestion(resolved);
        return;
      }
    }
    _applyShippingStreetSuggestion(selected);
  }

  SupabaseClient get _client => Supabase.instance.client;

  User? get _currentUser => _client.auth.currentUser;

  String get _uid => (_currentUser?.id ?? '').trim();

  String get _authEmail => (_currentUser?.email ?? '').trim().toLowerCase();

  dynamic get _companyCustomRequestsStorage =>
      _client.storage.from('company-custom-requests');

  void _closeAfterSuccessfulSubmit() {
    if (!mounted) return;

    if (widget.onBackHome != null) {
      widget.onBackHome!.call();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (widget.onNavTap != null) {
      widget.onNavTap!(0);
    }
  }

  String _snake(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m.group(1)}_${m.group(2)}',
        )
        .replaceAll('-', '_')
        .toLowerCase();
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

  String _generateRequestId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final parts = <String>[
      bytes.take(4).map(hex).join(),
      bytes.skip(4).take(2).map(hex).join(),
      bytes.skip(6).take(2).map(hex).join(),
      bytes.skip(8).take(2).map(hex).join(),
      bytes.skip(10).take(6).map(hex).join(),
    ];
    return parts.join('-');
  }

  String _normalizeStorageUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    if (text.startsWith('gs://')) return text;
    if (text.startsWith('data:image/')) return text;
    return _companyCustomRequestsStorage.getPublicUrl(text).trim();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final minDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 7));
    final initialDate = _needBy != null && !_needBy!.isBefore(minDate)
        ? _needBy!
        : minDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _requestSnow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.92)),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.blackCat,
                    onPrimary: Colors.white,
                    surface: _requestSnow,
                    onSurface: AppColors.blackCat,
                  ),
                  datePickerTheme: const DatePickerThemeData(
                    headerHeadlineStyle: TextStyle(fontSize: 16),
                    weekdayStyle: TextStyle(fontSize: 11),
                    dayStyle: TextStyle(fontSize: 12),
                    yearStyle: TextStyle(fontSize: 12),
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
                      if (_jntRevealDate != null &&
                          !_jntRevealDate!.isAfter(_needBy!)) {
                        _jntRevealDate = null;
                        _revealDateCtrl.clear();
                      }
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

  DateTime? _tryParseMmDdYyyy(String raw) {
    final text = raw.trim();
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
      return null;
    }
    final dt = DateTime(year, month, day);
    if (dt.month != month || dt.day != day || dt.year != year) return null;
    return dt;
  }

  Future<void> _pickRevealDate() async {
    if (_needBy == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.snow,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'Need By Date Required',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
          content: const Text(
            'Please select Need By Date first before choosing JNT Reveal Date.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.blackCat,
            ),
          ),
          actions: [
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: AppColors.snow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }
    final now = DateTime.now();
    final firstDate = DateTime(
      _needBy!.year,
      _needBy!.month,
      _needBy!.day,
    ).add(const Duration(days: 1));
    final initialDate =
        _jntRevealDate != null && !_jntRevealDate!.isBefore(firstDate)
        ? _jntRevealDate!
        : firstDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _requestSnow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.92)),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.blackCat,
                    onPrimary: Colors.white,
                    surface: _requestSnow,
                    onSurface: AppColors.blackCat,
                  ),
                  datePickerTheme: const DatePickerThemeData(
                    headerHeadlineStyle: TextStyle(fontSize: 16),
                    weekdayStyle: TextStyle(fontSize: 11),
                    dayStyle: TextStyle(fontSize: 12),
                    yearStyle: TextStyle(fontSize: 12),
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: now.add(const Duration(days: 365 * 2)),
                  onDateChanged: (picked) {
                    setState(() {
                      _jntRevealDate = picked;
                      _revealDateCtrl.text =
                          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
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

  Future<void> _uploadReferenceImages() async {
    final remainingSlots = _maxInspirationPhotos - _uploadedFiles.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 inspiration photos.'),
        ),
      );
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final pickedToAdd = picked.take(remainingSlots).toList(growable: false);

    final uploaded = await Future.wait(
      pickedToAdd.map((x) async {
        final bytes = await x.readAsBytes();
        return _UploadedReferenceImage(name: x.name, bytes: bytes);
      }),
    );

    if (!mounted) return;
    setState(() {
      _uploadedFiles.addAll(uploaded);
    });

    if (picked.length > pickedToAdd.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extra photos were skipped. Maximum is 10.'),
        ),
      );
    }
  }

  Future<void> _captureReferenceImage() async {
    if (_uploadedFiles.length >= _maxInspirationPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 inspiration photos.'),
        ),
      );
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    if (!mounted) return;
    setState(() {
      _uploadedFiles.add(
        _UploadedReferenceImage(name: picked.name, bytes: bytes),
      );
    });
  }

  String _pickFirstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _clientDisplayName(Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final clientProfile =
        (client['profile'] as Map<String, dynamic>?) ?? const {};
    final company = (data['company'] as Map<String, dynamic>?) ?? const {};
    String clean(String raw) {
      var value = raw.trim();
      if (value.isEmpty) return '';
      if (value.contains('@')) return '';
      value = value.replaceFirst(
        RegExp(r'^\s*client\s+', caseSensitive: false),
        '',
      );
      return value;
    }

    String pick(Map<String, dynamic> source, List<String> keys) {
      return clean(_pickFirstString(source, keys));
    }

    for (final source in <Map<String, dynamic>>[
      profile,
      basic,
      clientProfile,
      client,
      data,
      company,
    ]) {
      final name = pick(source, const [
        'fullName',
        'full_name',
        'name',
        'displayName',
        'clientName',
        'panel_displayName',
        'panel_display_name',
        'panel_name',
      ]);
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  String _clientEmail(Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};
    final client = (data['client'] as Map<String, dynamic>?) ?? const {};
    final email = _pickFirstString(data, const ['email']).isNotEmpty
        ? _pickFirstString(data, const ['email'])
        : _pickFirstString(profile, const ['email']).isNotEmpty
        ? _pickFirstString(profile, const ['email'])
        : _pickFirstString(basic, const ['email']).isNotEmpty
        ? _pickFirstString(basic, const ['email'])
        : _pickFirstString(client, const ['email']);
    return email.trim().toLowerCase();
  }

  bool _clientIsNfcEligible(Map<String, dynamic> data) {
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    double? mmValue(Object? raw) {
      if (raw is num) return raw.toDouble();
      final text = (raw ?? '').toString().trim().replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    bool hasEligibleDimension(Map<String, dynamic> dims) {
      const keys = <String>[
        'lThumb',
        'lIndex',
        'lMiddle',
        'lRing',
        'lPinky',
        'rThumb',
        'rIndex',
        'rMiddle',
        'rRing',
        'rPinky',
        'thumb',
        'index',
        'middle',
        'ring',
        'pinky',
      ];
      for (final key in keys) {
        final value = mmValue(dims[key]);
        if (value != null && value >= 8) return true;
      }
      return false;
    }

    final profile = asMap(data['profile']);
    final basic = asMap(data['basic']);
    final client = asMap(data['client']);
    // The client table's real column is the snake_case `nail_preferences`
    // (confirmed via the brand-outreach RPC's raw row shape) -- the
    // camelCase `nailPreferences` variants below are kept only in case some
    // other source (e.g. a legacy payload) uses that spelling instead.
    final nailPreferences = asMap(data['nail_preferences']);
    final nailPreferencesCamel = asMap(data['nailPreferences']);
    final profileNailPreferences = asMap(profile['nail_preferences']);
    final profileNailPreferencesCamel = asMap(profile['nailPreferences']);
    final basicNailPreferences = asMap(basic['nail_preferences']);
    final basicNailPreferencesCamel = asMap(basic['nailPreferences']);
    final clientNailPreferences = asMap(client['nail_preferences']);
    final clientNailPreferencesCamel = asMap(client['nailPreferences']);
    final apiNailMeasurements = asMap(data['apiNailMeasurements']);

    final dimensionMaps = <Map<String, dynamic>>[
      asMap(nailPreferences['dimensions']),
      asMap(nailPreferencesCamel['dimensions']),
      asMap(profileNailPreferences['dimensions']),
      asMap(profileNailPreferencesCamel['dimensions']),
      asMap(basicNailPreferences['dimensions']),
      asMap(basicNailPreferencesCamel['dimensions']),
      asMap(clientNailPreferences['dimensions']),
      asMap(clientNailPreferencesCamel['dimensions']),
      asMap(data['dimensions']),
      asMap(profile['dimensions']),
      asMap(basic['dimensions']),
      asMap(client['dimensions']),
      apiNailMeasurements,
    ];

    for (final dims in dimensionMaps) {
      if (hasEligibleDimension(dims)) return true;
    }

    if (data['nfcEligible'] == true ||
        data['nfc_eligible'] == true ||
        data['eligible_for_nfc'] == true ||
        data['eligibleForNfc'] == true ||
        profile['nfcEligible'] == true ||
        basic['nfcEligible'] == true ||
        client['nfcEligible'] == true ||
        nailPreferences['nfcEligible'] == true ||
        nailPreferences['eligibleForNfc'] == true) {
      return true;
    }

    return false;
  }

  int _effectiveClientBudgetMin() {
    final base = _clientBudget.start.round();
    return _nfcRequest ? base + _nfcBudgetSurcharge : base;
  }

  int _effectiveArtistBudgetMin() {
    final base = _artistBudget.start.round();
    return _nfcRequest ? base + _nfcBudgetSurcharge : base;
  }

  bool _isClientNameNfcEligible(String name) {
    return _clientNfcEligibleByNameLower[name.trim().toLowerCase()] == true;
  }

  List<String> get _nfcFilteredBrandPartnerClients {
    if (!_nfcRequest) return _brandPartnerClients;
    return _brandPartnerClients
        .where(_isClientNameNfcEligible)
        .toList(growable: false);
  }

  void _setNfcRequest(bool value) {
    setState(() {
      _nfcRequest = value;
      if (_nfcRequest) {
        final allowed = _nfcFilteredBrandPartnerClients
            .map((name) => name.toLowerCase())
            .toSet();
        if ((_requestedClient ?? '').trim().isNotEmpty &&
            !allowed.contains((_requestedClient ?? '').trim().toLowerCase())) {
          _requestedClient = null;
        }
        _groupSelectedClients.removeWhere(
          (name) => !allowed.contains(name.trim().toLowerCase()),
        );
        if (_groupClientToAdd.trim().isNotEmpty &&
            !allowed.contains(_groupClientToAdd.trim().toLowerCase())) {
          _groupClientToAdd = '';
          _groupClientFieldResetTick++;
        }
      }
    });
  }

  String _artistDisplayName(Map<String, dynamic> data) {
    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    final basic = (data['basic'] as Map<String, dynamic>?) ?? const {};

    String clean(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return '';
      if (value.contains('@')) return '';
      return value;
    }

    for (final source in <Map<String, dynamic>>[data, profile, artist, basic]) {
      final name = clean(
        _pickFirstString(source, const [
          'displayName',
          'nameOrStudio',
          'name',
          'fullName',
          'panel_displayName',
          'panel_display_name',
          'panel_name',
          'panel_nameOrStudio',
          'panel_fullName',
          'studioName',
          'panel_studio_name',
          'displayname',
          'studioname',
        ]),
      );
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  /*bool _artistAllowsDirectRequests(Map<String, dynamic> data) {
    bool asBool(Object? raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes';
    }

    final profile = (data['profile'] as Map<String, dynamic>?) ?? const {};
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    final availability =
        (data['availability'] as Map<String, dynamic>?) ?? const {};
    final artistAvailability =
        (artist['availability'] as Map<String, dynamic>?) ?? const {};

    return asBool(
      data['panel_directRequestsEnabled'] ??
          data['panel_artist_directRequestsEnabled'] ??
          availability['directRequestsEnabled'] ??
          profile['directRequestsEnabled'] ??
          artist['directRequestsEnabled'] ??
          artistAvailability['directRequestsEnabled'],
    );
  }*/

  bool _isBrandPartner(Map<String, dynamic> data) {
    return isBrandPartnerClient(data);
  }

  Future<List<Map<String, dynamic>>> _fetchTableRows(
    String table, {
    int limit = 300,
  }) async {
    // A direct select here silently returns nothing for `client` under RLS
    // (SELECT is restricted to your own row only, so a brand account can
    // never see other users' client rows) -- that's why "Designate a
    // specific client"/"Group Client" showed no eligible clients. The RPC
    // (see supabase/migrations/20260721210424_add_brand_outreach_rows_rpc.sql)
    // is SECURITY DEFINER and scoped to brand/company callers only, so it
    // bypasses that restriction safely. Falls back to the old direct select
    // if the RPC isn't available yet (e.g. migration not applied) or fails
    // for any other reason, matching prior behavior rather than erroring.
    try {
      final rpcRows = await _client.rpc(
        'fetch_role_rows_for_brand_outreach',
        params: {'p_table': table, 'p_limit': limit},
      );
      if (rpcRows is List) {
        return rpcRows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('_fetchTableRows RPC failed for $table, falling back: $e');
    }

    try {
      final rows = await _client
          .from(table)
          .select(columnsForProfileTable(table) ?? '*')
          .limit(limit);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadSelectionSources() async {
    try {
      final emailByName = <String, String>{};
      final nfcEligibleByName = <String, bool>{};
      final clientNames = <String>{};
      final allClientNames = <String>{};
      final clientRows = <Map<String, dynamic>>[];
      for (final table in const <String>['client', 'client_artist']) {
        clientRows.addAll(await _fetchTableRows(table));
      }
      for (final data in clientRows) {
        var name = _clientDisplayName(data).trim();
        if (name.isEmpty) {
          final email = _pickFirstString(data, const ['email']);
          if (email.contains('@')) {
            name = email.split('@').first.trim();
          }
        }
        if (name.isEmpty) continue;
        final email = _clientEmail(data);
        if (email.isNotEmpty) {
          emailByName.putIfAbsent(name.toLowerCase(), () => email);
        }
        nfcEligibleByName[name.toLowerCase()] = _clientIsNfcEligible(data);
        allClientNames.add(name);
        if (_isBrandPartner(data)) {
          clientNames.add(name);
        }
      }

      final artistNames = <String>{};
      final artistRows = <Map<String, dynamic>>[];
      for (final table in const <String>['artist', 'client_artist']) {
        artistRows.addAll(await _fetchTableRows(table));
      }
      for (final data in artistRows) {
        // Brand requests can only go to eligible artists: Goldsmith or Crowned.
        // This applies to both Artist Pool and Specific Artist selection.
        if (!isEligibleBrandRequestArtist(data)) continue;
        final name = _artistDisplayName(data).trim();
        if (name.isEmpty) continue;
        artistNames.add(name);
      }
      if (artistNames.isEmpty) {
        final artists = await ArtistDirectoryService.fetchAllArtists(
          hydrateMediaFallbacks: false,
        );
        artistNames.addAll(
          artists
              .where((a) {
                final tier = a.tierLabel.trim().toLowerCase();
                return tier == 'goldsmith' || tier == 'crowned';
              })
              .map((a) => a.name.trim())
              .where((n) => n.isNotEmpty && !n.contains('@')),
        );
      }

      if (!mounted) return;
      setState(() {
        _brandPartnerClients = clientNames.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        /*_allClients =
            (allClientNames.isEmpty ? _clientOptions.toSet() : allClientNames)
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));*/
        final allowed =
            (_nfcRequest
                    ? _nfcFilteredBrandPartnerClients
                    : _brandPartnerClients)
                .map((name) => name.toLowerCase())
                .toSet();
        if ((_requestedClient ?? '').trim().isNotEmpty &&
            !allowed.contains((_requestedClient ?? '').trim().toLowerCase())) {
          _requestedClient = null;
        }
        _groupSelectedClients.removeWhere(
          (name) => !allowed.contains(name.trim().toLowerCase()),
        );
        if (_groupClientToAdd.trim().isNotEmpty &&
            !allowed.contains(_groupClientToAdd.trim().toLowerCase())) {
          _groupClientToAdd = '';
          _groupClientFieldResetTick++;
        }
        _clientEmailByNameLower
          ..clear()
          ..addAll(emailByName);
        _clientNfcEligibleByNameLower
          ..clear()
          ..addAll(nfcEligibleByName);
        _directRequestArtists =
            (artistNames.isEmpty ? _artistOptions.toSet() : artistNames)
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    } catch (e) {
      debugPrint('_loadSelectionSources failed: $e');
      if (!mounted) return;
      setState(() {
        _brandPartnerClients = <String>[];
        //_allClients = _clientOptions;
        _requestedClient = null;
        _groupClientToAdd = '';
        _groupClientFieldResetTick++;
        _groupSelectedClients.clear();
        _clientEmailByNameLower.clear();
        _clientNfcEligibleByNameLower.clear();
        _directRequestArtists = _artistOptions;
      });
    }
  }

  dynamic _toSnakeCaseValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map(
        (key, innerValue) =>
            MapEntry(_snake(key), _toSnakeCaseValue(innerValue)),
      );
    }
    if (value is Map) {
      return value.map(
        (key, innerValue) =>
            MapEntry(_snake(key.toString()), _toSnakeCaseValue(innerValue)),
      );
    }
    if (value is List) {
      return value.map(_toSnakeCaseValue).toList(growable: false);
    }
    return value;
  }

  Map<String, dynamic> _snakeCaseMap(Map<String, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(_snake(key), _toSnakeCaseValue(value)),
    );
  }

  Future<Map<String, dynamic>?> _readCompanyRow() async {
    if (_uid.isEmpty && _authEmail.isEmpty) return null;
    try {
      if (_uid.isNotEmpty) {
        final rows = await _client
            .from('company')
            .select(kCompanyTableColumns)
            .eq('id', _uid)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      }
      if (_authEmail.isNotEmpty) {
        final rows = await _client
            .from('company')
            .select(kCompanyTableColumns)
            .eq('email', _authEmail)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _companyCustomRequestTableColumns(
    Map<String, dynamic> source,
  ) {
    final columns = Map<String, dynamic>.from(source)
      ..remove('admin')
      // These values must stay inside payload/details JSON. They are not
      // physical columns in public.company_custom_requests, so sending them
      // as top-level PostgREST fields causes PGRST204 schema-cache errors.
      ..remove('artistEligibilityRequiredTiers')
      ..remove('eligibleArtistEmails')
      // NFC routing values also live inside payload/details JSON only.
      // The company_custom_requests table does not have these physical columns.
      ..remove('nfcRequested')
      ..remove('requiresNfcEligibleClient')
      ..remove('nfcMaxChipsTotal')
      ..remove('nfcMaxChipsPerHand')
      ..remove('eligibleNfcClientEmails');
    return columns;
  }

  Future<String> _insertCompanyCustomRequestRow({
    required String requestId,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> details,
    required String companyUid,
  }) async {
    final summaryColumns = _companyCustomRequestTableColumns(summary);
    final payload = <String, dynamic>{
      ..._snakeCaseMap(summaryColumns),
      'id': requestId,
      'payload': summary,
      'details': details,
      'company_uid': companyUid,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('company_custom_requests').insert(payload);
    return requestId;
  }

  Future<void> _updateCompanyCustomRequestRow({
    required String requestId,
    required Map<String, dynamic> summaryUpdate,
    required Map<String, dynamic> detailsUpdate,
  }) async {
    final summaryColumns = _companyCustomRequestTableColumns(summaryUpdate);
    final payload = <String, dynamic>{
      ..._snakeCaseMap(summaryColumns),
      'payload': summaryUpdate,
      'details': detailsUpdate,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client
        .from('company_custom_requests')
        .update(payload)
        .eq('id', requestId);
  }

  Future<void> _showRequestInfoDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat,
          ),
        ),
        actions: [
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.snow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addGroupClientSelection() {
    final value = _groupClientToAdd.trim();
    if (value.isEmpty) return;
    if (_groupSelectedClients.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 15 clients only.')),
      );
      return;
    }
    if (_groupSelectedClients.any(
      (c) => c.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() {
        _groupClientToAdd = '';
        _groupClientFieldResetTick++;
      });
      unawaited(
        _showRequestInfoDialog(
          title: 'Client Already Added',
          message: '$value is already in your group client list.',
        ),
      );
      return;
    }
    setState(() {
      _groupSelectedClients.add(value);
      _groupClientToAdd = '';
      _groupClientFieldResetTick++;
    });
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting || _pendingRequestDocId != null) return;
    final campaignOk = _campaignNameCtrl.text.trim().isNotEmpty;
    final needByOk = _needBy != null;
    final descOk = _descCtrl.text.trim().isNotEmpty;
    final clientOk =
        _clientRecipientMode != _ClientRecipientMode.specificClient ||
        ((_requestedClient ?? '').trim().isNotEmpty);
    final groupOk =
        _clientRecipientMode != _ClientRecipientMode.groupClients ||
        _groupSelectedClients.length >= 2;
    final artistOk =
        _designCreatorMode != _DesignCreatorMode.specificArtist ||
        ((_requestedArtist ?? '').trim().isNotEmpty);
    final shippingOk =
        !_shippingAddressDifferentFromProfile ||
        (_shipStreetCtrl.text.trim().isNotEmpty &&
            _shipCityCtrl.text.trim().isNotEmpty &&
            _shipStateCtrl.text.trim().isNotEmpty &&
            _shipZipCtrl.text.trim().isNotEmpty &&
            _shipCountryCtrl.text.trim().isNotEmpty);
    final nfcHasEligibleRecipients =
        !_nfcRequest ||
        (_clientRecipientMode == _ClientRecipientMode.pool &&
            _nfcFilteredBrandPartnerClients.isNotEmpty) ||
        (_clientRecipientMode == _ClientRecipientMode.specificClient &&
            _isClientNameNfcEligible(_requestedClient ?? '')) ||
        (_clientRecipientMode == _ClientRecipientMode.groupClients &&
            _groupSelectedClients.every(_isClientNameNfcEligible));

    if (!campaignOk ||
        !needByOk ||
        !descOk ||
        !clientOk ||
        !groupOk ||
        !artistOk ||
        !shippingOk ||
        !nfcHasEligibleRecipients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Campaign Name, Need By Date, Description, required direct selections, and at least 2 group clients when using group mode. NFC requests require NFC-eligible clients only.',
          ),
        ),
      );
      return;
    }
    _setsNeededCtrl.text = _quantity.toString();

    setState(() => _isSubmitting = true);

    try {
      final dims = _profile.nail.dimensions;
      final city = _profile.address.city.trim();
      final state = _profile.address.state.trim();
      final location = (city.isEmpty && state.isEmpty)
          ? 'Unknown'
          : '${city.isEmpty ? '' : city}${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}${state.isEmpty ? '' : state}';

      final uid = _uid;
      final authEmail = _authEmail;
      final companyEmail = _profile.basic.email.trim().isNotEmpty
          ? _profile.basic.email.trim().toLowerCase()
          : authEmail;
      final companyName = (widget.companyName?.trim().isNotEmpty ?? false)
          ? widget.companyName!.trim()
          : (_profile.basic.name.trim().isNotEmpty
                ? _profile.basic.name.trim()
                : 'Brand Company');
      final shippingDifferent = _shippingAddressDifferentFromProfile;
      final shippingStreet = shippingDifferent
          ? _shipStreetCtrl.text.trim()
          : _profile.address.street.trim();
      final shippingCity = shippingDifferent
          ? _shipCityCtrl.text.trim()
          : _profile.address.city.trim();
      final shippingState = shippingDifferent
          ? _shipStateCtrl.text.trim()
          : _profile.address.state.trim();
      final shippingZip = shippingDifferent
          ? _shipZipCtrl.text.trim()
          : _profile.address.zip.trim();
      final shippingCountry = shippingDifferent
          ? _shipCountryCtrl.text.trim()
          : _profile.address.country.trim();
      final campaign = _campaignNameCtrl.text.trim();
      final isOpenToClientPool =
          _clientRecipientMode == _ClientRecipientMode.pool;
      final isOpenToArtistPool = _designCreatorMode == _DesignCreatorMode.pool;
      final isDirectToArtist =
          _designCreatorMode == _DesignCreatorMode.specificArtist;
      final orderTypeValue =
          _clientRecipientMode == _ClientRecipientMode.groupClients
          ? 'group'
          : 'single';
      final orderTypeLabel = orderTypeValue == 'group' ? 'Group' : 'Single';
      final requestTypeLabel = _computeRequestTypeLabel(
        isOpenToClientPool: isOpenToClientPool,
        isOpenToArtistPool: isOpenToArtistPool,
        orderTypeValue: orderTypeValue,
      );
      final whoReceivesOrder = _whoReceivesOrderLabel(_clientRecipientMode);
      final whoCreatesDesign = _whoCreatesDesignLabel(_designCreatorMode);
      final fallbackToPool = isOpenToArtistPool || _fallbackToPool;
      final selectedArtist = (_requestedArtist ?? '').trim();
      final selectedArtistEmail = isDirectToArtist
          ? await _resolveSelectedArtistEmail(
              selectedArtist,
            ).timeout(const Duration(seconds: 10), onTimeout: () => '')
          : '';
      final eligibleArtistEmails = isDirectToArtist
          ? <String>[
              if (selectedArtistEmail.trim().isNotEmpty)
                selectedArtistEmail.trim().toLowerCase(),
            ]
          : await _loadEligibleBrandArtistEmails().timeout(
              const Duration(seconds: 12),
              onTimeout: () => <String>[],
            );
      final selectedClient = (_requestedClient ?? '').trim();
      final selectedClientEmail = isOpenToClientPool
          ? ''
          : await _resolveSelectedClientEmail(
              selectedClient,
            ).timeout(const Duration(seconds: 10), onTimeout: () => '');
      final selectedGroupClientEmails =
          _clientRecipientMode == _ClientRecipientMode.groupClients
          ? await _resolveGroupClientEmails(
              _groupSelectedClients,
            ).timeout(const Duration(seconds: 12), onTimeout: () => <String>[])
          : const <String>[];
      final nfcEligibleClientEmails = _nfcRequest
          ? await _resolveGroupClientEmails(
              _nfcFilteredBrandPartnerClients,
            ).timeout(const Duration(seconds: 12), onTimeout: () => <String>[])
          : const <String>[];
      final effectiveClientBudgetMin = _effectiveClientBudgetMin();
      final effectiveClientBudgetMax = _clientBudget.end.round();
      final effectiveArtistBudgetMin = _effectiveArtistBudgetMin();
      final effectiveArtistBudgetMax = _artistBudget.end.round();

      final requestId = _generateRequestId();
      _pendingRequestDocId = requestId;
      final selectedPhotoCount = _uploadedFiles.length;
      final safeUploadUid = uid.trim().isEmpty ? 'unknown' : uid.trim();
      final plannedInspirationPhotos = List<String>.generate(
        selectedPhotoCount,
        (index) => _normalizeStorageUrl(
          '$safeUploadUid/$requestId/inspiration_${index + 1}.jpg',
        ),
        growable: false,
      );
      String companyBioSnapshot = '';
      String companySnapshotEmail = companyEmail;
      String companySnapshotName = companyName;
      try {
        final companyRow = await _readCompanyRow();
        if (companyRow != null) {
          Map<String, dynamic> asMap(dynamic value) {
            if (value is Map<String, dynamic>) return value;
            if (value is Map) {
              return value.map((key, value) => MapEntry(key.toString(), value));
            }
            return const <String, dynamic>{};
          }

          final nestedCompany = asMap(companyRow['company']);
          final nestedProfile = asMap(companyRow['profile']);
          final nestedBasic = asMap(companyRow['basic']);
          companyBioSnapshot = _firstNonEmpty([
            companyRow['panel_companyBio'],
            companyRow['panel_company_bio'],
            companyRow['companyBio'],
            companyRow['company_bio'],
            nestedCompany['bio'],
            nestedCompany['companyBio'],
            nestedCompany['company_bio'],
            nestedProfile['companyBio'],
            nestedProfile['company_bio'],
            nestedBasic['companyBio'],
            nestedBasic['company_bio'],
            companyRow['bio'],
            nestedProfile['bio'],
            nestedBasic['bio'],
          ]);
          companySnapshotEmail = _firstNonEmpty([
            companyRow['email'],
            companyRow['panel_contact_email'],
            companyRow['panel_company_email'],
            nestedCompany['contactEmail'],
            nestedCompany['email'],
            companyEmail,
          ]);
          companySnapshotName = _firstNonEmpty([
            companyRow['panel_company_name'],
            companyRow['company_name'],
            companyRow['brand_name'],
            nestedCompany['name'],
            nestedCompany['companyName'],
            companyName,
          ]);
        }
      } catch (_) {}
      // Do not fall back to the request description. Company Bio must come
      // from the brand/company registration profile only.
      final previewImage = plannedInspirationPhotos.isNotEmpty
          ? plannedInspirationPhotos.first
          : '';
      final orderNumber = _generateBrandOrderNumber(requestId);
      final requestAcceptBy = DateTime(
        _needBy!.year,
        _needBy!.month,
        _needBy!.day,
      ).subtract(const Duration(days: 5));
      final requestAcceptByDisplay =
          '${requestAcceptBy.month.toString().padLeft(2, '0')}/${requestAcceptBy.day.toString().padLeft(2, '0')}/${requestAcceptBy.year}';

      final summary = <String, dynamic>{
        'orderNumber': orderNumber,
        'admin': <String, dynamic>{'orderNumber': orderNumber},
        'requestType': 'companyCustomRequest',
        'status': 'pending',
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': 'pending',
        'title': campaign,
        'campaignName': campaign,
        'clientName': companyName,
        'companyName': companyName,
        'brandName': companyName,
        'clientEmail': companyEmail,
        'companyEmail': companyEmail,
        'companyUid': uid,
        'needBy': _needBy!.toIso8601String(),
        'requestAcceptBy': requestAcceptBy.toIso8601String(),
        'requestAcceptByDisplay': requestAcceptByDisplay,
        if (_jntRevealDate != null)
          'jntRevealDate': _jntRevealDate!.toIso8601String(),
        if (_jntRevealDate != null)
          'jntRevealDateDisplay': _revealDateCtrl.text.trim(),
        'descriptionPreview': _descCtrl.text.trim(),
        'budgetMin': effectiveArtistBudgetMin,
        'budgetMax': effectiveArtistBudgetMax,
        'clientBudgetMin': effectiveClientBudgetMin,
        'clientBudgetMax': effectiveClientBudgetMax,
        'artistBudgetMin': effectiveArtistBudgetMin,
        'artistBudgetMax': effectiveArtistBudgetMax,
        'isDirectRequest': isDirectToArtist,
        'fallbackToPool': fallbackToPool,
        'openToClientPool': isOpenToClientPool,
        'openToArtistPool': isOpenToArtistPool,
        'nfcRequested': _nfcRequest,
        'requiresNfcEligibleClient': _nfcRequest,
        'nfcMaxChipsTotal': _nfcRequest ? 2 : 0,
        'nfcMaxChipsPerHand': _nfcRequest ? 1 : 0,
        'eligibleNfcClientEmails': nfcEligibleClientEmails,
        'selectedArtist': isDirectToArtist ? selectedArtist : '',
        'selectedArtistEmail': selectedArtistEmail,
        'eligibleArtistEmails': eligibleArtistEmails,
        'artistEligibilityRequiredTiers': const <String>[
          'Goldsmith',
          'Crowned',
        ],
        'selectedClient': isOpenToClientPool ? '' : selectedClient,
        'selectedClientEmail': selectedClientEmail,
        'selectedGroupClientEmails': selectedGroupClientEmails,
        'orderType': orderTypeValue,
        'orderTypeLabel': orderTypeLabel,
        'requestTypeLabel': requestTypeLabel,
        'requestTypeDisplay': requestTypeLabel,
        'whoReceivesOrder': whoReceivesOrder,
        'whoCreatesDesign': whoCreatesDesign,
        'quantity': _quantity,
        'numberOfSets': _quantity,
        'hasInspirationPhotos': _uploadedFiles.isNotEmpty,
        'photoCount': _uploadedFiles.length,
        'photoUploadStatus': selectedPhotoCount > 0 ? 'pending' : 'none',
        'brandHasInspirationPhotos': plannedInspirationPhotos.isNotEmpty,
        'brandPhotoCount': plannedInspirationPhotos.length,
        'brandInspirationPhotos': plannedInspirationPhotos,
        'inspirationPhotos': plannedInspirationPhotos,
        if (previewImage.isNotEmpty) 'previewImage': previewImage,
        if (previewImage.isNotEmpty) 'previewImageAsset': previewImage,
        'clientLocation': location,
        'bio': _descCtrl.text.trim(),
        'companyBio': companyBioSnapshot,
        'panel_companyBio': companyBioSnapshot,
        'nailShape': _shape,
        'nailLength': _lengthTitle(_length),
        'nailPreferences': <String, dynamic>{
          'shape': _shape,
          'length': _lengthTitle(_length),
          'dimensions': <String, dynamic>{
            'lThumb': dims.lThumb,
            'lIndex': dims.lIndex,
            'lMiddle': dims.lMiddle,
            'lRing': dims.lRing,
            'lPinky': dims.lPinky,
            'rThumb': dims.rThumb,
            'rIndex': dims.rIndex,
            'rMiddle': dims.rMiddle,
            'rRing': dims.rRing,
            'rPinky': dims.rPinky,
            if (_nfcRequest) 'nfcRequested': true,
            if (_nfcRequest) 'requiresNfcEligibleClient': true,
          },
        },
        'clientProfileImage': _profile.basic.profileImageUrl.trim(),
        'shippingAddressDifferentFromProfile': shippingDifferent,
        'shippingStreet': shippingStreet,
        'shippingCity': shippingCity,
        'shippingState': shippingState,
        'shippingZip': shippingZip,
        'shippingCountry': shippingCountry,
        'shipping': <String, dynamic>{
          'isDifferentFromProfile': shippingDifferent,
          'street': shippingStreet,
          'city': shippingCity,
          'state': shippingState,
          'zip': shippingZip,
          'country': shippingCountry,
        },
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final details = <String, dynamic>{
        'status': 'pending',
        'brandStatus': 'pending',
        'clientStatus': 'pending',
        'artistStatus': 'pending',
        'orderNumber': orderNumber,
        'admin': <String, dynamic>{'orderNumber': orderNumber},
        'openToClientPool': isOpenToClientPool,
        'openToArtistPool': isOpenToArtistPool,
        'nfcRequested': _nfcRequest,
        'requiresNfcEligibleClient': _nfcRequest,
        'nfcMaxChipsTotal': _nfcRequest ? 2 : 0,
        'nfcMaxChipsPerHand': _nfcRequest ? 1 : 0,
        'eligibleNfcClientEmails': nfcEligibleClientEmails,
        'eligibleArtistEmails': eligibleArtistEmails,
        'artistEligibilityRequiredTiers': const <String>[
          'Goldsmith',
          'Crowned',
        ],
        'requestType': requestTypeLabel,
        'requestTypeLabel': requestTypeLabel,
        'orderType': orderTypeValue,
        'orderTypeLabel': orderTypeLabel,
        'whoReceivesOrder': whoReceivesOrder,
        'whoCreatesDesign': whoCreatesDesign,
        'requestDetails': <String, dynamic>{
          'campaignName': campaign,
          'description': _descCtrl.text.trim(),
          'needBy': _needBy!.toIso8601String(),
          'requestAcceptBy': requestAcceptBy.toIso8601String(),
          'requestAcceptByDisplay': requestAcceptByDisplay,
          if (_jntRevealDate != null)
            'jntRevealDate': _jntRevealDate!.toIso8601String(),
          if (_jntRevealDate != null)
            'jntRevealDateDisplay': _revealDateCtrl.text.trim(),
          'quantity': _quantity,
          'numberOfSets': _quantity,
          'brandInspirationPhotos': plannedInspirationPhotos,
          'inspirationPhotos': plannedInspirationPhotos,
          'uploadedReferenceNames': _uploadedFiles
              .map((file) => file.name)
              .toList(growable: false),
        },
        'brandInspirationPhotos': plannedInspirationPhotos,
        'inspirationPhotos': plannedInspirationPhotos,
        'companyProfileSnapshot': <String, dynamic>{
          'companyUid': uid,
          'companyEmail': companySnapshotEmail,
          'companyName': companySnapshotName,
          'panel_companyBio': companyBioSnapshot,
          'companyBio': companyBioSnapshot,
          'bio': companyBioSnapshot,
          'basic': <String, dynamic>{
            'name': companySnapshotName,
            'email': companySnapshotEmail,
          },
        },
        'budget': <String, dynamic>{
          'min': effectiveArtistBudgetMin,
          'max': effectiveArtistBudgetMax,
        },
        'clientBudget': <String, dynamic>{
          'min': effectiveClientBudgetMin,
          'max': effectiveClientBudgetMax,
        },
        'artistBudget': <String, dynamic>{
          'min': effectiveArtistBudgetMin,
          'max': effectiveArtistBudgetMax,
        },
        'order': <String, dynamic>{
          'type': orderTypeValue,
          'isDirectRequest': isDirectToArtist,
          'fallbackToPool': fallbackToPool,
          'openToClientPool': isOpenToClientPool,
          'openToArtistPool': isOpenToArtistPool,
          'nfcRequested': _nfcRequest,
          'requiresNfcEligibleClient': _nfcRequest,
          'eligibleNfcClientEmails': nfcEligibleClientEmails,
          'selectedArtist': isDirectToArtist ? selectedArtist : '',
          'selectedArtistEmail': selectedArtistEmail,
          'eligibleArtistEmails': eligibleArtistEmails,
          'artistEligibilityRequiredTiers': const <String>[
            'Goldsmith',
            'Crowned',
          ],
          'selectedClient': isOpenToClientPool ? '' : selectedClient,
          'selectedClientEmail': selectedClientEmail,
          'selectedGroupClientEmails': selectedGroupClientEmails,
        },
        'clientProfileSnapshot': <String, dynamic>{
          'basic': <String, dynamic>{
            'name': companyName,
            'email': companyEmail,
            'profileImageUrl': _profile.basic.profileImageUrl.trim(),
            'avatarUrl': _profile.basic.profileImageUrl.trim(),
          },
          'address': <String, dynamic>{
            'street': _profile.address.street.trim(),
            'city': _profile.address.city.trim(),
            'state': _profile.address.state.trim(),
            'zip': _profile.address.zip.trim(),
            'country': _profile.address.country.trim(),
          },
        },
        'shipping': <String, dynamic>{
          'isDifferentFromProfile': shippingDifferent,
          'street': shippingStreet,
          'city': shippingCity,
          'state': shippingState,
          'zip': shippingZip,
          'country': shippingCountry,
        },
        'nailPreferences': <String, dynamic>{
          'shape': _shape,
          'length': _lengthTitle(_length),
          'dimensions': <String, dynamic>{
            'lThumb': dims.lThumb,
            'lIndex': dims.lIndex,
            'lMiddle': dims.lMiddle,
            'lRing': dims.lRing,
            'lPinky': dims.lPinky,
            'rThumb': dims.rThumb,
            'rIndex': dims.rIndex,
            'rMiddle': dims.rMiddle,
            'rRing': dims.rRing,
            'rPinky': dims.rPinky,
            if (_nfcRequest) 'nfcRequested': true,
            if (_nfcRequest) 'requiresNfcEligibleClient': true,
          },
        },
        if (_clientRecipientMode == _ClientRecipientMode.groupClients)
          'groupOrder': <String, dynamic>{
            'clients': _groupSelectedClients
                .asMap()
                .entries
                .map(
                  (entry) => <String, dynamic>{
                    'slotIndex': entry.key + 1,
                    'clientId': '',
                    'clientName': entry.value,
                    'clientEmail': entry.key < selectedGroupClientEmails.length
                        ? selectedGroupClientEmails[entry.key]
                        : '',
                    'savedNails': <String, dynamic>{
                      'shape': _shape,
                      'length': _lengthTitle(_length),
                      'dimensions': <String, dynamic>{
                        'lThumb': dims.lThumb,
                        'lIndex': dims.lIndex,
                        'lMiddle': dims.lMiddle,
                        'lRing': dims.lRing,
                        'lPinky': dims.lPinky,
                        'rThumb': dims.rThumb,
                        'rIndex': dims.rIndex,
                        'rMiddle': dims.rMiddle,
                        'rRing': dims.rRing,
                        'rPinky': dims.rPinky,
                      },
                    },
                  },
                )
                .toList(growable: false),
          },
      };

      await _insertCompanyCustomRequestRow(
        requestId: requestId,
        summary: summary,
        details: details,
        companyUid: uid,
      );
      final uploadedPhotoUrls = await _uploadInspirationPhotos(
        orderId: requestId,
        companyUid: uid,
      );
      final photosUploadIncomplete =
          selectedPhotoCount > 0 &&
          uploadedPhotoUrls.length < selectedPhotoCount;
      await _attachUploadedInspirationPhotos(
        requestId: requestId,
        photos: uploadedPhotoUrls,
        summary: summary,
        details: details,
      );
      if (photosUploadIncomplete) {
        await _markPhotoUploadFailed(
          requestId: requestId,
          uploadedCount: uploadedPhotoUrls.length,
          selectedCount: selectedPhotoCount,
          summary: summary,
          details: details,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only ${uploadedPhotoUrls.length} of $selectedPhotoCount inspiration photos uploaded. The request was submitted.',
              ),
            ),
          );
        }
      }
      if (isOpenToClientPool) {
        unawaited(
          _notifyScenarioOneOnBrandSubmit(
            orderId: requestId,
            orderNumber: orderNumber,
            companyName: companyName,
            campaignName: campaign,
            sourceCollection: 'company_custom_requests',
            creatorEmail: companyEmail,
          ).catchError((_) {}),
        );
      }
      if (!isOpenToClientPool && selectedClientEmail.trim().isNotEmpty) {
        unawaited(
          _notifyDirectClientOnBrandSubmit(
            directClientEmail: selectedClientEmail,
            orderId: requestId,
            orderNumber: orderNumber,
            companyName: companyName,
            campaignName: campaign,
            sourceCollection: 'company_custom_requests',
            creatorEmail: companyEmail,
          ).catchError((_) {}),
        );
      }
      if (_clientRecipientMode == _ClientRecipientMode.groupClients &&
          selectedGroupClientEmails.length >= 2) {
        unawaited(
          _notifySelectedGroupClientsOnBrandSubmit(
            selectedGroupClientEmails: selectedGroupClientEmails,
            orderId: requestId,
            orderNumber: orderNumber,
            companyName: companyName,
            campaignName: campaign,
            sourceCollection: 'company_custom_requests',
            creatorEmail: companyEmail,
          ).catchError((_) {}),
        );
      }
      if (!mounted) return;
      _closeAfterSuccessfulSubmit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit request: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pendingRequestDocId = null;
        });
      }
    }
  }

  String _generateBrandOrderNumber(String docId) {
    final digits = docId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 5) {
      return 'BE-${digits.substring(digits.length - 5)}';
    }
    final hash = docId.codeUnits.fold<int>(
      0,
      (acc, ch) => (acc * 31 + ch) % 100000,
    );
    return 'BE-${hash.toString().padLeft(5, '0')}';
  }

  Future<List<String>> _uploadInspirationPhotos({
    required String orderId,
    required String companyUid,
  }) async {
    if (_uploadedFiles.isEmpty) return const <String>[];
    final safeUid = companyUid.trim().isEmpty ? 'unknown' : companyUid.trim();
    var dataUriBudget = 650000;
    Future<String?> uploadToPath({
      required String path,
      required Uint8List uploadBytes,
    }) async {
      if (uploadBytes.isEmpty) return null;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _companyCustomRequestsStorage
              .uploadBinary(
                path,
                uploadBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              )
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  throw TimeoutException('Upload timeout');
                },
              );
          return _normalizeStorageUrl(path);
        } catch (e) {
          debugPrint(
            '[BrandPhotoUpload] failed attempt ${attempt + 1} for $path: $e',
          );
          if (attempt == 1) return null;
        }
      }
      return null;
    }

    Future<String?> uploadOne(int i, _UploadedReferenceImage file) async {
      final uploadBytes = _bytesForUpload(file.bytes);
      final ext = 'jpg';
      // Path is relative to the bucket -- _companyCustomRequestsStorage is
      // already scoped to the 'company-custom-requests' bucket via
      // .from('company-custom-requests'), so repeating the bucket name here
      // would upload into a nested company-custom-requests/company-custom-
      // requests/... subfolder that nothing else expects to find.
      final path = '$safeUid/$orderId/inspiration_${i + 1}.$ext';
      final uploaded = await uploadToPath(path: path, uploadBytes: uploadBytes);
      if ((uploaded ?? '').trim().isNotEmpty) {
        return uploaded!.trim();
      }
      final dataUri = _buildInlinePreviewDataUri(file.bytes);
      if (dataUri != null &&
          dataUri.isNotEmpty &&
          dataUri.length <= dataUriBudget) {
        dataUriBudget -= dataUri.length;
        debugPrint(
          '[BrandPhotoUpload] using data-uri fallback for ${file.name}',
        );
        return dataUri;
      }
      return null;
    }

    final uploadTasks = _uploadedFiles.asMap().entries.map(
      (entry) => uploadOne(entry.key, entry.value),
    );
    final results = await Future.wait(uploadTasks);
    final urls = results.whereType<String>().toList(growable: false);
    return urls;
  }

  Future<void> _attachUploadedInspirationPhotos({
    required String requestId,
    required List<String> photos,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> details,
  }) async {
    final cleaned = photos
        .map((photo) => photo.trim())
        .where((photo) => photo.isNotEmpty)
        .toList(growable: false);
    final hasPhotos = cleaned.isNotEmpty;
    final previewImage = hasPhotos ? cleaned.first : '';
    final previewImageAsset = previewImage.startsWith('data:image/')
        ? ''
        : previewImage;
    final nowIso = DateTime.now().toIso8601String();
    final payloadUpdate = Map<String, dynamic>.from(summary)
      ..['hasInspirationPhotos'] = hasPhotos
      ..['photoCount'] = cleaned.length
      ..['photoUploadStatus'] = hasPhotos ? 'completed' : 'none'
      ..['photoUploadError'] = null
      ..['brandHasInspirationPhotos'] = hasPhotos
      ..['brandPhotoCount'] = cleaned.length
      ..['brandInspirationPhotos'] = cleaned
      ..['inspirationPhotos'] = cleaned
      ..['updatedAt'] = nowIso
      ..['photoUploadCompletedAt'] = hasPhotos
          ? nowIso
          : summary['photoUploadCompletedAt']
      ..['previewImage'] = previewImage.isNotEmpty
          ? previewImage
          : summary['previewImage']
      ..['previewImageAsset'] = previewImageAsset.isNotEmpty
          ? previewImageAsset
          : summary['previewImageAsset'];
    final detailRequestDetails = _asMap(details['requestDetails']);
    final detailUpdate = Map<String, dynamic>.from(details)
      ..['photoUploadStatus'] = hasPhotos ? 'completed' : 'none'
      ..['photoUploadError'] = null
      ..['brandInspirationPhotos'] = cleaned
      ..['inspirationPhotos'] = cleaned
      ..['requestDetails'] = <String, dynamic>{
        ...detailRequestDetails,
        'brandInspirationPhotos': cleaned,
        'inspirationPhotos': cleaned,
      }
      ..['updatedAt'] = nowIso
      ..['photoUploadCompletedAt'] = hasPhotos
          ? nowIso
          : details['photoUploadCompletedAt']
      ..['previewImage'] = previewImage.isNotEmpty
          ? previewImage
          : details['previewImage']
      ..['previewImageAsset'] = previewImageAsset.isNotEmpty
          ? previewImageAsset
          : details['previewImageAsset'];
    await _updateCompanyCustomRequestRow(
      requestId: requestId,
      summaryUpdate: payloadUpdate,
      detailsUpdate: detailUpdate,
    );
  }

  Future<void> _markPhotoUploadFailed({
    required String requestId,
    required int uploadedCount,
    required int selectedCount,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> details,
  }) async {
    final error =
        'Only $uploadedCount of $selectedCount inspiration photos uploaded.';
    try {
      final nowIso = DateTime.now().toIso8601String();
      final payloadUpdate = Map<String, dynamic>.from(summary)
        ..['photoUploadStatus'] = 'failed'
        ..['photoUploadError'] = error
        ..['photoUploadFailedAt'] = nowIso
        ..['updatedAt'] = nowIso;
      final detailUpdate = Map<String, dynamic>.from(details)
        ..['photoUploadStatus'] = 'failed'
        ..['photoUploadError'] = error
        ..['photoUploadFailedAt'] = nowIso
        ..['updatedAt'] = nowIso;
      await _updateCompanyCustomRequestRow(
        requestId: requestId,
        summaryUpdate: payloadUpdate,
        detailsUpdate: detailUpdate,
      );
    } catch (_) {}
  }

  Uint8List _bytesForUpload(Uint8List source) {
    // Skip CPU-heavy re-encoding for smaller files to keep submit fast.
    if (source.lengthInBytes <= 1400 * 1024) return source;
    return _optimizeUploadBytes(source) ?? source;
  }

  Uint8List? _optimizeUploadBytes(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
    img.Image processed = decoded;
    final maxSide = processed.width > processed.height
        ? processed.width
        : processed.height;
    if (maxSide > 1600) {
      final scale = 1600 / maxSide;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(processed, quality: 72));
  }

  String? _buildInlinePreviewDataUri(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
    img.Image processed = decoded;
    final maxSide = processed.width > processed.height
        ? processed.width
        : processed.height;
    if (maxSide > 128) {
      final scale = 128 / maxSide;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    final encoded = Uint8List.fromList(img.encodeJpg(processed, quality: 45));
    final dataUri = 'data:image/jpeg;base64,${base64Encode(encoded)}';
    return dataUri;
  }

  Future<void> _notifyScenarioOneOnBrandSubmit({
    required String orderId,
    required String orderNumber,
    required String companyName,
    required String campaignName,
    required String sourceCollection,
    required String creatorEmail,
  }) async {
    final recipients = await _loadBrandPartnerRecipientEmails();
    final brand = companyName.trim().isEmpty
        ? 'Brand company'
        : companyName.trim();
    final senderEmail = _authEmail;
    final creator = creatorEmail.trim().toLowerCase();
    for (final email in recipients) {
      if (senderEmail.isNotEmpty && email == senderEmail) continue;
      if (creator.isNotEmpty && email == creator) continue;
      await NotificationsService.createUserNotification(
        receiverEmail: email,
        title: 'New Brand Request',
        body: scenario41ClientReceiveOnSubmit(
          orderRef: orderNumber,
          brandCompany: brand,
          campaignName: campaignName,
        ),
        type: 'brand_request_received',
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
      );
    }

    await NotificationsService.notifyAdmins(
      title: 'New Brand Request',
      body:
          'New Brand request $orderNumber from $brand $campaignName is created.',
      type: 'admin_new_brand_custom_request',
      orderId: orderId,
      orderNumber: orderNumber,
      sourceCollection: sourceCollection,
      extra: <String, dynamic>{
        'companyName': companyName,
        'campaignName': campaignName,
      },
    );
  }

  Future<void> _notifyDirectClientOnBrandSubmit({
    required String directClientEmail,
    required String orderId,
    required String orderNumber,
    required String companyName,
    required String campaignName,
    required String sourceCollection,
    required String creatorEmail,
  }) async {
    final receiverEmail = directClientEmail.trim().toLowerCase();
    if (receiverEmail.isEmpty) return;
    final senderEmail = _authEmail;
    final creator = creatorEmail.trim().toLowerCase();
    if (senderEmail.isNotEmpty && receiverEmail == senderEmail) return;
    if (creator.isNotEmpty && receiverEmail == creator) return;

    final brand = companyName.trim().isEmpty
        ? 'Brand company'
        : companyName.trim();
    await NotificationsService.createUserNotification(
      receiverEmail: receiverEmail,
      title: 'New Brand Request',
      body: scenario41ClientReceiveOnSubmit(
        orderRef: orderNumber,
        brandCompany: brand,
        campaignName: campaignName,
      ),
      type: 'brand_request_received',
      orderId: orderId,
      orderNumber: orderNumber,
      sourceCollection: sourceCollection,
    );

    await NotificationsService.notifyAdmins(
      title: 'New Brand Request',
      body:
          'New Brand request $orderNumber from $brand $campaignName is created.',
      type: 'admin_new_brand_custom_request',
      orderId: orderId,
      orderNumber: orderNumber,
      sourceCollection: sourceCollection,
      extra: <String, dynamic>{
        'companyName': companyName,
        'campaignName': campaignName,
      },
    );
  }

  Future<void> _notifySelectedGroupClientsOnBrandSubmit({
    required List<String> selectedGroupClientEmails,
    required String orderId,
    required String orderNumber,
    required String companyName,
    required String campaignName,
    required String sourceCollection,
    required String creatorEmail,
  }) async {
    final senderEmail = _authEmail;
    final creator = creatorEmail.trim().toLowerCase();
    final recipients = selectedGroupClientEmails
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet();
    final brand = companyName.trim().isEmpty
        ? 'Brand company'
        : companyName.trim();

    for (final receiverEmail in recipients) {
      if (senderEmail.isNotEmpty && receiverEmail == senderEmail) continue;
      if (creator.isNotEmpty && receiverEmail == creator) continue;
      await NotificationsService.createUserNotification(
        receiverEmail: receiverEmail,
        title: 'New Brand Request',
        body: scenario41ClientReceiveOnSubmit(
          orderRef: orderNumber,
          brandCompany: brand,
          campaignName: campaignName,
        ),
        type: 'brand_request_received',
        orderId: orderId,
        orderNumber: orderNumber,
        sourceCollection: sourceCollection,
      );
    }

    await NotificationsService.notifyAdmins(
      title: 'New Brand Request',
      body:
          'New Brand request $orderNumber from $brand $campaignName is created.',
      type: 'admin_new_brand_custom_request',
      orderId: orderId,
      orderNumber: orderNumber,
      sourceCollection: sourceCollection,
      extra: <String, dynamic>{
        'companyName': companyName,
        'campaignName': campaignName,
      },
    );
  }

  Future<Set<String>> _loadBrandPartnerRecipientEmails() async {
    final recipients = <String>{};
    final sourceNames = _nfcRequest
        ? _nfcFilteredBrandPartnerClients
        : _brandPartnerClients;
    for (final name in sourceNames) {
      final email = (_clientEmailByNameLower[name.toLowerCase()] ?? '')
          .trim()
          .toLowerCase();
      if (email.isNotEmpty) recipients.add(email);
    }
    if (recipients.isNotEmpty) return recipients;

    try {
      for (final collection in const <String>['client', 'client_artist']) {
        final rows = await _fetchTableRows(collection);
        for (final data in rows) {
          if (_nfcRequest) {
            if (!_clientIsNfcEligible(data)) continue;
          } else if (!_isBrandPartner(data)) {
            continue;
          }
          final email = _clientEmail(data);
          if (email.isNotEmpty) recipients.add(email);
        }
      }
    } catch (_) {}
    return recipients;
  }

  String _whoReceivesOrderLabel(_ClientRecipientMode mode) {
    switch (mode) {
      case _ClientRecipientMode.pool:
        return 'Open to pool';
      case _ClientRecipientMode.specificClient:
        return 'Specific client';
      case _ClientRecipientMode.groupClients:
        return 'Client group order';
    }
  }

  String _whoCreatesDesignLabel(_DesignCreatorMode mode) {
    switch (mode) {
      case _DesignCreatorMode.pool:
        return 'Open to pool';
      case _DesignCreatorMode.specificArtist:
        return 'Specific Artist';
    }
  }

  String _computeRequestTypeLabel({
    required bool isOpenToClientPool,
    required bool isOpenToArtistPool,
    required String orderTypeValue,
  }) {
    final isGroup = orderTypeValue == 'group';
    if (isOpenToClientPool) {
      return isOpenToArtistPool ? 'Standard' : 'Direct to Artist';
    }
    if (isGroup) {
      return isOpenToArtistPool ? 'Direct to Client' : 'Direct';
    }
    return isOpenToArtistPool ? 'Direct to Client' : 'Direct';
  }

  Future<List<String>> _loadEligibleBrandArtistEmails() async {
    final emails = <String>{};
    try {
      final rows = <Map<String, dynamic>>[];
      for (final table in const <String>['artist', 'client_artist']) {
        rows.addAll(await _fetchTableRows(table));
      }
      for (final data in rows) {
        if (!isEligibleBrandRequestArtist(data)) continue;
        final email = _clientEmail(data).trim().toLowerCase();
        if (email.isNotEmpty) emails.add(email);
      }
      if (emails.isEmpty) {
        final entries = await ArtistDirectoryService.fetchAllArtists(
          hydrateMediaFallbacks: false,
        );
        for (final artist in entries) {
          final tier = artist.tierLabel.trim().toLowerCase();
          if (tier != 'goldsmith' && tier != 'crowned') continue;
          final email = artist.email.trim().toLowerCase();
          if (email.isNotEmpty) emails.add(email);
        }
      }
    } catch (_) {}
    return emails.toList(growable: false)..sort();
  }

  Future<String> _resolveSelectedArtistEmail(String selectedArtist) async {
    final normalized = selectedArtist.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    try {
      final rows = <Map<String, dynamic>>[];
      for (final table in const <String>['artist', 'client_artist']) {
        rows.addAll(await _fetchTableRows(table));
      }
      for (final data in rows) {
        if (_artistDisplayName(data).trim().toLowerCase() != normalized) {
          continue;
        }
        if (!isEligibleBrandRequestArtist(data)) continue;
        final email = _clientEmail(data).trim().toLowerCase();
        if (email.isNotEmpty) return email;
      }
      final entries = await ArtistDirectoryService.fetchAllArtists(
        hydrateMediaFallbacks: false,
      );
      for (final artist in entries) {
        if (artist.name.trim().toLowerCase() != normalized) continue;
        final tier = artist.tierLabel.trim().toLowerCase();
        if (tier != 'goldsmith' && tier != 'crowned') continue;
        final email = artist.email.trim().toLowerCase();
        if (email.isNotEmpty) return email;
      }
    } catch (_) {}
    return '';
  }

  Future<String> _resolveSelectedClientEmail(String selectedClient) async {
    final normalized = selectedClient.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    final cached = _clientEmailByNameLower[normalized] ?? '';
    if (cached.isNotEmpty) return cached;

    Future<String> fromCollection(String collection) async {
      final rows = await _fetchTableRows(collection);
      for (final data in rows) {
        final name = _clientDisplayName(data).trim().toLowerCase();
        if (name != normalized) continue;
        final email = _clientEmail(data);
        if (email.isNotEmpty) return email;
      }
      return '';
    }

    try {
      final fromClient = await fromCollection('client');
      if (fromClient.isNotEmpty) return fromClient;
      final fromClientArtist = await fromCollection('client_artist');
      if (fromClientArtist.isNotEmpty) return fromClientArtist;
    } catch (_) {}
    return '';
  }

  Future<List<String>> _resolveGroupClientEmails(List<String> clients) async {
    if (clients.isEmpty) return const <String>[];
    final resolved = <String>[];
    for (final name in clients) {
      final email = await _resolveSelectedClientEmail(name);
      resolved.add(email);
    }
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final pageTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.alabaster,
      canvasColor: _requestSnow,
      colorScheme: baseTheme.colorScheme.copyWith(surface: _requestSnow),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _requestSnow,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        constraints: BoxConstraints(minHeight: 52),
      ),
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Brand custom request',
      child: Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: widget.showBottomNav && widget.companyName != null
            ? CompanyHeader(
                companyName: widget.companyName!,
                imageUrl: widget.profile.basic.profileImageUrl,
                onOpenProfile: widget.onOpenProfile,
                onLogout: widget.onLogout,
                autoFocusNotifications: true,
              )
            : AppBar(
                backgroundColor: AppColors.alabaster,
                surfaceTintColor: AppColors.alabaster,
                elevation: 0,
                centerTitle: true,
                title: const Text(
                  'Company Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: widget.onBackHome ?? () => Navigator.pop(context),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            const SizedBox(height: 2),
            const Center(
              child: Text(
                'Create Brand Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'times-new-roman',
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Define your campaign and what you're looking for.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Arial',
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Campaign Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
                color: AppColors.blackCat,
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Campaign / Collection Name *'),
                  const SizedBox(height: 2),
                  _InputField(
                    controller: _campaignNameCtrl,
                    hint: 'e.g. Spring 2025 Heritage Collection',
                    minHeight: 52,
                    verticalPadding: 14,
                    focusNode: _campaignNameFocusNode,
                  ),
                  const SizedBox(height: 2),
                  _fieldLabel('Need By Date *'),
                  const SizedBox(height: 2),
                  _DateField(
                    controller: _dateCtrl,
                    onCalendarTap: _pickDate,
                    onChanged: (value) {
                      final parsed = _tryParseMmDdYyyy(value);
                      setState(() {
                        _needBy = parsed;
                        if (_jntRevealDate != null &&
                            (_needBy == null ||
                                !_jntRevealDate!.isAfter(_needBy!))) {
                          _jntRevealDate = null;
                          _revealDateCtrl.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 2),
                  _fieldLabel(
                    'JNT Reveal Date (Date aligned with your campaign)',
                  ),
                  const SizedBox(height: 2),
                  _DateField(
                    controller: _revealDateCtrl,
                    onCalendarTap: _pickRevealDate,
                    onChanged: (value) {
                      setState(() {
                        _jntRevealDate = _tryParseMmDdYyyy(value);
                      });
                    },
                  ),
                  const SizedBox(height: 2),
                  _fieldLabel('Description *'),
                  const SizedBox(height: 2),
                  _TextArea(
                    controller: _descCtrl,
                    hint:
                        'Describe your campaign vision, color palette, cultural references, and any specific design requirements...',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Inspiration & References',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload mood board photos, artwork scans, or reference images.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Arial',
                color: AppColors.blackCat.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _uploadReferenceImages,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: AppColors.blackCat.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: AppColors.blackCat,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Arial',
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _captureReferenceImage,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Arial',
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Allowed files: JPG, JPEG, PNG. Recommended size: up to 2 MB per photo. Maximum 10 photos.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                        color: AppColors.blackCat.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
                  if (_uploadedFiles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _uploadedFiles
                            .map((file) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 74,
                                    height: 74,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.blackCat.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Image.memory(
                                      file.bytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Semantics(
                                      button: true,
                                      label: 'Remove photo',
                                      onTap: () => setState(
                                        () => _uploadedFiles.remove(file),
                                      ),
                                      child: ExcludeSemantics(
                                        child: InkWell(
                                      onTap: () => setState(
                                        () => _uploadedFiles.remove(file),
                                      ),
                                      child: Container(
                                        color: AppColors.snow,
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                        ),
                                      ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Who receives the order?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _nfcRequest,
                    activeColor: AppColors.blackCat,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'NFC request',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                        color: AppColors.blackCat,
                      ),
                    ),
                    subtitle: Text(
                      'Only clients with one or more nail dimensions of 8 mm or more are eligible.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                        color: AppColors.blackCat.withValues(alpha: 0.62),
                      ),
                    ),
                    onChanged: (v) => _setNfcRequest(v ?? false),
                  ),
                  const SizedBox(height: 8),
                  _OptionCard(
                    selected: _clientRecipientMode == _ClientRecipientMode.pool,
                    title: 'Open to client pool',
                    badge: 'POOL',
                    subtitle:
                        'Any client in the marketplace can claim this request. First to accept proceeds.',
                    onTap: () => setState(
                      () => _clientRecipientMode = _ClientRecipientMode.pool,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _OptionCard(
                    selected:
                        _clientRecipientMode ==
                        _ClientRecipientMode.specificClient,
                    title: 'Designate a specific client',
                    badge: 'DIRECT',
                    subtitle:
                        'Only this client will see and be able to accept the request.',
                    onTap: () {
                      setState(
                        () => _clientRecipientMode =
                            _ClientRecipientMode.specificClient,
                      );
                      _focusAfterBuild(_requestedClientFocusNode);
                      unawaited(_loadSelectionSources());
                    },
                  ),
                  if (_clientRecipientMode ==
                      _ClientRecipientMode.specificClient)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _SearchableSelectField(
                        value: _requestedClient ?? '',
                        hint: 'Select Client',
                        items: _nfcFilteredBrandPartnerClients,
                        focusNode: _requestedClientFocusNode,
                        onChanged: (v) => setState(
                          () => _requestedClient = v.trim().isEmpty
                              ? null
                              : v.trim(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _OptionCard(
                    selected:
                        _clientRecipientMode ==
                        _ClientRecipientMode.groupClients,
                    title: 'Group clients (up to 15)',
                    badge: 'DIRECT',
                    subtitle:
                        'Send to a curated list. Each client receives and accepts their own request.',
                    onTap: () {
                      setState(
                        () => _clientRecipientMode =
                            _ClientRecipientMode.groupClients,
                      );
                      _focusAfterBuild(_groupClientFocusNode);
                      unawaited(_loadSelectionSources());
                    },
                  ),
                  if (_clientRecipientMode ==
                      _ClientRecipientMode.groupClients) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SearchableSelectField(
                            // Keyed only on the selected-count, not on the
                            // in-progress query text: this field must reset
                            // (clear its text) after "Add" changes the
                            // selection, but must NOT be torn down and
                            // recreated on every keystroke -- doing so
                            // discarded and rebuilt the Autocomplete/
                            // FocusNode wiring on every character typed,
                            // which could leave duplicate stale focus
                            // listeners registered on the shared external
                            // FocusNode (a rebuild churn bug, not a text
                            // filtering requirement).
                            key: ValueKey<int>(_groupClientFieldResetTick),
                            value: _groupClientToAdd,
                            hint: 'Select clients',
                            focusNode: _groupClientFocusNode,
                            items: _nfcFilteredBrandPartnerClients
                                .where(
                                  (name) => !_groupSelectedClients.any(
                                    (picked) =>
                                        picked.toLowerCase() ==
                                        name.toLowerCase(),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (v) =>
                                setState(() => _groupClientToAdd = v.trim()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _addGroupClientSelection,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Arial',
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                    if (_groupSelectedClients.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: _groupSelectedClients
                              .map((name) {
                                return MergeSemantics(
                                  child: Semantics(
                                    button: true,
                                    label: 'Remove $name',
                                    onTap: () => setState(
                                      () => _groupSelectedClients.remove(name),
                                    ),
                                    child: ExcludeSemantics(
                                      child: InkWell(
                                  borderRadius: BorderRadius.zero,
                                  onTap: () => setState(
                                    () => _groupSelectedClients.remove(name),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Arial',
                                            color: AppColors.blackCat,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.blackCat,
                                        ),
                                      ],
                                    ),
                                  ),
                                    ),
                                    ),
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Who creates the design?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _OptionCard(
                    selected: _designCreatorMode == _DesignCreatorMode.pool,
                    title: 'Open to artist pool',
                    badge: 'POOL',
                    subtitle:
                        'Any qualified artist can accept and fulfill this request.',
                    onTap: () => setState(
                      () => _designCreatorMode = _DesignCreatorMode.pool,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _OptionCard(
                    selected:
                        _designCreatorMode == _DesignCreatorMode.specificArtist,
                    title: 'Request a specific artist',
                    badge: 'DIRECT',
                    subtitle:
                        'Only this artist will receive the request. If declined, it returns to the artist pool.',
                    onTap: () {
                      setState(
                        () => _designCreatorMode =
                            _DesignCreatorMode.specificArtist,
                      );
                      _focusAfterBuild(_requestedArtistFocusNode);
                    },
                  ),
                  if (_designCreatorMode == _DesignCreatorMode.specificArtist)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchableSelectField(
                            value: _requestedArtist ?? '',
                            hint: 'Select Artist',
                            items: _directRequestArtists,
                            focusNode: _requestedArtistFocusNode,
                            onChanged: (v) => setState(
                              () => _requestedArtist = v.trim().isEmpty
                                  ? null
                                  : v.trim(),
                            ),
                          ),
                          if ((_requestedArtist ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'If the artist cannot complete the request, do you want the request to go into the request pool for other artists?',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.75,
                                ),
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
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.08,
                                    ),
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
                                    color: AppColors.blackCat.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Client Budget Range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set the client budget range.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Arial',
                color: AppColors.blackCat.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 10),
            _BudgetCard(
              minLabel: _nfcRequest ? '\$${15 + _nfcBudgetSurcharge}' : '\$15',
              maxLabel: '\$5000',
              values: _clientBudget,
              displayStartOffset: _nfcRequest ? _nfcBudgetSurcharge : 0,
              onChanged: (v) => setState(() => _clientBudget = v),
              onChangeEnd: (_) {},
            ),
            const SizedBox(height: 16),
            const Text(
              'Artist Budget Range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set the artist budget range.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Arial',
                color: AppColors.blackCat.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 10),
            _BudgetCard(
              minLabel: _nfcRequest ? '\$${15 + _nfcBudgetSurcharge}' : '\$15',
              maxLabel: '\$5000',
              values: _artistBudget,
              displayStartOffset: _nfcRequest ? _nfcBudgetSurcharge : 0,
              onChanged: (v) => setState(() => _artistBudget = v),
              onChangeEnd: (_) {},
            ),
            const SizedBox(height: 16),
            const Text(
              'Quantity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Number of sets',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ),
                      _stepperBtn(
                        icon: Icons.remove,
                        onTap: () => setState(() {
                          if (_quantity > 1) _quantity--;
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _stepperBtn(
                        icon: Icons.add,
                        onTap: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Each set includes 10 press-on nails (5 per hand). Minimum order: 1 set.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                      color: AppColors.blackCat.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Shipping Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Arialbold',
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _shippingAddressDifferentFromProfile,
                        activeColor: AppColors.blackCat,
                        onChanged: (v) => setState(
                          () =>
                              _shippingAddressDifferentFromProfile = v ?? false,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Shipping address different from profile address?',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Arial',
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_shippingAddressDifferentFromProfile) ...[
                    const SizedBox(height: 6),
                    _fieldLabel('Shipping Address *'),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipStreetCtrl,
                      hint: 'Street',
                      minHeight: 52,
                      verticalPadding: 14,
                      onChanged: (_) => _autofillShippingAddressFromStreet(),
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
                                onTap: () => _selectShippingStreetSuggestion(
                                  _shipStreetSuggestions[i],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipCityCtrl,
                      hint: 'City',
                      minHeight: 52,
                      verticalPadding: 14,
                    ),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipStateCtrl,
                      hint: 'State',
                      minHeight: 52,
                      verticalPadding: 14,
                    ),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipZipCtrl,
                      hint: 'Zip',
                      minHeight: 52,
                      verticalPadding: 14,
                    ),
                    const SizedBox(height: 4),
                    _InputField(
                      controller: _shipCountryCtrl,
                      hint: 'Country',
                      minHeight: 52,
                      verticalPadding: 14,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Nail Specifications',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'times-new-roman',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Set dimensions, shape and length for the press-on kit.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Arial',
                  color: AppColors.blackCat.withValues(alpha: 0.60),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.blackCat.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For brand orders: the Client’s dimensions will be provided when they accept the request.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                      color: AppColors.blackCat.withValues(alpha: 0.75),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPlum,
                  foregroundColor: AppColors.snow,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Arial',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitRequest,
                child: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Request',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.snow,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.showBottomNav
            ? CompanyBottomNav(
                currentIndex: widget.bottomNavIndex,
                onTap: (i) => widget.onNavTap?.call(i),
              )
            : null,
      ),
    ));
  }

  List<String> get _artistOptions {
    final seen = <String>{};
    final result = <String>[];
    final incoming = <String>[
      ...?widget.artistOptions,
      if ((_requestedArtist ?? '').trim().isNotEmpty) _requestedArtist!.trim(),
    ];
    for (final raw in incoming) {
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

  Widget _fieldLabel(String t) {
    return Text(
      t,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.blackCat,
        fontSize: 13,
        fontFamily: 'Arialbold',
      ),
    );
  }

  Widget _stepperBtn({required IconData icon, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: icon == Icons.add ? 'Increase quantity' : 'Decrease quantity',
      child: ExcludeSemantics(
        child: InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.zero,
        ),
        child: Icon(icon, size: 16),
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
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String badge;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.snow,
          border: Border.all(
            color: AppColors.blackCat.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Arial',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badge == 'POOL'
                              ? AppColors.blackCat.withValues(alpha: 0.14)
                              : AppColors.blackCat,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: badge == 'POOL'
                                ? AppColors.blackCat
                                : AppColors.snow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                      color: AppColors.blackCat.withValues(alpha: 0.65),
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
}

class _SearchableSelectField extends StatefulWidget {
  const _SearchableSelectField({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.focusNode,
  });

  final String value;
  final String hint;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  State<_SearchableSelectField> createState() => _SearchableSelectFieldState();
}

class _SearchableSelectFieldState extends State<_SearchableSelectField> {
  // Autocomplete gates its options-overlay visibility on
  // `_focusNode.hasFocus` for the *exact* FocusNode instance it was given.
  // When an external FocusNode is attached only to the TextField built in
  // fieldViewBuilder (as this used to do) but never passed to Autocomplete
  // itself, Autocomplete falls back to an internal FocusNode that never
  // receives focus, so the options overlay never shows even though the
  // options list is populated correctly. Passing a FocusNode to Autocomplete
  // requires pairing it with an explicit TextEditingController (Flutter's
  // "split field" API), so this field owns both together.
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.trim(),
  );
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _controller.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedItems = widget.items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return Autocomplete<String>(
          focusNode: _effectiveFocusNode,
          textEditingController: _controller,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return normalizedItems;
            final ranked = normalizedItems
                .map(
                  (item) => MapEntry(item, item.toLowerCase().indexOf(query)),
                )
                .where((entry) => entry.value >= 0)
                .toList(growable: false);
            ranked.sort((a, b) {
              final aStarts = a.key.toLowerCase().startsWith(query);
              final bStarts = b.key.toLowerCase().startsWith(query);
              if (aStarts != bStarts) return aStarts ? -1 : 1;
              if (a.value != b.value) return a.value.compareTo(b.value);
              return a.key.length.compareTo(b.key.length);
            });
            if (ranked.isEmpty) return normalizedItems;
            return ranked.map((entry) => entry.key);
          },
          onSelected: widget.onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return Semantics(
              label: widget.hint,
              textField: true,
              child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (text) {
                final normalizedText = text.trim();
                final matchesExisting = normalizedItems.any(
                  (item) => item.toLowerCase() == normalizedText.toLowerCase(),
                );
                if (normalizedText.isEmpty || !matchesExisting) {
                  widget.onChanged('');
                }
              },
              onTap: () async {
                if (controller.text.trim().isEmpty &&
                    normalizedItems.isNotEmpty) {
                  // Autocomplete only calls optionsBuilder in response to a
                  // real text change (empty -> empty is a no-op, so tapping
                  // an already-empty field wouldn't otherwise populate the
                  // options list at all). Mutating to ' ' and back to ''
                  // forces that change so the full list populates before the
                  // options overlay becomes visible.
                  controller.value = const TextEditingValue(
                    text: ' ',
                    selection: TextSelection.collapsed(offset: 1),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 16));
                  controller.value = const TextEditingValue(text: '');
                }
              },
              onSubmitted: (_) => onSubmit(),
              onTapOutside: (_) => focusNode.unfocus(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                fontFamily: 'Arial',
                color: AppColors.blackCat,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Arial',
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.snow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                suffixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: AppColors.blackCat.withValues(alpha: 0.45),
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
                    side: _requestBorder,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: menuHeight,
                      minWidth: fieldWidth,
                      maxWidth: fieldWidth,
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
                        return Semantics(
                          button: true,
                          child: ExcludeSemantics(
                            child: InkWell(
                          onTap: () => onSelected(item),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
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
                              ),
                            ),
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
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.onCalendarTap,
    this.onChanged,
  });
  final TextEditingController controller;
  final VoidCallback onCalendarTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Date',
      textField: true,
      child: TextField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: 'MM/DD/YYYY',
        hintStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          fontFamily: 'Arial',
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minHeight: 52),
        suffixIcon: IconButton(
          tooltip: 'Pick date',
          onPressed: onCalendarTap,
          icon: Icon(
            Icons.calendar_month_rounded,
            size: 14,
            color: AppColors.blackCat.withValues(alpha: 0.45),
          ),
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
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hint,
      textField: true,
      child: TextField(
      controller: controller,
      maxLines: 5,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          fontFamily: 'Arial',
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
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
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.minHeight,
    required this.verticalPadding,
    this.onChanged,
    this.focusNode,
  });
  final TextEditingController controller;
  final String hint;
  final double minHeight;
  final double verticalPadding;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hint,
      textField: true,
      child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          fontFamily: 'Arial',
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
        isDense: true,
        filled: true,
        fillColor: _requestSnow,
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
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.minLabel,
    required this.maxLabel,
    required this.values,
    required this.displayStartOffset,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String minLabel;
  final String maxLabel;
  final RangeValues values;
  final int displayStartOffset;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues> onChangeEnd;

  String _fmtMoney(double v) => '\$${v.round()}';

  @override
  Widget build(BuildContext context) {
    final start = values.start;
    final end = values.end;
    final currentText =
        '${_fmtMoney(start + displayStartOffset)} - ${_fmtMoney(end)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                showValueIndicator: ShowValueIndicator.never,
              ),
            ),
            child: RangeSlider(
              min: 15,
              max: 5000,
              divisions: 997,
              values: values,
              semanticFormatterCallback: (value) =>
                  _fmtMoney(value + displayStartOffset),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
              ),
              Text(
                maxLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------
// Nail pieces you already use
// ----------

String _lengthTitle(NailLength l) {
  switch (l) {
    case NailLength.short:
      return 'Short';
    case NailLength.medium:
      return 'Medium';
    case NailLength.long:
      return 'Long';
    case NailLength.extraLong:
      return 'XL Long';
    case NailLength.xlLong:
      return 'XXL Long';
    case NailLength.none:
      return 'Select';
  }
}
