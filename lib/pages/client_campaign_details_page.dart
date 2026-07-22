import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/profile_table_columns.dart';
import '../models/client_request_v2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';

class ClientCampaignDetailsPage extends StatefulWidget {
  const ClientCampaignDetailsPage({
    super.key,
    required this.request,
    required this.onDecline,
    required this.onAccept,
    this.declineLabel = 'Decline',
    this.acceptLabel = 'Accept',
    this.headerTitleOverride,
  });

  final ClientRequestV2 request;
  final Future<void> Function() onDecline;
  final Future<void> Function() onAccept;
  final String declineLabel;
  final String acceptLabel;
  final String? headerTitleOverride;

  @override
  State<ClientCampaignDetailsPage> createState() =>
      _ClientCampaignDetailsPageState();
}

class _ClientCampaignDetailsPageState extends State<ClientCampaignDetailsPage> {
  late final Future<_RequestDetailsVm> _vmFuture;

  @override
  void initState() {
    super.initState();
    _vmFuture = _RequestDetailsVm.load(widget.request);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.96;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Campaign details',
      child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(color: AppColors.snow),
        child: FutureBuilder<_RequestDetailsVm>(
          future: _vmFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Column(
                children: [
                  _headerBar(context),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.blackCat,
                      ),
                    ),
                  ),
                ],
              );
            }

            if (snap.hasError || !snap.hasData) {
              return Column(
                children: [
                  _headerBar(context),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Unable to load campaign request details.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final vm = snap.data!;
            return Column(
              children: [
                _headerBar(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          vm.statusLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blackCat,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _overviewCard(vm),
                      const SizedBox(height: 16),
                      _sectionContainer(
                        child: _plainSection(
                          title: vm.isBrandRequest ? 'Company Bio' : 'Client Bio',
                          body: vm.bioSectionBody,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionContainer(
                        child: _plainSection(
                          title: 'Custom Request Description',
                          body: vm.customDescription,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionContainer(child: _nailDimensionsSection(vm)),
                      const SizedBox(height: 12),
                      _sectionContainer(
                        child: _numberOfSetsSection(vm.numberOfSets),
                      ),
                      const SizedBox(height: 12),
                      _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(text: 'Inspiration Photos'),
                            const SizedBox(height: 10),
                            _photosStrip(vm.photos),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + safeBottom),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.snow,
                              side: BorderSide(
                                color: AppColors.blackCat.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              backgroundColor: AppColors.blackCat.withValues(
                                alpha: 0.7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: () async {
                              try {
                                await widget.onDecline();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to decline request: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              widget.declineLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.snow,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: () async {
                              try {
                                await widget.onAccept();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to accept request: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              widget.acceptLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.snow,
                                fontFamily: 'Arial',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _headerBar(BuildContext context) {
    return Container(
      color: AppColors.alabaster,
      height: JntModalHeaderMetrics.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: JntModalHeaderMetrics.logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard(_RequestDetailsVm vm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Center(child: _bigAvatar(vm)),
          const SizedBox(height: 10),
          Text(
            vm.brandName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 8),
          _requestTypeOrderRow(vm),
          const SizedBox(height: 8),
          _overviewNeedBudgetAcceptRow(vm),
        ],
      ),
    );
  }

  Widget _nailDimensionsSection(_RequestDetailsVm vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nail Dimensions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _dimensionHandCard(
                  'Left Hand',
                  vm.leftHand,
                  showNfcTags: vm.requiresNfc,
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1, color: AppColors.blackCatBorderLight),
              const SizedBox(width: 10),
              Expanded(
                child: _dimensionHandCard(
                  'Right Hand',
                  vm.rightHand,
                  showNfcTags: vm.requiresNfc,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _summaryValue('Shape', _valueOrDash(vm.nailShape)),
              ),
              const SizedBox(width: 10),
              Container(width: 1, color: AppColors.blackCatBorderLight),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryValue('Length', _valueOrDash(vm.nailLength)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryValue(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      ],
    );
  }

  Widget _dimensionHandCard(
    String title,
    NailDimensionsV2 hand, {
    required bool showNfcTags,
  }) {
    String value(String raw) {
      final trimmed = raw.trim();
      return trimmed.isEmpty || trimmed == '-' ? '-' : '$trimmed mm';
    }

    bool isNfcEligibleDimension(String raw) {
      final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed != null && parsed >= 8;
    }

    Widget row(String label, String raw, {bool showNfc = false}) {
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
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                  if (showNfc) ...[const SizedBox(width: 6), _nfcChip()],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value(raw),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'ArialBold',
                color: AppColors.blackCat,
              ),
            ),
          ],
        ),
      );
    }

    // NFC is only eligible on the thumb -- the tag never appears on any
    // other finger, even if that finger's own measurement is >= 8mm.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        row(
          'Thumb',
          hand.thumb,
          showNfc: showNfcTags && isNfcEligibleDimension(hand.thumb),
        ),
        row('Index', hand.index),
        row('Middle', hand.middle),
        row('Ring', hand.ring),
        row('Pinky', hand.pinky),
      ],
    );
  }

  Widget _nfcChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          color: AppColors.blackCat,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Arial',
        ),
      ),
    );
  }

  Widget _bigAvatar(_RequestDetailsVm vm) {
    final fallback = _initialAvatar(vm.brandName, size: 84);
    var path = vm.profileImage.trim();
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(path);
      if (decoded == path) break;
      path = decoded.trim();
    }
    if (path.isEmpty) return fallback;

    Widget image;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      image = Image.network(
        path,
        fit: BoxFit.cover,
        cacheWidth: 252,
        cacheHeight: 252,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (path.startsWith('gs://')) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 252,
            cacheHeight: 252,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    } else if (path.startsWith('assets/')) {
      image = Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (!kIsWeb && (path.startsWith('/') || path.contains(':\\'))) {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (!path.startsWith('data:') &&
        !path.startsWith('blob:') &&
        !path.startsWith('content://') &&
        (path.contains('/') || path.contains('\\'))) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(path).then((v) => v ?? ''),
        builder: (_, snap) {
          final url = snap.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 252,
            cacheHeight: 252,
            errorBuilder: (_, _, _) => fallback,
          );
        },
      );
    } else {
      image = fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(height: 84, width: 84, child: image),
    );
  }

  Widget _initialAvatar(String text, {double size = 84}) {
    final letter = text.trim().isEmpty ? 'B' : text.trim()[0].toUpperCase();
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }

  Widget _sectionHeader({required String text}) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.blackCat,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _requestTypeOrderRow(_RequestDetailsVm vm) {
    Widget divider() =>
        Container(width: 1, height: 16, color: AppColors.blackCatBorderLight);

    final requestTypeSegment = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          vm.requestType.toLowerCase().contains('direct')
              ? Icons.arrow_outward_rounded
              : Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            vm.requestType,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );

    final orderTypeSegment = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          vm.orderType.toLowerCase().contains('group')
              ? Icons.groups_2_outlined
              : Icons.person_outline_rounded,
          size: 16,
          color: AppColors.blackCat,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            vm.orderType,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );

    final nfcSegment = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.nfc_rounded, size: 16, color: AppColors.blackCat),
        const SizedBox(width: 6),
        const Flexible(
          child: Text(
            'NFC',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: requestTypeSegment),
        const SizedBox(width: 12),
        divider(),
        const SizedBox(width: 12),
        Expanded(child: orderTypeSegment),
        // Dynamic: only shown when this brand request requires NFC.
        if (vm.requiresNfc) ...[
          const SizedBox(width: 12),
          divider(),
          const SizedBox(width: 12),
          Expanded(child: nfcSegment),
        ],
      ],
    );
  }

  Widget _overviewNeedBudgetAcceptRow(_RequestDetailsVm vm) {
    if (vm.isBrandRequest) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _overviewMetaItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Need By',
                  value: vm.needByLabel,
                  center: true,
                  fontSize: 11.5,
                ),
              ),
              if (vm.jntRevealDateLabel.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                _overviewDivider(),
                const SizedBox(width: 12),
                Expanded(
                  child: _overviewMetaItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'JNT Reveal',
                    value: vm.jntRevealDateLabel,
                    center: true,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _overviewMetaItem(
                  icon: Icons.attach_money_rounded,
                  label: 'Budget',
                  value: vm.clientBudgetLabel,
                  center: true,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 12),
              _overviewDivider(),
              const SizedBox(width: 12),
              Expanded(
                child: _overviewMetaItem(
                  icon: Icons.event_available_outlined,
                  label: 'Accept By',
                  value: vm.requestAcceptByLabel,
                  center: true,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _overviewMetaItem(
          icon: Icons.calendar_today_outlined,
          label: 'Need By',
          value: vm.needByLabel,
        ),
        if (vm.isBrandRequest && vm.jntRevealDateLabel.trim().isNotEmpty)
          _overviewMetaItem(
            icon: Icons.auto_awesome_outlined,
            label: 'JNT Reveal',
            value: vm.jntRevealDateLabel,
          ),
        _overviewDivider(),
        _overviewMetaItem(
          icon: Icons.attach_money_rounded,
          label: 'Budget',
          value: vm.clientBudgetLabel,
        ),
        _overviewMetaItem(
          icon: Icons.event_available_outlined,
          label: 'Accept By',
          value: vm.requestAcceptByLabel,
        ),
      ],
    );
  }

  Widget _overviewMetaItem({
    required IconData icon,
    required String label,
    required String value,
    bool center = false,
    double? fontSize,
  }) {
    return Row(
      mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.blackCat),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: $value',
            textAlign: center ? TextAlign.center : TextAlign.start,
            maxLines: center ? 1 : 2,
            overflow: center ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
        ),
      ],
    );
  }

  Widget _overviewDivider() {
    return Container(
      width: 1,
      height: 16,
      color: AppColors.blackCatBorderLight,
    );
  }

  Widget _plainSection({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }

  Widget _numberOfSetsSection(String numberOfSets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of Sets',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          numberOfSets,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Each set includes 10 press on nails (5 per hand)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }

  Widget _sectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: child,
    );
  }

  String _valueOrDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  Widget _photosStrip(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        height: 92,
        alignment: Alignment.centerLeft,
        child: Text(
          'No inspiration photos uploaded.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat.withValues(alpha: 0.68),
          ),
        ),
      );
    }
    Widget buildTile(String raw, {required double size}) {
      return FutureBuilder<String>(
        future: _resolveDisplayPath(raw),
        builder: (context, snap) {
          final resolved = (snap.data ?? '').trim();
          if (resolved.isEmpty) return const SizedBox.shrink();
          final imageProvider = _imageProviderFor(resolved);
          return FutureBuilder<void>(
            future: precacheImage(imageProvider, context),
            builder: (context, imageSnap) {
              if (imageSnap.connectionState != ConnectionState.done) {
                return SizedBox(width: size, height: size);
              }
              if (imageSnap.hasError) return const SizedBox.shrink();
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Semantics(
                  button: true,
                  label: 'View campaign image full screen',
                  child: InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: const EdgeInsets.all(8),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4,
                                child: Center(
                                  child: Image(
                                    image: imageProvider,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                tooltip: 'Close image preview',
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: size,
                    height: size,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.blackCatBorderLight),
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = ((constraints.maxWidth - 24) / 4).clamp(72.0, 110.0);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: tileSize,
          ),
          itemBuilder: (context, index) =>
              buildTile(photos[index], size: tileSize),
        );
      },
    );
  }

  Future<String> _resolveDisplayPath(String raw) async {
    var p = raw.trim();
    for (var j = 0; j < 3; j++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded.trim();
    }
    if (p.isEmpty) return '';
    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('assets/') ||
        p.startsWith('blob:') ||
        p.startsWith('data:') ||
        p.startsWith('content://') ||
        p.startsWith('file://')) {
      return p;
    }
    final looksStoragePath =
        p.startsWith('gs://') ||
        p.startsWith('company_custom_requests/') ||
        p.startsWith('client_custom_requests/') ||
        p.startsWith('clients/') ||
        p.startsWith('artists/') ||
        p.startsWith('client_artists/') ||
        p.startsWith('company/') ||
        (!p.contains('://') && p.contains('/'));
    if (looksStoragePath) {
      final resolved = await StorageUrlResolver.resolve(p);
      if ((resolved ?? '').trim().isNotEmpty) return resolved!.trim();
    }
    final resolved = await StorageUrlResolver.resolve(p);
    if ((resolved ?? '').trim().isNotEmpty) return resolved!.trim();
    return '';
  }

  ImageProvider _imageProviderFor(String path) {
    if (path.startsWith('data:image/')) {
      try {
        final comma = path.indexOf(',');
        if (comma > 0) {
          final bytes = base64Decode(path.substring(comma + 1).trim());
          return MemoryImage(bytes);
        }
      } catch (_) {}
    }
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:') ||
        path.startsWith('data:') ||
        path.startsWith('content://')) {
      return NetworkImage(path);
    }
    if (path.startsWith('assets/')) return AssetImage(path);
    if (path.startsWith('file://')) {
      final localPath = path.replaceFirst('file://', '');
      if (kIsWeb) return NetworkImage(path);
      return FileImage(File(localPath));
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }
}

