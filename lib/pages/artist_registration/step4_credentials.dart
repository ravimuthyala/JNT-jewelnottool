import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class _UsPhoneFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) return newValue.copyWith(text: digits);
    if (digits.length <= 6) {
      return newValue.copyWith(
        text: '(${digits.substring(0, 3)}) ${digits.substring(3)}',
      );
    }
    return newValue.copyWith(
      text:
          '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, digits.length.clamp(0, 10))}',
    );
  }
}

class _CardNumFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = digitsOnly.substring(0, digitsOnly.length.clamp(0, 19));
    final buf = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && index % 4 == 0) buf.write(' ');
      buf.write(digits[index]);
    }
    return newValue.copyWith(text: buf.toString());
  }
}

class _ExpiryFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = digitsOnly.substring(0, digitsOnly.length.clamp(0, 4));
    if (digits.length <= 2) return newValue.copyWith(text: digits);
    return newValue.copyWith(
      text: '${digits.substring(0, 2)}/${digits.substring(2)}',
    );
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

  late PayoutMethod _payoutMethod;
  late final TextEditingController _legalNameCtrl;
  late final TextEditingController _payoutEmailCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _routingCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _applePayNameCtrl;
  late final TextEditingController _applePayPhoneCtrl;
  late final TextEditingController _applePayEmailCtrl;

  bool _isValidEmail(String v) => v.contains('@') && v.contains('.');

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _paymentMethod = d.paymentMethod.isEmpty ? 'PayPal' : d.paymentMethod;
    _paypalEmailCtrl = TextEditingController(text: d.paypalEmail);
    _venmoHandleCtrl = TextEditingController(text: d.venmoHandle);
    _applePayPaymentNameCtrl = TextEditingController(
      text: d.applePayPaymentName,
    );
    _applePayPaymentPhoneCtrl = TextEditingController(
      text: d.applePayPaymentPhone,
    );
    _applePayPaymentEmailCtrl = TextEditingController(
      text: d.applePayPaymentEmail,
    );
    _cardNameCtrl = TextEditingController(text: d.cardName);
    _cardNumberCtrl = TextEditingController(text: d.cardNumber);
    _cardExpiryCtrl = TextEditingController(text: d.cardExpiry);
    _cardCvvCtrl = TextEditingController(text: d.cardCvv);
    _cardZipCtrl = TextEditingController(text: d.cardZip);
    _paymentSaved = d.paymentSaved;

    _payoutMethod = d.payoutMethod;
    _legalNameCtrl = TextEditingController(text: d.legalName);
    _payoutEmailCtrl = TextEditingController(text: d.payoutEmail);
    _bankNameCtrl = TextEditingController(text: d.bankName);
    _routingCtrl = TextEditingController(text: d.routing);
    _accountNumberCtrl = TextEditingController(text: d.accountNumber);
    _applePayNameCtrl = TextEditingController(text: d.applePayName);
    _applePayPhoneCtrl = TextEditingController(text: d.applePayPhone);
    _applePayEmailCtrl = TextEditingController(text: d.applePayEmail);
  }

  @override
  void dispose() {
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
    if (_paymentMethod == 'PayPal') {
      return _isValidEmail(_paypalEmailCtrl.text.trim());
    }
    if (_paymentMethod == 'Venmo') {
      return _venmoHandleCtrl.text.trim().isNotEmpty;
    }
    if (_paymentMethod == 'Apple Pay') {
      final phone = _applePayPaymentPhoneCtrl.text.trim().replaceAll(
        RegExp(r'\D'),
        '',
      );
      return _applePayPaymentNameCtrl.text.trim().isNotEmpty &&
          phone.length >= 10 &&
          _isValidEmail(_applePayPaymentEmailCtrl.text.trim());
    }
    if (_paymentMethod == 'Credit Card') {
      final number = _cardNumberCtrl.text.trim().replaceAll(' ', '');
      final expiryOk = RegExp(
        r'^\d{2}\/\d{2}$',
      ).hasMatch(_cardExpiryCtrl.text.trim());
      final numberOk =
          RegExp(r'^\d+$').hasMatch(number) &&
          number.length >= 13 &&
          number.length <= 19;
      final cvv = _cardCvvCtrl.text.trim();
      final cvvOk =
          RegExp(r'^\d+$').hasMatch(cvv) &&
          (cvv.length == 3 || cvv.length == 4);
      return _cardNameCtrl.text.trim().isNotEmpty &&
          numberOk &&
          expiryOk &&
          cvvOk &&
          _cardZipCtrl.text.trim().isNotEmpty;
    }
    return false;
  }

  void autofill() {
    setState(() {
      _paymentMethod = 'PayPal';
      _paypalEmailCtrl.text = 'luna.nails@paypal.com';
      _paymentSaved = true;
      _payoutMethod = PayoutMethod.paypal;
      _legalNameCtrl.text = 'Luna Johnson';
      _payoutEmailCtrl.text = 'luna.nails@paypal.com';
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (!_paymentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save your payment method.')),
      );
      return false;
    }

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

    draft.payoutMethod = _payoutMethod;
    draft.legalName = _legalNameCtrl.text.trim();
    draft.payoutEmail = _payoutEmailCtrl.text.trim();
    draft.bankName = _bankNameCtrl.text.trim();
    draft.routing = _routingCtrl.text.trim();
    draft.accountNumber = _accountNumberCtrl.text.trim();
    draft.applePayName = _applePayNameCtrl.text.trim();
    draft.applePayPhone = _applePayPhoneCtrl.text.trim();
    draft.applePayEmail = _applePayEmailCtrl.text.trim();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          regSectionCard(
            title: 'Payment Method',
            subtitle: 'Select a method and save it.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    regChip(
                      'PayPal',
                      _paymentMethod == 'PayPal',
                      () => setState(() {
                        _paymentMethod = 'PayPal';
                        _paymentSaved = false;
                      }),
                    ),
                    regChip(
                      'Venmo',
                      _paymentMethod == 'Venmo',
                      () => setState(() {
                        _paymentMethod = 'Venmo';
                        _paymentSaved = false;
                      }),
                    ),
                    regChip(
                      'Apple Pay',
                      _paymentMethod == 'Apple Pay',
                      () => setState(() {
                        _paymentMethod = 'Apple Pay';
                        _paymentSaved = false;
                      }),
                    ),
                    regChip(
                      'Credit Card',
                      _paymentMethod == 'Credit Card',
                      () => setState(() {
                        _paymentMethod = 'Credit Card';
                        _paymentSaved = false;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: kFieldGap),
                if (_paymentMethod == 'PayPal') ...[
                  TextField(
                    controller: _paypalEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('PayPal Email *', 'name@example.com'),
                  ),
                  const SizedBox(height: kFieldGap),
                ],
                if (_paymentMethod == 'Venmo') ...[
                  TextField(
                    controller: _venmoHandleCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec(
                      'Venmo Handle / Phone *',
                      '@yourhandle or phone',
                    ),
                  ),
                  const SizedBox(height: kFieldGap),
                ],
                if (_paymentMethod == 'Apple Pay') ...[
                  TextField(
                    controller: _applePayPaymentNameCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('Full Name *', 'Name on Apple Pay'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _applePayPaymentPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      _UsPhoneFmt(),
                    ],
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('Phone Number *', 'Apple Pay phone'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _applePayPaymentEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec(
                      'Apple ID Email *',
                      'email linked to Apple Pay',
                    ),
                  ),
                  const SizedBox(height: kFieldGap),
                ],
                if (_paymentMethod == 'Credit Card') ...[
                  TextField(
                    controller: _cardNameCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('Name on Card *', 'Full name'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _cardNumberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19),
                      _CardNumFmt(),
                    ],
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('Card Number *', '1234 5678 9012 3456'),
                  ),
                  const SizedBox(height: kFieldGap),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cardExpiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryFmt(),
                          ],
                          style: const TextStyle(fontSize: kInputFs),
                          decoration: regDec('Expiry (MM/YY) *', 'MM/YY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _cardCvvCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          style: const TextStyle(fontSize: kInputFs),
                          decoration: regDec('CVV *', '123'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _cardZipCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('Billing ZIP *', 'ZIP code'),
                  ),
                  const SizedBox(height: kFieldGap),
                ],
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: regPrimaryButtonStyle(),
                    onPressed: () {
                      if (!_paymentFieldsValid()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill required payment fields.',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _paymentSaved = true);
                    },
                    child: const Text(
                      'Save Payment Method',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
                        color: AppColors.snow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                      size: kInputFs * 1.2,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _paymentSaved ? 'Saved' : 'Not saved yet',
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Payout',
            subtitle: 'How you receive payouts.',
            child: Column(
              children: [
                DropdownButtonFormField<PayoutMethod>(
                  initialValue: _payoutMethod,
                  dropdownColor: AppColors.snow,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: regDec('Payout Method *', 'Select payout method'),
                  items: const [
                    DropdownMenuItem(
                      value: PayoutMethod.paypal,
                      child: Text(
                        'PayPal',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: PayoutMethod.venmo,
                      child: Text(
                        'Venmo',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: PayoutMethod.bankTransfer,
                      child: Text(
                        'Bank Transfer',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: PayoutMethod.applePay,
                      child: Text(
                        'Apple Pay',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.blackCat,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _payoutMethod = v ?? PayoutMethod.paypal),
                ),
                const SizedBox(height: kFieldGap),
                if (_payoutMethod == PayoutMethod.paypal ||
                    _payoutMethod == PayoutMethod.venmo) ...[
                  TextField(
                    controller: _legalNameCtrl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Legal Name *', 'Legal Name'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _payoutEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec(
                      _payoutMethod == PayoutMethod.venmo
                          ? 'Venmo Email *'
                          : 'PayPal Email *',
                      'Email',
                    ),
                  ),
                ],
                if (_payoutMethod == PayoutMethod.bankTransfer) ...[
                  TextField(
                    controller: _legalNameCtrl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Legal Name *', 'Legal Name'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _bankNameCtrl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Bank Name *', 'Bank name'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _routingCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Routing Number *', 'Routing number'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _accountNumberCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Account Number *', 'Account number'),
                  ),
                ],
                if (_payoutMethod == PayoutMethod.applePay) ...[
                  TextField(
                    controller: _applePayNameCtrl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Full Name *', 'Name on Apple Pay'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _applePayPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      _UsPhoneFmt(),
                    ],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec('Phone Number *', 'Apple Pay phone'),
                  ),
                  const SizedBox(height: kFieldGap),
                  TextField(
                    controller: _applePayEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat,
                    ),
                    decoration: regDec(
                      'Apple ID Email *',
                      'Email linked to Apple Pay',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
