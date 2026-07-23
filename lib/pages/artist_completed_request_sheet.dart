import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../utils/image_cache_utils.dart';
// for ClientRequestV2 + NailDimensionsV2 (or move models to a shared file)
import '../models/client_request_v2.dart';
import '../widgets/group_client_measurements_tabs.dart';
import '../utils/request_nfc_details_loader.dart';
import '../utils/company_bio_loader.dart';
import '../services/shipping_qr_helper.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/shipping_qr_widgets.dart';

part 'artist_completed_details_tab.dart';
part 'artist_completed_photos_tab.dart';
part 'artist_completed_shipping_tab.dart';

Widget completedSectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: AppColors.blackCat,
    ),
  );
}

Widget completedSoftBox(Widget child) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.snow,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: AppColors.blackCatBorderLight),
    ),
    child: child,
  );
}

Widget _softBox(Widget child) => completedSoftBox(child);

Future<void> showCompletedRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function({
    required String courier,
    required String tracking,
    required DateTime shippedDate, // ✅ NEW
  })
  onMarkShipped,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompletedRequestSheet(
      request: request,
      shipDays: shipDays,
      onClose: onClose,
      onMarkShipped: onMarkShipped,
    ),
  );
}

class _CompletedRequestSheet extends StatefulWidget {
  const _CompletedRequestSheet({
    required this.request,
    required this.shipDays,
    required this.onClose,
    required this.onMarkShipped,
  });

  final ClientRequestV2 request;
  final int shipDays;
  final VoidCallback onClose;

  // ✅ NEW: include shippedDate in callback
  final Future<void> Function({
    required String courier,
    required String tracking,
    required DateTime shippedDate,
  })
  onMarkShipped;

  @override
  State<_CompletedRequestSheet> createState() => _CompletedRequestSheetState();
}

