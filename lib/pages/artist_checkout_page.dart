import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';

ThemeData _checkoutFormTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.snow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCatBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCat, width: 1.4),
      ),
      labelStyle: TextStyle(color: AppColors.blackCatLight, fontSize: 12),
    ),
  );
}

class ArtistCheckoutInfo {
  ArtistCheckoutInfo({
    required this.artistName,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.timeZone,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.zip,
    required this.country,
    required this.isShippingAddressSame,
    this.shippingAddressLine1 = '',
    this.shippingAddressLine2 = '',
    this.shippingCity = '',
    this.shippingState = '',
    this.shippingZip = '',
    required this.shippingCountry,
    this.shippingTimeZone = '',
    required this.paymentMethod,
    required this.paymentDetail,
    required this.productTitle,
    required this.productSubtitle,
    required this.productPriceText,
    required this.productImageAsset,
  });

  // Artist
  String artistName;
  String email;
  String phone;

  // Address (for shipping bundle)
  String city;
  String state;
  String timeZone;
  String addressLine1;
  String addressLine2;
  String zip;
  String country;
  bool isShippingAddressSame;
  String shippingAddressLine1;
  String shippingAddressLine2;
  String shippingCity;
  String shippingState;
  String shippingZip;
  String shippingCountry;
  String shippingTimeZone;

  // Payment
  String paymentMethod; // PayPal / Venmo / Apple Pay / Credit Card
  String paymentDetail; // e.g. paypal email, card last4, etc.

  // Product
  String productTitle;
  String productSubtitle;
  String productPriceText;
  String productImageAsset;

  ArtistCheckoutInfo copyWith({
    String? artistName,
    String? email,
    String? phone,
    String? city,
    String? state,
    String? timeZone,
    String? addressLine1,
    String? addressLine2,
    String? zip,
    String? country,
    bool? isShippingAddressSame,
    String? shippingAddressLine1,
    String? shippingAddressLine2,
    String? shippingCity,
    String? shippingState,
    String? shippingZip,
    String? shippingCountry,
    String? shippingTimeZone,
    String? paymentMethod,
    String? paymentDetail,
    String? productTitle,
    String? productSubtitle,
    String? productPriceText,
    String? productImageAsset,
  }) {
    return ArtistCheckoutInfo(
      artistName: artistName ?? this.artistName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      state: state ?? this.state,
      timeZone: timeZone ?? this.timeZone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      zip: zip ?? this.zip,
      country: country ?? this.country,
      isShippingAddressSame:
          isShippingAddressSame ?? this.isShippingAddressSame,
      shippingAddressLine1: shippingAddressLine1 ?? this.shippingAddressLine1,
      shippingAddressLine2: shippingAddressLine2 ?? this.shippingAddressLine2,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingState: shippingState ?? this.shippingState,
      shippingZip: shippingZip ?? this.shippingZip,
      shippingCountry: shippingCountry ?? this.shippingCountry,
      shippingTimeZone: shippingTimeZone ?? this.shippingTimeZone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDetail: paymentDetail ?? this.paymentDetail,
      productTitle: productTitle ?? this.productTitle,
      productSubtitle: productSubtitle ?? this.productSubtitle,
      productPriceText: productPriceText ?? this.productPriceText,
      productImageAsset: productImageAsset ?? this.productImageAsset,
    );
  }
}

class ArtistCheckoutPage extends StatefulWidget {
  const ArtistCheckoutPage({super.key, required this.initial});

  final ArtistCheckoutInfo initial;

  @override
  State<ArtistCheckoutPage> createState() => _ArtistCheckoutPageState();
}

