import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';

class EditPaymentInfoPage extends StatefulWidget {
  const EditPaymentInfoPage({super.key, required this.initial});
  final PaymentInfo initial;

  @override
  State<EditPaymentInfoPage> createState() => _EditPaymentInfoPageState();
}

class _EditPaymentInfoPageState extends State<EditPaymentInfoPage> {
  late PaymentMethod _method;
  bool _save = true;

  final _formKey = GlobalKey<FormState>();

  // Card
  final _cardName = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvv = TextEditingController();
  final _cardZip = TextEditingController();

  // PayPal
  final _paypalEmail = TextEditingController();

  // Venmo
  final _venmoHandle = TextEditingController();

  static const double _titleFs = 13.5;
  static const double _labelFs = 12;
  static const double _inputFs = 12;
  static const double _hintFs = 11.5;

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method;
    _save = widget.initial.saveForFuture;
    _cardName.text = widget.initial.nameOnCard;
    _cardNumber.text = widget.initial.cardNumber;
    _cardExp.text = widget.initial.expiryMMYY;
    _cardCvv.text = widget.initial.cvv;
    _cardZip.text = widget.initial.zip;
    _paypalEmail.text = widget.initial.paypalEmail;
    _venmoHandle.text = widget.initial.venmoHandle;
  }

  @override
  void dispose() {
    _cardName.dispose();
    _cardNumber.dispose();
    _cardExp.dispose();
    _cardCvv.dispose();
    _cardZip.dispose();
    _paypalEmail.dispose();
    _venmoHandle.dispose();
    super.dispose();
  }

  String? _req(String? v, String name) =>
      (v == null || v.trim().isEmpty) ? '$name is required' : null;

  InputDecoration _dec(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(fontSize: _labelFs),
      hintStyle: TextStyle(
        fontSize: _hintFs,
        color: AppColors.blackCat.withValues(alpha: 0.35),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      filled: true,
      fillColor: AppColors.snow,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.alabaster),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.alabaster, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Edit payment info',
      child: Material(
      color: AppColors.snow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Payment',
                        style: TextStyle(
                          fontSize: _titleFs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.blackCat.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                RadioGroup<PaymentMethod>(
                  groupValue: _method,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _method = value);
                  },
                  child: Column(
                    children: [
                      _paymentMethodTile(
                        value: PaymentMethod.applePay,
                        label: 'Apple Pay',
                      ),

                      _paymentMethodTile(
                        value: PaymentMethod.venmo,
                        label: 'Venmo',
                      ),

                      if (_method == PaymentMethod.venmo)
                        _MethodFieldsCard(
                          title: 'Venmo Details',
                          child: Semantics(
                            isRequired: true,
                            child: TextFormField(
                              controller: _venmoHandle,
                              style: const TextStyle(fontSize: _inputFs),
                              decoration: _dec('Venmo Username', '@username'),
                              validator: (v) => _req(v, 'Venmo Username'),
                            ),
                          ),
                        ),

                      _paymentMethodTile(
                        value: PaymentMethod.paypal,
                        label: 'PayPal',
                      ),

                      if (_method == PaymentMethod.paypal)
                        _MethodFieldsCard(
                          title: 'PayPal Details',
                          child: Semantics(
                            isRequired: true,
                            child: TextFormField(
                              controller: _paypalEmail,
                              style: const TextStyle(fontSize: _inputFs),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec('PayPal Email', 'name@email.com'),
                              validator: (v) => _req(v, 'PayPal Email'),
                            ),
                          ),
                        ),

                      _paymentMethodTile(
                        value: PaymentMethod.card,
                        label: 'Credit / Debit Card',
                      ),

                      if (_method == PaymentMethod.card)
                        _MethodFieldsCard(
                          title: 'Card Details',
                          child: Column(
                            children: [
                              Semantics(
                                isRequired: true,
                                child: TextFormField(
                                  controller: _cardName,
                                  style: const TextStyle(fontSize: _inputFs),
                                  decoration: _dec('Name on Card', 'Full name'),
                                  validator: (v) => _req(v, 'Name on Card'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                isRequired: true,
                                child: TextFormField(
                                  controller: _cardNumber,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec(
                                    'Card Number',
                                    '1234 5678 9012 3456',
                                  ),
                                  validator: (v) => _req(v, 'Card Number'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      isRequired: true,
                                      child: TextFormField(
                                        controller: _cardExp,
                                        style: const TextStyle(fontSize: _inputFs),
                                        decoration: _dec('Expiry', 'MM/YY'),
                                        validator: (v) => _req(v, 'Expiry'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Semantics(
                                      isRequired: true,
                                      child: TextFormField(
                                        controller: _cardCvv,
                                        style: const TextStyle(fontSize: _inputFs),
                                        keyboardType: TextInputType.number,
                                        decoration: _dec('CVV', '123'),
                                        validator: (v) => _req(v, 'CVV'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                isRequired: true,
                                child: TextFormField(
                                  controller: _cardZip,
                                  style: const TextStyle(fontSize: _inputFs),
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('Billing Zip', 'Billing zip'),
                                  validator: (v) => _req(v, 'Billing Zip'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                Material(
                  color: AppColors.snow,
                  child: CheckboxListTile(
                    value: _save,
                    onChanged: (v) => setState(() => _save = v ?? false),
                    title: const Text(
                      'Save payment method for future use',
                      style: TextStyle(fontSize: _inputFs),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.blackCat,
                    tileColor: AppColors.snow,
                  ),
                ),

                const SizedBox(height: 6),

                SizedBox(
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () async {
                      if (_method != PaymentMethod.applePay) {
                        if (_formKey.currentState?.validate() != true) return;
                      }

                      final updated = PaymentInfo(
                        method: _method,
                        saveForFuture: _save,
                        cardNumber: _method == PaymentMethod.card
                            ? _cardNumber.text.trim()
                            : '',
                        nameOnCard: _method == PaymentMethod.card
                            ? _cardName.text.trim()
                            : '',
                        expiryMMYY: _method == PaymentMethod.card
                            ? _cardExp.text.trim()
                            : '',
                        cvv: _method == PaymentMethod.card
                            ? _cardCvv.text.trim()
                            : '',
                        zip: _method == PaymentMethod.card
                            ? _cardZip.text.trim()
                            : '',
                        venmoHandle: _method == PaymentMethod.venmo
                            ? _venmoHandle.text.trim()
                            : '',
                        paypalEmail: _method == PaymentMethod.paypal
                            ? _paypalEmail.text.trim()
                            : '',
                      );

                      try {
                        await EditProfileSupabaseSave.savePaymentInfo(updated);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to save payment info: $e'),
                          ),
                        );
                        return;
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context, updated);
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.snow,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _paymentMethodTile({
    required PaymentMethod value,
    required String label,
  }) {
    return Material(
      color: AppColors.snow,
      child: RadioListTile<PaymentMethod>(
        value: value,
        title: Text(label, style: const TextStyle(fontSize: _inputFs)),
        activeColor: AppColors.blackCat,
        tileColor: AppColors.snow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: AppColors.alabaster),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// ---------------- Method Fields Card ----------------

class _MethodFieldsCard extends StatelessWidget {
  const _MethodFieldsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6, right: 6, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.alabaster),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}