class _CompletedRequestSheetState extends State<_CompletedRequestSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _trackingCtrl = TextEditingController();

  // ✅ NEW (optional, but helps keep formatting consistent)
  final _shippedDateCtrl = TextEditingController();
  DateTime? _shippedDate;

  String? _courier;
  bool _submitting = false;
  int _completedTabIndex = 0;
  bool? _dbShippingLabelReady;
  String _dbShippingLabelQrData = '';
  String _dbShippingQrCode = '';
  String _dbShippingLabelPdfUrl = '';
  String _dbShippingLabelCarrier = '';
  String _dbShippingLabelTrackingNumber = '';

  final _couriers = const ['USPS', 'UPS', 'FedEx', 'DHL'];

  String get _requestTable =>
      widget.request.sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests'
      : 'client_custom_requests';

  String get _requestDetailsTable =>
      widget.request.sourceCollection == 'Company_Custom_Requests'
      ? 'company_custom_requests_details'
      : 'client_custom_requests_details';

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList(growable: false);
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return const <dynamic>[];
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  @override
  void initState() {
    super.initState();
    final prefillTracking = widget.request.shippingLabelTrackingNumber.trim();
    final prefillCourier = widget.request.shippingLabelCarrier.trim();
    if (prefillTracking.isNotEmpty) {
      _trackingCtrl.text = prefillTracking;
    }
    if (prefillCourier.isNotEmpty && _couriers.contains(prefillCourier)) {
      _courier = prefillCourier;
    }
    Future<void>.microtask(_loadLatestShippingLabel);
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    _shippedDateCtrl.dispose(); // ✅ NEW
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CompletedRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when request data changes to ensure data is synced
    if (oldWidget.request != widget.request) {
      setState(() {});
    }
  }

  bool get _isValid =>
      (_courier != null && _courier!.trim().isNotEmpty) &&
      _trackingCtrl.text.trim().isNotEmpty &&
      _shippedDate != null; // ✅ NEW requirement

  bool get _isShippingLabelReady {
    if (_dbShippingLabelReady == true) return true;
    if (_shippingStatusValue.toLowerCase() == 'label_ready') return true;
    if (_shippingQrValue.isNotEmpty) return true;
    if (_shippingPdfValue.isNotEmpty) return true;
    if (_shippingTrackingValue.isNotEmpty) return true;
    return widget.request.shippingLabelReady;
  }

  String get _shippingQrValue => _firstNonEmpty([
    _dbShippingQrCode,
    _dbShippingLabelQrData,
    widget.request.shippingQrCode,
    widget.request.shippingLabelQrData,
  ]);

  String get _shippingPdfValue => _firstNonEmpty([
    _dbShippingLabelPdfUrl,
    widget.request.shippingLabelPdfUrl,
  ]);

  String get _shippingCarrierValue => _firstNonEmpty([
    _dbShippingLabelCarrier,
    widget.request.shippingLabelCarrier,
    _courier ?? '',
    'USPS',
  ]);

  String get _shippingTrackingValue => _firstNonEmpty([
    _dbShippingLabelTrackingNumber,
    widget.request.shippingLabelTrackingNumber,
    _trackingCtrl.text,
  ]);

  String get _shippingStatusValue => _firstNonEmpty([
    widget.request.shippingStatus,
    _dbShippingLabelReady == true ? 'label_ready' : '',
  ]);

  String _firstNonEmpty(Iterable<Object?> values) {
    for (final raw in values) {
      final value = (raw ?? '').toString().trim();
      if (value.isNotEmpty && value != '-') return value;
    }
    return '';
  }

  bool _asBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = (raw ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  Future<void> _loadLatestShippingLabel() async {
    try {
      final row = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (row == null) return;
      final data = Map<String, dynamic>.from(row as Map);
      final rootData = _asMap(data['data']);
      final payload = _asMap(data['payload']);
      final details = _asMap(data['details']);
      final shipping = <String, dynamic>{
        ..._asMap(rootData['shipping']),
        ..._asMap(payload['shipping']),
        ..._asMap(details['shipping']),
      };
      final shippingLabel = <String, dynamic>{
        ..._asMap(rootData['shippingLabel']),
        ..._asMap(payload['shippingLabel']),
        ..._asMap(details['shippingLabel']),
      };
      final ready =
          _asBool(data['shipping_label_ready']) ||
          _asBool(rootData['shippingLabelReady']) ||
          _asBool(payload['shippingLabelReady']) ||
          _asBool(details['shippingLabelReady']) ||
          _firstNonEmpty([
            data['shipping_label_qr_data'],
            data['shipping_qr_code'],
            rootData['shippingLabelQrData'],
            payload['shippingLabelQrData'],
            details['shippingLabelQrData'],
            shipping['qrCode'],
            shippingLabel['qrData'],
          ]).isNotEmpty;
      if (!mounted) return;
      setState(() {
        _dbShippingLabelReady = ready;
        _dbShippingLabelQrData = _firstNonEmpty([
          data['shipping_label_qr_data'],
          rootData['shippingLabelQrData'],
          payload['shippingLabelQrData'],
          details['shippingLabelQrData'],
          shippingLabel['qrData'],
        ]);
        _dbShippingQrCode = _firstNonEmpty([
          data['shipping_qr_code'],
          rootData['shippingQrCode'],
          payload['shippingQrCode'],
          details['shippingQrCode'],
          shipping['qrCode'],
        ]);
        _dbShippingLabelPdfUrl = _firstNonEmpty([
          data['shipping_label_pdf_url'],
          rootData['shippingLabelPdfUrl'],
          payload['shippingLabelPdfUrl'],
          details['shippingLabelPdfUrl'],
          shippingLabel['pdfUrl'],
        ]);
        _dbShippingLabelCarrier = _firstNonEmpty([
          data['shipping_label_carrier'],
          rootData['shippingLabelCarrier'],
          payload['shippingLabelCarrier'],
          details['shippingLabelCarrier'],
          shippingLabel['carrier'],
          shipping['carrier'],
        ]);
        _dbShippingLabelTrackingNumber = _firstNonEmpty([
          data['shipping_label_tracking_number'],
          rootData['shippingLabelTrackingNumber'],
          payload['shippingLabelTrackingNumber'],
          details['shippingLabelTrackingNumber'],
          shippingLabel['trackingNumber'],
          shipping['trackingNumber'],
        ]);
        if (_dbShippingLabelTrackingNumber.isNotEmpty) {
          _trackingCtrl.text = _dbShippingLabelTrackingNumber;
        }
        if (_dbShippingLabelCarrier.isNotEmpty &&
            _couriers.contains(_dbShippingLabelCarrier)) {
          _courier = _dbShippingLabelCarrier;
        }
      });
    } catch (_) {
      // Best-effort refresh only. The sheet still renders from widget.request.
    }
  }

  Future<void> _pickShippedDate() async {
    final now = DateTime.now();
    final initial = _shippedDate ?? now;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final baseTheme = Theme.of(context);
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: math.min(media.size.width * 0.84, 336),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
            ),
            child: Theme(
              data: baseTheme.copyWith(
                colorScheme: baseTheme.colorScheme.copyWith(
                  primary: AppColors.blackCat,
                  onPrimary: AppColors.snow,
                  surface: AppColors.snow,
                  onSurface: AppColors.blackCat,
                ),
                datePickerTheme: baseTheme.datePickerTheme.copyWith(
                  headerHeadlineStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  weekdayStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                  ),
                  dayStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                  ),
                  yearStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
              child: MediaQuery(
                data: media.copyWith(textScaler: const TextScaler.linear(0.88)),
                child: CalendarDatePicker(
                  initialDate: initial,
                  firstDate: now.subtract(const Duration(days: 30)),
                  lastDate: now.add(const Duration(days: 30)),
                  onDateChanged: (picked) {
                    setState(() {
                      _shippedDate = picked;
                      _shippedDateCtrl.text =
                          '${picked.month}/${picked.day}/${picked.year}';
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetMediaQuery = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Completed request details',
      child: MediaQuery(
        data: sheetMediaQuery,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: const BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    height: 5,
                    width: 54,
                    decoration: BoxDecoration(
                      color: AppColors.blackCat.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: IndexedStack(
                      index: _completedTabIndex,
                      children: [
                        _completedDetailsTab(context, bottomInset),
                        _completedPhotosTab(context, bottomInset),
                        _completedShippingTab(context, bottomInset),
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

  Widget _completedTabsBar() {
    return Row(
      children: [
        _completedTabButton('Details', 0),
        const SizedBox(width: 8),
        _completedTabButton('Photos', 1),
        const SizedBox(width: 8),
        _completedTabButton('Shipping', 2),
      ],
    );
  }

  Widget _completedStatusBanner() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 26,
          width: 26,
          decoration: const BoxDecoration(
            color: Color(0xFFDBF4E6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Color(0xFF1E8E5A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.80),
                height: 1.25,
              ),
              children: const [
                TextSpan(
                  text: 'Completed!\n',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                TextSpan(
                  text:
                      'Review the order details, photos, then use Shipping when the label is ready.',
                  style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _completedTabButton(String label, int index) {
    final selected = _completedTabIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => setState(() => _completedTabIndex = index),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.blackCat : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHeroCentered(
    BuildContext context,
    ClientRequestV2 request,
    VoidCallback onClose,
  ) {
    final isBrandRequest = _isBrandRequest(request);
    final headerName = isBrandRequest && request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName;
    final headerSubtitle = isBrandRequest ? request.title.trim() : '';
    final avatarPath = request.clientProfileImage.trim();
    final avatarLetter = headerName.isEmpty ? '' : headerName[0].toUpperCase();

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 78,
                  width: 78,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: FutureBuilder<String>(
                      future: _resolveCompletedClientProfileImage(request),
                      builder: (context, snapshot) {
                        final resolved = (snapshot.data ?? avatarPath).trim();
                        if (resolved.isNotEmpty) {
                          return _imageForPath(resolved);
                        }
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.zero,
                            color: AppColors.balletSlippers,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  headerName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.blackCat.withValues(alpha: 0.90),
                  ),
                ),
                if (headerSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    headerSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _outlinedChip('Brand Request'),
                ],
                const SizedBox(height: 4),

                Text(
                  'Order # ${request.orderNumber.trim().isNotEmpty ? request.orderNumber.trim() : request.id}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14.5,
                    color: AppColors.blackCat.withValues(alpha: 0.60),
                  ),
                ),
                const SizedBox(height: 10),
                _requestTypeOrderRow(request),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _chipInfo(
                          icon: Icons.calendar_today_outlined,
                          text: 'Need by: ${_needByLabel(request.neededBy)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 18,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _chipInfo(
                          icon: Icons.attach_money_rounded,
                          text:
                              'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 6,
          top: 6,
          child: Semantics(
            button: true,
            label: 'Close',
            onTap: onClose,
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.zero,
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: AppColors.blackCat.withValues(alpha: 0.70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isBrandRequest(ClientRequestV2 request) =>
      request.sourceCollection == 'Company_Custom_Requests' ||
      request.orderNumber.trim().toUpperCase().startsWith('BE-') ||
      request.orderNumber.trim().toUpperCase().startsWith('BR-');

  Widget _descriptionAndCompanyBioSection() {
    final r = widget.request;
    if (!_isBrandRequest(r)) {
      return completedSoftBox(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            completedSectionTitle('Description'),
            const SizedBox(height: 8),
            Text(
              r.bio.isEmpty ? '—' : r.bio,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                height: 1.2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return FutureBuilder<String>(
      future: fetchCompanyBio(
        sourceCollection: r.sourceCollection,
        requestId: r.id,
        requestOrderNumber: r.orderNumber,
      ),
      builder: (context, snapshot) {
        final bio = (snapshot.data ?? '').trim();
        return completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              completedSectionTitle('Description'),
              const SizedBox(height: 8),
              Text(
                r.bio.isEmpty ? '—' : r.bio,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.blackCatBorderLight),
              const SizedBox(height: 12),
              completedSectionTitle('Company Bio'),
              const SizedBox(height: 8),
              Text(
                bio.isEmpty ? 'No company bio available' : bio,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _outlinedChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCat),
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  Widget _acceptedClientDetailsSection(ClientRequestV2 request) {
    // Do not fall back to request.clientName here -- for brand-sourced
    // requests that field holds the brand/company name, not the client's,
    // whenever no accepted-client snapshot was captured.
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : 'Client';
    final avatarPath = _safeAcceptedClientAvatarPath(request);
    final avatarLetter = name[0].toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Client Details'),
        const SizedBox(height: 10),
        _softBox(
          Row(
            children: [
              avatarPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: SizedBox(
                        height: 54,
                        width: 54,
                        child: _imageForPath(avatarPath),
                      ),
                    )
                  : Container(
                      height: 54,
                      width: 54,
                      color: AppColors.balletSlippers,
                      alignment: Alignment.center,
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String> _resolveCompletedClientProfileImage(
    ClientRequestV2 request,
  ) async {
    final existing = request.clientProfileImage.trim();
    if (existing.isNotEmpty && existing.toLowerCase() != 'null')
      return existing;

    final accepted = request.acceptedClientProfileImage.trim();
    if (accepted.isNotEmpty && accepted.toLowerCase() != 'null')
      return accepted;

    return _lookupCompletedClientProfileImage(
      email: request.clientEmail.trim(),
      name: request.clientName.trim(),
    );
  }

  Future<String> _lookupCompletedClientProfileImage({
    required String email,
    required String name,
  }) async {
    String firstNonEmpty(List<Object?> values) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
      return const <String, dynamic>{};
    }

    String imageFromRow(Map<String, dynamic> row) {
      final profile = asMap(row['profile']);
      final basic = asMap(row['basic']);
      final client = asMap(row['client']);
      final clientProfile = asMap(client['profile']);
      final data = asMap(row['data']);
      return firstNonEmpty(<Object?>[
        row['client_profile_image'],
        row['clientProfileImage'],
        row['profileImageUrl'],
        row['profile_image_url'],
        row['profile_picture_url'],
        row['profilePhotoUrl'],
        row['profile_photo_url'],
        row['avatarUrl'],
        row['avatar_url'],
        row['photoUrl'],
        row['photo_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profile_picture_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        profile['photoUrl'],
        profile['photo_url'],
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['profile_picture_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        basic['photoUrl'],
        basic['photo_url'],
        client['profileImageUrl'],
        client['profile_image_url'],
        client['profile_picture_url'],
        client['avatarUrl'],
        client['avatar_url'],
        client['photoUrl'],
        client['photo_url'],
        clientProfile['profileImageUrl'],
        clientProfile['profile_image_url'],
        clientProfile['profile_picture_url'],
        clientProfile['avatarUrl'],
        clientProfile['avatar_url'],
        clientProfile['photoUrl'],
        clientProfile['photo_url'],
        data['clientProfileImage'],
        data['client_profile_image'],
        data['profileImageUrl'],
        data['profile_image_url'],
        data['avatarUrl'],
        data['avatar_url'],
        data['photoUrl'],
        data['photo_url'],
      ]);
    }

    Future<String> lookupBy(String table, String column, String value) async {
      final needle = value.trim();
      if (needle.isEmpty) return '';
      try {
        final row = await Supabase.instance.client
            .from(table)
            .select()
            .eq(column, needle)
            .limit(1)
            .maybeSingle();
        if (row == null) return '';
        return imageFromRow((row as Map).cast<String, dynamic>());
      } catch (_) {
        return '';
      }
    }

    if (email.trim().isNotEmpty) {
      for (final table in const ['client', 'clients', 'client_artist']) {
        for (final column in const ['email', 'client_email']) {
          final found = await lookupBy(
            table,
            column,
            email.trim().toLowerCase(),
          );
          if (found.isNotEmpty) return found;
        }
      }
    }

    if (name.trim().isNotEmpty) {
      for (final table in const ['client', 'clients', 'client_artist']) {
        for (final column in const [
          'name',
          'full_name',
          'display_name',
          'client_name',
        ]) {
          final found = await lookupBy(table, column, name.trim());
          if (found.isNotEmpty) return found;
        }
      }
    }

    return '';
  }

  String _safeAcceptedClientAvatarPath(ClientRequestV2 request) {
    final accepted = _normalizeImagePath(
      request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isEmpty) return '';
    final blocked = <String>{
      _normalizeImagePath(_heroPhotoSource(request)),
      _normalizeImagePath(request.clientProfileImage),
      _normalizeImagePath(request.previewImageAsset),
    }..removeWhere((e) => e.trim().isEmpty);
    return blocked.contains(accepted) ? '' : accepted;
  }

  String _heroPhotoSource(ClientRequestV2 request) {
    final profile = request.clientProfileImage.trim();
    if (profile.isNotEmpty) return profile;
    return '';
  }

  Widget _requestTypeOrderRow(ClientRequestV2 r) {
    // requestTypeLabel is frozen at submission and must never be
    // recomputed from current state (e.g. after client/artist acceptance).
    // Fall back to the old simplified rule only for legacy rows that
    // predate this field.
    final requestType = r.requestTypeLabel.isNotEmpty
        ? r.requestTypeLabel
        : (r.isDirectRequest ? 'Direct' : 'Standard');
    final orderType = r.orderType == RequestOrderTypeV2.group
        ? 'Group'
        : 'Single';
    return FutureBuilder<RequestNfcDetails>(
      future: loadRequestNfcDetails(
        sourceCollection: r.sourceCollection,
        requestId: r.id,
        requestOrderNumber: r.orderNumber,
      ),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? RequestNfcDetails.emptyConst;
        final requiresNfc =
            nfc.main.left['thumb'] == true || nfc.main.right['thumb'] == true;
        Widget segment({
          required IconData icon,
          required String text,
          required Alignment alignment,
        }) {
          return Align(
            alignment: alignment,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.blackCat),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Row(
          children: [
            // Request type values ("Direct to Artist"/"Direct to Client")
            // run noticeably longer than order-type/NFC values ("Single",
            // "Group", "NFC"), so give this segment more of the row instead
            // of splitting evenly -- otherwise it clips even with wrapping.
            Expanded(
              flex: 2,
              child: segment(
                icon: r.isDirectRequest
                    ? Icons.arrow_outward_rounded
                    : Icons.arrow_forward_rounded,
                text: requestType,
                alignment: Alignment.centerRight,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 18,
              color: AppColors.blackCatBorderLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: segment(
                icon: r.orderType == RequestOrderTypeV2.group
                    ? Icons.groups_2_outlined
                    : Icons.person_outline_rounded,
                text: orderType,
                alignment: requiresNfc
                    ? Alignment.center
                    : Alignment.centerLeft,
              ),
            ),
            if (requiresNfc) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 18,
                color: AppColors.blackCatBorderLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: segment(
                  icon: Icons.nfc_rounded,
                  text: 'NFC',
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );

  static Widget _chipInfo({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.blackCat),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  static Widget _handCardCentered(
    String title,
    NailDimensionsV2 d, {
    Map<String, bool> nfc = const <String, bool>{},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        _dimRow('Thumb', d.thumb, nfcRequested: nfc['thumb'] == true),
        _dimRow('Index', d.index, nfcRequested: nfc['index'] == true),
        _dimRow('Middle', d.middle, nfcRequested: nfc['middle'] == true),
        _dimRow('Ring', d.ring, nfcRequested: nfc['ring'] == true),
        _dimRow('Pinky', d.pinky, nfcRequested: nfc['pinky'] == true),
      ],
    );
  }

  static Widget _dimRow(String k, String v, {bool nfcRequested = false}) {
    String formatMm(String raw) {
      final value = raw.trim();
      if (value.isEmpty || value == '-') return '-';
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed == null) return value;
      return '${parsed.toStringAsFixed(2)} mm';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    k,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (nfcRequested) ...[
                  const SizedBox(width: 6),
                  _nfcDimensionChip(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMm(v),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  static Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.0,
        ),
      ),
    );
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      final decodedRest = Uri.decodeFull(rest);
      if (rest.startsWith('data:') ||
          rest.startsWith('blob:') ||
          rest.startsWith('gs://') ||
          rest.startsWith('content://') ||
          rest.startsWith('file://') ||
          decodedRest.startsWith('data:') ||
          decodedRest.startsWith('blob:') ||
          decodedRest.startsWith('gs://') ||
          decodedRest.startsWith('content://') ||
          decodedRest.startsWith('file://') ||
          decodedRest.startsWith('http://') ||
          decodedRest.startsWith('https://')) {
        p = decodedRest;
      }
    }
    if (p.startsWith('data%3A') ||
        p.startsWith('blob%3A') ||
        p.startsWith('gs%3A') ||
        p.startsWith('content%3A') ||
        p.startsWith('file%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    return p;
  }

  Widget _shippingLabelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Shipping Label'),
        const SizedBox(height: 10),
        if (_isShippingLabelReady) ...[
          _kv('Client', _firstNameOnly(widget.request.clientName)),
          _kv(
            'City/State',
            widget.request.clientLocation.trim().isEmpty
                ? '-'
                : widget.request.clientLocation.trim(),
          ),
          _kv('Carrier', _shippingCarrierValue),
          _kv(
            'Tracking',
            _shippingTrackingValue.isEmpty
                ? 'Auto-filled on label'
                : _shippingTrackingValue,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  side: const BorderSide(color: AppColors.blackCat),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => _openLabelPreview(_shippingPdfValue),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download Label'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  side: const BorderSide(color: AppColors.blackCat),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () => _openLabelPreview(_shippingPdfValue),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print Label'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  side: const BorderSide(color: AppColors.blackCat),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _openQrDialog,
                icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                label: const Text('QR Code'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use Download/Print to attach the label, or show the QR at the carrier counter for scan-and-print drop-off.',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ] else ...[
          Text(
            'Shipping label is being prepared by platform. It will appear here with Download, Print, and QR options.',
            style: TextStyle(
              color: AppColors.blackCat.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _measurementSection() {
    final isGroup = widget.request.orderType == RequestOrderTypeV2.group;
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client Measurements'),
          const SizedBox(height: 8),
          FutureBuilder<List<GroupClientMeasurementData>>(
            future: _loadGroupMeasurementClients(),
            builder: (context, snapshot) {
              final clients = snapshot.data ?? _buildGroupMeasurementClients();
              return _compactGroupClientMeasurementsTabs(clients);
            },
          ),
          const SizedBox(height: 4),
        ],
      );
    }

    return FutureBuilder<RequestNfcDetails>(
      future: loadRequestNfcDetails(
        sourceCollection: widget.request.sourceCollection,
        requestId: widget.request.id,
      ),
      builder: (context, snapshot) {
        final nfc = snapshot.data ?? RequestNfcDetails.emptyConst;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Nail Dimensions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  fontFamily: 'ArialBold',
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _handCardCentered(
                      'Left Hand',
                      widget.request.leftHand,
                      nfc: nfc.main.left,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, color: AppColors.blackCatBorderLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _handCardCentered(
                      'Right Hand',
                      widget.request.rightHand,
                      nfc: nfc.main.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.blackCatBorderLight),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Shape',
                        style: TextStyle(
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          fontFamily: 'Arial',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.request.nailShape.trim().isEmpty
                              ? '-'
                              : widget.request.nailShape,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.blackCat,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamily: 'ArialBold',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Length',
                        style: TextStyle(
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          fontFamily: 'Arial',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lengthLabel(widget.request.nailLength).trim().isEmpty
                              ? '-'
                              : _lengthLabel(widget.request.nailLength),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.blackCat,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamily: 'ArialBold',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _compactGroupClientMeasurementsTabs(
    List<GroupClientMeasurementData> clients,
  ) {
    final safeClients = clients.isEmpty
        ? _buildGroupMeasurementClients()
        : clients;
    if (safeClients.isEmpty) return const SizedBox.shrink();
    return GroupClientMeasurementsTabs(
      clients: safeClients,
      compactRequestDetailsLayout: true,
      tabViewHeight: 312,
    );
  }

  Future<List<GroupClientMeasurementData>>
  _loadGroupMeasurementClients() async {
    final merged = <GroupClientMeasurementData>[];
    final seen = <String>{};
    final nfcDetails = await loadRequestNfcDetails(
      sourceCollection: widget.request.sourceCollection,
      requestId: widget.request.id,
    );

    void addClient(
      GroupClientMeasurementData client, {
      String email = '',
      String id = '',
    }) {
      final name = client.name.trim();
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedId = id.trim().toLowerCase();
      final normalizedName = name.toLowerCase();
      final keys = <String>{
        if (normalizedEmail.isNotEmpty) 'email:$normalizedEmail',
        if (normalizedId.isNotEmpty) 'id:$normalizedId',
        if (normalizedName.isNotEmpty) 'name:$normalizedName',
      };
      if (keys.isEmpty) return;
      if (keys.any(seen.contains)) return;
      seen.addAll(keys);
      merged.add(client);
    }

    // Submitted client must always be first.
    addClient(
      GroupClientMeasurementData(
        name: widget.request.clientName.trim().isEmpty
            ? 'Client'
            : widget.request.clientName.trim(),
        clientEmail: widget.request.clientEmail,
        nailShape: widget.request.nailShape,
        nailLength: widget.request.nailLength,
        leftHand: _dimsMap(widget.request.leftHand),
        rightHand: _dimsMap(widget.request.rightHand),
        leftNfc: nfcDetails.main.left,
        rightNfc: nfcDetails.main.right,
      ),
      email: widget.request.clientEmail,
    );

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final raw in values) {
        final text = (raw ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return fallback;
    }

    Map<String, String> dimsFrom(Object? source, {required bool left}) {
      final map = _asMap(source);
      if (map.isEmpty) return const <String, String>{};
      final nested = _asMap(map['dimensions']);
      final data = nested.isNotEmpty ? nested : map;

      String pick(String finger) {
        final upper = finger[0].toUpperCase() + finger.substring(1);
        final candidates = left
            ? <String>[finger, 'l$upper', 'left$upper', 'left_$finger']
            : <String>[finger, 'r$upper', 'right$upper', 'right_$finger'];
        for (final key in candidates) {
          final text = (data[key] ?? '').toString().trim();
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        return '';
      }

      return <String, String>{
        'thumb': pick('thumb'),
        'index': pick('index'),
        'middle': pick('middle'),
        'ring': pick('ring'),
        'pinky': pick('pinky'),
      };
    }

    Map<String, String> firstDims(List<Object?> sources, {required bool left}) {
      for (final source in sources) {
        final dims = dimsFrom(source, left: left);
        if (dims.values.any((v) => v.trim().isNotEmpty)) return dims;
      }
      return const <String, String>{};
    }

    void updateSubmittedClientFromSource(Map<String, dynamic> source) {
      if (merged.isEmpty || source.isEmpty) return;

      final payload = _asMap(source['payload']);
      final details = _asMap(source['details']);
      final data = _asMap(source['data']);
      final requestDetails = _asMap(
        source['requestDetails'] ?? source['request_details'],
      );
      final orderData = _asMap(
        source['order'] ?? source['orderData'] ?? source['order_data'],
      );
      final sources = <Map<String, dynamic>>[
        source,
        payload,
        details,
        data,
        requestDetails,
        orderData,
      ];

      final leftSources = <Object?>[];
      final rightSources = <Object?>[];
      for (final item in sources) {
        final nailPreferences = _asMap(
          item['nailPreferences'] ?? item['nail_preferences'],
        );
        final snapshotNailPreferences = _asMap(
          _asMap(
            item['clientProfileSnapshot'] ?? item['client_profile_snapshot'],
          )['nailPreferences'],
        );
        leftSources.addAll(<Object?>[
          item['leftHandDimensions'],
          item['left_hand_dimensions'],
          nailPreferences['leftHandDimensions'],
          nailPreferences['left_hand_dimensions'],
          nailPreferences['dimensions'],
          snapshotNailPreferences['dimensions'],
          item['dimensions'],
        ]);
        rightSources.addAll(<Object?>[
          item['rightHandDimensions'],
          item['right_hand_dimensions'],
          nailPreferences['rightHandDimensions'],
          nailPreferences['right_hand_dimensions'],
          nailPreferences['dimensions'],
          snapshotNailPreferences['dimensions'],
          item['dimensions'],
        ]);
      }

      final left = firstDims(leftSources, left: true);
      final right = firstDims(rightSources, left: false);
      if (left.values.every((v) => v.trim().isEmpty) &&
          right.values.every((v) => v.trim().isEmpty)) {
        return;
      }

      final current = merged.first;
      merged[0] = GroupClientMeasurementData(
        name: current.name,
        clientEmail: current.clientEmail,
        nailShape: current.nailShape,
        nailLength: current.nailLength,
        leftHand: left.values.any((v) => v.trim().isNotEmpty)
            ? left
            : current.leftHand,
        rightHand: right.values.any((v) => v.trim().isNotEmpty)
            ? right
            : current.rightHand,
        leftNfc: current.leftNfc,
        rightNfc: current.rightNfc,
      );
    }

    void addGroupClientFromMap(Map<String, dynamic> client, int index) {
      if (client.isEmpty) return;

      final email = firstNonEmpty(<Object?>[
        client['clientEmail'],
        client['client_email'],
        client['email'],
      ]).toLowerCase();
      final id = firstNonEmpty(<Object?>[
        client['clientId'],
        client['client_id'],
        client['id'],
        client['uid'],
      ]);
      final name = firstNonEmpty(<Object?>[
        client['clientName'],
        client['client_name'],
        client['name'],
        client['displayName'],
        client['display_name'],
      ], fallback: 'Client $index');

      final savedNails = _asMap(client['savedNails'] ?? client['saved_nails']);
      final draftNails = _asMap(client['draftNails'] ?? client['draft_nails']);
      final nailPreferences = _asMap(
        client['nailPreferences'] ?? client['nail_preferences'],
      );
      final nailSource = savedNails.isNotEmpty
          ? savedNails
          : (draftNails.isNotEmpty ? draftNails : nailPreferences);

      final left = firstDims(<Object?>[
        client['leftHandDimensions'],
        client['left_hand_dimensions'],
        nailSource['leftHandDimensions'],
        nailSource['left_hand_dimensions'],
        nailSource['dimensions'],
        client['dimensions'],
      ], left: true);

      final right = firstDims(<Object?>[
        client['rightHandDimensions'],
        client['right_hand_dimensions'],
        nailSource['rightHandDimensions'],
        nailSource['right_hand_dimensions'],
        nailSource['dimensions'],
        client['dimensions'],
      ], left: false);

      addClient(
        GroupClientMeasurementData(
          name: name,
          clientEmail: email,
          nailShape: firstNonEmpty(<Object?>[
            client['nailShape'],
            client['nail_shape'],
            nailSource['shape'],
            nailSource['nailShape'],
            nailSource['nail_shape'],
          ], fallback: widget.request.nailShape),
          nailLength: firstNonEmpty(<Object?>[
            client['nailLength'],
            client['nail_length'],
            nailSource['length'],
            nailSource['nailLength'],
            nailSource['nail_length'],
          ], fallback: widget.request.nailLength),
          leftHand: left,
          rightHand: right,
          leftNfc:
              (nfcDetails.groupBySlotIndex[index] ??
                      RequestFingerNfcSelection.emptyConst)
                  .left,
          rightNfc:
              (nfcDetails.groupBySlotIndex[index] ??
                      RequestFingerNfcSelection.emptyConst)
                  .right,
        ),
        email: email,
        id: id,
      );
    }

    void addGroupClientsFromSource(Map<String, dynamic> source) {
      updateSubmittedClientFromSource(source);

      final payload = _asMap(source['payload']);
      final details = _asMap(source['details']);
      final data = _asMap(source['data']);
      final requestDetails = _asMap(
        source['requestDetails'] ?? source['request_details'],
      );
      final orderData = _asMap(
        source['order'] ?? source['orderData'] ?? source['order_data'],
      );
      final nestedSources = <Map<String, dynamic>>[
        source,
        payload,
        details,
        data,
        requestDetails,
        orderData,
      ];

      var index = 1;
      for (final nested in nestedSources) {
        final groupSources = <Object?>[
          _asMap(nested['groupOrder'] ?? nested['group_order'])['clients'],
          nested['groupClients'],
          nested['group_clients'],
          nested['selectedGroupClients'],
          nested['selected_group_clients'],
          nested['groupClientMeasurements'],
          nested['group_client_measurements'],
        ];
        for (final groupSource in groupSources) {
          for (final rawClient in _asList(groupSource)) {
            addGroupClientFromMap(_asMap(rawClient), index++);
          }
        }
      }
    }

    try {
      final root = await _supabase
          .from(_requestTable)
          .select()
          .eq('id', widget.request.id)
          .maybeSingle();
      if (root != null)
        addGroupClientsFromSource(Map<String, dynamic>.from(root));

      final detailRows = await _supabase
          .from(_requestDetailsTable)
          .select()
          .eq('request_id', widget.request.id);
      for (final row in detailRows) {
        final map = _asMap(row);
        addGroupClientsFromSource(map);
        addGroupClientsFromSource(_asMap(map['data']));
      }
    } catch (_) {
      // Keep the sheet usable if RLS blocks migrated detail lookup.
    }

    for (final client in _buildGroupMeasurementClients()) {
      addClient(client);
    }

    return merged.isEmpty ? _buildGroupMeasurementClients() : merged;
  }

  List<GroupClientMeasurementData> _buildGroupMeasurementClients() {
    final clients = <GroupClientMeasurementData>[
      GroupClientMeasurementData(
        name: widget.request.clientName,
        nailShape: widget.request.nailShape,
        nailLength: widget.request.nailLength,
        leftHand: _dimsMap(widget.request.leftHand),
        rightHand: _dimsMap(widget.request.rightHand),
      ),
    ];
    final seen = <String>{
      if (widget.request.clientName.trim().isNotEmpty)
        'name:${widget.request.clientName.trim().toLowerCase()}',
      if (widget.request.clientEmail.trim().isNotEmpty)
        'email:${widget.request.clientEmail.trim().toLowerCase()}',
    };
    for (final client in widget.request.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final keys = <String>{
        if (client.clientId.trim().isNotEmpty)
          'id:${client.clientId.trim().toLowerCase()}',
        if (client.clientEmail.trim().isNotEmpty)
          'email:${client.clientEmail.trim().toLowerCase()}',
        if (name.trim().isNotEmpty) 'name:${name.trim().toLowerCase()}',
      };
      if (keys.isEmpty || keys.any(seen.contains)) continue;
      seen.addAll(keys);
      clients.add(
        GroupClientMeasurementData(
          name: name,
          nailShape: client.nailShape,
          nailLength: client.nailLength,
          leftHand: _dimsMap(client.leftHand),
          rightHand: _dimsMap(client.rightHand),
        ),
      );
      if (clients.length >= 16) break;
    }
    return clients;
  }

  Map<String, String> _dimsMap(NailDimensionsV2 dims) {
    return <String, String>{
      'thumb': dims.thumb,
      'index': dims.index,
      'middle': dims.middle,
      'ring': dims.ring,
      'pinky': dims.pinky,
    };
  }

  Widget _imageForPath(String raw) {
    final path = _normalizeImagePath(raw);
    Widget fallback() => Container(
      color: AppColors.blackCat.withValues(alpha: 0.06),
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
    );
    if (path.isEmpty) return fallback();
    final dataBytes = _decodeDataImageBytes(path);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        cacheWidth: kMaxImageDecodeDimension,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    final isNetwork =
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('content://');
    final isAsset = path.startsWith('assets/');
    final isFileUri = path.startsWith('file://');
    final isFilePath =
        !kIsWeb && (path.startsWith('/') || path.contains(':\\'));
    if (isNetwork || path.startsWith('gs://') || (kIsWeb && !isAsset)) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return fallback();
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: kMaxImageDecodeDimension,
            errorBuilder: (_, _, _) => fallback(),
          );
        },
      );
    }
    if (isAsset) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (isFileUri || isFilePath) {
      final localPath = isFileUri ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return FutureBuilder<String>(
      future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
      builder: (_, snap) {
        final url = (snap.data ?? '').trim();
        if (url.isEmpty) return fallback();
        return Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: kMaxImageDecodeDimension,
          errorBuilder: (_, _, _) => fallback(),
        );
      },
    );
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

  Widget _photosGrid(List<String> images) {
    final renderable = images
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: renderable.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final path = renderable[i];
          return SizedBox(
            width: 112,
            child: Semantics(
              button: true,
              label: 'View photo ${i + 1} full screen',
              onTap: () => _openImagePreview(path),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => _openImagePreview(path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _imageForPath(path),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openImagePreview(String path) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            AspectRatio(aspectRatio: 1, child: _imageForPath(path)),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                tooltip: 'Close image preview',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: AppColors.blackCat,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _firstNameOnly(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Client';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  Future<void> _openLabelPreview(String pdfUrl) async {
    final resolvedPdf = pdfUrl.trim().isNotEmpty
        ? pdfUrl.trim()
        : _shippingPdfValue;
    final link = resolvedPdf.trim().isEmpty
        ? 'jnt://shipping/label?order=${widget.request.id}&download=1'
        : resolvedPdf.trim();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Shipping Label', style: TextStyle(fontSize: 12)),
        content: Text(
          'Label link ready for download/print:\n\n$link',
          style: const TextStyle(fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQrDialog() async {
    final qr = _shippingQrValue.isNotEmpty
        ? _shippingQrValue
        : generateShippingQrCode(
            collectionName: widget.request.sourceCollection,
            orderDocId: widget.request.id,
            orderNumber: widget.request.orderNumber.trim().isNotEmpty
                ? widget.request.orderNumber.trim()
                : widget.request.id,
            artistId: widget.request.acceptedByArtistEmail.trim(),
          );
    if (!mounted) return;
    await showSimpleQrPrintDialog(context, qr);
  }

  static String _needByLabel(DateTime d) => formatDateMdy(d);

  static String _lengthLabel(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return 'Short';
    if (v == 'medium') return 'Medium';
    if (v == 'long') return 'Long';
    if (v == 'extra long' || v == 'xlong' || v == 'xl') return 'Extra Long';
    return len.trim();
  }
}
