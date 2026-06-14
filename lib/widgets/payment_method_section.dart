import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../utils/registration_input_utils.dart';

class PaymentMethodSection extends StatefulWidget {
  const PaymentMethodSection({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final PaymentInfo initial;
  final ValueChanged<PaymentInfo> onChanged;

  @override
  State<PaymentMethodSection> createState() => _PaymentMethodSectionState();
}

class _PaymentMethodSectionState extends State<PaymentMethodSection> {
  late PaymentMethod _method;
  late bool _save;

  late final TextEditingController _cardNumberCtrl;
  late final TextEditingController _nameOnCardCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _cvvCtrl;
  late final TextEditingController _zipCtrl;

  late final TextEditingController _venmoCtrl;
  late final TextEditingController _paypalCtrl;

  bool get _isCard => _method == PaymentMethod.card;
  // Smaller font sizes (match registration small fields)
  static const double _titleFs = 16;
  static const double _radioFs = 14;
  static const double _inputFs = 16;
  static const double _labelFs = 16;
  static const double _hintFs = 13;
  static const double _checkFs = 14;
  static const double _fieldHeight = 46;
  static const Color _clientRegBrandBg = Color(0xFFF4EFE1);
  static const Color _clientRegBrandAccent = Color(0xFFEDD9C9);
  static const Color _clientRegBrandInk = Color(0xFF292222);
  @override
  void initState() {
    super.initState();

    _method = widget.initial.method;
    _save = widget.initial.saveForFuture;

    _cardNumberCtrl = TextEditingController(text: widget.initial.cardNumber);
    _nameOnCardCtrl = TextEditingController(text: widget.initial.nameOnCard);
    _expCtrl = TextEditingController(text: widget.initial.expiryMMYY);
    _cvvCtrl = TextEditingController(text: widget.initial.cvv);
    _zipCtrl = TextEditingController(text: widget.initial.zip);

    _venmoCtrl = TextEditingController(text: widget.initial.venmoHandle);
    _paypalCtrl = TextEditingController(text: widget.initial.paypalEmail);

    for (final c in [
      _cardNumberCtrl,
      _nameOnCardCtrl,
      _expCtrl,
      _cvvCtrl,
      _zipCtrl,
      _venmoCtrl,
      _paypalCtrl,
    ]) {
      c.addListener(_emit);
    }

    // emit initial once
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _nameOnCardCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    _zipCtrl.dispose();
    _venmoCtrl.dispose();
    _paypalCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      PaymentInfo(
        method: _method,
        saveForFuture: _save,
        cardNumber: _cardNumberCtrl.text.trim(),
        nameOnCard: _nameOnCardCtrl.text.trim(),
        expiryMMYY: _expCtrl.text.trim(),
        cvv: _cvvCtrl.text.trim(),
        zip: _zipCtrl.text.trim(),
        venmoHandle: _venmoCtrl.text.trim(),
        paypalEmail: _paypalCtrl.text.trim(),
      ),
    );
  }

  InputDecoration _dec(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        fontSize: _labelFs,
        color: AppColors.blackCat.withOpacity(0.70),
      ),
      hintStyle: TextStyle(
        fontSize: _hintFs,
        color: AppColors.blackCat.withOpacity(0.35),
      ),
      filled: true,
      fillColor: AppColors.snow,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCat, width: 1.4),
      ),
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          RadioListTile<PaymentMethod>(
            value: PaymentMethod.applePay,
            groupValue: _method,
            onChanged: (v) => setState(() {
              _method = v!;
              _emit();
            }),
            title: const Text(
              'Apple Pay',
              style: TextStyle(fontSize: _radioFs, fontWeight: FontWeight.w600),
            ),
            activeColor: AppColors.blackCat,
            contentPadding: EdgeInsets.zero,
          ),

          RadioListTile<PaymentMethod>(
            value: PaymentMethod.venmo,
            groupValue: _method,
            onChanged: (v) => setState(() {
              _method = v!;
              _emit();
            }),
            title: const Text(
              'Venmo',
              style: TextStyle(fontSize: _radioFs, fontWeight: FontWeight.w600),
            ),
            activeColor: AppColors.blackCat,
            contentPadding: EdgeInsets.zero,
          ),

          RadioListTile<PaymentMethod>(
            value: PaymentMethod.paypal,
            groupValue: _method,
            onChanged: (v) => setState(() {
              _method = v!;
              _emit();
            }),
            title: const Text(
              'PayPal',
              style: TextStyle(fontSize: _radioFs, fontWeight: FontWeight.w600),
            ),
            activeColor: AppColors.blackCat,
            contentPadding: EdgeInsets.zero,
          ),

          RadioListTile<PaymentMethod>(
            value: PaymentMethod.card,
            groupValue: _method,
            onChanged: (v) => setState(() {
              _method = v!;
              _emit();
            }),
            title: const Text(
              'Credit / Debit Card',
              style: TextStyle(fontSize: _radioFs, fontWeight: FontWeight.w600),
            ),
            activeColor: AppColors.blackCat,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 10),

          // Optional extra fields (only show when relevant)
          if (_method == PaymentMethod.venmo) ...[
            TextField(
              controller: _venmoCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Venmo Handle', '@username'),
            ),
            const SizedBox(height: 10),
          ],

          if (_method == PaymentMethod.paypal) ...[
            TextField(
              controller: _paypalCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('PayPal Email', 'name@email.com'),
            ),
            const SizedBox(height: 10),
          ],

          if (_isCard) ...[
            TextField(
              controller: _cardNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                CardNumberTextInputFormatter(),
              ],
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Card Number', '1234 5678 9012 3456'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameOnCardCtrl,
              style: const TextStyle(fontSize: _inputFs),
              decoration: _dec('Name on Card', 'Full name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expCtrl,
                    style: const TextStyle(fontSize: _inputFs),
                    keyboardType: TextInputType.datetime,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      ExpiryDateTextInputFormatter(),
                    ],
                    decoration: _dec('Expiration Date', 'MM/YY'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cvvCtrl,
                    style: const TextStyle(fontSize: _inputFs),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _dec('CVV', '123'),
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _zipCtrl,
              style: const TextStyle(fontSize: _inputFs),
              keyboardType: TextInputType.number,
              decoration: _dec('Billing ZIP', '12345'),
            ),
            const SizedBox(height: 10),
          ],

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _save,
            onChanged: (v) => setState(() {
              _save = v ?? false;
              _emit();
            }),
            title: const Text(
              'Save payment method for future use',
              style: TextStyle(fontSize: _checkFs, fontWeight: FontWeight.w500),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.blackCat,
          ),
        ],
      ),
    );
  }
}
