import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';

class EditPaymentInfoPage extends StatefulWidget {
  const EditPaymentInfoPage({super.key, required this.initial});

  final PaymentInfo initial;

  @override
  State<EditPaymentInfoPage> createState() => _EditPaymentInfoPageState();
}

class _EditPaymentInfoPageState extends State<EditPaymentInfoPage> {
  static const double _fieldHeight = 52;
  late PaymentMethod _method;
  bool _saveForFuture = true;

  // Card controllers
  final _cardNumberCtrl = TextEditingController();
  final _nameOnCardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  // Optional for Venmo/PayPal
  final _venmoCtrl = TextEditingController();
  final _paypalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method;
    _saveForFuture = widget.initial.saveForFuture;

    // _cardNumberCtrl.text = widget.initial.cardNumber;
    // _nameOnCardCtrl.text = widget.initial.nameOnCard;
    // _expiryCtrl.text = widget.initial.expiryMMYY;
    // _cvvCtrl.text = widget.initial.cvv;
    //  _zipCtrl.text = widget.initial.zip;

    // _venmoCtrl.text = widget.initial.venmoHandle;
    // _paypalCtrl.text = widget.initial.paypalEmail;
  }

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _nameOnCardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _zipCtrl.dispose();
    _venmoCtrl.dispose();
    _paypalCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.snow,
    constraints: const BoxConstraints(minHeight: _fieldHeight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
    ),
  );

  bool _isCardValid() {
    final number = _cardNumberCtrl.text
        .replaceAll(RegExp(r'\D'), '')
        .trim(); // remove spaces
    final name = _nameOnCardCtrl.text.trim();
    final exp = _expiryCtrl.text.trim();
    final cvv = _cvvCtrl.text.trim();
    final zip = _zipCtrl.text.trim();

    if (number.length < 12) return false;
    if (name.isEmpty) return false;
    if (!_isValidExpiry(exp)) return false;
    if (cvv.length < 3) return false;
    if (zip.length < 4) return false;

    return true;
  }

  bool _isValidExpiry(String exp) {
    // expects MM/YY
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(exp)) return false;
    final mm = int.tryParse(exp.substring(0, 2));
    final yy = int.tryParse(exp.substring(3, 5));
    if (mm == null || yy == null) return false;
    if (mm < 1 || mm > 12) return false;
    return true;
  }

  Future<void> _save() async {
    if (_method == PaymentMethod.card && !_isCardValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all credit card fields correctly.'),
        ),
      );
      return;
    }

    // Optional validation for venmo/paypal (you can remove if not needed)
    if (_method == PaymentMethod.venmo && _venmoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Venmo handle.')),
      );
      return;
    }
    if (_method == PaymentMethod.paypal && _paypalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your PayPal email.')),
      );
      return;
    }

    final updated = PaymentInfo(
      method: _method,
      saveForFuture: _saveForFuture,
      // cardNumber: _method == PaymentMethod.card ? _cardNumberCtrl.text.trim() : '',
      //nameOnCard: _method == PaymentMethod.card ? _nameOnCardCtrl.text.trim() : '',
      //expiryMMYY: _method == PaymentMethod.card ? _expiryCtrl.text.trim() : '',
      // cvv: _method == PaymentMethod.card ? _cvvCtrl.text.trim() : '',
      //zip: _method == PaymentMethod.card ? _zipCtrl.text.trim() : '',
      // venmoHandle: _method == PaymentMethod.venmo ? _venmoCtrl.text.trim() : '',
      // paypalEmail: _method == PaymentMethod.paypal ? _paypalCtrl.text.trim() : '',
    );

    try {
      await EditProfileSupabaseSave.savePaymentInfo(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save payment method: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final showCardFields = _method == PaymentMethod.card;

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        children: [
          _cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),

                _methodTile(PaymentMethod.applePay, Icons.apple),
                const SizedBox(height: 6),
                _methodTile(
                  PaymentMethod.venmo,
                  Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 6),
                _methodTile(PaymentMethod.paypal, Icons.payment_rounded),
                const SizedBox(height: 6),
                _methodTile(PaymentMethod.card, Icons.credit_card_rounded),

                const SizedBox(height: 6),

                SwitchListTile.adaptive(
                  value: _saveForFuture,
                  onChanged: (v) => setState(() => _saveForFuture = v),
                  activeThumbColor : AppColors.blackCat,
                  title: const Text(
                    'Save for future',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ✅ Conditional detail section
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: showCardFields
                ? _cardContainer(
                    key: const ValueKey('card_fields'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Card Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),

                        TextField(
                          controller: _cardNumberCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              19,
                            ), // includes spaces
                            _CardNumberFormatter(),
                          ],
                          decoration: _dec('Card Number'),
                        ),
                        const SizedBox(height: 6),

                        TextField(
                          controller: _nameOnCardCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Name on Card'),
                        ),
                        const SizedBox(height: 6),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _expiryCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    4,
                                  ), // MMYY (formatter adds /)
                                  _ExpiryFormatter(),
                                ],
                                decoration: _dec('Expiry (MM/YY)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _cvvCtrl,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: _dec('CVV'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        TextField(
                          controller: _zipCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          decoration: _dec('Billing ZIP'),
                        ),
                      ],
                    ),
                  )
                : (_method == PaymentMethod.venmo)
                ? _cardContainer(
                    key: const ValueKey('venmo_fields'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Venmo Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _venmoCtrl,
                          decoration: _dec('Venmo handle (e.g. @alex)'),
                        ),
                      ],
                    ),
                  )
                : (_method == PaymentMethod.paypal)
                ? _cardContainer(
                    key: const ValueKey('paypal_fields'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PayPal Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _paypalCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec('PayPal email'),
                        ),
                      ],
                    ),
                  )
                : _cardContainer(
                    key: const ValueKey('applepay_fields'),
                    child: Text(
                      'Apple Pay will be used at checkout.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(PaymentMethod m, IconData icon) {
    final selected = _method == m;

    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: () => setState(() => _method = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.alabaster, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? AppColors.blackCat
                  : Colors.black.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _label(m),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.85),
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppColors.blackCat
                  : Colors.black.withValues(alpha: 0.30),
            ),
          ],
        ),
      ),
    );
  }

  String _label(PaymentMethod m) {
    switch (m) {
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

  Widget _cardContainer({Key? key, required Widget child}) {
    return Container(
      key: key, // ✅ key goes here
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.alabaster),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  // Formats: 1234 5678 9012 3456
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      final index = i + 1;
      if (index % 4 == 0 && index != digitsOnly.length) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  // Formats: MM/YY
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    String mm = digits.length >= 2 ? digits.substring(0, 2) : digits;
    String yy = digits.length > 2
        ? digits.substring(2, digits.length.clamp(2, 4))
        : '';

    // Prevent invalid month like 19
    if (mm.length == 2) {
      final m = int.tryParse(mm) ?? 0;
      if (m == 0) mm = '01';
      if (m > 12) mm = '12';
    }

    final text = yy.isEmpty ? mm : '$mm/$yy';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

