import 'package:flutter/foundation.dart';

enum RequestStatusV2 {
  inReview('In Review'),
  accepted('Accepted'),
  designing('Designing'),
  completed('Completed'),
  shipped('Shipped'),
  delivered('Delivered'),
  declined('Declined'),
  cancelled('Cancelled'),
  expired('Expired');

  const RequestStatusV2(this.label);
  final String label;
}

enum RequestOrderTypeV2 { single, group }

@immutable
class NailDimensionsV2 {
  final String thumb;
  final String index;
  final String middle;
  final String ring;
  final String pinky;

  const NailDimensionsV2({
    required this.thumb,
    required this.index,
    required this.middle,
    required this.ring,
    required this.pinky,
  });
}

@immutable
class GroupOrderClientV2 {
  final int slotIndex;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String nailShape;
  final String nailLength;
  final NailDimensionsV2 leftHand;
  final NailDimensionsV2 rightHand;

  const GroupOrderClientV2({
    required this.slotIndex,
    required this.clientId,
    this.clientName = '',
    this.clientEmail = '',
    this.nailShape = '',
    this.nailLength = '',
    required this.leftHand,
    required this.rightHand,
  });
}

@immutable
class ClientRequestV2 {
  final String id;
  final String sourceCollection;
  final String orderNumber;
  final String clientEmail;
  final String clientName;
  final String title;
  final String subtitle;
  final DateTime neededBy;
  final DateTime? submittedAt;
  final int budgetMin;
  final int budgetMax;
  final int? clientBudgetMin;
  final int? clientBudgetMax;
  final int? artistBudgetMin;
  final int? artistBudgetMax;
  final double? artistFinalAmount;

  final bool isDirectRequest;
  final bool fallbackToPool;
  final bool openToClientPool;
  final bool allowNonLicensed;
  final RequestOrderTypeV2 orderType;
  final String selectedArtist;
  final String selectedArtistEmail;
  final String selectedClient;
  final String selectedClientEmail;
  final List<String> selectedGroupClientEmails;
  final bool hasInspo;
  final bool nfcRequested;

  final RequestStatusV2 status;

  final String clientLocation;
  final String previewImageAsset;
  final String clientProfileImage;
  final String brandName;
  final String acceptedClientName;
  final String acceptedClientProfileImage;

  final String bio;
  final String nailShape;
  final String nailLength;
  final NailDimensionsV2 leftHand;
  final NailDimensionsV2 rightHand;
  final List<String> clientImages;
  final List<GroupOrderClientV2> groupClients;
  final String paymentStatus;
  final String paymentLink;
  final String acceptedByArtistEmail;
  final String acceptedByClientEmail;
  final String clientResponseStatus;
  final List<String> acceptedGroupClientEmails;
  final List<String> declinedByClientEmails;
  final bool groupClientsAllResponded;
  final List<String> declinedByArtistEmails;
  final String completionReviewStatus;
  final String completionDeclineReason;
  final String completionDeclineDescription;
  final String cancelReason;
  final String declineReason;
  final DateTime? completionDeclinedAt;
  final String designApprovalStatus;
  final DateTime? designSubmittedAt;
  final DateTime? designApprovalDueAt;
  final DateTime? designReminderSentAt;
  final List<String> designPreviewPhotos;
  final bool shippingLabelReady;
  final String shippingLabelPdfUrl;
  final String shippingLabelQrData;
  final String shippingLabelCarrier;
  final String shippingLabelTrackingNumber;
  final DateTime? shippingLabelCreatedAt;
  final bool shippingRequired;
  final String shippingStatus;
  final String shippingQrCode;
  final Map<String, dynamic> shippingQrPayload;
  final bool shippingAddressDifferentFromProfile;
  final String shippingStreet;
  final String shippingCity;
  final String shippingState;
  final String shippingZip;
  final String shippingCountry;
  final String shippingLabelUrl;
  final DateTime? shippingCreatedAt;
  final DateTime? shippingLastUpdatedAt;
  final DateTime? shippingRegeneratedAt;
  final String shippingRegeneratedBy;

