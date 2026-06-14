import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../models/client_request_v2.dart';
import '../services/notifications_service.dart';
import '../utils/shipping_qr_helper.dart';
import '../services/storage_url_resolver.dart';
import '../widgets/group_client_measurements_tabs.dart';
import 'request_chat_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showAcceptedRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function(bool completed, List<String> artistPhotos)
  onMarkCompleted,
}) async {
  final result = await showModalBottomSheet<_AcceptedSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcceptedRequestSheet(
      request: request,
      shipDays: shipDays,
      mode: _AcceptedSheetMode.accepted,
    ),
  );

  // Firestore is already updated inside _handleMarkCompleted().
  if (result?.completed == true) {
    await onMarkCompleted(true, result?.artistPhotos ?? const <String>[]);
  } else {
    await onMarkCompleted(false, const <String>[]);
  }
}

Future<void> showDesigningRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function(bool completed, List<String> artistPhotos)
  onMarkCompleted,
}) async {
  final result = await showModalBottomSheet<_AcceptedSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcceptedRequestSheet(
      request: request,
      shipDays: shipDays,
      mode: _AcceptedSheetMode.designing,
    ),
  );

  // Firestore is already updated inside _handleMarkCompleted().
  if (result?.completed == true) {
    await onMarkCompleted(true, result?.artistPhotos ?? const <String>[]);
  } else {
    await onMarkCompleted(false, const <String>[]);
  }
}

class _AcceptedSheetResult {
  const _AcceptedSheetResult({
    required this.completed,
    required this.artistPhotos,
  });

  final bool completed;
  final List<String> artistPhotos;
}

class _AcceptedRequestSheet extends StatefulWidget {
  const _AcceptedRequestSheet({
    required this.request,
    required this.shipDays,
    required this.mode,
  });

  final ClientRequestV2 request;
  final int shipDays;
  final _AcceptedSheetMode mode;

  @override
  State<_AcceptedRequestSheet> createState() => _AcceptedRequestSheetState();
}

class _AcceptedRequestSheetState extends State<_AcceptedRequestSheet> {
  final _picker = ImagePicker();
  static const int _maxArtistImageBytes = 2 * 1024 * 1024;
  static const int _maxArtistCompletedPhotos = 10;

  /// Local photos selected for the final completed set.
  final List<XFile> _artistPhotos = [];

  /// Local photos selected for design preview/approval.
  final List<XFile> _designPreviewPhotos = [];
  final List<String> _submittedDesignPreviewUrls = <String>[];

  bool _markingCompleted = false;
  bool _submittingDesignPreview = false;
  late String _designApprovalStatus;

