import 'package:flutter/foundation.dart';

enum RequestStatus {
  newRequest,
  inReview,
  accepted,
  declined,
  completed,
  shipped,
  delivered,
  cancelled,
  expired,
}

@immutable
class NailDimensions {
  final String thumb;
  final String index;
  final String middle;
  final String ring;
  final String pinky;

  const NailDimensions({
    required this.thumb,
    required this.index,
    required this.middle,
    required this.ring,
    required this.pinky,
  });
}

@immutable
class ClientRequest {
  final String id;
  final String clientName;
  final String title;
  final String subtitle;
  final DateTime neededBy;
  final int budgetMin;
  final int budgetMax;
  final NailDimensions leftHand;
  final NailDimensions rightHand;
  final String nailShape;
  final String nailLength;
  final String bio;
  final List<String> images;
  final List<String> artistUploads;
  final RequestStatus status;
  final String? shippingQrCode;
  final String? shippingCarrier;
  final String? shippingService;
  final String? shippingLabelId;
  final String? trackingNumber;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final bool isDirectRequest;
  final int? estimatedShipDays;

  const ClientRequest({
    required this.id,
    required this.clientName,
    required this.title,
    required this.subtitle,
    required this.neededBy,
    required this.budgetMin,
    required this.budgetMax,
    required this.leftHand,
    required this.rightHand,
    required this.nailShape,
    required this.nailLength,
    required this.bio,
    required this.images,
    this.artistUploads = const <String>[],
    required this.status,
    this.shippingQrCode,
    this.shippingCarrier,
    this.shippingService,
    this.shippingLabelId,
    this.trackingNumber,
    this.shippedAt,
    this.deliveredAt,
    this.isDirectRequest = false,
    this.estimatedShipDays,
  });

  ClientRequest copyWith({
    RequestStatus? status,
    List<String>? artistUploads,
    String? shippingQrCode,
    String? shippingCarrier,
    String? shippingService,
    String? shippingLabelId,
    String? trackingNumber,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    bool? isDirectRequest,
    int? estimatedShipDays,
  }) {
    return ClientRequest(
      id: id,
      clientName: clientName,
      title: title,
      subtitle: subtitle,
      neededBy: neededBy,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      leftHand: leftHand,
      rightHand: rightHand,
      nailShape: nailShape,
      nailLength: nailLength,
      bio: bio,
      images: images,
      artistUploads: artistUploads ?? this.artistUploads,
      status: status ?? this.status,
      shippingQrCode: shippingQrCode ?? this.shippingQrCode,
      shippingCarrier: shippingCarrier ?? this.shippingCarrier,
      shippingService: shippingService ?? this.shippingService,
      shippingLabelId: shippingLabelId ?? this.shippingLabelId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      isDirectRequest: isDirectRequest ?? this.isDirectRequest,
      estimatedShipDays: estimatedShipDays ?? this.estimatedShipDays,
    );
  }
}