  final String? shippedByCourier; // e.g. "USPS", "UPS"
  final String? trackingNumber;
  final DateTime? shippedAt;
  final List<String> artistImages; // assets/urls
  final DateTime? deliveredAt;
  final double? clientRating;
  final String clientReviewText;
  final DateTime? clientReviewSubmittedAt;

  const ClientRequestV2({
    required this.id,
    this.sourceCollection = 'Client_Custom_Requests',
    this.orderNumber = '',
    this.clientEmail = '',
    required this.clientName,
    required this.title,
    required this.subtitle,
    required this.neededBy,
    this.submittedAt,
    required this.budgetMin,
    required this.budgetMax,
    this.clientBudgetMin,
    this.clientBudgetMax,
    this.artistBudgetMin,
    this.artistBudgetMax,
    this.artistFinalAmount,
    required this.status,
    required this.isDirectRequest,
    this.fallbackToPool = true,
    this.openToClientPool = true,
    this.allowNonLicensed = true,
    this.orderType = RequestOrderTypeV2.single,
    this.selectedArtist = '',
    this.selectedArtistEmail = '',
    this.selectedClient = '',
    this.selectedClientEmail = '',
    this.selectedGroupClientEmails = const [],
    required this.hasInspo,
    this.nfcRequested = false,
    required this.clientLocation,
    required this.previewImageAsset,
    this.clientProfileImage = '',
    this.brandName = '',
    this.acceptedClientName = '',
    this.acceptedClientProfileImage = '',
    required this.bio,
    required this.nailShape,
    required this.nailLength,
    required this.leftHand,
    required this.rightHand,
    this.clientImages = const [],
    this.groupClients = const [],
    this.paymentStatus = '',
    this.paymentLink = '',
    this.acceptedByArtistEmail = '',
    this.acceptedByClientEmail = '',
    this.clientResponseStatus = '',
    this.acceptedGroupClientEmails = const [],
    this.declinedByClientEmails = const [],
    this.groupClientsAllResponded = false,
    this.declinedByArtistEmails = const [],
    this.completionReviewStatus = '',
    this.completionDeclineReason = '',
    this.completionDeclineDescription = '',
    this.cancelReason = '',
    this.declineReason = '',
    this.completionDeclinedAt,
    this.designApprovalStatus = '',
    this.designSubmittedAt,
    this.designApprovalDueAt,
    this.designReminderSentAt,
    this.designPreviewPhotos = const [],
    this.shippingLabelReady = false,
    this.shippingLabelPdfUrl = '',
    this.shippingLabelQrData = '',
    this.shippingLabelCarrier = '',
    this.shippingLabelTrackingNumber = '',
    this.shippingLabelCreatedAt,
    this.shippingRequired = false,
    this.shippingStatus = '',
    this.shippingQrCode = '',
    this.shippingQrPayload = const <String, dynamic>{},
    this.shippingAddressDifferentFromProfile = false,
    this.shippingStreet = '',
    this.shippingCity = '',
    this.shippingState = '',
    this.shippingZip = '',
    this.shippingCountry = '',
    this.shippingLabelUrl = '',
    this.shippingCreatedAt,
    this.shippingLastUpdatedAt,
    this.shippingRegeneratedAt,
    this.shippingRegeneratedBy = '',
    this.shippedByCourier,
    this.trackingNumber,
    this.shippedAt,
    this.artistImages = const [],
    this.deliveredAt,
    this.clientRating,
    this.clientReviewText = '',
    this.clientReviewSubmittedAt,
  });

