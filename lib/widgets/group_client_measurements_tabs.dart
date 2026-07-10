import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GroupClientMeasurementData {
  const GroupClientMeasurementData({
    required this.name,
    this.clientEmail = '',
    required this.nailShape,
    required this.nailLength,
    required this.leftHand,
    required this.rightHand,
    this.leftNfc = const <String, bool>{},
    this.rightNfc = const <String, bool>{},
  });

  final String name;
  final String clientEmail;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHand;
  final Map<String, String> rightHand;
  final Map<String, bool> leftNfc;
  final Map<String, bool> rightNfc;
}

class GroupClientMeasurementsTabs extends StatelessWidget {
  const GroupClientMeasurementsTabs({
    super.key,
    required this.clients,
    this.compactRequestDetailsLayout = false,
    this.currentViewerEmail = '',
    this.tabViewHeight,
  });

  final List<GroupClientMeasurementData> clients;
  final bool compactRequestDetailsLayout;
  final String currentViewerEmail;
  final double? tabViewHeight;

  String _fmt(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }

  String _formatMm(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '-') return '-';
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return value;
    return '${parsed.toStringAsFixed(2)} mm';
  }

  Widget _clientTab(GroupClientMeasurementData c) {
    final viewerEmail = currentViewerEmail.trim().toLowerCase();
    final clientEmail = c.clientEmail.trim().toLowerCase();
    final canViewMeasurements =
        viewerEmail.isEmpty ||
        clientEmail.isEmpty ||
        viewerEmail == clientEmail;

    if (!canViewMeasurements) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Text(
              'Only this client’s measurements are visible to the account owner.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    if (compactRequestDetailsLayout) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: _measurementPanel(c, showOuterBorder: false),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: _measurementPanel(c),
    );
  }

  Widget _measurementPanel(
    GroupClientMeasurementData c, {
    bool showOuterBorder = true,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, showOuterBorder ? 0 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Nail Dimensions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                fontFamily: 'ArialBold',
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _plainHandColumn('Left Hand', c.leftHand, c.leftNfc),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                ),
                _plainHandColumn('Right Hand', c.rightHand, c.rightNfc),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.blackCatBorderLight,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _plainSummaryItem('Shape', c.nailShape)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.blackCatBorderLight,
                  ),
                ),
              ),
              Expanded(child: _plainSummaryItem('Length', c.nailLength)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plainHandColumn(
    String title,
    Map<String, String> map,
    Map<String, bool> nfc,
  ) {
    String value(String key) => _formatMm(map[key] ?? '');

    Widget row(String key, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.60),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: nfc[key] == true
                  ? Center(child: _nfcChip())
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value(key),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 8),
          row('thumb', 'Thumb'),
          row('index', 'Index'),
          row('middle', 'Middle'),
          row('ring', 'Ring'),
          row('pinky', 'Pinky'),
        ],
      ),
    );
  }

  Widget _plainSummaryItem(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.blackCat.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _fmt(value),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.blackCat,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _nfcChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'NFC',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Text(
          'No client measurements found.',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: clients.length,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.black.withValues(alpha: 0.90),
              unselectedLabelColor: Colors.black.withValues(alpha: 0.62),
              indicatorColor: AppColors.alabaster,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AppColors.alabaster.withValues(alpha: 0.9);
                }
                return null;
              }),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: clients
                  .map(
                    (c) => Tab(
                      text: c.name.trim().isEmpty ? 'Client' : c.name.trim(),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(
              height:
                  tabViewHeight ?? (compactRequestDetailsLayout ? 312 : 350),
              child: TabBarView(children: clients.map(_clientTab).toList()),
            ),
          ],
        ),
      ),
    );
  }
}
