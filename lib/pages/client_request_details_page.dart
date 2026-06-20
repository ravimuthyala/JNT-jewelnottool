import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../services/supabase_firebase_compat.dart';
import '../theme/app_colors.dart';

class ClientRequestDetailsPage extends StatefulWidget {
  const ClientRequestDetailsPage({
    super.key,
    required this.request,
    required this.onDecline,
    required this.onAccept,
    this.declineLabel = 'Decline',
    this.acceptLabel = 'Accept',
  });

  final ClientRequestV2 request;
  final Future<void> Function() onDecline;
  final Future<void> Function() onAccept;
  final String declineLabel;
  final String acceptLabel;

  @override
  State<ClientRequestDetailsPage> createState() =>
      _ClientRequestDetailsPageState();
}

class _ClientRequestDetailsPageState extends State<ClientRequestDetailsPage> {
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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(color: AppColors.snow),
        child: FutureBuilder<_RequestDetailsVm>(
          future: _vmFuture,
          builder: (context, snap) {
            final vm = snap.data ?? _RequestDetailsVm.fallback(widget.request);
            return Column(
              children: [
                _headerBar(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Brand Request Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat,
                              ),
                            ),
                          ),
                          if (_showDirectChip(vm))
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFB89A66),
                                ),
                                color: const Color(0xFFFFF7EA),
                              ),
                              child: const Text(
                                'Direct',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blackCat,
                                ),
                              ),
                            ),
                          Text(
                            vm.statusLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _overviewCard(vm),
                      if (vm.requiresNfc) ...[
                        const SizedBox(height: 10),
                        _nfcRequiredNotice(),
                      ],
                      const SizedBox(height: 16),
                      _plainSection(title: 'Company Bio', body: vm.companyBio),
                      _separator(),
                      _plainSection(
                        title: 'Custom Request Description',
                        body: vm.customDescription,
                      ),
                      _separator(),
                      _orderDetailsSection(vm),
                      _separator(),
                      _nailDimensionsSection(vm),
                      _separator(),
                      _numberOfSetsSection(vm.numberOfSets),
                      _separator(),
                      const SizedBox(height: 16),
                      _sectionHeader(text: 'Inspiration Photos'),
                      const SizedBox(height: 10),
                      _photosStrip(vm.photos),
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
    );
  }

  bool _showDirectChip(_RequestDetailsVm vm) {
    return widget.request.isDirectRequest &&
        !vm.openToClientPool &&
        vm.orderTypeRaw == 'single';
  }

  Widget _headerBar(BuildContext context) {
    return Container(
      color: AppColors.alabaster,
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 34),
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
          Text(
            vm.campaignName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Request Type: ${vm.requestType}  |  Order Type: ${vm.orderType}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.blackCat,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.blackCat.withValues(alpha: 0.14)),
        ],
      ),
    );
  }

  Widget _orderDetailsSection(_RequestDetailsVm vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Need By: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: vm.needByLabel),
            ],
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Accept By: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: vm.requestAcceptByLabel),
            ],
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Client Budget Range: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: vm.clientBudgetLabel),
            ],
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.blackCat,
          ),
        ),
      ],
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dimensionHandCard(
                'Left Hand',
                vm.leftHand,
                showNfcTags: vm.requiresNfc,
              ),
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 3),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: Column(
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
          row(
            'Index',
            hand.index,
            showNfc: showNfcTags && isNfcEligibleDimension(hand.index),
          ),
          row(
            'Middle',
            hand.middle,
            showNfc: showNfcTags && isNfcEligibleDimension(hand.middle),
          ),
          row(
            'Ring',
            hand.ring,
            showNfc: showNfcTags && isNfcEligibleDimension(hand.ring),
          ),
          row(
            'Pinky',
            hand.pinky,
            showNfc: showNfcTags && isNfcEligibleDimension(hand.pinky),
          ),
        ],
      ),
    );
  }

  Widget _nfcRequiredNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers.withValues(alpha: 0.45),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.nfc_rounded, size: 18, color: AppColors.blackCat),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'NFC Smart Nail Required',
              style: TextStyle(
                color: AppColors.blackCat,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'ArialBold',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nfcChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.circular(10),
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

  Widget _plainSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
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
      ),
    );
  }

  Widget _numberOfSetsSection(String numberOfSets) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
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
      ),
    );
  }

  Widget _separator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.blackCat.withValues(alpha: 0.14),
      ),
    );
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
    required this.brandName,
    required this.campaignName,
    required this.profileImage,
    required this.statusLabel,
    required this.needByLabel,
    required this.clientBudgetLabel,
    required this.requestType,
    required this.orderType,
    required this.openToClientPool,
    required this.orderTypeRaw,
    required this.companyBio,
    required this.customDescription,
    required this.numberOfSets,
    required this.photos,
    required this.leftHand,
    required this.rightHand,
    required this.requiresNfc,
    required this.requestAcceptByLabel,
  });

  final String brandName;
  final String campaignName;
  final String profileImage;
  final String statusLabel;
  final String needByLabel;
  final String clientBudgetLabel;
  final String requestType;
  final String orderType;
  final bool openToClientPool;
  final String orderTypeRaw;
  final String companyBio;
  final String customDescription;
  final String numberOfSets;
  final List<String> photos;
  final NailDimensionsV2 leftHand;
  final NailDimensionsV2 rightHand;
  final bool requiresNfc;
  final String requestAcceptByLabel;

  static _RequestDetailsVm fallback(ClientRequestV2 request) {
    final initialBrand = request.brandName.trim().isNotEmpty
        ? request.brandName.trim()
        : request.clientName.trim();
    final acceptByDate = DateTime(
      request.neededBy.year,
      request.neededBy.month,
      request.neededBy.day,
    ).subtract(const Duration(days: 5));
    return _RequestDetailsVm(
      brandName: initialBrand.isEmpty ? 'Brand Company' : initialBrand,
      campaignName: request.title.trim().isEmpty
          ? 'Untitled Campaign'
          : request.title.trim(),
      profileImage: request.clientProfileImage,
      statusLabel: _statusLabel(request.status),
      needByLabel: _dateLabel(request.neededBy),
      clientBudgetLabel:
          '\$${request.clientBudgetMin ?? request.budgetMin} - \$${request.clientBudgetMax ?? request.budgetMax}',
      requestType: _requestTypeFromRouting(
        openToClientPool: request.openToClientPool,
        openToArtistPool:
            request.selectedArtist.trim().isEmpty &&
            request.selectedArtistEmail.trim().isEmpty,
        orderTypeRaw: request.orderType == RequestOrderTypeV2.group
            ? 'group'
            : 'single',
      ),
      orderType: request.orderType == RequestOrderTypeV2.group
          ? 'Group'
          : 'Single',
      openToClientPool: request.openToClientPool,
      orderTypeRaw: request.orderType == RequestOrderTypeV2.group
          ? 'group'
          : 'single',
      companyBio: 'No company bio available.',
      customDescription: request.bio.trim().isEmpty ? '-' : request.bio.trim(),
      numberOfSets: '1',
      photos: request.clientImages,
      leftHand: request.leftHand,
      rightHand: request.rightHand,
      requiresNfc: _requestRequiresNfcFromMaps(
        const <String, dynamic>{},
        const <String, dynamic>{},
        const <String, dynamic>{},
      ),
      requestAcceptByLabel: _dateLabel(acceptByDate),
    );
  }

  static Future<_RequestDetailsVm> load(ClientRequestV2 request) async {
    final docRef = FirebaseFirestore.instance
        .collection(request.sourceCollection)
        .doc(request.id);
    final results = await Future.wait([
      docRef.get(),
      docRef.collection('details').doc('payload').get(),
    ]);
    final root = (results[0] as dynamic).data() ?? const <String, dynamic>{};
    final details = (results[1] as dynamic).data() ?? const <String, dynamic>{};

    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
      return const <String, dynamic>{};
    }

    String firstNonEmpty(List<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse((v ?? '').toString().trim()) ?? 0;
    }

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
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

    Future<Map<String, dynamic>> loadCurrentClientDimensions() async {
      final email = (FirebaseAuth.instance.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      if (email.isEmpty) return const <String, dynamic>{};
      for (final collection in const <String>['client', 'client_artist']) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(collection)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (snap.docs.isEmpty) continue;
          final data = snap.docs.first.data();
          final profile = asMap(data['profile']);
          final nail = asMap(data['nailPreferences']);
          final profileNail = asMap(profile['nailPreferences']);
          final dims = asMap(nail['dimensions']).isNotEmpty
              ? asMap(nail['dimensions'])
              : asMap(profileNail['dimensions']);
          if (dims.isNotEmpty) return dims;
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
    final openToClientPool =
        asNullableBool(root['openToClientPool']) ??
        asNullableBool(order['openToClientPool']) ??
        asNullableBool(details['openToClientPool']) ??
        ((root['selectedClient'] ?? '').toString().trim().isEmpty &&
            orderTypeRaw != 'group');
    final openToArtistPool =
        asNullableBool(root['openToArtistPool']) ??
        asNullableBool(order['openToArtistPool']) ??
        asNullableBool(details['openToArtistPool']) ??
        (root['selectedArtist'] ?? '').toString().trim().isEmpty;
    final computedRequestType = _requestTypeFromRouting(
      openToClientPool: openToClientPool,
      openToArtistPool: openToArtistPool,
      orderTypeRaw: orderTypeRaw,
    );
    final requestType = computedRequestType;
    final customDescription = firstNonEmpty([
      requestDetails['description'],
      root['descriptionPreview'],
      root['bio'],
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
    final numberOfSets = asInt(requestDetails['numberOfSets']) > 0
        ? asInt(requestDetails['numberOfSets']).toString()
        : (asInt(requestDetails['quantity']) > 0
              ? asInt(requestDetails['quantity']).toString()
              : (asInt(root['numberOfSets']) > 0
                    ? asInt(root['numberOfSets']).toString()
                    : (asInt(root['quantity']) > 0
                          ? asInt(root['quantity']).toString()
                          : '1')));

    String companyBio = '';
    final companySnapshot = asMap(details['companyProfileSnapshot']).isNotEmpty
        ? asMap(details['companyProfileSnapshot'])
        : asMap(root['companyProfileSnapshot']);
    final companyUid = firstNonEmpty([root['companyUid']]);
    final companyEmail = firstNonEmpty([
      root['companyEmail'],
      root['clientEmail'],
    ]).toLowerCase();
    if (companyUid.isNotEmpty) {
      final companySnap = await FirebaseFirestore.instance
          .collection('company')
          .doc(companyUid)
          .get();
      final company = companySnap.data() ?? const <String, dynamic>{};
      companyBio = firstNonEmpty([
        company['panel_companyBio'],
        company['companyBio'],
        company['bio'],
        company['panel_notes'],
        company['description'],
        company['about'],
        company['aboutBrand'],
      ]);
    }
    if (companyBio.isEmpty && companyEmail.isNotEmpty) {
      final query = await FirebaseFirestore.instance
          .collection('company')
          .where('email', isEqualTo: companyEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final company = query.docs.first.data();
        companyBio = firstNonEmpty([
          company['panel_companyBio'],
          company['companyBio'],
          company['bio'],
          company['panel_notes'],
          company['description'],
          company['about'],
          company['aboutBrand'],
        ]);
      }
    }
    if (companyBio.isEmpty) {
      companyBio = firstNonEmpty([
        companySnapshot['panel_companyBio'],
        companySnapshot['companyBio'],
        companySnapshot['bio'],
        companySnapshot['description'],
        root['companyBio'],
        root['panel_companyBio'],
        root['panel_notes'],
      ]);
    }
    if (companyBio.isEmpty) companyBio = 'No company bio available.';

    var leftHand = mapHand(left: true);
    var rightHand = mapHand(left: false);
    if (handIsEmpty(leftHand) && handIsEmpty(rightHand)) {
      final currentClientDims = await loadCurrentClientDimensions();
      if (currentClientDims.isNotEmpty) {
        String pickCurrent({required bool left, required String key}) {
          final cap = key[0].toUpperCase() + key.substring(1);
          final prefixed = left ? 'l$cap' : 'r$cap';
          return dimValue(
            currentClientDims[prefixed] ?? currentClientDims[key],
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
      brandName: brandName,
      campaignName: campaignName,
      profileImage: profileImage,
      statusLabel: _statusLabel(request.status),
      needByLabel: _dateLabel(needBy),
      clientBudgetLabel:
          '\$${cMin <= 0 ? 15 : cMin} - \$${cMax <= 0 ? 5000 : cMax}',
      requestType: requestType,
      orderType: orderType,
      openToClientPool: openToClientPool,
      orderTypeRaw: orderTypeRaw,
      companyBio: companyBio,
      customDescription: customDescription,
      numberOfSets: numberOfSets,
      photos: photos,
      leftHand: leftHand,
      rightHand: rightHand,
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

    final candidates = <Object?>[
      root['requiresNfc'],
      root['requiresNFC'],
      root['nfcRequired'],
      root['isNfcRequired'],
      root['hasNfc'],
      root['hasNFC'],
      root['nfcEnabled'],
      details['requiresNfc'],
      details['requiresNFC'],
      details['nfcRequired'],
      details['isNfcRequired'],
      details['hasNfc'],
      details['hasNFC'],
      payload['requiresNfc'],
      payload['requiresNFC'],
      payload['nfcRequired'],
      payload['isNfcRequired'],
      payload['hasNfc'],
      payload['hasNFC'],
      requestDetails['requiresNfc'],
      requestDetails['requiresNFC'],
      requestDetails['nfcRequired'],
      requestDetails['isNfcRequired'],
      requestDetails['hasNfc'],
      requestDetails['hasNFC'],
      order['requiresNfc'],
      order['requiresNFC'],
      order['nfcRequired'],
      order['isNfcRequired'],
      order['hasNfc'],
      order['hasNFC'],
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

  static String _statusLabel(RequestStatusV2 status) {
    switch (status) {
      case RequestStatusV2.inReview:
        return 'Pending';
      default:
        return status.label;
    }
  }

  static String _requestTypeFromRouting({
    required bool openToClientPool,
    required bool openToArtistPool,
    required String orderTypeRaw,
  }) {
    final isGroup = orderTypeRaw == 'group';
    if (openToClientPool) {
      return openToArtistPool ? 'Standard' : 'Direct to Artist';
    }
    if (isGroup) {
      return openToArtistPool ? 'Direct to Client' : 'Direct';
    }
    return openToArtistPool ? 'Direct to Client' : 'Direct';
  }
}
