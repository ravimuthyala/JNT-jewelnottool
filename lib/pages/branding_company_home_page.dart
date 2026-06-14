import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/storage_url_resolver.dart';

import '../widgets/company_shell_chrome.dart';

class BrandingCompanyHomePage extends StatelessWidget {
  const BrandingCompanyHomePage({
    super.key,
    required this.companyName,
    required this.campaignCount,
    required this.cancelledCount,
    required this.inProgressCount,
    required this.deliveredCount,
    required this.loadingTrendingLooks,
    required this.trendingArtists,
    required this.onLogout,
    this.onOpenProfile,
    this.onRequestTrendingArtist,
  });

  final String companyName;
  final int campaignCount;
  final int cancelledCount;
  final int inProgressCount;
  final int deliveredCount;
  final bool loadingTrendingLooks;
  final List<CompanyTrendingArtist> trendingArtists;

  /// If provided: open the Profile tab/page from Home
  final VoidCallback? onOpenProfile;
  final ValueChanged<CompanyTrendingArtist>? onRequestTrendingArtist;

  /// Logout callback (shell should route to '/')
  final Future<void> Function() onLogout;

  Future<void> _openArtistDetails(
    BuildContext context,
    CompanyTrendingArtist artist,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyArtistDetailsSheet(
        artist: artist,
        onRequest: () {
          Navigator.of(context).pop();
          onRequestTrendingArtist?.call(artist);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final looks = trendingArtists
        .expand((artist) {
          final photos = artist.previousProjects
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false);
          if (photos.isEmpty && artist.imageUrl.trim().isNotEmpty) {
            return <_ArtistLook>[
              _ArtistLook(artist: artist, imageUrl: artist.imageUrl.trim()),
            ];
          }
          return photos
              .map((img) => _ArtistLook(artist: artist, imageUrl: img))
              .toList(growable: false);
        })
        .take(240)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: CompanyHeader(
        companyName: companyName,
        onOpenProfile: onOpenProfile,
        onLogout: onLogout,
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: _OverviewTile(
                  icon: Icons.campaign_outlined,
                  title: 'Campaigns',
                  value: '$campaignCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewTile(
                  icon: Icons.timelapse,
                  title: 'In Progress',
                  value: '$inProgressCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OverviewTile(
                  icon: Icons.check_circle_outline,
                  title: 'Delivered',
                  value: '$deliveredCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewTile(
                  icon: Icons.cancel_outlined,
                  title: 'Cancelled',
                  value: '$cancelledCount',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (loadingTrendingLooks)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (looks.isEmpty)
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Text(
                'No artist uploads available right now.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: looks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) => _TrendingCard(
                artist: looks[index].artist,
                imageUrl: looks[index].imageUrl,
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blackCat, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.artist,
    required this.imageUrl,
  });
  final CompanyTrendingArtist artist;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPhotoPreview(context, imageUrl),
      borderRadius: BorderRadius.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: _buildAnyImage(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        fallback: Container(
                          width: double.infinity,
                          color: Colors.black.withOpacity(0.04),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: _buildAnyImage(
                        artist.avatarUrl,
                        width: 26,
                        height: 26,
                        fit: BoxFit.cover,
                        fallback: _fallbackAvatarChip(artist.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhotoPreview(BuildContext context, String imageSrc) async {
    final image = imageSrc.trim();
    if (image.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _buildAnyImage(
                    image,
                    fit: BoxFit.contain,
                    fallback: const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.blackCat),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatarChip(String artistName) {
    final letter = artistName.trim().isEmpty
        ? 'A'
        : artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      color: const Color(0xFFEDD9C9),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class _ArtistLook {
  const _ArtistLook({required this.artist, required this.imageUrl});
  final CompanyTrendingArtist artist;
  final String imageUrl;
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label.trim().isEmpty ? 'Maker' : label.trim(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class CompanyTrendingArtist {
  const CompanyTrendingArtist({
    required this.name,
    required this.imageUrl,
    this.tierLabel = 'Maker',
    this.avatarUrl = '',
    this.acceptsDirectRequests = false,
    this.rating = 0,
    this.city = '',
    this.state = '',
    this.budgetMin = 0,
    this.budgetMax = 0,
    this.credential = '',
    this.bio = '',
    this.projectNotes = '',
    this.previousProjects = const <String>[],
  });

  final String name;
  final String imageUrl;
  final String tierLabel;
  final String avatarUrl;
  final bool acceptsDirectRequests;
  final double rating;
  final String city;
  final String state;
  final int budgetMin;
  final int budgetMax;
  final String credential;
  final String bio;
  final String projectNotes;
  final List<String> previousProjects;
}

class _CompanyArtistDetailsSheet extends StatelessWidget {
  const _CompanyArtistDetailsSheet({
    required this.artist,
    required this.onRequest,
  });

  final CompanyTrendingArtist artist;
  final VoidCallback onRequest;

  bool _isValidAvatar(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v.startsWith('assets/')) return false;
    if (v.contains('profile_placeholder')) return false;
    if (v.contains('avatar_placeholder')) return false;
    return true;
  }

  void _openPhotoPreview(BuildContext context, String imageSrc) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: _buildAnyImage(
                      imageSrc,
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.16),
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: _isValidAvatar(artist.avatarUrl)
                                ? _buildAnyImage(
                                    artist.avatarUrl,
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    fallback: _fallbackAvatar(artist.name),
                                  )
                                : _fallbackAvatar(artist.name),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artist.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _TierChip(label: artist.tierLabel),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      artist.rating > 0
                                          ? artist.rating.toStringAsFixed(1)
                                          : 'N/A',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${artist.city}, ${artist.state}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Budget: \$${artist.budgetMin} - \$${artist.budgetMax}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (artist.credential.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.deepPlum.withOpacity(0.08),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Text(
                            artist.credential,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (artist.bio.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Artist Bio',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist.bio.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (artist.projectNotes.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Project Notes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist.projectNotes.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Previous Art',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: artist.previousProjects.isEmpty
                            ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.zero,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'No previous art uploaded yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: artist.previousProjects.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.zero,
                                  child: InkWell(
                                    onTap: () => _openPhotoPreview(
                                      context,
                                      artist.previousProjects[i],
                                    ),
                                    child: _buildAnyImage(
                                      artist.previousProjects[i],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      fallback: Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.black.withOpacity(0.04),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: artist.acceptsDirectRequests ? onRequest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPlum,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.blackCat.withOpacity(0.28),
                    disabledForegroundColor: AppColors.snow.withOpacity(0.78),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'Request',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String artistName) {
    final letter = artistName.trim().isEmpty
        ? 'A'
        : artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 84,
      height: 84,
      color: Colors.black.withOpacity(0.04),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Widget _buildAnyImage(
  String src, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  final value = src.trim();
  if (value.isEmpty) return fallback;
  if (value.startsWith('data:image/')) {
    final comma = value.indexOf(',');
    if (comma > 0 && comma < value.length - 1) {
      try {
        final bytes = base64Decode(value.substring(comma + 1));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    return fallback;
  }
  final looksLikeStoragePath =
      value.startsWith('gs://') ||
      value.startsWith('artist/') ||
      value.startsWith('artists/') ||
      value.startsWith('client_artist/') ||
      value.startsWith('client_artists/') ||
      value.startsWith('portfolio/') ||
      value.startsWith('company/') ||
      value.contains('/');
  if (looksLikeStoragePath) {
    return FutureBuilder<String>(
      future: _resolveStorageUrl(value),
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? '').trim();
        if (resolved.isEmpty) return fallback;
        return Image.network(
          resolved,
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  return fallback;
}

Future<String> _resolveStorageUrl(String pathOrGsUrl) async {
  try {
    return (await StorageUrlResolver.resolve(pathOrGsUrl)) ?? '';
  } catch (_) {
    return '';
  }
}