  ClientRequestV2 copyWith({
    RequestStatusV2? status,
    int? budgetMin,
    int? budgetMax,
    int? clientBudgetMin,
    int? clientBudgetMax,
    int? artistBudgetMin,
    int? artistBudgetMax,
    double? artistFinalAmount,
    RequestOrderTypeV2? orderType,
    bool? fallbackToPool,
    bool? openToClientPool,
    bool? allowNonLicensed,
    String? selectedArtist,
    String? selectedArtistEmail,
    String? selectedClient,
    String? selectedClientEmail,
    List<String>? selectedGroupClientEmails,
    bool? nfcRequested,
    String? sourceCollection,
    String? orderNumber,
    String? clientEmail,
    String? clientProfileImage,
    String? brandName,
    String? acceptedClientName,
    String? acceptedClientProfileImage,
    String? bio,
    String? paymentStatus,
    String? paymentLink,
    String? acceptedByArtistEmail,
    String? acceptedByClientEmail,
    String? clientResponseStatus,
    List<String>? acceptedGroupClientEmails,
    List<String>? declinedByClientEmails,
    bool? groupClientsAllResponded,
    List<String>? declinedByArtistEmails,
    String? completionReviewStatus,
    String? completionDeclineReason,
    String? completionDeclineDescription,
    String? cancelReason,
    String? declineReason,
    DateTime? completionDeclinedAt,
    String? designApprovalStatus,
    DateTime? designSubmittedAt,
    DateTime? designApprovalDueAt,
    DateTime? designReminderSentAt,
    List<String>? designPreviewPhotos,
    bool? shippingLabelReady,
    String? shippingLabelPdfUrl,
    String? shippingLabelQrData,
    String? shippingLabelCarrier,
    String? shippingLabelTrackingNumber,
    DateTime? shippingLabelCreatedAt,
    bool? shippingRequired,
    String? shippingStatus,
    String? shippingQrCode,
    Map<String, dynamic>? shippingQrPayload,
    bool? shippingAddressDifferentFromProfile,
    String? shippingStreet,
    String? shippingCity,
    String? shippingState,
    String? shippingZip,
    String? shippingCountry,
    String? shippingLabelUrl,
    DateTime? shippingCreatedAt,
    DateTime? shippingLastUpdatedAt,
    DateTime? shippingRegeneratedAt,
    String? shippingRegeneratedBy,
    List<String>? artistImages,
    List<String>? clientImages,
    List<GroupOrderClientV2>? groupClients,
    String? shippedByCourier,
    String? trackingNumber,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? submittedAt,
    double? clientRating,
    String? clientReviewText,
    DateTime? clientReviewSubmittedAt,
  }) {
    return ClientRequestV2(
      id: id,
      sourceCollection: sourceCollection ?? this.sourceCollection,
      orderNumber: orderNumber ?? this.orderNumber,
      clientEmail: clientEmail ?? this.clientEmail,
      clientName: clientName,
      title: title,
      subtitle: subtitle,
      neededBy: neededBy,
      submittedAt: submittedAt ?? this.submittedAt,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      clientBudgetMin: clientBudgetMin ?? this.clientBudgetMin,
      clientBudgetMax: clientBudgetMax ?? this.clientBudgetMax,
      artistBudgetMin: artistBudgetMin ?? this.artistBudgetMin,
      artistBudgetMax: artistBudgetMax ?? this.artistBudgetMax,
      artistFinalAmount: artistFinalAmount ?? this.artistFinalAmount,
      status: status ?? this.status,
      isDirectRequest: isDirectRequest,
      fallbackToPool: fallbackToPool ?? this.fallbackToPool,
      openToClientPool: openToClientPool ?? this.openToClientPool,
      allowNonLicensed: allowNonLicensed ?? this.allowNonLicensed,
      orderType: orderType ?? this.orderType,
      selectedArtist: selectedArtist ?? this.selectedArtist,
      selectedArtistEmail: selectedArtistEmail ?? this.selectedArtistEmail,
      selectedClient: selectedClient ?? this.selectedClient,
      selectedClientEmail: selectedClientEmail ?? this.selectedClientEmail,
      selectedGroupClientEmails:
          selectedGroupClientEmails ?? this.selectedGroupClientEmails,
      hasInspo: hasInspo,
      nfcRequested: nfcRequested ?? this.nfcRequested,
      clientLocation: clientLocation,
      previewImageAsset: previewImageAsset,
      clientProfileImage: clientProfileImage ?? this.clientProfileImage,
      brandName: brandName ?? this.brandName,
      acceptedClientName: acceptedClientName ?? this.acceptedClientName,
      acceptedClientProfileImage:
          acceptedClientProfileImage ?? this.acceptedClientProfileImage,
      bio: bio ?? this.bio,
      nailShape: nailShape,
      nailLength: nailLength,
      leftHand: leftHand,
      rightHand: rightHand,
      clientImages: clientImages ?? this.clientImages,
      groupClients: groupClients ?? this.groupClients,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentLink: paymentLink ?? this.paymentLink,
      acceptedByArtistEmail:
          acceptedByArtistEmail ?? this.acceptedByArtistEmail,
      acceptedByClientEmail:
          acceptedByClientEmail ?? this.acceptedByClientEmail,
      clientResponseStatus: clientResponseStatus ?? this.clientResponseStatus,
      acceptedGroupClientEmails:
          acceptedGroupClientEmails ?? this.acceptedGroupClientEmails,
      declinedByClientEmails:
          declinedByClientEmails ?? this.declinedByClientEmails,
      groupClientsAllResponded:
          groupClientsAllResponded ?? this.groupClientsAllResponded,
      declinedByArtistEmails:
          declinedByArtistEmails ?? this.declinedByArtistEmails,
      completionReviewStatus:
          completionReviewStatus ?? this.completionReviewStatus,
      completionDeclineReason:
          completionDeclineReason ?? this.completionDeclineReason,
      completionDeclineDescription:
          completionDeclineDescription ?? this.completionDeclineDescription,
      cancelReason: cancelReason ?? this.cancelReason,
      declineReason: declineReason ?? this.declineReason,
      completionDeclinedAt: completionDeclinedAt ?? this.completionDeclinedAt,
      designApprovalStatus: designApprovalStatus ?? this.designApprovalStatus,
      designSubmittedAt: designSubmittedAt ?? this.designSubmittedAt,
      designApprovalDueAt: designApprovalDueAt ?? this.designApprovalDueAt,
      designReminderSentAt: designReminderSentAt ?? this.designReminderSentAt,
      designPreviewPhotos: designPreviewPhotos ?? this.designPreviewPhotos,
      shippingLabelReady: shippingLabelReady ?? this.shippingLabelReady,
      shippingLabelPdfUrl: shippingLabelPdfUrl ?? this.shippingLabelPdfUrl,
      shippingLabelQrData: shippingLabelQrData ?? this.shippingLabelQrData,
      shippingLabelCarrier: shippingLabelCarrier ?? this.shippingLabelCarrier,
      shippingLabelTrackingNumber:
          shippingLabelTrackingNumber ?? this.shippingLabelTrackingNumber,
      shippingLabelCreatedAt:
          shippingLabelCreatedAt ?? this.shippingLabelCreatedAt,
      shippingRequired: shippingRequired ?? this.shippingRequired,
      shippingStatus: shippingStatus ?? this.shippingStatus,
      shippingQrCode: shippingQrCode ?? this.shippingQrCode,
      shippingQrPayload: shippingQrPayload ?? this.shippingQrPayload,
      shippingAddressDifferentFromProfile:
          shippingAddressDifferentFromProfile ??
          this.shippingAddressDifferentFromProfile,
      shippingStreet: shippingStreet ?? this.shippingStreet,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingState: shippingState ?? this.shippingState,
      shippingZip: shippingZip ?? this.shippingZip,
      shippingCountry: shippingCountry ?? this.shippingCountry,
      shippingLabelUrl: shippingLabelUrl ?? this.shippingLabelUrl,
      shippingCreatedAt: shippingCreatedAt ?? this.shippingCreatedAt,
      shippingLastUpdatedAt:
          shippingLastUpdatedAt ?? this.shippingLastUpdatedAt,
      shippingRegeneratedAt:
          shippingRegeneratedAt ?? this.shippingRegeneratedAt,
      shippingRegeneratedBy:
          shippingRegeneratedBy ?? this.shippingRegeneratedBy,
      artistImages: artistImages ?? this.artistImages,

      shippedByCourier: shippedByCourier ?? this.shippedByCourier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      clientRating: clientRating ?? this.clientRating,
      clientReviewText: clientReviewText ?? this.clientReviewText,
      clientReviewSubmittedAt:
          clientReviewSubmittedAt ?? this.clientReviewSubmittedAt,
    );
  }
}
