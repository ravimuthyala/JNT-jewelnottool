import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../services/supabase_firebase_compat.dart';

class ArtistDetailsModal extends StatefulWidget {
  const ArtistDetailsModal({
    super.key,
    required this.docRef,
    this.onProjectTap,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final ValueChanged<String>? onProjectTap;

  @override
  State<ArtistDetailsModal> createState() => _ArtistDetailsModalState();
}

class _ArtistDetailsModalState extends State<ArtistDetailsModal> {
  static const double _inputFs = 11.5;
  final int _portfolioPage = 0;

  String _first(List<dynamic> values) {
    for (final raw in values) {
      if (raw == null) continue;
      final v = raw.toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim()) ?? fallback;
  }

  List<String> _asStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  String _titleCaseTechType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'student') return 'Student / Unlicensed Technician';
    if (value == 'professional') return 'Professional Nail Technician';
    return raw.trim();
  }

  String _buildExperience(Map<String, dynamic> data) {
    final credentials =
        (data['credentials'] as Map<String, dynamic>?) ?? const {};
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    final artistCredentials =
        (artist['credentials'] as Map<String, dynamic>?) ?? const {};

    return _first([
      data['panel_proYearsExperience'],
      credentials['proYearsExperience'],
      artistCredentials['proYearsExperience'],
      data['panel_practiceDuration'],
      credentials['practiceDuration'],
      artistCredentials['practiceDuration'],
    ]);
  }

  List<String> _buildSpecializations(Map<String, dynamic> data) {
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    return _asStringList(data['panel_services']).isNotEmpty
        ? _asStringList(data['panel_services'])
        : _asStringList(data['services']).isNotEmpty
        ? _asStringList(data['services'])
        : _asStringList(artist['services']);
  }

  List<String> _buildPortfolioImages(Map<String, dynamic> data) {
    final artist = (data['artist'] as Map<String, dynamic>?) ?? const {};
    final portfolio = (data['portfolio'] as Map<String, dynamic>?) ?? const {};
    final artistPortfolio =
        (artist['portfolio'] as Map<String, dynamic>?) ?? const {};

    final directImages = <String>[
      ..._asStringList(data['panel_portfolioImages']),
      ..._asStringList(data['portfolioImages']),
      ..._asStringList(portfolio['images']),
      ..._asStringList(artistPortfolio['images']),
    ];

    if (directImages.isNotEmpty) {
      return directImages.toSet().toList(growable: false);
    }

    final items = <dynamic>[
      ...(data['portfolioItems'] as List<dynamic>? ?? const []),
      ...(portfolio['items'] as List<dynamic>? ?? const []),
      ...(artistPortfolio['items'] as List<dynamic>? ?? const []),
    ];

    final urls = items
        .map((e) {
          if (e is Map<String, dynamic>) {
            return (e['imageUrl'] ?? '').toString().trim();
          }
          if (e is Map) {
            return (e['imageUrl'] ?? '').toString().trim();
          }
          return '';
        })
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return urls;
  }

