import 'package:flutter/material.dart';

import '../models/checkout_info.dart';
import '../theme/app_colors.dart';
import 'checkout_page.dart';

class ClientArtistBundleCheckoutPage extends StatelessWidget {
  const ClientArtistBundleCheckoutPage({
    super.key,
    required this.info,
    required this.bundleKey,
  });

  final CheckoutInfo info;
  final String bundleKey;

  @override
  Widget build(BuildContext context) {
    return CheckoutPage(
      info: info,
      includeSizingKit: false,
      sizingKitPrice: 3.0,
      sizingKitImageAsset: 'assets/images/nail_sizing_kit.png',
      includeBundle: true,
      bundleKey: bundleKey,
      scrollHeaderWithBody: true,
      backgroundColor: AppColors.alabaster,
      sectionColor: AppColors.snow,
      dropdownColor: AppColors.snow,
      primaryColor: AppColors.blackCat,
      onPrimaryColor: AppColors.snow,
      fontFamily: 'Arial',
    );
  }
}
