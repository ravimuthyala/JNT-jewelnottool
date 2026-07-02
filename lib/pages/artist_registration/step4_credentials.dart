import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../artist_checkout_page.dart';
import 'registration_draft.dart';
import '_widgets/reg_helpers.dart';

// US phone formatter
class _UsPhoneFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) return newValue.copyWith(text: digits);
    if (digits.length <= 6) return newValue.copyWith(text: '(${digits.substring(0, 3)}) ${digits.substring(3)}');
    return newValue.copyWith(text: '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, digits.length.clamp(0, 10))}');
  }
}

// Card number formatter (groups of 4)
class _CardNumFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(0, newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 19));
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return newValue.copyWith(text: buf.toString());
  }
}

// MM/YY expiry formatter
class _ExpiryFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(0, newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 4));
    if (digits.length <= 2) return newValue.copyWith(text: digits);
    return newValue.copyWith(text: '${digits.substring(0, 2)}/${digits.substring(2)}');
  }
}

class Step4Credentials extends StatefulWidget {
  const Step4Credentials({
    super.key,
    required this.draft,
    this.showAdaCompliance = false,
  });

  final RegistrationDraft draft;
  final bool showAdaCompliance;

  @override
  State<Step4Credentials> createState() => Step4CredentialsState();
}

class Step4CredentialsState extends State<Step4Credentials> {
  final _formKey = GlobalKey<FormState>();

  // Credentials
  late NailTechType _nailTechType;
  late final TextEditingController _licenseCtrl;
  String? _jurisdiction;
  String? _proYearsExp;
  late final TextEditingController _schoolCtrl;
  String? _practiceDuration;

  // Payment
  late String _paymentMethod;
  late final TextEditingController _paypalEmailCtrl;
  late final TextEditingController _venmoHandleCtrl;
  late final TextEditingController _applePayPaymentNameCtrl;
  late final TextEditingController _applePayPaymentPhoneCtrl;
  late final TextEditingController _applePayPaymentEmailCtrl;
  late final TextEditingController _cardNameCtrl;
  late final TextEditingController _cardNumberCtrl;
  late final TextEditingController _cardExpiryCtrl;
  late final TextEditingController _cardCvvCtrl;
  late final TextEditingController _cardZipCtrl;
  late bool _paymentSaved;

  // Bundle
  late String _selectedBundle;
  late bool _bundlePurchased;

  // Payout
  late PayoutMethod _payoutMethod;
  late final TextEditingController _legalNameCtrl;
  late final TextEditingController _payoutEmailCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _routingCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _applePayNameCtrl;
  late final TextEditingController _applePayPhoneCtrl;
  late final TextEditingController _applePayEmailCtrl;

  // Agreements
  late bool _agreeTerms;
  late bool _noCopyright;
  late bool _agreeSafety;
  late bool _receiveUpdates;

  bool _isValidEmail(String v) => v.contains('@') && v.contains('.');

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nailTechType = d.nailTechType;
    _licenseCtrl = TextEditingController(text: d.licenseNumber);
    _jurisdiction = d.jurisdiction;
    _proYearsExp = d.proYearsExp;
    _schoolCtrl = TextEditingController(text: d.school);
    _practiceDuration = d.practiceDuration;

    _paymentMethod = d.paymentMethod.isEmpty ? 'PayPal' : d.paymentMethod;
    _paypalEmailCtrl = TextEditingController(text: d.paypalEmail);
    _venmoHandleCtrl = TextEditingController(text: d.venmoHandle);
    _applePayPaymentNameCtrl = TextEditingController(text: d.applePayPaymentName);
    _applePayPaymentPhoneCtrl = TextEditingController(text: d.applePayPaymentPhone);
    _applePayPaymentEmailCtrl = TextEditingController(text: d.applePayPaymentEmail);
    _cardNameCtrl = TextEditingController(text: d.cardName);
    _cardNumberCtrl = TextEditingController(text: d.cardNumber);
    _cardExpiryCtrl = TextEditingController(text: d.cardExpiry);
    _cardCvvCtrl = TextEditingController(text: d.cardCvv);
    _cardZipCtrl = TextEditingController(text: d.cardZip);
    _paymentSaved = d.paymentSaved;