class _ArtistCheckoutPageState extends State<ArtistCheckoutPage> {
  static const Color _checkoutBg = AppColors.alabaster;
  static const Color _checkoutSection = AppColors.snow;
  late ArtistCheckoutInfo _info;
  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.blackCat,
  );
  static const TextStyle _valueStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.blackCat,
  );

  @override
  void initState() {
    super.initState();
    _info = widget.initial;
  }

  Future<void> _editArtistInfo() async {
    final updated = await Navigator.push<ArtistCheckoutInfo?>(
      context,
      MaterialPageRoute(builder: (_) => _EditArtistInfoPage(initial: _info)),
    );
    if (!mounted) return;
    if (updated != null) setState(() => _info = updated);
  }

  Future<void> _editAddressInfo() async {
    final updated = await Navigator.push<ArtistCheckoutInfo?>(
      context,
      MaterialPageRoute(builder: (_) => _EditAddressInfoPage(initial: _info)),
    );
    if (!mounted) return;
    if (updated != null) setState(() => _info = updated);
  }

  Future<void> _editPaymentInfo() async {
    final updated = await Navigator.push<ArtistCheckoutInfo?>(
      context,
      MaterialPageRoute(builder: (_) => _EditPaymentInfoPage(initial: _info)),
    );
    if (!mounted) return;
    if (updated != null) setState(() => _info = updated);
  }

  void _completePurchase() {
    Navigator.pop(context, true);
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _checkoutSection,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCatBorderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionTitleStyle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _rowLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.blackCatLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(v, style: _valueStyle)),
        ],
      ),
    );
  }

  Widget _shippingField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        onChanged: (value) => setState(() => onChanged(value)),
        style: _valueStyle,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _editLink(VoidCallback onTap) {
    return Semantics(
      button: true,
      child: ExcludeSemantics(
      child: InkWell(
      onTap: onTap,
      child: const Text(
        'Edit',
        style: TextStyle(
          color: AppColors.blackCat,
          fontWeight: FontWeight.w700,
        ),
      ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Artist checkout',
      child: Scaffold(
      backgroundColor: _checkoutBg,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Theme(
        data: _checkoutFormTheme(context),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            _card(
              title: 'Artist Profile',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Container()),
                      _editLink(_editArtistInfo),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _rowLine('Name', _info.artistName),
                  _rowLine('Email', _info.email),
                  _rowLine('Phone', _info.phone),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _card(
              title: 'Address Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Container()),
                      _editLink(_editAddressInfo),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _rowLine('Address Line 1', _info.addressLine1),
                  _rowLine(
                    'Address Line 2',
                    _info.addressLine2.trim().isEmpty
                        ? '—'
                        : _info.addressLine2,
                  ),
                  _rowLine('City', _info.city),
                  _rowLine('State', _info.state),
                  _rowLine('ZIP', _info.zip),
                  _rowLine('Country', _info.country),
                  _rowLine('Time Zone', _info.timeZone),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Checkbox(
                        value: _info.isShippingAddressSame,
                        activeColor: AppColors.blackCat,
                        onChanged: (v) {
                          final isSame = v ?? true;
                          setState(() {
                            _info = _info.copyWith(
                              isShippingAddressSame: isSame,
                              shippingAddressLine1: isSame
                                  ? _info.addressLine1
                                  : '',
                              shippingAddressLine2: isSame
                                  ? _info.addressLine2
                                  : '',
                              shippingCity: isSame ? _info.city : '',
                              shippingState: isSame ? _info.state : '',
                              shippingZip: isSame ? _info.zip : '',
                              shippingCountry: isSame ? _info.country : '',
                              shippingTimeZone: isSame ? _info.timeZone : '',
                            );
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Is shipping address same as above address',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_info.isShippingAddressSame) ...[
                    const SizedBox(height: 6),
                    _shippingField(
                      label: 'Ship Address 1',
                      initialValue: _info.shippingAddressLine1,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingAddressLine1: value),
                    ),
                    _rowLine(
                      'Ship Address 2',
                      _info.shippingAddressLine2.trim().isEmpty
                          ? '—'
                          : _info.shippingAddressLine2,
                    ),
                    _shippingField(
                      label: 'Ship City',
                      initialValue: _info.shippingCity,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingCity: value),
                    ),
                    _shippingField(
                      label: 'Ship State',
                      initialValue: _info.shippingState,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingState: value),
                    ),
                    _shippingField(
                      label: 'Ship ZIP',
                      initialValue: _info.shippingZip,
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingZip: value),
                    ),
                    _shippingField(
                      label: 'Ship Country',
                      initialValue: _info.shippingCountry,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingCountry: value),
                    ),
                    _shippingField(
                      label: 'Ship Time Zone',
                      initialValue: _info.shippingTimeZone,
                      onChanged: (value) =>
                          _info = _info.copyWith(shippingTimeZone: value),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _card(
              title: 'Payment Information',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Container()),
                      _editLink(_editPaymentInfo),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _rowLine('Method', _info.paymentMethod),
                  _rowLine(
                    'Details',
                    _info.paymentDetail.isEmpty ? '—' : _info.paymentDetail,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _card(
              title: 'Product',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _info.productTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _info.productSubtitle,
                    style: TextStyle(
                      color: AppColors.blackCat.withValues(alpha: 0.65),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _info.productPriceText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _completePurchase,
                child: const Text(
                  'Complete Purchase',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// --------------------
/// Edit Pages (simple)
/// --------------------

class _EditArtistInfoPage extends StatefulWidget {
  const _EditArtistInfoPage({required this.initial});
  final ArtistCheckoutInfo initial;

  @override
  State<_EditArtistInfoPage> createState() => _EditArtistInfoPageState();
}

class _EditArtistInfoPageState extends State<_EditArtistInfoPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.artistName);
    _email = TextEditingController(text: widget.initial.email);
    _phone = TextEditingController(
      text: RegistrationInputUtils.formatUsPhoneLocal(widget.initial.phone),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: const Text(
          'Edit Artist Info',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Theme(
        data: _checkoutFormTheme(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
                UsPhoneTextInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone',
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      artistName: _name.text.trim(),
                      email: _email.text.trim(),
                      phone: _phone.text.trim(),
                    ),
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditAddressInfoPage extends StatefulWidget {
  const _EditAddressInfoPage({required this.initial});
  final ArtistCheckoutInfo initial;

  @override
  State<_EditAddressInfoPage> createState() => _EditAddressInfoPageState();
}

class _EditAddressInfoPageState extends State<_EditAddressInfoPage> {
  late final TextEditingController _addr;
  late final TextEditingController _addr2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _country;
  late final TextEditingController _tz;
  late final TextEditingController _shipAddr;
  late final TextEditingController _shipAddr2;
  late final TextEditingController _shipCity;
  late final TextEditingController _shipState;
  late final TextEditingController _shipZip;
  late final TextEditingController _shipCountry;
  late final TextEditingController _shipTz;
  late bool _isShippingSame;

  @override
  void initState() {
    super.initState();
    _addr = TextEditingController(text: widget.initial.addressLine1);
    _addr2 = TextEditingController(text: widget.initial.addressLine2);
    _city = TextEditingController(text: widget.initial.city);
    _state = TextEditingController(text: widget.initial.state);
    _zip = TextEditingController(text: widget.initial.zip);
    _country = TextEditingController(text: widget.initial.country);
    _tz = TextEditingController(text: widget.initial.timeZone);
    _isShippingSame = widget.initial.isShippingAddressSame;
    _shipAddr = TextEditingController(
      text: widget.initial.shippingAddressLine1,
    );
    _shipAddr2 = TextEditingController(
      text: widget.initial.shippingAddressLine2,
    );
    _shipCity = TextEditingController(text: widget.initial.shippingCity);
    _shipState = TextEditingController(text: widget.initial.shippingState);
    _shipZip = TextEditingController(text: widget.initial.shippingZip);
    _shipCountry = TextEditingController(text: widget.initial.shippingCountry);
    _shipTz = TextEditingController(text: widget.initial.shippingTimeZone);
  }

  @override
  void dispose() {
    _addr.dispose();
    _addr2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _country.dispose();
    _tz.dispose();
    _shipAddr.dispose();
    _shipAddr2.dispose();
    _shipCity.dispose();
    _shipState.dispose();
    _shipZip.dispose();
    _shipCountry.dispose();
    _shipTz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: const Text(
          'Edit Address',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Theme(
        data: _checkoutFormTheme(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _addr,
              decoration: const InputDecoration(
                labelText: 'Address Line 1',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addr2,
              decoration: const InputDecoration(
                labelText: 'Address Line 2',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _state,
              decoration: const InputDecoration(
                labelText: 'State',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zip,
              decoration: const InputDecoration(labelText: 'ZIP', filled: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _country,
              decoration: const InputDecoration(
                labelText: 'Country',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tz,
              decoration: const InputDecoration(
                labelText: 'Time Zone',
                filled: true,
              ),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isShippingSame,
              activeColor: AppColors.blackCat,
              title: const Text(
                'Is shipping address same as above address',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              onChanged: (v) => setState(() => _isShippingSame = v ?? true),
            ),
            if (!_isShippingSame) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _shipAddr,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address Line 1',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipAddr2,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address Line 2',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipCity,
                decoration: const InputDecoration(
                  labelText: 'Shipping City',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipState,
                decoration: const InputDecoration(
                  labelText: 'Shipping State',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipZip,
                decoration: const InputDecoration(
                  labelText: 'Shipping ZIP',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipCountry,
                decoration: const InputDecoration(
                  labelText: 'Shipping Country',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _shipTz,
                decoration: const InputDecoration(
                  labelText: 'Shipping Time Zone',
                  filled: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      addressLine1: _addr.text.trim(),
                      addressLine2: _addr2.text.trim(),
                      city: _city.text.trim(),
                      state: _state.text.trim(),
                      zip: _zip.text.trim(),
                      country: _country.text.trim(),
                      timeZone: _tz.text.trim(),
                      isShippingAddressSame: _isShippingSame,
                      shippingAddressLine1: _isShippingSame
                          ? _addr.text.trim()
                          : _shipAddr.text.trim(),
                      shippingAddressLine2: _isShippingSame
                          ? _addr2.text.trim()
                          : _shipAddr2.text.trim(),
                      shippingCity: _isShippingSame
                          ? _city.text.trim()
                          : _shipCity.text.trim(),
                      shippingState: _isShippingSame
                          ? _state.text.trim()
                          : _shipState.text.trim(),
                      shippingZip: _isShippingSame
                          ? _zip.text.trim()
                          : _shipZip.text.trim(),
                      shippingCountry: _isShippingSame
                          ? _country.text.trim()
                          : _shipCountry.text.trim(),
                      shippingTimeZone: _isShippingSame
                          ? _tz.text.trim()
                          : _shipTz.text.trim(),
                    ),
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPaymentInfoPage extends StatefulWidget {
  const _EditPaymentInfoPage({required this.initial});
  final ArtistCheckoutInfo initial;

  @override
  State<_EditPaymentInfoPage> createState() => _EditPaymentInfoPageState();
}

class _EditPaymentInfoPageState extends State<_EditPaymentInfoPage> {
  late String _method;
  late final TextEditingController _detail;

  @override
  void initState() {
    super.initState();
    _method = widget.initial.paymentMethod;
    _detail = TextEditingController(text: widget.initial.paymentDetail);
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        title: const Text(
          'Edit Payment',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Theme(
        data: _checkoutFormTheme(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _method,
              dropdownColor: AppColors.snow,
              items: const [
                DropdownMenuItem(value: 'PayPal', child: Text('PayPal')),
                DropdownMenuItem(value: 'Venmo', child: Text('Venmo')),
                DropdownMenuItem(value: 'Apple Pay', child: Text('Apple Pay')),
                DropdownMenuItem(
                  value: 'Credit Card',
                  child: Text('Credit Card'),
                ),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'PayPal'),
              decoration: const InputDecoration(
                labelText: 'Method',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detail,
              decoration: const InputDecoration(
                labelText: 'Details (email / last4 / etc)',
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      paymentMethod: _method,
                      paymentDetail: _detail.text.trim(),
                    ),
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
