import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../utils/date_format_utils.dart';
import '../utils/image_cache_utils.dart';
// for ClientRequestV2 + NailDimensionsV2 (or move models to a shared file)
import '../models/client_request_v2.dart';
import '../widgets/accessible_date_grid.dart';
import '../widgets/group_client_measurements_tabs.dart';
import '../widgets/request_modal_accessibility.dart';
import '../utils/request_nfc_details_loader.dart';
import '../utils/company_bio_loader.dart';
import '../services/shipping_qr_helper.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/shipping_qr_widgets.dart';
import '../utlis/responsive_layout.dart';

part 'artist_completed_details_tab.dart';
part 'artist_completed_photos_tab.dart';
part 'artist_completed_shipping_tab.dart';

// Real Shippo label purchase needs the Shippo *secret* API token, which
// must never ship inside the Flutter app -- see
// supabase/functions/create-shipping-label/index.ts, which is written but
// not deployed yet. Until that function is deployed and this flag is
// flipped, "Get Shipping Label" only simulates a label so the rest of the
// ready-to-ship flow (auto-filled courier/tracking, Track Order) can be
// tested end to end. Flipping it requires deploying create-shipping-label
// and shippo-webhook, and setting SHIPPO_API_TOKEN as an Edge Function
// secret.
const bool kShippingLiveEnabled = false;

/// One row in the "ship to each group member individually" list -- the
/// primary client (key 'self') plus every group member.
class _ShipmentRecipient {
  const _ShipmentRecipient({
    required this.key,
    required this.name,
    required this.email,
    required this.tag,
    required this.hasAddress,
    required this.addressLabel,
  });

  final String key;
  final String name;
  final String email;
  final String tag;
  final bool hasAddress;
  final String addressLabel;
}

Widget completedSectionTitle(String text) {
  return Semantics(
    header: true,
    label: text,
    child: ExcludeSemantics(
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.blackCat,
        ),
      ),
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
    required GroupShippingMode mode,
    required DateTime shippedDate,
    String courier,
    String tracking,
    List<ShipmentRecipientEntry> recipients,
  })
  onMarkShipped,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: isTabletSize(MediaQuery.sizeOf(context))
        ? const BoxConstraints(maxWidth: 1000)
        : null,
    backgroundColor: Colors.transparent,
    builder: (_) => CompletedRequestSheetBody(
      request: request,
      shipDays: shipDays,
      onClose: onClose,
      onMarkShipped: onMarkShipped,
    ),
  );
}

class CompletedRequestSheetBody extends StatefulWidget {
  const CompletedRequestSheetBody({
    required this.request,
    required this.shipDays,
    required this.onClose,
    required this.onMarkShipped,
  });

  final ClientRequestV2 request;
  final int shipDays;
  final VoidCallback onClose;

  final Future<void> Function({
    required GroupShippingMode mode,
    required DateTime shippedDate,
    String courier,
    String tracking,
    List<ShipmentRecipientEntry> recipients,
  })
  onMarkShipped;

  @override
  State<CompletedRequestSheetBody> createState() =>
      _CompletedRequestSheetState();
}

class _CompletedRequestSheetState extends State<CompletedRequestSheetBody> {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Flutter's iOS accessibility bridge doesn't reliably honor a proactively
  // *pushed* FocusSemanticEvent right after a TextField's keyboard closes --
  // this is a documented, still-open Flutter/iOS engine limitation
  // (flutter/flutter#36910, #137235: requestFocus()/sendSemanticsEvent
  // losing to iOS's own native VoiceOver focus resolution after the keyboard
  // dismisses), not something any amount of Dart-side delay tuning can win;
  // every timing variant tried here (immediate, 350ms, 650ms, awaiting the
  // hide call, a didChangeMetrics-based wait for the keyboard inset to hit
  // zero) still lost that race on a real device.
  //
  // So instead of pushing, this *catches* -- but where iOS actually lands
  // isn't a single fixed spot, and isn't even a single hop: observed
  // bouncing through the Shipping Label heading (the first accessible
  // element in the tab) and then the Courier/"Shipped by" field (the
  // immediately preceding sibling of the tracking field in reading order)
  // in sequence before settling, not just landing on one of them once.
  // _keepFieldFocusAfterSubmit arms this key; every plausible landing spot
  // (the Shipping Label heading, plus the self and per-recipient Courier
  // fields) wires the same trap via onDidGainAccessibilityFocus and
  // re-fires the redirect on *every* hit while armed -- disarming after
  // the first catch let a second bounce (to a different wrong spot) land
  // uncaught. The redirect target's own onDidGainAccessibilityFocus (see
  // the tracking fields below) is what actually disarms it, confirming the
  // redirect stuck rather than assuming the first catch was the only one
  // needed -- the same catch-and-redirect pattern already proven working
  // elsewhere in this modal (see _redirectEndOfModalToClose), extended to
  // keep retrying until it's confirmed to have worked.
  GlobalKey? _pendingTrackingFieldRefocusKey;

