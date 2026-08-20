import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../theme/app_colors.dart';
import '../services/storage_url_resolver.dart';

import '../widgets/company_shell_chrome.dart';

class BrandingCompanyHomePage extends StatelessWidget {
  const BrandingCompanyHomePage({
    super.key,
    required this.companyName,
    this.companyLogoUrl = '',
    required this.campaignCount,
    required this.cancelledCount,
    required this.inProgressCount,
    required this.deliveredCount,
    required this.loadingTrendingLooks,
    required this.trendingArtists,
    required this.onLogout,
    this.onOpenProfile,
    this.onRequestTrendingArtist,
    this.autoFocusNotifications = false,
    this.notificationFocusRequestKey = 0,
  });

  final String companyName;
  final String companyLogoUrl;
  final int campaignCount;
  final int cancelledCount;
  final int inProgressCount;
  final int deliveredCount;
  final bool loadingTrendingLooks;
  final List<CompanyTrendingArtist> trendingArtists;

  /// If provided: open the Profile tab/page from Home
  final VoidCallback? onOpenProfile;
  final ValueChanged<CompanyTrendingArtist>? onRequestTrendingArtist;
  final bool autoFocusNotifications;
  final int notificationFocusRequestKey;

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

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Company home',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: CompanyHeader(
        companyName: companyName,
        imageUrl: companyLogoUrl,
        onOpenProfile: onOpenProfile,
        onLogout: onLogout,
        autoFocusNotifications: autoFocusNotifications,
        notificationFocusRequestKey: notificationFocusRequestKey,
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
            Semantics(
              liveRegion: true,
              label: 'Loading artist looks',
              child: const ExcludeSemantics(
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            )
          else if (looks.isEmpty)
            Semantics(
              liveRegion: true,
              label: 'No artist uploads available right now.',
              child: ExcludeSemantics(
                child: Container(
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.snow,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: AppColors.blackCat.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Text(
                    'No artist uploads available right now.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
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
                index: index,
                total: looks.length,
              ),
            ),
        ],
      ),
    ));
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
    return Semantics(
      label: '$title, $value',
      child: ExcludeSemantics(
        child: Container(
      height: 74,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
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
                    color: AppColors.blackCat.withValues(alpha: 0.65),
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
        ),
      ),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  const _TrendingCard({
    required this.artist,
    required this.imageUrl,
    required this.index,
    required this.total,
  });

  final CompanyTrendingArtist artist;
  final String imageUrl;
  final int index;
  final int total;

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  final FocusNode _cardFocusNode = FocusNode(debugLabel: 'companyHomeArtistLook');
  final GlobalKey _cardSemanticsKey = GlobalKey(
    debugLabel: 'companyHomeArtistLookA11y',
  );

  @override
  void dispose() {
    _cardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreCardFocus() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final targetContext = _cardSemanticsKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (!mounted) return;

    FocusScope.of(context).requestFocus(_cardFocusNode);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    targetContext.findRenderObject()?.sendSemanticsEvent(
      FocusSemanticEvent(),
    );
  }

  Future<void> _openPhotoPreview() async {
    final image = widget.imageUrl.trim();
    if (image.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.blackCat.withValues(alpha: 0.9),
      builder: (_) => _ArtistPhotoPreviewDialog(
        imageSrc: image,
        artistName: widget.artist.name,
      ),
    );

    if (!mounted) return;
    await _restoreCardFocus();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.index + 1;

    return Semantics(
      key: _cardSemanticsKey,
      button: true,
      label:
          'Artist look by ${widget.artist.name}, photo $position of ${widget.total}',
      hint: 'Double tap to view full screen',
      onTap: _openPhotoPreview,
      child: ExcludeSemantics(
        child: InkWell(
          focusNode: _cardFocusNode,
          onTap: _openPhotoPreview,
          borderRadius: BorderRadius.zero,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.05),
              ),
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
                            widget.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            fallback: Container(
                              width: double.infinity,
                              color: AppColors.blackCat.withValues(alpha: 0.04),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
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
                            widget.artist.avatarUrl,
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            fallback: _fallbackAvatarChip(widget.artist.name),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.artist.name,
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

class _ArtistPhotoPreviewDialog extends StatefulWidget {
  const _ArtistPhotoPreviewDialog({
    required this.imageSrc,
    required this.artistName,
  });

  final String imageSrc;
  final String artistName;

  @override
  State<_ArtistPhotoPreviewDialog> createState() =>
      _ArtistPhotoPreviewDialogState();
}

class _ArtistPhotoPreviewDialogState extends State<_ArtistPhotoPreviewDialog> {
  final FocusNode _closeFocusNode = FocusNode(
    debugLabel: 'companyHomePhotoPreviewClose',
  );
  final GlobalKey _closeSemanticsKey = GlobalKey(
    debugLabel: 'companyHomePhotoPreviewCloseA11y',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _focusClose();
    });
  }

  @override
  void dispose() {
    _closeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _focusClose() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final closeContext = _closeSemanticsKey.currentContext;
    if (closeContext == null) return;

    FocusScope.of(context).requestFocus(_closeFocusNode);
    closeContext.findRenderObject()?.sendSemanticsEvent(
      FocusSemanticEvent(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _closeSemanticsKey.currentContext
        ?.findRenderObject()
        ?.sendSemanticsEvent(FocusSemanticEvent());
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Artist photo preview',
      child: Dialog(
        backgroundColor: AppColors.blackCat,
        surfaceTintColor: AppColors.blackCat,
        insetPadding: const EdgeInsets.all(12),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    sortKey: OrdinalSortKey(1),
                    image: true,
                    label: 'Artwork by ${widget.artistName}',
                    hint: 'Zoomable image',
                    child: ExcludeSemantics(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: _buildAnyImage(
                            widget.imageSrc,
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
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Semantics(
                    key: _closeSemanticsKey,
                    sortKey: OrdinalSortKey(0),
                    button: true,
                    label: 'Close artist photo preview',
                    hint: 'Double tap to close',
                    onTap: _close,
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          focusNode: _closeFocusNode,
                          tooltip: 'Close artist photo preview',
                          onPressed: _close,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.snow,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.blackCat.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 1,
                  child: Semantics(
                    sortKey: OrdinalSortKey(2),
                    button: true,
                    label: 'Close artist photo preview',
                    onTap: _close,
                    onDidGainAccessibilityFocus: _focusClose,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
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

  // Cap decode resolution to roughly what's actually displayed instead of
  // decoding at full native camera resolution (often 40+MB per image as an
  // uncompressed bitmap regardless of how small it's drawn) — this is what
  // was driving an EXC_RESOURCE memory crash when a list of several artist
  // avatars/portfolio thumbnails rendered at once. The *3 accounts for
  // high-density (3x) screens without needing a BuildContext here.
  final cacheWidth = (width != null && width.isFinite)
      ? (width * 3).round()
      : null;
  final cacheHeight = (height != null && height.isFinite)
      ? (height * 3).round()
      : null;

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
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
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
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
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
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
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


