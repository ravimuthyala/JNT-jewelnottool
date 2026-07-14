import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class ArtistDetailsModal extends StatefulWidget {
  const ArtistDetailsModal({
    super.key,
    required this.supabaseTable,
    this.supabaseId = '',
    this.artistEmail = '',
    this.onProjectTap,
  });

  final String supabaseTable;
  final String supabaseId;
  final String artistEmail;
  final ValueChanged<String>? onProjectTap;

  @override
  State<ArtistDetailsModal> createState() => _ArtistDetailsModalState();
}

class _ArtistDetailsModalState extends State<ArtistDetailsModal> {
  static const double _inputFs = 11.5;
  final int _portfolioPage = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _loadArtistRow() async {
    final table = widget.supabaseTable.trim();
    final id = widget.supabaseId.trim();
    final email = widget.artistEmail.trim().toLowerCase();
    if (table.isEmpty) return null;

    try {
      if (id.isNotEmpty) {
        final byId = await _supabase.from(table).select().eq('id', id).limit(1);
        if (byId.isNotEmpty) {
          return Map<String, dynamic>.from(byId.first as Map);
        }

        final byUid = await _supabase
            .from(table)
            .select()
            .eq('uid', id)
            .limit(1);
        if (byUid.isNotEmpty) {
          return Map<String, dynamic>.from(byUid.first as Map);
        }
      }

      if (email.isNotEmpty) {
        final byEmail = await _supabase
            .from(table)
            .select()
            .eq('email', email)
            .limit(1);
        if (byEmail.isNotEmpty) {
          return Map<String, dynamic>.from(byEmail.first as Map);
        }
      }
    } catch (_) {}

    return null;
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
    return _asStringList(data['panel_artist_services']).isNotEmpty
        ? _asStringList(data['panel_artist_services'])
        : _asStringList(data['panel_services']).isNotEmpty
        ? _asStringList(data['panel_services'])
        : _asStringList(data['services']).isNotEmpty
        ? _asStringList(data['services'])
        : _asStringList(artist['services']);
  }

  List<String> _buildPortfolioImages(Map<String, dynamic> data) {
    final artist = _asMap(data['artist']);
    final portfolio = _asMap(data['portfolio']);
    final artistPortfolio = _asMap(artist['portfolio']);

    final directImages = <String>[
      ..._asStringList(data['panel_portfolioImages']),
      ..._asStringList(data['portfolioImages']),
      ..._asStringList(data['portfolio_images']),
      ..._asStringList(data['panel_artist_portfolioImages']),
      ..._asStringList(portfolio['images']),
      ..._asStringList(portfolio['portfolioImages']),
      ..._asStringList(portfolio['portfolio_images']),
      ..._asStringList(artistPortfolio['images']),
      ..._asStringList(artist['portfolioImages']),
      ..._asStringList(artist['portfolio_images']),
    ];

    if (directImages.isNotEmpty) {
      return directImages.toSet().toList(growable: false);
    }

    final items = <dynamic>[
      ...(data['portfolioItems'] as List<dynamic>? ?? const []),
      ...(data['portfolio_items'] as List<dynamic>? ?? const []),
      ...(portfolio['items'] as List<dynamic>? ?? const []),
      ...(portfolio['portfolioItems'] as List<dynamic>? ?? const []),
      ...(portfolio['portfolio_items'] as List<dynamic>? ?? const []),
      ...(artistPortfolio['items'] as List<dynamic>? ?? const []),
      ...(artistPortfolio['portfolioItems'] as List<dynamic>? ?? const []),
      ...(artistPortfolio['portfolio_items'] as List<dynamic>? ?? const []),
      ...(artist['portfolioItems'] as List<dynamic>? ?? const []),
      ...(artist['portfolio_items'] as List<dynamic>? ?? const []),
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
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _loadArtistRow(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null) {
                  return _ErrorState(
                    onClose: () => Navigator.of(context).pop(),
                    message: 'Artist details not found.',
                  );
                }

                final profile =
                    (data['profile'] as Map<String, dynamic>?) ?? const {};
                final profileAddress =
                    (profile['address'] as Map<String, dynamic>?) ?? const {};
                final basic =
                    (data['basic'] as Map<String, dynamic>?) ?? const {};
                final basicAddress =
                    (basic['address'] as Map<String, dynamic>?) ?? const {};
                final address =
                    (data['address'] as Map<String, dynamic>?) ?? const {};
                final pricing =
                    (data['pricing'] as Map<String, dynamic>?) ?? const {};
                final artist =
                    (data['artist'] as Map<String, dynamic>?) ?? const {};
                final client =
                    (data['client'] as Map<String, dynamic>?) ?? const {};
                final clientProfile =
                    (client['profile'] as Map<String, dynamic>?) ?? const {};
                final clientAddress =
                    (client['address'] as Map<String, dynamic>?) ?? const {};
                final clientProfileAddress =
                    (clientProfile['address'] as Map<String, dynamic>?) ??
                    const {};
                final artistProfile =
                    (data['artist_profile'] as Map<String, dynamic>?) ??
                    const {};
                final nestedArtistProfile =
                    (artist['profile'] as Map<String, dynamic>?) ?? const {};
                final artistProfileAddress =
                    (artistProfile['address'] as Map<String, dynamic>?) ??
                    const {};
                final nestedArtistProfileAddress =
                    (nestedArtistProfile['address'] as Map<String, dynamic>?) ??
                    const {};
                final artistAddress =
                    (artist['address'] as Map<String, dynamic>?) ?? const {};
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
                  basicAddress['city'],
                  basicAddress['addressCity'],
                  profileAddress['city'],
                  profileAddress['addressCity'],
                  clientAddress['city'],
                  clientAddress['addressCity'],
                  clientProfileAddress['city'],
                  clientProfileAddress['addressCity'],
                  data['panel_city'],
                  basic['city'],
                  basic['addressCity'],
                  profile['city'],
                  profile['addressCity'],
                  clientProfile['city'],
                  clientProfile['addressCity'],
                  artistProfile['city'],
                  nestedArtistProfile['city'],
                  address['city'],
                  artist['city'],
                  artistAddress['city'],
                  artistAddress['addressCity'],
                  artistProfileAddress['city'],
                  artistProfileAddress['addressCity'],
                  nestedArtistProfileAddress['city'],
                  nestedArtistProfileAddress['addressCity'],
                  data['city'],
                ]);

