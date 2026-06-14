import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ClientArtistViewTabs extends StatelessWidget {
  const ClientArtistViewTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      margin: const EdgeInsets.fromLTRB(58, 8, 58, 2),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: AppColors.deepPlum,
          borderRadius: BorderRadius.zero,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black.withValues(alpha: 0.70),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        tabs: const <Widget>[
          Tab(text: 'Client'),
          Tab(text: 'Artist'),
        ],
      ),
    );
  }
}
