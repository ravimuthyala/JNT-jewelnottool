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
  });

  final String name;
  final String clientEmail;
  final String nailShape;
  final String nailLength;
  final Map<String, String> leftHand;
  final Map<String, String> rightHand;
}

class GroupClientMeasurementsTabs extends StatelessWidget {
  const GroupClientMeasurementsTabs({
    super.key,
    required this.clients,
    this.compactRequestDetailsLayout = false,
    this.currentViewerEmail = '',
  });

  final List<GroupClientMeasurementData> clients;
  final bool compactRequestDetailsLayout;
  final String currentViewerEmail;

  String _fmt(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }

  Widget _measureField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.60),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            _fmt(value),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _handCard(String title, Map<String, String> map) {
    String value(String key) {
      final raw = (map[key] ?? '').trim();
      if (raw.isEmpty || raw == '-') return '-';
      final normalized = raw.replaceAll(RegExp(r'\s+'), ' ');
      if (RegExp(r'\bmm$', caseSensitive: false).hasMatch(normalized)) {
        return normalized;
      }
      return '$normalized mm';
    }

    Widget row(String key, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.60),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              value(key),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            row('thumb', 'Thumb'),
            row('index', 'Index'),
            row('middle', 'Middle'),
            row('ring', 'Ring'),
            row('pinky', 'Pinky'),
          ],
        ),
      ),
    );
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
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Text(
              'Only this client’s measurements are visible to the account owner.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    if (compactRequestDetailsLayout) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        children: [
          Text(
            'Nail Dimensions (mm)',
            style: TextStyle(
              color: Colors.black.withOpacity(0.90),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _measureField('Nail Shape', c.nailShape)),
              const SizedBox(width: 8),
              Expanded(child: _measureField('Nail Length', c.nailLength)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handCard('Left Hand', c.leftHand),
              const SizedBox(width: 8),
              _handCard('Right Hand', c.rightHand),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Row(
          children: [
            Expanded(child: _measureField('Nail Shape', c.nailShape)),
            const SizedBox(width: 8),
            Expanded(child: _measureField('Nail Length', c.nailLength)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handCard('Left Hand', c.leftHand),
            const SizedBox(width: 8),
            _handCard('Right Hand', c.rightHand),
          ],
        ),
      ],
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
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Text(
          'No client measurements found.',
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: clients.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.black.withOpacity(0.90),
            unselectedLabelColor: Colors.black.withOpacity(0.62),
            indicatorColor: AppColors.alabaster,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return AppColors.alabaster.withOpacity(0.9);
              }
              return null;
            }),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            tabs: clients
                .map(
                  (c) => Tab(text: c.name.trim().isEmpty ? 'Client' : c.name.trim()),
                )
                .toList(),
          ),
          SizedBox(
            height: compactRequestDetailsLayout ? 230 : 210,
            child: TabBarView(children: clients.map(_clientTab).toList()),
          ),
        ],
      ),
    );
  }
}