  void _handleTrackingFieldSelfFocused() {
    _pendingTrackingFieldRefocusKey = null;
  }

  // Landing on the wrong field even briefly is enough for Flutter to
  // scroll it into view, and the keyboard closing resizes the ListView's
  // viewport too -- together these produce a visible scroll/jump right as
  // Done is tapped, even though the tracking field itself hasn't actually
  // moved and doesn't need to be re-revealed. _keepFieldFocusAfterSubmit
  // captures the offset and holds it (via the scroll listener below)
  // through the whole close/refocus sequence, then releases it.
  double? _heldShippingScrollOffset;

  void _holdShippingScrollOffset() {
    final target = _heldShippingScrollOffset;
    if (target == null || !_listController.hasClients) return;
    if ((_listController.offset - target).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      final stillHeld = _heldShippingScrollOffset;
      if (stillHeld == null) return;
      final clamped = stillHeld.clamp(
        _listController.position.minScrollExtent,
        _listController.position.maxScrollExtent,
      );
      if ((_listController.offset - clamped).abs() > 0.5) {
        _listController.jumpTo(clamped);
      }
    });
  }

  void _handleTrackingRefocusTrapFocused() {
    final target = _pendingTrackingFieldRefocusKey;
    if (target == null) return;
    // Deliberately not disarmed here -- see the field declaration. Only
    // _handleTrackingFieldSelfFocused (the redirect target actually
    // gaining focus) or the safety timeout in _keepFieldFocusAfterSubmit
    // clears this, so a second wrong-spot bounce after this one still gets
    // caught and redirected too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      target.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  final _trackingCtrl = TextEditingController();
  final FocusNode _closeFocusNode = FocusNode(
    debugLabel: 'completedRequestClose',
  );
  // Separate from _closeFocusNode, which is already attached to the visual
  // (ExcludeSemantics-wrapped) close icon -- a FocusNode can only be
  // attached to one widget at a time, and this one drives the accessible
  // RequestModalInitialClose control instead.
  final FocusNode _accessibleCloseFocusNode = FocusNode(
    debugLabel: 'completedRequestAccessibleClose',
  );
  final GlobalKey _closeSemanticsKey = GlobalKey(
    debugLabel: 'completedRequestCloseSemantics',
  );
  final ScrollController _listController = ScrollController();
  final FocusNode _detailsContentFocusNode = FocusNode(
    debugLabel: 'completedDetailsContent',
  );
  final FocusNode _photosContentFocusNode = FocusNode(
    debugLabel: 'completedPhotosContent',
  );
  final FocusNode _shippingContentFocusNode = FocusNode(
    debugLabel: 'completedShippingContent',
  );
  bool _didRequestInitialFocus = false;

  // ✅ NEW (optional, but helps keep formatting consistent)
  final _shippedDateCtrl = TextEditingController();
  DateTime? _shippedDate;

  String? _courier;
  bool _submitting = false;

  // Selecting a courier/date closes a modal (bottom sheet or date picker);
  // Flutter's post-close focus fallback otherwise lands somewhere unrelated
  // (e.g. the Shipping Label section above) instead of the field the user
  // was just on. These stay on the field they belong to across that
  // close-then-rebuild sequence, unlike a GlobalKey/FocusNode created fresh
  // inside the field's own build method, which goes stale the moment
  // selecting a value triggers setState and rebuilds it with a new one.
  final FocusNode _courierFocusNode = FocusNode(
    debugLabel: 'completedShippingCourier',
  );
  final GlobalKey _courierSemanticsKey = GlobalKey(
    debugLabel: 'completedShippingCourierSemantics',
  );
  final FocusNode _trackingFocusNode = FocusNode(
    debugLabel: 'completedShippingTracking',
  );
  final GlobalKey _trackingSemanticsKey = GlobalKey(
    debugLabel: 'completedShippingTrackingSemantics',
  );
  final FocusNode _shippedDateFocusNode = FocusNode(
    debugLabel: 'completedShippingDate',
  );
  final GlobalKey _shippedDateSemanticsKey = GlobalKey(
    debugLabel: 'completedShippingDateSemantics',
  );

  // Group order shipping (ship to each member individually): courier +
  // tracking are keyed per recipient instead of one shared pair. 'self'
  // is the primary client; group members are keyed by clientId (falling
  // back to slot index if a legacy row has no clientId).
  final Map<String, String?> _recipientCouriers = {};
  final Map<String, TextEditingController> _recipientTrackingCtrls = {};
  final Map<String, FocusNode> _recipientCourierFocusNodes = {};
  final Map<String, GlobalKey> _recipientCourierSemanticsKeys = {};
  final Map<String, FocusNode> _recipientTrackingFocusNodes = {};
  final Map<String, GlobalKey> _recipientTrackingSemanticsKeys = {};

  bool get _isRespectiveShippingMode =>
      widget.request.orderType == RequestOrderTypeV2.group &&
      widget.request.groupShippingMode == GroupShippingMode.toRespectiveClient;

  List<_ShipmentRecipient> get _shipmentRecipients {
    final selfCityState = [
      widget.request.shippingCity,
      widget.request.shippingState,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    return <_ShipmentRecipient>[
      _ShipmentRecipient(
        key: 'self',
        name: widget.request.clientName.trim().isEmpty
            ? 'You'
            : widget.request.clientName.trim(),
        email: widget.request.clientEmail,
        tag: 'You',
        hasAddress: true,
        addressLabel: widget.request.shippingAddressDifferentFromProfile
            ? (selfCityState.isEmpty ? 'Address on file' : selfCityState)
            : 'Profile address',
      ),
      for (final gc in widget.request.groupClients)
        _ShipmentRecipient(
          key: gc.clientId.trim().isNotEmpty
              ? gc.clientId.trim()
              : 'slot-${gc.slotIndex}',
          name: gc.clientName.trim().isEmpty
              ? 'Client ${gc.slotIndex}'
              : gc.clientName.trim(),
          email: gc.clientEmail,
          tag: 'Group',
          hasAddress: !gc.shippingAddress.isEmpty,
          addressLabel: gc.shippingAddress.isEmpty
              ? ''
              : gc.shippingAddress.cityState,
        ),
    ];
  }

  TextEditingController _trackingCtrlFor(String key) {
    return _recipientTrackingCtrls.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  FocusNode _courierFocusNodeFor(String key) {
    if (key == 'self') return _courierFocusNode;
    return _recipientCourierFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'completedShippingCourier-$key'),
    );
  }

  GlobalKey _courierSemanticsKeyFor(String key) {
    if (key == 'self') return _courierSemanticsKey;
    return _recipientCourierSemanticsKeys.putIfAbsent(
      key,
      () => GlobalKey(debugLabel: 'completedShippingCourierSemantics-$key'),
    );
  }

  FocusNode _trackingFocusNodeFor(String key) {
    if (key == 'self') return _trackingFocusNode;
    return _recipientTrackingFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'completedShippingTracking-$key'),
    );
  }

  GlobalKey _trackingSemanticsKeyFor(String key) {
    if (key == 'self') return _trackingSemanticsKey;
    return _recipientTrackingSemanticsKeys.putIfAbsent(
      key,
      () => GlobalKey(debugLabel: 'completedShippingTrackingSemantics-$key'),
    );
  }
  bool? _dbShippingLabelReady;
  String _dbShippingLabelQrData = '';
  String _dbShippingQrCode = '';
  String _dbShippingLabelPdfUrl = '';
  String _dbShippingLabelCarrier = '';
  String _dbShippingLabelTrackingNumber = '';
  bool _generatingShippingLabel = false;
  Map<String, Map<String, dynamic>> _dbRecipientShippingLabels = {};
  final Set<String> _generatingShippingLabelFor = {};

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

  bool _accessibleNavigation(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.accessibleNavigation ?? false) ||
        WidgetsBinding.instance.platformDispatcher.semanticsEnabled ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
  }

  void _requestAccessibleFocus(FocusNode node) {
    if (!_accessibleNavigation(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      node.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestInitialFocus || !_accessibleNavigation(context)) return;
    _didRequestInitialFocus = true;
    _requestAccessibleFocus(_closeFocusNode);
  }

  RealtimeChannel? _shippingLabelChannel;

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
    _listenForShippingLabelUpdates();
  }

  // Keeps this sheet's label/tracking fields live if admin (or the artist on
  // another device) updates the row while it's open, instead of only ever
  // reflecting the one-time load from initState.
  void _listenForShippingLabelUpdates() {
    _shippingLabelChannel = _supabase
        .channel('shipping-label-${widget.request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _requestTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.request.id,
          ),
          callback: (_) => _loadLatestShippingLabel(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _shippingLabelChannel?.unsubscribe();
    _trackingCtrl.dispose();
    _shippedDateCtrl.dispose(); // ✅ NEW
    for (final ctrl in _recipientTrackingCtrls.values) {
      ctrl.dispose();
    }
    _courierFocusNode.dispose();
    _trackingFocusNode.dispose();
    _shippedDateFocusNode.dispose();
    for (final node in _recipientCourierFocusNodes.values) {
      node.dispose();
    }
    for (final node in _recipientTrackingFocusNodes.values) {
      node.dispose();
    }
    _closeFocusNode.dispose();
    _accessibleCloseFocusNode.dispose();
    _listController.dispose();
    _detailsContentFocusNode.dispose();
    _photosContentFocusNode.dispose();
    _shippingContentFocusNode.dispose();
    super.dispose();
  }

  void _scrollListToTop() {
    if (!_listController.hasClients) return;
    _listController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _focusAccessibleCloseButton() {
    if (!mounted) return;
    _accessibleCloseFocusNode.requestFocus();
    _closeSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  // VoiceOver/TalkBack doesn't reliably wrap from the last element back to
  // the first on its own, so swiping past Mark as Shipped can otherwise
  // feel like nothing happens. This invisible stop is placed as the very
  // last thing in the scrollable content -- once focus reaches it, scroll
  // back to the top and redirect real focus onto the visible X button,
  // closing the loop.
  void _redirectEndOfModalToClose() {
    _scrollListToTop();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusAccessibleCloseButton(),
    );
  }

  Widget _buildAccessibilityCloseLoopTarget() {
    return Semantics(
      container: true,
      button: true,
      label: 'Close completed request details',
      hint: 'Double tap to close',
      onTap: widget.onClose,
      onDidGainAccessibilityFocus: _redirectEndOfModalToClose,
      child: const SizedBox(width: 1, height: 1),
    );
  }

  @override
  void didUpdateWidget(covariant CompletedRequestSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when request data changes to ensure data is synced
    if (oldWidget.request != widget.request) {
      setState(() {});
    }
  }

  bool get _isValid {
    if (_shippedDate == null) return false;
    if (!_isRespectiveShippingMode) {
      return (_courier != null && _courier!.trim().isNotEmpty) &&
          _trackingCtrl.text.trim().isNotEmpty;
    }
    final recipients = _shipmentRecipients;
    if (recipients.isEmpty) return false;
    for (final recipient in recipients) {
      if (!recipient.hasAddress) return false;
      final courier = _recipientCouriers[recipient.key];
      final tracking = _trackingCtrlFor(recipient.key).text.trim();
      if (courier == null || courier.trim().isEmpty || tracking.isEmpty) {
        return false;
      }
    }
    return true;
  }

  bool get _isShippingLabelReady {
    // shipping_status is set to 'label_ready' by artist_mark_request_completed
    // the moment the order is marked completed -- before any real label
    // exists -- so it can't be trusted on its own here. Only treat the
    // label as ready once there's an actual label marker (the explicit
    // shipping_label_ready column, or real qr/pdf/tracking data).
    if (_dbShippingLabelReady == true) return true;
    // _shippingQrValue is intentionally NOT used as a readiness signal --
    // it also includes the generic "scan to confirm shipment" QR that's
    // always present from completion time on (see _dbShippingQrCode).
    // _dbShippingLabelQrData is the real-label-only QR namespace.
    if (_dbShippingLabelQrData.isNotEmpty) return true;
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

  String get _shippingTrackingValue => _firstNonEmpty([
    _dbShippingLabelTrackingNumber,
    widget.request.shippingLabelTrackingNumber,
    _trackingCtrl.text,
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
            // Deliberately NOT shipping['qrCode'] -- that's the generic
            // "scan to confirm shipment" QR buildShippingPayload() always
            // writes into data.shipping.qrCode at completion time, before
            // any real label exists. shippingLabel['qrData'] below is the
            // separate, real-label namespace (data.shippingLabel), only
            // populated once admin or Shippo actually creates a label.
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

        // Per-recipient labels (group orders shipping to each member
        // individually) live under data.shippingLabels.<recipientKey>,
        // separate from the single-label columns above.
        final recipientLabels = <String, dynamic>{
          ..._asMap(rootData['shippingLabels']),
          ..._asMap(payload['shippingLabels']),
          ..._asMap(details['shippingLabels']),
        };
        _dbRecipientShippingLabels = {
          for (final entry in recipientLabels.entries)
            entry.key: _asMap(entry.value),
        };
        for (final entry in _dbRecipientShippingLabels.entries) {
          final tracking = _firstNonEmpty([entry.value['trackingNumber']]);
          if (tracking.isNotEmpty) {
            _trackingCtrlFor(entry.key).text = tracking;
          }
          final carrier = _firstNonEmpty([entry.value['carrier']]);
          if (carrier.isNotEmpty && _couriers.contains(carrier)) {
            _recipientCouriers[entry.key] = carrier;
          }
        }
      });
    } catch (_) {
      // Best-effort refresh only. The sheet still renders from widget.request.
    }
  }

  Map<String, dynamic> _recipientLabel(String key) =>
      _dbRecipientShippingLabels[key] ?? const <String, dynamic>{};

  bool _recipientLabelReady(String key) {
    final label = _recipientLabel(key);
    return _asBool(label['ready']) ||
        _firstNonEmpty([label['trackingNumber']]).isNotEmpty;
  }

  String _recipientLabelCarrier(String key) =>
      _firstNonEmpty([_recipientLabel(key)['carrier']]);

  String _recipientLabelQr(String key) =>
      _firstNonEmpty([_recipientLabel(key)['qrData']]);

  String _recipientLabelPdf(String key) =>
      _firstNonEmpty([_recipientLabel(key)['pdfUrl']]);

  /// Entry point for the "Get Shipping Label" action. Routes to the real
  /// Shippo call once kShippingLiveEnabled is flipped on; simulates a label
  /// for testing otherwise -- same shape as _payNow/_simulatePayment in
  /// order_details_pages.dart for Stripe.
  Future<void> _getShippingLabel() async {
    if (_generatingShippingLabel) return;
    setState(() => _generatingShippingLabel = true);
    try {
      if (kShippingLiveEnabled) {
        // await _supabase.functions.invoke('create-shipping-label', body: {
        //   'requestId': widget.request.id,
        //   'sourceCollection': widget.request.sourceCollection,
        // });
      } else {
        await _simulateGenerateShippingLabel();
      }
      await _loadLatestShippingLabel();
    } finally {
      if (mounted) setState(() => _generatingShippingLabel = false);
    }
  }

  /// Writes fabricated label/tracking data onto the request row so the rest
  /// of the ready-to-ship flow (auto-filled courier/tracking on the Mark as
  /// Shipped form, Track Order display) can be exercised before Shippo is
  /// live. Mirrors the columns supabase/functions/create-shipping-label
  /// will write for real.
  Future<void> _simulateGenerateShippingLabel() async {
    final now = DateTime.now();
    final carrier = _dbShippingLabelCarrier.isNotEmpty
        ? _dbShippingLabelCarrier
        : (_couriers.contains(_courier) ? _courier! : _couriers.first);
    final tracking = _simulatedTrackingNumberFor(carrier, now);
    await _supabase
        .from(_requestTable)
        .update({
          'shipping_label_ready': true,
          'shipping_label_carrier': carrier,
          'shipping_label_tracking_number': tracking,
          'shipping_label_qr_data': tracking,
          'shipping_qr_code': tracking,
          'shipping_label_created_at': now.toIso8601String(),
          'shipping_status': 'label_ready',
          'estimated_delivery_at': now
              .add(const Duration(days: 5))
              .toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', widget.request.id);
  }

  String _simulatedTrackingNumberFor(
    String carrier,
    DateTime now, {
    String seed = '',
  }) {
    final base = now.millisecondsSinceEpoch + seed.hashCode.abs() % 100000;
    final digits = base.toString();
    final tail = digits.substring(math.max(0, digits.length - 10));
    switch (carrier) {
      case 'UPS':
        return '1Z$tail SIM';
      case 'FedEx':
        return '$tail${tail.substring(0, 4)}';
      case 'DHL':
        return 'DHL$tail';
      case 'USPS':
      default:
        return '9400 $tail SIM';
    }
  }

  /// Entry point for the per-recipient "Get Shipping Label" action shown on
  /// group orders that ship to each member individually -- same
  /// simulate/live split as _getShippingLabel, but scoped to one recipient's
  /// entry under data.shippingLabels.
  Future<void> _getShippingLabelForRecipient(
    _ShipmentRecipient recipient,
  ) async {
    if (_generatingShippingLabelFor.contains(recipient.key)) return;
    setState(() => _generatingShippingLabelFor.add(recipient.key));
    try {
      if (kShippingLiveEnabled) {
        // await _supabase.functions.invoke('create-shipping-label', body: {
        //   'requestId': widget.request.id,
        //   'sourceCollection': widget.request.sourceCollection,
        //   'recipientKey': recipient.key,
        // });
      } else {
        await _simulateGenerateShippingLabelForRecipient(recipient);
      }
      await _loadLatestShippingLabel();
    } finally {
      if (mounted) {
        setState(() => _generatingShippingLabelFor.remove(recipient.key));
      }
    }
  }

  Future<void> _simulateGenerateShippingLabelForRecipient(
    _ShipmentRecipient recipient,
  ) async {
    final now = DateTime.now();
    final existingCarrier = _recipientLabelCarrier(recipient.key);
    final carrier = existingCarrier.isNotEmpty
        ? existingCarrier
        : _couriers.first;
    final tracking = _simulatedTrackingNumberFor(
      carrier,
      now,
      seed: recipient.key,
    );

    final row = await _supabase
        .from(_requestTable)
        .select('data')
        .eq('id', widget.request.id)
        .maybeSingle();
    final currentData = _asMap(row?['data']);
    final currentLabels = _asMap(currentData['shippingLabels']);
    final updatedLabels = <String, dynamic>{
      ...currentLabels,
      recipient.key: {
        'ready': true,
        'carrier': carrier,
        'trackingNumber': tracking,
        'qrData': tracking,
        'pdfUrl': '',
        'recipientName': recipient.name,
        'createdAt': now.toIso8601String(),
      },
    };

    await _supabase
        .from(_requestTable)
        .update({
          'data': {...currentData, 'shippingLabels': updatedLabels},
          'updated_at': now.toIso8601String(),
        })
        .eq('id', widget.request.id);
  }

  Future<void> _openLabelPreviewForRecipient(
    _ShipmentRecipient recipient,
  ) async {
    final pdfUrl = _recipientLabelPdf(recipient.key);
    final link = pdfUrl.trim().isEmpty
        ? 'jnt://shipping/label?order=${widget.request.id}&recipient=${recipient.key}&download=1'
        : pdfUrl.trim();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'Shipping Label — ${recipient.name}',
          style: const TextStyle(fontSize: 12),
        ),
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

  Future<void> _openQrDialogForRecipient(_ShipmentRecipient recipient) async {
    final storedQr = _recipientLabelQr(recipient.key);
    final qr = storedQr.isNotEmpty && storedQr.length <= _maxQrDataLength
        ? storedQr
        : generateShippingQrCode(
            collectionName: widget.request.sourceCollection,
            orderDocId: widget.request.id,
            orderNumber:
                '${widget.request.orderNumber.trim().isNotEmpty ? widget.request.orderNumber.trim() : widget.request.id}-${recipient.key}',
            artistId: widget.request.acceptedByArtistEmail.trim(),
          );
    if (!mounted) return;
    await showSimpleQrPrintDialog(context, qr);
  }

  Future<void> _pickShippedDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2000, 1, 1);
    final lastDate = today;
    final requestedInitial = _shippedDate ?? today;
    final initial = requestedInitial.isBefore(firstDate)
        ? firstDate
        : requestedInitial.isAfter(lastDate)
        ? lastDate
        : requestedInitial;

    final picked = await showAccessibleDatePickerDialog(
      context: context,
      fieldLabel: 'Shipped Date',
      firstDate: firstDate,
      lastDate: lastDate,
      initialSelectedDate: initial,
    );

    if (picked == null || !mounted) return;
    setState(() {
      _shippedDate = picked;
      _shippedDateCtrl.text = '${picked.month}/${picked.day}/${picked.year}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shippedDateFocusNode.requestFocus();
      _shippedDateSemanticsKey.currentContext?.findRenderObject()
          ?.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    final isTablet = isTabletSize(MediaQuery.sizeOf(context));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetMediaQuery = MediaQuery.of(context);

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
                    child: ListView(
                      controller: _listController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 24 : 16,
                        0,
                        isTablet ? 24 : 16,
                        16 + math.max(0.0, bottomInset),
                      ),
                      children: [
                        // Always present, regardless of keyboard visibility.
                        // This used to be wrapped in `if (!keyboardOpen)` to
                        // save vertical space while typing, but toggling it
                        // in and out of the list on every keyboard
                        // open/close inserts/removes real height above
                        // whatever the user is currently scrolled to --
                        // every field below it (including Tracking #) jumps
                        // by that amount the instant the keyboard opens or
                        // closes, which read as an uncontrolled scroll no
                        // amount of scroll-offset holding around the Done
                        // handler could fix, since the content itself was
                        // moving, not just the raw scroll offset.
                        _topHeroCentered(
                          context,
                          widget.request,
                          widget.onClose,
                        ),
                        const SizedBox(height: 12),
                        _completedStatusBanner(),
                        const SizedBox(height: 12),
                        const Divider(
                          height: 1,
                          color: AppColors.blackCatBorderLight,
                        ),
                        const SizedBox(height: 12),
                        ..._completedDetailsSectionItems(),
                        const SizedBox(height: 20),
                        ..._completedPhotosSectionItems(),
                        const SizedBox(height: 20),
                        ..._completedShippingSectionItems(),
                        _buildAccessibilityCloseLoopTarget(),
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
    final avatarLetter = headerName.isEmpty
        ? (isBrandRequest ? 'B' : 'C')
        : headerName[0].toUpperCase();
    final requestType = request.requestTypeLabel.isNotEmpty
        ? request.requestTypeLabel
        : (request.isDirectRequest ? 'Direct' : 'Standard');
    final orderType = request.orderType == RequestOrderTypeV2.group
        ? 'Group'
        : 'Single';
    final orderNumber = request.orderNumber.trim().isNotEmpty
        ? request.orderNumber.trim()
        : request.id;
    final summaryLabel =
        '$headerName. ${headerSubtitle.isEmpty ? '' : '$headerSubtitle. '}'
        'Order number $orderNumber. $requestType request. $orderType order. '
        'Need by ${_needByLabel(request.neededBy)}. '
        'Budget ${request.budgetMin} dollars to ${request.budgetMax} dollars.';

    // Sort keys alone weren't reliable here: the Close button's Stack-
    // positioned bounding box (top-right corner) doesn't just sit beside the
    // summary block's box -- since the summary is full-width and unpositioned,
    // its box actually contains Close's, and that containment (not mere
    // adjacency) is what let VoiceOver/TalkBack skip straight past the
    // summary. Giving Close its own non-overlapping strip above the summary
    // removes the ambiguity outright instead of hinting around it.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            children: [
              Positioned(
                right: 6,
                top: 6,
                child: RequestModalInitialClose(
                  label: 'Close completed request details',
                  onClose: onClose,
                  focusNode: _accessibleCloseFocusNode,
                  semanticsKey: _closeSemanticsKey,
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: ExcludeSemantics(
                  child: InkWell(
                    focusNode: _closeFocusNode,
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
            ],
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          label: summaryLabel,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
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
            // Equal flex for every visible segment so each is centered
            // within its own slot and the divider(s) always land at the
            // same relative position, whether NFC is shown or not.
            Expanded(
              child: segment(
                icon: r.isDirectRequest
                    ? Icons.arrow_outward_rounded
                    : Icons.arrow_forward_rounded,
                text: requestType,
                alignment: Alignment.center,
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
                alignment: Alignment.center,
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
                  text: 'JNT Tap',
                  alignment: Alignment.center,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static Widget _sectionTitle(String t) => completedSectionTitle(t);

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
          SizedBox(
            width: 54,
            child: Text(
              k,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: AppColors.blackCat.withValues(alpha: 0.65),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          if (nfcRequested) ...[const SizedBox(width: 3), _nfcDimensionChip()],
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatMm(v),
                textAlign: TextAlign.right,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _nfcDimensionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'JNT Tap',
        style: TextStyle(
          fontSize: 8,
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
    return _isRespectiveShippingMode
        ? _groupShippingLabelSection()
        : _singleShippingLabelSection();
  }

  Widget _shippingActionButton({
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.blackCat,
            foregroundColor: AppColors.snow,
            side: const BorderSide(color: AppColors.blackCat),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
        ),
      ),
    );
  }

  Widget _singleShippingLabelSection() {
    final clientName = _firstNameOnly(widget.request.clientName);
    final cityState = widget.request.clientLocation.trim().isEmpty
        ? 'Not provided'
        : widget.request.clientLocation.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Not the shared completedSectionTitle/_sectionTitle helper here --
        // this heading specifically doubles as the redirect-trap target for
        // _pendingTrackingFieldRefocusKey (see the field declaration for
        // why), which no other section title in this modal needs.
        Semantics(
          header: true,
          label: 'Shipping Label',
          onDidGainAccessibilityFocus: _handleTrackingRefocusTrapFocused,
          child: const ExcludeSemantics(
            child: Text(
              'Shipping Label',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_isShippingLabelReady) ...[
          _kv('Client', clientName),
          _kv('City/State', cityState == 'Not provided' ? '-' : cityState),
        ] else ...[
          Semantics(
            container: true,
            label:
                'Shipping label is being prepared. Download, print, and QR code options will be available when the label is ready.',
            child: ExcludeSemantics(
              child: Text(
                'Shipping label is being prepared by platform. It will appear here with Download, Print, and QR options.',
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _shippingActionButton(
            label: kShippingLiveEnabled
                ? 'Get Shipping Label'
                : 'Get Shipping Label (Simulated)',
            hint:
                'Double tap to generate a shipping label and tracking number for this order',
            icon: Icons.local_shipping_rounded,
            onPressed: _generatingShippingLabel
                ? () {}
                : () => unawaited(_getShippingLabel()),
          ),
        ],
        if (_isShippingLabelReady) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _shippingActionButton(
                label: 'Download Label',
                hint: 'Double tap to open the shipping label for download',
                icon: Icons.download_rounded,
                onPressed: () => _openLabelPreview(_shippingPdfValue),
              ),
              _shippingActionButton(
                label: 'Print Label',
                hint: 'Double tap to open the shipping label for printing',
                icon: Icons.print_rounded,
                onPressed: () => _openLabelPreview(_shippingPdfValue),
              ),
              _shippingActionButton(
                label: 'QR Code',
                hint:
                    'Double tap to show the shipping QR code for scan and print drop-off',
                icon: Icons.qr_code_2_rounded,
                onPressed: _openQrDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Use Download or Print to attach the label, or show the QR code at the carrier counter for scan and print drop-off.',
            child: ExcludeSemantics(
              child: Text(
                'Use Download/Print to attach the label, or show the QR at the carrier counter for scan-and-print drop-off.',
                style: TextStyle(
                  color: AppColors.blackCat.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Group orders shipping to each member individually get one label per
  /// recipient instead of the single Shipping Label block above -- each
  /// recipient has their own address, so their own carrier/tracking/QR.
  Widget _groupShippingLabelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          label: 'Shipping Labels',
          onDidGainAccessibilityFocus: _handleTrackingRefocusTrapFocused,
          child: const ExcludeSemantics(
            child: Text(
              'Shipping Labels',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final recipient in _shipmentRecipients)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _recipientLabelCard(recipient),
          ),
      ],
    );
  }

  Widget _recipientLabelCard(_ShipmentRecipient recipient) {
    final ready = _recipientLabelReady(recipient.key);
    final generating = _generatingShippingLabelFor.contains(recipient.key);

    return Container(
      key: ValueKey('recipientLabelCard-${recipient.key}'),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.blackCat.withValues(alpha: 0.04),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    recipient.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Text(
                  recipient.tag,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              recipient.hasAddress
                  ? recipient.addressLabel
                  : 'No shipping address on file',
              style: TextStyle(
                fontSize: 11,
                fontWeight: recipient.hasAddress
                    ? FontWeight.w400
                    : FontWeight.w700,
                color: recipient.hasAddress
                    ? AppColors.blackCat.withValues(alpha: 0.60)
                    : const Color(0xFFA64B3C),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ready) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _shippingActionButton(
                        label: 'Download Label',
                        hint:
                            'Double tap to open ${recipient.name}\'s shipping label for download',
                        icon: Icons.download_rounded,
                        onPressed: () =>
                            unawaited(_openLabelPreviewForRecipient(recipient)),
                      ),
                      _shippingActionButton(
                        label: 'Print Label',
                        hint:
                            'Double tap to open ${recipient.name}\'s shipping label for printing',
                        icon: Icons.print_rounded,
                        onPressed: () =>
                            unawaited(_openLabelPreviewForRecipient(recipient)),
                      ),
                      _shippingActionButton(
                        label: 'QR Code',
                        hint:
                            'Double tap to show ${recipient.name}\'s shipping QR code for scan and print drop-off',
                        icon: Icons.qr_code_2_rounded,
                        onPressed: () =>
                            unawaited(_openQrDialogForRecipient(recipient)),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Shipping label is being prepared. Download, print, and QR code options will be available when the label is ready.',
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _shippingActionButton(
                    label: kShippingLiveEnabled
                        ? 'Get Shipping Label'
                        : 'Get Shipping Label (Simulated)',
                    hint:
                        'Double tap to generate a shipping label and tracking number for ${recipient.name}',
                    icon: Icons.local_shipping_rounded,
                    onPressed: generating
                        ? () {}
                        : () => unawaited(
                            _getShippingLabelForRecipient(recipient),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementSection() {
    final isGroup = widget.request.orderType == RequestOrderTypeV2.group;
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Group Client Measurements'),
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
                  const SizedBox(width: 8),
                  Container(width: 1, color: AppColors.blackCatBorderLight),
                  const SizedBox(width: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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

  Widget _photosGrid(
    List<String> images, {
    required String ownerLabel,
    FocusNode? firstItemFocusNode,
  }) {
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
            child: Focus(
              focusNode: i == 0 ? firstItemFocusNode : null,
              child: Semantics(
                button: true,
                image: true,
                label:
                    '$ownerLabel uploaded photo ${i + 1} of ${renderable.length}',
                hint: 'Double tap to open full-screen preview',
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _openImagePreview(String path) async {
    final closeFocusNode = FocusNode(debugLabel: 'completedPhotoPreviewClose');
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          if (_accessibleNavigation(dialogContext)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (closeFocusNode.canRequestFocus) {
                closeFocusNode.requestFocus();
              }
            });
          }

          return Dialog(
            backgroundColor: AppColors.blackCat,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Positioned(
                  right: 6,
                  top: 6,
                  child: RequestModalInitialClose(
                    label: 'Close image preview',
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(child: _imageForPath(path)),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: ExcludeSemantics(
                    child: IconButton(
                        focusNode: closeFocusNode,
                        tooltip: 'Close image preview',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.snow,
                          size: 30,
                        ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      closeFocusNode.dispose();
    }
  }

  static Widget _kv(String label, String value) {
    return Semantics(
      container: true,
      label: '$label, $value',
      child: ExcludeSemantics(
        child: Padding(
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
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

  // qr_flutter's auto-version detection (package:qr 3.0.2) can hang the
  // main isolate indefinitely -- not throw -- when handed data too long to
  // fit in a QR code, instead of a normal exception. Stored QR values here
  // come from several legacy/DB sources of uncertain shape, so cap what we
  // ever hand to QrImageView and fall back to the known-short generated
  // payload rather than trust a stale value.
  static const int _maxQrDataLength = 300;

  Future<void> _openQrDialog() async {
    final storedQr = _shippingQrValue;
    final qr = storedQr.isNotEmpty && storedQr.length <= _maxQrDataLength
        ? storedQr
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

  static String _needByLabel(DateTime d) => formatDateMdyShortYear(d);

  static String _lengthLabel(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return 'Short';
    if (v == 'medium') return 'Medium';
    if (v == 'long') return 'Long';
    if (v == 'extra long' || v == 'xlong' || v == 'xl') return 'Extra Long';
    return len.trim();
  }
}
