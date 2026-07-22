import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/checkout_info.dart';
import '../models/client_profile_models.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.info,

    // Sizing kit
    required this.includeSizingKit,
    this.sizingKitPrice = 3.0,
    required this.sizingKitImageAsset,

    // Bundle
    this.includeBundle = false,
    this.bundleKey, // 'Starter' | 'Pro' | 'Studio' | 'Elite'
    this.scrollHeaderWithBody = false,
    this.backgroundColor = AppColors.alabaster,
    this.sectionColor = AppColors.snow,
    this.dropdownColor = AppColors.snow,
    this.primaryColor = AppColors.blackCat,
    this.onPrimaryColor = AppColors.snow,
    this.fontFamily = 'Arial',
  });

  final CheckoutInfo info;

  final bool includeSizingKit;
  final double sizingKitPrice;
  final String sizingKitImageAsset;

  final bool includeBundle;
  final String? bundleKey;
  final bool scrollHeaderWithBody;
  final Color backgroundColor;
  final Color sectionColor;
  final Color dropdownColor;
  final Color primaryColor;
  final Color onPrimaryColor;
  final String? fontFamily;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  PaymentMethod _method = PaymentMethod.applePay;
  bool _savePayment = true;

  final _nameOnCardCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _venmoCtrl = TextEditingController();
  final _paypalCtrl = TextEditingController();

  bool _kitEnabled = false;
  bool _bundleEnabled = false;
  String? _bundleKey;

  @override
  void initState() {
    super.initState();
    _kitEnabled = widget.includeSizingKit;
    _bundleEnabled = widget.includeBundle;
    _bundleKey = widget.bundleKey;
  }

  @override
  void dispose() {
    _nameOnCardCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    _zipCtrl.dispose();
    _venmoCtrl.dispose();
    _paypalCtrl.dispose();
    super.dispose();
  }

  bool get _isCard => _method == PaymentMethod.card;
  bool get _isVenmo => _method == PaymentMethod.venmo;
  bool get _isPayPal => _method == PaymentMethod.paypal;

  double get _bundlePrice {
    switch (_bundleKey) {
      case 'Starter':
        return 50.0;
      case 'Pro':
        return 100.0;
      case 'Studio':
        return 150.0;
      case 'Elite':
        return 200.0;
      default:
        return 0.0;
    }
  }

  String get _bundleTitle {
    switch (_bundleKey) {
      case 'Starter':
        return 'Starter Material Bundle';
      case 'Pro':
        return 'Pro Material Bundle';
      case 'Studio':
        return 'Studio Bundle';
      case 'Elite':
        return 'Elite Bundle';
      default:
        return 'Material Bundle';
    }
  }

  double get _total {
    double t = 0;
    if (_kitEnabled) t += widget.sizingKitPrice;
    if (_bundleEnabled) t += _bundlePrice;
    return t;
  }

  Future<void> _pay() async {
    if (!_kitEnabled && !_bundleEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    if (_bundleEnabled && (_bundleKey == null || _bundleKey!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a bundle')));
      return;
    }

    if (_isCard) {
      final nameOnCard = _nameOnCardCtrl.text.trim();
      final cardDigits = RegistrationInputUtils.normalizeCardNumber(
        _cardNumberCtrl.text,
      );
      final expiry = _expCtrl.text.trim();
      final cvv = _cvvCtrl.text.trim();
      final zip = _zipCtrl.text.trim();
      if (nameOnCard.isEmpty ||
          cardDigits.length < 15 ||
          !_isValidExpiry(expiry) ||
          !RegExp(r'^\d{3,4}$').hasMatch(cvv) ||
          zip.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid card details')),
        );
        return;
      }
    }

    if (_isVenmo && _venmoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your Venmo handle')));
      return;
    }

    if (_isPayPal &&
        !RegistrationInputUtils.isValidEmail(_paypalCtrl.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PayPal email')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    Navigator.pop<Map<String, dynamic>>(context, {
      'kitPaid': _kitEnabled,
      'bundlePaid': _bundleEnabled,
      'bundleKey': _bundleKey,
      'total': _total,
      'paymentMethod': _method.name,
      'paymentDetails': {
        'nameOnCard': _nameOnCardCtrl.text.trim(),
        'cardNumber': _cardNumberCtrl.text.trim(),
        'expiryMMYY': _expCtrl.text.trim(),
        'cvv': _cvvCtrl.text.trim(),
        'zip': _zipCtrl.text.trim(),
        'venmoHandle': _venmoCtrl.text.trim(),
        'paypalEmail': _paypalCtrl.text.trim(),
      },
    });
  }

  bool _isValidExpiry(String value) {
    final match = RegExp(r'^(\d{2})\/(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final month = int.tryParse(match.group(1)!);
    if (month == null || month < 1 || month > 12) return false;
    return true;
  }

  TextTheme _textTheme(BuildContext context) => Theme.of(context).textTheme;

  TextStyle _sectionTitleStyle(BuildContext context) =>
      _textTheme(context).titleLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.blackCat,
        fontFamily: widget.fontFamily,
      ) ??
      const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.blackCat,
        fontFamily: 'Arial',
      );

  TextStyle _bodyStyle(BuildContext context) =>
      _textTheme(context).bodyLarge?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.blackCat,
        fontFamily: widget.fontFamily,
      ) ??
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.blackCat,
        fontFamily: 'Arial',
      );

  TextStyle _labelStyle(BuildContext context) =>
      _textTheme(context).titleMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.blackCat,
        fontFamily: widget.fontFamily,
      ) ??
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.blackCat,
        fontFamily: 'Arial',
      );

  Widget _header(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/jnt_logo_black.png',
                height: 50,
                fit: BoxFit.contain,
                semanticLabel: 'JNT',
              ),
            ),
            Positioned(
              left: 2,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.scrollHeaderWithBody) ...[
          _header(context),
          const SizedBox(height: 6),
        ],
        _card(
          title: 'Order Summary',
          child: Column(
            children: [
              if (widget.includeSizingKit)
                _summaryRow(
                  title: 'Nail Sizing Kit',
                  price: widget.sizingKitPrice,
                  imageAsset: widget.sizingKitImageAsset,
                  enabled: _kitEnabled,
                  onToggle: (v) => setState(() => _kitEnabled = v),
                ),

              if (widget.includeBundle) ...[
                const SizedBox(height: 12),
                _summaryRow(
                  title: _bundleTitle,
                  price: _bundlePrice,
                  imageAsset: 'assets/images/bundle.png',
                  enabled: _bundleEnabled,
                  onToggle: (v) => setState(() => _bundleEnabled = v),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: 'Bundle',
                  value: _bundleKey ?? 'Not selected',
                  hint: 'Dropdown. Double tap to open.',
                  child: ExcludeSemantics(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bundleKey,
                      dropdownColor: widget.dropdownColor,
                      style: _bodyStyle(context),
                      decoration: _dec('Bundle', 'Select'),
                      items: const [
                        DropdownMenuItem(value: 'Starter', child: Text('Starter')),
                        DropdownMenuItem(value: 'Pro', child: Text('Pro')),
                        DropdownMenuItem(value: 'Studio', child: Text('Studio')),
                        DropdownMenuItem(value: 'Elite', child: Text('Elite')),
                      ],
                      onChanged: (v) => setState(() => _bundleKey = v),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(color: AppColors.blackCatBorderLight),
              const SizedBox(height: 10),
              _row('Total', '\$${_total.toStringAsFixed(2)}', boldRight: true),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _card(
          title: 'Customer Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Name', info.name),
              const SizedBox(height: 10),
              _row('Phone', info.phone),
              const SizedBox(height: 10),
              _row('Address', info.addressLine),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _card(
          title: 'Payment Method',
          child: RadioGroup<PaymentMethod>(
            groupValue: _method,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _method = value);
            },
            child: Column(
              children: [
                _radio(PaymentMethod.applePay, 'Apple Pay'),
                _radio(PaymentMethod.venmo, 'Venmo'),
                _radio(PaymentMethod.paypal, 'PayPal'),
                _radio(PaymentMethod.card, 'Credit / Debit Card'),
                const SizedBox(height: 10),
              if (_isVenmo) ...[
                TextField(
                  controller: _venmoCtrl,
                  style: _bodyStyle(context),
                  decoration: _dec('Venmo Handle', '@username'),
                ),
                const SizedBox(height: 10),
              ],
              if (_isPayPal) ...[
                TextField(
                  controller: _paypalCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: _bodyStyle(context),
                  decoration: _dec('PayPal Email', 'name@email.com'),
                ),
                const SizedBox(height: 10),
              ],
              if (_isCard) ...[
                TextField(
                  controller: _nameOnCardCtrl,
                  style: _bodyStyle(context),
                  decoration: _dec('Name on Card', 'Enter name on card'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cardNumberCtrl,
                  keyboardType: TextInputType.number,
                  style: _bodyStyle(context),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    CardNumberTextInputFormatter(),
                  ],
                  decoration: _dec('Card Number', '1234 5678 9012 3456'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _expCtrl,
                        keyboardType: TextInputType.number,
                        style: _bodyStyle(context),
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
                        keyboardType: TextInputType.number,
                        style: _bodyStyle(context),
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
                  keyboardType: TextInputType.number,
                  style: _bodyStyle(context),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _dec('Billing Zip', 'Enter billing zip'),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _savePayment,
                onChanged: (v) => setState(() => _savePayment = v ?? false),
                title: Text(
                  'Save payment method for future use',
                  style: _bodyStyle(context),
                ),
                activeColor: widget.primaryColor,
                checkColor: widget.onPrimaryColor,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: widget.onPrimaryColor,
              textStyle: _labelStyle(
                context,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: _pay,
            child: Text(
              'Pay \$${_total.toStringAsFixed(2)}',
              style: _labelStyle(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.onPrimaryColor,
              ),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Checkout',
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: widget.scrollHeaderWithBody
            ? null
            : AppBar(
                backgroundColor: AppColors.alabaster,
                centerTitle: true,
                title: Image.asset(
                  'assets/images/jnt_logo_black.png',
                  height: 50,
                  fit: BoxFit.contain,
                ),
                leading: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ),
        body: SafeArea(top: !widget.scrollHeaderWithBody, child: content),
      ),
    );
  }

  Widget _summaryRow({
    required String title,
    required double price,
    required String imageAsset,
    required bool enabled,
    required ValueChanged<bool> onToggle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.95,
          child: Checkbox(
            value: enabled,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: widget.primaryColor,
            checkColor: widget.onPrimaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _labelStyle(context)),
              const SizedBox(height: 6),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: _labelStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Container(
            height: 62,
            width: 62,
            color: AppColors.balletSlippers,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _radio(PaymentMethod value, String label) {
    return RadioListTile<PaymentMethod>(
      value: value,
      title: Text(label, style: _bodyStyle(context)),
      activeColor: widget.primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _row(String left, String right, {bool boldRight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            left,
            style: _labelStyle(
              context,
            ).copyWith(color: AppColors.blackCatLight),
          ),
        ),
        Expanded(
          child: Text(
            right,
            style: _bodyStyle(context).copyWith(
              color: AppColors.blackCat,
              fontWeight: boldRight ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: _labelStyle(context).copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.blackCatLight,
      ),
      floatingLabelStyle: _labelStyle(
        context,
      ).copyWith(fontSize: 12, color: widget.primaryColor),
      hintStyle: _bodyStyle(
        context,
      ).copyWith(fontSize: 12, color: AppColors.blackCatLight),
      filled: true,
      fillColor: widget.dropdownColor,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.blackCatBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCat, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: widget.sectionColor,
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
          Text(title, style: _sectionTitleStyle(context)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
