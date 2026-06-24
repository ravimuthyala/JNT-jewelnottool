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
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
              ),
              child: Text(
                'No artist uploads available right now.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat.withValues(alpha: 0.55),
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
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
          boxShadow: <BoxShadow>[
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
                          color: AppColors.blackCat.withValues(alpha: 0.04),
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
      barrierColor: AppColors.blackCat.withValues(alpha: 0.9),
      builder: (_) => Dialog(
        backgroundColor: AppColors.blackCat,
        surfaceTintColor: AppColors.blackCat,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox.expand(
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
                        color: AppColors.blackCat,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.snow,
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
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.snow),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.blackCat.withValues(alpha: 0.65),
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