class _RequestDetailsVm {
  const _RequestDetailsVm({
    required this.isBrandRequest,
    required this.brandName,
    required this.campaignName,
    required this.profileImage,
    required this.statusLabel,
    required this.needByLabel,
    required this.jntRevealDateLabel,
    required this.clientBudgetLabel,
    required this.requestType,
    required this.orderType,
    required this.openToClientPool,
    required this.orderTypeRaw,
    required this.bioSectionBody,
    required this.companyBio,
    required this.customDescription,
    required this.numberOfSets,
    required this.photos,
    required this.leftHand,
    required this.rightHand,
    required this.nailShape,
    required this.nailLength,
    required this.requiresNfc,
    required this.requestAcceptByLabel,
  });

  final bool isBrandRequest;
  final String brandName;
  final String campaignName;
  final String profileImage;
  final String statusLabel;
  final String needByLabel;
  final String jntRevealDateLabel;
  final String clientBudgetLabel;
  final String requestType;
  final String orderType;
  final bool openToClientPool;
  final String orderTypeRaw;
  final String bioSectionBody;
  final String companyBio;
  final String customDescription;
  final String numberOfSets;
  final List<String> photos;
  final NailDimensionsV2 leftHand;
  final NailDimensionsV2 rightHand;
  final String nailShape;
  final String nailLength;
  final bool requiresNfc;
  final String requestAcceptByLabel;

  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String) {
      final text = v.trim();
      if (text.isEmpty) return const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  static String _tableForSource(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized == 'company_custom_requests' ||
        normalized == 'companycustomrequests' ||
        normalized == 'brand_custom_requests' ||
        normalized == 'brandcustomrequests' ||
        normalized == 'company_custom_requests') {
      return 'company_custom_requests';
    }
    return 'client_custom_requests';
  }

  static Map<String, dynamic> _requestFallbackMap(ClientRequestV2 request) {
    return <String, dynamic>{
      'id': request.id,
      'source_collection': request.sourceCollection,
      'order_number': request.id,
      'request_number': request.id,
      'client_request_number': request.id,
      'title': request.title,
      'campaignName': request.title,
      'client_name': request.clientName,
      'clientName': request.clientName,
      'client_email': '',
      'clientEmail': '',
      'description': request.bio,
      'descriptionPreview': request.bio,
      'need_by': request.neededBy.toIso8601String(),
      'needBy': request.neededBy.toIso8601String(),
      'status': request.status.name,
      'order_type': request.orderType == RequestOrderTypeV2.group ? 'group' : 'single',
      'orderType': request.orderType == RequestOrderTypeV2.group ? 'group' : 'single',
      'is_direct_request': request.isDirectRequest,
      'isDirectRequest': request.isDirectRequest,
      'openToClientPool': request.openToClientPool,
      'selected_artist': request.selectedArtist,
      'selectedArtist': request.selectedArtist,
      'selected_artist_email': request.selectedArtistEmail,
      'selectedArtistEmail': request.selectedArtistEmail,
      'clientBudgetMin': request.clientBudgetMin ?? request.budgetMin,
      'clientBudgetMax': request.clientBudgetMax ?? request.budgetMax,
      'inspiration_photos': request.clientImages,
      'inspirationPhotos': request.clientImages,
      'clientImages': request.clientImages,
      'nailPreferences': <String, dynamic>{
        'leftHandDimensions': <String, dynamic>{
          'thumb': request.leftHand.thumb,
          'index': request.leftHand.index,
          'middle': request.leftHand.middle,
          'ring': request.leftHand.ring,
          'pinky': request.leftHand.pinky,
        },
        'rightHandDimensions': <String, dynamic>{
          'thumb': request.rightHand.thumb,
          'index': request.rightHand.index,
          'middle': request.rightHand.middle,
          'ring': request.rightHand.ring,
          'pinky': request.rightHand.pinky,
        },
      },
    };
  }

  static Future<_RequestDetailsVm> load(ClientRequestV2 request) async {
    final supabase = Supabase.instance.client;
    final table = _tableForSource(request.sourceCollection);
    final isBrandRequest = table == 'company_custom_requests';

    Map<String, dynamic> row = const <String, dynamic>{};
    try {
      final response = await supabase
          .from(table)
          .select()
          .eq('id', request.id)
          .maybeSingle();
      row = asMap(response);
    } catch (_) {
      row = const <String, dynamic>{};
    }

    if (row.isEmpty && table != 'client_custom_requests') {
      try {
        final response = await supabase
            .from('client_custom_requests')
            .select()
            .eq('id', request.id)
            .maybeSingle();
        row = asMap(response);
      } catch (_) {}
    }

    final root = row.isNotEmpty ? row : _requestFallbackMap(request);
    final rowSummary = asMap(root['summary']);
    final rowDetails = asMap(root['details']);
    final rowPayload = asMap(root['payload']);
    final rowRequestDetails = asMap(root['request_details']).isNotEmpty
        ? asMap(root['request_details'])
        : asMap(root['requestDetails']);
    final details = <String, dynamic>{
      ...rowSummary,
      ...rowDetails,
      ...rowPayload,
      ...rowRequestDetails,
      'payload': rowPayload.isNotEmpty ? rowPayload : rowSummary,
      'requestDetails': rowRequestDetails.isNotEmpty
          ? rowRequestDetails
          : (rowPayload['requestDetails'] is Map
                ? asMap(rowPayload['requestDetails'])
                : rowSummary),
      'order': asMap(root['order']).isNotEmpty
          ? asMap(root['order'])
          : (asMap(rowPayload['order']).isNotEmpty
                ? asMap(rowPayload['order'])
                : asMap(rowSummary['order'])),
      'clientBudget': asMap(root['client_budget']).isNotEmpty
          ? asMap(root['client_budget'])
          : (asMap(rowPayload['clientBudget']).isNotEmpty
                ? asMap(rowPayload['clientBudget'])
                : asMap(rowSummary['clientBudget'])),
    };

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    List<String> asStringList(Object? value) {
      if (value is List) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String) {
        final text = value.trim();
        if (text.isEmpty) return const <String>[];
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            return decoded
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
          }
        } catch (_) {}
      }
      return const <String>[];
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse((v ?? '').toString().trim()) ?? 0;
    }

    DateTime? asDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v != null) return DateTime.tryParse(v.toString());
      return null;
    }

    bool? asNullableBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final text = v.toString().trim().toLowerCase();
      if (text.isEmpty) return null;
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
      return null;
    }

    final payload = asMap(details['payload']).isNotEmpty
        ? asMap(details['payload'])
        : details;
    final requestDetails = asMap(payload['requestDetails']).isNotEmpty
        ? asMap(payload['requestDetails'])
        : asMap(details['requestDetails']);
    final order = asMap(payload['order']).isNotEmpty
        ? asMap(payload['order'])
        : asMap(details['order']);
    final clientBudget = asMap(payload['clientBudget']).isNotEmpty
        ? asMap(payload['clientBudget'])
        : asMap(details['clientBudget']);
    final rootNailPrefs = asMap(root['nailPreferences']);
    final detailNailPrefs = asMap(details['nailPreferences']);
    final requestDetailNailPrefs = asMap(requestDetails['nailPreferences']);
    final rootDims = asMap(rootNailPrefs['dimensions']).isNotEmpty
        ? asMap(rootNailPrefs['dimensions'])
        : asMap(root['dimensions']);
    final detailDims = asMap(detailNailPrefs['dimensions']).isNotEmpty
        ? asMap(detailNailPrefs['dimensions'])
        : asMap(details['dimensions']);
    final requestDetailDims = asMap(requestDetailNailPrefs['dimensions']);

    Map<String, dynamic> asHand(dynamic value) {
      final map = asMap(value);
      if (map.isEmpty) return map;
      final nested = asMap(map['dimensions']);
      return nested.isNotEmpty ? nested : map;
    }

    String dimensionTextFromMap(Map<String, dynamic> map, String key) {
      final raw = map[key];
      if (raw == null) return '';
      final text = raw.toString().trim();
      if (text.isEmpty || text == '-') return '';
      return text;
    }

    bool hasAnyDimensionValue(Map<String, dynamic> map, {required bool left}) {
      if (map.isEmpty) return false;
      for (final key in const <String>[
        'thumb',
        'index',
        'middle',
        'ring',
        'pinky',
      ]) {
        final cap = key[0].toUpperCase() + key.substring(1);
        final prefixed = left ? 'l$cap' : 'r$cap';
        if (dimensionTextFromMap(map, key).isNotEmpty ||
            dimensionTextFromMap(map, prefixed).isNotEmpty) {
          return true;
        }
      }
      return false;
    }

    Map<String, dynamic> resolveHandSources(
      List<Object?> sources, {
      required bool left,
    }) {
      for (final source in sources) {
        final map = asHand(source);
        if (hasAnyDimensionValue(map, left: left)) return map;
      }
      return const <String, dynamic>{};
    }

    String readHandValue(
      List<Object?> sources, {
      required bool left,
      required String key,
    }) {
      final searchKeys = left
          ? <String>[key, 'l${key[0].toUpperCase()}${key.substring(1)}']
          : <String>[key, 'r${key[0].toUpperCase()}${key.substring(1)}'];
      for (final source in sources) {
        final map = asHand(source);
        if (map.isEmpty) continue;
        for (final searchKey in searchKeys) {
          final text = dimensionTextFromMap(map, searchKey);
          if (text.isNotEmpty) return text;
        }
      }
      return '-';
    }

    Map<String, dynamic> handMap({required bool left}) {
      final requestHand = <String, dynamic>{
        'thumb': left ? request.leftHand.thumb : request.rightHand.thumb,
        'index': left ? request.leftHand.index : request.rightHand.index,
        'middle': left ? request.leftHand.middle : request.rightHand.middle,
        'ring': left ? request.leftHand.ring : request.rightHand.ring,
        'pinky': left ? request.leftHand.pinky : request.rightHand.pinky,
      };
      final sources = <Object?>[
        if (left) requestDetailNailPrefs['leftHandDimensions'],
        if (left) detailNailPrefs['leftHandDimensions'],
        if (left) rootNailPrefs['leftHandDimensions'],
        if (!left) requestDetailNailPrefs['rightHandDimensions'],
        if (!left) detailNailPrefs['rightHandDimensions'],
        if (!left) rootNailPrefs['rightHandDimensions'],
        if (left) requestDetailNailPrefs['dimensions'],
        if (left) detailNailPrefs['dimensions'],
        if (left) rootNailPrefs['dimensions'],
        if (!left) requestDetailNailPrefs['dimensions'],
        if (!left) detailNailPrefs['dimensions'],
        if (!left) rootNailPrefs['dimensions'],
        if (left) requestDetails['leftHandDimensions'],
        if (left) details['leftHandDimensions'],
        if (left) root['leftHandDimensions'],
        if (!left) requestDetails['rightHandDimensions'],
        if (!left) details['rightHandDimensions'],
        if (!left) root['rightHandDimensions'],
      ];
      final handSource = resolveHandSources(sources, left: left);
      if (handSource.isNotEmpty) return handSource;

      final flatSources = <Object?>[
        requestDetailDims,
        detailDims,
        rootDims,
        requestHand,
      ];
      final result = <String, dynamic>{
        'thumb': readHandValue(flatSources, left: left, key: 'thumb'),
        'index': readHandValue(flatSources, left: left, key: 'index'),
        'middle': readHandValue(flatSources, left: left, key: 'middle'),
        'ring': readHandValue(flatSources, left: left, key: 'ring'),
        'pinky': readHandValue(flatSources, left: left, key: 'pinky'),
      };
      return result;
    }

    String dimValue(dynamic value) {
      if (value is num) {
        return value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString();
      }
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? '-' : text;
    }

    NailDimensionsV2 mapHand({required bool left}) {
      final hand = handMap(left: left);

      String prefixedKey(String key) {
        final cap = key[0].toUpperCase() + key.substring(1);
        return left ? 'l$cap' : 'r$cap';
      }

      String pick(String key) {
        final direct = dimValue(hand[key]);
        if (direct != '-') return direct;
        final prefixed = dimValue(hand[prefixedKey(key)]);
        if (prefixed != '-') return prefixed;
        return '-';
      }

      return NailDimensionsV2(
        thumb: pick('thumb'),
        index: pick('index'),
        middle: pick('middle'),
        ring: pick('ring'),
        pinky: pick('pinky'),
      );
    }

    bool handIsEmpty(NailDimensionsV2 hand) {
      return <String>[
        hand.thumb,
        hand.index,
        hand.middle,
        hand.ring,
        hand.pinky,
      ].every((value) {
        final text = value.trim();
        return text.isEmpty || text == '-';
      });
    }

    String first(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = (source[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    Future<Map<String, dynamic>> readClientRecord({
      required String tableName,
      String normalizedEmail = '',
      String normalizedClientId = '',
    }) async {
      List<Map<String, dynamic>> rows = const <Map<String, dynamic>>[];
      final columns = columnsForProfileTable(tableName) ?? '*';

      Future<void> tryEmailLookup() async {
        if (normalizedEmail.isEmpty || rows.isNotEmpty) return;
        final response = await supabase
            .from(tableName)
            .select(columns)
            .ilike('email', normalizedEmail)
            .limit(1);
        rows = response
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }

      Future<void> tryColumnLookup(String column) async {
        if (normalizedClientId.isEmpty || rows.isNotEmpty) return;
        try {
          final response = await supabase
              .from(tableName)
              .select(columns)
              .eq(column, normalizedClientId)
              .limit(1);
          rows = response
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
        } catch (_) {}
      }

      await tryEmailLookup();
      await tryColumnLookup('client_id');
      await tryColumnLookup('clientId');
      await tryColumnLookup('id');

      if (rows.isEmpty) return const <String, dynamic>{};
      final data = asMap(rows.first);
      final profile = asMap(data['profile']);
      final basic = asMap(data['basic']);
      final nail = asMap(data['nail_preferences']).isNotEmpty
          ? asMap(data['nail_preferences'])
          : asMap(data['nailPreferences']);
      final profileNail = asMap(profile['nailPreferences']).isNotEmpty
          ? asMap(profile['nailPreferences'])
          : asMap(profile['nail_preferences']);
      final dimensions = asMap(nail['dimensions']).isNotEmpty
          ? asMap(nail['dimensions'])
          : asMap(profileNail['dimensions']);
      final profileDimensions = asMap(profileNail['dimensions']);

      return <String, dynamic>{
        'name': first(data, const ['displayName', 'name']).isNotEmpty
            ? first(data, const ['displayName', 'name'])
            : (first(profile, const ['name', 'displayName']).isNotEmpty
                  ? first(profile, const ['name', 'displayName'])
                  : first(basic, const ['name', 'displayName'])),
        'bio': first(data, const ['bio', 'about']).isNotEmpty
            ? first(data, const ['bio', 'about'])
            : (first(profile, const ['bio', 'about']).isNotEmpty
                  ? first(profile, const ['bio', 'about'])
                  : first(basic, const ['bio', 'about'])),
        'nailShape': first(nail, const ['shape']).isNotEmpty
            ? first(nail, const ['shape'])
            : first(profileNail, const ['shape']),
        'nailLength': first(nail, const ['length']).isNotEmpty
            ? first(nail, const ['length'])
            : first(profileNail, const ['length']),
        'nailDimensions': <String, dynamic>{
          'lThumb': dimensions['lThumb'] ?? profileDimensions['lThumb'],
          'lIndex': dimensions['lIndex'] ?? profileDimensions['lIndex'],
          'lMiddle': dimensions['lMiddle'] ?? profileDimensions['lMiddle'],
          'lRing': dimensions['lRing'] ?? profileDimensions['lRing'],
          'lPinky': dimensions['lPinky'] ?? profileDimensions['lPinky'],
          'rThumb': dimensions['rThumb'] ?? profileDimensions['rThumb'],
          'rIndex': dimensions['rIndex'] ?? profileDimensions['rIndex'],
          'rMiddle': dimensions['rMiddle'] ?? profileDimensions['rMiddle'],
          'rRing': dimensions['rRing'] ?? profileDimensions['rRing'],
          'rPinky': dimensions['rPinky'] ?? profileDimensions['rPinky'],
        },
      };
    }

    Future<Map<String, dynamic>> loadRequestClientData() async {
      final authUser = Supabase.instance.client.auth.currentUser;
      final authEmail = (authUser?.email ?? '').trim().toLowerCase();
      final authUid = (authUser?.id ?? '').trim();

      // Brand open-pool requests do not have selected/accepted client data yet.
      // In that case, use the signed-in viewer's client/client_artist profile so
      // the detail modal renders the current client's saved nail measurements.
      final normalizedEmail = firstNonEmpty([
        root['selectedClientEmail'],
        details['selectedClientEmail'],
        requestDetails['selectedClientEmail'],
        payload['selectedClientEmail'],
        root['acceptedByClientEmail'],
        details['acceptedByClientEmail'],
        requestDetails['acceptedByClientEmail'],
        payload['acceptedByClientEmail'],
        root['clientEmail'],
        details['clientEmail'],
        requestDetails['clientEmail'],
        payload['clientEmail'],
        authEmail,
      ]).trim().toLowerCase();

      final normalizedClientId = firstNonEmpty([
        root['selectedClientId'],
        details['selectedClientId'],
        requestDetails['selectedClientId'],
        payload['selectedClientId'],
        root['acceptedClientId'],
        details['acceptedClientId'],
        requestDetails['acceptedClientId'],
        payload['acceptedClientId'],
        root['clientId'],
        root['client_id'],
        details['clientId'],
        details['client_id'],
        requestDetails['clientId'],
        requestDetails['client_id'],
        payload['clientId'],
        payload['client_id'],
        authUid,
      ]).trim();

      for (final tableName in const <String>['client', 'client_artist']) {
        try {
          final result = await readClientRecord(
            tableName: tableName,
            normalizedEmail: normalizedEmail,
            normalizedClientId: normalizedClientId,
          );
          if (result.isNotEmpty) return result;
        } catch (_) {}
      }
      return const <String, dynamic>{};
    }

    List<String> collectPhotos(List<Object?> sources) {
      final out = <String>{};
      void add(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final v = value.trim();
          if (v.isNotEmpty) out.add(v);
          return;
        }
        if (value is List) {
          for (final item in value) {
            add(item);
          }
          return;
        }
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final candidate = firstNonEmpty([
            map['imageUrl'],
            map['downloadUrl'],
            map['downloadURL'],
            map['url'],
            map['photoUrl'],
            map['image'],
            map['photo'],
            map['path'],
            map['storagePath'],
            map['fullPath'],
            map['ref'],
            map['src'],
            map['uri'],
          ]);
          if (candidate.isNotEmpty) out.add(candidate);
          map.forEach((k, v) {
            final key = k.toString().toLowerCase();
            if (key.contains('photo') ||
                key.contains('image') ||
                key.contains('inspiration') ||
                key.contains('preview') ||
                key.endsWith('url') ||
                key.endsWith('path')) {
              add(v);
            }
          });
        }
      }

      for (final source in sources) {
        add(source);
      }
      return out.toList(growable: false);
    }

    final detailPhotos = collectPhotos([
      payload['inspirationPhotos'],
      payload['brandInspirationPhotos'],
      payload['inspirationPhotoUrls'],
      payload['inspirationPhotoRefs'],
      payload['photos'],
      payload['clientImages'],
      payload['inspirationPhoto'],
      payload['inspirationPhotoUrl'],
      payload['previewImage'],
      payload['previewImageAsset'],
      details['inspirationPhotos'],
      details['brandInspirationPhotos'],
      details['inspirationPhotoUrls'],
      details['inspirationPhotoRefs'],
      details['photos'],
      details['clientImages'],
      details['inspirationPhoto'],
      details['inspirationPhotoUrl'],
      details['previewImage'],
      details['previewImageAsset'],
      details['requestDetails.inspirationPhotos'],
      details['requestDetails.brandInspirationPhotos'],
      details['requestDetails.inspirationPhotoUrls'],
      details['requestDetails.inspirationPhotoRefs'],
      details['requestDetails.photos'],
      details['requestDetails.clientImages'],
      details['requestDetails.previewImage'],
      details['requestDetails.previewImageAsset'],
    ]);
    final requestDetailPhotos = collectPhotos([
      requestDetails['inspirationPhotos'],
      requestDetails['brandInspirationPhotos'],
      requestDetails['inspirationPhotoUrls'],
      requestDetails['inspirationPhotoRefs'],
      requestDetails['photos'],
      requestDetails['clientImages'],
      requestDetails['inspirationPhoto'],
      requestDetails['inspirationPhotoUrl'],
      requestDetails['previewImage'],
      requestDetails['previewImageAsset'],
    ]);
    final rootPhotos = collectPhotos([
      root['inspirationPhotos'],
      root['brandInspirationPhotos'],
      root['inspirationPhotoUrls'],
      root['inspirationPhotoRefs'],
      root['photos'],
      root['clientImages'],
      root['inspirationPhoto'],
      root['inspirationPhotoUrl'],
      root['previewImage'],
      root['previewImageAsset'],
      root['requestDetails.inspirationPhotos'],
      root['requestDetails.brandInspirationPhotos'],
      root['requestDetails.inspirationPhotoUrls'],
      root['requestDetails.inspirationPhotoRefs'],
      root['requestDetails.photos'],
      root['requestDetails.clientImages'],
      root['requestDetails.previewImage'],
      root['requestDetails.previewImageAsset'],
    ]);
    var photos = detailPhotos.isNotEmpty
        ? detailPhotos
        : (requestDetailPhotos.isNotEmpty
              ? requestDetailPhotos
              : (rootPhotos.isNotEmpty
                    ? rootPhotos
                    : request.clientImages
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(growable: false)));

    final brandName = firstNonEmpty([
      root['companyName'],
      root['brandName'],
      root['clientName'],
      request.clientName,
    ], fallback: 'Brand Company');
    final campaignName = firstNonEmpty([
      root['campaignName'],
      root['title'],
      request.title,
    ], fallback: 'Untitled Campaign');
    final detailClientProfile = asMap(details['clientProfileSnapshot']);
    final detailClientBasic = asMap(detailClientProfile['basic']);
    final companyProfileForImage =
        asMap(details['companyProfileSnapshot']).isNotEmpty
        ? asMap(details['companyProfileSnapshot'])
        : asMap(root['companyProfileSnapshot']);
    final profileImage = firstNonEmpty([
      root['companyProfileImage'],
      root['brandProfileImage'],
      root['companyLogoUrl'],
      root['logoUrl'],
      companyProfileForImage['profileImageUrl'],
      companyProfileForImage['avatarUrl'],
      companyProfileForImage['logoUrl'],
      detailClientBasic['profileImageUrl'],
      detailClientBasic['avatarUrl'],
      root['clientProfileImage'],
      root['clientProfilePic'],
      request.clientProfileImage,
    ]);
    final needBy =
        asDate(requestDetails['needBy']) ??
        asDate(root['needBy']) ??
        request.neededBy;
    final cMin = asInt(clientBudget['min']) > 0
        ? asInt(clientBudget['min'])
        : (asInt(root['clientBudgetMin']) > 0
              ? asInt(root['clientBudgetMin'])
              : (request.clientBudgetMin ?? request.budgetMin));
    final cMax = asInt(clientBudget['max']) > 0
        ? asInt(clientBudget['max'])
        : (asInt(root['clientBudgetMax']) > 0
              ? asInt(root['clientBudgetMax'])
              : (request.clientBudgetMax ?? request.budgetMax));
    final orderTypeRaw = firstNonEmpty([
      order['type'],
      root['orderType'],
      details['orderType'],
    ], fallback: 'single').toLowerCase();
    final orderType = orderTypeRaw == 'group' ? 'Group' : 'Single';
    final selectedArtist = firstNonEmpty([
      root['selectedArtist'],
      root['selected_artist'],
      order['selectedArtist'],
      order['selected_artist'],
      details['selectedArtist'],
      details['selected_artist'],
      requestDetails['selectedArtist'],
      requestDetails['selected_artist'],
      payload['selectedArtist'],
      payload['selected_artist'],
      request.selectedArtist,
    ]);
    final selectedArtistEmail = firstNonEmpty([
      root['selectedArtistEmail'],
      root['selected_artist_email'],
      order['selectedArtistEmail'],
      order['selected_artist_email'],
      details['selectedArtistEmail'],
      details['selected_artist_email'],
      requestDetails['selectedArtistEmail'],
      requestDetails['selected_artist_email'],
      payload['selectedArtistEmail'],
      payload['selected_artist_email'],
      request.selectedArtistEmail,
    ]).toLowerCase();
    final hasSpecificArtist =
        selectedArtist.isNotEmpty || selectedArtistEmail.isNotEmpty;
    final selectedClient = firstNonEmpty([
      root['selectedClient'],
      root['selected_client'],
      order['selectedClient'],
      order['selected_client'],
      details['selectedClient'],
      details['selected_client'],
      requestDetails['selectedClient'],
      requestDetails['selected_client'],
      payload['selectedClient'],
      payload['selected_client'],
      request.selectedClient,
    ]);
    final selectedClientEmail = firstNonEmpty([
      root['selectedClientEmail'],
      root['selected_client_email'],
      order['selectedClientEmail'],
      order['selected_client_email'],
      details['selectedClientEmail'],
      details['selected_client_email'],
      requestDetails['selectedClientEmail'],
      requestDetails['selected_client_email'],
      payload['selectedClientEmail'],
      payload['selected_client_email'],
      request.selectedClientEmail,
    ]).toLowerCase();
    final selectedClientId = firstNonEmpty([
      root['selectedClientId'],
      root['selected_client_id'],
      order['selectedClientId'],
      order['selected_client_id'],
      details['selectedClientId'],
      details['selected_client_id'],
      requestDetails['selectedClientId'],
      requestDetails['selected_client_id'],
      payload['selectedClientId'],
      payload['selected_client_id'],
    ]);
    final selectedGroupClientEmails = <String>{
      ...asStringList(root['selectedGroupClientEmails']),
      ...asStringList(root['selected_group_client_emails']),
      ...asStringList(order['selectedGroupClientEmails']),
      ...asStringList(order['selected_group_client_emails']),
      ...asStringList(details['selectedGroupClientEmails']),
      ...asStringList(details['selected_group_client_emails']),
      ...asStringList(requestDetails['selectedGroupClientEmails']),
      ...asStringList(requestDetails['selected_group_client_emails']),
      ...asStringList(payload['selectedGroupClientEmails']),
      ...asStringList(payload['selected_group_client_emails']),
      ...request.selectedGroupClientEmails
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty),
    };
    final hasSpecificClientTargets =
        selectedClient.isNotEmpty ||
        selectedClientEmail.isNotEmpty ||
        selectedClientId.isNotEmpty ||
        selectedGroupClientEmails.isNotEmpty;
    final openToClientPool =
        asNullableBool(root['openToClientPool']) ??
        asNullableBool(order['openToClientPool']) ??
        asNullableBool(details['openToClientPool']) ??
        !hasSpecificClientTargets;
    final openToArtistPool =
        asNullableBool(root['openToArtistPool']) ??
        asNullableBool(order['openToArtistPool']) ??
        asNullableBool(details['openToArtistPool']) ??
        !hasSpecificArtist;
    final computedRequestType = _requestTypeFromRouting(
      isBrandRequest: isBrandRequest,
      hasSpecificArtist: hasSpecificArtist,
      openToClientPool: openToClientPool,
      openToArtistPool: openToArtistPool,
    );
    final requestType = computedRequestType;
    final customDescription = firstNonEmpty([
      requestDetails['description'],
      root['descriptionPreview'],
      root['description'],
      request.bio,
    ], fallback: '-');
    final requestAcceptBy =
        asDate(root['requestAcceptBy']) ??
        asDate(requestDetails['requestAcceptBy']) ??
        asDate(details['requestAcceptBy']) ??
        (DateTime(
                needBy.year,
                needBy.month,
                needBy.day,
              ).subtract(const Duration(days: 5)));
    final jntRevealDate = firstNonEmpty([
      _dateLabelOrBlank(root['jntRevealDateDisplay']),
      _dateLabelOrBlank(root['jnt_reveal_date_display']),
      _dateLabelOrBlank(requestDetails['jntRevealDateDisplay']),
      _dateLabelOrBlank(requestDetails['jnt_reveal_date_display']),
      _dateLabelOrBlank(details['jntRevealDateDisplay']),
      _dateLabelOrBlank(details['jnt_reveal_date_display']),
      _dateLabelOrBlank(payload['jntRevealDateDisplay']),
      _dateLabelOrBlank(payload['jnt_reveal_date_display']),
      _dateLabelOrBlank(root['jntRevealDate']),
      _dateLabelOrBlank(root['jnt_reveal_date']),
      _dateLabelOrBlank(requestDetails['jntRevealDate']),
      _dateLabelOrBlank(requestDetails['jnt_reveal_date']),
      _dateLabelOrBlank(details['jntRevealDate']),
      _dateLabelOrBlank(details['jnt_reveal_date']),
      _dateLabelOrBlank(payload['jntRevealDate']),
      _dateLabelOrBlank(payload['jnt_reveal_date']),
      _dateLabelOrBlank(root['revealDate']),
      _dateLabelOrBlank(requestDetails['revealDate']),
      _dateLabelOrBlank(details['revealDate']),
      _dateLabelOrBlank(payload['revealDate']),
    ]);
    final numberOfSets = asInt(requestDetails['numberOfSets']) > 0
        ? asInt(requestDetails['numberOfSets']).toString()
        : (asInt(requestDetails['quantity']) > 0
              ? asInt(requestDetails['quantity']).toString()
              : (asInt(root['numberOfSets']) > 0
                    ? asInt(root['numberOfSets']).toString()
                    : (asInt(root['quantity']) > 0
                          ? asInt(root['quantity']).toString()
                          : '1')));

    String cleanCompanyBio(String raw) {
      String normalize(String value) =>
          value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
      final value = raw.trim();
      if (value.isEmpty) return '';

      // Brand request submit can store the custom request description inside
      // companyProfileSnapshot.bio. Do not show that as the brand/company bio.
      final description = customDescription.trim();
      if (description.isNotEmpty &&
          normalize(value) == normalize(description)) {
        return '';
      }
      return value;
    }

    String extractCompanyBio(
      Map<String, dynamic> source, {
      bool allowSnapshotDescriptionFallback = false,
    }) {
      if (source.isEmpty) return '';
      final nestedCompany = asMap(source['company']);
      final nestedProfile = asMap(source['profile']);
      final nestedBasic = asMap(source['basic']);
      final candidates = <Object?>[
        source['panel_companyBio'],
        source['panel_company_bio'],
        source['panel_company_bio_text'],
        source['companyBio'],
        source['company_bio'],
        source['about'],
        source['aboutBrand'],
        nestedCompany['bio'],
        nestedCompany['companyBio'],
        nestedCompany['company_bio'],
        nestedCompany['about'],
        nestedProfile['companyBio'],
        nestedProfile['company_bio'],
        nestedBasic['companyBio'],
        nestedBasic['company_bio'],
        // Keep generic bio last so the real company bio wins when available.
        source['bio'],
        nestedProfile['bio'],
        nestedBasic['bio'],
      ];

      for (final candidate in candidates) {
        final value = (candidate ?? '').toString().trim();
        if (value.isEmpty) continue;
        if (allowSnapshotDescriptionFallback) return value;
        final cleaned = cleanCompanyBio(value);
        if (cleaned.isNotEmpty) return cleaned;
      }
      return '';
    }

    String companyBio = '';
    final companySnapshot = asMap(details['companyProfileSnapshot']).isNotEmpty
        ? asMap(details['companyProfileSnapshot'])
        : asMap(root['companyProfileSnapshot']);
    final companySnapshotBasic = asMap(companySnapshot['basic']);
    final detailClientBasicForCompany = detailClientBasic;
    final rootClientProfile = asMap(root['clientProfileSnapshot']);
    final rootClientBasicForCompany = asMap(rootClientProfile['basic']);

    String extractUuidFromText(Object? raw) {
      final text = (raw ?? '').toString();
      if (text.trim().isEmpty) return '';
      final matches = RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
      ).allMatches(text).map((m) => m.group(0) ?? '').where((v) => v.isNotEmpty).toList();
      if (matches.isEmpty) return '';
      return matches.first.toLowerCase();
    }

    final companyUid = firstNonEmpty([
      root['companyUid'],
      root['company_uid'],
      details['companyUid'],
      details['company_uid'],
      requestDetails['companyUid'],
      requestDetails['company_uid'],
      payload['companyUid'],
      payload['company_uid'],
      root['brandId'],
      root['brand_id'],
      details['brandId'],
      details['brand_id'],
      requestDetails['brandId'],
      requestDetails['brand_id'],
      payload['brandId'],
      payload['brand_id'],
      extractUuidFromText(profileImage),
      extractUuidFromText(root['previewImage']),
      extractUuidFromText(root['previewImageAsset']),
      extractUuidFromText(details['previewImage']),
      extractUuidFromText(details['previewImageAsset']),
      if (photos.isNotEmpty) extractUuidFromText(photos.first),
    ]);
    final companyEmail = firstNonEmpty([
      root['companyEmail'],
      root['company_email'],
      details['companyEmail'],
      details['company_email'],
      requestDetails['companyEmail'],
      requestDetails['company_email'],
      payload['companyEmail'],
      payload['company_email'],
      root['brandEmail'],
      root['brand_email'],
      details['brandEmail'],
      details['brand_email'],
      requestDetails['brandEmail'],
      requestDetails['brand_email'],
      payload['brandEmail'],
      payload['brand_email'],
      companySnapshot['email'],
      companySnapshot['companyEmail'],
      companySnapshot['company_email'],
      companySnapshot['brandEmail'],
      companySnapshot['brand_email'],
      companySnapshotBasic['email'],
      if (!isBrandRequest) detailClientBasicForCompany['email'],
      if (!isBrandRequest) rootClientBasicForCompany['email'],
      if (!isBrandRequest) root['clientEmail'],
      if (!isBrandRequest) root['client_email'],
    ]).toLowerCase();
    final companyNameLookup = firstNonEmpty([
      root['companyName'],
      root['company_name'],
      details['companyName'],
      details['company_name'],
      requestDetails['companyName'],
      requestDetails['company_name'],
      payload['companyName'],
      payload['company_name'],
      root['brandName'],
      root['brand_name'],
      details['brandName'],
      details['brand_name'],
      requestDetails['brandName'],
      requestDetails['brand_name'],
      payload['brandName'],
      payload['brand_name'],
      companySnapshot['name'],
      companySnapshot['displayName'],
      companySnapshot['companyName'],
      companySnapshot['company_name'],
      companySnapshot['brandName'],
      companySnapshot['brand_name'],
      companySnapshotBasic['name'],
      companySnapshotBasic['displayName'],
      if (!isBrandRequest) detailClientBasicForCompany['name'],
      if (!isBrandRequest) rootClientBasicForCompany['name'],
      if (!isBrandRequest) request.clientName,
    ]);

    Future<Map<String, dynamic>> readCompanyRow({
      String uid = '',
      String email = '',
      String companyName = '',
    }) async {
      Future<Map<String, dynamic>> byColumn(
        String column,
        String value, {
        bool exact = true,
      }) async {
        if (value.trim().isEmpty) return const <String, dynamic>{};
        try {
          final rows = exact
              ? await supabase.from('company').select().eq(column, value.trim()).limit(1)
              : await supabase.from('company').select().ilike(column, value.trim()).limit(1);
          if (rows.isNotEmpty) return asMap(rows.first);
        } catch (_) {}
        return const <String, dynamic>{};
      }

      for (final column in const <String>[
        'id',
        'uid',
        'company_id',
        'companyId',
        'brand_id',
        'brandId',
      ]) {
        final row = await byColumn(column, uid);
        if (row.isNotEmpty) return row;
      }

      for (final column in const <String>[
        'email',
        'company_email',
        'contact_email',
        'panel_company_email',
        'panel_companyEmail',
        'panel_contact_email',
        'panel_contactEmail',
        'companyEmail',
        'contactEmail',
      ]) {
        final row = await byColumn(column, email.toLowerCase());
        if (row.isNotEmpty) return row;
      }

      for (final column in const <String>[
        'panel_company_name',
        'panel_companyName',
        'company_name',
        'companyName',
        'name',
        'brand_name',
        'brandName',
        'panel_name',
        'panelName',
      ]) {
        final row = await byColumn(column, companyName, exact: false);
        if (row.isNotEmpty) return row;
      }

      // Last-resort lookup for legacy rows where brand name/email only exists
      // inside the jsonb `company`/`basic`/`profile` objects and not as a
      // top-level column. Pushed into SQL via ->> operators instead of
      // pulling up to 1000 rows into Dart for a client-side string match.
      try {
        final emailNeedle = email.trim().toLowerCase();
        final nameNeedle = companyName.trim().toLowerCase();
        final filterParts = <String>[
          if (emailNeedle.isNotEmpty) 'company->>contactEmail.ilike."$emailNeedle"',
          if (emailNeedle.isNotEmpty) 'company->>email.ilike."$emailNeedle"',
          if (emailNeedle.isNotEmpty) 'basic->>email.ilike."$emailNeedle"',
          if (emailNeedle.isNotEmpty) 'profile->>email.ilike."$emailNeedle"',
          if (nameNeedle.isNotEmpty) 'company->>name.ilike."$nameNeedle"',
          if (nameNeedle.isNotEmpty) 'basic->>name.ilike."$nameNeedle"',
          if (nameNeedle.isNotEmpty) 'profile->>name.ilike."$nameNeedle"',
        ];
        if (filterParts.isNotEmpty) {
          final rows = await supabase.from('company').select().or(filterParts.join(',')).limit(1);
          if (rows.isNotEmpty) return asMap(rows.first);
        }
      } catch (_) {}

      return const <String, dynamic>{};
    }

    final companyRow = await readCompanyRow(
      uid: companyUid,
      email: companyEmail,
      companyName: companyNameLookup,
    );
    final requestClientData = await loadRequestClientData();
    final requestClientDims = asMap(requestClientData['nailDimensions']);
    final clientBio = cleanCompanyBio(firstNonEmpty([
      requestClientData['bio'],
      detailClientBasicForCompany['bio'],
      rootClientBasicForCompany['bio'],
      root['clientBio'],
      root['client_bio'],
      details['clientBio'],
      details['client_bio'],
    ]));
    companyBio = extractCompanyBio(
      companyRow,
      allowSnapshotDescriptionFallback: false,
    );
    if (companyBio.isEmpty) {
      companyBio = extractCompanyBio(
        companySnapshot,
        allowSnapshotDescriptionFallback: false,
      );
    }
    if (companyBio.isEmpty) {
      companyBio = cleanCompanyBio(firstNonEmpty([
        root['panel_companyBio'],
        root['panel_company_bio'],
        root['companyBio'],
        root['company_bio'],
      ]));
    }
    if (!isBrandRequest && clientBio.isNotEmpty) {
      companyBio = clientBio;
    }
    if (companyBio.isEmpty) {
      companyBio = isBrandRequest
          ? 'No company bio available.'
          : 'No client bio available.';
    }
    final bioSectionBody = companyBio;

    NailDimensionsV2 profileHand({required bool left}) {
      String pick(String key) {
        final cap = key[0].toUpperCase() + key.substring(1);
        return dimValue(
          requestClientDims[left ? 'l$cap' : 'r$cap'] ?? requestClientDims[key],
        );
      }

      return NailDimensionsV2(
        thumb: pick('thumb'),
        index: pick('index'),
        middle: pick('middle'),
        ring: pick('ring'),
        pinky: pick('pinky'),
      );
    }

    var leftHand = isBrandRequest && requestClientDims.isNotEmpty
        ? profileHand(left: true)
        : mapHand(left: true);
    var rightHand = isBrandRequest && requestClientDims.isNotEmpty
        ? profileHand(left: false)
        : mapHand(left: false);
    final nailShape = isBrandRequest
        ? firstNonEmpty([
            requestClientData['nailShape'],
            requestClientData['shape'],
            asMap(root['nailPreferences'])['shape'],
            asMap(details['nailPreferences'])['shape'],
            requestDetails['nailShape'],
            root['nailShape'],
            root['nail_shape'],
            request.nailShape,
          ], fallback: '-')
        : firstNonEmpty([
            asMap(requestDetails['nailPreferences'])['shape'],
            requestDetails['nailShape'],
            requestDetails['nail_shape'],
            asMap(details['nailPreferences'])['shape'],
            asMap(root['nailPreferences'])['shape'],
            root['nailShape'],
            root['nail_shape'],
            request.nailShape,
            requestClientData['nailShape'],
            requestClientData['shape'],
          ], fallback: '-');
    final nailLength = isBrandRequest
        ? firstNonEmpty([
            requestClientData['nailLength'],
            requestClientData['length'],
            asMap(root['nailPreferences'])['length'],
            asMap(details['nailPreferences'])['length'],
            requestDetails['nailLength'],
            root['nailLength'],
            root['nail_length'],
            request.nailLength,
          ], fallback: '-')
        : firstNonEmpty([
            asMap(requestDetails['nailPreferences'])['length'],
            requestDetails['nailLength'],
            requestDetails['nail_length'],
            asMap(details['nailPreferences'])['length'],
            asMap(root['nailPreferences'])['length'],
            root['nailLength'],
            root['nail_length'],
            request.nailLength,
            requestClientData['nailLength'],
            requestClientData['length'],
          ], fallback: '-');
    if (!isBrandRequest && handIsEmpty(leftHand) && handIsEmpty(rightHand)) {
      final fallbackDims = requestClientDims.isNotEmpty
          ? requestClientDims
          : const <String, dynamic>{};
      if (fallbackDims.isNotEmpty) {
        String pickCurrent({required bool left, required String key}) {
          final cap = key[0].toUpperCase() + key.substring(1);
          final prefixed = left ? 'l$cap' : 'r$cap';
          return dimValue(
            fallbackDims[prefixed] ?? fallbackDims[key],
          );
        }

        leftHand = NailDimensionsV2(
          thumb: pickCurrent(left: true, key: 'thumb'),
          index: pickCurrent(left: true, key: 'index'),
          middle: pickCurrent(left: true, key: 'middle'),
          ring: pickCurrent(left: true, key: 'ring'),
          pinky: pickCurrent(left: true, key: 'pinky'),
        );
        rightHand = NailDimensionsV2(
          thumb: pickCurrent(left: false, key: 'thumb'),
          index: pickCurrent(left: false, key: 'index'),
          middle: pickCurrent(left: false, key: 'middle'),
          ring: pickCurrent(left: false, key: 'ring'),
          pinky: pickCurrent(left: false, key: 'pinky'),
        );
      }
    }

    return _RequestDetailsVm(
      isBrandRequest: isBrandRequest,
      brandName: brandName,
      campaignName: campaignName,
      profileImage: profileImage,
      statusLabel: _statusLabel(request.status),
      needByLabel: _dateLabel(needBy),
      jntRevealDateLabel: jntRevealDate,
      clientBudgetLabel:
          '\$${cMin <= 0 ? 15 : cMin} - \$${cMax <= 0 ? 5000 : cMax}',
      requestType: requestType,
      orderType: orderType,
      openToClientPool: openToClientPool,
      orderTypeRaw: orderTypeRaw,
      bioSectionBody: bioSectionBody,
      companyBio: companyBio,
      customDescription: customDescription,
      numberOfSets: numberOfSets,
      photos: photos,
      leftHand: leftHand,
      rightHand: rightHand,
      nailShape: nailShape,
      nailLength: nailLength,
      requiresNfc: _requestRequiresNfcFromMaps(root, details, payload),
      requestAcceptByLabel: _dateLabel(requestAcceptBy),
    );
  }

  static bool _requestRequiresNfcFromMaps(
    Map<String, dynamic> root,
    Map<String, dynamic> details,
    Map<String, dynamic> payload,
  ) {
    bool truthy(Object? value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes' || text == 'y';
    }

    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return const <String, dynamic>{};
    }

    final requestDetails = asMap(payload['requestDetails']).isNotEmpty
        ? asMap(payload['requestDetails'])
        : asMap(details['requestDetails']);
    final order = asMap(payload['order']).isNotEmpty
        ? asMap(payload['order'])
        : asMap(details['order']);
    final nfc = asMap(payload['nfc']).isNotEmpty
        ? asMap(payload['nfc'])
        : (asMap(details['nfc']).isNotEmpty
              ? asMap(details['nfc'])
              : asMap(root['nfc']));

    // brand_custom_request_page.dart writes this flag as 'nfcRequested' /
    // 'requiresNfcEligibleClient' -- those exact keys (camelCase and
    // snake_case) were missing below, so this always evaluated to false for
    // real brand requests.
    final candidates = <Object?>[
      root['requiresNfc'],
      root['requiresNFC'],
      root['nfcRequired'],
      root['isNfcRequired'],
      root['hasNfc'],
      root['hasNFC'],
      root['nfcEnabled'],
      root['nfcRequested'],
      root['nfc_requested'],
      root['requiresNfcEligibleClient'],
      root['requires_nfc_eligible_client'],
      details['requiresNfc'],
      details['requiresNFC'],
      details['nfcRequired'],
      details['isNfcRequired'],
      details['hasNfc'],
      details['hasNFC'],
      details['nfcRequested'],
      details['nfc_requested'],
      details['requiresNfcEligibleClient'],
      details['requires_nfc_eligible_client'],
      payload['requiresNfc'],
      payload['requiresNFC'],
      payload['nfcRequired'],
      payload['isNfcRequired'],
      payload['hasNfc'],
      payload['hasNFC'],
      payload['nfcRequested'],
      payload['nfc_requested'],
      payload['requiresNfcEligibleClient'],
      payload['requires_nfc_eligible_client'],
      requestDetails['requiresNfc'],
      requestDetails['requiresNFC'],
      requestDetails['nfcRequired'],
      requestDetails['isNfcRequired'],
      requestDetails['hasNfc'],
      requestDetails['hasNFC'],
      requestDetails['nfcRequested'],
      requestDetails['nfc_requested'],
      requestDetails['requiresNfcEligibleClient'],
      requestDetails['requires_nfc_eligible_client'],
      order['requiresNfc'],
      order['requiresNFC'],
      order['nfcRequired'],
      order['isNfcRequired'],
      order['hasNfc'],
      order['hasNFC'],
      order['nfcRequested'],
      order['nfc_requested'],
      order['requiresNfcEligibleClient'],
      order['requires_nfc_eligible_client'],
      nfc['required'],
      nfc['enabled'],
      nfc['requiresNfc'],
      nfc['hasNfc'],
    ];
    return candidates.any(truthy);
  }

  static String _dateLabel(DateTime? d) {
    if (d == null) return '-';
    const months = <String>[
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _dateLabelOrBlank(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return _dateLabel(value);
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _dateLabel(parsed);
    return text;
  }

  static String _statusLabel(RequestStatusV2 status) {
    switch (status) {
      case RequestStatusV2.inReview:
        return 'Pending';
      default:
        return status.label;
    }
  }

  static String _requestTypeFromRouting({
    required bool isBrandRequest,
    required bool hasSpecificArtist,
    required bool openToClientPool,
    required bool openToArtistPool,
  }) {
    if (!isBrandRequest) {
      return hasSpecificArtist || !openToArtistPool ? 'Direct' : 'Standard';
    }
    if (openToClientPool) {
      return hasSpecificArtist || !openToArtistPool
          ? 'Direct to Artist'
          : 'Standard';
    }
    return hasSpecificArtist || !openToArtistPool ? 'Direct' : 'Direct to Client';
  }
}


class StorageUrlResolver {
  static final Map<String, Future<String?>> _cache = <String, Future<String?>>{};

  static Future<String?> resolve(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return Future<String?>.value(null);
    return _cache.putIfAbsent(value, () => _resolveUncached(value));
  }

  static Future<String?> _resolveUncached(String raw) async {
    var p = raw.trim();
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded.trim();
    }
    if (p.isEmpty) return null;
    if (p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('data:') ||
        p.startsWith('blob:') ||
        p.startsWith('content://') ||
        p.startsWith('file://') ||
        p.startsWith('assets/')) {
      return p;
    }

    String? bucket;
    String objectPath = p;

    if (p.startsWith('gs://')) {
      final withoutScheme = p.substring(5);
      final slash = withoutScheme.indexOf('/');
      if (slash >= 0) {
        bucket = withoutScheme.substring(0, slash);
        objectPath = withoutScheme.substring(slash + 1);
      }
    } else {
      final parts = p.split('/').where((e) => e.trim().isNotEmpty).toList();
      if (parts.length > 1 && _knownBuckets.contains(parts.first)) {
        bucket = parts.first;
        objectPath = parts.skip(1).join('/');
      }
    }

    final supabase = Supabase.instance.client;
    final buckets = <String>[
      if (bucket != null && bucket.isNotEmpty) bucket,
      'request-inspiration-photos',
      'client-request-photos',
      'client-custom-requests',
      'client_custom_requests',
      'company-custom-requests',
      'company_custom_requests',
      'jnt-uploads',
      'uploads',
      'public',
    ];

    for (final b in buckets.toSet()) {
      try {
        final publicUrl = supabase.storage.from(b).getPublicUrl(objectPath);
        if (publicUrl.trim().isNotEmpty) return publicUrl.trim();
      } catch (_) {}
    }
    return null;
  }

  static const Set<String> _knownBuckets = <String>{
    'request-inspiration-photos',
    'client-request-photos',
    'client-custom-requests',
    'client_custom_requests',
    'company-custom-requests',
    'company_custom_requests',
    'jnt-uploads',
    'uploads',
    'public',
  };
}