    _selectedBundle = d.selectedBundle.isEmpty ? 'Starter' : d.selectedBundle;
    _bundlePurchased = d.bundlePurchased;

    _payoutMethod = d.payoutMethod;
    _legalNameCtrl = TextEditingController(text: d.legalName);
    _payoutEmailCtrl = TextEditingController(text: d.payoutEmail);
    _bankNameCtrl = TextEditingController(text: d.bankName);
    _routingCtrl = TextEditingController(text: d.routing);
    _accountNumberCtrl = TextEditingController(text: d.accountNumber);
    _applePayNameCtrl = TextEditingController(text: d.applePayName);
    _applePayPhoneCtrl = TextEditingController(text: d.applePayPhone);
    _applePayEmailCtrl = TextEditingController(text: d.applePayEmail);

    _agreeTerms = d.agreeTerms;
    _noCopyright = d.noCopyright;
    _agreeSafety = d.agreeSafety;
    _receiveUpdates = d.receiveUpdates;
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _schoolCtrl.dispose();
    _paypalEmailCtrl.dispose();
    _venmoHandleCtrl.dispose();
    _applePayPaymentNameCtrl.dispose();
    _applePayPaymentPhoneCtrl.dispose();
    _applePayPaymentEmailCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardZipCtrl.dispose();
    _legalNameCtrl.dispose();
    _payoutEmailCtrl.dispose();
    _bankNameCtrl.dispose();
    _routingCtrl.dispose();
    _accountNumberCtrl.dispose();
    _applePayNameCtrl.dispose();
    _applePayPhoneCtrl.dispose();
    _applePayEmailCtrl.dispose();
    super.dispose();
  }

  bool _paymentFieldsValid() {
    if (_paymentMethod == 'PayPal') return _isValidEmail(_paypalEmailCtrl.text.trim());
    if (_paymentMethod == 'Venmo') return _venmoHandleCtrl.text.trim().isNotEmpty;
    if (_paymentMethod == 'Apple Pay') {
      final phone = _applePayPaymentPhoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      return _applePayPaymentNameCtrl.text.trim().isNotEmpty && phone.length >= 10 && _isValidEmail(_applePayPaymentEmailCtrl.text.trim());
    }
    if (_paymentMethod == 'Credit Card') {
      final number = _cardNumberCtrl.text.trim().replaceAll(' ', '');
      final expiryOk = RegExp(r'^\d{2}\/\d{2}$').hasMatch(_cardExpiryCtrl.text.trim());
      final numberOk = RegExp(r'^\d+$').hasMatch(number) && number.length >= 13 && number.length <= 19;
      final cvv = _cardCvvCtrl.text.trim();
      final cvvOk = RegExp(r'^\d+$').hasMatch(cvv) && (cvv.length == 3 || cvv.length == 4);
      return _cardNameCtrl.text.trim().isNotEmpty && numberOk && expiryOk && cvvOk && _cardZipCtrl.text.trim().isNotEmpty;
    }
    return false;
  }

  void autofill() {
    setState(() {
      // Credentials
      _nailTechType = NailTechType.professional;
      _licenseCtrl.text = 'NL-CA-2024-78901';
      _jurisdiction = 'California';
      _proYearsExp = '3–5 years (Skilled)';

      // Payment — pre-fill PayPal and mark saved
      _paymentMethod = 'PayPal';
      _paypalEmailCtrl.text = 'luna.nails@paypal.com';
      _paymentSaved = true;

      // Bundle — mark purchased so account creation unlocks
      _selectedBundle = 'Starter';
      _bundlePurchased = true;

      // Payout
      _payoutMethod = PayoutMethod.paypal;
      _legalNameCtrl.text = 'Luna Johnson';
      _payoutEmailCtrl.text = 'luna.nails@paypal.com';

      // Agreements
      _agreeTerms = true;
      _noCopyright = true;
      _agreeSafety = true;
      _receiveUpdates = true;
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (!_paymentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save your payment method.')));
      return false;
    }
    if (!_bundlePurchased) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please purchase a nail material bundle.')));
      return false;
    }
    if (widget.showAdaCompliance && (!_agreeTerms || !_noCopyright || !_agreeSafety)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept all required agreements.')));
      return false;
    }

    draft.nailTechType = _nailTechType;
    draft.licenseNumber = _licenseCtrl.text.trim();
    draft.jurisdiction = _jurisdiction;
    draft.proYearsExp = _proYearsExp;
    draft.school = _schoolCtrl.text.trim();
    draft.practiceDuration = _practiceDuration;

    draft.paymentMethod = _paymentMethod;
    draft.paypalEmail = _paypalEmailCtrl.text.trim();
    draft.venmoHandle = _venmoHandleCtrl.text.trim();
    draft.applePayPaymentName = _applePayPaymentNameCtrl.text.trim();
    draft.applePayPaymentPhone = _applePayPaymentPhoneCtrl.text.trim();
    draft.applePayPaymentEmail = _applePayPaymentEmailCtrl.text.trim();
    draft.cardName = _cardNameCtrl.text.trim();
    draft.cardNumber = _cardNumberCtrl.text.trim();
    draft.cardExpiry = _cardExpiryCtrl.text.trim();
    draft.cardCvv = _cardCvvCtrl.text.trim();
    draft.cardZip = _cardZipCtrl.text.trim();
    draft.paymentSaved = _paymentSaved;

    draft.selectedBundle = _selectedBundle;
    draft.bundlePurchased = _bundlePurchased;

    draft.payoutMethod = _payoutMethod;
    draft.legalName = _legalNameCtrl.text.trim();
    draft.payoutEmail = _payoutEmailCtrl.text.trim();
    draft.bankName = _bankNameCtrl.text.trim();
    draft.routing = _routingCtrl.text.trim();
    draft.accountNumber = _accountNumberCtrl.text.trim();
    draft.applePayName = _applePayNameCtrl.text.trim();
    draft.applePayPhone = _applePayPhoneCtrl.text.trim();
    draft.applePayEmail = _applePayEmailCtrl.text.trim();

    draft.agreeTerms = _agreeTerms;
    draft.noCopyright = _noCopyright;
    draft.agreeSafety = _agreeSafety;
    draft.receiveUpdates = _receiveUpdates;
    return true;
  }

  Future<void> _openBundleCheckout({
    required String bundleKey,
    required String title,
    required String subtitle,
    required String priceText,
    required String imageAsset,
  }) async {
    final d = widget.draft;
    final info = ArtistCheckoutInfo(
      artistName: d.displayName.isNotEmpty ? d.displayName : (d.studioName.isNotEmpty ? d.studioName : d.email),
      email: d.email,
      phone: '${d.phoneAreaCode}${d.phone}',
      city: d.city,
      state: d.state ?? d.manualState,
      timeZone: d.timeZone,
      addressLine1: d.addressLine1,
      addressLine2: d.addressLine2,
      zip: d.zip,
      country: d.country,
      isShippingAddressSame: true,
      shippingAddressLine1: d.addressLine1,
      shippingAddressLine2: d.addressLine2,
      shippingCity: d.addressCity,
      shippingState: d.state ?? d.manualState,
      shippingZip: d.zip,
      shippingCountry: d.country,
      shippingTimeZone: d.timeZone,
      paymentMethod: _paymentMethod,
      paymentDetail: _paymentDetailForCheckout(),
      productTitle: title,
      productSubtitle: subtitle,
      productPriceText: priceText,
      productImageAsset: imageAsset,
    );

    final purchased = (await Navigator.push<bool?>(context, MaterialPageRoute(builder: (_) => ArtistCheckoutPage(initial: info)))) ?? false;
    if (purchased) setState(() { _bundlePurchased = true; _selectedBundle = bundleKey; });
  }

  String _paymentDetailForCheckout() {
    switch (_paymentMethod) {
      case 'PayPal': return _paypalEmailCtrl.text.trim();
      case 'Venmo': return _venmoHandleCtrl.text.trim();
      case 'Apple Pay':
        return '${_applePayPaymentNameCtrl.text.trim()} • ${_applePayPaymentPhoneCtrl.text.trim()} • ${_applePayPaymentEmailCtrl.text.trim()}';
      case 'Credit Card':
        final num = _cardNumberCtrl.text.trim();
        final last4 = num.length >= 4 ? num.substring(num.length - 4) : num;
        return '${_cardNameCtrl.text.trim()} • **** $last4 • ${_cardExpiryCtrl.text.trim()}';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          // ── Credentials ────────────────────────────────────────────────────
          regSectionCard(
            title: 'Credentials',
            subtitle: 'Your professional qualifications',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('I am:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _typeToggleOption(NailTechType.professional, 'Professional Nail Technician'),
                    const SizedBox(width: 12),
                    _typeToggleOption(NailTechType.student, 'Student / Unlicensed'),
                  ],
                ),
                const SizedBox(height: 10),
                if (_nailTechType == NailTechType.professional) ...[
                  TextFormField(
                    controller: _licenseCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('License # *', 'Enter license number'),
                    validator: (v) => (_nailTechType == NailTechType.professional && (v == null || v.trim().isEmpty)) ? 'License # is required' : null,
                  ),
                  const SizedBox(height: 6),
                  RegTypeAheadField(
                    label: 'Jurisdiction *',
                    hint: 'Select state',
                    options: kUsStates,
                    selectedValue: _jurisdiction,
                    onChanged: (v) => setState(() => _jurisdiction = v),
                    validator: (v) => (_nailTechType == NailTechType.professional && (v == null || v.isEmpty)) ? 'Jurisdiction is required' : null,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _proYearsExp,
                    style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat),
                    decoration: regDec('Years of Experience *', 'Select years of experience'),
                    items: kProYearsOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat)))).toList(),
                    onChanged: (v) => setState(() => _proYearsExp = v),
                    validator: (v) => (_nailTechType == NailTechType.professional && (v == null || v.isEmpty)) ? 'Years of experience is required' : null,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _schoolCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('School / Training Program *', 'Enter school or program name'),
                    validator: (v) => (_nailTechType == NailTechType.student && (v == null || v.trim().isEmpty)) ? 'School/Program is required' : null,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _practiceDuration,
                    style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat),
                    decoration: regDec('How long have you been practicing? *', 'Select duration'),
                    items: kPracticeDurations.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat)))).toList(),
                    onChanged: (v) => setState(() => _practiceDuration = v),
                    validator: (v) => (_nailTechType == NailTechType.student && (v == null || v.isEmpty)) ? 'Duration is required' : null,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Payment Method ─────────────────────────────────────────────────
          regSectionCard(
            title: 'Payment Method',
            subtitle: 'Select a method and save it (required).',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    regChip('PayPal', _paymentMethod == 'PayPal', () => setState(() { _paymentMethod = 'PayPal'; _paymentSaved = false; })),
                    regChip('Venmo', _paymentMethod == 'Venmo', () => setState(() { _paymentMethod = 'Venmo'; _paymentSaved = false; })),
                    regChip('Apple Pay', _paymentMethod == 'Apple Pay', () => setState(() { _paymentMethod = 'Apple Pay'; _paymentSaved = false; })),
                    regChip('Credit Card', _paymentMethod == 'Credit Card', () => setState(() { _paymentMethod = 'Credit Card'; _paymentSaved = false; })),
                  ],
                ),
                const SizedBox(height: 8),

                if (_paymentMethod == 'PayPal') ...[
                  TextField(controller: _paypalEmailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: kInputFs), decoration: regDec('PayPal Email *', 'name@example.com')),
                  const SizedBox(height: 6),
                ],
                if (_paymentMethod == 'Venmo') ...[
                  TextField(controller: _venmoHandleCtrl, style: const TextStyle(fontSize: kInputFs), decoration: regDec('Venmo Handle / Phone *', '@yourhandle or phone')),
                  const SizedBox(height: 6),
                ],
                if (_paymentMethod == 'Apple Pay') ...[
                  TextField(controller: _applePayPaymentNameCtrl, style: const TextStyle(fontSize: kInputFs), decoration: regDec('Full Name *', 'Name on Apple Pay')),
                  const SizedBox(height: 6),
                  TextField(controller: _applePayPaymentPhoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10), _UsPhoneFmt()], style: const TextStyle(fontSize: kInputFs), decoration: regDec('Phone Number *', 'Apple Pay phone')),
                  const SizedBox(height: 6),
                  TextField(controller: _applePayPaymentEmailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: kInputFs), decoration: regDec('Apple ID Email *', 'email linked to Apple Pay')),
                  const SizedBox(height: 6),
                ],
                if (_paymentMethod == 'Credit Card') ...[
                  TextField(controller: _cardNameCtrl, style: const TextStyle(fontSize: kInputFs), decoration: regDec('Name on Card *', 'Full name')),
                  const SizedBox(height: 6),
                  TextField(controller: _cardNumberCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19), _CardNumFmt()], style: const TextStyle(fontSize: kInputFs), decoration: regDec('Card Number *', '1234 5678 9012 3456')),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _cardExpiryCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryFmt()], style: const TextStyle(fontSize: kInputFs), decoration: regDec('Expiry (MM/YY) *', 'MM/YY'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _cardCvvCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)], style: const TextStyle(fontSize: kInputFs), decoration: regDec('CVV *', '123'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(controller: _cardZipCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: kInputFs), decoration: regDec('Billing ZIP *', 'ZIP code')),
                  const SizedBox(height: 6),
                ],

                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepPlum, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                    onPressed: () {
                      if (!_paymentFieldsValid()) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required payment fields.')));
                        return;
                      }
                      setState(() => _paymentSaved = true);
                    },
                    child: const Text('Save Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.snow)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.blackCat.withValues(alpha: 0.55), size: kInputFs * 1.2),
                    const SizedBox(width: 8),
                    Text(_paymentSaved ? 'Saved ✅' : 'Not saved yet', style: TextStyle(color: AppColors.blackCat, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Nail Material Bundles ──────────────────────────────────────────
          regSectionCard(
            title: 'Nail Material Bundles',
            subtitle: 'Starter bundles for gel, tips, tools and more. (Required)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 320,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _bundleCard(title: 'Starter Material Bundle', subtitle: 'Perfect for new artists.', price: '\$50', imageAsset: 'assets/images/nail_bundle_50.png', bundleKey: 'Starter'),
                      const SizedBox(width: 12),
                      _bundleCard(title: 'Pro Material Bundle', subtitle: 'Gel, tools & tips.', price: '\$100', imageAsset: 'assets/images/nail_bundle_100.png', bundleKey: 'Pro'),
                      const SizedBox(width: 12),
                      _bundleCard(title: 'Studio Bundle', subtitle: 'For high volume artists.', price: '\$150', imageAsset: 'assets/images/nail_bundle_150.png', bundleKey: 'Studio'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(_bundlePurchased ? Icons.check_circle_outline : Icons.lock_outline, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bundlePurchased ? 'Purchased' : 'You must purchase a bundle before account creation.',
                        style: TextStyle(color: AppColors.blackCat, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Payout ─────────────────────────────────────────────────────────
          regSectionCard(
            title: 'Payout',
            subtitle: 'How you receive payouts (can be updated later).',
            child: Column(
              children: [
                DropdownButtonFormField<PayoutMethod>(
                  initialValue: _payoutMethod,
                  style: const TextStyle(fontSize: 13, color: AppColors.blackCat, fontWeight: FontWeight.w500),
                  decoration: regDec('Payout Method *', 'Select payout method'),
                  items: const [
                    DropdownMenuItem(value: PayoutMethod.paypal, child: Text('PayPal', style: TextStyle(fontSize: 14, color: AppColors.blackCat))),
                    DropdownMenuItem(value: PayoutMethod.venmo, child: Text('Venmo', style: TextStyle(fontSize: 14, color: AppColors.blackCat))),
                    DropdownMenuItem(value: PayoutMethod.bankTransfer, child: Text('Bank Transfer', style: TextStyle(fontSize: 14, color: AppColors.blackCat))),
                    DropdownMenuItem(value: PayoutMethod.applePay, child: Text('Apple Pay', style: TextStyle(fontSize: 14, color: AppColors.blackCat))),
                  ],
                  onChanged: (v) => setState(() => _payoutMethod = v ?? PayoutMethod.paypal),
                ),
                const SizedBox(height: 8),

                if (_payoutMethod == PayoutMethod.paypal || _payoutMethod == PayoutMethod.venmo) ...[
                  TextField(controller: _legalNameCtrl, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Legal Name *', 'Legal Name')),
                  const SizedBox(height: 8),
                  TextField(controller: _payoutEmailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec(_payoutMethod == PayoutMethod.venmo ? 'Venmo Email *' : 'PayPal Email *', 'Email')),
                ],

                if (_payoutMethod == PayoutMethod.bankTransfer) ...[
                  TextField(controller: _legalNameCtrl, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Legal Name *', 'Legal Name')),
                  const SizedBox(height: 8),
                  TextField(controller: _bankNameCtrl, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Bank Name *', 'Bank name')),
                  const SizedBox(height: 8),
                  TextField(controller: _routingCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Routing Number *', 'Routing number')),
                  const SizedBox(height: 8),
                  TextField(controller: _accountNumberCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Account Number *', 'Account number')),
                ],

                if (_payoutMethod == PayoutMethod.applePay) ...[
                  TextField(controller: _applePayNameCtrl, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Full Name *', 'Name on Apple Pay')),
                  const SizedBox(height: 8),
                  TextField(controller: _applePayPhoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10), _UsPhoneFmt()], style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Phone Number *', 'Apple Pay phone')),
                  const SizedBox(height: 8),
                  TextField(controller: _applePayEmailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13, color: AppColors.blackCat), decoration: regDec('Apple ID Email *', 'Email linked to Apple Pay')),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Policies & Agreements ──────────────────────────────────────────
          if (widget.showAdaCompliance) ...[
            regSectionCard(
              title: 'Policies & Agreements',
              child: Column(
                children: [
                  regCheckRow(value: _agreeTerms, text: 'I agree to the Terms & Conditions *', onChanged: (v) => setState(() => _agreeTerms = v)),
                  regCheckRow(value: _noCopyright, text: 'I will not use copyrighted designs without permission *', onChanged: (v) => setState(() => _noCopyright = v)),
                  regCheckRow(value: _agreeSafety, text: 'I agree to follow safety & hygiene guidelines *', onChanged: (v) => setState(() => _agreeSafety = v)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Receive JNT Nail updates & offers', style: TextStyle(fontSize: kInputFs, fontWeight: FontWeight.w800, color: AppColors.blackCat.withValues(alpha: 0.75)))),
                      Transform.scale(
                        scale: 0.88,
                        child: Switch(
                          value: _receiveUpdates,
                          onChanged: (v) => setState(() => _receiveUpdates = v),
                          activeThumbColor: AppColors.blackCat,
                          inactiveThumbColor: AppColors.blackCatLight,
                          inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _typeToggleOption(NailTechType type, String label) {
    final selected = _nailTechType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _nailTechType = type),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.blackCat.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: selected ? AppColors.blackCat : AppColors.blackCat.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              if (selected) const Icon(Icons.check, size: 14, color: AppColors.blackCat),
              if (selected) const SizedBox(width: 4),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.blackCat : AppColors.blackCat.withValues(alpha: 0.55)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bundleCard({
    required String title,
    required String subtitle,
    required String price,
    required String imageAsset,
    required String bundleKey,
  }) {
    final selected = _selectedBundle == bundleKey;
    final purchased = _bundlePurchased && _selectedBundle == bundleKey;

    return InkWell(
      onTap: () => setState(() => _selectedBundle = bundleKey),
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: selected ? AppColors.blackCat.withValues(alpha: 0.45) : AppColors.blackCat.withValues(alpha: 0.06), width: selected ? 1.4 : 1),
          boxShadow: [BoxShadow(color: AppColors.blackCat.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: Color(0xFFF5F0FF), borderRadius: BorderRadius.zero),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.asset(imageAsset, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => Text('Image', style: TextStyle(color: AppColors.blackCat.withValues(alpha: 0.35), fontWeight: FontWeight.w800))),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.blackCat.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF06C7A))),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.blackCat, foregroundColor: AppColors.snow, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                onPressed: (purchased || _bundlePurchased) ? null : () => _openBundleCheckout(bundleKey: bundleKey, title: title, subtitle: subtitle, priceText: price, imageAsset: imageAsset),
                child: Text(purchased ? 'Purchased' : 'Add to Cart', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
