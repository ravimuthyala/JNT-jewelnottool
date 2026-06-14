// lib/models/client_profile_models.dart

enum PaymentMethod { applePay, venmo, paypal, card }

class PaymentInfo {
  final PaymentMethod method;
  final bool saveForFuture;

  final String cardNumber;
  final String nameOnCard;
  final String expiryMMYY;
  final String cvv;
  final String zip;

  final String venmoHandle;
  final String paypalEmail;

  const PaymentInfo({
    required this.method,
    required this.saveForFuture,
    this.cardNumber = '',
    this.nameOnCard = '',
    this.expiryMMYY = '',
    this.cvv = '',
    this.zip = '',
    this.venmoHandle = '',
    this.paypalEmail = '',
  });

  PaymentInfo copyWith({
    PaymentMethod? method,
    bool? saveForFuture,
    String? cardNumber,
    String? nameOnCard,
    String? expiryMMYY,
    String? cvv,
    String? zip,
    String? venmoHandle,
    String? paypalEmail,
  }) {
    return PaymentInfo(
      method: method ?? this.method,
      saveForFuture: saveForFuture ?? this.saveForFuture,
      cardNumber: cardNumber ?? this.cardNumber,
      nameOnCard: nameOnCard ?? this.nameOnCard,
      expiryMMYY: expiryMMYY ?? this.expiryMMYY,
      cvv: cvv ?? this.cvv,
      zip: zip ?? this.zip,
      venmoHandle: venmoHandle ?? this.venmoHandle,
      paypalEmail: paypalEmail ?? this.paypalEmail,
    );
  }

  // ✅ now exists
  bool get isComplete => true;

  String get methodLabel {
    switch (method) {
      case PaymentMethod.applePay:
        return 'Apple Pay';
      case PaymentMethod.venmo:
        return 'Venmo';
      case PaymentMethod.paypal:
        return 'PayPal';
      case PaymentMethod.card:
        return 'Credit/Debit Card';
    }
  }
}

class AddressInfo {
  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;

  const AddressInfo({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  bool get isComplete =>
      street.isNotEmpty &&
      city.isNotEmpty &&
      state.isNotEmpty &&
      zip.isNotEmpty &&
      country.isNotEmpty;
}

enum NailLength { none, short, medium, long, extraLong, xlLong }

class NailDimensions {
  final double? lThumb, lIndex, lMiddle, lRing, lPinky;
  final double? rThumb, rIndex, rMiddle, rRing, rPinky;
  final bool lThumbNfc, lIndexNfc, lMiddleNfc, lRingNfc, lPinkyNfc;
  final bool rThumbNfc, rIndexNfc, rMiddleNfc, rRingNfc, rPinkyNfc;

  const NailDimensions({
    this.lThumb,
    this.lIndex,
    this.lMiddle,
    this.lRing,
    this.lPinky,
    this.rThumb,
    this.rIndex,
    this.rMiddle,
    this.rRing,
    this.rPinky,
    this.lThumbNfc = false,
    this.lIndexNfc = false,
    this.lMiddleNfc = false,
    this.lRingNfc = false,
    this.lPinkyNfc = false,
    this.rThumbNfc = false,
    this.rIndexNfc = false,
    this.rMiddleNfc = false,
    this.rRingNfc = false,
    this.rPinkyNfc = false,
  });

  int get filledCount => [
    lThumb,
    lIndex,
    lMiddle,
    lRing,
    lPinky,
    rThumb,
    rIndex,
    rMiddle,
    rRing,
    rPinky,
  ].where((v) => v != null).length;

  bool get isComplete => filledCount == 10;

  static NailDimensions empty() => const NailDimensions();
}

class ClientProfileDraft {
  final BasicInfo basic;
  final AddressInfo address;
  final PaymentInfo payment;
  final NailPreferences nail;

  const ClientProfileDraft({
    required this.basic,
    required this.address,
    required this.payment,
    required this.nail,
  });

  ClientProfileDraft copyWith({
    BasicInfo? basic,
    AddressInfo? address,
    PaymentInfo? payment,
    NailPreferences? nail,
  }) {
    return ClientProfileDraft(
      basic: basic ?? this.basic,
      address: address ?? this.address,
      payment: payment ?? this.payment,
      nail: nail ?? this.nail,
    );
  }

  bool get isComplete =>
      basic.isComplete &&
      address.isComplete &&
      payment.isComplete &&
      nail.isComplete;

  static ClientProfileDraft mock() {
    return ClientProfileDraft(
      basic: const BasicInfo(
        name: 'Alex',
        email: 'alex@mail.com',
        phone: '1234567890',
      ),
      address: const AddressInfo(
        street: '101 Main St',
        city: 'Dallas',
        state: 'Texas',
        zip: '75001',
        country: 'United States',
      ),
      payment: const PaymentInfo(
        method: PaymentMethod.applePay,
        saveForFuture: true,
      ),
      nail: NailPreferences.empty(),
    );
  }
}

const List<String> nailShapes = [
  'Square',
  'Round',
  'Oval',
  'Almond',
  'Stiletto',
  'Coffin',
];

/// -------------------------------------------
/// Models (single source of truth)
/// -------------------------------------------

class BasicInfo {
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;

  const BasicInfo({
    required this.name,
    required this.email,
    required this.phone,
    this.profileImageUrl = '',
  });

  BasicInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
  }) {
    return BasicInfo(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  bool get isComplete =>
      name.isNotEmpty && email.isNotEmpty && phone.isNotEmpty;
}

/// ✅ Add NONE so your checks compile.

class NailPreferences {
  final NailDimensions dimensions;
  final String shape;
  final NailLength length;

  const NailPreferences({
    required this.dimensions,
    required this.shape,
    required this.length,
  });

  bool get isComplete =>
      dimensions.isComplete && shape.isNotEmpty && length != NailLength.none;

  static NailPreferences empty() => NailPreferences(
    dimensions: NailDimensions.empty(),
    shape: '',
    length: NailLength.none,
  );
}