                final state = _first([
                  basicAddress['state'],
                  profileAddress['state'],
                  clientAddress['state'],
                  clientProfileAddress['state'],
                  data['panel_state'],
                  basic['state'],
                  profile['state'],
                  clientProfile['state'],
                  artistProfile['state'],
                  nestedArtistProfile['state'],
                  address['state'],
                  artist['state'],
                  artistAddress['state'],
                  artistProfileAddress['state'],
                  nestedArtistProfileAddress['state'],
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
                      data['panel_nfc_request_enabled'] ??
                      (data['availability']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      (data['availability']
                          as Map<String, dynamic>?)?['nfc_request_enabled'] ??
                      (data['profile']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      (data['profile']
                          as Map<String, dynamic>?)?['nfc_request_enabled'] ??
                      (data['artist']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      (data['artist']
                          as Map<String, dynamic>?)?['nfc_request_enabled'] ??
                      ((data['artist']
                              as Map<String, dynamic>?)?['availability']
                          as Map<String, dynamic>?)?['nfcRequestEnabled'] ??
                      ((data['artist']
                              as Map<String, dynamic>?)?['availability']
                          as Map<String, dynamic>?)?['nfc_request_enabled'],
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

                final portfolioImages = _buildPortfolioImages(data);

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
                                onPressed: () => Navigator.of(context).pop(),
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
                              label: [
                                city,
                                state,
                              ].where((e) => e.trim().isNotEmpty).join(', '),
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
                          if (acceptsNfcRequests) ...[
                            const SizedBox(height: 6),
                            Semantics(
                              container: true,
                              label: 'Accepts NFC',
                              child: const ExcludeSemantics(
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.nfc_rounded,
                                        size: 16,
                                        color: AppColors.blackCat,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Accepts NFC',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
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
                          ],
                          const SizedBox(height: 10),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _metaBand(
                                language: language,
                                currency: currency,
                                directRequestsEnabled: directRequestsEnabled,
                              ),
                              _artistBioSection(bio),
                              _specializationSection(
                                specializations: specializations,
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

  Widget _specializationSection({required List<String> specializations}) {
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
                ],
              ),
            ),
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