  List<String> _clientModalPhotos() {
    final out = <String>[];
    for (final raw in widget.request.clientImages) {
      final s = raw.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    final preview = widget.request.previewImageAsset.trim();
    if (out.isEmpty && preview.isNotEmpty) out.add(preview);
    return out;
  }

  String _heroPhotoSource(ClientRequestV2 r) {
    final profile = r.clientProfileImage.trim();
    if (profile.isNotEmpty) return profile;
    return '';
  }

  bool get _showClientDeclineInfo =>
      widget.request.completionReviewStatus.trim().toLowerCase() == 'declined';

  bool get _isDesigningMode => widget.mode == _AcceptedSheetMode.designing;
  bool get _isDesignApproved =>
      _designApprovalStatus.trim().toLowerCase() == 'approved';
  bool get _isDesignPending =>
      _designApprovalStatus.trim().toLowerCase() == 'pending';

  bool get _isPaymentDone {
    final paymentStatus = widget.request.paymentStatus.trim().toLowerCase();
    return paymentStatus == 'paid' || paymentStatus == 'completed';
  }

  @override
  void initState() {
    super.initState();
    _designApprovalStatus = widget.request.designApprovalStatus;
    _submittedDesignPreviewUrls.addAll(widget.request.designPreviewPhotos);
  }

  @override
  void didUpdateWidget(covariant _AcceptedRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when request data changes to ensure images are synced
    if (oldWidget.request != widget.request) {
      setState(() {
        _designApprovalStatus = widget.request.designApprovalStatus;
        _submittedDesignPreviewUrls.clear();
        _submittedDesignPreviewUrls.addAll(widget.request.designPreviewPhotos);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;

    final clientModalPhotos = _clientModalPhotos();
    return Align(
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
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _topHeader(widget.request, shipDays: widget.shipDays),

                  const SizedBox(height: 12),

                  // ✅ Accepted / Designing card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CBF6A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.78),
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              fontSize: 13.5,
                            ),
                            children: [
                              TextSpan(
                                text: _isDesigningMode
                                    ? 'Designing!\n'
                                    : 'Accepted!\n',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: _isDesigningMode
                                    ? 'You are now designing '
                                    : 'You accepted ',
                              ),
                              TextSpan(
                                text: "${widget.request.clientName}'s request",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: _isDesigningMode
                                    ? '. Continue designing the set, upload photos, and mark as completed.'
                                    : '. Once the set is ready, upload photos and mark as completed.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),
                  if (_isDesigningMode)
                    _finalAcceptedAmountBox(widget.request)
                  else
                    _paymentSectionBox(widget.request),
                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),
                  if (_showClientDeclineInfo) ...[
                    _clientDeclineReasonSection(widget.request),
                    const SizedBox(height: 10),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                  ],

                  _sectionTitle('Description'),
                  const SizedBox(height: 8),
                  Text(
                    widget.request.bio.trim().isEmpty
                        ? '—'
                        : widget.request.bio.trim(),
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.75),
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),

                  if (_isBrandRequest(widget.request)) ...[
                    _acceptedClientDetailsSection(widget.request),
                    const SizedBox(height: 10),
                    const Divider(
                      height: 1,
                      color: AppColors.blackCatBorderLight,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _measurementSection(),

                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 12),

                  _sectionTitle('Uploaded Photos (Client)'),
                  const SizedBox(height: 10),
                  if (clientModalPhotos.isEmpty)
                    _softBox(
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: Colors.black.withOpacity(0.45),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'No images uploaded',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _clientPhotosGrid(clientModalPhotos),

                  const SizedBox(height: 10),
                  const Divider(
                    height: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                  const SizedBox(height: 14),

                  if (_isDesigningMode) ...[
                    _sectionTitle('Upload Completed Set (Artist)'),
                    const SizedBox(height: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blackCat.withValues(
                                  alpha: 0.78,
                                ),
                                foregroundColor: AppColors.snow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                              ),
                              onPressed: () =>
                                  _openPickOptions(_UploadTarget.completedSet),
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text(
                                'Upload',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Allowed formats: JPG, JPEG, PNG. Max file size: < 2 MB each. Maximum 10 photos.',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
                          ),
                        ),
                        if (_artistPhotos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _artistPhotosGrid(),
                        ],
                        if (_artistPhotos.isEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Add photos of the finished nails before marking as completed.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.60),
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),

            // Bottom actions
            if (_isDesigningMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 132,
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.blackCat.withOpacity(0.16),
                          foregroundColor: AppColors.blackCat,
                          side: BorderSide(
                            color: AppColors.blackCat.withOpacity(0.30),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          final artistEmail =
                              (widget.request.acceptedByArtistEmail
                                          .trim()
                                          .isNotEmpty
                                      ? widget.request.acceptedByArtistEmail
                                      : (FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.email ??
                                            ''))
                                  .trim()
                                  .toLowerCase();
                          if (widget.request.clientEmail.trim().isEmpty ||
                              artistEmail.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Chat unavailable until both client and artist are assigned.',
                                ),
                              ),
                            );
                            return;
                          }
                          showRequestChatModal(
                            context: context,
                            requestId: widget.request.id,
                            clientEmail: widget.request.clientEmail,
                            artistEmail: artistEmail,
                            clientName: widget.request.clientName,
                            artistName:
                                (FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.displayName ??
                                        '')
                                    .trim(),
                          );
                        },
                        child: const Text(
                          'Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            fontFamily: 'Arial',
                            color: AppColors.snow,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 166,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
                        ),
                        onPressed: (_markingCompleted || _artistPhotos.isEmpty)
                            ? null
                            : _handleMarkCompleted,
                        child: _markingCompleted
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Mark as Completed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  fontFamily: 'Arial',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // Actions
  // -----------------------
  Future<void> _openPickOptions(_UploadTarget target) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add photos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          backgroundColor: AppColors.snow,
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        label: const Text(
                          'Choose from Gallery',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: AppColors.blackCat,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _pickFromGallery(target);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          backgroundColor: AppColors.snow,
                        ),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: AppColors.blackCat,
                        ),
                        label: const Text(
                          'Take Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: AppColors.blackCat,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _takePhoto(target);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery(_UploadTarget target) async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked.isEmpty) return;

    await _validateAndAddPhotos(picked, target);
  }

  Future<void> _takePhoto(_UploadTarget target) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (x == null) return;

    await _validateAndAddPhotos([x], target);
  }

  bool _isAllowedImageExtension(String value) {
    final p = value.trim().toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
  }

  bool _hasAllowedImageSignature(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true; // JPEG
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true; // PNG
    }
    return false;
  }

  Future<bool> _isAllowedImageFile(XFile file) async {
    if (_isAllowedImageExtension(file.name) ||
        _isAllowedImageExtension(file.path)) {
      return true;
    }
    try {
      final bytes = await file.readAsBytes();
      return _hasAllowedImageSignature(bytes);
    } catch (_) {
      return false;
    }
  }

  Future<void> _validateAndAddPhotos(
    List<XFile> files,
    _UploadTarget target,
  ) async {
    final accepted = <XFile>[];
    var invalidType = 0;
    var invalidSize = 0;
    var skippedForLimit = 0;
    final maxPhotos = target == _UploadTarget.completedSet
        ? _maxArtistCompletedPhotos
        : null;
    final existingCount = target == _UploadTarget.completedSet
        ? _artistPhotos.length
        : _designPreviewPhotos.length;

    for (final file in files) {
      if (maxPhotos != null && existingCount + accepted.length >= maxPhotos) {
        skippedForLimit++;
        continue;
      }
      if (!await _isAllowedImageFile(file)) {
        invalidType++;
        continue;
      }
      final bytes = await file.length();
      if (bytes > _maxArtistImageBytes) {
        invalidSize++;
        continue;
      }
      accepted.add(file);
    }

    if (accepted.isNotEmpty) {
      setState(() {
        if (target == _UploadTarget.completedSet) {
          _artistPhotos.addAll(accepted);
        } else {
          _designPreviewPhotos.addAll(accepted);
        }
      });
    }

    if (!mounted) return;
    if (invalidType > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidType file(s) skipped. Only JPG, JPEG, PNG are allowed.',
          ),
        ),
      );
    }
    if (invalidSize > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidSize file(s) skipped. File size must be less than 2 MB.',
          ),
        ),
      );
    }
    if (skippedForLimit > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extra photos were skipped. Maximum is 10.'),
        ),
      );
    }
  }

  Future<void> _handleMarkCompleted() async {
    if (_artistPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least 1 photo before completing.'),
        ),
      );
      return;
    }

    setState(() => _markingCompleted = true);

    try {
      final uploadedArtistPhotos = await _uploadArtistPhotos();

      if (uploadedArtistPhotos.isEmpty) {
        throw Exception(
          'Photo upload failed. No uploaded image URL was returned.',
        );
      }

      final docRef = FirebaseFirestore.instance
          .collection(widget.request.sourceCollection)
          .doc(widget.request.id);
      final currentUser = FirebaseAuth.instance.currentUser;
      final artistId = (currentUser?.uid ?? '').trim();
      final artistEmail = (currentUser?.email ?? '').trim();
      final orderNumber = widget.request.orderNumber.trim().isNotEmpty
          ? widget.request.orderNumber.trim()
          : widget.request.id;
      final shipping = buildShippingPayload(
        collectionName: widget.request.sourceCollection,
        orderDocId: widget.request.id,
        orderNumber: orderNumber,
        artistId: artistId,
        artistEmail: artistEmail,
        shippingAddressDifferentFromProfile:
            widget.request.shippingAddressDifferentFromProfile,
        shippingStreet: widget.request.shippingStreet,
        shippingCity: widget.request.shippingCity,
        shippingState: widget.request.shippingState,
        shippingZip: widget.request.shippingZip,
        shippingCountry: widget.request.shippingCountry,
      );
      final completedArt = <String, dynamic>{
        'imageUrls': uploadedArtistPhotos,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedByArtistId': artistId,
        'uploadedByArtistEmail': artistEmail,
      };

      await docRef.set({
        'status': 'completed',
        'artistStatus': 'Completed',
        'clientStatus': 'In Progress',
        'artistImages': uploadedArtistPhotos,
        'artistUploadedPhotos': uploadedArtistPhotos,
        'artistCompletedPhotos': uploadedArtistPhotos,
        'completedArt': completedArt,
        'shipping': shipping,
        'shippingStatus': 'label_ready',
        'shippingLabelQrData': shipping['qrCode'],
        'shippingLabelReady': true,
        'completedPhotos': FieldValue.delete(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await docRef.collection('details').doc('payload').set({
        'status': 'completed',
        'artistStatus': 'Completed',
        'clientStatus': 'In Progress',
        'artistImages': uploadedArtistPhotos,
        'artistUploadedPhotos': uploadedArtistPhotos,
        'artistCompletedPhotos': uploadedArtistPhotos,
        'completedArt': completedArt,
        'shipping': shipping,
        'shippingStatus': 'label_ready',
        'shippingLabelQrData': shipping['qrCode'],
        'shippingLabelReady': true,
        'completedPhotos': FieldValue.delete(),
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final result = _AcceptedSheetResult(
        completed: true,
        artistPhotos: uploadedArtistPhotos,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }

      // Run non-critical side effects after closing the sheet so UI is not blocked.
      unawaited(_runPostCompleteSideEffects(docRef, uploadedArtistPhotos));
    } catch (e) {
      debugPrint('MARK COMPLETED FAILED: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark completed: $e')));
    } finally {
      if (mounted) {
        setState(() => _markingCompleted = false);
      }
    }
  }

  Future<void> _runPostCompleteSideEffects(
    DocumentReference<Map<String, dynamic>> docRef,
    List<String> uploadedArtistPhotos,
  ) async {
    try {
      await _notifyClientOrderCompleted(docRef: docRef);
    } catch (_) {}
    try {
      await _mirrorCompletedPhotosToClientPortfolio(uploadedArtistPhotos);
    } catch (_) {}
    try {
      await _mirrorCompletedPhotosToArtistPortfolio(uploadedArtistPhotos);
    } catch (_) {}
  }

  Future<void> _notifyClientOrderCompleted({
    required DocumentReference<Map<String, dynamic>> docRef,
  }) async {
    final orderNo = widget.request.orderNumber.trim().isNotEmpty
        ? widget.request.orderNumber.trim()
        : widget.request.id;
    final sourceCollection = widget.request.sourceCollection.trim().isNotEmpty
        ? widget.request.sourceCollection.trim()
        : 'Client_Custom_Requests';
    final title = 'Order Completed';
    final artistName =
        (FirebaseAuth.instance.currentUser?.displayName ?? '').trim().isNotEmpty
        ? (FirebaseAuth.instance.currentUser?.displayName ?? '').trim()
        : (FirebaseAuth.instance.currentUser?.email ?? 'Artist')
              .split('@')
              .first;

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final detailSnap = await docRef.collection('details').doc('payload').get();
    final detailData = detailSnap.data() ?? const <String, dynamic>{};

    if (_isBrandRequest(widget.request)) {
      // Brand request completion notifications are emitted by the centralized
      // flow in artist_requests_page_redesign.dart. Skip here to avoid duplicates.
      return;
    } else {
      // Client in-app completion notification is emitted by
      // artist_requests_page_redesign.dart. Skip here to avoid duplicates.
    }

    try {
      final profileSnapshot =
          (detailData['clientProfileSnapshot'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final basic =
          (profileSnapshot['basic'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final phone =
          ((data['clientPhone'] ?? basic['phone'] ?? data['phone'] ?? '')
                  as Object)
              .toString()
              .trim();
      if (phone.isNotEmpty) {
        await NotificationsService.queueSms(
          to: phone,
          text:
              'JNT: Your completed design for order $orderNo is ready for review. Please accept or decline in the app.',
        );
      }
    } catch (_) {}
  }

  Future<void> _mirrorCompletedPhotosToClientPortfolio(
    List<String> photos,
  ) async {
    if (photos.isEmpty) return;
    final clientEmail = widget.request.clientEmail.trim().toLowerCase();
    if (clientEmail.isEmpty) return;

    final db = FirebaseFirestore.instance;

    Future<DocumentReference<Map<String, dynamic>>?> findClientRef(
      String collection,
    ) async {
      final snap = await db
          .collection(collection)
          .where('email', isEqualTo: clientEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.reference;
    }

    DocumentReference<Map<String, dynamic>>? clientRef;
    try {
      clientRef = await findClientRef('client_artist');
      clientRef ??= await findClientRef('client');
    } catch (_) {
      return;
    }
    if (clientRef == null) return;

    final cleaned = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return;

    final now = Timestamp.now();
    final itemMaps = cleaned
        .map(
          (url) => <String, dynamic>{
            'imageUrl': url,
            'url': url,
            'image': url,
            'style': 'All',
            'source': 'artist_completed_set',
            'requestId': widget.request.id,
            'createdAt': now,
          },
        )
        .toList(growable: false);

    await clientRef.set({
      'portfolioImages': FieldValue.arrayUnion(cleaned),
      'panel_portfolioImages': FieldValue.arrayUnion(cleaned),
      'panel_artist_portfolioImages': FieldValue.arrayUnion(cleaned),
      'portfolioItems': FieldValue.arrayUnion(itemMaps),
      'portfolio': {
        'images': FieldValue.arrayUnion(cleaned),
        'items': FieldValue.arrayUnion(itemMaps),
      },
      'client': {
        'portfolioImages': FieldValue.arrayUnion(cleaned),
        'portfolioItems': FieldValue.arrayUnion(itemMaps),
        'portfolio': {
          'images': FieldValue.arrayUnion(cleaned),
          'items': FieldValue.arrayUnion(itemMaps),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final url in cleaned) {
      try {
        await clientRef.collection('portfolio_items').add({
          'imageUrl': url,
          'url': url,
          'image': url,
          'style': 'All',
          'storagePath': '',
          'source': 'artist_completed_set',
          'requestId': widget.request.id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _mirrorCompletedPhotosToArtistPortfolio(
    List<String> photos,
  ) async {
    if (photos.isEmpty) return;
    final artistEmail =
        (widget.request.acceptedByArtistEmail.trim().isNotEmpty
                ? widget.request.acceptedByArtistEmail
                : (FirebaseAuth.instance.currentUser?.email ?? ''))
            .trim()
            .toLowerCase();
    if (artistEmail.isEmpty) return;

    final db = FirebaseFirestore.instance;

    Future<DocumentReference<Map<String, dynamic>>?> findArtistRef(
      String collection,
    ) async {
      final snap = await db
          .collection(collection)
          .where('email', isEqualTo: artistEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.reference;
    }

    DocumentReference<Map<String, dynamic>>? artistRef;
    try {
      artistRef = await findArtistRef('artist');
      artistRef ??= await findArtistRef('client_artist');
    } catch (_) {
      return;
    }
    if (artistRef == null) return;

    final cleaned = photos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return;

    final now = Timestamp.now();
    final itemMaps = cleaned
        .map(
          (url) => <String, dynamic>{
            'imageUrl': url,
            'url': url,
            'image': url,
            'style': 'All',
            'source': 'artist_completed_set',
            'requestId': widget.request.id,
            'createdAt': now,
          },
        )
        .toList(growable: false);

    await artistRef.set({
      'portfolioImages': FieldValue.arrayUnion(cleaned),
      'panel_portfolioImages': FieldValue.arrayUnion(cleaned),
      'panel_artist_portfolioImages': FieldValue.arrayUnion(cleaned),
      'portfolioItems': FieldValue.arrayUnion(itemMaps),
      'portfolio': {
        'images': FieldValue.arrayUnion(cleaned),
        'items': FieldValue.arrayUnion(itemMaps),
      },
      'artist': {
        'portfolioImages': FieldValue.arrayUnion(cleaned),
        'portfolioItems': FieldValue.arrayUnion(itemMaps),
        'portfolio': {
          'images': FieldValue.arrayUnion(cleaned),
          'items': FieldValue.arrayUnion(itemMaps),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final url in cleaned) {
      try {
        await artistRef.collection('portfolio_items').add({
          'imageUrl': url,
          'url': url,
          'image': url,
          'style': 'All',
          'storagePath': '',
          'source': 'artist_completed_set',
          'requestId': widget.request.id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _submitDesignForApproval() async {
    if (_designPreviewPhotos.isEmpty && _submittedDesignPreviewUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 1 design image.')),
      );
      return;
    }

    setState(() => _submittingDesignPreview = true);
    try {
      final uploaded = <String>[..._submittedDesignPreviewUrls];
      if (_designPreviewPhotos.isNotEmpty) {
        uploaded.addAll(
          await _uploadPhotosFor(
            photos: _designPreviewPhotos,
            storageFolder: 'artist_design_previews',
          ),
        );
      }
      if (uploaded.isEmpty) {
        throw Exception('Unable to upload design previews.');
      }

      final dueAt = DateTime.now().add(const Duration(days: 1));
      final docRef = FirebaseFirestore.instance
          .collection('Client_Custom_Requests')
          .doc(widget.request.id);
      await docRef.set({
        'status': 'designing',
        'designApprovalStatus': 'pending',
        'clientDesignApprovalStatus': 'pending',
        'designPreviewPhotos': uploaded,
        'designSubmittedAt': FieldValue.serverTimestamp(),
        'designApprovalDueAt': Timestamp.fromDate(dueAt),
        'designReminderSentAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await docRef.collection('details').doc('payload').set({
        'designApproval': {
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'dueAt': Timestamp.fromDate(dueAt),
          'previewPhotos': uploaded,
          'reminderSentAt': null,
        },
      }, SetOptions(merge: true));

      final clientEmail = widget.request.clientEmail.trim().toLowerCase();
      if (clientEmail.isNotEmpty) {
        await NotificationsService.createUserNotification(
          receiverEmail: clientEmail,
          title: 'Design Ready for Approval',
          body:
              'Your artist shared a design preview. Please accept within 1 day so work can begin.',
          type: 'design_approval_required',
          orderId: widget.request.id,
          sourceCollection: 'Client_Custom_Requests',
        );
      }

      if (!mounted) return;
      setState(() {
        _designApprovalStatus = 'pending';
        _submittedDesignPreviewUrls
          ..clear()
          ..addAll(uploaded);
        _designPreviewPhotos.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Design submitted for client approval. Work starts after approval.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit design: $e')));
    } finally {
      if (mounted) setState(() => _submittingDesignPreview = false);
    }
  }

  Future<List<String>> _uploadArtistPhotos() async {
    return _uploadPhotosFor(
      photos: _artistPhotos,
      storageFolder: 'artist_completed_sets',
    );
  }

  Future<List<String>> _uploadPhotosFor({
    required List<XFile> photos,
    required String storageFolder,
  }) async {
    final refs = <String>[];
    final storage = FirebaseStorage.instance;
    final requestId = widget.request.id.trim().isEmpty
        ? 'request'
        : widget.request.id.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    var dataUriBudget = 900000;

    for (var i = 0; i < photos.length; i++) {
      final file = photos[i];
      final ext = _guessExt(file.path);
      final path = '$storageFolder/$requestId/$now-$i.$ext';
      final ref = storage.ref().child(path);
      final contentType = 'image/jpeg';

      String uploadedUrl = '';
      try {
        final originalBytes = await file.readAsBytes().timeout(
          const Duration(seconds: 20),
        );
        final bytes = _normalizeImageBytes(originalBytes);
        final uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            uploadTask.cancel();
            throw TimeoutException(
              'Upload timeout after 20 seconds for ${file.name}',
            );
          },
        );
        if (snapshot.state != TaskState.success) {
          throw Exception('Upload failed with state: ${snapshot.state}');
        }
        uploadedUrl = 'gs://${ref.bucket}/${ref.fullPath}';
      } catch (e) {
        debugPrint('[ArtistPhotoUpload] upload failed for ${file.name}: $e');
      }

      if (uploadedUrl.trim().isEmpty) {
        // Fallback: keep a compact data URI so completion does not block.
        try {
          final original = await file.readAsBytes().timeout(
            const Duration(seconds: 20),
          );
          final compact = _compactDataBytes(original);
          final dataUri = 'data:$contentType;base64,${base64Encode(compact)}';
          if (dataUri.length <= dataUriBudget) {
            uploadedUrl = dataUri;
            dataUriBudget -= dataUri.length;
            debugPrint(
              '[ArtistPhotoUpload] using data-uri fallback for ${file.name}',
            );
          }
        } catch (_) {}
      }

      if (uploadedUrl.trim().isNotEmpty) refs.add(uploadedUrl.trim());
    }
    return refs;
  }

  String _guessExt(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpeg')) return 'jpeg';
    if (p.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  Uint8List _normalizeImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image output = decoded;
      const maxSide = 1080;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        output = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
      var encoded = img.encodeJpg(output, quality: 58);
      if (encoded.length > 850 * 1024) {
        final tighter = img.copyResize(
          output,
          width: output.width >= output.height ? 900 : null,
          height: output.height > output.width ? 900 : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
        encoded = img.encodeJpg(tighter, quality: 48);
      }
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  Uint8List _compactDataBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image output = decoded;
      const maxSide = 900;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        output = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          maintainAspect: true,
          interpolation: img.Interpolation.linear,
        );
      }
      final encoded = img.encodeJpg(output, quality: 45);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  // -----------------------
  // UI helpers
  // -----------------------
  Widget _artistPhotosGrid() {
    return _localPhotosGrid(
      photos: _artistPhotos,
      onRemoveAt: (i) => setState(() => _artistPhotos.removeAt(i)),
    );
  }

  Widget _localPhotosGrid({
    required List<XFile> photos,
    required void Function(int index) onRemoveAt,
  }) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final x = photos[i];

          final imageWidget = kIsWeb
              ? Image.network(x.path, fit: BoxFit.cover)
              : Image.file(File(x.path), fit: BoxFit.cover);

          return SizedBox(
            width: 112,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: imageWidget,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: InkWell(
                    onTap: () => onRemoveAt(i),
                    child: Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.70),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );

  Widget _finalAcceptedAmountBox(ClientRequestV2 r) {
    final amountText = r.artistFinalAmount != null
        ? '\$${r.artistFinalAmount!.round()}'
        : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Final Accepted Amount',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Amount: $amountText',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.80),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Artist can start working immediately after acceptance.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.72),
          ),
        ),
      ],
    );
  }

  Widget _paymentSectionBox(ClientRequestV2 r) {
    final paymentStatus = r.paymentStatus.trim().toLowerCase();
    final isPaid =
        _isDesigningMode ||
        paymentStatus == 'paid' ||
        paymentStatus == 'completed';
    final statusText = isPaid ? 'Paid' : 'Pending';
    final statusBg = AppColors.balletSlippers;
    final statusFg = AppColors.blackCat;
    final amountText = r.artistFinalAmount != null
        ? '\$${r.artistFinalAmount!.round()}'
        : '\$${r.budgetMin} to \$${r.budgetMax}';

    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Amount:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.balletSlippers,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Text(
                  amountText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFFEAF7F2) : const Color(0xFFF8F8FB),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isPaid ? Icons.check_circle_outline : Icons.info_outline,
                  size: 14,
                  color: isPaid
                      ? const Color(0xFF2E8B57)
                      : Colors.black.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPaid
                        ? (_isDesigningMode
                              ? 'Continue designing and mark as completed when done.'
                              : 'You can now complete and ship this order.')
                        : 'Waiting for client payment. You will get a notification once payment is received.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: Colors.black.withOpacity(0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientDeclineReasonSection(ClientRequestV2 r) {
    final raw = r.completionDeclineReason.trim();
    final reasons = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    String? otherReason;
    final primaryReasons = <String>[];
    for (final reason in reasons) {
      if (reason.toLowerCase().startsWith('other:')) {
        final detail = reason.substring('other:'.length).trim();
        if (detail.isNotEmpty) {
          otherReason = detail;
        }
      } else {
        primaryReasons.add(reason);
      }
    }
    final dateText = _dateText(r.completionDeclinedAt) ?? '—';

    return _softBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Decline Reason',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _kv(
            'Reason to decline',
            primaryReasons.isEmpty ? '—' : primaryReasons.join(', '),
          ),
          if (otherReason != null && otherReason.isNotEmpty)
            _kv('Other reason', otherReason),
          _kv('Date declined', dateText),
        ],
      ),
    );
  }

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

  static Widget _dimRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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

  static String _lengthLabel(String len) {
    final v = len.trim().toLowerCase();
    if (v == 'short') return 'Short';
    if (v == 'medium') return 'Medium';
    if (v == 'long') return 'Long';
    if (v == 'extra long' || v == 'xlong' || v == 'xl') return 'Extra Long';
    return len.trim();
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
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Nail Dimensions (mm)'),
        const SizedBox(height: 10),
        Row(
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
                    Text(
                      'Nail Shape ',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.60),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.request.nailShape,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
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
                    Text(
                      'Nail Length ',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.60),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _lengthLabel(widget.request.nailLength),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Widget _topHeader(ClientRequestV2 r, {required int shipDays}) {
    final isBrandRequest = _isBrandRequest(r);
    final headerName = isBrandRequest && r.brandName.trim().isNotEmpty
        ? r.brandName.trim()
        : r.clientName;
    final headerSubtitle = isBrandRequest ? r.title.trim() : '';
    final avatarPath = _heroPhotoSource(r);
    final avatarLetter = headerName.isEmpty ? '' : headerName[0].toUpperCase();

    Widget avatarFallback() => Container(
      height: 78,
      width: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        color: AppColors.balletSlippers,
      ),
      alignment: Alignment.center,
      child: Text(
        avatarLetter,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
      ),
    );

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              if (avatarPath.isNotEmpty)
                SizedBox(
                  height: 78,
                  width: 78,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _clientImage(avatarPath),
                  ),
                )
              else
                avatarFallback(),
              const SizedBox(height: 12),
              Text(
                headerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (headerSubtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  headerSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: Colors.black.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 6),
                _outlinedChip('Brand Request'),
              ],
              const SizedBox(height: 4),
              Text(
                'Order # ${r.orderNumber.trim().isNotEmpty ? r.orderNumber.trim() : r.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  color: Colors.black.withOpacity(0.60),
                ),
              ),
              const SizedBox(height: 12),
              _requestTypeOrderRow(r),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _chipInfo(
                      icon: Icons.calendar_today_outlined,
                      text: 'Need by: ${_needByLabel(r.neededBy)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _chipInfo(
                      icon: Icons.attach_money_rounded,
                      text: 'Budget: \$${r.budgetMin} to \$${r.budgetMax}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.blackCatBorderLight),
            ],
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => Navigator.pop(
              context,
              const _AcceptedSheetResult(
                completed: false,
                artistPhotos: <String>[],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.black.withOpacity(0.70),
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
                        child: _clientImage(avatarPath),
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
      _normalizeImagePath(_heroPhotoSource(request)),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    );
  }

  static Widget _miniChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.blackCat),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
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

  static Widget _infoPill(IconData icon, String a, String b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black.withOpacity(0.75)),
          const SizedBox(width: 10),
          Text(
            a,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          Expanded(
            child: Text(
              b,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
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

  Widget _clientPhotosGrid(List<String> images) {
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
              borderRadius: BorderRadius.zero,
              onTap: () => _openImagePreview(path),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: _clientImage(path),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _clientImage(String path) {
    final p = _normalizeImagePath(path);
    Widget fallback() => Container(
      color: Colors.black.withOpacity(0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.black.withOpacity(0.35),
      ),
    );
    final dataBytes = _decodeDataImageBytes(p);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    final isRemoteLike =
        p.startsWith('gs://') ||
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('blob:') ||
        p.startsWith('content://');

    if (isRemoteLike) {
      return FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
          return '';
        }),
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
    if (p.startsWith('assets/')) {
      return Image.asset(
        p,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    if (!kIsWeb &&
        (p.startsWith('/') || p.contains(':\\') || p.startsWith('file://'))) {
      final local = p.startsWith('file://') ? p.substring(7) : p;
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return FutureBuilder<String>(
      future: StorageUrlResolver.resolve(p).then((v) {
        final resolved = (v ?? '').trim();
        if (resolved.isNotEmpty) return resolved;
        if (p.startsWith('http://') || p.startsWith('https://')) return p;
        return '';
      }),
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

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _dateText(DateTime? date) {
    if (date == null) return null;
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
    return '${wds[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _normalizeImagePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return p;
    for (var i = 0; i < 3; i++) {
      final decoded = Uri.decodeFull(p);
      if (decoded == p) break;
      p = decoded;
    }
    if (p.startsWith('gs%3A') ||
        p.startsWith('content%3A') ||
        p.startsWith('file%3A') ||
        p.startsWith('http%3A') ||
        p.startsWith('https%3A')) {
      p = Uri.decodeFull(p);
    }
    if (p.startsWith('assets/')) {
      final rest = p.substring('assets/'.length);
      if (rest.startsWith('http://') ||
          rest.startsWith('https://') ||
          rest.startsWith('gs://') ||
          rest.startsWith('blob:') ||
          rest.startsWith('data:') ||
          rest.startsWith('content://') ||
          rest.startsWith('file://')) {
        p = rest;
      }
    }
    return p;
  }

  Future<void> _openImagePreview(String path) async {
    final p = _normalizeImagePath(path);
    Widget image = _clientImage(p);
    if (p.startsWith('gs://')) {
      image = FutureBuilder<String>(
        future: StorageUrlResolver.resolve(p).then((v) {
          final resolved = (v ?? '').trim();
          if (resolved.isNotEmpty) return resolved;
          if (p.startsWith('http://') || p.startsWith('https://')) return p;
          return '';
        }),
        builder: (_, snap) {
          final url = (snap.data ?? '').trim();
          if (url.isEmpty) return const SizedBox.shrink();
          return Image.network(url, fit: BoxFit.contain);
        },
      );
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: image),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.blackCat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AcceptedSheetMode { accepted, designing }

enum _UploadTarget { completedSet, designPreview }

class _ShippingQrDialog extends StatelessWidget {
  const _ShippingQrDialog({
    required this.qrCode,
    required this.orderNumber,
    required this.artistId,
  });

  final String qrCode;
  final String orderNumber;
  final String artistId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SHIPPING QR CODE',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Show the QR code below to the carrier when shipping the item.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),

            // ✅ Replace with real QR widget later (qr_flutter)
            Container(
              height: 210,
              width: 210,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.zero,
              ),
              alignment: Alignment.center,
              child: QrImageView(
                data: qrCode,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Order #: $orderNumber',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Artist ID: ${artistId.isEmpty ? '-' : artistId}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6FED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Download/Print will be enabled in next step.',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Download / Print QR',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Confirm Shipment Later',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
