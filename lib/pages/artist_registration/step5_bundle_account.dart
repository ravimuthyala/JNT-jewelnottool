import 'package:flutter/material.dart';

import '../artist_checkout_page.dart';
import '../../theme/app_colors.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class Step5BundleAccount extends StatefulWidget {
  const Step5BundleAccount({
    super.key,
    required this.draft,
    this.showAdaCompliance = false,
  });

  final RegistrationDraft draft;
  final bool showAdaCompliance;

  @override
  State<Step5BundleAccount> createState() => Step5BundleAccountState();
}

class Step5BundleAccountState extends State<Step5BundleAccount> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _confirmCtrl;
  late String _selectedBundle;
  late bool _bundlePurchased;
  late bool _agreeTerms;
  late bool _noCopyright;
  late bool _agreeSafety;
  late bool _receiveUpdates;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _emailTouched = false;

  bool get _isEmailValid =>
      _emailCtrl.text.contains('@') && _emailCtrl.text.contains('.');

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _emailCtrl = TextEditingController(text: d.email);
    _passCtrl = TextEditingController(text: d.password);
    _confirmCtrl = TextEditingController(text: d.password);
    _selectedBundle = d.selectedBundle.isEmpty ? 'Starter' : d.selectedBundle;
    _bundlePurchased = d.bundlePurchased;
    _agreeTerms = d.agreeTerms;
    _noCopyright = d.noCopyright;
    _agreeSafety = d.agreeSafety;
    _receiveUpdates = d.receiveUpdates;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void autofill() {
    setState(() {
      _emailCtrl.text = 'luna.nails@test.com';
      _passCtrl.text = 'Test1234!';
      _confirmCtrl.text = 'Test1234!';
      _bundlePurchased = true;
      _selectedBundle = 'Starter';
      _agreeTerms = true;
      _noCopyright = true;
      _agreeSafety = true;
      _receiveUpdates = true;
      _emailTouched = true;
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    setState(() => _emailTouched = true);
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (!_bundlePurchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please purchase a nail material bundle.'),
        ),
      );
      return false;
    }
    if (widget.showAdaCompliance &&
        (!_agreeTerms || !_noCopyright || !_agreeSafety)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept all required agreements.')),
      );
      return false;
    }

    draft.email = _emailCtrl.text.trim();
    draft.password = _passCtrl.text;
    draft.selectedBundle = _selectedBundle;
    draft.bundlePurchased = _bundlePurchased;
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
      artistName: d.displayName.isNotEmpty
          ? d.displayName
          : (d.studioName.isNotEmpty ? d.studioName : d.email),
      email: _emailCtrl.text.trim(),
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
      paymentMethod: d.paymentMethod,
      paymentDetail: _paymentDetailForCheckout(d),
      productTitle: title,
      productSubtitle: subtitle,
      productPriceText: priceText,
      productImageAsset: imageAsset,
    );

    final purchased =
        (await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (_) => ArtistCheckoutPage(initial: info)),
        )) ??
        false;
    if (!mounted) return;
    if (purchased) {
      setState(() {
        _bundlePurchased = true;
        _selectedBundle = bundleKey;
      });
    }
  }

  String _paymentDetailForCheckout(RegistrationDraft draft) {
    switch (draft.paymentMethod) {
      case 'PayPal':
        return draft.paypalEmail.trim();
      case 'Venmo':
        return draft.venmoHandle.trim();
      case 'Apple Pay':
        return '${draft.applePayPaymentName.trim()} • ${draft.applePayPaymentPhone.trim()} • ${draft.applePayPaymentEmail.trim()}';
      case 'Credit Card':
        final number = draft.cardNumber.trim();
        final last4 = number.length >= 4
            ? number.substring(number.length - 4)
            : number;
        return '${draft.cardName.trim()} • **** $last4 • ${draft.cardExpiry.trim()}';
      default:
        return '';
    }
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
            title: 'Account Credentials',
            subtitle: 'You will use these to log in to JewelNotTool.',
            child: Column(
              children: [
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_emailTouched) setState(() {});
                  },
                  onEditingComplete: () {
                    setState(() => _emailTouched = true);
                    FocusScope.of(context).nextFocus();
                  },
                  validator: (_) {
                    if (!_emailTouched) return null;
                    if (_emailCtrl.text.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!_isEmailValid) return 'Enter a valid email address';
                    return null;
                  },
                  decoration: regDec('Email', 'you@example.com'),
                  style: const TextStyle(
                    color: Color(0xFF292222),
                    fontSize: 14,
                    fontFamily: 'Arial',
                  ),
                  ),
                ),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Must be at least 8 characters';
                    }
                    return null;
                  },
                  decoration: regDec(
                    'Password',
                    'At least 8 characters',
                    suffixIcon: IconButton(
                      tooltip: _obscurePass ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.blackCatLight,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF292222),
                    fontSize: 14,
                    fontFamily: 'Arial',
                  ),
                  ),
                ),
                const SizedBox(height: kFieldGap),
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: regDec(
                    'Confirm password',
                    '',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.blackCatLight,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF292222),
                    fontSize: 14,
                    fontFamily: 'Arial',
                  ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Nail Material Bundles',
            subtitle: 'Starter bundles for gel, tips, tools and more.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 320,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _bundleCard(
                        title: 'Starter Material Bundle',
                        subtitle: 'Perfect for new artists.',
                        price: '\$50',
                        imageAsset: 'assets/images/nail_bundle_50.png',
                        bundleKey: 'Starter',
                      ),
                      const SizedBox(width: 12),
                      _bundleCard(
                        title: 'Pro Material Bundle',
                        subtitle: 'Gel, tools & tips.',
                        price: '\$100',
                        imageAsset: 'assets/images/nail_bundle_100.png',
                        bundleKey: 'Pro',
                      ),
                      const SizedBox(width: 12),
                      _bundleCard(
                        title: 'Studio Bundle',
                        subtitle: 'For high volume artists.',
                        price: '\$150',
                        imageAsset: 'assets/images/nail_bundle_150.png',
                        bundleKey: 'Studio',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _bundlePurchased
                          ? Icons.check_circle_outline
                          : Icons.lock_outline,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bundlePurchased
                            ? 'Purchased'
                            : 'You must purchase a bundle before account creation.',
                        style: const TextStyle(
                          color: AppColors.blackCat,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.showAdaCompliance) ...[
            regSectionCard(
              title: 'Policies & Agreements',
              child: Column(
                children: [
                  regCheckRow(
                    value: _agreeTerms,
                    text: 'I agree to the Terms & Conditions *',
                    onChanged: (v) => setState(() => _agreeTerms = v),
                  ),
                  regCheckRow(
                    value: _noCopyright,
                    text:
                        'I will not use copyrighted designs without permission *',
                    onChanged: (v) => setState(() => _noCopyright = v),
                  ),
                  regCheckRow(
                    value: _agreeSafety,
                    text: 'I agree to follow safety & hygiene guidelines *',
                    onChanged: (v) => setState(() => _agreeSafety = v),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Receive JNT Nail updates & offers',
                          style: TextStyle(
                            fontSize: kInputFs,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blackCat.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.88,
                        child: Switch(
                          value: _receiveUpdates,
                          onChanged: (v) => setState(() => _receiveUpdates = v),
                          activeThumbColor: AppColors.blackCat,
                          inactiveThumbColor: AppColors.blackCatLight,
                          inactiveTrackColor: AppColors.blackCatLight
                              .withValues(alpha: 0.35),
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

  Widget _bundleCard({
    required String title,
    required String subtitle,
    required String price,
    required String imageAsset,
    required String bundleKey,
  }) {
    final selected = _selectedBundle == bundleKey;
    final purchased = _bundlePurchased && _selectedBundle == bundleKey;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
      onTap: () => setState(() => _selectedBundle = bundleKey),
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? AppColors.blackCat.withValues(alpha: 0.45)
                : AppColors.blackCat.withValues(alpha: 0.06),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blackCat.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.zero,
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, _, _) => Text(
                      'Image',
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.blackCat.withValues(alpha: 0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFFF06C7A),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: (purchased || _bundlePurchased)
                    ? null
                    : () => _openBundleCheckout(
                        bundleKey: bundleKey,
                        title: title,
                        subtitle: subtitle,
                        priceText: price,
                        imageAsset: imageAsset,
                      ),
                child: Text(
                  purchased ? 'Purchased' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
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
