import 'package:flutter/material.dart';

import '../helpers/artist_ascension.dart';
import '../theme/app_colors.dart';

class ArtistAscensionCard extends StatelessWidget {
  const ArtistAscensionCard({super.key, required this.ascension});

  final ArtistAscensionState ascension;

  static const List<String> _makerPerks = <String>[
    'Welcome gift',
    'Group orders',
    'Learning & development',
  ];
  static const List<String> _goldsmithPerks = <String>[
    'Welcome gift',
    'Group orders',
    'Learning & development',
    'Sponsorship requests',
    'Priority in search',
    'Annual elite conference',
  ];
  static const List<String> _crownedPerks = <String>[
    'Welcome gift',
    'Group orders',
    'Learning & development',
    'Sponsorship requests',
    'Priority in search',
    'Annual elite conference',
    'Insurance reimbursement eligibility',
  ];

  @override
  Widget build(BuildContext context) {
    final tierText = _tierText(ascension.tier);
    final progressMeta = _progressMeta();
    final perks = _perksForTier(ascension.tier);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        border: Border.all(color: AppColors.blackCatBorderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Artist Ascension',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              TierBadge(tier: ascension.tier),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Current tier: $tierText',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current points: ${ascension.points.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 10),
          if (progressMeta.isMaxTier)
            Text(
              'You have reached the highest JNT Ascension tier.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            Text(
              'Progress to ${progressMeta.nextTierLabel}',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressMeta.progress.clamp(0, 1),
                minHeight: 10,
                backgroundColor: AppColors.snow,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${progressMeta.pointsNeeded.toStringAsFixed(2)} points needed for next tier',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
            ),
          ],
          const SizedBox(height: 12),
          _metricRow('Lifetime orders', '${ascension.lifetimeOrders}'),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: const Text(
              'Unlocked perks',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          for (final perk in perks) _perkRow(perk),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _perkRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.blackCat),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.82)),
            ),
          ),
        ],
      ),
    );
  }

  String _tierText(ArtistAscensionTier tier) {
    switch (tier) {
      case ArtistAscensionTier.goldsmith:
        return 'Goldsmith';
      case ArtistAscensionTier.crowned:
        return 'Crowned';
      case ArtistAscensionTier.maker:
        return 'Maker';
    }
  }

  List<String> _perksForTier(ArtistAscensionTier tier) {
    switch (tier) {
      case ArtistAscensionTier.goldsmith:
        return _goldsmithPerks;
      case ArtistAscensionTier.crowned:
        return _crownedPerks;
      case ArtistAscensionTier.maker:
        return _makerPerks;
    }
  }


  _ProgressMeta _progressMeta() {
    switch (ascension.tier) {
      case ArtistAscensionTier.maker:
        return _ProgressMeta(
          progress: ascension.points / 1000,
          pointsNeeded: (1000 - ascension.points).clamp(0.0, 1000.0).toDouble(),
          nextTierLabel: 'Goldsmith',
          isMaxTier: false,
        );
      case ArtistAscensionTier.goldsmith:
        return _ProgressMeta(
          progress: ascension.points / 9750,
          pointsNeeded: (9750 - ascension.points).clamp(0.0, 9750.0).toDouble(),
          nextTierLabel: 'Crowned',
          isMaxTier: false,
        );
      case ArtistAscensionTier.crowned:
        return const _ProgressMeta(
          progress: 1,
          pointsNeeded: 0.0,
          nextTierLabel: '',
          isMaxTier: true,
        );
    }
  }
}

class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier});

  final ArtistAscensionTier tier;

  @override
  Widget build(BuildContext context) {
    final label = switch (tier) {
      ArtistAscensionTier.maker => 'Maker',
      ArtistAscensionTier.goldsmith => 'Goldsmith',
      ArtistAscensionTier.crowned => 'Crowned',
    };
    final color = switch (tier) {
      ArtistAscensionTier.maker => const Color(0xFF8B7355),
      ArtistAscensionTier.goldsmith => const Color(0xFFB08A28),
      ArtistAscensionTier.crowned => const Color(0xFF4E4A7F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProgressMeta {
  const _ProgressMeta({
    required this.progress,
    required this.pointsNeeded,
    required this.nextTierLabel,
    required this.isMaxTier,
  });

  final double progress;
  final double pointsNeeded;
  final String nextTierLabel;
  final bool isMaxTier;
}