  List<String> _mergePortfolioImages(
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final merged = <String>[..._buildPortfolioImages(data)];
    for (final doc in docs) {
      final item = doc.data();
      final imageUrl = _first([
        item['imageUrl'],
        item['url'],
        item['photoUrl'],
        item['downloadUrl'],
      ]);
      if (imageUrl.isNotEmpty) {
        merged.add(imageUrl);
      }
    }

    final seen = <String>{};
    final deduped = <String>[];
    for (final raw in merged) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (seen.add(url)) deduped.add(url);
    }
    return deduped;
  }

  void _openPhotoPreview(String imageSrc) {
    final closeFocusNode = FocusNode(debugLabel: 'closeImagePreview');

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));

          if (Navigator.of(dialogContext).canPop() &&
              MediaQuery.of(dialogContext).accessibleNavigation) {
            closeFocusNode.requestFocus();
          }
        });

        return Dialog(
          backgroundColor: AppColors.blackCat,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ExcludeSemantics(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: _buildAnyImage(
                        imageSrc,
                        fit: BoxFit.contain,
                        fallback: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.snow,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 8,
                top: 8,
                child: Focus(
                  focusNode: closeFocusNode,
                  child: Semantics(
                    button: true,
                    label: 'Close image preview',
                    hint: 'Double tap to close',
                    onTap: () {
                      closeFocusNode.dispose();
                      Navigator.of(dialogContext).pop();
                    },
                    child: ExcludeSemantics(
                      child: IconButton(
                        tooltip: 'Close image preview',
                        onPressed: () {
                          closeFocusNode.dispose();
                          Navigator.of(dialogContext).pop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.snow,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (closeFocusNode.hasFocus) {
        closeFocusNode.unfocus();
      }
      closeFocusNode.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Artist details',
      child: Material(
        color: AppColors.blackCat.withValues(alpha: 0.6),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SafeArea(
            top: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.docRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.data();
                if (data == null) {
                  return _ErrorState(
                    onClose: () => Navigator.of(context).pop(),
                    message: 'Artist details not found.',
                  );
                }

                final profile =
                    (data['profile'] as Map<String, dynamic>?) ?? const {};
                final address =
                    (data['address'] as Map<String, dynamic>?) ?? const {};
                final pricing =
                    (data['pricing'] as Map<String, dynamic>?) ?? const {};
                final artist =
                    (data['artist'] as Map<String, dynamic>?) ?? const {};
                final artistPricing =
                    (artist['pricing'] as Map<String, dynamic>?) ?? const {};

                final name = _first([
                  data['panel_displayName'],
                  profile['displayName'],
                  data['panel_studioName'],
                  profile['studioName'],
                  data['displayName'],
                  data['name'],
                ]);

                final city = _first([
                  data['panel_city'],
                  profile['city'],
                  address['city'],
                  data['city'],
                ]);

                final state = _first([
                  data['panel_state'],
                  profile['state'],
                  address['state'],
                  data['state'],
                ]);

                final avatarUrl = _first([
                  data['panel_profileImageUrl'],
                  profile['profileImageUrl'],
                  profile['profilePhotoUrl'],
                  profile['photoUrl'],
                  profile['avatarUrl'],
                  data['photoUrl'],
                  data['avatarUrl'],
                  artist['photoUrl'],
                  artist['avatarUrl'],
                ]);

                final bio = _first([
                  data['panel_bio'],
                  profile['bio'],
                  data['bio'],
                ]);

                final language = _first([
                  data['panel_languageSpoken'],
                  profile['languageSpoken'],
                  data['languageSpoken'],
                ]);

                final currency = _first([
                  data['panel_currency'],
                  profile['currency'],
                  data['currency'],
                ]);

                final techType = _titleCaseTechType(
                  _first([
                    data['panel_nailTechType'],
                    profile['nailTechType'],
                    (data['credentials']
                        as Map<String, dynamic>?)?['nailTechType'],
                  ]),
                );
                final yearsExperience = _buildExperience(data);

                final specializations = _buildSpecializations(data);

                final directRequestsEnabled = _asBool(
                  data['panel_directRequestsEnabled'] ??
                      (data['availability']
                          as Map<String, dynamic>?)?['directRequestsEnabled'],
                  fallback: false,
                );
                final acceptsNfcRequests = _asBool(
                  data['panel_nfcRequestEnabled'] ??
                      (data['availability']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      (data['profile']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      (data['artist']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      ((data['artist']
                              as Map<String, dynamic>?)?['availability']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'],
                  fallback: false,
                );

                final rating = _asDouble(
                  ((data['stats'] as Map<String, dynamic>?)?['rating']) ??
                      data['rating'],
                );

                final minPrice = _first([
                  data['panel_minPrice'],
                  pricing['minPrice'],
                  artistPricing['minPrice'],
                ]);

                final maxPrice = _first([
                  data['panel_maxPrice'],
                  pricing['maxPrice'],
                  artistPricing['maxPrice'],
                ]);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.docRef
                      .collection('portfolio_items')
                      .snapshots(),
                  builder: (context, portfolioSnapshot) {
                    final portfolioImages = _mergePortfolioImages(
                      data,
                      portfolioSnapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                    );

                    return Column(
                      children: [
                        Container(
                          color: AppColors.alabaster,
                          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: ExcludeSemantics(
                                  child: Image.asset(
                                    'assets/images/jnt_logo_black.png',
                                    height: 50,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  button: true,
                                  label: 'Close artist details',
                                  child: IconButton(
                                    tooltip: 'Close artist details',
                                    autofocus: MediaQuery.of(
                                      context,
                                    ).accessibleNavigation,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                            children: [
                              const SizedBox(height: 2),
                              Stack(
                                children: [
                                  Center(
                                    child: ExcludeSemantics(
                                      child: _ArtistProfileImage(
                                        url: avatarUrl,
                                        displayName: name,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Semantics(
                                container: true,
                                label:
                                    '${name.isEmpty ? 'Artist' : name}, ${rating > 0 ? '${rating.toStringAsFixed(1)} star rating' : 'no rating available'}',
                                child: ExcludeSemantics(
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name.isEmpty ? 'Artist' : name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.blackCat,
                                            fontFamily: 'ArialBold',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: AppColors.balletSlippers,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating > 0
                                              ? rating.toStringAsFixed(1)
                                              : 'N/A',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.blackCat,
                                            fontFamily: 'Arial',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Column(
                                  children: [
                                    if (techType.isNotEmpty)
                                      Semantics(
                                        container: true,
                                        label: techType,
                                        child: ExcludeSemantics(
                                          child: Text(
                                            techType,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.blackCat,
                                              fontFamily: 'Arial',
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (yearsExperience.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Semantics(
                                        container: true,
                                        label:
                                            'Experience, ${_experienceSemanticLabel(yearsExperience)}',
                                        child: ExcludeSemantics(
                                          child: Text(
                                            yearsExperience,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.blackCat,
                                              fontFamily: 'Arial',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (minPrice.isNotEmpty ||
                                        maxPrice.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Semantics(
                                        container: true,
                                        label: _budgetSemanticLabel(
                                          minPrice,
                                          maxPrice,
                                        ),
                                        child: ExcludeSemantics(
                                          child: Text(
                                            'Budget: ${_budgetDisplayValue(minPrice)} - ${_budgetDisplayValue(maxPrice)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.blackCat,
                                              fontFamily: 'Arial',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              if ([
                                city,
                                state,
                              ].where((e) => e.trim().isNotEmpty).isNotEmpty)
                                Semantics(
                                  container: true,
                                  label: [city, state]
                                      .where((e) => e.trim().isNotEmpty)
                                      .join(', '),
                                  child: ExcludeSemantics(
                                    child: Center(
                                      child: Text(
                                        [city, state]
                                            .where((e) => e.trim().isNotEmpty)
                                            .join(', '),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.blackCat,
                                          fontFamily: 'Arial',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _metaBand(
                                    language: language,
                                    currency: currency,
                                    directRequestsEnabled:
                                        directRequestsEnabled,
                                  ),
                                  _artistBioSection(bio),
                                  _specializationSection(
                                    specializations: specializations,
                                    acceptsNfcRequests: acceptsNfcRequests,
                                  ),
                                  _previousArtSection(portfolioImages),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _budgetDisplayValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '-';
    return value.startsWith('\$') ? value : '\$$value';
  }

  String _budgetSemanticLabel(String minPrice, String maxPrice) {
    final min = minPrice.trim();
    final max = maxPrice.trim();
    if (min.isEmpty && max.isEmpty) return 'Budget not specified';
    if (min.isNotEmpty && max.isNotEmpty) {
      return 'Budget, $min dollars to $max dollars';
    }
    if (min.isNotEmpty) return 'Budget, starting at $min dollars';
    return 'Budget, up to $max dollars';
  }

  String _experienceSemanticLabel(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*[–-]\s*'), ' to ')
        .replaceAll(RegExp(r'\byr\b', caseSensitive: false), 'year')
        .replaceAll(RegExp(r'\byrs\b', caseSensitive: false), 'years');
  }

  Widget _metaBand({
    required String language,
    required String currency,
    required bool directRequestsEnabled,
  }) {
    final languageText = language.trim().isNotEmpty ? language.trim() : 'N/A';
    final currencyText = currency.trim().isNotEmpty ? currency.trim() : 'N/A';
    final requestTypeText = directRequestsEnabled
        ? 'Direct Request'
        : 'Standard Request';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _metaItem(
                  icon: Icons.language_rounded,
                  semanticLabel: 'Language, $languageText',
                  text: languageText,
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _metaItem(
                  icon: Icons.currency_exchange_rounded,
                  semanticLabel: 'Currency, $currencyText',
                  text: currencyText,
                ),
              ),
              _verticalDivider(),
              Expanded(
                child: _metaItem(
                  icon: directRequestsEnabled
                      ? Icons.arrow_outward_rounded
                      : Icons.arrow_forward_rounded,
                  semanticLabel: 'Request type, $requestTypeText',
                  text: requestTypeText,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
      ],
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    height: 24,
    color: AppColors.blackCatBorderLight,
    margin: const EdgeInsets.symmetric(horizontal: 10),
  );

  Widget _metaItem({
    required IconData icon,
    required String semanticLabel,
    required String text,
  }) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.blackCat),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackCat,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _specializationIcon(String label) {
    final value = label.trim().toLowerCase();
    if (value.contains('3d')) return Icons.interests_outlined;
    if (value.contains('airbrush')) return Icons.blur_on_outlined;
    if (value.contains('french')) return Icons.auto_fix_high_outlined;
    if (value.contains('minimal')) return Icons.hexagon_outlined;
    if (value.contains('abstract')) return Icons.gesture_outlined;
    return Icons.brush_outlined;
  }

  Widget _artistBioSection(String bio) {
    final text = bio.trim().isEmpty ? 'No artist bio added yet.' : bio.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: const BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Semantics(
        container: true,
        label: 'Artist Bio, $text',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Artist Bio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.blackCat,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _specializationSection({
    required List<String> specializations,
    required bool acceptsNfcRequests,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: const BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  const Text(
                    'Specialization',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (acceptsNfcRequests) ...[
                    const SizedBox(width: 8),
                    _acceptsNfcTag(),
                  ],
                ],
              ),
            ),
            if (acceptsNfcRequests) ...[
              const SizedBox(height: 8),
              Semantics(
                container: true,
                label: 'Artist accepts NFC requests',
                child: const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 10),
            if (specializations.isEmpty)
              Semantics(
                container: true,
                label: 'Specialization, no specialization selected yet',
                child: ExcludeSemantics(
                  child: Text(
                    'No specialization selected yet.',
                    style: TextStyle(fontSize: 13, color: AppColors.blackCat),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final tileWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 8,
                    children: List.generate(specializations.length, (index) {
                      final item = specializations[index];
                      return SizedBox(
                        width: tileWidth,
                        child: Semantics(
                          container: true,
                          label: index == 0 ? 'Specialization, $item' : item,
                          child: ExcludeSemantics(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _specializationIcon(item),
                                  size: 22,
                                  color: AppColors.blackCat,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _previousArtSection(List<String> images) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: const BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(color: AppColors.blackCatBorderLight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Text(
                'Previous Art',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            _previousArtStrip(images),
          ],
        ),
      ),
    );
  }

  Widget _acceptsNfcTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'Accepts NFC',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _previousArtStrip(List<String> images) {
    if (images.isEmpty) {
      return Semantics(
        container: true,
        label: 'Previous Art, no previous art uploaded yet',
        child: ExcludeSemantics(
          child: Text(
            'No previous art uploaded yet.',
            style: TextStyle(
              fontSize: _inputFs,
              color: AppColors.blackCat.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    final visible = images.take(3).toList(growable: false);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final tileSize = (constraints.maxWidth - (spacing * 2)) / 3;
            return Row(
              children: List.generate(3, (i) {
                final src = i < visible.length ? visible[i] : '';
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : spacing),
                  child: SizedBox(
                    width: tileSize,
                    height: tileSize,
                    child: src.isEmpty
                        ? const SizedBox.shrink()
                        : Semantics(
                            container: true,
                            button: true,
                            label:
                                'Previous art image ${i + 1} of ${visible.length}',
                            hint: 'Double tap to open image preview',
                            onTap: () => _openPhotoPreview(src),
                            child: ExcludeSemantics(
                              child: InkWell(
                                onTap: () => _openPhotoPreview(src),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.zero,
                                  child: _buildAnyImage(
                                    src,
                                    width: tileSize,
                                    height: tileSize,
                                    fit: BoxFit.cover,
                                    fallback: Container(
                                      color: AppColors.blackCat.withValues(
                                        alpha: 0.05,
                                      ),
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
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length > 3 ? 4 : 3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _portfolioPage
                      ? AppColors.blackCat.withValues(alpha: 0.35)
                      : AppColors.blackCat.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ArtistProfileImage extends StatelessWidget {
  const _ArtistProfileImage({required this.url, required this.displayName});

  final String url;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final fallbackLetter = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : '';

    if (url.trim().isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          color: AppColors.balletSlippers,
          border: Border.all(color: AppColors.blackCatBorderLight),
        ),
        alignment: Alignment.center,
        child: Text(
          fallbackLetter,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return SizedBox(
      width: 72,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: _buildAnyImage(
          url,
          fit: BoxFit.cover,
          fallback: Container(
            color: AppColors.balletSlippers,
            alignment: Alignment.center,
            child: Text(
              fallbackLetter,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onClose, required this.message});

  final VoidCallback onClose;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: AppColors.snow,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
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

  if (value.startsWith('gs://') ||
      value.startsWith('artists/') ||
      value.startsWith('client_artists/')) {
    return FutureBuilder<String>(
      future: _resolveStorageUrl(value),
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? '').trim();
        if (resolved.isEmpty) {
          return FutureBuilder<Uint8List?>(
            future: _resolveStorageBytes(value),
            builder: (context, bytesSnap) {
              final bytes = bytesSnap.data;
              if (bytes == null || bytes.isEmpty) return fallback;
              return Image.memory(
                bytes,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, _, _) => fallback,
              );
            },
          );
        }

        return Image.network(
          resolved,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }

  return Image.network(
    value,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => fallback,
  );
}

String _storageBucketForArtistAsset(String value) {
  final lower = value.trim().toLowerCase();
  if (lower.startsWith('portfolio-images/')) return 'portfolio-images';
  if (lower.startsWith('profile-pictures/')) return 'profile-pictures';
  if (lower.startsWith('company-logos/')) return 'company-logos';
  if (lower.startsWith('request-inspiration-photos/')) {
    return 'request-inspiration-photos';
  }

  if (lower.startsWith('artists/') ||
      lower.startsWith('client_artists/') ||
      lower.startsWith('portfolio/')) {
    return 'portfolio-images';
  }

  return 'profile-pictures';
}

String _storagePathForArtistAsset(String value, String bucket) {
  var path = value.trim();
  if (path.startsWith('$bucket/')) {
    path = path.substring(bucket.length + 1);
  }
  return path;
}

Future<Uint8List?> _resolveStorageBytes(String raw) async {
  final value = raw.trim();
  if (value.isEmpty) return null;

  try {
    if (value.startsWith('gs://')) {
      return null;
    }

    if (value.startsWith('artists/') ||
        value.startsWith('client_artists/') ||
        value.startsWith('portfolio-images/') ||
        value.startsWith('profile-pictures/')) {
      final bucket = _storageBucketForArtistAsset(value);
      final path = _storagePathForArtistAsset(value, bucket);
      return await Supabase.instance.client.storage.from(bucket).download(path);
    }
  } catch (_) {}

  return null;
}

Future<String> _resolveStorageUrl(String raw) async {
  final value = raw.trim();
  if (value.isEmpty) return '';

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  try {
    if (value.startsWith('gs://')) {
      return '';
    }

    if (value.startsWith('artists/') ||
        value.startsWith('client_artists/') ||
        value.startsWith('portfolio-images/') ||
        value.startsWith('profile-pictures/')) {
      final bucket = _storageBucketForArtistAsset(value);
      final path = _storagePathForArtistAsset(value, bucket);
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(path)
          .trim();
    }
  } catch (_) {}

  return '';
}
