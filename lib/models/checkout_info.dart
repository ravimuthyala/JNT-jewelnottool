class CheckoutInfo {
  final String name;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;

  const CheckoutInfo({
    required this.name,
    required this.phone,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  String get addressLine =>
      '$street, $city, $state $zip, $country';
}
