import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../theme/app_colors.dart';
// for ClientRequestV2 + NailDimensionsV2 (or move models to a shared file)
import '../models/client_request_v2.dart';
import '../widgets/group_client_measurements_tabs.dart';
import '../services/shipping_qr_helper.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/shipping_qr_widgets.dart';

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
  final _trackingCtrl = TextEditingController();

  // ✅ NEW (optional, but helps keep formatting consistent)
  final _shippedDateCtrl = TextEditingController();
  DateTime? _shippedDate;

  String? _courier;
  bool _submitting = false;

  final _couriers = const ['USPS', 'UPS', 'FedEx', 'DHL', 'Other'];

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
    if (widget.request.status == RequestStatusV2.completed) return true;
    if (widget.request.shippingStatus.trim().toLowerCase() == 'label_ready') {
      return true;
    }
    if (widget.request.shippingLabelReady) return true;
    return widget.request.shippingLabelPdfUrl.trim().isNotEmpty ||
        widget.request.shippingLabelQrData.trim().isNotEmpty ||
        widget.request.shippingLabelTrackingNumber.trim().isNotEmpty;
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

    return MediaQuery(
      data: sheetMediaQuery,
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
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + math.max(0, bottomInset),
                  ),
                  children: [
                    _topHeroCentered(context, widget.request, widget.onClose),
                    const SizedBox(height: 12),

                    // Completed status message (NOT shipped yet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 26,
                          width: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDBF4E6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Color(0xFF1E8E5A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.80,
                                ),
                                height: 1.25,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Completed!\n',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      'Add courier, tracking #, and shipped date to mark as shipped and notify the client.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                    // ✅ Bio
                    _sectionTitle('Shipping Label'),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isShippingLabelReady) ...[
                          _kv(
                            'Client',
                            _firstNameOnly(widget.request.clientName),
                          ),
                          _kv(
                            'City/State',
                            widget.request.clientLocation.trim().isEmpty
                                ? '-'
                                : widget.request.clientLocation.trim(),
                          ),
                          _kv(
                            'Carrier',
                            widget.request.shippingLabelCarrier.trim().isEmpty
                                ? 'USPS'
                                : widget.request.shippingLabelCarrier.trim(),
                          ),
                          _kv(
                            'Tracking',
                            widget.request.shippingLabelTrackingNumber
                                    .trim()
                                    .isEmpty
                                ? (_trackingCtrl.text.trim().isEmpty
                                      ? 'Auto-filled on label'
                                      : _trackingCtrl.text.trim())
                                : widget.request.shippingLabelTrackingNumber
                                      .trim(),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openLabelPreview(
                                  widget.request.shippingLabelPdfUrl,
                                ),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 16,
                                ),
                                label: const Text('Download Label'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openLabelPreview(
                                  widget.request.shippingLabelPdfUrl,
                                ),
                                icon: const Icon(Icons.print_rounded, size: 16),
                                label: const Text('Print Label'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openQrDialog,
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 16,
                                ),
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
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Description'),
                    const SizedBox(height: 8),
                    Text(
                      widget.request.bio.isEmpty ? '—' : widget.request.bio,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                    if (_isBrandRequest(widget.request)) ...[
                      _acceptedClientDetailsSection(widget.request),
                      const SizedBox(height: 12),
                      const Divider(
                        height: 1,
                        color: AppColors.blackCatBorderLight,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _measurementSection(),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),

                    // ✅ Client uploaded photos
                    _sectionTitle('Uploaded Photos (Client)'),
                    const SizedBox(height: 10),
                    if (widget.request.clientImages.isEmpty)
                      _softBox(
                        Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'No images uploaded',
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _photosGrid(widget.request.clientImages),

                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),

                    // ✅ Artist uploaded photos
                    _sectionTitle('Uploaded Photos (Artist)'),
                    const SizedBox(height: 10),
                    if (widget.request.artistImages.isEmpty)
                      _softBox(
                        Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: AppColors.blackCat.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'No artist photos uploaded',
                              style: TextStyle(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _photosGrid(widget.request.artistImages),

                    const SizedBox(height: 16),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),

                    // ✅ Shipping input
                    _sectionTitle('Shipping (required)'),
                    const SizedBox(height: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shipped by',
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.60),
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _courier,
                          dropdownColor: AppColors.snow,
                          items: _couriers
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _courier = v),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.snow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: AppColors.blackCat),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Tracking #',
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.60),
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _trackingCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter tracking number',
                            hintStyle: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: AppColors.snow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: AppColors.blackCat),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),

                        // ✅ NEW: Shipped Date AFTER Tracking #
                        const SizedBox(height: 12),
                        Text(
                          'Shipped Date',
                          style: TextStyle(
                            color: AppColors.blackCat.withValues(alpha: 0.60),
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),

                        InkWell(
                          borderRadius: BorderRadius.zero,
                          onTap: _pickShippedDate,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.snow,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _shippedDate == null
                                        ? 'Select shipped date'
                                        : '${_shippedDate!.month}/${_shippedDate!.day}/${_shippedDate!.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13.5,
                                      color: _shippedDate == null
                                          ? AppColors.blackCat.withValues(
                                              alpha: 0.45,
                                            )
                                          : AppColors.blackCat.withValues(
                                              alpha: 0.90,
                                            ),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom CTA
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + math.max(0, bottomInset),
                ),
                child: Center(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        disabledBackgroundColor: AppColors.blackCat.withValues(
                          alpha: 0.18,
                        ),
                        foregroundColor: AppColors.snow,
                        disabledForegroundColor: AppColors.snow.withValues(
                          alpha: 0.78,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                      ),
                      onPressed: (!_isValid || _submitting)
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              try {
                                await widget.onMarkShipped(
                                  courier: _courier!.trim(),
                                  tracking: _trackingCtrl.text.trim(),
                                  shippedDate: _shippedDate!,
                                );
                                if (mounted) Navigator.pop(context);
                              } finally {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                }
                              }
                            },
                      child: Text(
                        _submitting ? 'Updating...' : 'Mark as Shipped',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.snow,
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
                if (avatarPath.isNotEmpty)
                  SizedBox(
                    height: 78,
                    width: 78,
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: _imageForPath(avatarPath),
                    ),
                  )
                else
                  Container(
                    height: 78,
                    width: 78,
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
                      child: _chipInfo(
                        icon: Icons.calendar_today_outlined,
                        text: 'Need by: ${_needByLabel(request.neededBy)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _chipInfo(
                        icon: Icons.attach_money_rounded,
                        text:
                            'Budget: \$${request.budgetMin} to \$${request.budgetMax}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.blackCatBorderLight),
              ],
            ),
          ),
        ),

        Positioned(
          right: 6,
          top: 6,
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
      ],
    );
  }

  bool _isBrandRequest(ClientRequestV2 request) =>
      request.sourceCollection == 'Company_Custom_Requests' ||
      request.orderNumber.trim().toUpperCase().startsWith('BE-') ||
      request.orderNumber.trim().toUpperCase().startsWith('BR-');

  Widget _outlinedChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9FC0E8)),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _acceptedClientDetailsSection(ClientRequestV2 request) {
    final name = request.acceptedClientName.trim().isNotEmpty
        ? request.acceptedClientName.trim()
        : (request.clientName.trim().isNotEmpty
              ? request.clientName.trim()
              : 'Client');
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

  String _safeAcceptedClientAvatarPath(ClientRequestV2 request) {
    final accepted = _normalizeImagePath(
      request.acceptedClientProfileImage.trim(),
    );
    if (accepted.isEmpty) return '';
    final blocked = <String>{
      _normalizeImagePath(request.clientProfileImage),
      _normalizeImagePath(request.previewImageAsset),
    }..removeWhere((e) => e.trim().isEmpty);
    return blocked.contains(accepted) ? '' : accepted;
  }

  Widget _requestTypeOrderRow(ClientRequestV2 r) {
    final requestType = r.isDirectRequest
        ? 'Direct Request'
        : 'Standard Request';
    final orderType = r.orderType == RequestOrderTypeV2.group
        ? 'Group Order'
        : 'Single Order';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          r.isDirectRequest
              ? Icons.arrow_outward_rounded
              : Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Text(
          requestType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
        ),
        const SizedBox(width: 14),
        Container(width: 1, height: 16, color: AppColors.blackCatBorderLight),
        const SizedBox(width: 14),
        Icon(
          r.orderType == RequestOrderTypeV2.group
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Text(
          orderType,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
        ),
      ],
    );
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );

  static Widget _softBox(Widget child) {
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

  static Widget _chipInfo({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.blackCat),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  static Widget _handCardCentered(String title, NailDimensionsV2 d) {
    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          _dimRow('Thumb', d.thumb),
          _dimRow('Index', d.index),
          _dimRow('Middle', d.middle),
          _dimRow('Ring', d.ring),
          _dimRow('Pinky', d.pinky),
        ],
      ),
    );
  }

  static Widget _dimRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.65),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
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

  Widget _measurementSection() {
    final isGroup = widget.request.orderType == RequestOrderTypeV2.group;
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client Measurements'),
          const SizedBox(height: 10),
          GroupClientMeasurementsTabs(clients: _buildGroupMeasurementClients()),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Nail Dimensions (mm)'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _handCardCentered('Left Hand', widget.request.leftHand),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _handCardCentered('Right Hand', widget.request.rightHand),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _softBox(
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nail Shape',
                        style: TextStyle(
                          color: AppColors.blackCat.withValues(alpha: 0.60),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      widget.request.nailShape,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _softBox(
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nail Length',
                        style: TextStyle(
                          color: AppColors.blackCat.withValues(alpha: 0.60),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      _lengthLabel(widget.request.nailLength),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
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
    final seen = <String>{widget.request.clientName.trim().toLowerCase()};
    for (final client in widget.request.groupClients) {
      final name = client.clientName.trim().isEmpty
          ? 'Client ${client.slotIndex}'
          : client.clientName.trim();
      final key = client.clientId.trim().isNotEmpty
          ? client.clientId.trim().toLowerCase()
          : name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
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
            child: InkWell(
              onTap: () => _openImagePreview(path),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _imageForPath(path),
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
                color: AppColors.blackCat.withValues(alpha: 0.55),
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
    final link = pdfUrl.trim().isEmpty
        ? 'jnt://shipping/label?order=${widget.request.id}&download=1'
        : pdfUrl.trim();
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
    final qr = widget.request.shippingQrCode.trim().isNotEmpty
        ? widget.request.shippingQrCode.trim()
        : (widget.request.shippingLabelQrData.trim().isEmpty
              ? generateShippingQrCode(
                  collectionName: widget.request.sourceCollection,
                  orderDocId: widget.request.id,
                  orderNumber: widget.request.orderNumber.trim().isNotEmpty
                      ? widget.request.orderNumber.trim()
                      : widget.request.id,
                  artistId: widget.request.acceptedByArtistEmail.trim(),
                )
              : widget.request.shippingLabelQrData.trim());
    if (!mounted) return;
    await showSimpleQrPrintDialog(context, qr);
  }

  static String _needByLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wds[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  static String _lengthLabel(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return 'Short';
    if (v == 'medium') return 'Medium';
    if (v == 'long') return 'Long';
    if (v == 'extra long' || v == 'xlong' || v == 'xl') return 'Extra Long';
    return len.trim();
  }
}
